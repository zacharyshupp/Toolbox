<#
.SYNOPSIS
    Send an HTTP request and return response details

.DESCRIPTION
    Sends HTTP/HTTPS requests to web endpoints and returns detailed response information including status codes, headers, timing, and content.

.PARAMETER Uri
    URL to send the request to

.PARAMETER Method
    HTTP method to use. Valid values: GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS. Default: GET

.PARAMETER Body
    Request body content

.PARAMETER ContentType
    Content type for the request body. Default: application/json

.PARAMETER TimeoutSeconds
    Request timeout in seconds. Default: 30

.NOTES
    TaskName: HTTP.InvokeRequest
    Version: 1.0.0
    Author: Toolbox
    Tags: HTTP, Web, API, REST
    RequiresElevation: False
    SupportedOS: Windows, Linux, MacOS
    PSEdition: Desktop, Core
    MinPSVersion: 5.1
    Timeout: 60

.EXAMPLE
    Invoke-Task -TaskName 'HTTP.InvokeRequest' -Computers 'localhost' -TaskParameters @{ Uri = 'https://api.github.com' }

.EXAMPLE
    Invoke-Task -TaskName 'HTTP.InvokeRequest' -Computers 'localhost' -TaskParameters @{ Uri = 'https://api.example.com/data'; Method = 'POST'; Body = '{"key":"value"}' }
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Uri,

    [Parameter()]
    [ValidateSet('GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS')]
    [string]$Method = 'GET',

    [Parameter()]
    [string]$Body,

    [Parameter()]
    [string]$ContentType = 'application/json',

    [Parameter()]
    [int]$TimeoutSeconds = 30
)

try {
    Write-Verbose "Sending $Method request to: $Uri"
    
    # Build parameters for Invoke-RestMethod/Invoke-WebRequest
    $requestParams = @{
        Uri             = $Uri
        Method          = $Method
        TimeoutSec      = $TimeoutSeconds
        ErrorAction     = 'Stop'
    }
    
    # Add body if provided
    if ($PSBoundParameters.ContainsKey('Body')) {
        $requestParams['Body'] = $Body
        $requestParams['ContentType'] = $ContentType
        Write-Verbose "Request body length: $($Body.Length) characters"
        Write-Verbose "Content type: $ContentType"
    }
    
    # Measure request time
    $startTime = Get-Date
    
    try {
        # Use Invoke-WebRequest to get full response details
        $response = Invoke-WebRequest @requestParams
        $success = $true
        $errorMessage = $null
    }
    catch {
        $success = $false
        $response = $_.Exception.Response
        $errorMessage = $_.Exception.Message
        
        Write-Verbose "Request failed: $errorMessage"
    }
    
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalMilliseconds
    
    Write-Verbose "Request completed in $([math]::Round($duration, 2)) ms"
    
    # Build result object
    if ($success) {
        $result = [PSCustomObject]@{
            Success           = $true
            StatusCode        = $response.StatusCode
            StatusDescription = $response.StatusDescription
            ResponseTime      = [math]::Round($duration, 2)
            ContentLength     = $response.Content.Length
            ContentType       = $response.Headers['Content-Type']
            Server            = $response.Headers['Server']
            Headers           = $response.Headers
            Content           = $response.Content
            Uri               = $Uri
            Method            = $Method
        }
        
        Write-Verbose "Response status: $($response.StatusCode) $($response.StatusDescription)"
    }
    else {
        # Handle error response
        $statusCode = if ($response) { [int]$response.StatusCode } else { $null }
        
        $result = [PSCustomObject]@{
            Success           = $false
            StatusCode        = $statusCode
            StatusDescription = if ($response) { $response.StatusDescription } else { 'Request Failed' }
            ResponseTime      = [math]::Round($duration, 2)
            Error             = $errorMessage
            Uri               = $Uri
            Method            = $Method
        }
    }
    
    $result
}
catch {
    Write-Error "Failed to send HTTP request: $_"
    throw
}
