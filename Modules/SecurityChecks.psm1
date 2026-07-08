function New-CheckResult {
    param(
        [string]$ComputerName,
        [string]$Name,
        [ValidateSet("Passed", "Warning", "Failed", "Skipped")]
        [string]$Status,
        [string]$Message
    )

    [PSCustomObject]@{
        ComputerName = $ComputerName
        Name         = $Name
        Status       = $Status
        Message      = $Message
    }
}

function Get-SecurityCheckCatalog {
    [PSCustomObject]@{
        Firewall = [PSCustomObject]@{
            Function       = "Test-FirewallStatus"
            Severity       = "High"
            Recommendation = "Schakel alle Windows Firewall-profielen in en controleer groepsbeleid of lokale overrides."
        }
        Defender = [PSCustomObject]@{
            Function       = "Test-DefenderStatus"
            Severity       = "High"
            Recommendation = "Zorg dat Microsoft Defender actief is, realtime bescherming aanstaat en signatures recent zijn."
        }
        SMBv1 = [PSCustomObject]@{
            Function       = "Test-SMBv1Status"
            Severity       = "High"
            Recommendation = "Schakel SMBv1 uit tenzij een legacy afhankelijkheid dit tijdelijk vereist."
        }
        UAC = [PSCustomObject]@{
            Function       = "Test-UacStatus"
            Severity       = "High"
            Recommendation = "Schakel User Account Control opnieuw in om privilege escalation te beperken."
        }
        GuestAccount = [PSCustomObject]@{
            Function       = "Test-GuestAccountStatus"
            Severity       = "Medium"
            Recommendation = "Schakel het ingebouwde gastaccount uit om ongecontroleerde toegang te vermijden."
        }
        LocalAdministrators = [PSCustomObject]@{
            Function       = "Test-LocalAdministratorsStatus"
            Severity       = "Medium"
            Recommendation = "Beperk lokale administrators tot strikt noodzakelijke accounts en review groepslidmaatschap."
        }
        PasswordPolicy = [PSCustomObject]@{
            Function       = "Test-PasswordPolicyStatus"
            Severity       = "High"
            Recommendation = "Verhoog de minimale wachtwoordlengte en stem het beleid af op de organisatievereisten."
        }
        BitLocker = [PSCustomObject]@{
            Function       = "Test-BitLockerStatus"
            Severity       = "High"
            Recommendation = "Activeer BitLocker op systeemschijven en controleer of herstelmethodes veilig zijn opgeslagen."
        }
        WindowsUpdates = [PSCustomObject]@{
            Function       = "Test-WindowsUpdatesStatus"
            Severity       = "High"
            Recommendation = "Installeer recente beveiligingsupdates en controleer het updatebeleid op het systeem."
        }
        CriticalServices = [PSCustomObject]@{
            Function       = "Test-CriticalServicesStatus"
            Severity       = "High"
            Recommendation = "Controleer waarom kritieke beveiligings- of beheerservices niet actief zijn en herstel de configuratie."
        }
        OpenPorts = [PSCustomObject]@{
            Function       = "Test-OpenPortsStatus"
            Severity       = "Medium"
            Recommendation = "Beperk luisterende poorten tot noodzakelijke services en verifieer de bijhorende firewallregels."
        }
        SystemInfo = [PSCustomObject]@{
            Function       = "Test-SystemInfoStatus"
            Severity       = "Info"
            Recommendation = "Gebruik deze systeeminformatie om bevindingen te contextualiseren en te documenteren."
        }
        DiskSpace = [PSCustomObject]@{
            Function       = "Test-DiskSpaceStatus"
            Severity       = "Medium"
            Recommendation = "Maak vrije ruimte vrij of vergroot de systeemschijf om update- en logproblemen te voorkomen."
        }
    }
}

function Get-AvailableSecurityChecks {
    $catalog = Get-SecurityCheckCatalog
    @($catalog.PSObject.Properties.Name) | Sort-Object
}

function Resolve-CheckMetadata {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $catalog = Get-SecurityCheckCatalog
    if ($catalog.PSObject.Properties.Name -contains $Name) {
        return $catalog.$Name
    }

    $null
}

function Test-CheckConfiguration {
    param(
        [Parameter(Mandatory)]
        [string[]]$Checks
    )

    $knownChecks = Get-AvailableSecurityChecks
    $unknownChecks = @($Checks | Where-Object { $knownChecks -notcontains $_ } | Select-Object -Unique)

    [PSCustomObject]@{
        IsValid       = ($unknownChecks.Count -eq 0)
        KnownChecks   = $knownChecks
        UnknownChecks = $unknownChecks
    }
}

function Test-FirewallStatus {
    param([string]$ComputerName)

    try {
        $profiles = Get-NetFirewallProfile -ErrorAction Stop
        $disabled = @($profiles | Where-Object { -not $_.Enabled })

        if ($disabled.Count -eq 0) {
            return New-CheckResult -ComputerName $ComputerName -Name "Firewall" -Status "Passed" -Message "Alle firewallprofielen zijn ingeschakeld."
        }

        $names = $disabled.Name -join ", "
        return New-CheckResult -ComputerName $ComputerName -Name "Firewall" -Status "Failed" -Message "Uitgeschakelde firewallprofielen: $names"
    }
    catch {
        New-CheckResult -ComputerName $ComputerName -Name "Firewall" -Status "Failed" -Message $_.Exception.Message
    }
}

function Test-DefenderStatus {
    param([string]$ComputerName)

    try {
        $status = Get-MpComputerStatus -ErrorAction Stop
        if ($status.RealTimeProtectionEnabled -and $status.AntivirusSignatureAge -le 7) {
            return New-CheckResult -ComputerName $ComputerName -Name "Defender" -Status "Passed" -Message "Microsoft Defender realtime bescherming is actief."
        }

        $message = "Defender status: Realtime=$($status.RealTimeProtectionEnabled), SignatureAge=$($status.AntivirusSignatureAge)"
        return New-CheckResult -ComputerName $ComputerName -Name "Defender" -Status "Warning" -Message $message
    }
    catch {
        New-CheckResult -ComputerName $ComputerName -Name "Defender" -Status "Failed" -Message $_.Exception.Message
    }
}

function Test-SMBv1Status {
    param([string]$ComputerName)

    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction Stop
        if ($feature.State -eq "Disabled") {
            return New-CheckResult -ComputerName $ComputerName -Name "SMBv1" -Status "Passed" -Message "SMBv1 is uitgeschakeld."
        }

        return New-CheckResult -ComputerName $ComputerName -Name "SMBv1" -Status "Failed" -Message "SMBv1 staat nog ingeschakeld."
    }
    catch {
        New-CheckResult -ComputerName $ComputerName -Name "SMBv1" -Status "Skipped" -Message "SMBv1 kon niet gecontroleerd worden: $($_.Exception.Message)"
    }
}

function Test-UacStatus {
    param([string]$ComputerName)

    try {
        $value = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -ErrorAction Stop
        if ($value -eq 1) {
            return New-CheckResult -ComputerName $ComputerName -Name "UAC" -Status "Passed" -Message "UAC is ingeschakeld."
        }

        return New-CheckResult -ComputerName $ComputerName -Name "UAC" -Status "Failed" -Message "UAC is uitgeschakeld."
    }
    catch {
        New-CheckResult -ComputerName $ComputerName -Name "UAC" -Status "Failed" -Message $_.Exception.Message
    }
}

function Test-GuestAccountStatus {
    param([string]$ComputerName)

    try {
        $guest = Get-LocalUser -Name "Guest" -ErrorAction Stop
        if (-not $guest.Enabled) {
            return New-CheckResult -ComputerName $ComputerName -Name "GuestAccount" -Status "Passed" -Message "Gastaccount is uitgeschakeld."
        }

        return New-CheckResult -ComputerName $ComputerName -Name "GuestAccount" -Status "Failed" -Message "Gastaccount is ingeschakeld."
    }
    catch {
        New-CheckResult -ComputerName $ComputerName -Name "GuestAccount" -Status "Skipped" -Message "Guest-account niet beschikbaar of niet leesbaar: $($_.Exception.Message)"
    }
}

function Test-LocalAdministratorsStatus {
    param([string]$ComputerName)

    try {
        $admins = @(Get-LocalGroupMember -Group "Administrators" -ErrorAction Stop)
        $count = $admins.Count

        if ($count -le 2) {
            return New-CheckResult -ComputerName $ComputerName -Name "LocalAdministrators" -Status "Passed" -Message "Beperkt aantal lokale administrators: $count"
        }

        $names = ($admins.Name | Select-Object -First 6) -join ", "
        return New-CheckResult -ComputerName $ComputerName -Name "LocalAdministrators" -Status "Warning" -Message "Veel lokale administrators ($count): $names"
    }
    catch {
        New-CheckResult -ComputerName $ComputerName -Name "LocalAdministrators" -Status "Skipped" -Message $_.Exception.Message
    }
}

function Test-PasswordPolicyStatus {
    param([string]$ComputerName)

    try {
        $lines = net accounts
        $minLengthLine = $lines | Where-Object { $_ -match "Minimum password length|Minimale wachtwoordlengte" } | Select-Object -First 1

        if (-not $minLengthLine) {
            return New-CheckResult -ComputerName $ComputerName -Name "PasswordPolicy" -Status "Skipped" -Message "Kon minimum password length niet bepalen."
        }

        $length = [int]([regex]::Match($minLengthLine, "\d+").Value)
        if ($length -ge 12) {
            return New-CheckResult -ComputerName $ComputerName -Name "PasswordPolicy" -Status "Passed" -Message "Minimum wachtwoordlengte is $length."
        }

        return New-CheckResult -ComputerName $ComputerName -Name "PasswordPolicy" -Status "Warning" -Message "Minimum wachtwoordlengte is $length. Aanbevolen: 12 of hoger."
    }
    catch {
        New-CheckResult -ComputerName $ComputerName -Name "PasswordPolicy" -Status "Skipped" -Message $_.Exception.Message
    }
}

function Test-BitLockerStatus {
    param([string]$ComputerName)

    try {
        $drive = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
        if ($drive.ProtectionStatus -eq "On") {
            return New-CheckResult -ComputerName $ComputerName -Name "BitLocker" -Status "Passed" -Message "BitLocker bescherming is actief op $($drive.MountPoint)."
        }

        return New-CheckResult -ComputerName $ComputerName -Name "BitLocker" -Status "Warning" -Message "BitLocker is niet actief op $($drive.MountPoint)."
    }
    catch {
        New-CheckResult -ComputerName $ComputerName -Name "BitLocker" -Status "Skipped" -Message $_.Exception.Message
    }
}

function Test-WindowsUpdatesStatus {
    param([string]$ComputerName)

    try {
        $recent = Get-CimInstance -ClassName Win32_QuickFixEngineering -ErrorAction Stop | Where-Object {
            $_.InstalledOn -and ([datetime]$_.InstalledOn) -ge (Get-Date).AddDays(-30)
        }

        if (@($recent).Count -gt 0) {
            return New-CheckResult -ComputerName $ComputerName -Name "WindowsUpdates" -Status "Passed" -Message "Recente updates gevonden in de laatste 30 dagen."
        }

        return New-CheckResult -ComputerName $ComputerName -Name "WindowsUpdates" -Status "Warning" -Message "Geen recente updates gevonden in de laatste 30 dagen."
    }
    catch {
        New-CheckResult -ComputerName $ComputerName -Name "WindowsUpdates" -Status "Skipped" -Message $_.Exception.Message
    }
}

function Test-CriticalServicesStatus {
    param([string]$ComputerName)

    try {
        $requiredServices = "MpsSvc", "WinDefend", "wuauserv", "WinRM"
        $services = Get-Service -Name $requiredServices -ErrorAction Stop
        $notRunning = @($services | Where-Object { $_.Status -ne "Running" })

        if ($notRunning.Count -eq 0) {
            return New-CheckResult -ComputerName $ComputerName -Name "CriticalServices" -Status "Passed" -Message "Alle kritieke services draaien."
        }

        $names = $notRunning.Name -join ", "
        return New-CheckResult -ComputerName $ComputerName -Name "CriticalServices" -Status "Failed" -Message "Niet draaiende kritieke services: $names"
    }
    catch {
        New-CheckResult -ComputerName $ComputerName -Name "CriticalServices" -Status "Skipped" -Message $_.Exception.Message
    }
}

function Test-OpenPortsStatus {
    param([string]$ComputerName)

    try {
        $ports = @(Get-NetTCPConnection -State Listen -ErrorAction Stop | Sort-Object -Property LocalPort -Unique)
        $count = $ports.Count

        if ($count -le 20) {
            return New-CheckResult -ComputerName $ComputerName -Name "OpenPorts" -Status "Passed" -Message "Beperkt aantal luisterende TCP-poorten: $count"
        }

        $sample = ($ports.LocalPort | Select-Object -First 10) -join ", "
        return New-CheckResult -ComputerName $ComputerName -Name "OpenPorts" -Status "Warning" -Message "Veel luisterende poorten ($count). Voorbeeld: $sample"
    }
    catch {
        New-CheckResult -ComputerName $ComputerName -Name "OpenPorts" -Status "Skipped" -Message $_.Exception.Message
    }
}

function Test-SystemInfoStatus {
    param([string]$ComputerName)

    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $message = "{0} build {1}, laatste boot {2}" -f $os.Caption, $os.BuildNumber, $os.LastBootUpTime
        New-CheckResult -ComputerName $ComputerName -Name "SystemInfo" -Status "Passed" -Message $message
    }
    catch {
        New-CheckResult -ComputerName $ComputerName -Name "SystemInfo" -Status "Skipped" -Message $_.Exception.Message
    }
}

function Test-DiskSpaceStatus {
    param([string]$ComputerName)

    try {
        $systemDrive = $env:SystemDrive.TrimEnd(":")
        $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'" -ErrorAction Stop
        $freePercent = [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 2)

        if ($freePercent -ge 15) {
            return New-CheckResult -ComputerName $ComputerName -Name "DiskSpace" -Status "Passed" -Message "Vrije ruimte op $systemDrive`: $freePercent%"
        }

        return New-CheckResult -ComputerName $ComputerName -Name "DiskSpace" -Status "Warning" -Message "Lage vrije ruimte op $systemDrive`: $freePercent%"
    }
    catch {
        New-CheckResult -ComputerName $ComputerName -Name "DiskSpace" -Status "Skipped" -Message $_.Exception.Message
    }
}

function Invoke-SelectedChecks {
    param(
        [string]$ComputerName,
        [string[]]$Checks
    )

    foreach ($check in $Checks) {
        $metadata = Resolve-CheckMetadata -Name $check
        if ($null -ne $metadata) {
            & $metadata.Function -ComputerName $ComputerName
            continue
        }

        New-CheckResult -ComputerName $ComputerName -Name $check -Status "Skipped" -Message "Onbekende check."
    }
}

Export-ModuleMember -Function *-*, New-CheckResult
