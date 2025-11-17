# Toolbox
Your daily-driver toolbox for modern IT.

## Overview

Toolbox is a PowerShell module for parallel remote task orchestration with runspace pooling, throttling, timeout controls, structured output, error aggregation, retry logic, and a pluggable task framework.

## Directory Structure

```text
Toolbox/
├── Toolbox/
│   ├── Public/              # Exported cmdlets
│   ├── Private/             # Internal functions
│   ├── Config/              # Default configuration
│   ├── Schemas/             # JSON schemas for validation
│   └── Tasks/
│       └── BuiltIn/         # Built-in task library
│           ├── File/        # File system operations
│           │   ├── Get-PathSize.ps1
│           │   └── Test-PathExists.ps1
│           ├── Network/     # Network operations
│           │   ├── Test-Connection.ps1
│           │   └── Test-Port.ps1
│           ├── Process/     # Process management
│           │   └── Get-Process.ps1
│           ├── Registry/    # Windows Registry operations
│           │   └── Get-Value.ps1
│           ├── Service/     # Windows Service management
│           │   ├── Get-Service.ps1
│           │   └── Set-ServiceStatus.ps1
│           ├── System/      # System information
│           │   ├── Get-BasicInfo.ps1
│           │   └── Get-Uptime.ps1
│           └── HTTP/        # HTTP/REST operations
│               └── Invoke-Request.ps1
├── Tests/                   # Pester tests
└── build.ps1               # Build script
```

## Task Organization

Tasks are organized by category for easy navigation and maintenance. Each task is a single PowerShell script file with embedded metadata in comment-based help.

**Task Structure:**

- Each task is a single PowerShell script: `Tasks/<Category>/<Verb-Noun>.ps1`
- Task names follow PowerShell conventions (e.g., `Get-PathSize.ps1`, `Test-Connection.ps1`)
- Metadata is embedded in the `.NOTES` section of comment-based help
- No separate JSON files or nested folders - clean and simple

**Available Categories:**

- **File**: File system operations (paths, sizes, testing)
- **Network**: Network operations (ping, port tests, connectivity)
- **Process**: Process management (list, filter, information)
- **Registry**: Windows Registry operations (read values, keys)
- **Service**: Windows Service management (status, control)
- **System**: System information (uptime, hardware, OS)
- **HTTP**: HTTP/REST API operations (requests, responses)

## Getting Started

### Installation

```powershell

# Import the module
Import-Module .\Toolbox\Toolbox.psd1

# Or install from PowerShell Gallery (when published)
Install-Module -Name Toolbox
```

**Note:** The module requires the `ImportExcel` module for Excel export functionality:
```powershell
Install-Module -Name ImportExcel
```

### Quick Start

**List all available tasks:**
```powershell
Get-TaskDefinition -ListAvailable
```

**Run a task on multiple computers:**
```powershell
Invoke-Task -TaskName 'System.GetBasicInfo' -Computers 'SERVER01', 'SERVER02', 'SERVER03'
```

**Load computers from a file (TXT, CSV, or Excel):**
```powershell
# Text file (one computer per line)
Invoke-Task -TaskName 'System.GetUptime' -Computers 'C:\servers.txt'

# CSV file with column specification
Invoke-Task -TaskName 'System.GetUptime' -Computers 'C:\inventory.csv:ComputerName'

# Excel file (uses first column if not specified)
Invoke-Task -TaskName 'System.GetUptime' -Computers 'C:\assets.xlsx:HostName'

# Mix files and computer names
Invoke-Task -TaskName 'System.GetUptime' -Computers 'C:\servers.txt','SERVER99','localhost'
```

**Run a task with parameters:**

```powershell
Invoke-Task -TaskName 'File.GetPathSize' -Computers 'localhost' -TaskParameters @{
    Path = 'C:\Windows'
    Unit = 'GB'
}
```

**Export results to Excel:**

```powershell
Invoke-Task -TaskName 'Process.GetProcess' -Computers 'C:\servers.csv:ServerName' -OutputFormat Excel -OutputPath 'C:\Reports\Processes.xlsx'
```

## Usage Examples

### Example 1: Check Disk Space Across Servers

```powershell
$servers = 'WEB01', 'WEB02', 'DB01', 'DB02'

Invoke-Task -TaskName 'File.GetPathSize' -Computers $servers -TaskParameters @{
    Path = 'C:\'
    Unit = 'GB'
    IncludeDetails = $true
} -ExportPath 'DiskSpace.xlsx' -Verbose
```

### Example 2: Test Network Connectivity

```powershell
# Test if critical services are reachable
# Automatically reads from text file
Invoke-Task -TaskName 'Network.TestPort' -Computers 'C:\servers.txt' -TaskParameters @{
    TargetHost = 'dc01.domain.com'
    Port = 389  # LDAP
    TimeoutSeconds = 5
} -ThrottleLimit 50

# Read from CSV file with specific column
Invoke-Task -TaskName 'Network.TestConnection' -Computers 'C:\inventory.csv:ServerName' -TaskParameters @{
    TargetHost = '8.8.8.8'
    Count = 3
}

# Read from Excel file
Invoke-Task -TaskName 'System.GetUptime' -Computers 'C:\assets.xlsx:HostName' -ShowProgress
```

### Example 3: Service Management

```powershell
# Get status of a specific service across all servers
Invoke-Task -TaskName 'Service.GetService' -Computers $servers -TaskParameters @{
    ServiceName = 'W3SVC'
}

# Restart a service on multiple servers
Invoke-Task -TaskName 'Service.ChangeStatus' -Computers $webServers -TaskParameters @{
    ServiceName = 'W3SVC'
    Action = 'Restart'
    TimeoutSeconds = 60
}
```

### Example 4: Parallel Execution with Retry

```powershell
# Execute with custom throttle, timeout, and retry settings
Invoke-Task -TaskName 'System.GetUptime' `
    -Computers (1..100 | ForEach-Object { "SERVER$_" }) `
    -ThrottleLimit 64 `
    -TimeoutSeconds 30 `
    -RetryCount 3 `
    -RetryDelaySeconds 5 `
    -Verbose
```

### Example 5: HTTP Health Checks

```powershell
# Check API endpoints from multiple locations
$endpoints = @(
    @{ Uri = 'https://api.example.com/health'; Method = 'GET' }
    @{ Uri = 'https://api.example.com/status'; Method = 'GET' }
)

foreach ($endpoint in $endpoints) {
    Invoke-Task -TaskName 'HTTP.InvokeRequest' `
        -Computers 'MONITOR01', 'MONITOR02' `
        -TaskParameters $endpoint
}
```

## Creating Custom Tasks

Create a new task with scaffolding:

```powershell
New-TaskDefinition -TaskName 'Custom.MyTask' -Description 'My custom task'
```

This creates a new task file at `%APPDATA%\Toolbox\Tasks\Custom\My-Task.ps1` with:

- Comment-based help template
- Parameter scaffolding
- Metadata in .NOTES section

**Example custom task:**

```powershell
<#
.SYNOPSIS
    Check if a website is responding

.DESCRIPTION
    Tests HTTP connectivity to a website and returns status code

.PARAMETER Url
    URL to test

.NOTES
    TaskName: Custom.TestWebsite
    Version: 1.0.0
    Author: YourName
    Tags: HTTP, Web, Monitoring
    RequiresElevation: False
    SupportedOS: Windows, Linux, MacOS
    PSEdition: Desktop, Core
    MinPSVersion: 5.1
    Timeout: 30

.EXAMPLE
    Invoke-Task -TaskName 'Custom.TestWebsite' -Computers 'localhost' -TaskParameters @{ Url = 'https://google.com' }
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Url
)

try {
    $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 10
    
    [PSCustomObject]@{
        Url = $Url
        StatusCode = $response.StatusCode
        StatusDescription = $response.StatusDescription
        Success = $true
        ResponseTime = $response.Headers['X-Response-Time']
    }
}
catch {
    [PSCustomObject]@{
        Url = $Url
        StatusCode = $null
        Success = $false
        Error = $_.Exception.Message
    }
}
```

## Configuration

The module stores configuration in `%APPDATA%\Toolbox\Config.json`:

```powershell
# View current configuration
Get-TbConfig

# View specific section
Get-TbConfig -Section Execution

# Update configuration
Set-TbConfig -Section Execution -Property ThrottleLimit -Value 64
Set-TbConfig -Section Logging -Property LogLevel -Value 'Verbose'
```

**Configuration Sections:**

- **Execution**: Throttle limits, timeouts, retry behavior
- **Logging**: Log levels, retention, file paths
- **Tasks**: Task resolution paths (BuiltIn, System, User)
- **Export**: Default export formats and locations

## Remote Authentication

Use the `-Credential` parameter to authenticate to remote systems:

```powershell
# Prompt for credentials
$cred = Get-Credential

# Execute with credentials
Invoke-Task -TaskName 'System.GetUptime' -Computers 'Server1','Server2' -Credential $cred

# Use saved credentials
$username = 'domain\admin'
$password = ConvertTo-SecureString 'P@ssw0rd' -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($username, $password)
Invoke-Task -TaskName 'Service.GetService' -Computers 'C:\servers.txt' -Credential $cred
```

**Credential Flow:**
1. Credentials are passed from `Invoke-Task` to each work item
2. Work items execute in runspace threads with credential context
3. Credentials are used for WinRM/SSH remote connections via `Invoke-Command`
4. Localhost execution doesn't require credentials
5. **No credentials are stored** in logs or configuration files

**Security Notes:**
- Credentials are handled as `[PSCredential]` objects (secure)
- Sensitive data is masked in logs (passwords, tokens, keys)
- SSH authentication supports key-based auth (PowerShell 7+)
- Execution policy and remoting security are respected

## Logging

View task execution logs:

```powershell
# Get recent logs
Get-TaskLog -Last 50

# Filter by task name
Get-TaskLog -TaskName 'System.GetBasicInfo' -Last 20

# Filter by log level
Get-TaskLog -Level Error -Last 100

# Tail mode (follow logs in real-time)
Get-TaskLog -Tail
```

Logs are stored in JSON Lines format at `%APPDATA%\Toolbox\Logs\` with automatic rotation.

## Advanced Features

### Task Resolution Order

Tasks are resolved in priority order (user tasks override system/built-in):

1. **User Tasks**: `%APPDATA%\Toolbox\Tasks\`
2. **System Tasks**: `%ProgramData%\Toolbox\Tasks\`
3. **Built-In Tasks**: Module's `Tasks\BuiltIn\`

### Remote Execution Protocols

The module automatically selects the optimal protocol:

- **Local**: Direct execution (localhost/127.0.0.1)
- **WinRM**: Windows Remote Management (default for remote Windows)
- **SSH**: PowerShell remoting over SSH (PowerShell 7+ on Linux/macOS)

### Parallel Execution

Tasks execute in parallel using runspace pools:

- Configurable throttle limit (1-256 concurrent tasks)
- Automatic load balancing
- Progress reporting
- Timeout and cancellation support

### Error Handling & Retry

- Automatic retry with exponential backoff
- Configurable retry count and delays
- Error aggregation in results
- Detailed error logging

## Cmdlet Reference

| Cmdlet | Description |
|--------|-------------|
| `Invoke-Task` | Execute tasks on one or more computers |
| `Get-TaskDefinition` | List and query available tasks |
| `New-TaskDefinition` | Create new custom tasks |
| `Get-TbConfig` | Retrieve configuration settings |
| `Set-TbConfig` | Update configuration settings |
| `Get-TaskLog` | Query and tail execution logs |
| `Export-TaskResult` | Export results to CSV/JSON/XML/Excel |

## Requirements

- PowerShell 5.1 or higher (PowerShell 7+ recommended)
- Windows PowerShell Desktop or PowerShell Core
- ImportExcel module (for Excel export functionality)

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request

## License

See [LICENSE](LICENSE) file for details.
