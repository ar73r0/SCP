[CmdletBinding()]
param(
    [string]$VmName = "wscp-win11-test-01",
    [string]$IsoPath = "/home/aaronsengier/Downloads/Win11_25H2_EnglishInternational_x64_v2.iso",
    [string]$StoragePoolPath = "$HOME/.local/share/libvirt/images",
    [int]$DiskSizeGb = 64,
    [int]$MemoryMb = 8192,
    [int]$CpuCount = 4,
    [ValidateSet("e1000e", "virtio", "rtl8139")]
    [string]$NetworkModel = "e1000e",
    [ValidateSet("sata", "virtio")]
    [string]$DiskBus = "sata",
    [switch]$StartInstall
)

$ErrorActionPreference = "Stop"

function Test-Executable {
    param([Parameter(Mandatory)][string]$Name)
    [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Write-Step {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host ""
    Write-Host "== $Message ==" -ForegroundColor Cyan
}

Write-Host "Windows lab VM helper" -ForegroundColor Cyan
Write-Host "Datum: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

foreach ($command in "qemu-img", "virt-install") {
    if (-not (Test-Executable -Name $command)) {
        throw "$command is niet beschikbaar. Installeer libvirt/qemu tooling op de host."
    }
}

if (-not (Test-Path $IsoPath)) {
    throw "ISO niet gevonden: $IsoPath"
}

if (-not (Test-Path $StoragePoolPath)) {
    if ($StartInstall) {
        New-Item -ItemType Directory -Path $StoragePoolPath -Force | Out-Null
    }
}

$diskPath = Join-Path $StoragePoolPath "$VmName.qcow2"

if ($StartInstall -and -not (Test-Path $diskPath)) {
    Write-Step "Nieuwe qcow2 disk maken"
    & qemu-img create -f qcow2 $diskPath "${DiskSizeGb}G"
}
elseif (Test-Path $diskPath) {
    Write-Host "Disk bestaat al: $diskPath" -ForegroundColor Yellow
}
else {
    Write-Host "Dry run: qcow2 disk zou hier worden aangemaakt: $diskPath" -ForegroundColor Yellow
}

$virtInstallArgs = @(
    "--name", $VmName,
    "--memory", $MemoryMb,
    "--vcpus", $CpuCount,
    "--cpu", "host",
    "--disk", "path=$diskPath,format=qcow2,bus=$DiskBus",
    "--cdrom", $IsoPath,
    "--os-variant", "win11",
    "--network", "network=default,model=$NetworkModel",
    "--graphics", "spice",
    "--video", "qxl",
    "--channel", "spicevmc",
    "--sound", "ich9",
    "--boot", "uefi",
    "--tpm", "backend.type=emulator,backend.version=2.0,model=tpm-crb",
    "--noautoconsole"
)

Write-Step "virt-install commando"
$escaped = $virtInstallArgs | ForEach-Object {
    if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ }
}
Write-Host ("virt-install " + ($escaped -join " ")) -ForegroundColor Green

if ($StartInstall) {
    Write-Step "VM installatie starten"
    & virt-install @virtInstallArgs
    Write-Host "VM aangemaakt. Open virt-manager of GNOME Boxes om de installatie af te ronden." -ForegroundColor Green
}
else {
    Write-Host "Dry run voltooid. Gebruik -StartInstall om de VM effectief aan te maken." -ForegroundColor Yellow
}
