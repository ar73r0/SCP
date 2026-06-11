# Windows Security Compliance Platform

Een modulair PowerShell-project voor het uitvoeren van security audits op Windows-systemen.

## Huidige status

Deze eerste versie bevat:

- een CLI-startscript;
- een basis-TUI entrypoint met nette fallback;
- 13 security checks;
- ondersteuning voor lokale en remote audits via PowerShell Remoting;
- compliance scoring;
- JSON, CSV en HTML rapportage;
- een eerste Pester testbestand.

## Structuur

```text
WindowsSecurityCompliancePlatform/
├── Start-Audit.ps1
├── Start-AuditTui.ps1
├── Config/
├── Modules/
├── Logs/
├── Reports/
└── Tests/
```

## Gebruik

```powershell
Set-Location C:\Pad\Naar\WindowsSecurityCompliancePlatform
.\Start-Audit.ps1
```

Of met eigen bestanden:

```powershell
.\Start-Audit.ps1 -ComputerListPath .\Config\computers.csv -ChecksConfigPath .\Config\checks.json
```

## Opmerking

De code is hier voorbereid, maar niet lokaal uitgevoerd in deze Linux-omgeving omdat `pwsh` hier niet beschikbaar is. Test daarom op een Windows-machine met PowerShell 7+.
