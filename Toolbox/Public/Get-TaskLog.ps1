function Get-TaskLog {
    <#
    .SYNOPSIS
        Retrieves and queries Toolbox execution logs.
    
    .DESCRIPTION
        Reads and filters log entries from Toolbox log files. Supports filtering
        by run ID, computer, task name, log level, date range, and search text.
    
    .PARAMETER RunId
        Filter logs by specific execution run ID.
    
    .PARAMETER Computer
        Filter logs by target computer name. Supports wildcards.
    
    .PARAMETER TaskName
        Filter logs by task name. Supports wildcards.
    
    .PARAMETER Level
        Filter logs by log level.
    
    .PARAMETER StartDate
        Filter logs from this date/time forward.
    
    .PARAMETER EndDate
        Filter logs up to this date/time.
    
    .PARAMETER Search
        Search for text in log messages.
    
    .PARAMETER Last
        Return only the last N log entries.
    
    .PARAMETER Tail
        Continuously monitor and display new log entries (like tail -f).
    
    .EXAMPLE
        Get-TaskLog -Last 50
        Retrieves the last 50 log entries.
    
    .EXAMPLE
        Get-TaskLog -RunId "abc123-def456" 
        Retrieves all log entries for a specific run.
    
    .EXAMPLE
        Get-TaskLog -Computer "SERVER*" -Level Error
        Retrieves error-level logs for computers matching "SERVER*".
    
    .EXAMPLE
        Get-TaskLog -TaskName "File.TestPathExists" -StartDate (Get-Date).AddHours(-1)
        Retrieves logs for a specific task from the last hour.
    
    .EXAMPLE
        Get-TaskLog -Tail
        Continuously displays new log entries as they are written.
    
    .EXAMPLE
        Get-TaskLog -StartDate (Get-Date).AddDays(-7) -Level Error | Export-Csv errors.csv
        Exports all errors from the last 7 days to CSV.
    
    .EXAMPLE
        Get-TaskLog -Search "timeout" -Last 100
        Searches the last 100 log entries for the word "timeout".
    
    .EXAMPLE
        Get-TaskLog -Computer "WEB*" -TaskName "Service.*" | Group-Object Level | Select-Object Count, Name
        Groups logs by level for web servers running service tasks.
    
    .OUTPUTS
        PSCustomObject array containing log entries.
    
    .NOTES
        Logs are stored in %APPDATA%\Toolbox\Logs in JSON Lines (.jsonl) format.
        Log files are automatically rotated based on size and retention settings.
        Use -Tail for real-time monitoring during task execution.
    #>
    [CmdletBinding(DefaultParameterSetName = "Filter")]
    param(
        [Parameter(ParameterSetName = "Filter")]
        [string]$RunId,
        
        [Parameter(ParameterSetName = "Filter")]
        [SupportsWildcards()]
        [string]$Computer,
        
        [Parameter(ParameterSetName = "Filter")]
        [SupportsWildcards()]
        [string]$TaskName,
        
        [Parameter(ParameterSetName = "Filter")]
        [ValidateSet("Verbose", "Info", "Warning", "Error")]
        [string]$Level,
        
        [Parameter(ParameterSetName = "Filter")]
        [datetime]$StartDate,
        
        [Parameter(ParameterSetName = "Filter")]
        [datetime]$EndDate,
        
        [Parameter(ParameterSetName = "Filter")]
        [string]$Search,
        
        [Parameter(ParameterSetName = "Filter")]
        [int]$Last,
        
        [Parameter(ParameterSetName = "Tail")]
        [switch]$Tail
    )
    
    # Get log configuration
    $config = Get-TbConfig -Section Logging
    
    if (-not (Test-Path $config.LogPath)) {
        Write-Warning "Log directory not found: $($config.LogPath)"
        return
    }
    
    try {
        if ($Tail) {
            # Tail mode - continuously monitor logs
            Write-Host "Monitoring logs... (Press Ctrl+C to stop)" -ForegroundColor Cyan
            
            $logFiles = Get-ChildItem -Path $config.LogPath -Filter "Toolbox_*.log" | 
                Sort-Object LastWriteTime -Descending | 
                Select-Object -First 1
            
            if (-not $logFiles) {
                Write-Warning "No log files found"
                return
            }
            
            $currentFile = $logFiles.FullName
            $lastPosition = (Get-Item $currentFile).Length
            
            while ($true) {
                Start-Sleep -Milliseconds 500
                
                # Check for new log file
                $latestFile = Get-ChildItem -Path $config.LogPath -Filter "Toolbox_*.log" | 
                    Sort-Object LastWriteTime -Descending | 
                    Select-Object -First 1
                
                if ($latestFile.FullName -ne $currentFile) {
                    $currentFile = $latestFile.FullName
                    $lastPosition = 0
                }
                
                $currentLength = (Get-Item $currentFile).Length
                
                if ($currentLength -gt $lastPosition) {
                    $stream = [System.IO.File]::Open($currentFile, "Open", "Read", "ReadWrite")
                    $stream.Position = $lastPosition
                    $reader = New-Object System.IO.StreamReader($stream)
                    
                    while ($null -ne ($line = $reader.ReadLine())) {
                        try {
                            $entry = $line | ConvertFrom-Json
                            Format-LogEntry -Entry $entry
                        }
                        catch {
                            Write-Host $line
                        }
                    }
                    
                    $lastPosition = $stream.Position
                    $reader.Close()
                    $stream.Close()
                }
            }
        }
        else {
            # Standard filter mode
            $logFiles = Get-ChildItem -Path $config.LogPath -Filter "Toolbox_*.log" | 
                Sort-Object LastWriteTime -Descending
            
            if (-not $logFiles) {
                Write-Warning "No log files found in: $($config.LogPath)"
                return
            }
            
            $allEntries = @()
            
            foreach ($logFile in $logFiles) {
                $content = Get-Content -Path $logFile.FullName -Encoding UTF8
                
                foreach ($line in $content) {
                    if ([string]::IsNullOrWhiteSpace($line)) { continue }
                    
                    try {
                        $entry = $line | ConvertFrom-Json
                        $allEntries += $entry
                    }
                    catch {
                        Write-Verbose "Failed to parse log line: $line"
                    }
                }
            }
            
            # Apply filters
            $filteredEntries = $allEntries
            
            if ($RunId) {
                $filteredEntries = $filteredEntries | Where-Object { $_.RunId -eq $RunId }
            }
            
            if ($Computer) {
                $filteredEntries = $filteredEntries | Where-Object { $_.Computer -like $Computer }
            }
            
            if ($TaskName) {
                $filteredEntries = $filteredEntries | Where-Object { $_.TaskName -like $TaskName }
            }
            
            if ($Level) {
                $filteredEntries = $filteredEntries | Where-Object { $_.Level -eq $Level }
            }
            
            if ($StartDate) {
                $filteredEntries = $filteredEntries | Where-Object { 
                    [datetime]$_.Timestamp -ge $StartDate 
                }
            }
            
            if ($EndDate) {
                $filteredEntries = $filteredEntries | Where-Object { 
                    [datetime]$_.Timestamp -le $EndDate 
                }
            }
            
            if ($Search) {
                $filteredEntries = $filteredEntries | Where-Object { 
                    $_.Message -like "*$Search*" 
                }
            }
            
            # Sort by timestamp
            $filteredEntries = $filteredEntries | Sort-Object Timestamp
            
            # Apply Last filter
            if ($Last) {
                $filteredEntries = $filteredEntries | Select-Object -Last $Last
            }
            
            return $filteredEntries
        }
    }
    catch {
        Write-Error "Failed to retrieve logs: $_"
    }
}

function Format-LogEntry {
    <#
    .SYNOPSIS
        Formats a log entry for console display.
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Entry
    )
    
    $timestamp = [datetime]::Parse($Entry.Timestamp).ToString("yyyy-MM-dd HH:mm:ss")
    
    $color = switch ($Entry.Level) {
        "Verbose" { "Gray" }
        "Info" { "White" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        default { "White" }
    }
    
    $prefix = "[$timestamp][$($Entry.Level)]"
    
    if ($Entry.Computer) {
        $prefix += "[$($Entry.Computer)]"
    }
    
    if ($Entry.TaskName) {
        $prefix += "[$($Entry.TaskName)]"
    }
    
    Write-Host $prefix -ForegroundColor $color -NoNewline
    Write-Host " $($Entry.Message)"
    
    if ($Entry.Error) {
        Write-Host "  Error: $($Entry.Error.Message)" -ForegroundColor Red
    }
}
