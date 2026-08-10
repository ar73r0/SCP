[CmdletBinding()]
param(
    [string]$ComputerListPath = (Join-Path $PSScriptRoot "Config/computers.csv"),
    [string]$ChecksConfigPath = (Join-Path $PSScriptRoot "Config/checks.json"),
    [string]$OutputRoot = $PSScriptRoot,
    [ValidateRange(1, 64)]
    [int]$ThrottleLimit = 5,
    [pscredential]$Credential,
    [ValidateSet("Default", "Basic", "Negotiate", "Kerberos", "Credssp", "Digest", "NegotiateWithImplicitCredential")]
    [string]$Authentication = "Negotiate",
    [ValidateRange(1, 65535)]
    [int]$Port = 5985,
    [switch]$UseSSL,
    [switch]$SkipCertificateCheck,
    [switch]$Lab,
    [switch]$DisableParallel,
    [switch]$SkipHtmlReport,
    [switch]$PassThru
)

$ErrorActionPreference = "Stop"

if ($Lab) {
    if (-not $Credential) {
        $labPassword = ConvertTo-SecureString "AuditDemo!2026" -AsPlainText -Force
        $Credential = [pscredential]::new("auditdemo", $labPassword)
    }

    $Authentication = "Basic"
    $Port = 5986
    $UseSSL = $true
    $SkipCertificateCheck = $true
}

function Invoke-AuditForComputer {
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,

        [Parameter(Mandatory)]
        [string[]]$Checks,

        [pscredential]$Credential,

        [string]$Authentication,

        [int]$Port,

        [switch]$UseSSL,

        [switch]$SkipCertificateCheck
    )

    try {
        Write-Host "[$ComputerName] Audit gestart..."
        Invoke-ComputerAudit `
            -ComputerName $ComputerName `
            -Checks $Checks `
            -Credential $Credential `
            -Authentication $Authentication `
            -Port $Port `
            -UseSSL:$UseSSL `
            -SkipCertificateCheck:$SkipCertificateCheck
    }
    catch {
        [PSCustomObject]@{
            ComputerName = $ComputerName
            Reachable    = $false
            IsLocal      = $false
            Error        = $_.Exception.Message
            Results      = @(
                [PSCustomObject]@{
                    ComputerName = $ComputerName
                    Name         = "AuditExecution"
                    Status       = "Failed"
                    Message      = $_.Exception.Message
                }
            )
        }
    }
}

$moduleRoot = Join-Path $PSScriptRoot "Modules"
$requiredModules = @(
    "SecurityChecks.psm1",
    "RemoteAudit.psm1",
    "Scoring.psm1",
    "Reporting.psm1"
)

foreach ($module in $requiredModules) {
    Import-Module (Join-Path $moduleRoot $module) -Force
}

if (-not (Test-Path $ComputerListPath)) {
    throw "Computerlijst niet gevonden: $ComputerListPath"
}

if (-not (Test-Path $ChecksConfigPath)) {
    throw "Checks-configuratie niet gevonden: $ChecksConfigPath"
}

$config = Get-Content $ChecksConfigPath -Raw | ConvertFrom-Json
$checks = @($config.checks | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

if (-not $checks.Count) {
    throw "Geen checks gevonden in $ChecksConfigPath"
}

$validation = Test-CheckConfiguration -Checks $checks
if (-not $validation.IsValid) {
    $unknownChecks = $validation.UnknownChecks -join ", "
    $knownChecks = $validation.KnownChecks -join ", "
    throw "Onbekende checks in configuratie: $unknownChecks. Geldige checks zijn: $knownChecks"
}

$computers = Import-Csv $ComputerListPath | ForEach-Object {
    $_.ComputerName
} | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

if (-not $computers.Count) {
    throw "Geen computers gevonden in $ComputerListPath"
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logsPath = Join-Path $OutputRoot "Logs"
$reportsPath = Join-Path $OutputRoot "Reports"

New-Item -ItemType Directory -Path $logsPath -Force | Out-Null
New-Item -ItemType Directory -Path $reportsPath -Force | Out-Null

Write-Host ""
Write-Host "Windows Security Compliance Platform" -ForegroundColor Cyan
Write-Host "Start audit: $timestamp"
Write-Host "Aantal computers: $($computers.Count)"
Write-Host "Checks: $($checks -join ', ')"
Write-Host "ThrottleLimit: $ThrottleLimit"
Write-Host "Lab preset: $([bool]$Lab)"
Write-Host "Remoting: $Authentication op poort $Port (SSL: $([bool]$UseSSL))"
Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
Write-Host ""

$supportsParallel = ($PSVersionTable.PSVersion.Major -ge 7) -and (-not $DisableParallel)
if ($supportsParallel) {
    Write-Host "Uitvoering: parallel" -ForegroundColor DarkCyan

    # Capture plain values instead of automatic variables and SwitchParameter
    # instances, which are unreliable when PowerShell serializes runspace state.
    $parallelProjectRoot = $PSScriptRoot
    [string[]]$parallelChecks = $checks
    $parallelCredential = $Credential
    $parallelAuthentication = [string]$Authentication
    $parallelPort = [int]$Port
    $parallelUseSsl = [bool]$UseSSL
    $parallelSkipCertificateCheck = [bool]$SkipCertificateCheck

    $computerResults = @($computers | ForEach-Object -Parallel {
        $computerName = $_
        $checksToRun = $using:parallelChecks
        $projectRoot = $using:parallelProjectRoot
        $credentialToUse = $using:parallelCredential
        $authenticationToUse = $using:parallelAuthentication
        $portToUse = $using:parallelPort
        $useSslForRemote = $using:parallelUseSsl
        $skipCertificateValidation = $using:parallelSkipCertificateCheck
        $ProgressPreference = "SilentlyContinue"

        Import-Module (Join-Path $projectRoot "Modules/SecurityChecks.psm1") -Force
        Import-Module (Join-Path $projectRoot "Modules/RemoteAudit.psm1") -Force

        try {
            Write-Host "[$computerName] Audit gestart..."
            Invoke-ComputerAudit `
                -ComputerName $computerName `
                -Checks $checksToRun `
                -Credential $credentialToUse `
                -Authentication $authenticationToUse `
                -Port $portToUse `
                -UseSSL:$useSslForRemote `
                -SkipCertificateCheck:$skipCertificateValidation
        }
        catch {
            [PSCustomObject]@{
                ComputerName = $computerName
                Reachable    = $false
                IsLocal      = $false
                Error        = $_.Exception.Message
                Results      = @(
                    [PSCustomObject]@{
                        ComputerName = $computerName
                        Name         = "AuditExecution"
                        Status       = "Failed"
                        Message      = $_.Exception.Message
                    }
                )
            }
        }
    } -ThrottleLimit $ThrottleLimit)
}
else {
    if ($DisableParallel) {
        Write-Host "Uitvoering: sequentieel (parallel uitgeschakeld)" -ForegroundColor Yellow
    }
    else {
        Write-Host "Uitvoering: sequentieel (PowerShell 5.1 compatibiliteit)" -ForegroundColor Yellow
    }

    $computerResults = foreach ($computerName in $computers) {
        Invoke-AuditForComputer `
            -ComputerName $computerName `
            -Checks $checks `
            -Credential $Credential `
            -Authentication $Authentication `
            -Port $Port `
            -UseSSL:$UseSSL `
            -SkipCertificateCheck:$SkipCertificateCheck
    }
}

$flatResults = foreach ($entry in $computerResults) {
    foreach ($result in $entry.Results) {
        $result
    }
}

$scoreSummary = Get-ComplianceSummary -Results $flatResults

$jsonLogPath = Join-Path $logsPath "audit-$timestamp.json"
$csvLogPath = Join-Path $logsPath "audit-$timestamp.csv"
$htmlReportPath = Join-Path $reportsPath "audit-$timestamp.html"

Write-AuditJsonLog -AuditResults $computerResults -Summary $scoreSummary -Path $jsonLogPath
Write-AuditCsvLog -Results $flatResults -Path $csvLogPath

if (-not $SkipHtmlReport) {
    Write-AuditHtmlReport -AuditResults $computerResults -Summary $scoreSummary -Path $htmlReportPath
}

Write-Host ""
Write-Host "Audit voltooid." -ForegroundColor Green
Write-Host "JSON log: $jsonLogPath"
Write-Host "CSV log : $csvLogPath"

if (-not $SkipHtmlReport) {
    Write-Host "HTML report: $htmlReportPath"
}

Write-Host ""
$scoreSummary | Format-Table -AutoSize | Out-Host

if ($PassThru) {
    [PSCustomObject]@{
        Timestamp      = $timestamp
        ComputerCount  = $computers.Count
        Checks         = $checks
        JsonLogPath    = $jsonLogPath
        CsvLogPath     = $csvLogPath
        HtmlReportPath = if ($SkipHtmlReport) { $null } else { $htmlReportPath }
        Summary        = $scoreSummary
        AuditResults   = $computerResults
    }
}
