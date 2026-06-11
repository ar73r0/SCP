BeforeAll {
    $projectRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $projectRoot "Modules/SecurityChecks.psm1") -Force
    Import-Module (Join-Path $projectRoot "Modules/Scoring.psm1") -Force
}

Describe "Projectstructuur" {
    It "heeft de belangrijkste bestanden" {
        $required = @(
            "Start-Audit.ps1",
            "Start-AuditTui.ps1",
            "Config/checks.json",
            "Config/computers.csv",
            "Modules/SecurityChecks.psm1",
            "Modules/RemoteAudit.psm1",
            "Modules/Scoring.psm1",
            "Modules/Reporting.psm1",
            "Modules/TUI.psm1"
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
