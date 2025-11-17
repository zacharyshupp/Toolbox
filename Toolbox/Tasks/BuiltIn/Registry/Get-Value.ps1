<#
.SYNOPSIS
    Retrieves a value from the Windows Registry

.DESCRIPTION
    Reads one or all values from the specified registry path and returns the value data, type, and metadata.

.PARAMETER Path
    Registry path (e.g., HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion)

.PARAMETER Name
    Name of the registry value to retrieve. Omit to get all values in the key

.NOTES
    TaskName: Registry.GetValue
    Version: 1.0.0
    Author: Toolbox
    Tags: Registry, Windows, Configuration
    RequiresElevation: False
    SupportedOS: Windows
    PSEdition: Desktop, Core
    MinPSVersion: 5.1
    Timeout: 15

.EXAMPLE
    Invoke-Task -TaskName 'Registry.GetValue' -Computers 'localhost' -TaskParameters @{ Path = 'HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion'; Name = 'ProgramFilesDir' }
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path,

    [Parameter()]
    [string]$Name
)

try {
    Write-Verbose "Retrieving registry value from path: $Path"
    
    # Validate registry path exists
    if (-not (Test-Path -Path $Path)) {
        throw "Registry path not found: $Path"
    }
    
    # Get registry key
    $regKey = Get-Item -Path $Path -ErrorAction Stop
    
    if ($PSBoundParameters.ContainsKey('Name')) {
        # Get specific value
        Write-Verbose "Retrieving value: $Name"
        
        $value = $regKey.GetValue($Name, $null)
        $valueKind = $regKey.GetValueKind($Name)
        
        if ($null -eq $value) {
            throw "Registry value '$Name' not found at path: $Path"
        }
        
        Write-Verbose "Value type: $valueKind"
        
        [PSCustomObject]@{
            Path      = $Path
            Name      = $Name
            Value     = $value
            Type      = $valueKind.ToString()
            ValueType = $value.GetType().Name
        }
    }
    else {
        # Get all values
        Write-Verbose "Retrieving all values in key"
        
        $valueNames = $regKey.GetValueNames()
        
        if ($valueNames.Count -eq 0) {
            Write-Verbose "No values found in registry key"
            
            [PSCustomObject]@{
                Path       = $Path
                ValueCount = 0
                Values     = @()
            }
        }
        else {
            Write-Verbose "Found $($valueNames.Count) value(s)"
            
            $values = foreach ($valueName in $valueNames) {
                $value = $regKey.GetValue($valueName)
                $valueKind = $regKey.GetValueKind($valueName)
                
                [PSCustomObject]@{
                    Name      = $valueName
                    Value     = $value
                    Type      = $valueKind.ToString()
                    ValueType = $value.GetType().Name
                }
            }
            
            [PSCustomObject]@{
                Path       = $Path
                ValueCount = $values.Count
                Values     = $values
            }
        }
    }
}
catch {
    Write-Error "Failed to retrieve registry value: $_"
    throw
}
