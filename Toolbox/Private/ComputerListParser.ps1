function Get-ComputersFromFile {
    <#
    .SYNOPSIS
        Parses computer names from various file formats.
    
    .DESCRIPTION
        Supports .txt, .csv, and .xlsx files. For CSV and Excel files, allows
        specifying a column name using the format: filepath:columnname
    
    .PARAMETER FilePath
        Path to the file, optionally with :columnname suffix for CSV/Excel files.
    
    .EXAMPLE
        Get-ComputersFromFile -FilePath 'servers.txt'
    
    .EXAMPLE
        Get-ComputersFromFile -FilePath 'servers.csv:ComputerName'
    
    .EXAMPLE
        Get-ComputersFromFile -FilePath 'servers.xlsx:HostName'
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    
    try {
        # Parse file path and column name
        $columnName = $null
        $actualPath = $FilePath
        
        if ($FilePath -match '^(.+?):([\w]+)$') {
            $actualPath = $Matches[1]
            $columnName = $Matches[2]
            Write-Verbose "Parsed file path: '$actualPath', column: '$columnName'"
        }
        
        # Validate file exists
        if (-not (Test-Path -Path $actualPath -PathType Leaf)) {
            throw "File not found: $actualPath"
        }
        
        $extension = [System.IO.Path]::GetExtension($actualPath).ToLower()
        $computers = @()
        
        switch ($extension) {
            '.txt' {
                Write-Verbose "Reading computers from text file: $actualPath"
                $computers = Get-Content -Path $actualPath |
                    Where-Object { $_ -and $_.Trim() -and -not $_.StartsWith('#') } |
                    ForEach-Object { $_.Trim() }
            }
            
            '.csv' {
                Write-Verbose "Reading computers from CSV file: $actualPath"
                $csvData = Import-Csv -Path $actualPath
                
                if ($columnName) {
                    # Use specified column
                    if (-not ($csvData | Get-Member -Name $columnName -MemberType NoteProperty)) {
                        throw "Column '$columnName' not found in CSV. Available columns: $($csvData[0].PSObject.Properties.Name -join ', ')"
                    }
                    $computers = $csvData | ForEach-Object { $_.$columnName } | Where-Object { $_ }
                    Write-Verbose "Extracted $($computers.Count) computers from column '$columnName'"
                }
                else {
                    # No column specified - use first column
                    $firstColumn = $csvData[0].PSObject.Properties.Name[0]
                    $computers = $csvData | ForEach-Object { $_.$firstColumn } | Where-Object { $_ }
                    Write-Verbose "No column specified, using first column '$firstColumn': $($computers.Count) computers"
                }
            }
            
            { $_ -in '.xlsx', '.xls' } {
                Write-Verbose "Reading computers from Excel file: $actualPath"
                
                # Require ImportExcel module
                if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
                    throw "ImportExcel module is required to read Excel files. Install it with: Install-Module ImportExcel"
                }
                
                Import-Module ImportExcel -ErrorAction Stop
                
                $excelData = Import-Excel -Path $actualPath
                
                if ($columnName) {
                    # Use specified column
                    if (-not ($excelData | Get-Member -Name $columnName -MemberType NoteProperty)) {
                        throw "Column '$columnName' not found in Excel file. Available columns: $($excelData[0].PSObject.Properties.Name -join ', ')"
                    }
                    $computers = $excelData | ForEach-Object { $_.$columnName } | Where-Object { $_ }
                    Write-Verbose "Extracted $($computers.Count) computers from column '$columnName'"
                }
                else {
                    # No column specified - use first column
                    $firstColumn = $excelData[0].PSObject.Properties.Name[0]
                    $computers = $excelData | ForEach-Object { $_.$firstColumn } | Where-Object { $_ }
                    Write-Verbose "No column specified, using first column '$firstColumn': $($computers.Count) computers"
                }
            }
            
            default {
                throw "Unsupported file format: $extension. Supported formats: .txt, .csv, .xlsx, .xls"
            }
        }
        
        # Clean up computer names
        $computers = $computers | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ }
        
        Write-Verbose "Successfully loaded $($computers.Count) computers from file"
        return $computers
    }
    catch {
        Write-Error "Failed to read computers from file '$FilePath': $_"
        throw
    }
}
