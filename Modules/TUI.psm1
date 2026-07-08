function Import-TuiDependencies {
    $securityChecksModule = Join-Path $PSScriptRoot "SecurityChecks.psm1"
    if (-not (Get-Command Get-AvailableSecurityChecks -ErrorAction SilentlyContinue)) {
        Import-Module $securityChecksModule -Force
    }
}

function Test-SpectreAvailability {
    [bool](Get-Module -ListAvailable -Name PwshSpectreConsole | Select-Object -First 1)
}

function Get-TuiAuditDefaults {
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot
    )

    Import-TuiDependencies

    $checksConfigPath = Join-Path $ProjectRoot "Config/checks.json"
    $computerListPath = Join-Path $ProjectRoot "Config/computers.csv"

    $defaultChecks = @()
    if (Test-Path $checksConfigPath) {
        $config = Get-Content $checksConfigPath -Raw | ConvertFrom-Json
        $defaultChecks = @($config.checks | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    }

    $defaultComputers = @()
    if (Test-Path $computerListPath) {
        $defaultComputers = @(
            Import-Csv $computerListPath | ForEach-Object { $_.ComputerName } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Select-Object -Unique
        )
    }

    [PSCustomObject]@{
        ProjectRoot      = $ProjectRoot
        ChecksConfigPath = $checksConfigPath
        ComputerListPath = $computerListPath
        OutputRoot       = $ProjectRoot
        AvailableChecks  = @(Get-AvailableSecurityChecks)
        DefaultChecks    = $defaultChecks
        DefaultComputers = $defaultComputers
    }
}

function New-TuiAuditSessionFiles {
    param(
        [Parameter(Mandatory)]
        [string[]]$ComputerNames,

        [Parameter(Mandatory)]
        [string[]]$Checks,

        [Parameter(Mandatory)]
        [string]$OutputRoot
    )

    $selectedComputers = @($ComputerNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    $selectedChecks = @($Checks | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)

    if (-not $selectedComputers.Count) {
        throw "Selecteer minstens één computer voor de audit."
    }

    if (-not $selectedChecks.Count) {
        throw "Selecteer minstens één check voor de audit."
    }

    $sessionRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("wscp-tui-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $sessionRoot -Force | Out-Null

    $checksConfigPath = Join-Path $sessionRoot "checks.json"
    $computerListPath = Join-Path $sessionRoot "computers.csv"

    @{
        checks = $selectedChecks
    } | ConvertTo-Json -Depth 3 | Set-Content -Path $checksConfigPath -Encoding UTF8

    $selectedComputers |
        ForEach-Object { [PSCustomObject]@{ ComputerName = $_ } } |
        Export-Csv -Path $computerListPath -NoTypeInformation -Encoding UTF8

    [PSCustomObject]@{
        SessionRoot      = $sessionRoot
        ChecksConfigPath = $checksConfigPath
        ComputerListPath = $computerListPath
        OutputRoot       = $OutputRoot
        Checks           = $selectedChecks
        ComputerNames    = $selectedComputers
    }
}

function Invoke-TuiAuditRun {
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot,

        [Parameter(Mandatory)]
        [string[]]$ComputerNames,

        [Parameter(Mandatory)]
        [string[]]$Checks,

        [Parameter(Mandatory)]
        [string]$OutputRoot,

        [switch]$SkipHtmlReport
    )

    $session = New-TuiAuditSessionFiles -ComputerNames $ComputerNames -Checks $Checks -OutputRoot $OutputRoot
    $auditScript = Join-Path $ProjectRoot "Start-Audit.ps1"

    $invokeParams = @{
        ComputerListPath = $session.ComputerListPath
        ChecksConfigPath = $session.ChecksConfigPath
        OutputRoot       = $OutputRoot
        PassThru         = $true
    }

    if ($SkipHtmlReport) {
        $invokeParams.SkipHtmlReport = $true
    }

    $auditResult = & $auditScript @invokeParams
    $generatedLogs = @($auditResult.JsonLogPath, $auditResult.CsvLogPath | Where-Object { $_ -and (Test-Path $_) })
    $generatedReports = @($auditResult.HtmlReportPath | Where-Object { $_ -and (Test-Path $_) })
    $newFiles = @($generatedLogs + $generatedReports)

    [PSCustomObject]@{
        Session          = $session
        AuditResult      = $auditResult
        OutputRoot       = $OutputRoot
        GeneratedFiles   = $newFiles
        GeneratedLogs    = $generatedLogs
        GeneratedReports = $generatedReports
    }
}

function Read-BasicSelection {
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter(Mandatory)]
        [string[]]$Choices
    )

    Write-Host ""
    Write-Host $Prompt -ForegroundColor Cyan
    for ($index = 0; $index -lt $Choices.Count; $index++) {
        Write-Host ("[{0}] {1}" -f ($index + 1), $Choices[$index])
    }

    while ($true) {
        $rawChoice = Read-Host "Kies een nummer"
        $choiceNumber = 0
        if ([int]::TryParse($rawChoice, [ref]$choiceNumber) -and $choiceNumber -ge 1 -and $choiceNumber -le $Choices.Count) {
            return $Choices[$choiceNumber - 1]
        }

        Write-Host "Ongeldige keuze, probeer opnieuw." -ForegroundColor Yellow
    }
}

function Read-BasicMultiSelection {
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter(Mandatory)]
        [string[]]$Choices
    )

    Write-Host ""
    Write-Host $Prompt -ForegroundColor Cyan
    for ($index = 0; $index -lt $Choices.Count; $index++) {
        Write-Host ("[{0}] {1}" -f ($index + 1), $Choices[$index])
    }

    while ($true) {
        $rawChoice = Read-Host "Geef nummers gescheiden door komma's of typ 'all'"
        if ($rawChoice -match '^\s*all\s*$') {
            return @($Choices)
        }

        $tokens = @($rawChoice -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        if (-not $tokens.Count) {
            Write-Host "Selecteer minstens één optie." -ForegroundColor Yellow
            continue
        }

        $selectedIndexes = @()
        $valid = $true
        foreach ($token in $tokens) {
            $choiceNumber = 0
            if (-not [int]::TryParse($token, [ref]$choiceNumber) -or $choiceNumber -lt 1 -or $choiceNumber -gt $Choices.Count) {
                $valid = $false
                break
            }

            $selectedIndexes += ($choiceNumber - 1)
        }

        if (-not $valid) {
            Write-Host "Ongeldige selectie, probeer opnieuw." -ForegroundColor Yellow
            continue
        }

        return @($selectedIndexes | Select-Object -Unique | ForEach-Object { $Choices[$_] })
    }
}

function Start-BasicAuditTui {
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot
    )

    $defaults = Get-TuiAuditDefaults -ProjectRoot $ProjectRoot
    $availableComputers = @($defaults.DefaultComputers)
    if (-not $availableComputers.Count) {
        $availableComputers = @("localhost")
    }

    Write-Host ""
    Write-Host "Windows Security Compliance Platform" -ForegroundColor Cyan
    Write-Host "PwshSpectreConsole niet gevonden. Basis TUI fallback wordt gebruikt." -ForegroundColor Yellow

    $targetMode = Read-BasicSelection -Prompt "Welke targets wil je auditen?" -Choices @(
        "Alle computers uit CSV"
        "Een subset selecteren"
    )

    $selectedComputers = if ($targetMode -eq "Een subset selecteren") {
        Read-BasicMultiSelection -Prompt "Selecteer de computers voor deze audit" -Choices $availableComputers
    }
    else {
        $availableComputers
    }

    $selectedChecks = Read-BasicMultiSelection -Prompt "Selecteer de checks die je wil uitvoeren" -Choices $defaults.AvailableChecks

    $outputMode = Read-BasicSelection -Prompt "Waar moeten logs en rapporten komen?" -Choices @(
        "Projectmap gebruiken"
        "Aangepast pad invoeren"
    )

    $outputRoot = if ($outputMode -eq "Aangepast pad invoeren") {
        Read-Host "Geef het outputpad op"
    }
    else {
        $defaults.OutputRoot
    }

    if ([string]::IsNullOrWhiteSpace($outputRoot)) {
        $outputRoot = $defaults.OutputRoot
    }

    $htmlChoice = Read-BasicSelection -Prompt "HTML-rapport genereren?" -Choices @("Ja", "Nee")
    $skipHtmlReport = ($htmlChoice -eq "Nee")

    Write-Host ""
    Write-Host "Audit samenvatting" -ForegroundColor Green
    Write-Host "Targets     : $($selectedComputers -join ', ')"
    Write-Host "Checks      : $($selectedChecks -join ', ')"
    Write-Host "Output      : $outputRoot"
    Write-Host "HTML report : $htmlChoice"

    $confirmation = Read-BasicSelection -Prompt "Klaar om de audit te starten?" -Choices @(
        "Audit starten"
        "Annuleren"
    )

    if ($confirmation -ne "Audit starten") {
        Write-Host "Audit geannuleerd." -ForegroundColor Yellow
        return
    }

    $result = Invoke-TuiAuditRun -ProjectRoot $ProjectRoot -ComputerNames $selectedComputers -Checks $selectedChecks -OutputRoot $outputRoot -SkipHtmlReport:$skipHtmlReport

    Write-Host ""
    Write-Host "Audit afgerond" -ForegroundColor Green
    if ($result.GeneratedLogs.Count) {
        Write-Host "Nieuwe logs     : $($result.GeneratedLogs -join ', ')"
    }

    if ($result.GeneratedReports.Count) {
        Write-Host "Nieuwe rapporten: $($result.GeneratedReports -join ', ')"
    }

    Write-Host "Tijdelijke sessiebestanden: $($result.Session.SessionRoot)"
}

function Start-SecurityAuditTui {
    param(
        [string]$ProjectRoot
    )

    Import-TuiDependencies

    if (-not (Test-SpectreAvailability)) {
        Start-BasicAuditTui -ProjectRoot $ProjectRoot
        return
    }

    Import-Module PwshSpectreConsole -ErrorAction Stop

    $defaults = Get-TuiAuditDefaults -ProjectRoot $ProjectRoot
    $availableComputers = @($defaults.DefaultComputers)
    if (-not $availableComputers.Count) {
        $availableComputers = @("localhost")
    }

    Write-SpectreRule -Title "[yellow]Windows Security Compliance Platform[/]"
    Write-SpectreHost "[grey]Gebruik spatie om meerdere items te kiezen en Enter om te bevestigen.[/]"

    $targetMode = Read-SpectreSelection -Message "Welke targets wil je auditen?" -Choices @(
        "Alle computers uit CSV"
        "Een subset selecteren"
    ) -EnableSearch

    $selectedComputers = if ($targetMode -eq "Een subset selecteren") {
        @(
            Read-SpectreMultiSelection -Message "Selecteer de computers voor deze audit" -Choices $availableComputers -PageSize 8
        )
    }
    else {
        $availableComputers
    }

    $selectedChecks = @(
        Read-SpectreMultiSelection -Message "Selecteer de checks die je wil uitvoeren" -Choices $defaults.AvailableChecks -PageSize 8
    )

    $outputMode = Read-SpectreSelection -Message "Waar moeten logs en rapporten komen?" -Choices @(
        "Projectmap gebruiken"
        "Aangepast pad invoeren"
    )

    $outputRoot = if ($outputMode -eq "Aangepast pad invoeren") {
        Read-SpectreText -Message "Geef het outputpad op" -DefaultAnswer $defaults.OutputRoot
    }
    else {
        $defaults.OutputRoot
    }

    $htmlChoice = Read-SpectreSelection -Message "HTML-rapport genereren?" -Choices @(
        "Ja"
        "Nee"
    )
    $skipHtmlReport = ($htmlChoice -eq "Nee")

    Write-SpectreRule -Title "[green]Audit samenvatting[/]"
    Write-SpectreHost "Targets     : [green]$($selectedComputers -join ', ')[/]"
    Write-SpectreHost "Checks      : [green]$($selectedChecks -join ', ')[/]"
    Write-SpectreHost "Output      : [green]$outputRoot[/]"
    Write-SpectreHost "HTML report : [green]$htmlChoice[/]"

    $confirmation = Read-SpectreSelection -Message "Klaar om de audit te starten?" -Choices @(
        "Audit starten"
        "Annuleren"
    )

    if ($confirmation -ne "Audit starten") {
        Write-SpectreHost "[yellow]Audit geannuleerd.[/]"
        return
    }

    $preparedSession = Invoke-SpectreCommandWithStatus -Title "Tijdelijke auditconfiguratie voorbereiden..." -ScriptBlock {
        New-TuiAuditSessionFiles -ComputerNames $selectedComputers -Checks $selectedChecks -OutputRoot $outputRoot
    }

    Write-SpectreRule -Title "[blue]Audit uitvoering[/]"
    $result = Invoke-TuiAuditRun -ProjectRoot $ProjectRoot -ComputerNames $preparedSession.ComputerNames -Checks $preparedSession.Checks -OutputRoot $outputRoot -SkipHtmlReport:$skipHtmlReport

    Write-SpectreRule -Title "[green]Audit afgerond[/]"
    if ($result.GeneratedLogs.Count) {
        Write-SpectreHost "Nieuwe logs     : [green]$($result.GeneratedLogs -join ', ')[/]"
    }

    if ($result.GeneratedReports.Count) {
        Write-SpectreHost "Nieuwe rapporten: [green]$($result.GeneratedReports -join ', ')[/]"
    }
    elseif (-not $skipHtmlReport) {
        Write-SpectreHost "[yellow]Geen nieuw HTML-rapport gedetecteerd in de outputmap.[/]"
    }

    Write-SpectreHost "[grey]Tijdelijke sessiebestanden:[/] $($result.Session.SessionRoot)"
}

Export-ModuleMember -Function Start-SecurityAuditTui, Get-TuiAuditDefaults, New-TuiAuditSessionFiles, Invoke-TuiAuditRun, Test-SpectreAvailability
