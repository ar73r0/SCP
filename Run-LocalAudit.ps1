[CmdletBinding()]
param(
    [string]$ChecksConfigPath = (Join-Path $PSScriptRoot "Config/checks.json"),
    [string]$OutputRoot = $PSScriptRoot,
    [switch]$SkipHtmlReport
)

$ErrorActionPreference = "Stop"

$tempConfigDir = Join-Path $env:TEMP "wscp-local-audit"
$tempComputerListPath = Join-Path $tempConfigDir "computers.csv"

New-Item -ItemType Directory -Path $tempConfigDir -Force | Out-Null
"ComputerName`n$env:COMPUTERNAME" | Set-Content -Path $tempComputerListPath -Encoding UTF8

$startAuditParams = @{
    ComputerListPath = $tempComputerListPath
    ChecksConfigPath = $ChecksConfigPath
    OutputRoot       = $OutputRoot
    DisableParallel  = $true
}

if ($SkipHtmlReport) {
    $startAuditParams.SkipHtmlReport = $true
}

& (Join-Path $PSScriptRoot "Start-Audit.ps1") @startAuditParams
