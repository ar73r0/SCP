[CmdletBinding()]
param(
    [string]$ComputerName = "low-spec",
    [string]$AuditUser = "auditdemo",
    [string]$AuditPassword = "AuditDemo!2026"
)

$ErrorActionPreference = "Stop"

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)

    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Run this script from an elevated PowerShell session."
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

function Set-LabNetworkPrivate {
    $profiles = Get-NetConnectionProfile -ErrorAction SilentlyContinue

    foreach ($profile in $profiles) {
        if ($profile.IPv4Connectivity -ne "Disconnected") {
            Set-NetConnectionProfile -InterfaceIndex $profile.InterfaceIndex -NetworkCategory Private -ErrorAction SilentlyContinue
        }
    }
}

Assert-Administrator

Write-Host "Applying low-spec demo profile..." -ForegroundColor Cyan

Rename-Computer -NewName $ComputerName -Force

Set-LabNetworkPrivate
Enable-PSRemoting -SkipNetworkProfileCheck -Force
Enable-NetFirewallRule -DisplayGroup "Windows Remote Management" -ErrorAction SilentlyContinue
Set-Service -Name "WinRM" -StartupType Automatic
Start-Service -Name "WinRM"

Ensure-LocalUser -UserName $AuditUser -Password $AuditPassword
Ensure-LocalUser -UserName "labadmin1" -Password "LabAdmin1!2026"
Ensure-LocalUser -UserName "labadmin2" -Password "LabAdmin2!2026"

& (Join-Path $PSScriptRoot "Fix-LabRemoting.ps1") `
    -Role Target `
    -SharedUser $AuditUser `
    -SharedPassword $AuditPassword

cmd /c "net accounts /minpwlen:0" | Out-Null

New-ItemProperty `
    -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
    -Name "EnableLUA" `
    -PropertyType DWord `
    -Value 0 `
    -Force | Out-Null

Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False
New-NetFirewallRule -DisplayName "Allow WinRM 5985 for lab" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5985 -Profile Any -ErrorAction SilentlyContinue | Out-Null
Set-Service -Name "wuauserv" -StartupType Disabled
Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue

if (Get-Command Get-LocalUser -ErrorAction SilentlyContinue) {
    Enable-LocalUser -Name "Guest" -ErrorAction SilentlyContinue
}

try {
    Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
}
catch {
}

try {
    Enable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -All -ErrorAction SilentlyContinue | Out-Null
}
catch {
}

Write-Host "Low-spec profile applied." -ForegroundColor Green
Write-Host "Restart the VM before using it as a remote target." -ForegroundColor Yellow
Write-Host "Expected audit outcome: obvious failures and warnings across several checks, while remaining remotely reachable." -ForegroundColor Yellow
