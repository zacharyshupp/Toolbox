@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'Toolbox.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')

    # ID used to uniquely identify this module
    GUID = '8b3c9d5e-7f2a-4b1e-9c6d-3a8e5f7b2c9d'

    # Author of this module
    Author = 'Zachary Shupp'

    # Company or vendor of this module
    CompanyName = 'Unknown'

    # Copyright statement for this module
    Copyright = '(c) 2025 Zachary Shupp. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'A robust PowerShell module for parallel remote task orchestration with runspaces, throttling, timeout controls, structured output, error aggregation, retry logic, and pluggable task framework.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @(
        @{
            ModuleName = 'ImportExcel'
            ModuleVersion = '7.0.0'
        }
    )

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Invoke-Task',
        'Get-TaskDefinition',
        'New-TaskDefinition',
        'Export-TaskResult',
        'Get-TaskLog',
        'Get-TbConfig',
        'Set-TbConfig'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('PowerShell', 'Remote', 'Orchestration', 'Parallel', 'Runspaces', 'Tasks', 'WinRM', 'SSH', 'Toolbox', 'Tools', "Toolkit")

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/zacharyshupp/Toolbox/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/zacharyshupp/Toolbox'

            # A URL to an icon representing this module.
            IconUri = 'https://raw.githubusercontent.com/zacharyshupp/Toolbox/main/docs/assets/images/Toolbox_64x64.png'

            # ReleaseNotes of this module
            ReleaseNotes = @'
## 1.0.0 - First Stable Release (November 2025)

### Core Features
- **Parallel Task Execution**: Execute tasks across multiple computers simultaneously with runspace pooling
- **Configurable Throttling**: Control concurrent execution with throttle limits (1-256)
- **Timeout & Retry**: Automatic timeout handling and exponential backoff retry logic
- **Smart Computer Lists**: Load targets from TXT, CSV, or Excel files with column specification
- **Multiple Export Formats**: Export results to CSV, JSON, XML, or Excel
- **Comprehensive Logging**: JSON Lines format logs with sensitive data masking

### Built-In Tasks (11 Total)
- **System**: Get-Uptime, Get-BasicInfo
- **File**: Test-PathExists, Get-PathSize
- **Network**: Test-Connection, Test-Port
- **Process**: Get-Process
- **Service**: Get-Service
- **Registry**: Get-Value
- **HTTP**: Invoke-Request

### Cmdlets (7 Total)
- `Invoke-Task`: Execute tasks on remote computers
- `Get-TaskDefinition`: Query available tasks
- `New-TaskDefinition`: Create custom task scaffolding
- `Export-TaskResult`: Export results to various formats
- `Get-TaskLog`: Query execution logs
- `Get-TbConfig`: View configuration
- `Set-TbConfig`: Modify configuration

### Quality & Testing
- 103 comprehensive tests (100 passing)
- Full compatibility: PowerShell 5.1 and 7.x
- Cross-platform support: Windows, Linux, macOS (PS 7+)
- Complete documentation with 41 help examples
- Task authoring guide and contribution guidelines

### Requirements
- PowerShell 5.1 or higher
- ImportExcel module (for Excel export)
'@
        }
    }
}
