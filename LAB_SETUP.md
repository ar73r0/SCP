# Windows Lab Setup

Dit bestand beschrijft hoe je snel een Windows testomgeving kan voorbereiden om het project in een realistische situatie te valideren.

## Doel

Het doel van deze testopstelling is om aan te tonen dat:

- de audit lokaal werkt op Windows;
- remote auditing via WinRM werkt;
- rapporten verschillen naargelang de configuratie van de doelmachine;
- de compliance score bruikbaar is in de praktijk.

## Vereisten

- `virt-install`
- `qemu-img`
- een Windows ISO
- een actief `default` libvirt netwerk

De helper gebruikt standaard een `e1000e` netwerkkaart en `sata` diskbus zodat Windows direct drivers heeft tijdens installatie. Voor performance-tests kan je later nog bewust `virtio` kiezen.

## VM voorbereiden

Controleer eerst het gegenereerde commando:

```powershell
pwsh ./New-WindowsLabVm.ps1
```

Maak daarna effectief een VM aan:

```powershell
pwsh ./New-WindowsLabVm.ps1 -VmName wscp-win11-audit-01 -StartInstall
```

Expliciet toch met VirtIO testen:

```powershell
pwsh ./New-WindowsLabVm.ps1 -VmName wscp-win11-virtio-01 -NetworkModel virtio -DiskBus virtio -StartInstall
```

## Aanbevolen testopstelling

Gebruik bij voorkeur twee Windows-VM's:

- een basis-VM met een normale configuratie;
- een tweede VM waarop je bewust enkele afwijkingen aanbrengt.

Voorbeelden van bruikbare afwijkingen:

- extra lokale administratoraccounts;
- BitLocker uitgeschakeld;
- zwakkere password policy;
- extra open luisterende poorten.

Met zo'n opstelling kan je de meerwaarde van de audit duidelijk aantonen in je rapportering.

## Validatie in Windows

1. Installeer PowerShell 7 op de Windows-VM.
2. Kopieer deze projectmap naar de VM.
3. Voer `.\Setup-Project.ps1 -All` uit.
4. Schakel remoting in met `Enable-PSRemoting -Force`.
5. Vul `Config/computers.csv` aan met de te testen computers.
6. Start `.\Start-Audit.ps1`.
7. Bewaar de gegenereerde JSON-, CSV- en HTML-bestanden.

## Aanbevolen bewijs voor de eindindiening

- een screenshot van een geslaagde audit op Windows;
- een screenshot van de TUI;
- een HTML-rapport met zichtbare warnings of failures;
- een korte toelichting van de testomgeving.
