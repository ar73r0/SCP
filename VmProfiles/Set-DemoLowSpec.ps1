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

Assert-Administrator

Write-Host "Applying low-spec demo profile..." -ForegroundColor Cyan

Rename-Computer -NewName $ComputerName -Force

Enable-PSRemoting -Force
Set-Service -Name "WinRM" -StartupType Automatic
Start-Service -Name "WinRM"

Ensure-LocalUser -UserName $AuditUser -Password $AuditPassword
Ensure-LocalUser -UserName "labadmin1" -Password "LabAdmin1!2026"
Ensure-LocalUser -UserName "labadmin2" -Password "LabAdmin2!2026"

cmd /c "net accounts /minpwlen:0" | Out-Null

Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False

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
Write-Host "Expected audit outcome: obvious failures and warnings across several checks." -ForegroundColor Yellow
