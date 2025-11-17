<#
.SYNOPSIS
    Retrieves information about Windows services

.DESCRIPTION
    Gets detailed information about one or more Windows services including status, startup type, dependencies, and account information.

.PARAMETER ServiceName
    Name of the service to retrieve (supports wildcards)

.PARAMETER DisplayName
    Display name of the service (supports wildcards)

.NOTES
    TaskName: Service.GetService
    Version: 1.0.0
    Author: Toolbox
    Tags: Service, Windows, Management
    RequiresElevation: False
    SupportedOS: Windows
    PSEdition: Desktop, Core
    MinPSVersion: 5.1
    Timeout: 30

.EXAMPLE
    Invoke-Task -TaskName 'Service.GetService' -Computers 'localhost'

.EXAMPLE
    Invoke-Task -TaskName 'Service.GetService' -Computers 'SERVER01' -TaskParameters @{ ServiceName = 'W3SVC' }
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$ServiceName,

    [Parameter()]
    [string]$DisplayName
)

try {
    Write-Verbose "Retrieving service information..."
    
    # Build Get-Service parameters
    $getServiceParams = @{}
    
    if ($PSBoundParameters.ContainsKey('ServiceName')) {
        $getServiceParams['Name'] = $ServiceName
        Write-Verbose "Filtering by ServiceName: $ServiceName"
    }
    
    if ($PSBoundParameters.ContainsKey('DisplayName')) {
        $getServiceParams['DisplayName'] = $DisplayName
        Write-Verbose "Filtering by DisplayName: $DisplayName"
    }
    
    # Get services
    $services = if ($getServiceParams.Count -gt 0) {
        Get-Service @getServiceParams -ErrorAction Stop
    } else {
        Get-Service -ErrorAction Stop
    }
    
    # Convert to array if single service
    $services = @($services)
    
    Write-Verbose "Found $($services.Count) service(s)"
    
    # Build structured output
    $results = foreach ($service in $services) {
        # Get additional service details via WMI
        $wmiService = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($service.Name)'" -ErrorAction SilentlyContinue
        
        [PSCustomObject]@{
            ServiceName    = $service.Name
            DisplayName    = $service.DisplayName
            Status         = $service.Status.ToString()
            StartType      = $service.StartType.ToString()
            CanStop        = $service.CanStop
            CanPauseResume = $service.CanPauseAndContinue
            DependentServices = @($service.DependentServices | Select-Object -ExpandProperty Name)
            ServicesDependedOn = @($service.ServicesDependedOn | Select-Object -ExpandProperty Name)
            Description    = if ($wmiService) { $wmiService.Description } else { $null }
            PathName       = if ($wmiService) { $wmiService.PathName } else { $null }
            StartName      = if ($wmiService) { $wmiService.StartName } else { $null }
            ProcessId      = if ($wmiService) { $wmiService.ProcessId } else { $null }
            State          = if ($wmiService) { $wmiService.State } else { $null }
        }
    }
    
    Write-Verbose "Service information retrieved successfully"
    
    # Return results
    [PSCustomObject]@{
        Success      = $true
        ServiceCount = $results.Count
        Services     = $results
    }
}
catch {
    Write-Error "Failed to retrieve service information: $_"
    throw
}
