[CmdletBinding()]
param(
    [ValidateSet("Target", "Controller")]
    [string]$Role = "Target",

    [string]$ComputerName = $env:COMPUTERNAME,

    [string]$SharedUser = "auditdemo",

    [string]$SharedPassword = "AuditDemo!2026",

    [switch]$EnableBuiltinAdministrator,

    [string]$BuiltinAdministratorPassword = "AdminDemo!2026",

    [string[]]$TrustedHosts = @("remote-audit", "low-spec", "192.168.122.138", "192.168.122.139")
)

$ErrorActionPreference = "Stop"

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)

    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Run this script from an elevated PowerShell session."
    }
}

function Ensure-RegistryPath {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
}

function Ensure-LocalAdminUser {
    param(
        [Parameter(Mandatory)]
        [string]$UserName,

        [Parameter(Mandatory)]
        [string]$Password
    )

    if (-not (Get-Command Get-LocalUser -ErrorAction SilentlyContinue)) {
        return
    }

    $existing = Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue
    $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force

    if (-not $existing) {
        New-LocalUser -Name $UserName -Password $securePassword -PasswordNeverExpires -AccountNeverExpires | Out-Null
    }
    else {
        $adsi = [ADSI]"WinNT://$env:COMPUTERNAME/$UserName,user"
        $adsi.SetPassword($Password)
        $adsi.SetInfo()
    }

    Enable-LocalUser -Name $UserName -ErrorAction SilentlyContinue
    Add-LocalGroupMember -Group "Administrators" -Member $UserName -ErrorAction SilentlyContinue
    Add-LocalGroupMember -Group "Remote Management Users" -Member $UserName -ErrorAction SilentlyContinue
}

function Enable-BuiltInAdministrator {
    param(
        [Parameter(Mandatory)]
        [string]$Password
    )

    if (-not (Get-Command Get-LocalUser -ErrorAction SilentlyContinue)) {
        return
    }

    $adminUser = Get-LocalUser -Name "Administrator" -ErrorAction SilentlyContinue
    if (-not $adminUser) {
        return
    }

    $adsi = [ADSI]"WinNT://$env:COMPUTERNAME/Administrator,user"
    $adsi.SetPassword($Password)
    $adsi.SetInfo()

    Enable-LocalUser -Name "Administrator" -ErrorAction SilentlyContinue
    Add-LocalGroupMember -Group "Remote Management Users" -Member "Administrator" -ErrorAction SilentlyContinue
}

function Set-ConnectedNetworksPrivate {
    $profiles = Get-NetConnectionProfile -ErrorAction SilentlyContinue

    foreach ($profile in $profiles) {
        if ($profile.IPv4Connectivity -ne "Disconnected" -or $profile.IPv6Connectivity -ne "Disconnected") {
            Set-NetConnectionProfile -InterfaceIndex $profile.InterfaceIndex -NetworkCategory Private -ErrorAction SilentlyContinue
        }
    }
}

function Enable-WinRmTarget {
    Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True
    Set-ConnectedNetworksPrivate
    Enable-PSRemoting -SkipNetworkProfileCheck -Force

    Enable-NetFirewallRule -DisplayGroup "Windows Remote Management" -ErrorAction SilentlyContinue
    Enable-NetFirewallRule -Name "WINRM-HTTP-In-TCP" -ErrorAction SilentlyContinue

    Set-Service -Name "WinRM" -StartupType Automatic
    Start-Service -Name "WinRM" -ErrorAction SilentlyContinue

    Ensure-RegistryPath -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    New-ItemProperty `
        -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
        -Name "LocalAccountTokenFilterPolicy" `
        -PropertyType DWord `
        -Value 1 `
        -Force | Out-Null

    Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true -Force
    Set-Item WSMan:\localhost\Service\Auth\Kerberos -Value $true -Force
    Set-Item WSMan:\localhost\Service\Auth\Negotiate -Value $true -Force

    Restart-Service -Name "WinRM" -Force
}

function Set-ControllerTrust {
    param(
        [Parameter(Mandatory)]
        [string[]]$Hosts
    )

    $cleanHosts = $Hosts |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique

    if ($cleanHosts.Count -gt 0) {
        Set-Item WSMan:\localhost\Client\TrustedHosts -Value ($cleanHosts -join ",") -Force
    }
}

function Show-Verification {
    Write-Host ""
    Write-Host "Verification" -ForegroundColor Cyan
    Write-Host "------------" -ForegroundColor Cyan

    try {
        Get-NetConnectionProfile | Format-Table Name, InterfaceAlias, NetworkCategory, IPv4Connectivity -AutoSize
    }
    catch {
    }

    try {
        Get-LocalGroupMember Administrators | Format-Table Name, PrincipalSource -AutoSize
    }
    catch {
    }

    try {
        Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" |
            Select-Object LocalAccountTokenFilterPolicy |
            Format-List
    }
    catch {
    }

    try {
        winrm quickconfig
    }
    catch {
    }
}

Assert-Administrator

Write-Host "Fixing lab remoting for role: $Role" -ForegroundColor Cyan

if ($ComputerName -and $ComputerName -ne $env:COMPUTERNAME) {
    Rename-Computer -NewName $ComputerName -Force
    Write-Host "Computer rename queued: $ComputerName" -ForegroundColor Yellow
}

Ensure-LocalAdminUser -UserName $SharedUser -Password $SharedPassword

if ($EnableBuiltinAdministrator) {
    Enable-BuiltInAdministrator -Password $BuiltinAdministratorPassword
}

if ($Role -eq "Target") {
    Enable-WinRmTarget
    Write-Host "Target remoting settings repaired." -ForegroundColor Green
    Write-Host "Use this shared account from baseline: $SharedUser / $SharedPassword" -ForegroundColor Yellow
    if ($EnableBuiltinAdministrator) {
        Write-Host "Built-in Administrator enabled with password: $BuiltinAdministratorPassword" -ForegroundColor Yellow
    }
}
else {
    Set-ConnectedNetworksPrivate
    Enable-PSRemoting -SkipNetworkProfileCheck -Force
    Set-Service -Name "WinRM" -StartupType Automatic
    Start-Service -Name "WinRM" -ErrorAction SilentlyContinue
    Set-ControllerTrust -Hosts $TrustedHosts
    Write-Host "Controller trust settings repaired." -ForegroundColor Green
    Write-Host "TrustedHosts: $((Get-Item WSMan:\localhost\Client\TrustedHosts).Value)" -ForegroundColor Yellow
}

Show-Verification

Write-Host ""
Write-Host "Restart this VM before testing remoting again." -ForegroundColor Yellow
