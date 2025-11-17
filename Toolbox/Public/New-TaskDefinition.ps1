function New-TaskDefinition {
    <#
    .SYNOPSIS
        Creates a new task definition scaffolding.
    
    .DESCRIPTION
        Generates a new task definition with Task.json metadata and Task.ps1 
        implementation template in the user task directory.
    
    .PARAMETER TaskName
        Name of the task in Category.TaskName format (e.g., "Custom.MyTask").
    
    .PARAMETER Description
        Task description.
    
    .PARAMETER Author
        Task author name. Defaults to current user.
    
    .PARAMETER Parameters
        Array of parameter definitions. Each should be a hashtable with Name, Type, 
        Mandatory, and Description keys.
    
    .PARAMETER RequiresElevation
        Indicates if the task requires elevated privileges.
    
    .PARAMETER OutputPath
        Custom output path for the task. If not specified, creates in user task directory.
    
    .PARAMETER Force
        Overwrite existing task if it exists.
    
    .EXAMPLE
        New-TaskDefinition -TaskName "Custom.MyTask" -Description "My custom task"
        Creates a basic task template.
    
    .EXAMPLE
        $params = @(
            @{ Name = "Path"; Type = "string"; Mandatory = $true; Description = "File path" }
            @{ Name = "Recurse"; Type = "bool"; Mandatory = $false; Description = "Recurse subdirectories" }
        )
        New-TaskDefinition -TaskName "Custom.FileProcessor" -Description "Process files" -Parameters $params
        Creates a task with custom parameters.
    
    .EXAMPLE
        New-TaskDefinition -TaskName "Security.AuditUsers" -Description "Audit user accounts" -RequiresElevation
        Creates a task that requires administrator privileges.
    
    .EXAMPLE
        New-TaskDefinition -TaskName "Custom.BackupCheck" -Description "Verify backups" -OutputPath "C:\Scripts\Tasks"
        Creates a task in a custom location instead of user task directory.
    
    .OUTPUTS
        PSCustomObject containing the created task definition paths.
    
    .NOTES
        Tasks are created in %APPDATA%\Toolbox\Tasks by default.
        Task names must follow Category.TaskName format with proper PowerShell Verb-Noun naming.
        Generated files include proper comment-based help and parameter definitions.
        Edit the generated .ps1 file to implement your task logic.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern("^[A-Za-z]+\.[A-Za-z0-9]+$")]
        [string]$TaskName,
        
        [Parameter(Mandatory, Position = 1)]
        [string]$Description,
        
        [Parameter()]
        [string]$Author = $env:USERNAME,
        
        [Parameter()]
        [hashtable[]]$Parameters,
        
        [Parameter()]
        [switch]$RequiresElevation,
        
        [Parameter()]
        [string]$OutputPath,
        
        [Parameter()]
        [switch]$Force
    )
    
    try {
        # Parse category from task name (e.g., "File.GetPathSize" -> Category: "File", TaskName: "GetPathSize")
        $parts = $TaskName -split "\."
        if ($parts.Count -ne 2) {
            Write-Error "TaskName must be in "Category.TaskName" format (e.g., "Custom.MyTask")"
            return
        }
        
        $category = $parts[0]
        $taskSimpleName = $parts[1]
        
        # Convert task name to PowerShell verb-noun format (e.g., "GetPathSize" -> "Get-PathSize")
        $fileName = $taskSimpleName -creplace "([a-z])([A-Z])", "$1-$2"
        if ($fileName -notmatch "^[A-Z][a-z]+-") {
            # If no verb prefix detected, keep original name
            $fileName = $taskSimpleName
        }
        $fileName = "$fileName.ps1"
        
        # Determine output directory (category folder only)
        if ($OutputPath) {
            $categoryDir = Join-Path $OutputPath $category
        }
        else {
            $config = Get-TbConfig -Section Tasks
            $categoryDir = Join-Path $config.UserTaskPath $category
        }
        
        $taskScriptPath = Join-Path $categoryDir $fileName
        
        # Check if task already exists
        if ((Test-Path $taskScriptPath) -and -not $Force) {
            Write-Error "Task file already exists: $taskScriptPath. Use -Force to overwrite."
            return
        }
        
        if ($PSCmdlet.ShouldProcess($taskScriptPath, "Create task definition")) {
            # Create category directory
            New-Item -ItemType Directory -Path $categoryDir -Force | Out-Null
            Write-Verbose "Created category directory: $categoryDir"
            
            # Generate parameter documentation
            $paramDocs = ""
            $paramBlock = ""
            
            if ($Parameters) {
                # Build .PARAMETER documentation
                $paramDocLines = @()
                foreach ($param in $Parameters) {
                    $paramDocLines += ".PARAMETER $($param.Name)"
                    $paramDocLines += "    $($param.Description)"
                    $paramDocLines += ""
                }
                $paramDocs = "`n" + ($paramDocLines -join "`n")
                
                # Build parameter block code
                $paramLines = @()
                foreach ($param in $Parameters) {
                    $paramLine = "    "
                    
                    if ($param.Mandatory) {
                        $paramLine += "[Parameter(Mandatory)]`n    "
                    }
                    else {
                        $paramLine += "[Parameter()]`n    "
                    }
                    
                    $paramLine += "[$($param.Type)]`$$($param.Name)"
                    
                    if ($param.DefaultValue) {
                        $paramLine += " = $($param.DefaultValue)"
                    }
                    
                    $paramLines += $paramLine
                }
                
                $paramBlock = "`n$($paramLines -join ",`n`n")`n"
            }
            
            # Create Task.ps1 template
            $taskScript = @"
<#
.SYNOPSIS
    $Description

.DESCRIPTION
    Detailed task implementation for $TaskName.
$paramDocs
.NOTES
    TaskName: $TaskName
    Version: 1.0.0
    Author: $Author
    Tags: $category
    RequiresElevation: $([bool]$RequiresElevation)
    SupportedOS: Windows, Linux, MacOS
    PSEdition: Desktop, Core
    MinPSVersion: 5.1
    Timeout: 60

.EXAMPLE
    Invoke-Task -TaskName "$TaskName" -Computers "localhost"
#>
[CmdletBinding()]
param($paramBlock)

try {
    # Task implementation goes here
    Write-Verbose "Starting task: $TaskName"
    
    # Example: Return task output
    `$result = [PSCustomObject]@{
        Success = `$true
        Message = "Task completed successfully"
        # Add your output properties here
    }
    
    # Return result
    return `$result
}
catch {
    # Handle errors
    Write-Error "Task failed: `$_"
    throw
}
"@
            
            $taskScript | Set-Content -Path $taskScriptPath -Force
            Write-Verbose "Created task script: $taskScriptPath"
            
            # Clear task cache to pick up new task
            $script:TaskCache = $null
            
            Write-Host "✓ Task created successfully: $TaskName" -ForegroundColor Green
            Write-Host "  Location: $taskScriptPath" -ForegroundColor Cyan
            Write-Host "  Edit the script to implement your task logic" -ForegroundColor Yellow
            
            return [PSCustomObject]@{
                TaskName = $TaskName
                Category = $category
                FileName = $fileName
                TaskScriptPath = $taskScriptPath
            }
        }
    }
    catch {
        Write-Error "Failed to create task definition: $_"
    }
}
