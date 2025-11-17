#Requires -Version 5.1

<#
.SYNOPSIS
    Build script for the Toolbox PowerShell module.

.DESCRIPTION
    This script handles building, testing, and packaging the Toolbox module.
    It performs the following tasks:
    - Cleans previous build artifacts
    - Validates module manifest
    - Runs Pester tests (if requested)
    - Copies module files to output directory
    - Creates a distributable package

.PARAMETER Task
    The build task to execute. Valid values: Clean, Build, Test, Package, All
    Default: Build

.PARAMETER OutputPath
    The path where build artifacts will be created.
    Default: .\Build

.PARAMETER SkipTests
    Skip running Pester tests during the build process.

.EXAMPLE
    .\build.ps1 -Task Build
    Builds the module without running tests.

.EXAMPLE
    .\build.ps1 -Task All
    Cleans, builds, tests, and packages the module.

.EXAMPLE
    .\build.ps1 -Task Test
    Runs Pester tests only.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Clean', 'Build', 'Test', 'Package', 'All')]
    [string]$Task = 'Build',

    [Parameter()]
    [string]$OutputPath = (Join-Path $PSScriptRoot 'Build'),

    [Parameter()]
    [switch]$SkipTests
)

#region Helper Functions

function Write-BuildLog {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $color = switch ($Level) {
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        default { 'Cyan' }
    }
    
    $prefix = switch ($Level) {
        'Success' { '[✓]' }
        'Warning' { '[!]' }
        'Error' { '[✗]' }
        default { '[i]' }
    }
    
    Write-Host "$prefix $Message" -ForegroundColor $color
}

function Invoke-CleanTask {
    Write-BuildLog "Cleaning build artifacts..." -Level Info
    
    if (Test-Path $OutputPath) {
        Remove-Item -Path $OutputPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-BuildLog "Removed existing build directory: $OutputPath" -Level Success
    }
    
    # Clean test results
    $testResults = Join-Path $PSScriptRoot 'TestResults'
    if (Test-Path $testResults) {
        Remove-Item -Path $testResults -Recurse -Force -ErrorAction SilentlyContinue
        Write-BuildLog "Removed test results directory" -Level Success
    }
}

function Invoke-BuildTask {
    Write-BuildLog "Building Toolbox module..." -Level Info
    
    # Create output directory
    $modulePath = Join-Path $OutputPath 'Toolbox'
    New-Item -ItemType Directory -Path $modulePath -Force | Out-Null
    
    # Validate module manifest
    $manifestPath = Join-Path $PSScriptRoot 'Toolbox\Toolbox.psd1'
    try {
        $manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
        Write-BuildLog "Module manifest is valid (Version: $($manifest.Version))" -Level Success
    }
    catch {
        Write-BuildLog "Module manifest validation failed: $_" -Level Error
        throw
    }
    
    # Copy module files
    $sourcePath = Join-Path $PSScriptRoot 'Toolbox'
    
    # Copy all module content
    Copy-Item -Path "$sourcePath\*" -Destination $modulePath -Recurse -Force -Exclude '*.Tests.ps1'
    
    Write-BuildLog "Module files copied to: $modulePath" -Level Success
    
    # Display module structure
    Write-BuildLog "Build output structure:" -Level Info
    Get-ChildItem -Path $modulePath -Recurse | ForEach-Object {
        $relativePath = $_.FullName.Replace($modulePath, '').TrimStart('\')
        Write-Host "  $relativePath" -ForegroundColor Gray
    }
}

function Invoke-TestTask {
    Write-BuildLog "Running Pester tests..." -Level Info
    
    # Check if Pester is available
    $pester = Get-Module -ListAvailable -Name Pester | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $pester) {
        Write-BuildLog "Pester module not found. Install it using: Install-Module -Name Pester -Force" -Level Error
        throw "Pester module is required for testing"
    }
    
    Write-BuildLog "Using Pester version: $($pester.Version)" -Level Info
    
    # Import Pester
    Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop
    
    # Configure Pester
    $testsPath = Join-Path $PSScriptRoot 'Tests'
    $testResultsPath = Join-Path $PSScriptRoot 'TestResults'
    
    if (-not (Test-Path $testsPath)) {
        Write-BuildLog "No tests directory found at: $testsPath" -Level Warning
        return
    }
    
    New-Item -ItemType Directory -Path $testResultsPath -Force | Out-Null
    
    $config = New-PesterConfiguration
    $config.Run.Path = $testsPath
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Detailed'
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputPath = Join-Path $testResultsPath 'TestResults.xml'
    $config.CodeCoverage.Enabled = $false
    
    # Run tests
    $result = Invoke-Pester -Configuration $config
    
    # Report results
    Write-BuildLog "Tests completed: $($result.TotalCount) total, $($result.PassedCount) passed, $($result.FailedCount) failed" -Level $(if ($result.FailedCount -eq 0) { 'Success' } else { 'Error' })
    
    if ($result.FailedCount -gt 0) {
        throw "Pester tests failed"
    }
}

function Invoke-PackageTask {
    Write-BuildLog "Creating module package..." -Level Info
    
    $modulePath = Join-Path $OutputPath 'Toolbox'
    if (-not (Test-Path $modulePath)) {
        Write-BuildLog "Module not built. Run Build task first." -Level Error
        throw "Module build not found"
    }
    
    # Get module version from manifest
    $manifestPath = Join-Path $modulePath 'Toolbox.psd1'
    $manifest = Import-PowerShellDataFile -Path $manifestPath
    $version = $manifest.ModuleVersion
    
    # Create package
    $packageName = "Toolbox-v$version.zip"
    $packagePath = Join-Path $OutputPath $packageName
    
    Compress-Archive -Path $modulePath -DestinationPath $packagePath -Force
    
    Write-BuildLog "Package created: $packagePath" -Level Success
    Write-BuildLog "Package size: $([math]::Round((Get-Item $packagePath).Length / 1MB, 2)) MB" -Level Info
}

#endregion

#region Main Execution

try {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    Write-Host ""
    Write-BuildLog "========================================" -Level Info
    Write-BuildLog "  Toolbox Module Build Script" -Level Info
    Write-BuildLog "========================================" -Level Info
    Write-Host ""
    
    switch ($Task) {
        'Clean' {
            Invoke-CleanTask
        }
        'Build' {
            Invoke-CleanTask
            Invoke-BuildTask
        }
        'Test' {
            if (-not $SkipTests) {
                Invoke-TestTask
            }
            else {
                Write-BuildLog "Tests skipped (-SkipTests specified)" -Level Warning
            }
        }
        'Package' {
            Invoke-PackageTask
        }
        'All' {
            Invoke-CleanTask
            Invoke-BuildTask
            
            if (-not $SkipTests) {
                try {
                    Invoke-TestTask
                }
                catch {
                    Write-BuildLog "Tests failed but continuing with packaging..." -Level Warning
                }
            }
            
            Invoke-PackageTask
        }
    }
    
    $stopwatch.Stop()
    Write-Host ""
    Write-BuildLog "Build completed successfully in $($stopwatch.Elapsed.TotalSeconds.ToString('F2')) seconds" -Level Success
    Write-Host ""
}
catch {
    Write-Host ""
    Write-BuildLog "Build failed: $_" -Level Error
    Write-Host ""
    exit 1
}

#endregion
