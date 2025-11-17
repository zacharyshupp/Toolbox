# Define C# Status enumeration
# This must be loaded before PowerShell classes that reference it

if (-not ([System.Management.Automation.PSTypeName]'Tb.Status').Type) {
    Add-Type -TypeDefinition @"
        namespace Tb
        {
            public enum Status
            {
                NotStarted,
                Running,
                Success,
                SuccessWithWarning,
                Failed,
                Timeout,
                Cancelled,
                Skipped
            }
        }
"@
}
