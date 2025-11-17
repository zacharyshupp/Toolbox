function Get-TaskDefinition {
    <#
    .SYNOPSIS
        Retrieves task definitions from the Toolbox task library.
    
    .DESCRIPTION
        Discovers and retrieves task definitions following the resolution order:
        1. Built-in tasks (module Tasks\BuiltIn)
        2. System tasks (ProgramData\Toolbox\Tasks)
        3. User tasks (AppData\Toolbox\Tasks)
        
        User tasks override system tasks, system tasks override built-in tasks.
    
    .PARAMETER TaskName
        Name of the task to retrieve (e.g., "File.TestPathExists").
        Supports wildcards for listing multiple tasks.
    
    .PARAMETER Category
        Filter tasks by category (e.g., "File", "Process", "Network").
    
    .PARAMETER Tag
        Filter tasks by tag.
    
    .PARAMETER ListAvailable
        Lists all available tasks.
    
    .PARAMETER Refresh
        Clears the task cache and reloads task definitions.
    
    .EXAMPLE
        Get-TaskDefinition -TaskName "File.TestPathExists"
        Retrieves the File.TestPathExists task definition.
    
    .EXAMPLE
        Get-TaskDefinition -ListAvailable
        Lists all available tasks.
    
    .EXAMPLE
        Get-TaskDefinition -Category "File"
        Lists all File category tasks.
    
    .EXAMPLE
        Get-TaskDefinition -TaskName "File.*"
        Lists all tasks in the File category using wildcards.
    
    .EXAMPLE
        Get-TaskDefinition -Tag "Network" -Verbose
        Lists all tasks tagged with "Network" with verbose output.
    
    .EXAMPLE
        Get-TaskDefinition -ListAvailable | Where-Object { $_.RequiresElevation -eq $false }
        Lists all tasks that don"t require elevation.
    
    .EXAMPLE
        Get-TaskDefinition -TaskName "System.GetUptime" | Select-Object Name, Version, Description, Timeout
        Gets detailed information about a specific task.
    
    .OUTPUTS
        PSCustomObject containing task definition metadata and script path.
    
    .NOTES
        Task definitions are cached for performance. Use -Refresh to reload from disk.
    #>
    [CmdletBinding(DefaultParameterSetName = "Name")]
    param(
        [Parameter(Position = 0, ParameterSetName = "Name")]
        [SupportsWildcards()]
        [string]$TaskName,
        
        [Parameter(ParameterSetName = "Filter")]
        [string]$Category,
        
        [Parameter(ParameterSetName = "Filter")]
        [string]$Tag,
        
        [Parameter(ParameterSetName = "List")]
        [switch]$ListAvailable,
        
        [Parameter()]
        [switch]$Refresh
    )
    
    # Initialize task cache if needed
    if ($Refresh -or -not $script:TaskCache) {
        Initialize-TaskCache
    }
    
    try {
        $results = @()
        
        if ($ListAvailable -or $PSCmdlet.ParameterSetName -eq "Filter") {
            # Return all or filtered tasks
            $results = $script:TaskCache.Values
            
            if ($Category) {
                $results = $results | Where-Object { 
                    $_.Name -like "$Category.*" 
                }
            }
            
            if ($Tag) {
                $results = $results | Where-Object { 
                    $_.Tags -contains $Tag 
                }
            }
        }
        elseif ($TaskName) {
            # Handle wildcards
            if ([System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($TaskName)) {
                $results = $script:TaskCache.Values | Where-Object { 
                    $_.Name -like $TaskName 
                }
            }
            else {
                # Direct lookup
                if ($script:TaskCache.ContainsKey($TaskName)) {
                    $results = @($script:TaskCache[$TaskName])
                }
                else {
                    Write-Error "Task "$TaskName" not found. Use -ListAvailable to see available tasks."
                    return
                }
            }
        }
        else {
            Write-Error "Please specify -TaskName, -ListAvailable, or filter parameters."
            return
        }
        
        return $results | Sort-Object Name
    }
    catch {
        Write-Error "Failed to get task definition: $_"
    }
}

function Get-TaskMetadataFromScript {
    <#
    .SYNOPSIS
        Parses task metadata from a PowerShell script"s comment-based help.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath
    )
    
    $content = Get-Content -Path $ScriptPath -Raw
    
    # Extract comment-based help block
    if ($content -match "(?s)<#(.*?)#>") {
        $helpBlock = $Matches[1]
        
        # Extract .NOTES section which contains our task metadata
        if ($helpBlock -match "(?s)\.NOTES\s+(.*?)(?=\.EXAMPLE|\.LINK|$)") {
            $notesSection = $Matches[1].Trim()
            
            # Parse key-value pairs from NOTES
            $metadata = @{}
            $notesSection -split "`n" | ForEach-Object {
                if ($_ -match "^\s*(\w+):\s*(.+)$") {
                    $key = $Matches[1].Trim()
                    $value = $Matches[2].Trim()
                    $metadata[$key] = $value
                }
            }
            
            # Extract SYNOPSIS
            $synopsis = if ($helpBlock -match "\.SYNOPSIS\s+(.*?)(?=\.DESCRIPTION|\.)") {
                $Matches[1].Trim()
            } else { "" }
            
            # Extract DESCRIPTION
            $description = if ($helpBlock -match "\.DESCRIPTION\s+(.*?)(?=\.PARAMETER|\.NOTES)") {
                $Matches[1].Trim() -replace "\s+", " "
            } else { $synopsis }
            
            # Parse parameters from .PARAMETER sections
            $parameters = @()
            $paramMatches = [regex]::Matches($helpBlock, "\.PARAMETER\s+(\w+)\s+(.*?)(?=\.PARAMETER|\.NOTES|\.EXAMPLE|$)", "Singleline")
            foreach ($match in $paramMatches) {
                $parameters += [PSCustomObject]@{
                    Name = $match.Groups[1].Value.Trim()
                    Description = $match.Groups[2].Value.Trim() -replace "\s+", " "
                }
            }
            
            # Build task definition object
            $taskDef = [PSCustomObject]@{
                Name = $metadata["TaskName"]
                Version = $metadata["Version"]
                Description = $description
                Author = $metadata["Author"]
                Synopsis = $synopsis
                Parameters = $parameters
                Tags = if ($metadata["Tags"]) { $metadata["Tags"] -split ",\s*" } else { @() }
                RequiresElevation = [bool]($metadata["RequiresElevation"] -eq "True")
                SupportedOS = if ($metadata["SupportedOS"]) { $metadata["SupportedOS"] -split ",\s*" } else { @() }
                PSEdition = if ($metadata["PSEdition"]) { $metadata["PSEdition"] -split ",\s*" } else { @() }
                MinPSVersion = $metadata["MinPSVersion"]
                Timeout = if ($metadata["Timeout"]) { [int]$metadata["Timeout"] } else { 60 }
            }
            
            return $taskDef
        }
    }
    
    throw "Unable to parse task metadata from script. Ensure .NOTES section contains TaskName."
}

function Initialize-TaskCache {
    <#
    .SYNOPSIS
        Initializes the task definition cache.
    #>
    [CmdletBinding()]
    param()
    
    Write-Verbose "Initializing task cache..."
    
    $config = Get-TbConfig -Section Tasks
    $script:TaskCache = @{}
    
    # Define search paths in resolution order (reverse, so later entries override earlier)
    $searchPaths = @(
        @{ Path = $config.BuiltInTaskPath; Source = "BuiltIn" }
        @{ Path = $config.SystemTaskPath; Source = "System" }
        @{ Path = $config.UserTaskPath; Source = "User" }
    )
    
    foreach ($pathInfo in $searchPaths) {
        if (-not (Test-Path $pathInfo.Path)) {
            Write-Verbose "Task path not found: $($pathInfo.Path)"
            continue
        }
        
        # Find all .ps1 files in category subdirectories
        $taskFiles = Get-ChildItem -Path $pathInfo.Path -Filter "*.ps1" -Recurse -File
        
        foreach ($taskFile in $taskFiles) {
            try {
                # Parse metadata from comment-based help and .NOTES section
                $taskDef = Get-TaskMetadataFromScript -ScriptPath $taskFile.FullName
                
                # Validate task definition
                if (-not $taskDef.Name) {
                    Write-Warning "Task definition missing TaskName in .NOTES section: $($taskFile.FullName)"
                    continue
                }
                
                # Add metadata
                $taskDef | Add-Member -NotePropertyName "FullScriptPath" -NotePropertyValue $taskFile.FullName -Force
                $taskDef | Add-Member -NotePropertyName "Source" -NotePropertyValue $pathInfo.Source -Force
                
                # Add or update in cache (later sources override earlier ones)
                $script:TaskCache[$taskDef.Name] = $taskDef
                
                Write-Verbose "Loaded task: $($taskDef.Name) from $($pathInfo.Source)"
            }
            catch {
                Write-Warning "Failed to load task from $($taskFile.FullName): $_"
            }
        }
    }
    
    Write-Verbose "Task cache initialized with $($script:TaskCache.Count) task(s)"
}

function Test-TaskCompatibility {
    <#
    .SYNOPSIS
        Tests if a task is compatible with the current environment.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$TaskDefinition
    )
    
    $issues = @()
    
    # Check PowerShell version
    if ($TaskDefinition.MinPSVersion) {
        $minVersion = [version]$TaskDefinition.MinPSVersion
        if ($PSVersionTable.PSVersion -lt $minVersion) {
            $issues += "Requires PowerShell $minVersion or higher (current: $($PSVersionTable.PSVersion))"
        }
    }
    
    # Check PowerShell edition
    if ($TaskDefinition.PSEdition) {
        $currentEdition = $PSVersionTable.PSEdition
        if ($currentEdition -notin $TaskDefinition.PSEdition) {
            $issues += "Requires PowerShell edition: $($TaskDefinition.PSEdition -join " or ") (current: $currentEdition)"
        }
    }
    
    # Check OS compatibility
    if ($TaskDefinition.SupportedOS) {
        $currentOS = if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) { "Windows" }
                     elseif ($IsLinux) { "Linux" }
                     elseif ($IsMacOS) { "MacOS" }
                     else { "Unknown" }
        
        if ($currentOS -notin $TaskDefinition.SupportedOS) {
            $issues += "Not supported on $currentOS (supported: $($TaskDefinition.SupportedOS -join ", "))"
        }
    }
    
    if ($issues.Count -gt 0) {
        Write-Warning "Task "$($TaskDefinition.Name)" compatibility issues:"
        $issues | ForEach-Object { Write-Warning "  - $_" }
        return $false
    }
    
    return $true
}
