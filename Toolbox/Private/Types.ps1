# Define PowerShell classes for Toolbox execution engine
# NOTE: StatusEnum.ps1 must be loaded first to define the Tb.Status type

# WorkItem class - represents a unit of work to be executed
class TbWorkItem {
    [string]$WorkItemId
    [string]$Computer
    [string]$TaskName
    [scriptblock]$ScriptBlock
    [hashtable]$TaskParameters
    [int]$Timeout
    [int]$RetryCount
    [System.Management.Automation.PSCredential]$Credential
    [datetime]$QueuedTime
    [datetime]$StartTime
    [datetime]$EndTime
    [int]$AttemptNumber
    [Tb.Status]$Status
    
    TbWorkItem() {
        $this.WorkItemId = [guid]::NewGuid().ToString()
        $this.TaskParameters = @{}
        $this.QueuedTime = Get-Date
        $this.Status = [Tb.Status]::NotStarted
        $this.AttemptNumber = 0
    }
    
    TbWorkItem([string]$computer, [string]$taskName) {
        $this.WorkItemId = [guid]::NewGuid().ToString()
        $this.Computer = $computer
        $this.TaskName = $taskName
        $this.TaskParameters = @{}
        $this.QueuedTime = Get-Date
        $this.Status = [Tb.Status]::NotStarted
        $this.AttemptNumber = 0
    }
    
    [string] ToString() {
        return "WorkItem: $($this.Computer) - $($this.TaskName)"
    }
}

# ErrorInfo class - represents error information
class TbErrorInfo {
    [string]$Message
    [string]$ExceptionType
    [string]$Category
    [string]$TargetObject
    [string]$ScriptStackTrace
    [string]$FullyQualifiedErrorId
    
    TbErrorInfo() {}
    
    TbErrorInfo([System.Management.Automation.ErrorRecord]$errorRecord) {
        $this.Message = $errorRecord.Exception.Message
        $this.ExceptionType = $errorRecord.Exception.GetType().FullName
        $this.Category = $errorRecord.CategoryInfo.Category.ToString()
        $this.TargetObject = $errorRecord.TargetObject
        $this.ScriptStackTrace = $errorRecord.ScriptStackTrace
        $this.FullyQualifiedErrorId = $errorRecord.FullyQualifiedErrorId
    }
    
    [string] ToString() {
        return $this.Message
    }
}

# TaskResult class - represents the result of a task execution
class TbTaskResult {
    [string]$WorkItemId
    [string]$Computer
    [string]$TaskName
    [Tb.Status]$Status
    [object]$Output
    [TbErrorInfo]$Error
    [string]$Warning
    [datetime]$StartTime
    [datetime]$EndTime
    [timespan]$Duration
    [int]$AttemptNumber
    [int]$RetryCount
    [bool]$TimedOut
    [hashtable]$Metadata
    
    TbTaskResult() {
        $this.Status = [Tb.Status]::NotStarted
        $this.Metadata = @{}
        $this.TimedOut = $false
    }
    
    TbTaskResult([TbWorkItem]$workItem) {
        $this.WorkItemId = $workItem.WorkItemId
        $this.Computer = $workItem.Computer
        $this.TaskName = $workItem.TaskName
        $this.StartTime = Get-Date
        $this.Status = [Tb.Status]::Running
        $this.AttemptNumber = $workItem.AttemptNumber
        $this.RetryCount = $workItem.RetryCount
        $this.Metadata = @{}
        $this.TimedOut = $false
    }
    
    [void] Complete([object]$output) {
        $this.EndTime = Get-Date
        $this.Duration = $this.EndTime - $this.StartTime
        $this.Output = $output
        
        if ($this.Error) {
            $this.Status = [Tb.Status]::Failed
        }
        elseif ($this.Warning) {
            $this.Status = [Tb.Status]::SuccessWithWarning
        }
        else {
            $this.Status = [Tb.Status]::Success
        }
    }
    
    [void] Fail([System.Management.Automation.ErrorRecord]$errorRecord) {
        $this.EndTime = Get-Date
        $this.Duration = $this.EndTime - $this.StartTime
        $this.Error = [TbErrorInfo]::new($errorRecord)
        $this.Status = [Tb.Status]::Failed
    }
    
    [void] Timeout() {
        $this.EndTime = Get-Date
        $this.Duration = $this.EndTime - $this.StartTime
        $this.TimedOut = $true
        $this.Status = [Tb.Status]::Timeout
        $this.Error = [TbErrorInfo]@{
            Message = "Task execution timed out after $($this.Duration.TotalSeconds) seconds"
            ExceptionType = "TimeoutException"
            Category = "OperationTimeout"
        }
    }
    
    [void] Cancel() {
        $this.EndTime = Get-Date
        $this.Duration = $this.EndTime - $this.StartTime
        $this.Status = [Tb.Status]::Cancelled
    }
    
    [void] AddWarning([string]$warning) {
        if ($this.Warning) {
            $this.Warning += "; $warning"
        }
        else {
            $this.Warning = $warning
        }
    }
    
    [bool] IsSuccess() {
        return $this.Status -eq [Tb.Status]::Success -or 
               $this.Status -eq [Tb.Status]::SuccessWithWarning
    }
    
    [bool] ShouldRetry() {
        return $this.Status -eq [Tb.Status]::Failed -and 
               $this.AttemptNumber -lt $this.RetryCount -and
               -not $this.TimedOut
    }
    
    [string] ToString() {
        return "$($this.Computer): $($this.Status) - $($this.TaskName)"
    }
}

# Export types
Export-ModuleMember -Variable * -Function *
