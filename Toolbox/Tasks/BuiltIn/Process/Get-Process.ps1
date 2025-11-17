<#
.SYNOPSIS
    Retrieves information about running processes.

.DESCRIPTION
    Gets detailed information about running processes, with optional filtering
    by process name or ID.

.PARAMETER ProcessName
    Name of the process to retrieve (supports wildcards).

.PARAMETER ProcessId
    Process ID to retrieve.

.NOTES
    TaskName: Process.GetProcess
    Version: 1.0.0
    Author: Toolbox
    Tags: Process, Task Manager, System
    RequiresElevation: False
    SupportedOS: Windows, Linux, MacOS
    PSEdition: Desktop, Core
    MinPSVersion: 5.1
    Timeout: 30

.EXAMPLE
    Invoke-Task -TaskName 'Process.GetProcess' -Computers 'localhost'
#>
[CmdletBinding(DefaultParameterSetName = 'All')]
param(
    [Parameter(ParameterSetName = 'ByName')]
    [string]$ProcessName,
    
    [Parameter(ParameterSetName = 'ById')]
    [int]$ProcessId
)

try {
    Write-Verbose "Retrieving process information..."
    
    $processes = if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'ById') {
        Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    }
    else {
        Get-Process
    }
    
    if (-not $processes) {
        $filter = if ($ProcessName) { "name '$ProcessName'" } elseif ($ProcessId) { "ID $ProcessId" } else { "" }
        Write-Verbose "No processes found$(if ($filter) { " matching $filter" })"
        return @()
    }
    
    $results = $processes | ForEach-Object {
        [PSCustomObject]@{
            ProcessName = $_.ProcessName
            ProcessId = $_.Id
            CPU = [math]::Round($_.CPU, 2)
            WorkingSetMB = [math]::Round($_.WorkingSet64 / 1MB, 2)
            PrivateMemoryMB = [math]::Round($_.PrivateMemorySize64 / 1MB, 2)
            VirtualMemoryMB = [math]::Round($_.VirtualMemorySize64 / 1MB, 2)
            Threads = $_.Threads.Count
            Handles = $_.HandleCount
            StartTime = if ($_.StartTime) { $_.StartTime } else { $null }
            Path = $_.Path
            Company = $_.Company
            ProductVersion = $_.ProductVersion
        }
    }
    
    Write-Verbose "Retrieved $($results.Count) process(es)"
    return $results
}
catch {
    Write-Error "Failed to retrieve process information: $_"
    throw
}
