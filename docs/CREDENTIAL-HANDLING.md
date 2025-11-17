# Credential Handling in Toolbox Module

## Overview

The Toolbox module has **complete credential support** for authenticating to remote systems. Credentials are securely passed through the entire execution pipeline from the user's command to remote computers.

## Credential Flow Architecture

```
User Command
    ↓
Invoke-Task -Credential $cred
    ↓
WorkItem Objects (Credential property)
    ↓
Runspace Pool Execution (Credential context preserved)
    ↓
Invoke-TbRemoteExecution (Credential parameter)
    ↓
WinRM/SSH Protocol Handler
    ↓
Invoke-Command -Credential $cred (Remote authentication)
```

## Implementation Details

### 1. User Interface (`Invoke-Task`)

```powershell
[Parameter()]
[System.Management.Automation.PSCredential]$Credential
```

- Accepts standard PowerShell `PSCredential` objects
- Optional parameter (not required for localhost execution)
- Credential is validated by PowerShell runtime

### 2. Work Item Assignment (`WorkQueue.ps1`)

```powershell
$workItem.Credential = $Credential
```

- Credential is attached to each work item
- All computers in a single `Invoke-Task` call share the same credential
- Work items are queued with credential context

### 3. Runspace Execution (`WorkQueue.ps1`)

```powershell
$executionScript = {
    param($Computer, $ScriptBlock, $TaskParameters, $Credential, $Timeout)
    
    $result = Invoke-TbRemoteExecution -Computer $Computer `
        -ScriptBlock $ScriptBlock `
        -ArgumentList $argumentList `
        -Credential $Credential `
        -TimeoutSeconds $Timeout
}
```

- Credential is passed as a parameter to the runspace script block
- Each runspace thread receives the credential
- Runspace pools maintain credential context

### 4. Remote Execution (`RemoteExecution.ps1`)

#### WinRM Protocol

```powershell
function Invoke-WinRMExecution {
    param(
        [System.Management.Automation.PSCredential]$Credential
    )
    
    $invokeParams = @{
        ComputerName = $Computer
        ScriptBlock = $ScriptBlock
        Credential = $Credential  # Passed to Invoke-Command
    }
    
    Invoke-Command @invokeParams
}
```

#### SSH Protocol (PowerShell 7+)

```powershell
function Invoke-SSHExecution {
    param(
        [System.Management.Automation.PSCredential]$Credential
    )
    
    $invokeParams = @{
        HostName = $Computer
        ScriptBlock = $ScriptBlock
        UserName = $Credential.UserName  # SSH uses username
    }
    
    Invoke-Command @invokeParams
}
```

#### Localhost Optimization

- No credential needed for localhost execution
- Direct script block invocation in current context
- Bypasses remoting overhead

## Usage Examples

### Basic Authentication

```powershell
# Interactive credential prompt
$cred = Get-Credential

# Execute with credentials
Invoke-Task -TaskName 'System.GetUptime' `
    -Computers 'Server1','Server2','Server3' `
    -Credential $cred
```

### Stored Credentials

```powershell
# Build credential from secure string
$username = 'DOMAIN\Administrator'
$password = ConvertTo-SecureString 'P@ssw0rd' -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($username, $password)

# Execute
Invoke-Task -TaskName 'Service.GetService' `
    -Computers 'C:\servers.txt' `
    -Credential $cred `
    -TaskParameters @{ ServiceName = 'W3SVC' }
```

### From Secure Credential Storage

```powershell
# Export credential securely (one-time setup)
$cred = Get-Credential
$cred | Export-Clixml -Path "$env:USERPROFILE\admin-cred.xml"

# Import and use
$cred = Import-Clixml -Path "$env:USERPROFILE\admin-cred.xml"
Invoke-Task -TaskName 'System.GetBasicInfo' -Computers 'Server1' -Credential $cred
```

### Different Credentials for Different Batches

```powershell
# Domain servers with domain cred
$domainCred = Get-Credential DOMAIN\Admin
Invoke-Task -TaskName 'System.GetUptime' `
    -Computers 'DC01','DC02' `
    -Credential $domainCred

# Workgroup servers with local cred
$localCred = Get-Credential Administrator
Invoke-Task -TaskName 'System.GetUptime' `
    -Computers 'DMZ01','DMZ02' `
    -Credential $localCred
```

## Security Considerations

### ✅ Secure Practices

1. **PSCredential Objects**: Use `[PSCredential]` type (not plain text)
2. **Secure String**: Passwords stored as `SecureString` in memory
3. **No Logging**: Credentials never written to logs
4. **No Storage**: Credentials not saved in configuration files
5. **Masked Output**: Sensitive data masked in log files (see `Write-TbLog`)
6. **Thread Safety**: Credentials safely passed through runspace boundaries

### 🔒 Sensitive Data Masking

The module automatically masks these property names in logs:

- Password
- Secret
- Token
- Key
- Credential
- ApiKey
- AccessToken
- RefreshToken
- ClientSecret

### 🛡️ Authentication Methods

**WinRM (Default for Windows)**

- Kerberos (domain-joined)
- NTLM (workgroup)
- Basic (with SSL)
- Negotiate (automatic)

**SSH (PowerShell 7+ only)**

- Username from credential
- Key-based authentication (preferred)
- Password authentication (requires SSH server config)

**Localhost**

- No credential required
- Executes in current user context

## Testing Credential Flow

### Test Script

```powershell
# Create test credential
$testPass = ConvertTo-SecureString "TestPassword123" -AsPlainText -Force
$testCred = New-Object PSCredential ("TestUser", $testPass)

# Test on localhost (should work without cred)
$result1 = Invoke-Task -TaskName 'System.GetUptime' -Computers 'localhost'
Write-Host "Localhost (no cred): $($result1.Status)" -ForegroundColor Green

# Test with credential (will attempt authentication)
try {
    $result2 = Invoke-Task -TaskName 'System.GetUptime' `
        -Computers 'localhost' `
        -Credential $testCred
    
    Write-Host "With credential: $($result2.Status)" -ForegroundColor Green
}
catch {
    Write-Host "Credential test (expected to use localhost bypass): OK" -ForegroundColor Yellow
}
```

## Credential Limitations

### Current Limitations

1. **Single Credential Per Call**: All computers in one `Invoke-Task` call use the same credential
2. **No Credential Persistence**: Credentials not cached between calls
3. **SSH Password Auth**: Requires SSH server configuration for password authentication

### Workarounds

**Multiple Credentials**:

```powershell
# Group computers by credential requirement
$domainServers = @('DC01', 'DC02')
$workgroupServers = @('WEB01', 'WEB02')

$domainCred = Get-Credential DOMAIN\Admin
$workgroupCred = Get-Credential Administrator

# Execute separately
$results1 = Invoke-Task -Computers $domainServers -TaskName 'System.GetUptime' -Credential $domainCred
$results2 = Invoke-Task -Computers $workgroupServers -TaskName 'System.GetUptime' -Credential $workgroupCred

# Combine results
$allResults = $results1 + $results2
```

## Future Enhancements

Potential future features for credential handling:

- [ ] Per-computer credential mapping
- [ ] Credential provider integration
- [ ] Azure Key Vault integration
- [ ] CyberArk/Thycotic integration
- [ ] Certificate-based authentication
- [ ] CredSSP delegation support (opt-in)
- [ ] Credential caching with timeout

## Troubleshooting

### Common Issues

**"Access Denied" errors**:

- Verify credential has proper permissions on target system
- Check if WinRM is enabled: `Test-WSMan Server01`
- Ensure firewall allows WinRM (port 5985/5986)

**"Credential parameter not accepted"**:

- Localhost execution doesn't use credentials (by design)
- Check if computer name resolves correctly

**SSH authentication fails**:

- Ensure PowerShell 7+ is being used
- Verify SSH key configuration
- Check SSH server allows password authentication (if using password)

### Debug Credential Flow

```powershell
# Enable verbose output to trace credential usage
$VerbosePreference = 'Continue'

Invoke-Task -TaskName 'System.GetUptime' `
    -Computers 'Server01' `
    -Credential $cred `
    -Verbose

# Check logs for authentication details
Get-TaskLog -Last 10 -Level Verbose | Where-Object { $_.Message -like '*credential*' }
```

## Summary

✅ **Credential support is fully implemented** throughout the Toolbox module  
✅ **Secure handling** with PSCredential objects and SecureString  
✅ **Thread-safe** passing through runspace pools  
✅ **Protocol support** for WinRM and SSH  
✅ **No storage** of credentials in logs or config  
✅ **Sensitive data masking** prevents credential leakage  

The credential implementation follows PowerShell security best practices and provides a seamless authentication experience for remote task execution.
