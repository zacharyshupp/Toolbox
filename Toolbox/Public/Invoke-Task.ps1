function Invoke-Task {
    <#
    .SYNOPSIS
        Executes tasks on remote computers in parallel.
    
    .DESCRIPTION
        The primary cmdlet for executing tasks or script blocks across multiple computers
        in parallel. Supports throttling, timeouts, retries, progress reporting, and
        multiple output formats.
    
    .PARAMETER Computers
        Target computer names, IP addresses, or file paths. Accepts pipeline input.
        
        Supports automatic file detection and parsing:
        - .txt files: One computer per line (lines starting with # are ignored)
        - .csv files: Use filepath:ColumnName to specify column, or first column is used
        - .xlsx/.xls files: Use filepath:ColumnName to specify column, or first column is used
        
        Can mix computer names and file paths in the same parameter.
    
    .PARAMETER ComputerFile
        (Deprecated - use -Computers with file path instead)
        Path to a file containing computer names (one per line).
    
    .PARAMETER TaskName
        Name of a defined task to execute (e.g., "File.TestPathExists").
    
    .PARAMETER ScriptBlock
        Ad-hoc script block to execute on targets.
    
    .PARAMETER TaskParameters
        Hashtable of parameters to pass to the task or script block.
    
    .PARAMETER Credential
        PSCredential for remote authentication.
    
    .PARAMETER ThrottleLimit
        Maximum concurrent executions (default from config).
    
    .PARAMETER Timeout
        Timeout per target in seconds (default from config).
    
    .PARAMETER RetryCount
        Number of retry attempts on failure (default from config).
    
    .PARAMETER Protocol
        Remote protocol (WinRM, SSH, Auto).
    
    .PARAMETER ShowProgress
        Display progress bar during execution.
    
    .PARAMETER OutputFormat
        Export format (CSV, JSON, XML, Excel, None).
    
    .PARAMETER OutputPath
        Path to save exported results.
    
    .PARAMETER PassThru
        Return results to pipeline even when exporting.
    
    .EXAMPLE
        Invoke-Task -Computers "Server1","Server2" -TaskName "System.GetUptime"
        Executes the GetUptime task on two servers.
    
    .EXAMPLE
        Invoke-Task -Computers "C:\servers.txt" -TaskName "System.GetUptime"
        Reads computer names from a text file and executes the task.
    
    .EXAMPLE
        Invoke-Task -Computers "C:\inventory.csv:ComputerName" -TaskName "System.GetBasicInfo"
        Reads computer names from the "ComputerName" column in a CSV file.
    
    .EXAMPLE
        Invoke-Task -Computers "C:\servers.xlsx:HostName","Server99" -TaskName "Network.TestPort" -TaskParameters @{TargetHost="8.8.8.8";Port=53}
        Mixes computers from Excel file and direct computer name with task parameters.
    
    .EXAMPLE
        Invoke-Task -Computers "Server1" -TaskName "File.TestPathExists" -TaskParameters @{Path="C:\Temp"}
        Executes a task with parameters.
    
    .EXAMPLE
        Invoke-Task -Computers "C:\servers.csv" -TaskName "System.GetBasicInfo" -OutputFormat Excel -OutputPath results.xlsx
        Reads from CSV (uses first column) and exports results to Excel.
    
    .EXAMPLE
        $cred = Get-Credential
        Invoke-Task -Computers "Server1","Server2" -TaskName "System.GetUptime" -Credential $cred
        Executes task on remote servers using provided credentials for authentication.
    
    .OUTPUTS
        TbTaskResult[] - Array of task execution results.
    #>
    [CmdletBinding(DefaultParameterSetName = "TaskName")]
    param(
        [Parameter(Mandatory, ParameterSetName = "TaskName", ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter(Mandatory, ParameterSetName = "ScriptBlock", ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("Computer", "ComputerName", "CN")]
        [string[]]$Computers,
        
        [Parameter(ParameterSetName = "TaskName")]
        [Parameter(ParameterSetName = "ScriptBlock")]
        [Alias("File")]
        [string]$ComputerFile,
        
        [Parameter(Mandatory, ParameterSetName = "TaskName", Position = 0)]
        [string]$TaskName,
        
        [Parameter(Mandatory, ParameterSetName = "ScriptBlock", Position = 0)]
        [scriptblock]$ScriptBlock,
        
        [Parameter()]
        [Alias("Parameters", "Args")]
        [hashtable]$TaskParameters = @{},
        
        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter()]
        [ValidateRange(1, 256)]
        [int]$ThrottleLimit,
        
        [Parameter()]
        [ValidateRange(1, 3600)]
        [int]$Timeout,
        
        [Parameter()]
        [ValidateRange(0, 10)]
        [int]$RetryCount,
        
        [Parameter()]
        [ValidateSet("WinRM", "SSH", "Auto")]
        [string]$Protocol = "Auto",
        
        [Parameter()]
        [switch]$ShowProgress,
        
        [Parameter()]
        [ValidateSet("CSV", "JSON", "XML", "Excel", "None")]
        [string]$OutputFormat = "None",
        
        [Parameter()]
        [string]$OutputPath,
        
        [Parameter()]
        [switch]$PassThru
    )
    
    begin {
        # Generate unique run ID
        $runId = [guid]::NewGuid().ToString()
        $allComputers = [System.Collections.ArrayList]::new()
        
        Write-Verbose "Invoke-Task started. RunId: $runId"
        
        # Load configuration defaults
        $config = Get-TbConfig
        
        if (-not $ThrottleLimit) {
            $ThrottleLimit = $config.Execution.DefaultThrottle
        }
        
        if (-not $Timeout) {
            $Timeout = $config.Execution.DefaultTimeout
        }
        
        if ($PSBoundParameters.ContainsKey("RetryCount") -eq $false) {
            $RetryCount = $config.Execution.DefaultRetryCount
        }
        
        # Log invocation
        Write-TbLog -Message "Invoke-Task started" -Level Info -RunId $runId -Data @{
            ParameterSet = $PSCmdlet.ParameterSetName
            TaskName = $TaskName
            ThrottleLimit = $ThrottleLimit
            Timeout = $Timeout
            RetryCount = $RetryCount
        }
        
        # Validate task if using TaskName
        $taskDefinition = $null
        if ($PSCmdlet.ParameterSetName -eq "TaskName") {
            try {
                $taskDefinition = Get-TaskDefinition -TaskName $TaskName -ErrorAction Stop
                
                if (-not $taskDefinition) {
                    throw "Task '$TaskName' not found"
                }
                
                Write-Verbose "Loaded task definition: $TaskName (Version: $($taskDefinition.Version))"
                
                # Check compatibility
                if (-not (Test-TaskCompatibility -TaskDefinition $taskDefinition)) {
                    throw "Task '$TaskName' is not compatible with current environment"
                }
                
                # Load task script
                $ScriptBlock = [scriptblock]::Create((Get-Content -Path $taskDefinition.FullScriptPath -Raw))
                
                # Use task-specific timeout/retry if defined
                if ($taskDefinition.Timeout -and -not $PSBoundParameters.ContainsKey("Timeout")) {
                    $Timeout = $taskDefinition.Timeout
                }
                
                if ($taskDefinition.RetryCount -and -not $PSBoundParameters.ContainsKey("RetryCount")) {
                    $RetryCount = $taskDefinition.RetryCount
                }
            }
            catch {
                Write-Error "Failed to load task "$TaskName": $_"
                Write-TbLog -Message "Failed to load task" -Level Error -RunId $runId -TaskName $TaskName -ErrorRecord $_
                return
            }
        }
        
        # Load computers from file if specified
        if ($ComputerFile) {
            if (-not (Test-Path $ComputerFile)) {
                Write-Error "Computer file not found: $ComputerFile"
                return
            }
            
            try {
                $fileComputers = Get-Content -Path $ComputerFile | 
                    Where-Object { $_ -and $_.Trim() -and -not $_.StartsWith("#") } |
                    ForEach-Object { $_.Trim() }
                
                $allComputers.AddRange($fileComputers)
                Write-Verbose "Loaded $($fileComputers.Count) computers from file: $ComputerFile"
            }
            catch {
                Write-Error "Failed to read computer file: $_"
                return
            }
        }
    }
    
    process {
        # Collect computers from pipeline or parameter
        if ($Computers) {
            foreach ($item in $Computers) {
                # Extract base path (without :column suffix)
                $basePath = if ($item -match "^(.+?):\w+$") { $Matches[1] } else { $item }
                
                # Check if this is a file that exists
                if ((Test-Path -Path $basePath -PathType Leaf -ErrorAction SilentlyContinue)) {
                    $extension = [System.IO.Path]::GetExtension($basePath).ToLower()
                    
                    # Check if it"s a supported file format
                    if ($extension -in ".txt", ".csv", ".xlsx", ".xls") {
                        # It"s a file - parse it
                        try {
                            $fileComputers = Get-ComputersFromFile -FilePath $item
                            $allComputers.AddRange($fileComputers)
                            Write-Verbose "Loaded $($fileComputers.Count) computers from file: $item"
                        }
                        catch {
                            Write-Error "Failed to load computers from file "$item": $_"
                            return
                        }
                    }
                    else {
                        # File exists but not a supported format - treat as computer name
                        $allComputers.Add($item) | Out-Null
                    }
                }
                else {
                    # Not a file or doesn"t exist - treat as computer name
                    $allComputers.Add($item) | Out-Null
                }
            }
        }
    }
    
    end {
        if ($allComputers.Count -eq 0) {
            Write-Error "No computers specified. Use -Computers or -ComputerFile parameter."
            return
        }
        
        # Remove duplicates
        $uniqueComputers = $allComputers | Select-Object -Unique
        Write-Verbose "Processing $($uniqueComputers.Count) unique computer(s)"
        
        try {
            # Create work items
            $workItems = @()
            foreach ($computer in $uniqueComputers) {
                $workItem = [TbWorkItem]::new($computer, $TaskName)
                $workItem.ScriptBlock = $ScriptBlock
                $workItem.TaskParameters = $TaskParameters
                $workItem.Timeout = $Timeout
                $workItem.RetryCount = $RetryCount
                $workItem.Credential = $Credential
                
                $workItems += $workItem
            }
            
            Write-Verbose "Created $($workItems.Count) work items"
            
            # Execute work queue
            $progressActivity = if ($TaskName) { "Executing Task: $TaskName" } else { "Executing Script Block" }
            
            $results = Start-TbWorkQueue -WorkItems $workItems `
                -ThrottleLimit $ThrottleLimit `
                -RunId $runId `
                -ShowProgress:$ShowProgress `
                -ProgressActivity $progressActivity
            
            Write-Verbose "Execution completed. Total results: $($results.Count)"
            
            # Generate summary
            $successCount = ($results | Where-Object { $_.IsSuccess() }).Count
            $failureCount = ($results | Where-Object { -not $_.IsSuccess() }).Count
            
            Write-Host ""
            Write-Host "Execution Summary:" -ForegroundColor Cyan
            Write-Host "  Total Computers: $($results.Count)" -ForegroundColor White
            Write-Host "  Successful: $successCount" -ForegroundColor Green
            Write-Host "  Failed: $failureCount" -ForegroundColor $(if ($failureCount -gt 0) { "Red" } else { "White" })
            Write-Host ""
            
            Write-TbLog -Message "Invoke-Task completed" -Level Info -RunId $runId -Data @{
                TotalComputers = $results.Count
                Successful = $successCount
                Failed = $failureCount
            }
            
            # Export results if requested
            if ($OutputFormat -ne "None" -or $OutputPath) {
                if (-not $OutputPath) {
                    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                    $fileName = if ($TaskName) { "TaskResults_${TaskName}_${timestamp}" } else { "TaskResults_${timestamp}" }
                    $extension = switch ($OutputFormat) {
                        "CSV" { "csv" }
                        "JSON" { "json" }
                        "XML" { "xml" }
                        "Excel" { "xlsx" }
                        default { "csv" }
                    }
                    $OutputPath = Join-Path (Get-Location) "$fileName.$extension"
                }
                
                try {
                    Export-TaskResult -Results $results -OutputPath $OutputPath -Format $OutputFormat
                    Write-Host "Results exported to: $OutputPath" -ForegroundColor Green
                }
                catch {
                    Write-Warning "Failed to export results: $_"
                }
            }
            
            # Return results
            if ($OutputFormat -eq "None" -or $PassThru) {
                return $results
            }
        }
        catch {
            Write-Error "Task execution failed: $_"
            Write-TbLog -Message "Invoke-Task failed" -Level Error -RunId $runId -ErrorRecord $_
            throw
        }
    }
}
