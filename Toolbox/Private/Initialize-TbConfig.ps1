function Initialize-TbConfig {
    <#
    .SYNOPSIS
        Initializes the Toolbox configuration.
    
    .DESCRIPTION
        Creates default configuration if it doesn't exist and loads it into memory.
        This is an internal function called during module initialization.
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Define configuration path
        $configDir = Join-Path $env:APPDATA 'Toolbox'
        $configPath = Join-Path $configDir 'Config.json'
        
        # Create directory if it doesn't exist
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
            Write-Verbose "Created configuration directory: $configDir"
        }
        
        # Load or create configuration
        if (Test-Path $configPath) {
            Write-Verbose "Loading configuration from: $configPath"
            $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
        }
        else {
            Write-Verbose "Creating default configuration"
            $defaultConfigPath = Join-Path $script:ModuleRoot 'Config\Config.Default.json'
            $config = Get-Content -Path $defaultConfigPath -Raw | ConvertFrom-Json
            
            # Set dynamic paths
            $config.Logging.LogPath = Join-Path $configDir 'Logs'
            $config.Tasks.BuiltInTaskPath = Join-Path $script:ModuleRoot 'Tasks\BuiltIn'
            $config.Tasks.SystemTaskPath = Join-Path $env:ProgramData 'Toolbox\Tasks'
            $config.Tasks.UserTaskPath = Join-Path $env:APPDATA 'Toolbox\Tasks'
            
            # Create log directory
            if (-not (Test-Path $config.Logging.LogPath)) {
                New-Item -ItemType Directory -Path $config.Logging.LogPath -Force | Out-Null
            }
            
            # Save configuration
            $config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Force
            Write-Verbose "Default configuration created at: $configPath"
        }
        
        # Store in module scope
        $script:ModuleConfig = $config
        $script:ConfigPath = $configPath
        
        Write-Verbose "Configuration initialized successfully"
    }
    catch {
        Write-Error "Failed to initialize configuration: $_"
        throw
    }
}
