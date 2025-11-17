# Task Authoring Guide

This guide explains how to create custom tasks for the Toolbox module.

## Overview

Tasks in Toolbox are self-contained PowerShell scripts with embedded metadata. They can be executed locally or on remote computers in parallel, with automatic error handling, retry logic, and result aggregation.

## Quick Start

Create a new task using the scaffolding cmdlet:

```powershell
New-TaskDefinition -TaskName 'Custom.MyTask' -Description 'My custom task'
```

This creates a template at `%APPDATA%\Toolbox\Tasks\Custom\My-Task.ps1`.

## Task Structure

### File Naming and Location

- **Naming Convention**: `<Category>.<TaskName>` (e.g., `Custom.MyTask`)
- **File Name**: PowerShell verb-noun format (e.g., `My-Task.ps1`)
- **Location**: Tasks are stored in category subdirectories:
  - User tasks: `%APPDATA%\Toolbox\Tasks\<Category>\`
  - System tasks: `%ProgramData%\Toolbox\Tasks\<Category>\`
  - Built-in tasks: `<ModulePath>\Tasks\BuiltIn\<Category>\`

### Task Template

```powershell
<#
.SYNOPSIS
    Brief one-line description

.DESCRIPTION
    Detailed description of what the task does.
    Can span multiple lines.

.PARAMETER ParamName
    Description of parameter

.NOTES
    TaskName: Custom.MyTask
    Version: 1.0.0
    Author: Your Name
    Tags: tag1, tag2, tag3
    RequiresElevation: False
    SupportedOS: Windows, Linux, MacOS
    PSEdition: Desktop, Core
    MinPSVersion: 5.1
    Timeout: 60

.EXAMPLE
    Invoke-Task -TaskName 'Custom.MyTask' -Computers 'localhost' -TaskParameters @{ Param = 'value' }
    
    Description of what this example does
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ParamName,
    
    [Parameter()]
    [int]$OptionalParam = 10
)

try {
    # Your task logic here
    
    # Return a structured object
    [PSCustomObject]@{
        Status = 'Success'
        Value = $result
        Timestamp = Get-Date
    }
}
catch {
    # Errors are automatically captured and logged
    throw "Task failed: $_"
}
```

## Metadata Reference

All metadata is specified in the `.NOTES` section:

| Field | Required | Description | Example |
|-------|----------|-------------|---------|
| `TaskName` | Yes | Full task identifier | `Custom.MyTask` |
| `Version` | Yes | Semantic version | `1.0.0` |
| `Author` | No | Task author | `John Doe` |
| `Tags` | Yes | Comma-separated tags | `monitoring, disk, storage` |
| `RequiresElevation` | Yes | Needs admin rights | `True` or `False` |
| `SupportedOS` | Yes | Compatible OS | `Windows`, `Linux`, `MacOS` |
| `PSEdition` | Yes | PowerShell edition | `Desktop`, `Core`, or both |
| `MinPSVersion` | Yes | Minimum PS version | `5.1`, `7.0` |
| `Timeout` | Yes | Default timeout (seconds) | `60` |

### Tag Categories

Use descriptive tags to help with task discovery:

- **Function**: `monitoring`, `configuration`, `deployment`, `troubleshooting`
- **Resource**: `disk`, `network`, `service`, `process`, `registry`
- **Operation**: `read`, `write`, `test`, `restart`, `backup`

## Best Practices

### 1. Output Structure

Always return structured objects (PSCustomObject) with consistent properties:

```powershell
# Good
[PSCustomObject]@{
    Status = 'Success'
    MachineName = $env:COMPUTERNAME
    Result = $data
    Timestamp = Get-Date
}

# Bad - don't just output raw values
Write-Output "Success"
```

### 2. Error Handling

Use try/catch and throw meaningful errors:

```powershell
try {
    $result = Get-Something -ErrorAction Stop
}
catch [System.UnauthorizedAccessException] {
    throw "Access denied. This task requires elevation."
}
catch {
    throw "Failed to get data: $($_.Exception.Message)"
}
```

### 3. Parameter Validation

Use PowerShell validation attributes:

```powershell
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,
    
    [Parameter()]
    [ValidateSet('KB', 'MB', 'GB', 'TB')]
    [string]$Unit = 'MB',
    
    [Parameter()]
    [ValidateRange(1, 3600)]
    [int]$TimeoutSeconds = 30
)
```

### 4. Platform Compatibility

Check platform compatibility when needed:

```powershell
# Check OS
if ($PSVersionTable.PSEdition -eq 'Desktop') {
    # Windows PowerShell specific code
}

# Check for Windows-specific features
if ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') {
    Get-WmiObject -Class Win32_OperatingSystem
}
else {
    # Linux/macOS alternative
    Get-Content /proc/uptime
}
```

### 5. Performance

- Avoid expensive operations in loops
- Use `-ErrorAction Stop` for critical operations
- Don't call remote systems from within tasks (that's already handled)
- Keep tasks focused on a single responsibility

### 6. Documentation

Provide comprehensive examples in comment-based help:

```powershell
.EXAMPLE
    Invoke-Task -TaskName 'Custom.MyTask' -Computers 'SERVER01' -TaskParameters @{ Path = 'C:\Data' }
    
    Check data directory on SERVER01

.EXAMPLE
    Invoke-Task -TaskName 'Custom.MyTask' -Computers (Get-Content servers.txt) -TaskParameters @{ 
        Path = 'D:\Logs'
        OlderThanDays = 30
    } -ThrottleLimit 50
    
    Process multiple servers with custom throttle limit
```

## Testing Your Task

### Test Locally First

```powershell
# Test directly
. "C:\Users\YourName\AppData\Roaming\Toolbox\Tasks\Custom\My-Task.ps1"
My-Task -ParamName 'test'

# Test through Invoke-Task on localhost
Invoke-Task -TaskName 'Custom.MyTask' -Computers 'localhost' -TaskParameters @{
    ParamName = 'test'
}
```

### Test Error Handling

```powershell
# Test with invalid parameters
Invoke-Task -TaskName 'Custom.MyTask' -Computers 'localhost' -TaskParameters @{
    ParamName = '' # Should fail validation
}

# Test timeout
Invoke-Task -TaskName 'Custom.MyTask' -Computers 'localhost' -TimeoutSeconds 5
```

### Test on Remote Systems

```powershell
# Test on a dev/test system first
Invoke-Task -TaskName 'Custom.MyTask' -Computers 'DEV-SERVER' -Verbose

# Test with multiple targets
Invoke-Task -TaskName 'Custom.MyTask' -Computers 'DEV01', 'DEV02', 'DEV03'
```

## Advanced Patterns

### Progress Reporting

For long-running tasks, use Write-Progress:

```powershell
$items = Get-ChildItem -Path $Path -Recurse
$total = $items.Count
$current = 0

foreach ($item in $items) {
    $current++
    Write-Progress -Activity "Processing files" -Status $item.Name `
        -PercentComplete (($current / $total) * 100)
    
    # Process item
}

Write-Progress -Activity "Processing files" -Completed
```

### Handling Credentials

Don't define credential parameters in tasks. Remote execution handles credentials:

```powershell
# Bad - don't do this
param([PSCredential]$Credential)

# Good - tasks execute in remote context automatically
# Just access resources as normal
Get-ChildItem -Path 'C:\SecuredFolder'
```

### Working with Modules

Load required modules in the task:

```powershell
# Check and import module
if (-not (Get-Module -Name RequiredModule -ErrorAction SilentlyContinue)) {
    Import-Module RequiredModule -ErrorAction Stop
}
```

### Complex Return Objects

For complex data, return nested objects:

```powershell
[PSCustomObject]@{
    Summary = [PSCustomObject]@{
        TotalItems = $total
        SuccessCount = $success
        FailureCount = $failed
    }
    Details = @($items | ForEach-Object {
        [PSCustomObject]@{
            Name = $_.Name
            Status = $_.Status
            Size = $_.Size
        }
    })
    Timestamp = Get-Date
}
```

## Common Patterns

### File Operations

```powershell
param(
    [Parameter(Mandatory)]
    [string]$Path
)

if (-not (Test-Path $Path)) {
    throw "Path not found: $Path"
}

$item = Get-Item -Path $Path
[PSCustomObject]@{
    Path = $item.FullName
    Exists = $true
    Type = $item.PSIsContainer ? 'Directory' : 'File'
    Size = $item.Length
    LastModified = $item.LastWriteTime
}
```

### Service Management

```powershell
param(
    [Parameter(Mandatory)]
    [string]$ServiceName
)

$service = Get-Service -Name $ServiceName -ErrorAction Stop

[PSCustomObject]@{
    Name = $service.Name
    DisplayName = $service.DisplayName
    Status = $service.Status
    StartType = $service.StartType
    CanStop = $service.CanStop
}
```

### Registry Access

```powershell
param(
    [Parameter(Mandatory)]
    [string]$Path,
    
    [Parameter(Mandatory)]
    [string]$Name
)

if (-not $IsWindows -and $PSVersionTable.PSEdition -ne 'Desktop') {
    throw "Registry operations are only supported on Windows"
}

$value = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop

[PSCustomObject]@{
    Path = $Path
    Name = $Name
    Value = $value.$Name
    Type = $value.GetType().Name
}
```

### HTTP Requests

```powershell
param(
    [Parameter(Mandatory)]
    [string]$Uri,
    
    [Parameter()]
    [string]$Method = 'GET'
)

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$response = Invoke-RestMethod -Uri $Uri -Method $Method -TimeoutSec 30
$sw.Stop()

[PSCustomObject]@{
    Uri = $Uri
    Method = $Method
    StatusCode = 200
    ResponseTime = $sw.ElapsedMilliseconds
    ContentLength = $response.Length
    Success = $true
}
```

## Task Discovery

Once created, your task will be automatically discovered:

```powershell
# List all custom tasks
Get-TaskDefinition -Category Custom

# View task details
Get-TaskDefinition -Name 'Custom.MyTask'

# Search by tag
Get-TaskDefinition -ListAvailable | Where-Object { $_.Tags -contains 'monitoring' }
```

## Troubleshooting

### Task Not Found

1. Check file location and naming
2. Verify metadata has correct `TaskName`
3. Refresh task cache: `Get-TaskDefinition -Refresh`

### Task Fails Immediately

1. Test the script directly (dot-source it)
2. Check parameter validation
3. Review logs: `Get-TaskLog -TaskName 'Custom.MyTask' -Last 10`

### Timeout Issues

1. Increase timeout in metadata or via `-TimeoutSeconds`
2. Optimize task performance
3. Remove unnecessary operations

### Permission Errors

1. Set `RequiresElevation: True` in metadata
2. Ensure remote systems grant proper permissions
3. Test with explicit credentials

## Examples

See the built-in tasks in `<ModulePath>\Tasks\BuiltIn\` for production-ready examples:

- **File**: `Test-PathExists.ps1`, `Get-PathSize.ps1`
- **Network**: `Test-Connection.ps1`, `Test-Port.ps1`
- **System**: `Get-Uptime.ps1`, `Get-BasicInfo.ps1`
- **Service**: `Get-Service.ps1`
- **Registry**: `Get-Value.ps1`
- **HTTP**: `Invoke-Request.ps1`

## Getting Help

- View module help: `Get-Help Invoke-Task -Full`
- View task examples: `Get-Help about_Toolbox_Tasks`
- Check logs: `Get-TaskLog -Tail`
- Open an issue on GitHub

---

*Happy Task Authoring!*
