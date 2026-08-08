[CmdletBinding()]
param()

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

Write-Host "Applying remote-audit demo profile..." -ForegroundColor Cyan

Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True
Enable-PSRemoting -Force
Set-Service -Name "WinRM" -StartupType Automatic
Start-Service -Name "WinRM"
Set-Service -Name "wuauserv" -StartupType Manual
Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue

cmd /c "net accounts /minpwlen:8" | Out-Null
Ensure-LocalUser -UserName "auditdemo" -Password "AuditDemo!2026"

Write-Host "Remote-audit profile applied." -ForegroundColor Green
Write-Host "Expected audit outcome: WinRM passes, LocalAdministrators warns, PasswordPolicy warns." -ForegroundColor Yellow
