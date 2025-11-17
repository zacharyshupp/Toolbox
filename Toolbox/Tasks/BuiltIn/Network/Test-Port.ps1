<#
.SYNOPSIS
    Tests if a TCP port is open and accepting connections

.DESCRIPTION
    Attempts to establish a TCP connection to verify if a port is open and accepting connections.
    Returns connection status and response time.

.PARAMETER TargetHost
    Target hostname or IP address

.PARAMETER Port
    TCP port number to test

.PARAMETER TimeoutSeconds
    Connection timeout in seconds. Default: 5

.NOTES
    TaskName: Network.TestPort
    Version: 1.0.0
    Author: Toolbox
    Tags: Network, Port, TCP, Connectivity
    RequiresElevation: False
    SupportedOS: Windows, Linux, MacOS
    PSEdition: Desktop, Core
    MinPSVersion: 5.1
    Timeout: 30

.EXAMPLE
    Invoke-Task -TaskName 'Network.TestPort' -Computers 'localhost' -TaskParameters @{ TargetHost = 'google.com'; Port = 443 }

.EXAMPLE
    Invoke-Task -TaskName 'Network.TestPort' -Computers 'SERVER01' -TaskParameters @{ TargetHost = '10.0.0.1'; Port = 3389; TimeoutSeconds = 10 }
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$TargetHost,
    
    [Parameter(Mandatory)]
    [int]$Port,
    
    [Parameter()]
    [int]$TimeoutSeconds = 5
)

try {
    Write-Verbose "Testing port $Port on $TargetHost..."
    
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $startTime = Get-Date
    
    try {
        $asyncResult = $tcpClient.BeginConnect($TargetHost, $Port, $null, $null)
        $waitHandle = $asyncResult.AsyncWaitHandle
        
        $connected = $waitHandle.WaitOne([TimeSpan]::FromSeconds($TimeoutSeconds), $false)
        
        if ($connected) {
            $tcpClient.EndConnect($asyncResult)
            $responseTime = ((Get-Date) - $startTime).TotalMilliseconds
            
            $result = [PSCustomObject]@{
                TargetHost = $TargetHost
                Port = $Port
                IsOpen = $true
                ResponseTimeMs = [math]::Round($responseTime, 2)
                Protocol = 'TCP'
                TestedAt = Get-Date -Format 'o'
                Error = $null
            }
            
            Write-Verbose "Port $Port is OPEN (Response: $([math]::Round($responseTime, 2))ms)"
        }
        else {
            $result = [PSCustomObject]@{
                TargetHost = $TargetHost
                Port = $Port
                IsOpen = $false
                ResponseTimeMs = $null
                Protocol = 'TCP'
                TestedAt = Get-Date -Format 'o'
                Error = "Connection timed out after $TimeoutSeconds seconds"
            }
            
            Write-Verbose "Port $Port is CLOSED or FILTERED (timeout)"
        }
    }
    catch {
        $result = [PSCustomObject]@{
            TargetHost = $TargetHost
            Port = $Port
            IsOpen = $false
            ResponseTimeMs = $null
            Protocol = 'TCP'
            TestedAt = Get-Date -Format 'o'
            Error = $_.Exception.Message
        }
        
        Write-Verbose "Port $Port is CLOSED (Error: $($_.Exception.Message))"
    }
    finally {
        if ($tcpClient) {
            $tcpClient.Close()
            $tcpClient.Dispose()
        }
    }
    
    return $result
}
catch {
    Write-Error "Failed to test port: $_"
    throw
}
