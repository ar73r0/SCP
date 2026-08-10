BeforeAll {
    $projectRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $projectRoot "Modules/SecurityChecks.psm1") -Force
    Import-Module (Join-Path $projectRoot "Modules/Scoring.psm1") -Force
    Import-Module (Join-Path $projectRoot "Modules/Reporting.psm1") -Force
    Import-Module (Join-Path $projectRoot "Modules/RemoteAudit.psm1") -Force
    Import-Module (Join-Path $projectRoot "Modules/TUI.psm1") -Force
}

Describe "Projectstructuur" {
    It "heeft de belangrijkste bestanden" {
        $required = @(
            "Setup-Project.ps1",
            "Start-Audit.ps1",
            "Start-AuditTui.ps1",
            "Config/checks.json",
            "Config/computers.csv",
            "Modules/SecurityChecks.psm1",
            "Modules/RemoteAudit.psm1",
            "Modules/Scoring.psm1",
            "Modules/Reporting.psm1",
            "Modules/TUI.psm1",
            "VmSetup/New-WindowsLabVm.ps1",
            "VmSetup/Fix-LabRemoting.ps1",
            "VmSetup/Set-DemoBaseline.ps1",
            "VmSetup/Set-DemoRemoteAudit.ps1",
            "VmSetup/Set-DemoLowSpec.ps1"
        )

        foreach ($path in $required) {
            $fullPath = Join-Path $projectRoot $path
            Test-Path $fullPath | Should -BeTrue
        }
    }
}

Describe "Check resultaat" {
    It "maakt een uniform resultaatobject" {
        $result = New-CheckResult -ComputerName "localhost" -Name "Firewall" -Status "Passed" -Message "OK"

        $result.ComputerName | Should -Be "localhost"
        $result.Name | Should -Be "Firewall"
        $result.Status | Should -Be "Passed"
        $result.Message | Should -Be "OK"
    }
}

Describe "Host compatibiliteit" {
    It "markeert Windows-specifieke checks als skipped op een niet-Windows host" {
        InModuleScope SecurityChecks {
            Mock Test-IsWindowsAuditHost { $false }
            $result = Test-FirewallStatus -ComputerName "localhost"

            $result.Status | Should -Be "Skipped"
            $result.Message | Should -Match "Windows-host"
        }
    }
}

Describe "Compliance scoring" {
    It "berekent een score per computer" {
        $results = @(
            [PSCustomObject]@{ ComputerName = "pc1"; Name = "A"; Status = "Passed"; Message = "" }
            [PSCustomObject]@{ ComputerName = "pc1"; Name = "B"; Status = "Warning"; Message = "" }
            [PSCustomObject]@{ ComputerName = "pc1"; Name = "C"; Status = "Failed"; Message = "" }
        )

        $summary = Get-ComplianceSummary -Results $results

        $summary.Count | Should -Be 1
        $summary[0].ComputerName | Should -Be "pc1"
        $summary[0].Score | Should -Be 50
    }
}

Describe "Check catalogus" {
    It "kent alle verwachte checks" {
        $expectedChecks = @(
            "Firewall",
            "Defender",
            "SMBv1",
            "UAC",
            "GuestAccount",
            "LocalAdministrators",
            "PasswordPolicy",
            "BitLocker",
            "WindowsUpdates",
            "CriticalServices",
            "OpenPorts",
            "SystemInfo",
            "DiskSpace"
        )
        $checks = Get-AvailableSecurityChecks

        $checks.Count | Should -Be $expectedChecks.Count
        foreach ($expectedCheck in $expectedChecks) {
            $checks | Should -Contain $expectedCheck
        }
    }

    It "markeert onbekende checks als ongeldig" {
        $validation = Test-CheckConfiguration -Checks @("Firewall", "BestaatNiet")

        $validation.IsValid | Should -BeFalse
        $validation.UnknownChecks | Should -Contain "BestaatNiet"
    }
}

Describe "Audit runner" {
    It "biedt een schakelaar om parallelle uitvoering uit te zetten" {
        $command = Get-Command (Join-Path $projectRoot "Start-Audit.ps1")

        $command.Parameters.Keys | Should -Contain "DisableParallel"
        $command.Parameters.Keys | Should -Contain "Authentication"
        $command.Parameters.Keys | Should -Contain "UseSSL"
        $command.Parameters.Keys | Should -Contain "Port"
        $command.Parameters.Keys | Should -Contain "Lab"
    }

    It "houdt verbindingsinstellingen uit de TUI launcher" {
        $command = Get-Command (Join-Path $projectRoot "Start-AuditTui.ps1")

        $command.Parameters.Keys | Should -Not -Contain "Lab"
    }
}

Describe "Remote audit embedding" {
    It "gebruikt Test-WSMan met een fallback voor zelfondertekende labcertificaten" {
        $source = (Get-Command Test-ComputerReachability).Definition

        $source | Should -Match "Test-WSMan"
        $source | Should -Match "New-PSSession"
    }

    It "stuurt metadata helpers mee naar remote systemen" {
        $source = InModuleScope RemoteAudit {
            Get-EmbeddedAuditSource
        }

        $source | Should -Match "function Get-SecurityCheckCatalog"
        $source | Should -Match "function Resolve-CheckMetadata"
        $source | Should -Match "function Test-IsWindowsAuditHost"
        $source | Should -Match "function Test-RequiredCommand"
        $source | Should -Match "function New-UnsupportedCheckResult"
        $source | Should -Match "function Invoke-SelectedChecks"
    }
}

Describe "HTML rapportage" {
    It "escaped HTML in foutmeldingen en toont aanbevelingen" {
        $auditResults = @(
            [PSCustomObject]@{
                ComputerName = "pc1"
                Reachable    = $true
                IsLocal      = $true
                Error        = $null
                Results      = @(
                    [PSCustomObject]@{
                        ComputerName = "pc1"
                        Name         = "Firewall"
                        Status       = "Failed"
                        Message      = "<script>alert(1)</script>"
                    }
                )
            }
        )
        $summary = @(
            [PSCustomObject]@{
                ComputerName = "pc1"
                Passed       = 0
                Warning      = 0
                Failed       = 1
                Skipped      = 0
                Total        = 1
                Score        = 0
            }
        )
        $outFile = Join-Path $TestDrive "report.html"

        Write-AuditHtmlReport -AuditResults $auditResults -Summary $summary -Path $outFile
        $content = Get-Content $outFile -Raw

        $content | Should -Match "&lt;script&gt;alert\(1\)&lt;/script&gt;"
        $content | Should -Match "Schakel alle Windows Firewall-profielen in"
        $content | Should -Match "Prioritaire acties"
    }

    It "toont geen aanbeveling voor geslaagde checks" {
        $auditResults = @(
            [PSCustomObject]@{
                ComputerName = "pc1"
                Reachable    = $true
                IsLocal      = $true
                Error        = $null
                Results      = @(
                    [PSCustomObject]@{
                        ComputerName = "pc1"
                        Name         = "Firewall"
                        Status       = "Passed"
                        Message      = "Alle firewallprofielen zijn ingeschakeld."
                    }
                )
            }
        )
        $summary = @(
            [PSCustomObject]@{
                ComputerName = "pc1"
                Passed       = 1
                Warning      = 0
                Failed       = 0
                Skipped      = 0
                Total        = 1
                Score        = 100
            }
        )
        $outFile = Join-Path $TestDrive "passed-report.html"

        Write-AuditHtmlReport -AuditResults $auditResults -Summary $summary -Path $outFile
        $content = Get-Content $outFile -Raw

        $content | Should -Not -Match "Schakel alle Windows Firewall-profielen in"
    }

    It "toont onbereikbare systemen in een aparte sectie" {
        $auditResults = @(
            [PSCustomObject]@{
                ComputerName = "offline-pc"
                Reachable    = $false
                IsLocal      = $false
                Error        = "WinRM timeout"
                Results      = @(
                    [PSCustomObject]@{
                        ComputerName = "offline-pc"
                        Name         = "Connectivity"
                        Status       = "Failed"
                        Message      = "WinRM timeout"
                    }
                )
            }
        )
        $summary = @(
            [PSCustomObject]@{
                ComputerName = "offline-pc"
                Passed       = 0
                Warning      = 0
                Failed       = 1
                Skipped      = 0
                Total        = 1
                Score        = 0
            }
        )
        $outFile = Join-Path $TestDrive "offline-report.html"

        Write-AuditHtmlReport -AuditResults $auditResults -Summary $summary -Path $outFile
        $content = Get-Content $outFile -Raw

        $content | Should -Match "Niet bereikbare systemen"
        $content | Should -Match "offline-pc"
        $content | Should -Match "WinRM timeout"
    }
}

Describe "TUI helpers" {
    It "laadt standaardwaarden uit de projectconfiguratie" {
        $defaults = Get-TuiAuditDefaults -ProjectRoot $projectRoot

        $defaults.ProjectRoot | Should -Be $projectRoot
        $defaults.AvailableChecks.Count | Should -Be 13
        $defaults.DefaultChecks | Should -Contain "Firewall"
        $defaults.DefaultComputers | Should -Contain "baseline"
        $defaults.DefaultComputers | Should -Contain "192.168.122.138"
        $defaults.DefaultComputers | Should -Contain "192.168.122.139"
    }

    It "maakt tijdelijke invoerbestanden voor een TUI-run" {
        $session = New-TuiAuditSessionFiles -ComputerNames @("pc1", "pc2", "pc1") -Checks @("Firewall", "UAC", "Firewall") -OutputRoot $TestDrive

        Test-Path $session.SessionRoot | Should -BeTrue
        Test-Path $session.ChecksConfigPath | Should -BeTrue
        Test-Path $session.ComputerListPath | Should -BeTrue
        $session.ComputerNames.Count | Should -Be 2
        $session.Checks.Count | Should -Be 2

        $savedChecks = (Get-Content $session.ChecksConfigPath -Raw | ConvertFrom-Json).checks
        $savedComputers = Import-Csv $session.ComputerListPath | Select-Object -ExpandProperty ComputerName

        $savedChecks | Should -Contain "Firewall"
        $savedChecks | Should -Contain "UAC"
        $savedComputers | Should -Contain "pc1"
        $savedComputers | Should -Contain "pc2"
    }

    It "kan detecteren of Spectre beschikbaar is" {
        $availability = Test-SpectreAvailability

        $availability | Should -BeOfType [bool]
    }

    It "stuurt de labpreset door naar de audit runner" {
        $fakeProjectRoot = Join-Path $TestDrive "lab-project"
        New-Item -ItemType Directory -Path $fakeProjectRoot -Force | Out-Null
        @'
param(
    [string]$ComputerListPath,
    [string]$ChecksConfigPath,
    [string]$OutputRoot,
    [switch]$Lab,
    [switch]$PassThru
)

[PSCustomObject]@{
    Lab            = $Lab.IsPresent
    JsonLogPath    = $null
    CsvLogPath     = $null
    HtmlReportPath = $null
}
'@ | Set-Content (Join-Path $fakeProjectRoot "Start-Audit.ps1") -Encoding UTF8

        $result = Invoke-TuiAuditRun -ProjectRoot $fakeProjectRoot -ComputerNames @("lab-target") -Checks @("Firewall") -OutputRoot $TestDrive

        $result.AuditResult.Lab | Should -BeTrue
    }
}
