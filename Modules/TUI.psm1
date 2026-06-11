function Start-SecurityAuditTui {
    param(
        [string]$ProjectRoot
    )

    $module = Get-Module -ListAvailable -Name PwshSpectreConsole | Select-Object -First 1
    if (-not $module) {
        throw "PwshSpectreConsole is niet geïnstalleerd. Installeer het eerst of gebruik Start-Audit.ps1 voor de CLI-versie."
    }

    Import-Module PwshSpectreConsole -ErrorAction Stop

    Write-Host "TUI basis geladen. Verdere schermopbouw is de volgende logische stap." -ForegroundColor Cyan
    Write-Host "Project root: $ProjectRoot"
    Write-Host "Start voorlopig de audit via .\\Start-Audit.ps1"
}

Export-ModuleMember -Function Start-SecurityAuditTui
