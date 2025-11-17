function New-TbRunspacePool {
    <#
    .SYNOPSIS
        Creates and initializes a runspace pool for parallel execution.
    
    .DESCRIPTION
        Creates a runspace pool with configurable throttle limit and pre-loads
        common modules and functions for efficient parallel execution.
    
    .PARAMETER ThrottleLimit
        Maximum number of concurrent runspaces.
    
    .PARAMETER Modules
        Array of module names to pre-load into each runspace.
    
    .PARAMETER Functions
        Array of function definitions to pre-load into each runspace.
    
    .PARAMETER Variables
        Hashtable of variables to pre-load into each runspace.
    
    .EXAMPLE
        $pool = New-TbRunspacePool -ThrottleLimit 32
    
    .OUTPUTS
        System.Management.Automation.Runspaces.RunspacePool
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.Runspaces.RunspacePool])]
    param(
        [Parameter()]
        [ValidateRange(1, 256)]
        [int]$ThrottleLimit = 32,
        
        [Parameter()]
        [string[]]$Modules,
        
        [Parameter()]
        [hashtable]$Functions,
        
        [Parameter()]
        [hashtable]$Variables
    )
    
    try {
        Write-Verbose "Creating runspace pool with throttle limit: $ThrottleLimit"
        
        # Create initial session state
        $initialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        
        # Import modules into session state
        if ($Modules) {
            foreach ($moduleName in $Modules) {
                try {
                    $module = Get-Module -Name $moduleName -ListAvailable | Select-Object -First 1
                    if ($module) {
                        $initialSessionState.ImportPSModule($module.Path)
                        Write-Verbose "Pre-loaded module: $moduleName"
                    }
                }
                catch {
                    Write-Warning "Failed to pre-load module '$moduleName': $_"
                }
            }
        }
        
        # Add functions to session state
        if ($Functions) {
            foreach ($funcName in $Functions.Keys) {
                try {
                    $funcDef = $Functions[$funcName]
                    $sessionStateFunction = New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry(
                        $funcName, 
                        $funcDef
                    )
                    $initialSessionState.Commands.Add($sessionStateFunction)
                    Write-Verbose "Pre-loaded function: $funcName"
                }
                catch {
                    Write-Warning "Failed to pre-load function '$funcName': $_"
                }
            }
        }
        
        # Add variables to session state
        if ($Variables) {
            foreach ($varName in $Variables.Keys) {
                try {
                    $varValue = $Variables[$varName]
                    $sessionStateVariable = New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry(
                        $varName,
                        $varValue,
                        $null
                    )
                    $initialSessionState.Variables.Add($sessionStateVariable)
                    Write-Verbose "Pre-loaded variable: $varName"
                }
                catch {
                    Write-Warning "Failed to pre-load variable '$varName': $_"
                }
            }
        }
        
        # Create runspace pool
        $runspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(
            1,
            $ThrottleLimit,
            $initialSessionState,
            $Host
        )
        
        # Set apartment state (required for some COM operations)
        $runspacePool.ApartmentState = [System.Threading.ApartmentState]::MTA
        
        # Open the pool
        $runspacePool.Open()
        
        Write-Verbose "Runspace pool created and opened successfully"
        
        return $runspacePool
    }
    catch {
        Write-Error "Failed to create runspace pool: $_"
        throw
    }
}

function Close-TbRunspacePool {
    <#
    .SYNOPSIS
        Closes and disposes a runspace pool.
    
    .DESCRIPTION
        Safely closes a runspace pool and releases all resources.
    
    .PARAMETER RunspacePool
        The runspace pool to close.
    
    .EXAMPLE
        Close-TbRunspacePool -RunspacePool $pool
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Runspaces.RunspacePool]$RunspacePool
    )
    
    try {
        if ($RunspacePool -and -not $RunspacePool.IsDisposed) {
            Write-Verbose "Closing runspace pool..."
            
            # Close the pool
            $RunspacePool.Close()
            
            # Dispose of the pool
            $RunspacePool.Dispose()
            
            Write-Verbose "Runspace pool closed and disposed"
        }
    }
    catch {
        Write-Warning "Error closing runspace pool: $_"
    }
}

function Invoke-TbRunspaceJob {
    <#
    .SYNOPSIS
        Executes a script block in a runspace from the pool.
    
    .DESCRIPTION
        Creates a PowerShell instance, assigns it to a runspace from the pool,
        and begins asynchronous execution.
    
    .PARAMETER RunspacePool
        The runspace pool to use for execution.
    
    .PARAMETER ScriptBlock
        The script block to execute.
    
    .PARAMETER Parameters
        Hashtable of parameters to pass to the script block.
    
    .PARAMETER WorkItemId
        Unique identifier for this work item.
    
    .EXAMPLE
        $job = Invoke-TbRunspaceJob -RunspacePool $pool -ScriptBlock $script -Parameters @{Computer='Server1'}
    
    .OUTPUTS
        PSCustomObject containing the PowerShell instance and async result.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Runspaces.RunspacePool]$RunspacePool,
        
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [Parameter()]
        [hashtable]$Parameters,
        
        [Parameter()]
        [string]$WorkItemId
    )
    
    try {
        # Create PowerShell instance
        $powershell = [powershell]::Create()
        $powershell.RunspacePool = $RunspacePool
        
        # Add script block
        $null = $powershell.AddScript($ScriptBlock)
        
        # Add parameters
        if ($Parameters) {
            foreach ($key in $Parameters.Keys) {
                $null = $powershell.AddParameter($key, $Parameters[$key])
            }
        }
        
        # Begin invocation
        $asyncResult = $powershell.BeginInvoke()
        
        # Return job object
        return [PSCustomObject]@{
            WorkItemId = $WorkItemId
            PowerShell = $powershell
            AsyncResult = $asyncResult
            StartTime = Get-Date
        }
    }
    catch {
        Write-Error "Failed to invoke runspace job: $_"
        if ($powershell) {
            $powershell.Dispose()
        }
        throw
    }
}

function Wait-TbRunspaceJob {
    <#
    .SYNOPSIS
        Waits for a runspace job to complete with timeout support.
    
    .DESCRIPTION
        Waits for a runspace job to complete or timeout, then retrieves the results.
    
    .PARAMETER Job
        The job object returned from Invoke-TbRunspaceJob.
    
    .PARAMETER TimeoutSeconds
        Maximum time to wait for completion in seconds.
    
    .EXAMPLE
        $result = Wait-TbRunspaceJob -Job $job -TimeoutSeconds 60
    
    .OUTPUTS
        PSCustomObject containing success status, output, errors, and timeout flag.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Job,
        
        [Parameter()]
        [int]$TimeoutSeconds = 60
    )
    
    try {
        $timeoutMs = $TimeoutSeconds * 1000
        $completed = $Job.AsyncResult.AsyncWaitHandle.WaitOne($timeoutMs)
        
        $result = [PSCustomObject]@{
            Success = $false
            Output = $null
            Errors = @()
            Warnings = @()
            TimedOut = -not $completed
            Duration = (Get-Date) - $Job.StartTime
        }
        
        if ($completed) {
            # Job completed - get results
            try {
                $result.Output = $Job.PowerShell.EndInvoke($Job.AsyncResult)
                $result.Success = $Job.PowerShell.HadErrors -eq $false
                
                # Collect errors
                if ($Job.PowerShell.Streams.Error.Count -gt 0) {
                    $result.Errors = @($Job.PowerShell.Streams.Error)
                }
                
                # Collect warnings
                if ($Job.PowerShell.Streams.Warning.Count -gt 0) {
                    $result.Warnings = @($Job.PowerShell.Streams.Warning)
                }
            }
            catch {
                $result.Success = $false
                $result.Errors = @($_)
            }
        }
        else {
            # Job timed out
            try {
                $Job.PowerShell.Stop()
            }
            catch {
                Write-Verbose "Error stopping timed out job: $_"
            }
        }
        
        return $result
    }
    finally {
        # Cleanup PowerShell instance
        if ($Job.PowerShell) {
            $Job.PowerShell.Dispose()
        }
    }
}
