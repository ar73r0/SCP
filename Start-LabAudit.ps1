[CmdletBinding()]
param(
    [pscredential]$Credential,
    [ValidateRange(1, 64)]
    [int]$ThrottleLimit = 5,
    [switch]$DisableParallel,
    [switch]$SkipHtmlReport,
    [switch]$PassThru
)

$ErrorActionPreference = "Stop"

if (-not $Credential) {
    $password = ConvertTo-SecureString "AuditDemo!2026" -AsPlainText -Force
    $Credential = [pscredential]::new("auditdemo", $password)
}

$auditParameters = @{
    Credential               = $Credential
    Authentication           = "Basic"
    Port                     = 5986
    UseSSL                   = $true
    SkipCertificateCheck     = $true
    ThrottleLimit            = $ThrottleLimit
    DisableParallel          = $DisableParallel
    SkipHtmlReport           = $SkipHtmlReport
    PassThru                 = $PassThru
}

& (Join-Path $PSScriptRoot "Start-Audit.ps1") @auditParameters
