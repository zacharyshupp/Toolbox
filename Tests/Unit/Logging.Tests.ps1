BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\..\Toolbox\Toolbox.psd1'
    Import-Module $modulePath -Force
}

Describe "Logging Framework" -Tag 'Unit', 'Logging' {
    
    Context "Get-TaskLog" {
        BeforeAll {
            # Generate some log entries
            $null = Invoke-Task -TaskName 'System.GetUptime' -Computers 'localhost' -ErrorAction SilentlyContinue
        }

        It "Should retrieve log entries" {
            $logs = Get-TaskLog -Last 10
            $logs | Should -Not -BeNullOrEmpty
        }

        It "Should return log objects with required properties" {
            $log = Get-TaskLog -Last 1
            $log.Timestamp | Should -Not -BeNullOrEmpty
            $log.Level | Should -Not -BeNullOrEmpty
            $log.Message | Should -Not -BeNullOrEmpty
        }

        It "Should filter by log level" {
            $infoLogs = Get-TaskLog -Level Info -Last 50
            $infoLogs | ForEach-Object { $_.Level | Should -Be 'Info' }
        }

        It "Should filter by date range" {
            $startDate = (Get-Date).AddHours(-1)
            $logs = Get-TaskLog -StartDate $startDate
            $logs | ForEach-Object { 
                [DateTime]$_.Timestamp | Should -BeGreaterThan $startDate 
            }
        }

        It "Should support text search" {
            $logs = Get-TaskLog -Search 'Task' -Last 100
            $logs | Should -Not -BeNullOrEmpty
            $logs | ForEach-Object { 
                $_.Message | Should -Match 'Task' 
            }
        }

        It "Should filter by computer name" {
            $logs = Get-TaskLog -Computer 'localhost' -Last 50
            if ($logs) {
                $logs | ForEach-Object { 
                    if ($_.Computer) {
                        $_.Computer | Should -Be 'localhost'
                    }
                }
            }
        }

        It "Should limit results with -Last parameter" {
            $logs = Get-TaskLog -Last 5
            $logs.Count | Should -BeLessOrEqual 5
        }
    }

    Context "Log File Management" {
        It "Should have log directory" {
            $config = Get-TbConfig -Section Logging
            $logPath = $config.LogPath
            Test-Path $logPath | Should -BeTrue
        }

        It "Should create log files" {
            $config = Get-TbConfig -Section Logging
            $logPath = $config.LogPath
            $logFiles = Get-ChildItem -Path $logPath -Filter "*.jsonl" -ErrorAction SilentlyContinue
            # Log files should exist after running a task
            if ($logFiles) {
                $logFiles | Should -Not -BeNullOrEmpty
            } else {
                Set-ItResult -Skipped -Because "No log files exist yet"
            }
        }

        It "Should write valid JSON Lines format" {
            $config = Get-TbConfig -Section Logging
            $logPath = $config.LogPath
            $logFile = Get-ChildItem -Path $logPath -Filter "*.jsonl" -ErrorAction SilentlyContinue | 
                Sort-Object LastWriteTime -Descending | 
                Select-Object -First 1
            
            if ($logFile) {
                $firstLine = Get-Content $logFile.FullName -TotalCount 1
                { $firstLine | ConvertFrom-Json } | Should -Not -Throw
            } else {
                Set-ItResult -Skipped -Because "No log files exist yet"
            }
        }
    }

    Context "Log Levels" {
        It "Should support all log levels" {
            $validLevels = @('Verbose', 'Info', 'Warning', 'Error')
            $config = Get-TbConfig -Section Logging
            $config.LogLevel | Should -BeIn $validLevels
        }

        It "Should filter logs by level" {
            $errorLogs = Get-TaskLog -Level Error -Last 100
            if ($errorLogs) {
                $errorLogs | ForEach-Object { $_.Level | Should -Be 'Error' }
            }
        }
    }
}

AfterAll {
    Remove-Module -Name Toolbox -Force -ErrorAction SilentlyContinue
}
