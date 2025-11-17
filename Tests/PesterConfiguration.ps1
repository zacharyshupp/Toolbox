#Requires -Version 5.1

<#
.SYNOPSIS
    Pester configuration for Toolbox module tests.

.DESCRIPTION
    This file configures the Pester test runner for the Toolbox module.
#>

$config = New-PesterConfiguration

# Run settings
$config.Run.Path = $PSScriptRoot
$config.Run.PassThru = $true
$config.Run.Exit = $false

# Output settings
$config.Output.Verbosity = 'Detailed'

# Test result settings
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = Join-Path $PSScriptRoot '..\TestResults\TestResults.xml'
$config.TestResult.OutputFormat = 'NUnitXml'

# Code coverage settings
$config.CodeCoverage.Enabled = $false
$config.CodeCoverage.Path = Join-Path $PSScriptRoot '..\Toolbox\**\*.ps1'
$config.CodeCoverage.OutputPath = Join-Path $PSScriptRoot '..\TestResults\Coverage.xml'
$config.CodeCoverage.OutputFormat = 'JaCoCo'

# Should settings
$config.Should.ErrorAction = 'Stop'

# Export configuration
$config
