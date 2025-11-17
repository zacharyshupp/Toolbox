BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\..\Toolbox\Toolbox.psd1'
    Import-Module $modulePath -Force
}

Describe "Export Functionality" -Tag 'Integration', 'Export' {
    
    BeforeAll {
        # Execute a task to get results
        $script:testResults = Invoke-Task -TaskName 'System.GetUptime' `
            -Computers @('localhost', '127.0.0.1')
    }

    Context "CSV Export" {
        BeforeAll {
            $script:csvPath = Join-Path $TestDrive 'results.csv'
        }

        It "Should export to CSV" {
            { Export-TaskResult -Results $script:testResults `
                -OutputPath $script:csvPath `
                -Format CSV } | Should -Not -Throw
            
            Test-Path $script:csvPath | Should -BeTrue
        }

        It "Should create valid CSV file" {
            Export-TaskResult -Results $script:testResults `
                -OutputPath $script:csvPath `
                -Format CSV
            
            $imported = Import-Csv $script:csvPath
            $imported | Should -Not -BeNullOrEmpty
            $imported.Count | Should -BeGreaterThan 0
        }

        It "Should include required columns" {
            Export-TaskResult -Results $script:testResults `
                -OutputPath $script:csvPath `
                -Format CSV
            
            $imported = Import-Csv $script:csvPath
            $imported[0].Computer | Should -Not -BeNullOrEmpty
            $imported[0].TaskName | Should -Not -BeNullOrEmpty
            $imported[0].Status | Should -Not -BeNullOrEmpty
        }
    }

    Context "JSON Export" {
        BeforeAll {
            $script:jsonPath = Join-Path $TestDrive 'results.json'
        }

        It "Should export to JSON" {
            { Export-TaskResult -Results $script:testResults `
                -OutputPath $script:jsonPath `
                -Format JSON } | Should -Not -Throw
            
            Test-Path $script:jsonPath | Should -BeTrue
        }

        It "Should create valid JSON file" {
            Export-TaskResult -Results $script:testResults `
                -OutputPath $script:jsonPath `
                -Format JSON
            
            $content = Get-Content $script:jsonPath -Raw
            { $content | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should preserve complex objects" {
            Export-TaskResult -Results $script:testResults `
                -OutputPath $script:jsonPath `
                -Format JSON
            
            $imported = Get-Content $script:jsonPath -Raw | ConvertFrom-Json
            $imported | Should -Not -BeNullOrEmpty
            $imported[0].Output | Should -Not -BeNullOrEmpty
        }
    }

    Context "XML Export" {
        BeforeAll {
            $script:xmlPath = Join-Path $TestDrive 'results.xml'
        }

        It "Should export to XML" {
            { Export-TaskResult -Results $script:testResults `
                -OutputPath $script:xmlPath `
                -Format XML } | Should -Not -Throw
            
            Test-Path $script:xmlPath | Should -BeTrue
        }

        It "Should create valid XML file" {
            Export-TaskResult -Results $script:testResults `
                -OutputPath $script:xmlPath `
                -Format XML
            
            { [xml](Get-Content $script:xmlPath -Raw) } | Should -Not -Throw
        }
    }

    Context "Excel Export" {
        BeforeAll {
            $script:excelPath = Join-Path $TestDrive 'results.xlsx'
        }

        It "Should export to Excel" {
            { Export-TaskResult -Results $script:testResults `
                -OutputPath $script:excelPath `
                -Format Excel } | Should -Not -Throw
            
            Test-Path $script:excelPath | Should -BeTrue
        }

        It "Should create valid Excel file" {
            Export-TaskResult -Results $script:testResults `
                -OutputPath $script:excelPath `
                -Format Excel
            
            $fileInfo = Get-Item $script:excelPath
            $fileInfo.Length | Should -BeGreaterThan 0
        }

        It "Should support auto-format detection" {
            $autoPath = Join-Path $TestDrive 'auto.xlsx'
            Export-TaskResult -Results $script:testResults -OutputPath $autoPath
            
            Test-Path $autoPath | Should -BeTrue
        }
    }

    Context "Integration with Invoke-Task" {
        It "Should export directly from Invoke-Task" {
            $outputPath = Join-Path $TestDrive 'direct-export.csv'
            
            $result = Invoke-Task -TaskName 'System.GetUptime' `
                -Computers 'localhost' `
                -OutputFormat CSV `
                -OutputPath $outputPath
            
            Test-Path $outputPath | Should -BeTrue
        }

        It "Should support all formats via Invoke-Task" {
            $formats = @('CSV', 'JSON', 'XML', 'Excel')
            
            foreach ($format in $formats) {
                $extension = $format.ToLower()
                if ($extension -eq 'excel') { $extension = 'xlsx' }
                
                $path = Join-Path $TestDrive "invoke-$format.$extension"
                
                $result = Invoke-Task -TaskName 'System.GetUptime' `
                    -Computers 'localhost' `
                    -OutputFormat $format `
                    -OutputPath $path
                
                Test-Path $path | Should -BeTrue
            }
        }
    }

    Context "Export Options" {
        It "Should respect NoClobber" {
            $path = Join-Path $TestDrive 'noclobber.csv'
            
            Export-TaskResult -Results $script:testResults `
                -OutputPath $path `
                -Format CSV
            
            { Export-TaskResult -Results $script:testResults `
                -OutputPath $path `
                -Format CSV `
                -NoClobber `
                -ErrorAction Stop } | Should -Throw
        }

        It "Should support pipeline input" {
            $path = Join-Path $TestDrive 'pipeline.csv'
            
            { $script:testResults | Export-TaskResult `
                -OutputPath $path `
                -Format CSV } | Should -Not -Throw
            
            Test-Path $path | Should -BeTrue
        }
    }
}

AfterAll {
    Remove-Module -Name Toolbox -Force -ErrorAction SilentlyContinue
}
