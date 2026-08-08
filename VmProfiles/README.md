# VM Demo Profiles

Deze scripts helpen om drie Windows-VM's snel om te zetten naar een bruikbare demo-opstelling voor de leerkracht.

## Gebruik

Open op elke VM een **PowerShell als administrator** en voer het juiste script uit vanuit de projectmap:

```powershell
Set-Location C:\Users\student\Documents\SCP
.\VmProfiles\Set-DemoBaseline.ps1
```

```powershell
Set-Location C:\Users\student\Documents\SCP
.\VmProfiles\Set-DemoRemoteAudit.ps1
```

```powershell
Set-Location C:\Users\student\Documents\SCP
.\VmProfiles\Set-DemoLowSpec.ps1
```

## Aanbevolen mapping

- `wscp-win11-baseline`: `Set-DemoBaseline.ps1`
- `wscp-win11-remote-audit`: `Set-DemoRemoteAudit.ps1`
- `wscp-win11-low-spec`: `Set-DemoLowSpec.ps1`

## Verwachte verschillen

- `baseline`: grotendeels compliant
- `remote-audit`: extra lokale administrator + zwakkere password policy
- `low-spec`: firewall uit, WinRM uit, Windows Update uit, zwakke password policy
