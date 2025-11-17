BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\..\Toolbox\Toolbox.psd1'
    Import-Module $modulePath -Force
}

Describe "Task Discovery and Management" -Tag 'Unit', 'Tasks' {
    
    Context "Get-TaskDefinition" {
        It "Should list all available tasks" {
            $tasks = Get-TaskDefinition -ListAvailable
            $tasks | Should -Not -BeNullOrEmpty
            $tasks.Count | Should -BeGreaterThan 0
        }

        It "Should return task objects with required properties" {
            $tasks = Get-TaskDefinition -ListAvailable | Select-Object -First 1
            $tasks[0].Name | Should -Not -BeNullOrEmpty
            $tasks[0].Version | Should -Not -BeNullOrEmpty
            $tasks[0].FullScriptPath | Should -Not -BeNullOrEmpty
            $tasks[0].Source | Should -Not -BeNullOrEmpty
        }

        It "Should retrieve specific task by name" {
            $task = Get-TaskDefinition -TaskName 'System.GetUptime'
            $task | Should -Not -BeNullOrEmpty
            $task.Name | Should -Be 'System.GetUptime'
        }

        It "Should support wildcard filtering" {
            $tasks = Get-TaskDefinition -TaskName 'File.*'
            $tasks | Should -Not -BeNullOrEmpty
            $tasks | ForEach-Object { $_.Name | Should -Match '^File\.' }
        }

        It "Should filter by category" {
            $tasks = Get-TaskDefinition -ListAvailable | Where-Object { $_.Name -like 'Network.*' }
            $tasks | Should -Not -BeNullOrEmpty
            $tasks | ForEach-Object { $_.Name | Should -Match '^Network\.' }
        }

        It "Should have valid script paths" {
            $tasks = Get-TaskDefinition -ListAvailable
            foreach ($task in $tasks) {
                Test-Path $task.FullScriptPath | Should -BeTrue
            }
        }

        It "Should cache task definitions" {
            # First call
            $start1 = Get-Date
            $tasks1 = Get-TaskDefinition -ListAvailable
            $time1 = (Get-Date) - $start1
            
            # Second call (should be faster due to caching)
            $start2 = Get-Date
            $tasks2 = Get-TaskDefinition -ListAvailable
            $time2 = (Get-Date) - $start2
            
            $tasks1.Count | Should -Be $tasks2.Count
            $time2.TotalMilliseconds | Should -BeLessOrEqual $time1.TotalMilliseconds
        }

        It "Should refresh cache when requested" {
            $tasks1 = Get-TaskDefinition -ListAvailable
            $tasks2 = Get-TaskDefinition -ListAvailable -Refresh
            $tasks1.Count | Should -Be $tasks2.Count
        }
    }

    Context "Task Metadata" {
        BeforeAll {
            $script:testTask = Get-TaskDefinition -TaskName 'System.GetUptime'
        }

        It "Should have valid version format" {
            { [Version]$script:testTask.Version } | Should -Not -Throw
        }

        It "Should have description" {
            # Description might be in Synopsis or Description
            ($script:testTask.Description -or $script:testTask.Synopsis) | Should -Not -BeNullOrEmpty
        }

        It "Should have tags array" {
            $script:testTask.Tags | Should -Not -BeNullOrEmpty
            $script:testTask.Tags.Count | Should -BeGreaterThan 0
        }

        It "Should have timeout value" {
            $script:testTask.Timeout | Should -BeOfType [int]
            $script:testTask.Timeout | Should -BeGreaterThan 0
        }

        It "Should specify supported OS" {
            $script:testTask.SupportedOS | Should -Not -BeNullOrEmpty
        }

        It "Should specify PowerShell edition support" {
            $script:testTask.PSEdition | Should -Not -BeNullOrEmpty
        }
    }

    Context "Task Categories" {
        It "Should have File category tasks" {
            $tasks = Get-TaskDefinition -ListAvailable | Where-Object { $_.Name -like 'File.*' }
            $tasks | Should -Not -BeNullOrEmpty
        }

        It "Should have Network category tasks" {
            $tasks = Get-TaskDefinition -ListAvailable | Where-Object { $_.Name -like 'Network.*' }
            $tasks | Should -Not -BeNullOrEmpty
        }

        It "Should have System category tasks" {
            $tasks = Get-TaskDefinition -ListAvailable | Where-Object { $_.Name -like 'System.*' }
            $tasks | Should -Not -BeNullOrEmpty
        }

        It "Should have Service category tasks" {
            $tasks = Get-TaskDefinition -ListAvailable | Where-Object { $_.Name -like 'Service.*' }
            $tasks | Should -Not -BeNullOrEmpty
        }
    }

    Context "New-TaskDefinition" {
        BeforeAll {
            $script:tempTaskPath = Join-Path $TestDrive 'CustomTask'
        }

        It "Should create new task scaffolding" {
            $result = New-TaskDefinition -TaskName 'Custom.TestTask' `
                -Description 'Test task' `
                -OutputPath $script:tempTaskPath `
                -Force
            
            $result | Should -Not -BeNullOrEmpty
            if ($result.FullScriptPath) {
                Test-Path $result.FullScriptPath | Should -BeTrue
            }
        }

        It "Should validate task name format" {
            { New-TaskDefinition -TaskName 'InvalidName' -Description 'Test' -ErrorAction Stop } | 
                Should -Throw
        }

        It "Should prevent overwriting without -Force" {
            New-TaskDefinition -TaskName 'Custom.TestTask2' `
                -Description 'Test' `
                -OutputPath $script:tempTaskPath `
                -Force
            
            { New-TaskDefinition -TaskName 'Custom.TestTask2' `
                -Description 'Test' `
                -OutputPath $script:tempTaskPath `
                -ErrorAction Stop } | Should -Throw
        }
    }
}

AfterAll {
    Remove-Module -Name Toolbox -Force -ErrorAction SilentlyContinue
}
