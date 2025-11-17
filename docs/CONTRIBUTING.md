# Contributing to Toolbox

Thank you for considering contributing to Toolbox! This guide will help you get started.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Project Structure](#project-structure)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Style Guidelines](#style-guidelines)

## Code of Conduct

This project adheres to a code of conduct. By participating, you are expected to uphold this code. Please be respectful and constructive in all interactions.

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork locally
3. Create a feature branch from `main`
4. Make your changes
5. Test your changes
6. Submit a pull request

## Development Setup

### Prerequisites

- PowerShell 5.1 or higher (PowerShell 7+ recommended)
- Pester 5.x for testing
- ImportExcel module
- Git for version control
- VS Code (recommended) with PowerShell extension

### Initial Setup

```powershell
# Clone your fork
git clone https://github.com/YOUR-USERNAME/Toolbox.git
cd Toolbox

# Install required modules
Install-Module -Name Pester -MinimumVersion 5.0 -Scope CurrentUser
Install-Module -Name ImportExcel -Scope CurrentUser

# Import the module
Import-Module .\Toolbox\Toolbox.psd1 -Force
```

## Project Structure

```
Toolbox/
├── Toolbox/                    # Module root
│   ├── Public/                 # Exported cmdlets (7 files)
│   ├── Private/                # Internal functions (9 files)
│   ├── Config/                 # Default configuration
│   ├── Schemas/                # JSON validation schemas
│   ├── Tasks/BuiltIn/          # Built-in task library (11 tasks)
│   ├── Toolbox.psd1            # Module manifest
│   └── Toolbox.psm1            # Root module
├── Tests/                      # Pester test suite
│   ├── Unit/                   # Unit tests
│   ├── Integration/            # Integration tests
│   └── Invoke-Tests.ps1        # Test runner
├── TestResults/                # Test output (auto-generated)
├── docs/                       # Documentation
├── .project/                   # Project tracking
├── build.ps1                   # Build script
└── README.md                   # Main documentation
```

### Key Components

- **Public cmdlets**: User-facing functions in `Toolbox/Public/`
- **Private functions**: Internal helpers in `Toolbox/Private/`
- **Built-in tasks**: Reusable tasks in `Toolbox/Tasks/BuiltIn/`
- **Tests**: Comprehensive test suite with 103 tests

## Making Changes

### Branching Strategy

- `main`: Stable production code
- `feature/*`: New features
- `bugfix/*`: Bug fixes
- `docs/*`: Documentation updates

```powershell
# Create a feature branch
git checkout -b feature/my-new-feature
```

### Types of Contributions

1. **Bug Fixes**: Fix issues in existing code
2. **New Features**: Add new cmdlets or functionality
3. **New Tasks**: Create built-in tasks
4. **Documentation**: Improve docs, examples, help
5. **Tests**: Add or improve test coverage
6. **Performance**: Optimize existing code

## Testing

**Always test your changes before submitting!**

### Running Tests

```powershell
cd Tests

# Run all tests
.\Invoke-Tests.ps1

# Run only unit tests
.\Invoke-Tests.ps1 -Tags 'Unit'

# Run only integration tests
.\Invoke-Tests.ps1 -Tags 'Integration'

# Run with code coverage
.\Invoke-Tests.ps1 -CodeCoverage
```

### Test Organization

- **Unit Tests** (`Tests/Unit/`): Test individual functions in isolation
  - `Configuration.Tests.ps1`: Configuration management tests
  - `TaskManagement.Tests.ps1`: Task discovery and management tests
  - `Logging.Tests.ps1`: Logging framework tests

- **Integration Tests** (`Tests/Integration/`): Test complete workflows
  - `TaskExecution.Tests.ps1`: Task execution scenarios
  - `Export.Tests.ps1`: Export functionality tests
  - `BuiltInTasks.Tests.ps1`: All built-in tasks

### Writing Tests

Use Pester 5.x syntax:

```powershell
Describe "My Feature" -Tag 'Unit' {
    BeforeAll {
        # Setup code that runs once
    }
    
    Context "When doing something" {
        It "Should do expected thing" {
            $result = Do-Something -Parameter 'value'
            $result | Should -Not -BeNullOrEmpty
            $result.Property | Should -Be 'expected'
        }
        
        It "Should handle errors" {
            { Do-Something -Invalid } | Should -Throw
        }
    }
    
    AfterAll {
        # Cleanup code
    }
}
```

### Test Requirements

- **All new cmdlets** must have unit tests
- **All new tasks** must have integration tests
- **Bug fixes** should include regression tests
- **Maintain 90%+ pass rate** (100 of 103 tests currently passing)

## Submitting Changes

### Before Submitting

1. **Run all tests** and ensure they pass
2. **Update documentation** if adding features
3. **Add examples** to cmdlet help if applicable
4. **Follow style guidelines** (see below)
5. **Update CHANGELOG** if making significant changes

### Pull Request Process

1. Push your changes to your fork
2. Create a pull request against `main`
3. Provide a clear description of changes
4. Reference any related issues
5. Wait for review and address feedback

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] New task
- [ ] Documentation
- [ ] Performance improvement

## Testing
- [ ] All existing tests pass
- [ ] New tests added for new functionality
- [ ] Manual testing performed

## Checklist
- [ ] Code follows style guidelines
- [ ] Documentation updated
- [ ] Help examples added (if applicable)
- [ ] CHANGELOG updated (if significant change)
```

## Style Guidelines

### PowerShell Coding Standards

Follow [PowerShell Practice and Style Guide](https://poshcode.gitbook.io/powershell-practice-and-style/):

```powershell
# Use approved verbs
function Get-Something { }  # Good
function Fetch-Something { }  # Bad

# Use PascalCase for functions and parameters
function Get-UserInfo {
    param(
        [Parameter(Mandatory)]
        [string]$UserName  # PascalCase
    )
}

# Use clear, descriptive names
$userCount = 0  # Good
$uc = 0  # Bad

# One statement per line
$result = Get-Data
$processed = Process-Data $result  # Good

$result = Get-Data; $processed = Process-Data $result  # Bad (except for short tests)
```

### Comment-Based Help

All public functions must have comprehensive help:

```powershell
<#
.SYNOPSIS
    Brief one-line description

.DESCRIPTION
    Detailed description of what the function does.
    Can span multiple lines.

.PARAMETER ParameterName
    Description of parameter

.EXAMPLE
    Get-Something -Parameter 'value'
    
    Description of what this example does

.EXAMPLE
    Get-Something -Parameter 'value' | Format-Table
    
    Another example with different usage

.OUTPUTS
    Type of objects returned

.NOTES
    Additional information
#>
```

### Error Handling

Use try/catch with meaningful error messages:

```powershell
try {
    $result = Get-Something -ErrorAction Stop
}
catch [System.IO.FileNotFoundException] {
    Write-Error "File not found: $($_.Exception.Message)"
    return
}
catch {
    Write-Error "Unexpected error: $_"
    throw
}
```

### Parameter Validation

Use built-in validation attributes:

```powershell
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,
    
    [Parameter()]
    [ValidateRange(1, 256)]
    [int]$ThrottleLimit = 32,
    
    [Parameter()]
    [ValidateSet('Info', 'Warning', 'Error')]
    [string]$LogLevel = 'Info'
)
```

### Output Objects

Return structured PSCustomObjects:

```powershell
# Good
[PSCustomObject]@{
    PSTypeName = 'Tb.ResultType'
    Property1 = $value1
    Property2 = $value2
}

# Bad
Write-Output $value1, $value2
```

## Adding New Features

### New Cmdlets

1. Create file in `Toolbox/Public/` or `Toolbox/Private/`
2. Add comprehensive comment-based help
3. Use proper parameter validation
4. Add unit tests
5. Update module manifest exports (if public)

### New Built-In Tasks

1. Create file in `Toolbox/Tasks/BuiltIn/<Category>/`
2. Follow task template structure
3. Include metadata in `.NOTES`
4. Add integration tests
5. Update documentation

See [TASK-AUTHORING.md](TASK-AUTHORING.md) for detailed task authoring guide.

### New Configuration Options

1. Update `Toolbox/Config/DefaultConfig.json`
2. Update `Get-TbConfig` and `Set-TbConfig` if needed
3. Add validation in `Initialize-TbConfig`
4. Update configuration tests
5. Document in README

## Documentation

### What to Document

- **All public cmdlets**: Full comment-based help
- **All tasks**: Metadata and examples
- **Complex features**: Architecture docs in `docs/`
- **Configuration**: Options and defaults
- **Examples**: Real-world use cases

### Documentation Files

- `README.md`: Main user documentation
- `docs/TASK-AUTHORING.md`: Task creation guide
- `docs/CONTRIBUTING.md`: This file
- Inline help: Comment-based help in all public functions

## Code Review Process

Pull requests will be reviewed for:

1. **Functionality**: Does it work as intended?
2. **Tests**: Are there adequate tests?
3. **Style**: Does it follow guidelines?
4. **Documentation**: Is it properly documented?
5. **Breaking Changes**: Are they necessary and documented?

## Getting Help

- **Questions**: Open a GitHub Discussion
- **Bugs**: Open a GitHub Issue
- **Chat**: Join our community (if applicable)

## Recognition

Contributors will be recognized in:
- CONTRIBUTORS.md file
- Release notes
- Module credits

Thank you for contributing to Toolbox!
