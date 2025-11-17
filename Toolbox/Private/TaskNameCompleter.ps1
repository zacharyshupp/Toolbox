# Argument completer for TaskName parameter
Register-ArgumentCompleter -CommandName 'Invoke-Task' -ParameterName 'TaskName' -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    
    # Get all available tasks
    $tasks = Get-TaskDefinition -ListAvailable -ErrorAction SilentlyContinue
    
    if (-not $tasks) {
        return @()
    }
    
    # Filter tasks based on what user has typed
    $tasks | Where-Object { $_.Name -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new(
            $_.Name,
            $_.Name,
            'ParameterValue',
            "$($_.Name) - $($_.Tags -join ', ')"
        )
    }
}
