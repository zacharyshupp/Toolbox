BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\..\Toolbox\Toolbox.psd1'
    Import-Module $modulePath -Force
}

Describe "Configuration Management" -Tag 'Unit', 'Configuration' {
    
    Context "Get-TbConfig" {
        It "Should return configuration object" {
            $config = Get-TbConfig
            $config | Should -Not -BeNullOrEmpty
        }

        It "Should have all required sections" {
            $config = Get-TbConfig
            $config.Execution | Should -Not -BeNullOrEmpty
            $config.Logging | Should -Not -BeNullOrEmpty
            $config.Tasks | Should -Not -BeNullOrEmpty
            $config.Session | Should -Not -BeNullOrEmpty
            $config.Export | Should -Not -BeNullOrEmpty
        }

        It "Should retrieve specific section" {
            $execution = Get-TbConfig -Section Execution
            $execution | Should -Not -BeNullOrEmpty
            $execution.DefaultThrottle | Should -BeGreaterThan 0
        }

        It "Should retrieve specific property" {
            $throttle = Get-TbConfig -Section Execution -Property DefaultThrottle
            $throttle | Should -BeGreaterThan 0
        }

        It "Should return hashtable when requested" {
            $config = Get-TbConfig -AsHashtable
            $config | Should -BeOfType [hashtable]
        }
    }

    Context "Set-TbConfig" {
        BeforeEach {
            # Backup current config
            $script:originalThrottle = Get-TbConfig -Section Execution -Property DefaultThrottle
        }

        AfterEach {
            # Restore original value
            Set-TbConfig -Section Execution -Property DefaultThrottle -Value $script:originalThrottle
        }

        It "Should update configuration value" {
            $newValue = 16
            Set-TbConfig -Section Execution -Property DefaultThrottle -Value $newValue
            $current = Get-TbConfig -Section Execution -Property DefaultThrottle
            $current | Should -Be $newValue
        }

        It "Should persist configuration changes" {
            $newValue = 48
            Set-TbConfig -Section Execution -Property DefaultThrottle -Value $newValue
            
            # Reload module to test persistence
            Remove-Module Toolbox -Force
            Import-Module $modulePath -Force
            
            $current = Get-TbConfig -Section Execution -Property DefaultThrottle
            $current | Should -Be $newValue
        }

        It "Should validate section names" {
            { Set-TbConfig -Section 'InvalidSection' -Property 'Test' -Value 123 -ErrorAction Stop } | 
                Should -Throw
        }
    }

    Context "Configuration Defaults" {
        It "Should have valid default throttle" {
            $throttle = Get-TbConfig -Section Execution -Property DefaultThrottle
            $throttle | Should -Not -BeNullOrEmpty
            Should -BeGreaterThan -ActualValue $throttle -ExpectedValue 0
            Should -BeLessOrEqual -ActualValue $throttle -ExpectedValue 256
        }

        It "Should have valid default timeout" {
            $timeout = Get-TbConfig -Section Execution -Property DefaultTimeout
            $timeout | Should -Not -BeNullOrEmpty
            Should -BeGreaterThan -ActualValue $timeout -ExpectedValue 0
        }

        It "Should have valid retry count" {
            $retry = Get-TbConfig -Section Execution -Property DefaultRetryCount
            $retry | Should -Not -BeNullOrEmpty
            Should -BeGreaterOrEqual -ActualValue $retry -ExpectedValue 0
        }

        It "Should have valid log level" {
            $level = Get-TbConfig -Section Logging -Property LogLevel
            $level | Should -BeIn @('Verbose', 'Info', 'Warning', 'Error')
        }
    }
}

AfterAll {
    Remove-Module -Name Toolbox -Force -ErrorAction SilentlyContinue
}
