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

Assert-Administrator

Write-Host "Applying low-spec demo profile..." -ForegroundColor Cyan

cmd /c "net accounts /minpwlen:0" | Out-Null

Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False

Stop-Service -Name "WinRM" -Force -ErrorAction SilentlyContinue
Set-Service -Name "WinRM" -StartupType Disabled

Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
Set-Service -Name "wuauserv" -StartupType Disabled

Write-Host "Low-spec profile applied." -ForegroundColor Green
Write-Host "Expected audit outcome: Firewall fails, CriticalServices fails, PasswordPolicy warns." -ForegroundColor Yellow
