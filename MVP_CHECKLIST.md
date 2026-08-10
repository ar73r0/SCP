# MVP Checklist

Dit document koppelt elke MVP-eis aan concrete code en een reproduceerbare validatie.

## Securitycontroles

Alle 13 controles staan in `Modules/SecurityChecks.psm1` en worden geselecteerd via `Config/checks.json`:

`Firewall`, `Defender`, `SMBv1`, `UAC`, `GuestAccount`, `LocalAdministrators`, `PasswordPolicy`, `BitLocker`, `WindowsUpdates`, `CriticalServices`, `OpenPorts`, `SystemInfo` en `DiskSpace`.

## Functionaliteiten

| MVP-eis | Implementatie |
|---|---|
| CLI-interface | `Start-Audit.ps1` |
| TUI via PwshSpectreConsole | `Start-AuditTui.ps1` en `Modules/TUI.psm1` |
| Meerdere computers via CSV | `Config/computers.csv` en `Import-Csv` in `Start-Audit.ps1` |
| Remote auditing | `Modules/RemoteAudit.psm1` |
| Parallelle uitvoering | `ForEach-Object -Parallel` met `ThrottleLimit` in `Start-Audit.ps1` |
| JSON-configuratie | `Config/checks.json` |
| Live feedback | Statusmeldingen per computer via `Write-Host` |
| JSON-logging | `Write-AuditJsonLog` |
| CSV-logging | `Write-AuditCsvLog` |
| Compliance score | `Get-ComplianceSummary` in `Modules/Scoring.psm1` |
| HTML-rapport | `Write-AuditHtmlReport` in `Modules/Reporting.psm1` |
| Foutafhandeling | `try/catch` rond bereikbaarheid, remote uitvoering en controles |
| Pester-tests | `Tests/SecurityAudit.Tests.ps1` |

## Technologieen

| Technologie | Bewijs in het project |
|---|---|
| PowerShell | Alle uitvoerbare scripts en modules zijn PowerShell |
| CIM | `Get-CimInstance` voor updates, systeeminformatie en schijfruimte |
| Get-NetFirewallProfile | Firewallcontrole in `Modules/SecurityChecks.psm1` |
| JSON | Checkconfiguratie en auditlog |
| HTML | Zelfstandig HTML-compliancerapport |
| PowerShell Remoting | `Invoke-Command` in `Modules/RemoteAudit.psm1` |
| Test-WSMan | Standaard bereikbaarheidscontrole met PSSession-fallback voor zelfondertekende labcertificaten |
| ForEach-Object -Parallel | Parallelle verwerking onder PowerShell 7 |
| PwshSpectreConsole | Interactieve TUI met basisfallback |
| Pester | Geautomatiseerde tests met minimaal Pester 5 |

## Validatie

Voer op de baseline-VM uit vanuit de projectmap:

```powershell
pwsh -File .\Setup-Project.ps1 -All
pwsh -File .\Start-Audit.ps1
pwsh -File .\Start-AuditTui.ps1
pwsh -Command "Invoke-Pester -Path .\Tests -Output Detailed"
```

Een geslaagde MVP-demo toont drie systemen in het HTML-rapport, verschillende compliancescores en nul onbereikbare systemen.
