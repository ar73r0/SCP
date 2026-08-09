[CmdletBinding()]
param(
    [string]$ComputerName = "remote-audit",
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

Write-Host "Applying remote-audit demo profile..." -ForegroundColor Cyan

Rename-Computer -NewName $ComputerName -Force

Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True
Set-LabNetworkPrivate
Enable-PSRemoting -SkipNetworkProfileCheck -Force
Enable-NetFirewallRule -DisplayGroup "Windows Remote Management" -ErrorAction SilentlyContinue
Set-Service -Name "WinRM" -StartupType Automatic
Start-Service -Name "WinRM"
Set-Service -Name "wuauserv" -StartupType Manual
Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue

cmd /c "net accounts /minpwlen:8" | Out-Null

Ensure-LocalUser -UserName $AuditUser -Password $AuditPassword
Ensure-LocalUser -UserName "helpdesk-temp" -Password "HelpdeskTemp!2026"

try {
    Add-MpPreference -ExclusionPath "C:\Temp" -ErrorAction SilentlyContinue
}
catch {
}

Write-Host "Remote-audit profile applied." -ForegroundColor Green
Write-Host "Restart the VM before using it as a remote target." -ForegroundColor Yellow
Write-Host "Expected audit outcome: mostly healthy, but weaker password policy and extra admins." -ForegroundColor Yellow
