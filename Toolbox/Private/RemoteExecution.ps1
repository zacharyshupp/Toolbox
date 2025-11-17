function Invoke-TbRemoteExecution {
    <#
    .SYNOPSIS
        Executes a script block on a remote computer.
    
    .DESCRIPTION
        Handles remote execution with support for WinRM, SSH, and localhost optimization.
        Manages sessions, credentials, and protocol selection.
    
    .PARAMETER Computer
        Target computer name or IP address.
    
    .PARAMETER ScriptBlock
        Script block to execute remotely.
    
    .PARAMETER ArgumentList
        Arguments to pass to the script block.
    
    .PARAMETER Credential
        PSCredential for remote authentication.
    
    .PARAMETER Protocol
        Remote protocol to use (WinRM, SSH, Auto).
    
    .PARAMETER TimeoutSeconds
        Execution timeout in seconds.
    
    .PARAMETER UseSSL
        Use SSL for WinRM connections.
    
    .EXAMPLE
        Invoke-TbRemoteExecution -Computer 'Server1' -ScriptBlock {Get-Service} -Credential $cred
    
    .OUTPUTS
        PSCustomObject with execution results.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Computer,
        
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [Parameter()]
        [object[]]$ArgumentList,
        
        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter()]
        [ValidateSet('WinRM', 'SSH', 'Auto')]
        [string]$Protocol = 'Auto',
        
        [Parameter()]
        [int]$TimeoutSeconds = 60,
        
        [Parameter()]
        [switch]$UseSSL
    )
    
    try {
        # Check if localhost
        $isLocalhost = Test-IsLocalhost -Computer $Computer
        
        if ($isLocalhost) {
            Write-Verbose "Executing locally on $Computer"
            return Invoke-LocalExecution -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
        }
        
        # Determine protocol
        if ($Protocol -eq 'Auto') {
            $Protocol = Get-OptimalProtocol -Computer $Computer
        }
        
        Write-Verbose "Executing on $Computer using $Protocol protocol"
        
        # Execute based on protocol
        switch ($Protocol) {
            'WinRM' {
                return Invoke-WinRMExecution -Computer $Computer -ScriptBlock $ScriptBlock `
                    -ArgumentList $ArgumentList -Credential $Credential `
                    -TimeoutSeconds $TimeoutSeconds -UseSSL:$UseSSL
            }
            'SSH' {
                return Invoke-SSHExecution -Computer $Computer -ScriptBlock $ScriptBlock `
                    -ArgumentList $ArgumentList -Credential $Credential `
                    -TimeoutSeconds $TimeoutSeconds
            }
            default {
                throw "Unsupported protocol: $Protocol"
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            Output = $null
            Error = $_
            Protocol = $Protocol
            IsLocalhost = $isLocalhost
        }
    }
}

function Test-IsLocalhost {
    <#
    .SYNOPSIS
        Determines if a computer name refers to the local machine.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Computer
    )
    
    $localhostNames = @(
        'localhost',
        '127.0.0.1',
        '::1',
        $env:COMPUTERNAME,
        ([System.Net.Dns]::GetHostName()),
        '.'
    )
    
    return $Computer -in $localhostNames
}

function Get-OptimalProtocol {
    <#
    .SYNOPSIS
        Determines the optimal remoting protocol for a computer.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Computer
    )
    
    # For Windows PowerShell or Windows OS, prefer WinRM
    if ($PSVersionTable.PSVersion.Major -le 5 -or $IsWindows) {
        return 'WinRM'
    }
    
    # For PowerShell Core on non-Windows, prefer SSH
    if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
        return 'SSH'
    }
    
    # Default to WinRM
    return 'WinRM'
}

function Invoke-LocalExecution {
    <#
    .SYNOPSIS
        Executes a script block locally (optimized path).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [Parameter()]
        [object[]]$ArgumentList
    )
    
    try {
        $result = if ($ArgumentList -and $ArgumentList.Count -gt 0) {
            # If ArgumentList contains a single hashtable, wrap in a script block that splats
            if ($ArgumentList.Count -eq 1 -and $ArgumentList[0] -is [hashtable]) {
                $params = $ArgumentList[0]
                # Invoke with splatting - need to access the hashtable directly
                & $ScriptBlock @params
            }
            else {
                # Pass as positional arguments
                & $ScriptBlock $ArgumentList
            }
        }
        else {
            & $ScriptBlock
        }
        
        return [PSCustomObject]@{
            Success = $true
            Output = $result
            Error = $null
            Protocol = 'Local'
            IsLocalhost = $true
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            Output = $null
            Error = $_.Exception.Message
            Protocol = 'Local'
            IsLocalhost = $true
        }
    }
}

function Invoke-WinRMExecution {
    <#
    .SYNOPSIS
        Executes a script block via WinRM.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Computer,
        
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [Parameter()]
        [object[]]$ArgumentList,
        
        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter()]
        [int]$TimeoutSeconds = 60,
        
        [Parameter()]
        [switch]$UseSSL
    )
    
    try {
        # Build session options
        $sessionOptions = New-PSSessionOption -OperationTimeout ($TimeoutSeconds * 1000) `
            -NoMachineProfile
        
        # Build Invoke-Command parameters
        $invokeParams = @{
            ComputerName = $Computer
            ScriptBlock = $ScriptBlock
            ErrorAction = 'Stop'
            SessionOption = $sessionOptions
        }
        
        if ($ArgumentList) {
            $invokeParams.ArgumentList = $ArgumentList
        }
        
        if ($Credential) {
            $invokeParams.Credential = $Credential
        }
        
        if ($UseSSL) {
            $invokeParams.UseSSL = $true
        }
        
        # Execute
        $output = Invoke-Command @invokeParams
        
        return [PSCustomObject]@{
            Success = $true
            Output = $output
            Error = $null
            Protocol = 'WinRM'
            IsLocalhost = $false
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            Output = $null
            Error = $_
            Protocol = 'WinRM'
            IsLocalhost = $false
        }
    }
}

function Invoke-SSHExecution {
    <#
    .SYNOPSIS
        Executes a script block via SSH (PowerShell 7+).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Computer,
        
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [Parameter()]
        [object[]]$ArgumentList,
        
        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter()]
        [int]$TimeoutSeconds = 60
    )
    
    # Check if PowerShell 7+ (SSH remoting requires it)
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw "SSH remoting requires PowerShell 7 or higher"
    }
    
    try {
        # Build Invoke-Command parameters for SSH
        $invokeParams = @{
            HostName = $Computer
            ScriptBlock = $ScriptBlock
            ErrorAction = 'Stop'
        }
        
        if ($ArgumentList) {
            $invokeParams.ArgumentList = $ArgumentList
        }
        
        if ($Credential) {
            $invokeParams.UserName = $Credential.UserName
            # Note: SSH typically uses key-based auth, password auth requires additional setup
        }
        
        # Execute
        $output = Invoke-Command @invokeParams
        
        return [PSCustomObject]@{
            Success = $true
            Output = $output
            Error = $null
            Protocol = 'SSH'
            IsLocalhost = $false
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            Output = $null
            Error = $_
            Protocol = 'SSH'
            IsLocalhost = $false
        }
    }
}

function New-TbPSSession {
    <#
    .SYNOPSIS
        Creates a new PSSession with proper configuration.
    
    .DESCRIPTION
        Creates and configures a PSSession for reuse scenarios.
    
    .PARAMETER Computer
        Target computer name.
    
    .PARAMETER Credential
        PSCredential for authentication.
    
    .PARAMETER Protocol
        Protocol to use (WinRM or SSH).
    
    .PARAMETER UseSSL
        Use SSL for WinRM connections.
    
    .EXAMPLE
        $session = New-TbPSSession -Computer 'Server1' -Credential $cred
    
    .OUTPUTS
        System.Management.Automation.Runspaces.PSSession
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Computer,
        
        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter()]
        [ValidateSet('WinRM', 'SSH')]
        [string]$Protocol = 'WinRM',
        
        [Parameter()]
        [switch]$UseSSL
    )
    
    try {
        $sessionParams = @{
            ErrorAction = 'Stop'
        }
        
        if ($Protocol -eq 'SSH') {
            if ($PSVersionTable.PSVersion.Major -lt 7) {
                throw "SSH sessions require PowerShell 7 or higher"
            }
            $sessionParams.HostName = $Computer
            if ($Credential) {
                $sessionParams.UserName = $Credential.UserName
            }
        }
        else {
            $sessionParams.ComputerName = $Computer
            if ($Credential) {
                $sessionParams.Credential = $Credential
            }
            if ($UseSSL) {
                $sessionParams.UseSSL = $true
            }
        }
        
        $session = New-PSSession @sessionParams
        Write-Verbose "Created PSSession to $Computer using $Protocol"
        
        return $session
    }
    catch {
        Write-Error "Failed to create PSSession to $Computer : $_"
        throw
    }
}
