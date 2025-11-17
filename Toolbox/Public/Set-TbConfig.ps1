function Set-TbConfig {
    <#
    .SYNOPSIS
        Updates Toolbox module configuration settings.
    
    .DESCRIPTION
        Modifies configuration settings for the Toolbox module. Changes are saved
        to the configuration file and applied immediately.
    
    .PARAMETER Section
        Configuration section to update (e.g., "Execution", "Logging", "Tasks").
    
    .PARAMETER Property
        Property name to update within the specified section.
    
    .PARAMETER Value
        New value for the property.
    
    .PARAMETER Reset
        Resets the configuration to default values.
    
    .EXAMPLE
        Set-TbConfig -Section Execution -Property DefaultThrottle -Value 64
        Sets the default throttle to 64 concurrent runspaces.
    
    .EXAMPLE
        Set-TbConfig -Section Logging -Property LogLevel -Value "Verbose"
        Sets the log level to Verbose.
    
    .EXAMPLE
        Set-TbConfig -Reset
        Resets all configuration to default values.
    
    .EXAMPLE
        Set-TbConfig -Section Logging -Property MaxLogFileSizeMB -Value 100
        Increases maximum log file size to 100 MB.
    
    .EXAMPLE
        Set-TbConfig -Section Execution -Property DefaultTimeout -Value 300
        Sets default task timeout to 5 minutes (300 seconds).
    
    .EXAMPLE
        Set-TbConfig -Section Export -Property DefaultFormat -Value "Excel"
        Sets Excel as the default export format.
    
    .NOTES
        Changes are persisted to disk and take effect immediately.
        Use Get-TbConfig to view current settings before making changes.
        Invalid property names or values will generate errors.
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = "Update")]
    param(
        [Parameter(Mandatory, ParameterSetName = "Update", Position = 0)]
        [ValidateSet("Execution", "Logging", "Tasks", "Session", "Export")]
        [string]$Section,
        
        [Parameter(Mandatory, ParameterSetName = "Update", Position = 1)]
        [string]$Property,
        
        [Parameter(Mandatory, ParameterSetName = "Update", Position = 2)]
        [object]$Value,
        
        [Parameter(Mandatory, ParameterSetName = "Reset")]
        [switch]$Reset
    )
    
    # Ensure configuration is loaded
    if (-not $script:ModuleConfig) {
        Initialize-TbConfig
    }
    
    try {
        if ($Reset) {
            if ($PSCmdlet.ShouldProcess("Configuration", "Reset to defaults")) {
                # Load default configuration
                $defaultConfigPath = Join-Path $script:ModuleRoot "Config\Config.Default.json"
                $config = Get-Content -Path $defaultConfigPath -Raw | ConvertFrom-Json
                
                # Set dynamic paths
                $configDir = Split-Path $script:ConfigPath -Parent
                $config.Logging.LogPath = Join-Path $configDir "Logs"
                $config.Tasks.BuiltInTaskPath = Join-Path $script:ModuleRoot "Tasks\BuiltIn"
                $config.Tasks.SystemTaskPath = Join-Path $env:ProgramData "Toolbox\Tasks"
                $config.Tasks.UserTaskPath = Join-Path $env:APPDATA "Toolbox\Tasks"
                
                # Update module config
                $script:ModuleConfig = $config
                
                # Save to disk
                $config | ConvertTo-Json -Depth 10 | Set-Content -Path $script:ConfigPath -Force
                
                Write-Verbose "Configuration reset to defaults"
                return $script:ModuleConfig
            }
        }
        else {
            # Validate section exists
            if (-not $script:ModuleConfig.$Section) {
                Write-Error "Configuration section "$Section" not found"
                return
            }
            
            # Validate property exists
            if (-not ($script:ModuleConfig.$Section.PSObject.Properties.Name -contains $Property)) {
                Write-Error "Property "$Property" not found in section "$Section""
                return
            }
            
            # Get current value for comparison
            $currentValue = $script:ModuleConfig.$Section.$Property
            
            # Validate value type matches
            if ($null -ne $currentValue) {
                $expectedType = $currentValue.GetType()
                if ($Value.GetType() -ne $expectedType) {
                    # Try to convert
                    try {
                        $Value = $Value -as $expectedType
                        if ($null -eq $Value) {
                            Write-Error "Cannot convert value to expected type: $($expectedType.Name)"
                            return
                        }
                    }
                    catch {
                        Write-Error "Invalid value type. Expected: $($expectedType.Name)"
                        return
                    }
                }
            }
            
            # Perform validation based on property
            if (-not (Test-ConfigValue -Section $Section -Property $Property -Value $Value)) {
                return
            }
            
            if ($PSCmdlet.ShouldProcess("$Section.$Property", "Set to '$Value'")) {
                # Update the configuration
                $script:ModuleConfig.$Section.$Property = $Value
                
                # Save to disk
                $script:ModuleConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $script:ConfigPath -Force
                
                Write-Verbose "Configuration updated: $Section.$Property = $Value"
                
                # Return the updated section
                return $script:ModuleConfig.$Section
            }
        }
    }
    catch {
        Write-Error "Failed to update configuration: $_"
    }
}

function Test-ConfigValue {
    <#
    .SYNOPSIS
        Validates configuration values.
    #>
    param(
        [string]$Section,
        [string]$Property,
        [object]$Value
    )
    
    # Validation rules
    switch ("$Section.$Property") {
        "Execution.DefaultThrottle" {
            if ($Value -lt 1 -or $Value -gt 256) {
                Write-Error "DefaultThrottle must be between 1 and 256"
                return $false
            }
        }
        "Execution.DefaultTimeout" {
            if ($Value -lt 1) {
                Write-Error "DefaultTimeout must be greater than 0"
                return $false
            }
        }
        "Execution.DefaultRetryCount" {
            if ($Value -lt 0) {
                Write-Error "DefaultRetryCount must be 0 or greater"
                return $false
            }
        }
        "Execution.RetryDelaySeconds" {
            if ($Value -lt 1) {
                Write-Error "RetryDelaySeconds must be greater than 0"
                return $false
            }
        }
        "Execution.RetryBackoffMultiplier" {
            if ($Value -lt 1.0) {
                Write-Error "RetryBackoffMultiplier must be 1.0 or greater"
                return $false
            }
        }
        "Logging.LogLevel" {
            $validLevels = @("Verbose", "Info", "Warning", "Error")
            if ($Value -notin $validLevels) {
                Write-Error "LogLevel must be one of: $($validLevels -join ", ")"
                return $false
            }
        }
        "Logging.MaxLogFileSizeMB" {
            if ($Value -lt 1) {
                Write-Error "MaxLogFileSizeMB must be greater than 0"
                return $false
            }
        }
        "Logging.MaxLogFiles" {
            if ($Value -lt 1) {
                Write-Error "MaxLogFiles must be greater than 0"
                return $false
            }
        }
        "Session.DefaultProtocol" {
            $validProtocols = @("WinRM", "SSH", "Auto")
            if ($Value -notin $validProtocols) {
                Write-Error "DefaultProtocol must be one of: $($validProtocols -join ", ")"
                return $false
            }
        }
        "Session.SessionTimeoutSeconds" {
            if ($Value -lt 60) {
                Write-Error "SessionTimeoutSeconds must be at least 60"
                return $false
            }
        }
        "Export.DefaultFormat" {
            $validFormats = @("CSV", "JSON", "XML", "Excel")
            if ($Value -notin $validFormats) {
                Write-Error "DefaultFormat must be one of: $($validFormats -join ", ")"
                return $false
            }
        }
    }
    
    return $true
}
