[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$ApiKeyFile = "$PSScriptRoot\ApiKey.txt"
)

$ErrorActionPreference = 'Stop'

Write-Host "`n=== Toolbox Module Publishing Script ===" -ForegroundColor Cyan
Write-Host "This script will publish the Toolbox module to PowerShell Gallery`n" -ForegroundColor Cyan

# Step 1: Validate module manifest
Write-Host "[1/6] Validating module manifest..." -ForegroundColor Yellow
try {
    $manifest = Test-ModuleManifest -Path "$PSScriptRoot\Toolbox\Toolbox.psd1" -ErrorAction Stop
    Write-Host "  ✓ Module version: $($manifest.Version)" -ForegroundColor Green
    Write-Host "  ✓ Author: $($manifest.Author)" -ForegroundColor Green
    Write-Host "  ✓ PowerShell version: $($manifest.PowerShellVersion)+" -ForegroundColor Green
    Write-Host "  ✓ Functions exported: $($manifest.ExportedFunctions.Count)" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Module manifest validation failed!" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Red
    exit 1
}

# Step 2: Test module import
Write-Host "`n[2/6] Testing module import..." -ForegroundColor Yellow
try {
    Import-Module "$PSScriptRoot\Toolbox\Toolbox.psd1" -Force -ErrorAction Stop
    Write-Host "  ✓ Module imported successfully" -ForegroundColor Green
    
    # Verify cmdlets are available
    $commands = Get-Command -Module Toolbox
    Write-Host "  ✓ $($commands.Count) commands available" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Module import failed!" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Red
    exit 1
}

# Step 3: Verify required files exist
Write-Host "`n[3/6] Verifying required files..." -ForegroundColor Yellow
$requiredFiles = @(
    @{ Path = "$PSScriptRoot\LICENSE"; Name = "LICENSE" }
    @{ Path = "$PSScriptRoot\README.md"; Name = "README.md" }
    @{ Path = "$PSScriptRoot\CHANGELOG.md"; Name = "CHANGELOG.md" }
)

$missingFiles = @()
foreach ($file in $requiredFiles) {
    if (Test-Path $file.Path) {
        Write-Host "  ✓ $($file.Name) found" -ForegroundColor Green
    }
    else {
        Write-Host "  ✗ $($file.Name) missing" -ForegroundColor Red
        $missingFiles += $file.Name
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host "`n  Missing required files: $($missingFiles -join ', ')" -ForegroundColor Red
    exit 1
}

# Step 4: Check for API key
Write-Host "`n[4/6] Checking for API key..." -ForegroundColor Yellow
$apiKey = $null

if ($env:PSGalleryApiKey) {
    $apiKey = $env:PSGalleryApiKey
    Write-Host "  ✓ Using API key from environment variable" -ForegroundColor Green
}
elseif (Test-Path $ApiKeyFile) {
    try {
        $secureKey = Get-Content $ApiKeyFile -Raw | ConvertTo-SecureString -ErrorAction Stop
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
        $apiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        Write-Host "  ✓ Using API key from file: $ApiKeyFile" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ API key file exists but is invalid or corrupted" -ForegroundColor Red
        Write-Host "  Delete the file and recreate it with the instructions below" -ForegroundColor Yellow
        $apiKey = $null
    }
}

if (-not $apiKey) {
    Write-Host "  ✗ API key not found!" -ForegroundColor Red
    Write-Host "`n  Please set one of the following:" -ForegroundColor Yellow
    Write-Host "    1. Environment variable: `$env:PSGalleryApiKey = 'your-api-key'" -ForegroundColor Yellow
    Write-Host "    2. Create encrypted file: $ApiKeyFile" -ForegroundColor Yellow
    Write-Host "`n  To create encrypted API key file, run:" -ForegroundColor Cyan
    Write-Host "    `$key = Read-Host 'Enter API Key' -AsSecureString" -ForegroundColor Cyan
    Write-Host "    ConvertFrom-SecureString `$key | Out-File '$ApiKeyFile'" -ForegroundColor Cyan
    Write-Host "`n  Get your API key from: https://www.powershellgallery.com/account/apikeys" -ForegroundColor Cyan
    exit 1
}

# Step 5: Check if module already exists on gallery
Write-Host "`n[5/6] Checking PowerShell Gallery..." -ForegroundColor Yellow
try {
    $existingModule = Find-Module -Name Toolbox -ErrorAction SilentlyContinue
    if ($existingModule) {
        Write-Host "  ⚠ Module 'Toolbox' already exists on PowerShell Gallery" -ForegroundColor Yellow
        Write-Host "    Current version: $($existingModule.Version)" -ForegroundColor Yellow
        Write-Host "    New version: $($manifest.Version)" -ForegroundColor Yellow
        
        if ([version]$manifest.Version -le [version]$existingModule.Version) {
            Write-Host "`n  ✗ New version must be greater than existing version!" -ForegroundColor Red
            Write-Host "    Update ModuleVersion in Toolbox.psd1 to a higher version" -ForegroundColor Red
            exit 1
        }
        else {
            Write-Host "  ✓ Version is newer - ready to publish update" -ForegroundColor Green
        }
    }
    else {
        Write-Host "  ✓ Module name 'Toolbox' is available" -ForegroundColor Green
    }
}
catch {
    Write-Host "  ⚠ Could not check PowerShell Gallery (continuing anyway)" -ForegroundColor Yellow
}

# Step 6: Publish module
Write-Host "`n[6/6] Publishing module to PowerShell Gallery..." -ForegroundColor Yellow

$publishParams = @{
    Path = "$PSScriptRoot\Toolbox"
    NuGetApiKey = $apiKey
    Verbose = $true
    ErrorAction = 'Stop'
}

if ($PSCmdlet.ShouldProcess("Toolbox v$($manifest.Version)", "Publish to PowerShell Gallery")) {
        try {
            Publish-Module @publishParams
            
            Write-Host "`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
            Write-Host "║  ✓ Module published successfully!                        ║" -ForegroundColor Green
            Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green
            
            Write-Host "`nModule Details:" -ForegroundColor Cyan
            Write-Host "  Name:    Toolbox" -ForegroundColor White
            Write-Host "  Version: $($manifest.Version)" -ForegroundColor White
            Write-Host "  Author:  $($manifest.Author)" -ForegroundColor White
            
            Write-Host "`nNext Steps:" -ForegroundColor Cyan
            Write-Host "  1. View on Gallery: https://www.powershellgallery.com/packages/Toolbox/$($manifest.Version)" -ForegroundColor White
            Write-Host "  2. Test installation: Install-Module -Name Toolbox -Scope CurrentUser" -ForegroundColor White
            Write-Host "  3. Tag release: git tag v$($manifest.Version) && git push origin --tags" -ForegroundColor White
            Write-Host "  4. Create GitHub release with CHANGELOG notes" -ForegroundColor White
            
            Write-Host "`nThe module will be available for installation within a few minutes.`n" -ForegroundColor Yellow
        }
        catch {
            Write-Host "`n✗ Publishing failed!" -ForegroundColor Red
            Write-Host "Error: $_" -ForegroundColor Red
            
            if ($_.Exception.Message -like "*already exists*") {
                Write-Host "`nThis version already exists. Increment the version number in Toolbox.psd1" -ForegroundColor Yellow
            }
            elseif ($_.Exception.Message -like "*API key*") {
                Write-Host "`nAPI key may be invalid. Regenerate at: https://www.powershellgallery.com/account/apikeys" -ForegroundColor Yellow
            }
            
            exit 1
        }
}
