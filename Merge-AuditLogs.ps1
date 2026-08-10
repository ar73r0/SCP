[CmdletBinding()]
param(
    [string[]]$JsonLogPaths,
    [string]$SearchRoot = $PSScriptRoot,
    [string]$OutputRoot = $PSScriptRoot
)

$ErrorActionPreference = "Stop"

$moduleRoot = Join-Path $PSScriptRoot "Modules"
Import-Module (Join-Path $moduleRoot "Scoring.psm1") -Force
Import-Module (Join-Path $moduleRoot "Reporting.psm1") -Force

if (-not $JsonLogPaths -or $JsonLogPaths.Count -eq 0) {
    $JsonLogPaths = Get-ChildItem -Path (Join-Path $SearchRoot "Logs") -Filter "audit-*.json" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -ExpandProperty FullName -First 10
}

if (-not $JsonLogPaths -or $JsonLogPaths.Count -eq 0) {
    throw "Geen JSON auditlogs gevonden."
}

$systemsByName = [ordered]@{}

foreach ($path in $JsonLogPaths) {
    if (-not (Test-Path $path)) {
        continue
    }

    $payload = Get-Content -Path $path -Raw | ConvertFrom-Json
    foreach ($system in @($payload.Systems)) {
        if ($null -eq $system -or [string]::IsNullOrWhiteSpace($system.ComputerName)) {
            continue
        }

        $systemsByName[$system.ComputerName] = [PSCustomObject]@{
            ComputerName = $system.ComputerName
            Reachable    = [bool]$system.Reachable
            IsLocal      = [bool]$system.IsLocal
            Error        = $system.Error
            Results      = @($system.Results)
        }
    }
}

$auditResults = @($systemsByName.Values)
if (-not $auditResults.Count) {
    throw "Geen systeemresultaten gevonden in de opgegeven logs."
}

$flatResults = foreach ($entry in $auditResults) {
    foreach ($result in @($entry.Results)) {
        $result
    }
}

$summary = Get-ComplianceSummary -Results $flatResults

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logsPath = Join-Path $OutputRoot "Logs"
$reportsPath = Join-Path $OutputRoot "Reports"

New-Item -ItemType Directory -Path $logsPath -Force | Out-Null
New-Item -ItemType Directory -Path $reportsPath -Force | Out-Null

$jsonLogPath = Join-Path $logsPath "merged-audit-$timestamp.json"
$csvLogPath = Join-Path $logsPath "merged-audit-$timestamp.csv"
$htmlReportPath = Join-Path $reportsPath "merged-audit-$timestamp.html"

Write-AuditJsonLog -AuditResults $auditResults -Summary $summary -Path $jsonLogPath
Write-AuditCsvLog -Results $flatResults -Path $csvLogPath
Write-AuditHtmlReport -AuditResults $auditResults -Summary $summary -Path $htmlReportPath

Write-Host ""
Write-Host "Merged audit voltooid." -ForegroundColor Green
Write-Host "JSON log: $jsonLogPath"
Write-Host "CSV log : $csvLogPath"
Write-Host "HTML report: $htmlReportPath"
Write-Host ""
$summary | Format-Table -AutoSize | Out-Host
