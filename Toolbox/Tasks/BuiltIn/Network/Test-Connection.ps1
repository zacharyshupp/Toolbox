<#
.SYNOPSIS
    Tests network connectivity to a target host.

.DESCRIPTION
    Performs ping tests to verify network connectivity and measures response times.

.PARAMETER TargetHost
    Target hostname or IP address to test.

.PARAMETER Count
    Number of ping attempts (default: 4).

.PARAMETER TimeoutSeconds
    Timeout for each ping in seconds (default: 5).

.NOTES
    TaskName: Network.TestConnection
    Version: 1.0.0
    Author: Toolbox
    Tags: Network, Ping, ICMP, Connectivity
    RequiresElevation: False
    SupportedOS: Windows, Linux, MacOS
    PSEdition: Desktop, Core
    MinPSVersion: 5.1
    Timeout: 30

.EXAMPLE
    Invoke-Task -TaskName 'Network.TestConnection' -Computers 'localhost'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$TargetHost,
    
    [Parameter()]
    [int]$Count = 4,
    
    [Parameter()]
    [int]$TimeoutSeconds = 5
)

try {
    Write-Verbose "Testing connectivity to $TargetHost ($Count attempts)..."
    
    # Use Test-Connection (compatible with both PowerShell versions)
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        # PowerShell Core has different parameters
        $pingResults = Test-Connection -TargetName $TargetHost -Count $Count -TimeoutSeconds $TimeoutSeconds -ErrorAction SilentlyContinue
    }
    else {
        # Windows PowerShell
        $pingResults = Test-Connection -ComputerName $TargetHost -Count $Count -ErrorAction SilentlyContinue
    }
    
    $successful = @($pingResults | Where-Object { $_.StatusCode -eq 0 -or $_.Status -eq 'Success' })
    $successRate = if ($pingResults) { 
        [math]::Round(($successful.Count / $Count) * 100, 2) 
    } else { 
        0 
    }
    
    $result = [PSCustomObject]@{
        TargetHost = $TargetHost
        Reachable = $successful.Count -gt 0
        SuccessRate = $successRate
        PacketsSent = $Count
        PacketsReceived = $successful.Count
        PacketsLost = $Count - $successful.Count
        MinResponseTime = if ($successful) { ($successful | Measure-Object -Property ResponseTime -Minimum).Minimum } else { $null }
        MaxResponseTime = if ($successful) { ($successful | Measure-Object -Property ResponseTime -Maximum).Maximum } else { $null }
        AvgResponseTime = if ($successful) { [math]::Round(($successful | Measure-Object -Property ResponseTime -Average).Average, 2) } else { $null }
        TestedAt = Get-Date -Format 'o'
    }
    
    if ($result.Reachable) {
        Write-Verbose "Host is reachable (Success rate: $successRate%)"
    }
    else {
        Write-Verbose "Host is not reachable"
    }
    
    return $result
}
catch {
    Write-Error "Failed to test connection: $_"
    throw
}
