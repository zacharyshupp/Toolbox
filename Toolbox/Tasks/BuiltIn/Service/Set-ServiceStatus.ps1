<#
.SYNOPSIS
    Start, stop, restart, pause, or resume a Windows service

.DESCRIPTION
    Performs service control operations with validation and status monitoring. Waits for the service to reach the target state before completing.

.PARAMETER ServiceName
    Name of the service to modify

.PARAMETER Action
    Action to perform on the service. Valid values: Start, Stop, Restart, Pause, Resume

.PARAMETER TimeoutSeconds
    Timeout in seconds to wait for the action to complete. Default: 30

.NOTES
    TaskName: Service.ChangeStatus
    Version: 1.0.0
    Author: Toolbox
    Tags: Service, Windows, Management, Administration
    RequiresElevation: True
    SupportedOS: Windows
    PSEdition: Desktop, Core
    MinPSVersion: 5.1
    Timeout: 60

.EXAMPLE
    Invoke-Task -TaskName 'Service.ChangeStatus' -Computers 'localhost' -TaskParameters @{ ServiceName = 'Spooler'; Action = 'Restart' }

.EXAMPLE
    Invoke-Task -TaskName 'Service.ChangeStatus' -Computers 'SERVER01' -TaskParameters @{ ServiceName = 'W3SVC'; Action = 'Stop'; TimeoutSeconds = 60 }
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ServiceName,

    [Parameter(Mandatory)]
    [ValidateSet('Start', 'Stop', 'Restart', 'Pause', 'Resume')]
    [string]$Action,

    [Parameter()]
    [int]$TimeoutSeconds = 30
)

try {
    Write-Verbose "Performing action '$Action' on service '$ServiceName'..."
    
    # Get the service
    $service = Get-Service -Name $ServiceName -ErrorAction Stop
    $initialStatus = $service.Status.ToString()
    
    Write-Verbose "Current service status: $initialStatus"
    
    # Determine target status based on action
    $targetStatus = switch ($Action) {
        'Start'   { 'Running' }
        'Stop'    { 'Stopped' }
        'Restart' { 'Running' }
        'Pause'   { 'Paused' }
        'Resume'  { 'Running' }
    }
    
    # Validate service capabilities
    switch ($Action) {
        'Stop' {
            if (-not $service.CanStop) {
                throw "Service '$ServiceName' cannot be stopped"
            }
        }
        { $_ -in 'Pause', 'Resume' } {
            if (-not $service.CanPauseAndContinue) {
                throw "Service '$ServiceName' does not support pause/resume"
            }
        }
    }
    
    # Perform the action
    $startTime = Get-Date
    $actionPerformed = $false
    
    switch ($Action) {
        'Start' {
            if ($service.Status -ne 'Running') {
                Start-Service -Name $ServiceName -ErrorAction Stop
                $actionPerformed = $true
            }
        }
        'Stop' {
            if ($service.Status -ne 'Stopped') {
                Stop-Service -Name $ServiceName -Force -ErrorAction Stop
                $actionPerformed = $true
            }
        }
        'Restart' {
            Restart-Service -Name $ServiceName -Force -ErrorAction Stop
            $actionPerformed = $true
        }
        'Pause' {
            if ($service.Status -eq 'Running') {
                Suspend-Service -Name $ServiceName -ErrorAction Stop
                $actionPerformed = $true
            }
        }
        'Resume' {
            if ($service.Status -eq 'Paused') {
                Resume-Service -Name $ServiceName -ErrorAction Stop
                $actionPerformed = $true
            }
        }
    }
    
    # Wait for the service to reach target status
    if ($actionPerformed) {
        Write-Verbose "Waiting for service to reach status '$targetStatus' (timeout: $TimeoutSeconds seconds)..."
        
        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
        $statusReached = $false
        
        while ((Get-Date) -lt $deadline) {
            $service.Refresh()
            
            if ($service.Status.ToString() -eq $targetStatus) {
                $statusReached = $true
                break
            }
            
            Start-Sleep -Milliseconds 500
        }
        
        if (-not $statusReached) {
            throw "Timeout waiting for service to reach status '$targetStatus'. Current status: $($service.Status)"
        }
    }
    
    $duration = ((Get-Date) - $startTime).TotalSeconds
    $finalStatus = $service.Status.ToString()
    
    Write-Verbose "Action completed in $([math]::Round($duration, 2)) seconds. Final status: $finalStatus"
    
    # Return results
    [PSCustomObject]@{
        Success        = $true
        ServiceName    = $ServiceName
        Action         = $Action
        InitialStatus  = $initialStatus
        FinalStatus    = $finalStatus
        ActionPerformed = $actionPerformed
        DurationSeconds = [math]::Round($duration, 2)
    }
}
catch {
    Write-Error "Failed to perform action '$Action' on service '$ServiceName': $_"
    throw
}
