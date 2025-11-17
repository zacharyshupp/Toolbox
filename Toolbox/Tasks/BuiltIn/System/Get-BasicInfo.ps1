<#
.SYNOPSIS
    Retrieves basic system information.

.DESCRIPTION
    Collects comprehensive system information including OS details, computer name,
    uptime, processor, memory, and disk information.

.NOTES
    TaskName: System.GetBasicInfo
    Version: 1.0.0
    Author: Toolbox
    Tags: System, Information, Hardware, OS
    RequiresElevation: False
    SupportedOS: Windows, Linux, MacOS
    PSEdition: Desktop, Core
    MinPSVersion: 5.1
    Timeout: 30

.EXAMPLE
    Invoke-Task -TaskName 'System.GetBasicInfo' -Computers 'localhost'
#>
[CmdletBinding()]
param()

try {
    Write-Verbose "Collecting system information..."
    
    # Get OS information
    $os = if ($PSVersionTable.PSVersion.Major -ge 6) {
        Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    } else {
        Get-WmiObject -Class Win32_OperatingSystem -ErrorAction SilentlyContinue
    }
    
    # Get computer system information
    $computerSystem = if ($PSVersionTable.PSVersion.Major -ge 6) {
        Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
    } else {
        Get-WmiObject -Class Win32_ComputerSystem -ErrorAction SilentlyContinue
    }
    
    # Get processor information
    $processor = if ($PSVersionTable.PSVersion.Major -ge 6) {
        Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    } else {
        Get-WmiObject -Class Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    
    # Calculate uptime
    $uptime = if ($os) {
        (Get-Date) - $os.LastBootUpTime
    } else {
        $null
    }
    
    # Get disk information (system drive)
    $systemDrive = if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
        } else {
            Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
        }
    } else {
        $null
    }
    
    # Build result object
    $result = [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        OperatingSystem = if ($os) { $os.Caption } else { "Unknown" }
        OSVersion = if ($os) { $os.Version } else { "Unknown" }
        OSArchitecture = if ($os) { $os.OSArchitecture } else { "Unknown" }
        InstallDate = if ($os) { $os.InstallDate } else { $null }
        LastBootTime = if ($os) { $os.LastBootUpTime } else { $null }
        UptimeDays = if ($uptime) { [math]::Round($uptime.TotalDays, 2) } else { $null }
        Manufacturer = if ($computerSystem) { $computerSystem.Manufacturer } else { "Unknown" }
        Model = if ($computerSystem) { $computerSystem.Model } else { "Unknown" }
        ProcessorName = if ($processor) { $processor.Name } else { "Unknown" }
        ProcessorCores = if ($processor) { $processor.NumberOfCores } else { 0 }
        ProcessorLogicalCores = if ($processor) { $processor.NumberOfLogicalProcessors } else { 0 }
        TotalMemoryGB = if ($computerSystem) { [math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2) } else { 0 }
        FreeMemoryGB = if ($os) { [math]::Round($os.FreePhysicalMemory / 1MB, 2) } else { 0 }
        SystemDriveSizeGB = if ($systemDrive) { [math]::Round($systemDrive.Size / 1GB, 2) } else { 0 }
        SystemDriveFreeGB = if ($systemDrive) { [math]::Round($systemDrive.FreeSpace / 1GB, 2) } else { 0 }
        PowerShellVersion = "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
        PowerShellEdition = $PSVersionTable.PSEdition
        CollectedAt = Get-Date -Format 'o'
    }
    
    Write-Verbose "System information collected successfully"
    return $result
}
catch {
    Write-Error "Failed to collect system information: $_"
    throw
}
