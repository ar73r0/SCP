function Import-SecurityChecksModule {
    $securityChecksModule = Join-Path $PSScriptRoot "SecurityChecks.psm1"

    if (-not (Get-Module -Name SecurityChecks)) {
        Import-Module $securityChecksModule -Force
    }
}

function ConvertTo-HtmlSafeText {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return ""
    }

    [System.Net.WebUtility]::HtmlEncode($Value)
}

function Get-StatusBadgeClass {
    param([string]$Status)

    switch ($Status) {
        "Passed" { "status-passed" }
        "Warning" { "status-warning" }
        "Failed" { "status-failed" }
        default { "status-skipped" }
    }
}

function Get-ReportRecommendation {
    param([string]$CheckName)

    Import-SecurityChecksModule

    $resolver = Get-Command Resolve-CheckMetadata -ErrorAction SilentlyContinue
    $metadata = if ($resolver) { Resolve-CheckMetadata -Name $CheckName } else { $null }
    if ($null -eq $metadata) {
        return "Geen aanbeveling beschikbaar."
    }

    $metadata.Recommendation
}

function Get-ReportSeverity {
    param([string]$CheckName)

    Import-SecurityChecksModule

    $resolver = Get-Command Resolve-CheckMetadata -ErrorAction SilentlyContinue
    $metadata = if ($resolver) { Resolve-CheckMetadata -Name $CheckName } else { $null }
    if ($null -eq $metadata) {
        return "Unknown"
    }

    $metadata.Severity
}

function Write-AuditJsonLog {
    param(
        [object[]]$AuditResults,
        [object[]]$Summary,
        [string]$Path
    )

    $generatedAt = Get-Date
    $payload = [PSCustomObject]@{
        GeneratedAt = $generatedAt
        Summary     = $Summary
        Systems     = $AuditResults
    }

    $payload | ConvertTo-Json -Depth 8 | Set-Content -Path $Path -Encoding UTF8
}

function Write-AuditCsvLog {
    param(
        [object[]]$Results,
        [string]$Path
    )

    $Results | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
}

function Write-AuditHtmlReport {
    param(
        [object[]]$AuditResults,
        [object[]]$Summary,
        [string]$Path
    )

    $generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $totalSystems = @($AuditResults).Count
    $unreachableSystems = @($AuditResults | Where-Object { -not $_.Reachable })
    $failedFindings = @(
        foreach ($system in $AuditResults) {
            foreach ($result in $system.Results) {
                if ($result.Status -in @("Failed", "Warning")) {
                    [PSCustomObject]@{
                        ComputerName   = $result.ComputerName
                        Name           = $result.Name
                        Status         = $result.Status
                        Message        = $result.Message
                        Severity       = Get-ReportSeverity -CheckName $result.Name
                        Recommendation = Get-ReportRecommendation -CheckName $result.Name
                    }
                }
            }
        }
    )

    $summaryRows = foreach ($item in $Summary) {
        "<tr><td>$(ConvertTo-HtmlSafeText $item.ComputerName)</td><td>$($item.Passed)</td><td>$($item.Warning)</td><td>$($item.Failed)</td><td>$($item.Skipped)</td><td>$($item.Score)%</td></tr>"
    }

    $detailRows = foreach ($system in $AuditResults) {
        foreach ($result in $system.Results) {
            $cssClass = $result.Status.ToLowerInvariant()
            $badgeClass = Get-StatusBadgeClass -Status $result.Status
            $severity = ConvertTo-HtmlSafeText (Get-ReportSeverity -CheckName $result.Name)
            $recommendation = if ($result.Status -eq "Passed") {
                ""
            }
            else {
                ConvertTo-HtmlSafeText (Get-ReportRecommendation -CheckName $result.Name)
            }
            $message = ConvertTo-HtmlSafeText $result.Message
            "<tr class='$cssClass'><td>$(ConvertTo-HtmlSafeText $result.ComputerName)</td><td>$(ConvertTo-HtmlSafeText $result.Name)</td><td><span class='status-badge $badgeClass'>$(ConvertTo-HtmlSafeText $result.Status)</span></td><td>$severity</td><td>$message</td><td>$recommendation</td></tr>"
        }
    }

    $priorityRows = foreach ($finding in $failedFindings) {
        $badgeClass = Get-StatusBadgeClass -Status $finding.Status
        "<tr><td>$(ConvertTo-HtmlSafeText $finding.ComputerName)</td><td>$(ConvertTo-HtmlSafeText $finding.Name)</td><td>$(ConvertTo-HtmlSafeText $finding.Severity)</td><td><span class='status-badge $badgeClass'>$(ConvertTo-HtmlSafeText $finding.Status)</span></td><td>$(ConvertTo-HtmlSafeText $finding.Recommendation)</td></tr>"
    }

    $unreachableRows = foreach ($system in $unreachableSystems) {
        "<tr><td>$(ConvertTo-HtmlSafeText $system.ComputerName)</td><td>$(ConvertTo-HtmlSafeText $system.Error)</td></tr>"
    }

    $html = @"
<!DOCTYPE html>
<html lang="nl">
<head>
    <meta charset="utf-8">
    <title>Windows Security Compliance Report</title>
    <style>
        :root {
            --bg: #eef2f7;
            --panel: #ffffff;
            --ink: #1f2937;
            --muted: #475569;
            --line: #d1d5db;
            --head: #e2e8f0;
            --passed: #dcfce7;
            --warning: #fef3c7;
            --failed: #fee2e2;
            --skipped: #e5e7eb;
            --accent: #0f172a;
        }
        body { font-family: Segoe UI, sans-serif; background: linear-gradient(180deg, #f8fafc 0%, var(--bg) 100%); color: var(--ink); margin: 2rem; }
        h1, h2 { color: #0f172a; }
        .hero, .panel { background: var(--panel); border: 1px solid var(--line); border-radius: 16px; padding: 1.25rem; box-shadow: 0 10px 30px rgba(15, 23, 42, 0.06); margin-bottom: 1.5rem; }
        .meta { display: flex; gap: 1rem; flex-wrap: wrap; color: var(--muted); margin-top: 0.75rem; }
        .meta-item { background: #f8fafc; border: 1px solid var(--line); border-radius: 999px; padding: 0.4rem 0.8rem; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 2rem; background: white; }
        th, td { border: 1px solid var(--line); padding: 0.75rem; text-align: left; vertical-align: top; }
        th { background: var(--head); }
        .passed { background: var(--passed); }
        .warning { background: var(--warning); }
        .failed { background: var(--failed); }
        .skipped { background: var(--skipped); }
        .status-badge { display: inline-block; border-radius: 999px; padding: 0.2rem 0.65rem; font-weight: 600; }
        .status-passed { background: #166534; color: #fff; }
        .status-warning { background: #a16207; color: #fff; }
        .status-failed { background: #b91c1c; color: #fff; }
        .status-skipped { background: #475569; color: #fff; }
        .empty { color: var(--muted); font-style: italic; }
    </style>
</head>
<body>
    <section class="hero">
        <h1>Windows Security Compliance Report</h1>
        <p>Gegenereerd op: $generatedAt</p>
        <div class="meta">
            <span class="meta-item">Systemen: $totalSystems</span>
            <span class="meta-item">Niet bereikbaar: $(@($unreachableSystems).Count)</span>
            <span class="meta-item">Actiepunten: $(@($failedFindings).Count)</span>
        </div>
    </section>

    <section class="panel">
        <h2>Samenvatting</h2>
        <table>
            <thead>
                <tr>
                    <th>Computer</th>
                    <th>Passed</th>
                    <th>Warning</th>
                    <th>Failed</th>
                    <th>Skipped</th>
                    <th>Score</th>
                </tr>
            </thead>
            <tbody>
                $($summaryRows -join "`n")
            </tbody>
        </table>
    </section>

    <section class="panel">
        <h2>Prioritaire acties</h2>
        $(if ($priorityRows) {
            "<table><thead><tr><th>Computer</th><th>Check</th><th>Severity</th><th>Status</th><th>Aanbeveling</th></tr></thead><tbody>$($priorityRows -join "`n")</tbody></table>"
        }
        else {
            "<p class='empty'>Geen warnings of failures gevonden.</p>"
        })
    </section>

    <section class="panel">
        <h2>Details</h2>
        <table>
            <thead>
                <tr>
                    <th>Computer</th>
                    <th>Check</th>
                    <th>Status</th>
                    <th>Severity</th>
                    <th>Message</th>
                    <th>Aanbeveling</th>
                </tr>
            </thead>
            <tbody>
                $($detailRows -join "`n")
            </tbody>
        </table>
    </section>

    <section class="panel">
        <h2>Niet bereikbare systemen</h2>
        $(if ($unreachableRows) {
            "<table><thead><tr><th>Computer</th><th>Fout</th></tr></thead><tbody>$($unreachableRows -join "`n")</tbody></table>"
        }
        else {
            "<p class='empty'>Alle systemen waren bereikbaar of lokaal uitvoerbaar.</p>"
        })
    </section>
</body>
</html>
"@

    Set-Content -Path $Path -Value $html -Encoding UTF8
}

Export-ModuleMember -Function Write-AuditJsonLog, Write-AuditCsvLog, Write-AuditHtmlReport
