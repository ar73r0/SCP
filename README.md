# Windows Security Compliance Platform

PowerShell-project voor het uitvoeren van security audits op Windows-systemen.

## Overzicht

Deze tool controleert één of meerdere Windows-computers op basis van een lijst in CSV-formaat. De resultaten worden verwerkt tot een compliance score en opgeslagen als JSON, CSV en HTML.

De toepassing bevat:

- een CLI-startscript voor standaard- en labaudits via `Start-Audit.ps1`;
- een TUI-startscript via `Start-AuditTui.ps1`;
- 13 ingebouwde security checks;
- ondersteuning voor lokale en remote audits;
- parallelle verwerking van meerdere computers;
- configuratie via JSON;
- rapportage in JSON, CSV en HTML;
- Pester-tests voor de belangrijkste onderdelen.

De volledige koppeling tussen de opdrachtvereisten en de implementatie staat in [`MVP_CHECKLIST.md`](MVP_CHECKLIST.md).

## Projectstructuur

```text
WindowsSecurityCompliancePlatform/
├── Start-Audit.ps1
├── Start-AuditTui.ps1
├── Setup-Project.ps1
├── Config/
├── Modules/
├── VmSetup/
├── Logs/
├── Reports/
└── Tests/
```

## Gebruik

Start de audit met de standaardconfiguratie:

```powershell
.\Start-Audit.ps1
```

Start de drie vooraf geconfigureerde lab-VM's via WinRM HTTPS:

```powershell
.\Start-Audit.ps1 -Lab
```

Dit gebruikt het gedeelde lokale account `auditdemo` via Basic-authenticatie binnen een versleutelde HTTPS-verbinding op poort `5986`. De zelfondertekende labcertificaten worden bewust zonder CA-validatie gebruikt.

Gebruik eigen configuratiebestanden:

```powershell
.\Start-Audit.ps1 -ComputerListPath .\Config\computers.csv -ChecksConfigPath .\Config\checks.json
```

Voer de audit sequentieel uit:

```powershell
.\Start-Audit.ps1 -DisableParallel
```

Start de TUI:

```powershell
.\Start-AuditTui.ps1
```

De TUI gebruikt automatisch de werkende labverbinding via WinRM HTTPS op poort `5986`. Voor afwijkende remotinginstellingen gebruik je de parameters van `Start-Audit.ps1`.

## Setup op Windows

Installeer de aanbevolen modules en profielinstellingen:

```powershell
.\Setup-Project.ps1 -All
```

Of installeer alleen de nodige onderdelen:

```powershell
.\Setup-Project.ps1 -InstallPester -InstallPwshSpectreConsole -ConfigureUtf8Profile
```

De setup vereist minimaal Pester 5, zodat de tests niet per ongeluk met de ingebouwde verouderde Pester 3.4 worden uitgevoerd.

## Windows testlab op Linux-host

Voor een Linux-host met `libvirt` is een extra helper voorzien:

```powershell
pwsh ./VmSetup/New-WindowsLabVm.ps1
```

Een effectieve VM-aanmaak start je met:

```powershell
pwsh ./VmSetup/New-WindowsLabVm.ps1 -VmName wscp-win11-audit-01 -StartInstall
```

Meer uitleg staat in `VmSetup/LAB_SETUP.md`.

## Belangrijke opmerking

De security checks zelf zijn bedoeld voor Windows. In deze repository kunnen de tests ook buiten Windows uitgevoerd worden, maar een echte audit moet op een Windows-machine gevalideerd worden.

Wanneer de tool op een niet-Windows host gestart wordt, worden Windows-specifieke controles bewust als `Skipped` weergegeven.
