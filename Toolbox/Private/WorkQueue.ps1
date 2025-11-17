function Start-TbWorkQueue {
    <#
    .SYNOPSIS
        Processes a queue of work items with parallel execution.
    
    .DESCRIPTION
        Manages a work queue, dispatching items to runspaces and collecting results.
        Handles throttling, timeouts, retries, and progress reporting.
    
    .PARAMETER WorkItems
        Array of TbWorkItem objects to process.
    
    .PARAMETER ThrottleLimit
        Maximum concurrent executions.
    
    .PARAMETER RunId
        Unique identifier for this execution run.
    
    .PARAMETER ShowProgress
        Display progress bar during execution.
    
    .PARAMETER ProgressActivity
        Custom activity text for progress bar.
    
    .EXAMPLE
        $results = Start-TbWorkQueue -WorkItems $workItems -ThrottleLimit 32 -ShowProgress
    
    .OUTPUTS
        Array of TbTaskResult objects.
    #>
    [CmdletBinding()]
    [OutputType([TbTaskResult[]])]
    param(
        [Parameter(Mandatory)]
        [TbWorkItem[]]$WorkItems,
        
        [Parameter()]
        [int]$ThrottleLimit = 32,
        
        [Parameter()]
        [string]$RunId = [guid]::NewGuid().ToString(),
        
        [Parameter()]
        [switch]$ShowProgress,
        
        [Parameter()]
        [string]$ProgressActivity = "Processing Tasks"
    )
    
    $results = [System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]::new())
    $runningJobs = [System.Collections.ArrayList]::new()
    $workQueue = [System.Collections.Queue]::new()
    
    # Initialize work queue
    foreach ($item in $WorkItems) {
        $workQueue.Enqueue($item)
    }
    
    $totalItems = $WorkItems.Count
    $completedItems = 0
    $failedItems = 0
    
    Write-Verbose "Starting work queue with $totalItems items, throttle: $ThrottleLimit"
    
    try {
        # Get private function definitions to pass to runspaces
        $privateFunctions = @{
            'Invoke-TbRemoteExecution' = (Get-Command Invoke-TbRemoteExecution).Definition
            'Test-IsLocalhost' = (Get-Command Test-IsLocalhost).Definition
            'Get-OptimalProtocol' = (Get-Command Get-OptimalProtocol).Definition
            'Invoke-LocalExecution' = (Get-Command Invoke-LocalExecution).Definition
            'Invoke-WinRMExecution' = (Get-Command Invoke-WinRMExecution).Definition
            'Invoke-SSHExecution' = (Get-Command Invoke-SSHExecution).Definition
            'New-TbPSSession' = (Get-Command New-TbPSSession).Definition
        }
        
        # Create runspace pool with required functions
        $runspacePool = New-TbRunspacePool -ThrottleLimit $ThrottleLimit -Functions $privateFunctions
        
        # Log execution start
        Write-TbLog -Message "Work queue started" -Level Info -RunId $RunId -Data @{
            TotalItems = $totalItems
            ThrottleLimit = $ThrottleLimit
        }
        
        # Main processing loop
        while ($workQueue.Count -gt 0 -or $runningJobs.Count -gt 0) {
            
            # Start new jobs if slots available
            while ($workQueue.Count -gt 0 -and $runningJobs.Count -lt $ThrottleLimit) {
                $workItem = $workQueue.Dequeue()
                $workItem.StartTime = Get-Date
                $workItem.Status = [Tb.Status]::Running
                $workItem.AttemptNumber++
                
                Write-Verbose "Starting work item: $($workItem.Computer) - $($workItem.TaskName) (Attempt $($workItem.AttemptNumber))"
                
                # Build execution script block
                $executionScript = {
                    param($Computer, $ScriptBlock, $TaskParameters, $Credential, $Timeout)
                    
                    try {
                        # Convert task parameters hashtable to argument list
                        $argumentList = if ($TaskParameters -and $TaskParameters.Count -gt 0) {
                            @($TaskParameters)
                        } else {
                            $null
                        }
                        
                        # Import remote execution function (will be pre-loaded)
                        $result = Invoke-TbRemoteExecution -Computer $Computer `
                            -ScriptBlock $ScriptBlock `
                            -ArgumentList $argumentList `
                            -Credential $Credential `
                            -TimeoutSeconds $Timeout
                        
                        return $result
                    }
                    catch {
                        return [PSCustomObject]@{
                            Success = $false
                            Output = $null
                            Error = $_.Exception.Message
                        }
                    }
                }
                
                # Prepare parameters
                $jobParams = @{
                    Computer = $workItem.Computer
                    ScriptBlock = $workItem.ScriptBlock
                    TaskParameters = $workItem.TaskParameters
                    Credential = $workItem.Credential
                    Timeout = $workItem.Timeout
                }
                
                # Start job
                $job = Invoke-TbRunspaceJob -RunspacePool $runspacePool `
                    -ScriptBlock $executionScript `
                    -Parameters $jobParams `
                    -WorkItemId $workItem.WorkItemId
                
                # Track job with work item
                $runningJobs.Add([PSCustomObject]@{
                    Job = $job
                    WorkItem = $workItem
                }) | Out-Null
                
                # Log job start
                Write-TbLog -Message "Task started" -Level Verbose -RunId $RunId `
                    -Computer $workItem.Computer -TaskName $workItem.TaskName `
                    -Data @{ WorkItemId = $workItem.WorkItemId; Attempt = $workItem.AttemptNumber }
            }
            
            # Check for completed jobs
            $completedJobs = @()
            foreach ($runningJob in $runningJobs) {
                if ($runningJob.Job.AsyncResult.IsCompleted) {
                    $completedJobs += $runningJob
                }
            }
            
            # Process completed jobs
            foreach ($completedJob in $completedJobs) {
                $workItem = $completedJob.WorkItem
                $job = $completedJob.Job
                
                # Wait for job and get result
                $jobResult = Wait-TbRunspaceJob -Job $job -TimeoutSeconds $workItem.Timeout
                
                # Create task result
                $taskResult = [TbTaskResult]::new($workItem)
                
                if ($jobResult.TimedOut) {
                    $taskResult.Timeout()
                    Write-Verbose "Work item timed out: $($workItem.Computer) - $($workItem.TaskName)"
                    
                    Write-TbLog -Message "Task timed out" -Level Warning -RunId $RunId `
                        -Computer $workItem.Computer -TaskName $workItem.TaskName `
                        -Data @{ Timeout = $workItem.Timeout }
                }
                elseif (-not $jobResult.Success -or $jobResult.Errors.Count -gt 0) {
                    $errorRecord = if ($jobResult.Errors.Count -gt 0) { $jobResult.Errors[0] } else { $null }
                    if ($errorRecord) {
                        $taskResult.Fail($errorRecord)
                    }
                    else {
                        $taskResult.Status = [Tb.Status]::Failed
                    }
                    
                    Write-Verbose "Work item failed: $($workItem.Computer) - $($workItem.TaskName)"
                    
                    Write-TbLog -Message "Task failed" -Level Error -RunId $RunId `
                        -Computer $workItem.Computer -TaskName $workItem.TaskName `
                        -ErrorRecord $errorRecord
                    
                    # Check for retry
                    if ($taskResult.ShouldRetry()) {
                        Write-Verbose "Retrying work item: $($workItem.Computer) - $($workItem.TaskName)"
                        
                        # Calculate retry delay with exponential backoff
                        $config = Get-TbConfig -Section Execution
                        $delay = [Math]::Min(
                            $config.RetryDelaySeconds * [Math]::Pow($config.RetryBackoffMultiplier, $workItem.AttemptNumber - 1),
                            $config.MaxRetryDelaySeconds
                        )
                        
                        Start-Sleep -Seconds $delay
                        
                        # Re-queue the work item
                        $workQueue.Enqueue($workItem)
                        
                        Write-TbLog -Message "Task queued for retry" -Level Info -RunId $RunId `
                            -Computer $workItem.Computer -TaskName $workItem.TaskName `
                            -Data @{ Attempt = $workItem.AttemptNumber; Delay = $delay }
                    }
                    else {
                        $failedItems++
                    }
                }
                else {
                    $taskResult.Complete($jobResult.Output)
                    
                    # Add warnings if any
                    if ($jobResult.Warnings.Count -gt 0) {
                        foreach ($warning in $jobResult.Warnings) {
                            $taskResult.AddWarning($warning.ToString())
                        }
                    }
                    
                    Write-Verbose "Work item completed: $($workItem.Computer) - $($workItem.TaskName)"
                    
                    Write-TbLog -Message "Task completed" -Level Info -RunId $RunId `
                        -Computer $workItem.Computer -TaskName $workItem.TaskName `
                        -Data @{ Duration = $taskResult.Duration.TotalSeconds; Status = $taskResult.Status.ToString() }
                }
                
                # Add to results
                $results.Add($taskResult) | Out-Null
                $completedItems++
                
                # Remove from running jobs
                $runningJobs.Remove($completedJob) | Out-Null
                
                # Update progress
                if ($ShowProgress) {
                    $percentComplete = [math]::Round(($completedItems / $totalItems) * 100)
                    $statusText = "Completed: $completedItems/$totalItems (Failed: $failedItems)"
                    
                    Write-Progress -Activity $ProgressActivity `
                        -Status $statusText `
                        -PercentComplete $percentComplete
                }
            }
            
            # Small sleep to prevent CPU spinning
            if ($runningJobs.Count -gt 0) {
                Start-Sleep -Milliseconds 100
            }
        }
        
        # Clear progress
        if ($ShowProgress) {
            Write-Progress -Activity $ProgressActivity -Completed
        }
        
        Write-Verbose "Work queue completed. Total: $totalItems, Completed: $completedItems, Failed: $failedItems"
        
        Write-TbLog -Message "Work queue completed" -Level Info -RunId $RunId -Data @{
            TotalItems = $totalItems
            CompletedItems = $completedItems
            FailedItems = $failedItems
        }
        
        return $results.ToArray()
    }
    catch {
        Write-Error "Work queue processing failed: $_"
        Write-TbLog -Message "Work queue failed" -Level Error -RunId $RunId -ErrorRecord $_
        throw
    }
    finally {
        # Cleanup
        if ($runspacePool) {
            Close-TbRunspacePool -RunspacePool $runspacePool
        }
    }
}
