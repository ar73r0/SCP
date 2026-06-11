function Get-ComplianceSummary {
    param(
        [Parameter(Mandatory)]
        [object[]]$Results
    )

    $grouped = $Results | Group-Object -Property ComputerName

    foreach ($group in $grouped) {
        $passed = @($group.Group | Where-Object Status -eq "Passed").Count
        $warning = @($group.Group | Where-Object Status -eq "Warning").Count
        $failed = @($group.Group | Where-Object Status -eq "Failed").Count
        $skipped = @($group.Group | Where-Object Status -eq "Skipped").Count
        $total = @($group.Group).Count

        $weightedScore = (($passed * 1.0) + ($warning * 0.5)) / [math]::Max($total, 1) * 100

        [PSCustomObject]@{
            ComputerName = $group.Name
            Passed       = $passed
            Warning      = $warning
            Failed       = $failed
            Skipped      = $skipped
            Total        = $total
            Score        = [math]::Round($weightedScore, 2)
        }
    }
}

Export-ModuleMember -Function Get-ComplianceSummary
