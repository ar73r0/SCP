# Windows Security Compliance Platform

Een modulair PowerShell-project voor het uitvoeren van security audits op Windows-systemen.

## Huidige status

Deze versie bevat:

- een CLI-startscript;
- een werkende TUI-entrypoint via `PwshSpectreConsole`;
- 13 security checks;
- ondersteuning voor lokale en remote audits via PowerShell Remoting;
- compliance scoring;
- JSON, CSV en HTML rapportage;
- aanbevelingen en prioriteiten in het HTML-rapport;
- Pester tests voor structuur, scoring, validatie, rapportage en TUI-helpers.

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

Als parallelle uitvoering tijdens een demo te weinig feedback geeft, kan je sequentieel draaien:

```powershell
.\Start-Audit.ps1 -DisableParallel
```

TUI starten:

```powershell
.\Start-AuditTui.ps1
```

Snelle setup op een Windows-VM:

```powershell
.\Setup-Project.ps1 -All
```

Of alleen de optionele TUI- en testmodules:

```powershell
.\Setup-Project.ps1 -InstallPester -InstallPwshSpectreConsole -ConfigureUtf8Profile
```

## Opmerking

De security checks zelf blijven gericht op Windows-systemen. In deze Linux-omgeving is PowerShell 7 lokaal toegevoegd om de Pester tests uit te voeren, maar de echte auditresultaten moeten nog steeds op een Windows-machine gevalideerd worden.
