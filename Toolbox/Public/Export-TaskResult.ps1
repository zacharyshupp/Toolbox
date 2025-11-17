function Export-TaskResult {
    <#
    .SYNOPSIS
        Exports task results to various formats.
    
    .DESCRIPTION
        Exports TbTaskResult objects to CSV, JSON, XML, or Excel formats.
        Handles complex nested objects by flattening or JSON-encoding them.
    
    .PARAMETER Results
        Array of TbTaskResult objects to export.
    
    .PARAMETER OutputPath
        Path for the output file.
    
    .PARAMETER Format
        Output format (CSV, JSON, XML, Excel).
    
    .PARAMETER NoClobber
        Prevent overwriting existing files.
    
    .EXAMPLE
        Export-TaskResult -Results $results -OutputPath results.csv -Format CSV
        Exports task results to CSV format.
    
    .EXAMPLE
        $results | Export-TaskResult -OutputPath results.xlsx -Format Excel
        Exports results to Excel with conditional formatting.
    
    .EXAMPLE
        Export-TaskResult -Results $results -OutputPath results.json -Format JSON
        Exports results to JSON format preserving complex nested objects.
    
    .EXAMPLE
        Invoke-Task -TaskName "System.GetUptime" -Computers "SERVER01","SERVER02" | Export-TaskResult -OutputPath uptime.xlsx
        Executes task and pipes results directly to Excel export (format auto-detected).
    
    .NOTES
        Excel export requires ImportExcel module.
        Format is auto-detected from file extension if not explicitly specified.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [TbTaskResult[]]$Results,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [Parameter()]
        [ValidateSet("CSV", "JSON", "XML", "Excel")]
        [string]$Format,
        
        [Parameter()]
        [switch]$NoClobber
    )
    
    begin {
        $allResults = [System.Collections.ArrayList]::new()
    }
    
    process {
        $allResults.AddRange($Results)
    }
    
    end {
        if ($allResults.Count -eq 0) {
            Write-Warning "No results to export"
            return
        }
        
        # Auto-detect format from extension if not specified
        if (-not $Format) {
            $extension = [System.IO.Path]::GetExtension($OutputPath).TrimStart(".")
            $Format = switch ($extension) {
                "csv" { "CSV" }
                "json" { "JSON" }
                "xml" { "XML" }
                "xlsx" { "Excel" }
                default { "CSV" }
            }
        }
        
        # Check for existing file
        if ((Test-Path $OutputPath) -and $NoClobber) {
            Write-Error "File already exists: $OutputPath (use -Force to overwrite)"
            return
        }
        
        # Ensure directory exists
        $directory = [System.IO.Path]::GetDirectoryName($OutputPath)
        if ($directory -and -not (Test-Path $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        
        if ($PSCmdlet.ShouldProcess($OutputPath, "Export $($allResults.Count) results as $Format")) {
            try {
                switch ($Format) {
                    "CSV" {
                        Export-ToCsv -Results $allResults -Path $OutputPath
                    }
                    "JSON" {
                        Export-ToJson -Results $allResults -Path $OutputPath
                    }
                    "XML" {
                        Export-ToXml -Results $allResults -Path $OutputPath
                    }
                    "Excel" {
                        Export-ToExcel -Results $allResults -Path $OutputPath
                    }
                }
                
                Write-Verbose "Exported $($allResults.Count) results to $OutputPath"
            }
            catch {
                Write-Error "Failed to export results: $_"
                throw
            }
        }
    }
}

function Export-ToCsv {
    param(
        [TbTaskResult[]]$Results,
        [string]$Path
    )
    
    # Flatten results for CSV
    $flattenedResults = $Results | ForEach-Object {
        $result = $_
        
        [PSCustomObject]@{
            Computer = $result.Computer
            TaskName = $result.TaskName
            Status = $result.Status.ToString()
            Success = $result.IsSuccess()
            StartTime = $result.StartTime
            EndTime = $result.EndTime
            Duration = $result.Duration.TotalSeconds
            AttemptNumber = $result.AttemptNumber
            TimedOut = $result.TimedOut
            ErrorMessage = if ($result.Error) { $result.Error.Message } else { $null }
            ErrorType = if ($result.Error) { $result.Error.ExceptionType } else { $null }
            Warning = $result.Warning
            Output = if ($result.Output) { 
                if ($result.Output -is [string]) { $result.Output }
                else { ConvertTo-Json -InputObject $result.Output -Compress -Depth 5 }
            } else { $null }
        }
    }
    
    $flattenedResults | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
}

function Export-ToJson {
    param(
        [TbTaskResult[]]$Results,
        [string]$Path
    )
    
    # Convert results to JSON-friendly format
    $jsonResults = $Results | ForEach-Object {
        @{
            Computer = $_.Computer
            TaskName = $_.TaskName
            Status = $_.Status.ToString()
            Success = $_.IsSuccess()
            StartTime = $_.StartTime.ToString("o")
            EndTime = $_.EndTime.ToString("o")
            DurationSeconds = $_.Duration.TotalSeconds
            AttemptNumber = $_.AttemptNumber
            TimedOut = $_.TimedOut
            Error = if ($_.Error) {
                @{
                    Message = $_.Error.Message
                    Type = $_.Error.ExceptionType
                    Category = $_.Error.Category
                }
            } else { $null }
            Warning = $_.Warning
            Output = $_.Output
            Metadata = $_.Metadata
        }
    }
    
    $jsonResults | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding UTF8
}

function Export-ToXml {
    param(
        [TbTaskResult[]]$Results,
        [string]$Path
    )
    
    # Convert to XML-friendly objects
    $xmlResults = $Results | ForEach-Object {
        [PSCustomObject]@{
            Computer = $_.Computer
            TaskName = $_.TaskName
            Status = $_.Status.ToString()
            Success = $_.IsSuccess()
            StartTime = $_.StartTime.ToString("o")
            EndTime = $_.EndTime.ToString("o")
            DurationSeconds = $_.Duration.TotalSeconds
            AttemptNumber = $_.AttemptNumber
            TimedOut = $_.TimedOut
            ErrorMessage = if ($_.Error) { $_.Error.Message } else { $null }
            ErrorType = if ($_.Error) { $_.Error.ExceptionType } else { $null }
            Warning = $_.Warning
            OutputJson = if ($_.Output) { ConvertTo-Json -InputObject $_.Output -Compress -Depth 5 } else { $null }
        }
    }
    
    $xmlResults | Export-Clixml -Path $Path -Depth 10
}

function Export-ToExcel {
    param(
        [TbTaskResult[]]$Results,
        [string]$Path
    )
    
    # Check if ImportExcel module is available
    if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
        throw "ImportExcel module is not installed. Install it using: Install-Module -Name ImportExcel"
    }
    
    Import-Module ImportExcel -ErrorAction Stop
    
    # Prepare data for Excel
    $excelData = $Results | ForEach-Object {
        [PSCustomObject]@{
            Computer = $_.Computer
            TaskName = $_.TaskName
            Status = $_.Status.ToString()
            Success = $_.IsSuccess()
            StartTime = $_.StartTime
            EndTime = $_.EndTime
            "Duration (s)" = [math]::Round($_.Duration.TotalSeconds, 2)
            Attempt = $_.AttemptNumber
            TimedOut = $_.TimedOut
            ErrorMessage = if ($_.Error) { $_.Error.Message } else { "" }
            ErrorType = if ($_.Error) { $_.Error.ExceptionType } else { "" }
            Warning = if ($_.Warning) { $_.Warning } else { "" }
            Output = if ($_.Output) {
                if ($_.Output -is [string]) { $_.Output }
                else { ConvertTo-Json -InputObject $_.Output -Compress -Depth 3 }
            } else { "" }
        }
    }
    
    # Export with formatting
    $excelParams = @{
        Path = $Path
        WorksheetName = "TaskResults"
        AutoSize = $true
        FreezeTopRow = $true
        BoldTopRow = $true
        TableName = "Results"
        TableStyle = "Medium2"
    }
    
    $excelData | Export-Excel @excelParams
    
    # Add conditional formatting for status
    $excel = Open-ExcelPackage -Path $Path
    $worksheet = $excel.Workbook.Worksheets["TaskResults"]
    
    # Find Status column
    $statusColumn = ($worksheet.Cells["1:1"] | Where-Object { $_.Value -eq "Status" }).Start.Column
    
    if ($statusColumn) {
        # Green for Success
        Add-ConditionalFormatting -Worksheet $worksheet -Range "$([char](64 + $statusColumn))2:$([char](64 + $statusColumn))$($Results.Count + 1)" `
            -RuleType Equal -ConditionValue "Success" -BackgroundColor ([System.Drawing.Color]::LightGreen)
        
        # Red for Failed
        Add-ConditionalFormatting -Worksheet $worksheet -Range "$([char](64 + $statusColumn))2:$([char](64 + $statusColumn))$($Results.Count + 1)" `
            -RuleType Equal -ConditionValue "Failed" -BackgroundColor ([System.Drawing.Color]::LightCoral)
        
        # Yellow for Timeout
        Add-ConditionalFormatting -Worksheet $worksheet -Range "$([char](64 + $statusColumn))2:$([char](64 + $statusColumn))$($Results.Count + 1)" `
            -RuleType Equal -ConditionValue "Timeout" -BackgroundColor ([System.Drawing.Color]::Yellow)
    }
    
    Close-ExcelPackage -ExcelPackage $excel
}
