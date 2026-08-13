#Requires -Version 5.1

<#
.SYNOPSIS
    GitLabAuthEngine - Secure GitLab Authentication for FRB-Auto-Packaging Tool
.DESCRIPTION
    Engine 15 of 15 - Handles secure token storage and retrieval using Windows DPAPI
    Replaces plain-text token storage with per-user encrypted credentials
.NOTES
    Engine Number: 15
    Dependencies: None (uses built-in Windows DPAPI)
    Token Storage: $env:USERPROFILE\.config\frb-packaging-gitlab-token.xml
    Encryption: Windows Data Protection API (DPAPI)
#>

# Module-level variables
$Script:TokenPath = "$env:USERPROFILE\.config\frb-packaging-gitlab-token.xml"
$Script:ConfigDir = "$env:USERPROFILE\.config"

#region Core Functions

function Test-GitLabTokenExists {
    <#
    .SYNOPSIS
        Check if GitLab token has been configured for current user
    .DESCRIPTION
        Returns true if encrypted token file exists in user's config directory
        Does not validate token - only checks file existence
    .OUTPUTS
        Boolean - True if token file exists, False otherwise
    .EXAMPLE
        if (Test-GitLabTokenExists) {
            Write-Host "Token is configured"
        } else {
            Write-Host "Run Setup-GitLabToken.ps1 first"
        }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    Process {
        $exists = Test-Path -Path $Script:TokenPath
        Write-Verbose "GitLab token exists: $exists"
        return $exists
    }
}

function Get-GitLabToken {
    <#
    .SYNOPSIS
        Retrieve stored GitLab Personal Access Token
    .DESCRIPTION
        Decrypts and returns the GitLab PAT from secure storage
        Token is decrypted using Windows DPAPI - only works for user who stored it
    .OUTPUTS
        String - Decrypted token if successful, $null if not found or decryption fails
    .EXAMPLE
        $token = Get-GitLabToken
        if ($null -ne $token) {
            $headers = @{ 'PRIVATE-TOKEN' = $token }
            Invoke-RestMethod -Uri "..." -Headers $headers
        }
    .NOTES
        This function returns plain text token in memory only
        Token is never written to disk in plain text
        Token cleared from memory when variable goes out of scope
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    Process {
        try {
            if (-not (Test-Path -Path $Script:TokenPath)) {
                Write-Verbose "Token file not found at: $Script:TokenPath"
                return $null
            }
            
            # Import encrypted credential (DPAPI decryption automatic)
            $credential = Import-Clixml -Path $Script:TokenPath -ErrorAction Stop
            
            # Extract plain text token from SecureString
            $token = $credential.GetNetworkCredential().Password
            
            if ([string]::IsNullOrWhiteSpace($token)) {
                Write-Warning "Token file exists but contains no token"
                return $null
            }
            
            Write-Verbose "Token retrieved successfully (length: $($token.Length))"
            return $token
        }
        catch {
            Write-Error "Failed to retrieve GitLab token: $($_.Exception.Message)"
            Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
            return $null
        }
    }
}

function Set-GitLabToken {
    <#
    .SYNOPSIS
        Store GitLab token securely using Windows DPAPI encryption
    .DESCRIPTION
        Encrypts the provided token and stores it in user's config directory
        Token can only be decrypted by same user on same machine
    .PARAMETER Token
        The GitLab Personal Access Token as a SecureString
    .PARAMETER TokenString
        The GitLab Personal Access Token as a plain string (will be converted to SecureString)
    .OUTPUTS
        Boolean - True if token stored successfully, False otherwise
    .EXAMPLE
        # Using SecureString (recommended)
        $token = Read-Host "GitLab Token" -AsSecureString
        if (Set-GitLabToken -Token $token) {
            Write-Host "Token stored successfully"
        }
    .EXAMPLE
        # Using plain string (less secure during input)
        $result = Set-GitLabToken -TokenString "glpat-xxxxxxxxxxxxx"
    #>
    [CmdletBinding(DefaultParameterSetName = 'SecureString')]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'SecureString')]
        [SecureString]$Token,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'PlainString')]
        [string]$TokenString
    )
    
    Process {
        try {
            # Convert plain string to SecureString if needed
            if ($PSCmdlet.ParameterSetName -eq 'PlainString') {
                $Token = ConvertTo-SecureString -String $TokenString -AsPlainText -Force
            }
            
            # Create config directory if needed
            if (-not (Test-Path -Path $Script:ConfigDir)) {
                Write-Verbose "Creating config directory: $Script:ConfigDir"
                New-Item -Path $Script:ConfigDir -ItemType Directory -Force | Out-Null
            }
            
            # Create PSCredential object and export encrypted
            $credential = New-Object System.Management.Automation.PSCredential("GitLabToken", $Token)
            $credential | Export-Clixml -Path $Script:TokenPath -Force
            
            Write-Verbose "Token stored successfully at: $Script:TokenPath"
            return $true
        }
        catch {
            Write-Error "Failed to store GitLab token: $($_.Exception.Message)"
            Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
            return $false
        }
    }
}

function Remove-GitLabToken {
    <#
    .SYNOPSIS
        Remove stored GitLab token
    .DESCRIPTION
        Deletes the encrypted token file from user's config directory
        Use this to clear token before setting a new one or troubleshooting
    .OUTPUTS
        Boolean - True if token removed (or didn't exist), False on error
    .EXAMPLE
        if (Remove-GitLabToken) {
            Write-Host "Token removed. Run Setup-GitLabToken.ps1 to configure new token."
        }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    Process {
        try {
            if (Test-Path -Path $Script:TokenPath) {
                Remove-Item -Path $Script:TokenPath -Force -ErrorAction Stop
                Write-Verbose "Token file removed successfully"
                return $true
            }
            else {
                Write-Verbose "No token file to remove"
                return $true
            }
        }
        catch {
            Write-Error "Failed to remove token file: $($_.Exception.Message)"
            return $false
        }
    }
}

#endregion

#region Helper Functions

function Get-TokenInfo {
    <#
    .SYNOPSIS
        Get information about stored token without revealing it
    .DESCRIPTION
        Returns metadata about the token file (exists, path, age)
        Does not return the actual token value
    .OUTPUTS
        Hashtable with token information
    .EXAMPLE
        $info = Get-TokenInfo
        Write-Host "Token configured: $($info.Exists)"
        Write-Host "Token age: $($info.AgeInDays) days"
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    
    Process {
        $info = @{
            Exists = $false
            Path = $Script:TokenPath
            AgeInDays = 0
            LastModified = $null
            FileSize = 0
        }
        
        if (Test-Path -Path $Script:TokenPath) {
            $file = Get-Item -Path $Script:TokenPath
            $info.Exists = $true
            $info.LastModified = $file.LastWriteTime
            $info.AgeInDays = [math]::Round((New-TimeSpan -Start $file.LastWriteTime -End (Get-Date)).TotalDays, 1)
            $info.FileSize = $file.Length
        }
        
        return $info
    }
}

function Test-GitLabTokenValid {
    <#
    .SYNOPSIS
        Validate token by making test API call to GitLab
    .DESCRIPTION
        Attempts to retrieve current user info from GitLab API
        Returns true if token works, false if invalid/expired
    .PARAMETER GitLabUrl
        GitLab instance URL (default: FRB GitLab)
    .OUTPUTS
        Hashtable with validation results
    .EXAMPLE
        $result = Test-GitLabTokenValid
        if ($result.Valid) {
            Write-Host "Token is valid for user: $($result.Username)"
        }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$GitLabUrl = "https://gitlab.prod.nit-cicd.awscfs.frb.pvt"
    )
    
    Process {
        $result = @{
            Valid = $false
            Username = ""
            Message = ""
            StatusCode = 0
        }
        
        try {
            $token = Get-GitLabToken
            if ($null -eq $token) {
                $result.Message = "No token configured"
                return $result
            }
            
            $headers = @{ 'PRIVATE-TOKEN' = $token }
            $uri = "$GitLabUrl/api/v4/user"
            
            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ErrorAction Stop
            
            $result.Valid = $true
            $result.Username = $response.username
            $result.Message = "Token valid for user: $($response.username)"
            $result.StatusCode = 200
            
            Write-Verbose "Token validation successful"
        }
        catch {
            $statusCode = 0
            if ($_.Exception.Response) {
                $statusCode = $_.Exception.Response.StatusCode.value__
            }
            
            $result.Valid = $false
            $result.StatusCode = $statusCode
            
            switch ($statusCode) {
                401 { $result.Message = "Token is invalid or expired" }
                403 { $result.Message = "Token lacks required permissions" }
                404 { $result.Message = "GitLab API endpoint not found" }
                default { $result.Message = "Token validation failed: $($_.Exception.Message)" }
            }
            
            Write-Verbose "Token validation failed: $($result.Message)"
        }
        
        return $result
    }
}

function Show-GitLabTokenSetupDialog {
    <#
    .SYNOPSIS
        Display GUI dialog for token setup instructions
    .DESCRIPTION
        Shows Windows Forms message box with setup instructions
        Provides link to Setup-GitLabToken.ps1 script
    .PARAMETER ToolPath
        Path to FRB-Auto-Packaging installation (defaults to script root)
    .OUTPUTS
        None - displays dialog only
    .EXAMPLE
        Show-GitLabTokenSetupDialog
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ToolPath = $PSScriptRoot
    )
    
    Process {
        Add-Type -AssemblyName System.Windows.Forms
        
        # Find root of tool (3 levels up from engine folder)
        $toolRoot = Split-Path (Split-Path (Split-Path $ToolPath -Parent) -Parent) -Parent
        $setupScript = Join-Path $toolRoot "Setup-GitLabToken.ps1"
        
        $message = @"
GitLab Token Setup Required

The Master Template download requires a GitLab Personal Access Token.
This is a ONE-TIME setup that takes less than 2 minutes.

STEP 1: Get Your Token
1. Open: https://gitlab.prod.nit-cicd.awscfs.frb.pvt/-/user_settings/personal_access_tokens
2. Create new token with 'read_repository' scope
3. Copy the token (starts with glpat-)

STEP 2: Run Setup Script
Run this script and paste your token:
$setupScript

SECURITY:
• Token encrypted using Windows DPAPI
• Only YOU can decrypt it
• No plain text storage

Click OK to continue, then run the setup script.
"@
        
        [System.Windows.Forms.MessageBox]::Show(
            $message,
            "GitLab Token Setup Required",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }
}

#endregion

#region Engine Info

function Get-GitLabAuthEngineInfo {
    <#
    .SYNOPSIS
        Get information about GitLabAuthEngine
    .DESCRIPTION
        Returns engine metadata and status
    .OUTPUTS
        Hashtable with engine information
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    
    Process {
        $tokenInfo = Get-TokenInfo
        $validation = Test-GitLabTokenValid
        
        return @{
            EngineName = "GitLabAuthEngine"
            EngineNumber = 15
            Version = "1.0.0"
            Description = "Secure GitLab authentication using Windows DPAPI"
            TokenConfigured = $tokenInfo.Exists
            TokenValid = $validation.Valid
            TokenPath = $Script:TokenPath
            TokenAge = $tokenInfo.AgeInDays
            LastModified = $tokenInfo.LastModified
        }
    }
}

#endregion

# Export public functions
Export-ModuleMember -Function `
    Test-GitLabTokenExists, `
    Get-GitLabToken, `
    Set-GitLabToken, `
    Remove-GitLabToken, `
    Get-TokenInfo, `
    Test-GitLabTokenValid, `
    Show-GitLabTokenSetupDialog, `
    Get-GitLabAuthEngineInfo
