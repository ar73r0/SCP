function Import-SecurityChecksModule {
    $securityChecksModule = Join-Path $PSScriptRoot "SecurityChecks.psm1"

    if (-not (Get-Module -Name SecurityChecks)) {
        Import-Module $securityChecksModule -Force
    }
}

function New-RemoteSessionParameters {
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,

        [pscredential]$Credential,

        [string]$Authentication = "Negotiate",

        [ValidateRange(1, 65535)]
        [int]$Port = 5985,

        [switch]$UseSSL,

        [switch]$SkipCertificateCheck
    )

    $parameters = @{
        ComputerName = $ComputerName
        Port         = $Port
        ErrorAction  = "Stop"
    }

    if ($Credential) {
        $parameters.Credential = $Credential
    }

    if (-not [string]::IsNullOrWhiteSpace($Authentication) -and $Authentication -ne "Default") {
        $parameters.Authentication = $Authentication
    }

    if ($UseSSL) {
        $parameters.UseSSL = $true
    }

    if ($SkipCertificateCheck) {
        $parameters.SessionOption = New-PSSessionOption `
            -SkipCACheck `
            -SkipCNCheck `
            -SkipRevocationCheck
    }

    $parameters
}

function Test-ComputerReachability {
    param(
        [string]$ComputerName,
        [pscredential]$Credential,
        [string]$Authentication = "Negotiate",
        [int]$Port = 5985,
        [switch]$UseSSL,
        [switch]$SkipCertificateCheck
    )

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
        $sessionParameters = New-RemoteSessionParameters `
            -ComputerName $ComputerName `
            -Credential $Credential `
            -Authentication $Authentication `
            -Port $Port `
            -UseSSL:$UseSSL `
            -SkipCertificateCheck:$SkipCertificateCheck

        $probeMethod = "Test-WSMan"
        if ((Get-Command Test-WSMan -ErrorAction SilentlyContinue) -and -not $SkipCertificateCheck) {
            Test-WSMan @sessionParameters | Out-Null
        }
        else {
            # Test-WSMan cannot ignore self-signed certificate errors. A short
            # PSSession probe preserves the encrypted HTTPS lab workflow.
            $probeMethod = "PSSession"
            $session = New-PSSession @sessionParameters
            Remove-PSSession -Session $session
        }

        return [PSCustomObject]@{
            ComputerName = $ComputerName
            Reachable    = $true
            IsLocal      = $false
            Reason       = "WinRM bereikbaar via $probeMethod"
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
    Import-SecurityChecksModule

    $functionsToEmbed = @(
        "New-CheckResult",
        "Test-IsWindowsAuditHost",
        "Test-RequiredCommand",
        "New-UnsupportedCheckResult",
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
        [string[]]$Checks,
        [pscredential]$Credential,
        [string]$Authentication = "Negotiate",
        [int]$Port = 5985,
        [switch]$UseSSL,
        [switch]$SkipCertificateCheck
    )

    Import-SecurityChecksModule

    $probe = Test-ComputerReachability `
        -ComputerName $ComputerName `
        -Credential $Credential `
        -Authentication $Authentication `
        -Port $Port `
        -UseSSL:$UseSSL `
        -SkipCertificateCheck:$SkipCertificateCheck
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
        $results = @(SecurityChecks\Invoke-SelectedChecks -ComputerName $ComputerName -Checks $Checks)
        return [PSCustomObject]@{
            ComputerName = $ComputerName
            Reachable    = $true
            IsLocal      = $true
            Error        = $null
            Results      = $results
        }
    }

    $source = Get-EmbeddedAuditSource
    $checksJson = ConvertTo-Json -InputObject @($Checks) -Compress
    $checksBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($checksJson))
    $remoteScript = @"
param(
    [string]`$RemoteComputerName
)

$source

`$RemoteChecksJson = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("$checksBase64"))
[string[]]`$RemoteChecks = (`$RemoteChecksJson | ConvertFrom-Json)
Invoke-SelectedChecks -ComputerName `$RemoteComputerName -Checks `$RemoteChecks
"@

    $invokeParams = New-RemoteSessionParameters `
        -ComputerName $ComputerName `
        -Credential $Credential `
        -Authentication $Authentication `
        -Port $Port `
        -UseSSL:$UseSSL `
        -SkipCertificateCheck:$SkipCertificateCheck

    $invokeParams.ScriptBlock = [scriptblock]::Create($remoteScript)
    $invokeParams.ArgumentList = $ComputerName

    $results = Invoke-Command @invokeParams

    [PSCustomObject]@{
        ComputerName = $ComputerName
        Reachable    = $true
        IsLocal      = $false
        Error        = $null
        Results      = @($results)
    }
}

Export-ModuleMember -Function Test-ComputerReachability, Invoke-ComputerAudit
