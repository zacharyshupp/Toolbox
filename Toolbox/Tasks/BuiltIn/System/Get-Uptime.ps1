<#
.SYNOPSIS
    Get system uptime and last boot time information

.DESCRIPTION
    Retrieves the system's last boot time and calculates the current uptime in various formats.

.NOTES
    TaskName: System.GetUptime
    Version: 1.0.0
    Author: Toolbox
    Tags: System, Uptime, Monitoring
    RequiresElevation: False
    SupportedOS: Windows, Linux, MacOS
    PSEdition: Desktop, Core
    MinPSVersion: 5.1
    Timeout: 10

.EXAMPLE
    Invoke-Task -TaskName 'System.GetUptime' -Computers 'localhost'
#>
[CmdletBinding()]
param()

try {
    Write-Verbose "Retrieving system uptime information..."
    
    # Get OS information
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    
    $lastBootTime = $os.LastBootUpTime
    $currentTime = Get-Date
    $uptime = $currentTime - $lastBootTime
    
    Write-Verbose "Last boot time: $lastBootTime"
    Write-Verbose "Current time: $currentTime"
    Write-Verbose "Uptime: $($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes"
    
    # Build result object with multiple formats
    [PSCustomObject]@{
        LastBootTime        = $lastBootTime
        CurrentTime         = $currentTime
        UptimeDays          = [math]::Round($uptime.TotalDays, 2)
        UptimeHours         = [math]::Round($uptime.TotalHours, 2)
        UptimeMinutes       = [math]::Round($uptime.TotalMinutes, 0)
        UptimeFormatted     = "{0} days, {1} hours, {2} minutes, {3} seconds" -f $uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds
        UptimeTimeSpan      = $uptime
        LocalTimeZone       = $os.CurrentTimeZone / 60  # Convert minutes to hours
        BootDevice          = $os.BootDevice
        SystemDirectory     = $os.SystemDirectory
        WindowsDirectory    = $os.WindowsDirectory
    }
}
catch {
    Write-Error "Failed to retrieve uptime information: $_"
    throw
}
