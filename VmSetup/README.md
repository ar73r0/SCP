# VM Demo Profiles

Deze scripts helpen om drie Windows-VM's snel om te zetten naar een bruikbare demo-opstelling voor de leerkracht.

## Gebruik

Open op elke VM een **PowerShell als administrator** en voer het juiste script uit vanuit de projectmap:

```powershell
Set-Location C:\Users\student\Documents\SCP
.\VmSetup\Set-DemoBaseline.ps1
Restart-Computer
```

```powershell
Set-Location C:\Users\student\Documents\SCP
.\VmSetup\Set-DemoRemoteAudit.ps1
Restart-Computer
```

```powershell
Set-Location C:\Users\student\Documents\SCP
.\VmSetup\Set-DemoLowSpec.ps1
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
.\Start-Audit.ps1 -Lab
```

Als `Test-WSMan` na de eerste reboot nog faalt, voer het profielscript nog eens uit op de doel-VM en herstart daarna opnieuw. De scripts zetten nu de lab-NIC expliciet op `Private` en openen WinRM ook wanneer Windows die NIC eerst als `Public` zag.

## Snelle reparatie van WinRM

Als remote-audit of low-spec nog altijd `Access is denied` of `TrustedHosts`-problemen geven, gebruik dan dit herstelscript.

Op `remote-audit` en `low-spec`:

```powershell
Set-Location C:\Users\student\Documents\SCP
.\VmSetup\Fix-LabRemoting.ps1 -Role Target
Restart-Computer
```

Op `baseline`:

```powershell
Set-Location C:\Users\student\Documents\SCP
.\VmSetup\Fix-LabRemoting.ps1 -Role Controller
Restart-Computer
```

Daarna op `baseline`:

```powershell
Test-NetConnection 192.168.122.138 -Port 5986
Test-NetConnection 192.168.122.139 -Port 5986
.\Start-Audit.ps1 -Lab
```

Gebruik voor de labdemo het ongekwalificeerde account `auditdemo`. De VM's zijn zonder Sysprep gekloond en hebben daardoor dezelfde machine-SID. Recente Windows 11-versies blokkeren NTLM tussen zulke klonen. De `-Lab`-preset omzeilt dat specifieke cloneprobleem met Basic-authenticatie binnen WinRM HTTPS; wachtwoorden gaan dus niet onversleuteld over het netwerk.

## Fallback zonder remote WinRM

Als remote auditing blijft blokkeren op `Access is denied`, gebruik dan deze demo-veilige fallback:

Op elke VM afzonderlijk:

```powershell
Set-Location C:\Users\student\Documents\SCP
.\Run-LocalAudit.ps1
```

Kopieer daarna de drie JSON logs uit `C:\Users\student\Documents\SCP\Logs\` naar `baseline` en merge ze daar:

```powershell
Set-Location C:\Users\student\Documents\SCP
.\Merge-AuditLogs.ps1
```

De gecombineerde HTML komt in `C:\Users\student\Documents\SCP\Reports\`.
