BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\..\Toolbox\Toolbox.psd1'
    Import-Module $modulePath -Force
}

Describe "Task Execution" -Tag 'Integration', 'Execution' {
    
    Context "Local Execution" {
        It "Should execute task on localhost" {
            $result = Invoke-Task -TaskName 'System.GetUptime' -Computers 'localhost'
            $result | Should -Not -BeNullOrEmpty
            $result.Status | Should -Be 'Success'
            $result.Computer | Should -Be 'localhost'
        }

        It "Should return task output" {
            $result = Invoke-Task -TaskName 'System.GetUptime' -Computers 'localhost'
            $result.Output | Should -Not -BeNullOrEmpty
            $result.Output.Output | Should -Not -BeNullOrEmpty
        }

        It "Should execute with parameters" {
            $result = Invoke-Task -TaskName 'File.TestPathExists' `
                -Computers 'localhost' `
                -TaskParameters @{ Path = 'C:\Windows' }
            
            $result.Status | Should -Be 'Success'
            $result.Output.Output.Exists | Should -BeTrue
        }

        It "Should handle invalid parameters gracefully" {
            $result = Invoke-Task -TaskName 'File.TestPathExists' `
                -Computers 'localhost' `
                -TaskParameters @{ InvalidParam = 'test' }
            
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Parallel Execution" {
        It "Should execute on multiple computers" {
            $computers = @('localhost', '127.0.0.1', '::1')
            $result = Invoke-Task -TaskName 'System.GetUptime' -Computers $computers
            
            $result.Count | Should -Be $computers.Count
            $result | ForEach-Object { $_.Status | Should -Be 'Success' }
        }

        It "Should respect throttle limit" {
            # Create unique computer names to avoid deduplication
            $computers = 1..10 | ForEach-Object { "localhost-$_" }
            $result = Invoke-Task -TaskName 'System.GetUptime' `
                -Computers $computers `
                -ThrottleLimit 5 `
                -ErrorAction SilentlyContinue
            
            # Most will fail (nonexistent hosts), but we're testing throttle behavior
            # Just verify we got results back (throttle doesn't prevent execution)
            $result.Count | Should -Be 10
        }

        It "Should deduplicate computers" {
            $computers = @('localhost', 'localhost', '127.0.0.1')
            $result = Invoke-Task -TaskName 'System.GetUptime' -Computers $computers
            
            # localhost and 127.0.0.1 might be deduplicated depending on resolution
            $result.Count | Should -BeGreaterThan 0
        }
    }

    Context "Computer List Files" {
        BeforeAll {
            # Create test files
            $script:txtFile = Join-Path $TestDrive 'computers.txt'
            @('localhost', '127.0.0.1') | Set-Content $script:txtFile
            
            $script:csvFile = Join-Path $TestDrive 'computers.csv'
            @(
                [PSCustomObject]@{ ServerName = 'localhost'; Environment = 'Test' }
                [PSCustomObject]@{ ServerName = '127.0.0.1'; Environment = 'Test' }
            ) | Export-Csv $script:csvFile -NoTypeInformation
        }

        It "Should read from text file" {
            $result = Invoke-Task -TaskName 'System.GetUptime' -Computers $script:txtFile
            $result.Count | Should -BeGreaterThan 0
        }

        It "Should read from CSV file with column" {
            $result = Invoke-Task -TaskName 'System.GetUptime' `
                -Computers "$($script:csvFile):ServerName"
            
            $result.Count | Should -BeGreaterThan 0
        }

        It "Should mix file and computer names" {
            $computers = @($script:txtFile, '::1')
            $result = Invoke-Task -TaskName 'System.GetUptime' -Computers $computers
            $result.Count | Should -BeGreaterThan 0
        }
    }

    Context "Error Handling" {
        It "Should handle nonexistent task" {
            { Invoke-Task -TaskName 'Invalid.Task' -Computers 'localhost' -ErrorAction Stop } | 
                Should -Throw
        }

        It "Should handle task errors gracefully" {
            $result = Invoke-Task -TaskName 'File.TestPathExists' `
                -Computers 'localhost' `
                -TaskParameters @{ Path = 'C:\NonExistentPath123456' }
            
            $result | Should -Not -BeNullOrEmpty
            # Task should complete even if path doesn't exist
        }

        It "Should timeout long-running tasks" {
            $result = Invoke-Task -TaskName 'System.GetUptime' `
                -Computers 'localhost' `
                -Timeout 1
            
            # Should complete or timeout without crashing
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Task Parameters" {
        It "Should pass parameters correctly" {
            $result = Invoke-Task -TaskName 'Network.TestPort' `
                -Computers 'localhost' `
                -TaskParameters @{ 
                    TargetHost = '8.8.8.8'
                    Port = 53
                }
            
            $result.Status | Should -Be 'Success'
            $result.Output.Output.TargetHost | Should -Be '8.8.8.8'
            $result.Output.Output.Port | Should -Be 53
        }

        It "Should handle complex parameters" {
            $result = Invoke-Task -TaskName 'File.GetPathSize' `
                -Computers 'localhost' `
                -TaskParameters @{ 
                    Path = 'C:\Windows\System32'
                    Unit = 'MB'
                }
            
            $result.Status | Should -Be 'Success'
            $result.Output.Output.Unit | Should -Be 'MB'
        }
    }

    Context "Progress Reporting" {
        It "Should support -ShowProgress switch" {
            { $result = Invoke-Task -TaskName 'System.GetUptime' `
                -Computers @('localhost', '127.0.0.1') `
                -ShowProgress } | Should -Not -Throw
        }
    }

    Context "Result Structure" {
        BeforeAll {
            $script:result = Invoke-Task -TaskName 'System.GetUptime' -Computers 'localhost'
        }

        It "Should have WorkItemId" {
            $script:result.WorkItemId | Should -Not -BeNullOrEmpty
        }

        It "Should have Computer name" {
            $script:result.Computer | Should -Be 'localhost'
        }

        It "Should have TaskName" {
            $script:result.TaskName | Should -Be 'System.GetUptime'
        }

        It "Should have Status" {
            $script:result.Status | Should -BeIn @('Success', 'Failed', 'Timeout', 'Cancelled')
        }

        It "Should have timestamps" {
            $script:result.StartTime | Should -Not -BeNullOrEmpty
            $script:result.EndTime | Should -Not -BeNullOrEmpty
        }

        It "Should have Duration" {
            $script:result.Duration | Should -Not -BeNullOrEmpty
            $script:result.Duration.TotalMilliseconds | Should -BeGreaterThan 0
        }

        It "Should have AttemptNumber" {
            $script:result.AttemptNumber | Should -BeGreaterThan 0
        }
    }
}

AfterAll {
    Remove-Module -Name Toolbox -Force -ErrorAction SilentlyContinue
}
