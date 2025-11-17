#Requires -Version 5.1

<#
.SYNOPSIS
    Toolbox - Remote Task Orchestrator Module

.DESCRIPTION
    A robust PowerShell module for parallel remote task orchestration with runspaces,
    throttling, timeout controls, structured output, error aggregation, retry logic,
    and pluggable task framework.

.NOTES
    Author: Zachary Shupp
    Version: 0.1.0
#>

#region Module Variables
$script:ModuleRoot = $PSScriptRoot
$script:ModuleName = 'Toolbox'
$script:ModuleVersion = '0.1.0'

# Initialize module-level configuration store
$script:ModuleConfig = $null
$script:ConfigPath = $null

# Initialize module-level logging state
$script:LoggingInitialized = $false

# Initialize module-level task cache
$script:TaskCache = $null
#endregion

#region Auto-Load Functions

# Load StatusEnum.ps1 first (C# type definition must be loaded before PowerShell classes)
$StatusEnumFile = Join-Path $PSScriptRoot 'Private\StatusEnum.ps1'
if (Test-Path $StatusEnumFile) {
    try {
        Write-Verbose "Loading Status enum from $StatusEnumFile"
        . $StatusEnumFile
    }
    catch {
        Write-Error "Failed to load Status enum: $_"
    }
}

# Load Types.ps1 second (PowerShell classes that reference the enum)
$TypesFile = Join-Path $PSScriptRoot 'Private\Types.ps1'
if (Test-Path $TypesFile) {
    try {
        Write-Verbose "Loading PowerShell classes from $TypesFile"
        . $TypesFile
    }
    catch {
        Write-Error "Failed to load PowerShell classes: $_"
    }
}

# Get public and private function definition files (excluding StatusEnum.ps1 and Types.ps1 since we already loaded them)
$Public = @(Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin @('StatusEnum.ps1', 'Types.ps1') })

# Dot source the files
foreach ($import in @($Public + $Private)) {
    try {
        Write-Verbose "Importing $($import.FullName)"
        . $import.FullName
    }
    catch {
        Write-Error "Failed to import function $($import.FullName): $_"
    }
}

# Export public functions
Export-ModuleMember -Function $Public.BaseName

#endregion

#region Module Initialization

# Initialize module on import
Write-Verbose "Toolbox module loaded. Version: $script:ModuleVersion"
Write-Verbose "Module root: $script:ModuleRoot"

# Initialize configuration
try {
    Initialize-TbConfig
    Write-Verbose "Configuration initialized"
}
catch {
    Write-Warning "Failed to initialize configuration: $_"
}

# Check for ImportExcel module (required dependency)
if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Write-Warning "ImportExcel module is not installed. Excel export functionality will not be available."
    Write-Warning "Install it using: Install-Module -Name ImportExcel -Scope CurrentUser"
}

#endregion

#region Module Cleanup

# Register cleanup on module removal
$ExecutionContext.SessionState.Module.OnRemove = {
    Write-Verbose "Cleaning up Toolbox module..."
    
    # Clean up any module-level resources
    Remove-Variable -Name ModuleConfig -Scope Script -ErrorAction SilentlyContinue
    Remove-Variable -Name ConfigPath -Scope Script -ErrorAction SilentlyContinue
    Remove-Variable -Name LoggingInitialized -Scope Script -ErrorAction SilentlyContinue
    Remove-Variable -Name TaskCache -Scope Script -ErrorAction SilentlyContinue
}

#endregion
