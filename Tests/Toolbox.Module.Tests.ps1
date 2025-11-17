BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot '..\Toolbox\Toolbox.psd1'
    Import-Module $modulePath -Force
}

Describe "Toolbox Module" {
    Context "Module Import" {
        It "Should import the module successfully" {
            Get-Module -Name Toolbox | Should -Not -BeNullOrEmpty
        }

        It "Should have the correct module version" {
            $module = Get-Module -Name Toolbox
            $module.Version | Should -BeOfType [Version]
        }

        It "Should export expected public functions" {
            $module = Get-Module -Name Toolbox
            $expectedFunctions = @(
                'Invoke-Task',
                'Get-TaskDefinition',
                'New-TaskDefinition',
                'Export-TaskResult',
                'Get-TaskLog',
                'Get-TbConfig',
                'Set-TbConfig'
            )
            
            foreach ($function in $expectedFunctions) {
                $module.ExportedFunctions.Keys | Should -Contain $function
            }
        }
    }

    Context "Module Manifest" {
        BeforeAll {
            $manifestPath = Join-Path $PSScriptRoot '..\Toolbox\Toolbox.psd1'
            $script:manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
        }

        It "Should have a valid manifest" {
            $script:manifest | Should -Not -BeNullOrEmpty
        }

        It "Should require PowerShell 5.1 or higher" {
            $script:manifest.PowerShellVersion | Should -BeGreaterOrEqual ([Version]'5.1')
        }

        It "Should require ImportExcel module" {
            $script:manifest.RequiredModules.Name | Should -Contain 'ImportExcel'
        }

        It "Should support Desktop and Core editions" {
            $script:manifest.CompatiblePSEditions | Should -Contain 'Desktop'
            $script:manifest.CompatiblePSEditions | Should -Contain 'Core'
        }
    }
}

AfterAll {
    # Clean up
    Remove-Module -Name Toolbox -Force -ErrorAction SilentlyContinue
}
