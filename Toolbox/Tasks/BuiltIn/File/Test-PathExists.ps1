<#
.SYNOPSIS
    Tests if a file or directory path exists

.DESCRIPTION
    Checks if the specified path exists and returns detailed information about the path including type, size, and timestamps.

.PARAMETER Path
    Path to test for existence

.NOTES
    TaskName: File.TestPathExists
    Version: 1.0.0
    Author: Toolbox
    Tags: File, Path, Test
    RequiresElevation: False
    SupportedOS: Windows, Linux, MacOS
    PSEdition: Desktop, Core
    MinPSVersion: 5.1
    Timeout: 10

.EXAMPLE
    Invoke-Task -TaskName 'File.TestPathExists' -Computers 'localhost'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path
)

try {
    Write-Verbose "Testing path: $Path"
    
    $exists = Test-Path -Path $Path
    
    $result = [PSCustomObject]@{
        Path = $Path
        Exists = $exists
        Type = $null
        SizeBytes = $null
        SizeMB = $null
        CreationTime = $null
        LastWriteTime = $null
        LastAccessTime = $null
    }
    
    if ($exists) {
        $item = Get-Item -Path $Path -ErrorAction Stop
        
        $result.Type = if ($item.PSIsContainer) { "Directory" } else { "File" }
        
        if ($result.Type -eq "File") {
            $result.SizeBytes = $item.Length
            $result.SizeMB = [math]::Round($item.Length / 1MB, 2)
        }
        
        $result.CreationTime = $item.CreationTime
        $result.LastWriteTime = $item.LastWriteTime
        $result.LastAccessTime = $item.LastAccessTime
        
        Write-Verbose "Path exists: $($result.Type)"
    }
    else {
        Write-Verbose "Path does not exist"
    }
    
    return $result
}
catch {
    Write-Error "Failed to test path: $_"
    throw
}
