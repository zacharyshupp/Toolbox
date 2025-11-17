#Requires -Version 5.1
#Requires -Modules Pester

<#
.SYNOPSIS
    Runs all Pester tests for the Toolbox module.

.DESCRIPTION
    Executes unit and integration tests with optional code coverage analysis.

.PARAMETER Tags
    Run only tests with specific tags (Unit, Integration, etc.)

.PARAMETER ExcludeTags
    Exclude tests with specific tags.

.PARAMETER CodeCoverage
    Enable code coverage analysis.

.PARAMETER OutputFormat
    Output format for test results (NUnitXml, JUnitXml).

.EXAMPLE
    .\Invoke-Tests.ps1

.EXAMPLE
    .\Invoke-Tests.ps1 -Tags 'Unit'

.EXAMPLE
    .\Invoke-Tests.ps1 -CodeCoverage
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string[]]$Tags,
    
    [Parameter()]
    [string[]]$ExcludeTags,
    
    [Parameter()]
    [switch]$CodeCoverage,
    
    [Parameter()]
    [ValidateSet('NUnitXml', 'JUnitXml')]
    [string]$OutputFormat = 'NUnitXml'
)

$ErrorActionPreference = 'Stop'

# Ensure Pester is available
if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Error "Pester module is not installed. Install it with: Install-Module -Name Pester -Force"
    exit 1
}

# Import Pester (require 5.x)
Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop

# Set up paths
$projectRoot = Split-Path $PSScriptRoot -Parent
$testsPath = $PSScriptRoot
$moduleRoot = Join-Path $projectRoot 'Toolbox'
$testResultsPath = Join-Path $projectRoot 'TestResults'

# Ensure test results directory exists
if (-not (Test-Path $testResultsPath)) {
    New-Item -Path $testResultsPath -ItemType Directory -Force | Out-Null
}

# Build configuration
$config = New-PesterConfiguration

# Run settings
$config.Run.Path = $testsPath
$config.Run.PassThru = $true
$config.Run.Exit = $false

# Filter settings
if ($Tags) {
    $config.Filter.Tag = $Tags
}
if ($ExcludeTags) {
    $config.Filter.ExcludeTag = $ExcludeTags
}

# Output settings
$config.Output.Verbosity = 'Detailed'

# Test result settings
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = Join-Path $testResultsPath "TestResults-$(Get-Date -Format 'yyyyMMdd-HHmmss').xml"
$config.TestResult.OutputFormat = $OutputFormat

# Code coverage settings
if ($CodeCoverage) {
    $config.CodeCoverage.Enabled = $true
    $config.CodeCoverage.Path = @(
        "$moduleRoot\Public\*.ps1"
        "$moduleRoot\Private\*.ps1"
    )
    $config.CodeCoverage.OutputPath = Join-Path $testResultsPath "Coverage-$(Get-Date -Format 'yyyyMMdd-HHmmss').xml"
    $config.CodeCoverage.OutputFormat = 'JaCoCo'
}

# Should settings
$config.Should.ErrorAction = 'Stop'

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Toolbox Module - Test Execution" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Tests Path: $testsPath" -ForegroundColor Gray
Write-Host "Results Path: $testResultsPath" -ForegroundColor Gray
if ($Tags) {
    Write-Host "Filter Tags: $($Tags -join ', ')" -ForegroundColor Gray
}
if ($ExcludeTags) {
    Write-Host "Exclude Tags: $($ExcludeTags -join ', ')" -ForegroundColor Gray
}
if ($CodeCoverage) {
    Write-Host "Code Coverage: Enabled" -ForegroundColor Gray
}
Write-Host ""

# Run tests
$result = Invoke-Pester -Configuration $config

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Test Results Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Tests: $($result.TotalCount)" -ForegroundColor White
Write-Host "Passed: $($result.PassedCount)" -ForegroundColor Green
Write-Host "Failed: $($result.FailedCount)" -ForegroundColor $(if ($result.FailedCount -eq 0) { 'Green' } else { 'Red' })
Write-Host "Skipped: $($result.SkippedCount)" -ForegroundColor Yellow
Write-Host "Duration: $($result.Duration.ToString('mm\:ss\.fff'))" -ForegroundColor White
Write-Host ""

if ($CodeCoverage -and $result.CodeCoverage) {
    $coveragePercent = [math]::Round(($result.CodeCoverage.CoveragePercent), 2)
    $coverageColor = if ($coveragePercent -ge 80) { 'Green' } 
                     elseif ($coveragePercent -ge 60) { 'Yellow' } 
                     else { 'Red' }
    
    Write-Host "Code Coverage: $coveragePercent%" -ForegroundColor $coverageColor
    Write-Host "Commands Analyzed: $($result.CodeCoverage.NumberOfCommandsAnalyzed)" -ForegroundColor Gray
    Write-Host "Commands Executed: $($result.CodeCoverage.NumberOfCommandsExecuted)" -ForegroundColor Gray
    Write-Host "Commands Missed: $($result.CodeCoverage.NumberOfCommandsMissed)" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "Test results saved to: $($config.TestResult.OutputPath.Value)" -ForegroundColor Gray
if ($CodeCoverage) {
    Write-Host "Coverage report saved to: $($config.CodeCoverage.OutputPath.Value)" -ForegroundColor Gray
}
Write-Host ""

# Exit with appropriate code
if ($result.FailedCount -gt 0) {
    Write-Host "❌ Tests Failed!" -ForegroundColor Red
    exit 1
} else {
    Write-Host "✅ All Tests Passed!" -ForegroundColor Green
    exit 0
}
