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

Assert-Administrator

Write-Host "Applying baseline demo profile..." -ForegroundColor Cyan

Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True
Enable-PSRemoting -Force
Start-ServiceSafe -Name "WinRM" -StartupType "Automatic"
Start-ServiceSafe -Name "wuauserv" -StartupType "Manual"
Start-ServiceSafe -Name "MpsSvc" -StartupType "Automatic"

cmd /c "net accounts /minpwlen:12" | Out-Null

if (Get-Command Get-LocalUser -ErrorAction SilentlyContinue) {
    $guest = Get-LocalUser -Name "Guest" -ErrorAction SilentlyContinue
    if ($guest) {
        Disable-LocalUser -Name "Guest" -ErrorAction SilentlyContinue
    }
}

Write-Host "Baseline profile applied." -ForegroundColor Green
Write-Host "Expected audit outcome: mostly Passed, with BitLocker depending on Windows edition." -ForegroundColor Yellow
