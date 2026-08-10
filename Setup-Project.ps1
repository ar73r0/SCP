[CmdletBinding()]
param(
    [switch]$InstallPowerShell7,
    [switch]$InstallPester,
    [switch]$InstallPwshSpectreConsole,
    [switch]$ConfigureUtf8Profile,
    [switch]$All
)

$ErrorActionPreference = "Stop"

function Write-SetupStep {
    param(
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::Cyan
    )

    Write-Host ""
    Write-Host "== $Message ==" -ForegroundColor $Color
}

function Test-CommandAvailable {
    param([Parameter(Mandatory)][string]$Name)

    [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Install-ModuleIfMissing {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [version]$MinimumVersion = [version]"0.0"
    )

    $installed = Get-Module -ListAvailable -Name $Name |
        Where-Object { $_.Version -ge $MinimumVersion } |
        Sort-Object Version -Descending |
        Select-Object -First 1
    if ($installed) {
        Write-Host "$Name $($installed.Version) is al geinstalleerd." -ForegroundColor Green
        return
    }

    if (-not (Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue)) {
        throw "PSGallery repository niet beschikbaar."
    }

    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    $installParameters = @{
        Name               = $Name
        Scope              = "CurrentUser"
        Force              = $true
        SkipPublisherCheck = $true
    }

    if ($MinimumVersion -gt [version]"0.0") {
        $installParameters.MinimumVersion = $MinimumVersion
    }

    Install-Module @installParameters
    Write-Host "$Name $MinimumVersion of hoger werd geinstalleerd in CurrentUser scope." -ForegroundColor Green
}

function Add-Utf8ProfileConfiguration {
    Write-SetupStep -Message "UTF-8 profielconfiguratie" -Color Yellow

    if (-not (Test-Path $PROFILE.CurrentUserCurrentHost)) {
        $profileDir = Split-Path -Parent $PROFILE.CurrentUserCurrentHost
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        New-Item -ItemType File -Path $PROFILE.CurrentUserCurrentHost -Force | Out-Null
    }

    $profileContent = Get-Content $PROFILE.CurrentUserCurrentHost -Raw -ErrorAction SilentlyContinue
    $utf8Line = '$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = [System.Text.UTF8Encoding]::new()'

    if ($profileContent -match [regex]::Escape($utf8Line)) {
        Write-Host "UTF-8 configuratie staat al in $($PROFILE.CurrentUserCurrentHost)." -ForegroundColor Green
        return
    }

    Add-Content -Path $PROFILE.CurrentUserCurrentHost -Value ""
    Add-Content -Path $PROFILE.CurrentUserCurrentHost -Value "# Windows Security Compliance Platform UTF-8 console configuration"
    Add-Content -Path $PROFILE.CurrentUserCurrentHost -Value $utf8Line

    Write-Host "UTF-8 configuratie toegevoegd aan $($PROFILE.CurrentUserCurrentHost)." -ForegroundColor Green
    Write-Host "Herstart de terminal om de wijziging toe te passen." -ForegroundColor Yellow
}

if ($All) {
    $InstallPowerShell7 = $true
    $InstallPester = $true
    $InstallPwshSpectreConsole = $true
    $ConfigureUtf8Profile = $true
}

Write-Host "Windows Security Compliance Platform setup" -ForegroundColor Cyan
Write-Host "PowerShell versie: $($PSVersionTable.PSVersion)"

if ($InstallPowerShell7) {
    Write-SetupStep -Message "PowerShell 7"

    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Write-Host "PowerShell 7 of hoger is al actief." -ForegroundColor Green
    }
    elseif (Test-CommandAvailable -Name "winget") {
        Write-Host "Installeer PowerShell 7 via winget..." -ForegroundColor Yellow
        winget install --id Microsoft.PowerShell --source winget
        Write-Host "Open daarna een nieuwe terminal met 'pwsh'." -ForegroundColor Yellow
    }
    else {
        Write-Host "winget niet gevonden. Installeer PowerShell 7 manueel vanaf https://github.com/PowerShell/PowerShell/releases" -ForegroundColor Yellow
    }
}

if ($InstallPester) {
    Write-SetupStep -Message "Pester module"
    Install-ModuleIfMissing -Name "Pester" -MinimumVersion "5.0.0"
}

if ($InstallPwshSpectreConsole) {
    Write-SetupStep -Message "PwshSpectreConsole module"
    Install-ModuleIfMissing -Name "PwshSpectreConsole"
}

if ($ConfigureUtf8Profile) {
    Add-Utf8ProfileConfiguration
}

Write-SetupStep -Message "Klaar" -Color Green
Write-Host "Aanbevolen volgende stappen:" -ForegroundColor Cyan
Write-Host "1. Start een nieuwe PowerShell 7 sessie met 'pwsh'."
Write-Host "2. Voer './Start-Audit.ps1' of './Start-AuditTui.ps1' uit."
Write-Host "3. Gebruik './Tests/SecurityAudit.Tests.ps1' via Invoke-Pester voor validatie."
