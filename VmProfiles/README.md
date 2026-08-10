# VM Demo Profiles

Deze scripts helpen om drie Windows-VM's snel om te zetten naar een bruikbare demo-opstelling voor de leerkracht.

## Gebruik

Open op elke VM een **PowerShell als administrator** en voer het juiste script uit vanuit de projectmap:

```powershell
Set-Location C:\Users\student\Documents\SCP
.\VmProfiles\Set-DemoBaseline.ps1
Restart-Computer
```

```powershell
Set-Location C:\Users\student\Documents\SCP
.\VmProfiles\Set-DemoRemoteAudit.ps1
Restart-Computer
```

```powershell
Set-Location C:\Users\student\Documents\SCP
.\VmProfiles\Set-DemoLowSpec.ps1
Restart-Computer
```

## Aanbevolen mapping

- `wscp-win11-baseline`: `Set-DemoBaseline.ps1`
- `wscp-win11-remote-audit`: `Set-DemoRemoteAudit.ps1`
- `wscp-win11-low-spec`: `Set-DemoLowSpec.ps1`

## Verwachte verschillen

- `baseline`: sterkste systeem, WinRM correct geconfigureerd, langere password policy
- `remote-audit`: bereikbaar via WinRM maar met extra administrators en zwakkere password policy
- `low-spec`: duidelijk onveiliger met firewall uit, Windows Update uit, guest account aan, extra admins, zwakke password policy

## Demo van meerdere systemen

Gebruik op de controller-VM (`baseline`) een gedeeld audit-account op alle machines:

- gebruiker: `auditdemo`
- wachtwoord: `AuditDemo!2026`

Start de audit op `baseline` met:

```powershell
$cred = Get-Credential .\auditdemo
.\Start-Audit.ps1 -Credential $cred
```

Als `Test-WSMan` na de eerste reboot nog faalt, voer het profielscript nog eens uit op de doel-VM en herstart daarna opnieuw. De scripts zetten nu de lab-NIC expliciet op `Private` en openen WinRM ook wanneer Windows die NIC eerst als `Public` zag.

## Snelle reparatie van WinRM

Als remote-audit of low-spec nog altijd `Access is denied` of `TrustedHosts`-problemen geven, gebruik dan dit herstelscript.

Op `remote-audit` en `low-spec`:

```powershell
Set-Location C:\Users\student\Documents\SCP
.\VmProfiles\Fix-LabRemoting.ps1 -Role Target
Restart-Computer
```

Op `baseline`:

```powershell
Set-Location C:\Users\student\Documents\SCP
.\VmProfiles\Fix-LabRemoting.ps1 -Role Controller
Restart-Computer
```

Daarna op `baseline`:

```powershell
$cred = Get-Credential
# username: auditdemo
# password: AuditDemo!2026
Test-WSMan 192.168.122.138
Test-WSMan 192.168.122.139
.\Start-Audit.ps1 -Credential $cred
```

Gebruik voor de labdemo liever `auditdemo` dan `student`, zodat alle target-VM's exact dezelfde remote account en hetzelfde wachtwoord hebben.
