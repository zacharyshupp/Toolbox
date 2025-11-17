function Get-TbConfig {
    <#
    .SYNOPSIS
        Retrieves Toolbox module configuration settings.
    
    .DESCRIPTION
        Gets the current Toolbox configuration. Can retrieve the entire configuration
        or specific sections/properties.
    
    .PARAMETER Section
        Specific configuration section to retrieve (e.g., "Execution", "Logging", "Tasks").
        If not specified, returns the entire configuration.
    
    .PARAMETER Property
        Specific property within a section to retrieve. Requires -Section parameter.
    
    .PARAMETER AsHashtable
        Returns the configuration as a hashtable instead of PSCustomObject.
    
    .EXAMPLE
        Get-TbConfig
        Returns the entire configuration.
    
    .EXAMPLE
        Get-TbConfig -Section Execution
        Returns only the Execution section of the configuration.
    
    .EXAMPLE
        Get-TbConfig -Section Execution -Property DefaultThrottle
        Returns the DefaultThrottle value from the Execution section.
    
    .EXAMPLE
        Get-TbConfig -AsHashtable
        Returns the configuration as a hashtable.
    
    .EXAMPLE
        (Get-TbConfig -Section Execution).DefaultThrottle
        Gets the default throttle limit value using dot notation.
    
    .EXAMPLE
        Get-TbConfig | ConvertTo-Json -Depth 5
        Exports entire configuration to JSON format.
    
    .OUTPUTS
        PSCustomObject or Hashtable containing the configuration.
    
    .NOTES
        Configuration is loaded from %APPDATA%\Toolbox\Config.json.
        Default values are used if configuration file doesn"t exist.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject], [Hashtable])]
    param(
        [Parameter()]
        [ValidateSet("Execution", "Logging", "Tasks", "Session", "Export")]
        [string]$Section,
        
        [Parameter()]
        [string]$Property,
        
        [Parameter()]
        [switch]$AsHashtable
    )
    
    # Ensure configuration is loaded
    if (-not $script:ModuleConfig) {
        Initialize-TbConfig
    }
    
    try {
        # Get the requested configuration
        if ($Section) {
            if (-not $script:ModuleConfig.$Section) {
                Write-Error "Configuration section "$Section" not found"
                return
            }
            
            $result = $script:ModuleConfig.$Section
            
            if ($Property) {
                if (-not ($result.PSObject.Properties.Name -contains $Property)) {
                    Write-Error "Property "$Property" not found in section "$Section""
                    return
                }
                $result = $result.$Property
            }
        }
        else {
            if ($Property) {
                Write-Warning "Property parameter ignored when Section is not specified"
            }
            $result = $script:ModuleConfig
        }
        
        # Convert to hashtable if requested
        if ($AsHashtable -and $result -is [PSCustomObject]) {
            $result = ConvertTo-Hashtable -InputObject $result
        }
        
        return $result
    }
    catch {
        Write-Error "Failed to get configuration: $_"
    }
}

function ConvertTo-Hashtable {
    <#
    .SYNOPSIS
        Helper function to convert PSCustomObject to Hashtable.
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$InputObject
    )
    
    $hashtable = @{}
    
    foreach ($property in $InputObject.PSObject.Properties) {
        $value = $property.Value
        
        if ($value -is [PSCustomObject]) {
            $value = ConvertTo-Hashtable -InputObject $value
        }
        elseif ($value -is [Array]) {
            $value = @($value | ForEach-Object {
                if ($_ -is [PSCustomObject]) {
                    ConvertTo-Hashtable -InputObject $_
                }
                else {
                    $_
                }
            })
        }
        
        $hashtable[$property.Name] = $value
    }
    
    return $hashtable
}
