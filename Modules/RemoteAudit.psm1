function Test-ComputerReachability {
    param([string]$ComputerName)

    $localNames = @(
        ".",
        "localhost",
        $env:COMPUTERNAME,
        "$env:COMPUTERNAME.$env:USERDNSDOMAIN"
    ) | Where-Object { $_ }

    if ($localNames -contains $ComputerName) {
        return [PSCustomObject]@{
            ComputerName = $ComputerName
            Reachable    = $true
            IsLocal      = $true
            Reason       = "Lokale machine"
        }
    }

    try {
        Test-WSMan -ComputerName $ComputerName -ErrorAction Stop | Out-Null
        return [PSCustomObject]@{
            ComputerName = $ComputerName
            Reachable    = $true
            IsLocal      = $false
            Reason       = "WinRM bereikbaar"
        }
    }
    catch {
        return [PSCustomObject]@{
            ComputerName = $ComputerName
            Reachable    = $false
            IsLocal      = $false
            Reason       = $_.Exception.Message
        }
    }
}

function Get-EmbeddedAuditSource {
    $functionsToEmbed = @(
        "New-CheckResult",
        "Get-SecurityCheckCatalog",
        "Get-AvailableSecurityChecks",
        "Resolve-CheckMetadata",
        "Test-CheckConfiguration",
        "Test-FirewallStatus",
        "Test-DefenderStatus",
        "Test-SMBv1Status",
        "Test-UacStatus",
        "Test-GuestAccountStatus",
        "Test-LocalAdministratorsStatus",
        "Test-PasswordPolicyStatus",
        "Test-BitLockerStatus",
        "Test-WindowsUpdatesStatus",
        "Test-CriticalServicesStatus",
        "Test-OpenPortsStatus",
        "Test-SystemInfoStatus",
        "Test-DiskSpaceStatus",
        "Invoke-SelectedChecks"
    )

    $definitions = foreach ($name in $functionsToEmbed) {
        $definition = (Get-Command $name -CommandType Function -ErrorAction Stop).Definition
        "function $name {`n$definition`n}"
    }

    $definitions -join "`n`n"
}

function Invoke-ComputerAudit {
    param(
        [string]$ComputerName,
        [string[]]$Checks
    )

    $probe = Test-ComputerReachability -ComputerName $ComputerName
    if (-not $probe.Reachable) {
        return [PSCustomObject]@{
            ComputerName = $ComputerName
            Reachable    = $false
            IsLocal      = $probe.IsLocal
            Error        = $probe.Reason
            Results      = @(
                [PSCustomObject]@{
                    ComputerName = $ComputerName
                    Name         = "Connectivity"
                    Status       = "Failed"
                    Message      = $probe.Reason
                }
            )
        }
    }

    if ($probe.IsLocal) {
        $results = @(Invoke-SelectedChecks -ComputerName $ComputerName -Checks $Checks)
        return [PSCustomObject]@{
            ComputerName = $ComputerName
            Reachable    = $true
            IsLocal      = $true
            Error        = $null
            Results      = $results
        }
    }

    $source = Get-EmbeddedAuditSource
    $remoteScript = @"
$source

param(
    [string]`$RemoteComputerName,
    [string[]]`$RemoteChecks
)

Invoke-SelectedChecks -ComputerName `$RemoteComputerName -Checks `$RemoteChecks
"@

    $results = Invoke-Command -ComputerName $ComputerName -ScriptBlock ([scriptblock]::Create($remoteScript)) -ArgumentList $ComputerName, (,$Checks) -ErrorAction Stop

    [PSCustomObject]@{
        ComputerName = $ComputerName
        Reachable    = $true
        IsLocal      = $false
        Error        = $null
        Results      = @($results)
    }
}

Export-ModuleMember -Function Test-ComputerReachability, Invoke-ComputerAudit
