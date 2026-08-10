[CmdletBinding()]
param(
    [string]$ComputerName = "baseline",
    [string]$AuditUser = "auditdemo",
    [string]$AuditPassword = "AuditDemo!2026",
    [string[]]$TrustedHosts = @("remote-audit", "low-spec")
)

$ErrorActionPreference = "Stop"

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)

    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Run this script from an elevated PowerShell session."
    }
}

function Start-ServiceSafe {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$StartupType
    )

    Set-Service -Name $Name -StartupType $StartupType -ErrorAction SilentlyContinue
    Start-Service -Name $Name -ErrorAction SilentlyContinue
}

function Set-LabNetworkPrivate {
    $profiles = Get-NetConnectionProfile -ErrorAction SilentlyContinue

    foreach ($profile in $profiles) {
        if ($profile.IPv4Connectivity -ne "Disconnected") {
            Set-NetConnectionProfile -InterfaceIndex $profile.InterfaceIndex -NetworkCategory Private -ErrorAction SilentlyContinue
        }
    }
}

function Ensure-LocalUser {
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
    if (-not $existing) {
        $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
        New-LocalUser -Name $UserName -Password $securePassword -PasswordNeverExpires -AccountNeverExpires | Out-Null
    }

    Add-LocalGroupMember -Group "Administrators" -Member $UserName -ErrorAction SilentlyContinue
}

Assert-Administrator

Write-Host "Applying baseline demo profile..." -ForegroundColor Cyan

Rename-Computer -NewName $ComputerName -Force

Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True
Set-LabNetworkPrivate
Enable-PSRemoting -SkipNetworkProfileCheck -Force
Enable-NetFirewallRule -DisplayGroup "Windows Remote Management" -ErrorAction SilentlyContinue
Start-ServiceSafe -Name "WinRM" -StartupType "Automatic"
Start-ServiceSafe -Name "wuauserv" -StartupType "Manual"
Start-ServiceSafe -Name "MpsSvc" -StartupType "Automatic"

cmd /c "net accounts /minpwlen:14" | Out-Null

Ensure-LocalUser -UserName $AuditUser -Password $AuditPassword

if (Get-Command Get-LocalUser -ErrorAction SilentlyContinue) {
    $guest = Get-LocalUser -Name "Guest" -ErrorAction SilentlyContinue
    if ($guest) {
        Disable-LocalUser -Name "Guest" -ErrorAction SilentlyContinue
    }
}

if ($TrustedHosts.Count -gt 0) {
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value ($TrustedHosts -join ",") -Force
}

& (Join-Path $PSScriptRoot "Fix-LabRemoting.ps1") `
    -Role Controller `
    -SharedUser $AuditUser `
    -SharedPassword $AuditPassword `
    -TrustedHosts $TrustedHosts

# The controller runs its own checks locally, so the shared remote audit account
# does not need administrative rights here.
Remove-LocalGroupMember -Group "Administrators" -Member $AuditUser -ErrorAction SilentlyContinue

Write-Host "Baseline profile applied." -ForegroundColor Green
Write-Host "Restart the VM before using it as the audit controller." -ForegroundColor Yellow
Write-Host "Expected audit outcome: strongest machine, mostly Passed." -ForegroundColor Yellow
