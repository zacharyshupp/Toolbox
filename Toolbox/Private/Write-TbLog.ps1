function Write-TbLog {
    <#
    .SYNOPSIS
        Writes structured log entries to the Toolbox log file.
    
    .DESCRIPTION
        Internal logging function that writes JSON Lines formatted log entries.
        Handles log rotation, sensitive data masking, and correlation tracking.
    
    .PARAMETER Message
        Log message content.
    
    .PARAMETER Level
        Log level (Verbose, Info, Warning, Error).
    
    .PARAMETER RunId
        Execution run identifier for correlation.
    
    .PARAMETER Computer
        Target computer name for the log entry.
    
    .PARAMETER TaskName
        Task name being executed.
    
    .PARAMETER Data
        Additional structured data to include in the log.
    
    .PARAMETER ErrorRecord
        PowerShell ErrorRecord to log.
    
    .EXAMPLE
        Write-TbLog -Message "Task started" -Level Info -RunId $runId -TaskName "File.TestPathExists"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('Verbose', 'Info', 'Warning', 'Error')]
        [string]$Level = 'Info',
        
        [Parameter()]
        [string]$RunId,
        
        [Parameter()]
        [string]$Computer,
        
        [Parameter()]
        [string]$TaskName,
        
        [Parameter()]
        [hashtable]$Data,
        
        [Parameter()]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    
    # Get configuration
    $config = Get-TbConfig -Section Logging
    
    # Check if logging is enabled
    if (-not $config.Enabled) {
        return
    }
    
    # Check log level filtering
    $levelPriority = @{
        'Verbose' = 0
        'Info' = 1
        'Warning' = 2
        'Error' = 3
    }
    
    if ($levelPriority[$Level] -lt $levelPriority[$config.LogLevel]) {
        return
    }
    
    try {
        # Ensure log directory exists
        if (-not (Test-Path $config.LogPath)) {
            New-Item -ItemType Directory -Path $config.LogPath -Force | Out-Null
        }
        
        # Determine log file path (current date)
        $logFileName = "Toolbox_$(Get-Date -Format 'yyyyMMdd').log"
        $logFilePath = Join-Path $config.LogPath $logFileName
        
        # Check for log rotation
        if (Test-Path $logFilePath) {
            $logFile = Get-Item $logFilePath
            $logSizeMB = [math]::Round($logFile.Length / 1MB, 2)
            
            if ($logSizeMB -ge $config.MaxLogFileSizeMB) {
                Invoke-LogRotation -LogPath $config.LogPath -MaxFiles $config.MaxLogFiles
                $logFileName = "Toolbox_$(Get-Date -Format 'yyyyMMdd').log"
                $logFilePath = Join-Path $config.LogPath $logFileName
            }
        }
        
        # Build log entry
        $logEntry = [ordered]@{
            Timestamp = (Get-Date).ToString('o')
            Level = $Level
            Message = $Message
        }
        
        if ($RunId) { $logEntry.RunId = $RunId }
        if ($Computer) { $logEntry.Computer = $Computer }
        if ($TaskName) { $logEntry.TaskName = $TaskName }
        if ($Data) {
            # Mask sensitive data if enabled
            if ($config.MaskSensitiveData) {
                $logEntry.Data = Hide-SensitiveData -Data $Data -SensitiveProperties $config.SensitiveProperties
            }
            else {
                $logEntry.Data = $Data
            }
        }
        
        # Add error information if provided
        if ($ErrorRecord) {
            $logEntry.Error = @{
                Message = $ErrorRecord.Exception.Message
                Type = $ErrorRecord.Exception.GetType().FullName
                Category = $ErrorRecord.CategoryInfo.Category.ToString()
                TargetObject = $ErrorRecord.TargetObject
                ScriptStackTrace = $ErrorRecord.ScriptStackTrace
            }
        }
        
        # Add process context
        $logEntry.ProcessId = $PID
        $logEntry.User = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        
        # Convert to JSON and write (JSON Lines format - one JSON object per line)
        $jsonLine = $logEntry | ConvertTo-Json -Compress -Depth 10
        Add-Content -Path $logFilePath -Value $jsonLine -Encoding UTF8
        
        Write-Verbose "Log entry written: $Level - $Message"
    }
    catch {
        # Logging failure should not break execution
        Write-Warning "Failed to write log entry: $_"
    }
}

function Invoke-LogRotation {
    <#
    .SYNOPSIS
        Rotates log files when size limit is reached.
    #>
    [CmdletBinding()]
    param(
        [string]$LogPath,
        [int]$MaxFiles
    )
    
    try {
        # Get all log files sorted by creation time
        $logFiles = Get-ChildItem -Path $LogPath -Filter "Toolbox_*.log" | 
            Sort-Object CreationTime -Descending
        
        # If we have more files than allowed, remove the oldest
        if ($logFiles.Count -ge $MaxFiles) {
            $filesToRemove = $logFiles | Select-Object -Skip ($MaxFiles - 1)
            foreach ($file in $filesToRemove) {
                Remove-Item -Path $file.FullName -Force
                Write-Verbose "Removed old log file: $($file.Name)"
            }
        }
        
        # Rename current log file with timestamp
        $currentLog = Join-Path $LogPath "Toolbox_$(Get-Date -Format 'yyyyMMdd').log"
        if (Test-Path $currentLog) {
            $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
            $newName = "Toolbox_$timestamp.log"
            $newPath = Join-Path $LogPath $newName
            Move-Item -Path $currentLog -Destination $newPath -Force
            Write-Verbose "Rotated log file to: $newName"
        }
    }
    catch {
        Write-Warning "Failed to rotate log files: $_"
    }
}

function Hide-SensitiveData {
    <#
    .SYNOPSIS
        Masks sensitive data in log entries.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Data,
        
        [Parameter(Mandatory)]
        [array]$SensitiveProperties
    )
    
    $maskedData = @{}
    
    foreach ($key in $Data.Keys) {
        $value = $Data[$key]
        
        # Check if key matches sensitive property names (case-insensitive)
        $isSensitive = $false
        foreach ($sensitiveKey in $SensitiveProperties) {
            if ($key -like "*$sensitiveKey*") {
                $isSensitive = $true
                break
            }
        }
        
        if ($isSensitive -and $null -ne $value) {
            # Mask the value
            if ($value -is [string] -and $value.Length -gt 0) {
                $maskedData[$key] = "***MASKED***"
            }
            elseif ($value -is [System.Security.SecureString]) {
                $maskedData[$key] = "***MASKED_SECURE_STRING***"
            }
            elseif ($value -is [PSCredential]) {
                $maskedData[$key] = @{
                    UserName = $value.UserName
                    Password = "***MASKED***"
                }
            }
            else {
                $maskedData[$key] = "***MASKED***"
            }
        }
        else {
            $maskedData[$key] = $value
        }
    }
    
    return $maskedData
}
