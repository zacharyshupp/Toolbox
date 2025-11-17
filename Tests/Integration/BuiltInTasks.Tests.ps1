BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\..\Toolbox\Toolbox.psd1'
    Import-Module $modulePath -Force
}

Describe "Built-In Tasks" -Tag 'Integration', 'BuiltInTasks' {
    
    Context "System Tasks" {
        It "System.GetUptime should return uptime information" {
            $result = Invoke-Task -TaskName 'System.GetUptime' -Computers 'localhost'
            
            $result.Status | Should -Be 'Success'
            $result.Output.Output.UptimeDays | Should -Not -BeNullOrEmpty
            $result.Output.Output.LastBootTime | Should -Not -BeNullOrEmpty
        }

        It "System.GetBasicInfo should return system information" {
            $result = Invoke-Task -TaskName 'System.GetBasicInfo' -Computers 'localhost'
            
            $result.Status | Should -Be 'Success'
            $result.Output.Output.ComputerName | Should -Not -BeNullOrEmpty
            $result.Output.Output.OSVersion | Should -Not -BeNullOrEmpty
        }
    }

    Context "File Tasks" {
        It "File.TestPathExists should validate path existence" {
            $result = Invoke-Task -TaskName 'File.TestPathExists' `
                -Computers 'localhost' `
                -TaskParameters @{ Path = 'C:\Windows' }
            
            $result.Status | Should -Be 'Success'
            $result.Output.Output.Exists | Should -BeTrue
            $result.Output.Output.Path | Should -Be 'C:\Windows'
        }

        It "File.TestPathExists should detect nonexistent paths" {
            $result = Invoke-Task -TaskName 'File.TestPathExists' `
                -Computers 'localhost' `
                -TaskParameters @{ Path = 'C:\NonExistentPath123456' }
            
            $result.Status | Should -Be 'Success'
            $result.Output.Output.Exists | Should -BeFalse
        }

        It "File.GetPathSize should calculate directory size" {
            $result = Invoke-Task -TaskName 'File.GetPathSize' `
                -Computers 'localhost' `
                -TaskParameters @{ 
                    Path = 'C:\Windows\System32\drivers'
                    Unit = 'MB'
                }
            
            $result.Status | Should -Be 'Success'
            $result.Output.Output.TotalSize | Should -BeGreaterThan 0
            $result.Output.Output.Unit | Should -Be 'MB'
        }
    }

    Context "Network Tasks" {
        It "Network.TestConnection should ping hosts" {
            $result = Invoke-Task -TaskName 'Network.TestConnection' `
                -Computers 'localhost' `
                -TaskParameters @{ 
                    TargetHost = '127.0.0.1'
                    Count = 2
                }
            
            $result.Status | Should -Be 'Success'
            $result.Output.Output.Reachable | Should -BeTrue
        }

        It "Network.TestPort should test TCP connectivity" {
            $result = Invoke-Task -TaskName 'Network.TestPort' `
                -Computers 'localhost' `
                -TaskParameters @{ 
                    TargetHost = '8.8.8.8'
                    Port = 53
                }
            
            $result.Status | Should -Be 'Success'
            $result.Output.Output.Port | Should -Be 53
        }
    }

    Context "Process Tasks" {
        It "Process.GetProcess should list processes" {
            $result = Invoke-Task -TaskName 'Process.GetProcess' `
                -Computers 'localhost' `
                -TaskParameters @{ ProcessName = 'pwsh' }
            
            $result.Status | Should -Be 'Success'
            # Process may or may not be running
        }
    }

    Context "Service Tasks" {
        It "Service.GetService should retrieve service information" {
            $result = Invoke-Task -TaskName 'Service.GetService' `
                -Computers 'localhost' `
                -TaskParameters @{ ServiceName = 'winmgmt' }
            
            $result.Status | Should -Be 'Success'
        }
    }

    Context "Registry Tasks" {
        It "Registry.GetValue should read registry values" {
            $result = Invoke-Task -TaskName 'Registry.GetValue' `
                -Computers 'localhost' `
                -TaskParameters @{ 
                    Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
                    Name = 'ProductName'
                }
            
            $result.Status | Should -Be 'Success'
            $result.Output.Output.Value | Should -Not -BeNullOrEmpty
        }
    }

    Context "HTTP Tasks" {
        It "HTTP.InvokeRequest should make HTTP requests" {
            $result = Invoke-Task -TaskName 'HTTP.InvokeRequest' `
                -Computers 'localhost' `
                -TaskParameters @{ 
                    Uri = 'https://api.github.com'
                    Method = 'GET'
                }
            
            $result.Status | Should -Be 'Success'
            $result.Output.Output.StatusCode | Should -Be 200
        }
    }

    Context "Task Parameter Validation" {
        It "Should validate required parameters" {
            # Skip this test as parameter validation happens at the task level
            # and missing parameters would cause interactive prompts
            Set-ItResult -Skipped -Because "Parameter validation testing requires mock setup to avoid prompts"
        }

        It "Should handle parameter type conversion" {
            $result = Invoke-Task -TaskName 'Network.TestPort' `
                -Computers 'localhost' `
                -TaskParameters @{ 
                    TargetHost = '8.8.8.8'
                    Port = '53'  # String instead of int
                }
            
            # Should convert and succeed
            $result.Status | Should -Be 'Success'
        }
    }
}

AfterAll {
    Remove-Module -Name Toolbox -Force -ErrorAction SilentlyContinue
}
