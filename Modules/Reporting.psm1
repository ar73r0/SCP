function Write-AuditJsonLog {
    param(
        [object[]]$AuditResults,
        [object[]]$Summary,
        [string]$Path
    )

    $payload = [PSCustomObject]@{
        GeneratedAt = Get-Date
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

    $summaryRows = foreach ($item in $Summary) {
        "<tr><td>$($item.ComputerName)</td><td>$($item.Passed)</td><td>$($item.Warning)</td><td>$($item.Failed)</td><td>$($item.Skipped)</td><td>$($item.Score)%</td></tr>"
    }

    $detailRows = foreach ($system in $AuditResults) {
        foreach ($result in $system.Results) {
            $cssClass = $result.Status.ToLowerInvariant()
            "<tr class='$cssClass'><td>$($result.ComputerName)</td><td>$($result.Name)</td><td>$($result.Status)</td><td>$($result.Message)</td></tr>"
        }
    }

    $html = @"
<!DOCTYPE html>
<html lang="nl">
<head>
    <meta charset="utf-8">
    <title>Windows Security Compliance Report</title>
    <style>
        body { font-family: Segoe UI, sans-serif; background: #f4f6f8; color: #1f2937; margin: 2rem; }
        h1, h2 { color: #0f172a; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 2rem; background: white; }
        th, td { border: 1px solid #d1d5db; padding: 0.75rem; text-align: left; vertical-align: top; }
        th { background: #e2e8f0; }
        .passed { background: #dcfce7; }
        .warning { background: #fef3c7; }
        .failed { background: #fee2e2; }
        .skipped { background: #e5e7eb; }
    </style>
</head>
<body>
    <h1>Windows Security Compliance Report</h1>
    <p>Gegenereerd op: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>

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

    <h2>Details</h2>
    <table>
        <thead>
            <tr>
                <th>Computer</th>
                <th>Check</th>
                <th>Status</th>
                <th>Message</th>
            </tr>
        </thead>
        <tbody>
            $($detailRows -join "`n")
        </tbody>
    </table>
</body>
</html>
"@

    Set-Content -Path $Path -Value $html -Encoding UTF8
}

Export-ModuleMember -Function Write-AuditJsonLog, Write-AuditCsvLog, Write-AuditHtmlReport
