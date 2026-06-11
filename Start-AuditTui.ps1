$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "Modules/TUI.psm1") -Force
Start-SecurityAuditTui -ProjectRoot $PSScriptRoot
