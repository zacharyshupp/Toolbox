<#
.SYNOPSIS
    Calculate the size of a file or directory including all subdirectories

.DESCRIPTION
    This task calculates the total size of a file or directory, including all subdirectories and files.
    Can display results in various units (Bytes, KB, MB, GB, TB) and optionally provide a breakdown by file type.

.PARAMETER Path
    Path to the file or directory

.PARAMETER Unit
    Unit to display size in. Valid values: Bytes, KB, MB, GB, TB. Default: MB

.PARAMETER IncludeDetails
    Include breakdown of file types and counts

.NOTES
    TaskName: File.GetPathSize
    Version: 1.0.0
    Author: Toolbox
    Tags: File, Directory, Storage
    RequiresElevation: False
    SupportedOS: Windows, Linux, MacOS
    PSEdition: Desktop, Core
    MinPSVersion: 5.1
    Timeout: 300

.EXAMPLE
    Invoke-Task -TaskName 'File.GetPathSize' -Computers 'localhost' -TaskParameters @{ Path = 'C:\Temp' }
    
.EXAMPLE
    Invoke-Task -TaskName 'File.GetPathSize' -Computers 'localhost' -TaskParameters @{ Path = 'C:\Temp'; Unit = 'GB'; IncludeDetails = $true }
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path,

    [Parameter()]
    [ValidateSet('Bytes', 'KB', 'MB', 'GB', 'TB')]
    [string]$Unit = 'MB',

    [Parameter()]
    [switch]$IncludeDetails
)

try {
    Write-Verbose "Calculating size of path: $Path"
    
    # Validate path exists
    if (-not (Test-Path -Path $Path)) {
        throw "Path not found: $Path"
    }
    
    $item = Get-Item -Path $Path -ErrorAction Stop
    $isDirectory = $item.PSIsContainer
    
    Write-Verbose "Path type: $(if ($isDirectory) { 'Directory' } else { 'File' })"
    
    # Calculate size
    $totalBytes = 0
    $fileCount = 0
    $directoryCount = 0
    $fileTypeStats = @{}
    
    if ($isDirectory) {
        Write-Verbose "Enumerating all items in directory..."
        
        $allItems = Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
        
        foreach ($file in $allItems) {
            if ($file.PSIsContainer) {
                $directoryCount++
            }
            else {
                $fileCount++
                $totalBytes += $file.Length
                
                # Track file type statistics if requested
                if ($IncludeDetails) {
                    $extension = if ($file.Extension) { $file.Extension.ToLower() } else { '(no extension)' }
                    
                    if (-not $fileTypeStats.ContainsKey($extension)) {
                        $fileTypeStats[$extension] = @{
                            Count = 0
                            Size = 0
                        }
                    }
                    
                    $fileTypeStats[$extension].Count++
                    $fileTypeStats[$extension].Size += $file.Length
                }
            }
        }
    }
    else {
        $fileCount = 1
        $totalBytes = $item.Length
        
        if ($IncludeDetails) {
            $extension = if ($item.Extension) { $item.Extension.ToLower() } else { '(no extension)' }
            $fileTypeStats[$extension] = @{
                Count = 1
                Size = $item.Length
            }
        }
    }
    
    # Convert to requested unit
    $divisor = switch ($Unit) {
        'Bytes' { 1 }
        'KB'    { 1KB }
        'MB'    { 1MB }
        'GB'    { 1GB }
        'TB'    { 1TB }
    }
    
    $sizeInUnit = [math]::Round($totalBytes / $divisor, 2)
    
    Write-Verbose "Total size: $sizeInUnit $Unit ($totalBytes bytes)"
    Write-Verbose "Files: $fileCount, Directories: $directoryCount"
    
    # Build result object
    $result = [PSCustomObject]@{
        Path            = $Path
        Type            = if ($isDirectory) { 'Directory' } else { 'File' }
        TotalSize       = $sizeInUnit
        Unit            = $Unit
        TotalSizeBytes  = $totalBytes
        FileCount       = $fileCount
        DirectoryCount  = $directoryCount
    }
    
    # Add file type breakdown if requested
    if ($IncludeDetails -and $fileTypeStats.Count -gt 0) {
        $fileTypeBreakdown = foreach ($ext in ($fileTypeStats.Keys | Sort-Object)) {
            [PSCustomObject]@{
                Extension = $ext
                FileCount = $fileTypeStats[$ext].Count
                Size      = [math]::Round($fileTypeStats[$ext].Size / $divisor, 2)
                Unit      = $Unit
                SizeBytes = $fileTypeStats[$ext].Size
            }
        }
        
        $result | Add-Member -NotePropertyName 'FileTypeBreakdown' -NotePropertyValue $fileTypeBreakdown
    }
    
    $result
}
catch {
    Write-Error "Failed to calculate path size: $_"
    throw
}
