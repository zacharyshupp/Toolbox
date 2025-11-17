# Changelog

All notable changes to the Toolbox module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-17

### Added
- **Core Task Orchestration Framework**
  - Parallel task execution with runspace pooling
  - Configurable throttle limits (1-256 concurrent tasks)
  - Timeout handling with configurable defaults
  - Automatic retry with exponential backoff
  - Progress reporting with `-ShowProgress` switch

- **Smart Computer Input**
  - Direct computer name specification
  - Load from text files (one per line)
  - Load from CSV files with column specification (`file.csv:ColumnName`)
  - Load from Excel files with column specification (`file.xlsx:ColumnName`)
  - Mix and match files and computer names

- **Built-In Task Library** (11 tasks across 6 categories)
  - **System**: Get-Uptime, Get-BasicInfo
  - **File**: Test-PathExists, Get-PathSize
  - **Network**: Test-Connection, Test-Port
  - **Process**: Get-Process
  - **Service**: Get-Service
  - **Registry**: Get-Value (Windows only)
  - **HTTP**: Invoke-Request

- **Export Functionality**
  - CSV export with automatic flattening
  - JSON export preserving complex objects
  - XML export with structured data
  - Excel export using ImportExcel module
  - Auto-format detection from file extension
  - NoClobber protection

- **Configuration Management**
  - JSON-based configuration storage
  - User-specific settings in `%APPDATA%\Toolbox\Config.json`
  - Configurable execution defaults (throttle, timeout, retry)
  - Configurable logging behavior
  - Task path resolution (Built-in → System → User)

- **Logging Framework**
  - JSON Lines format for structured logging
  - Automatic log rotation (size and count based)
  - Log level filtering (Verbose, Info, Warning, Error)
  - Sensitive data masking
  - Correlation ID tracking for execution runs
  - Query logs with `Get-TaskLog` cmdlet

- **Public Cmdlets** (7 total)
  - `Invoke-Task`: Execute tasks on one or more computers
  - `Get-TaskDefinition`: List and query available tasks
  - `New-TaskDefinition`: Create custom task scaffolding
  - `Export-TaskResult`: Export task results to various formats
  - `Get-TaskLog`: Query and filter execution logs
  - `Get-TbConfig`: Retrieve configuration settings
  - `Set-TbConfig`: Update configuration settings

- **Custom Task Support**
  - Task authoring framework with scaffolding
  - Comment-based metadata in `.NOTES` section
  - Task discovery with caching
  - Category-based organization
  - User task directory (`%APPDATA%\Toolbox\Tasks\`)

- **Documentation**
  - Comprehensive README with 6 usage examples
  - 41 cmdlet help examples across all functions
  - Task authoring guide (docs/TASK-AUTHORING.md)
  - Contribution guidelines (docs/CONTRIBUTING.md)
  - Full comment-based help for all public cmdlets

- **Testing**
  - 103 Pester tests (100 passing, 3 acceptable skips)
  - Unit tests for core functionality
  - Integration tests for end-to-end scenarios
  - Task-specific tests for all built-in tasks
  - Test runner with rich reporting

### Technical Details
- **PowerShell Compatibility**: 5.1, 7.0+
- **PowerShell Editions**: Desktop, Core
- **Platform Support**: Windows, Linux (PS 7+), macOS (PS 7+)
- **Remoting Protocols**: WinRM, SSH (PS 7+)
- **Dependencies**: ImportExcel module (7.0.0+)
- **Execution Model**: Runspace pools for parallel processing
- **Default Throttle**: 32 concurrent runspaces
- **Default Timeout**: 60 seconds per target
- **Retry Strategy**: Exponential backoff with 2x multiplier

### Performance
- Single computer execution: ~330ms
- Parallel execution (3 computers): ~370ms
- Efficient runspace pooling with minimal overhead
- Localhost optimization (no remoting overhead)

### Security
- Credential parameter support for remote authentication
- Sensitive data masking in logs
- Execution policy compliant
- No credentials stored in configuration

## [Unreleased]

### Planned Features
- Background job mode (`-AsJob` parameter)
- PSSession reuse (`-ReuseSession` parameter)
- Result filtering options
- Additional built-in tasks
- Web UI for result visualization
- Real-time log streaming

---

[1.0.0]: https://github.com/zacharyshupp/Toolbox/releases/tag/v1.0.0
