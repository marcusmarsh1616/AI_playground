# SessionManager.psm1
# Module for managing documentation capture sessions

<#
.SYNOPSIS
    Manages documentation capture sessions with auto-numbering and organization.

.DESCRIPTION
    This module handles session lifecycle, auto-incrementing capture numbers,
    folder organization, and session metadata tracking.
#>

# Module variables
$script:CurrentSession = $null
$script:SessionActive = $false

function Start-CaptureSession {
    <#
    .SYNOPSIS
        Starts a new documentation capture session.
    
    .DESCRIPTION
        Initializes a new session with a unique name and output folder.
        Creates directory structure and session manifest.
    
    .PARAMETER SessionName
        Name for this capture session (e.g., "MyTool-Setup-Guide")
    
    .PARAMETER OutputBasePath
        Base directory for all captures. Default: Documents\SnagitCaptures
    
    .EXAMPLE
        Start-CaptureSession -SessionName "UserGuide-Installation"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SessionName,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputBasePath = "$env:USERPROFILE\Documents\SnagitCaptures"
    )
    
    if ($script:SessionActive) {
        Write-Warning "Session already active: $($script:CurrentSession.Name)"
        Write-Warning "End current session before starting a new one."
        return $false
    }
    
    try {
        # Create timestamp for unique session folder
        $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
        $sessionFolder = Join-Path -Path $OutputBasePath -ChildPath "$SessionName`_$timestamp"
        
        # Create directory structure
        New-Item -Path $sessionFolder -ItemType Directory -Force | Out-Null
        
        # Initialize session object
        $script:CurrentSession = @{
            Name = $SessionName
            FolderPath = $sessionFolder
            StartTime = Get-Date
            CaptureCount = 0
            Captures = @()
            Timestamp = $timestamp
        }
        
        $script:SessionActive = $true
        
        # Create session manifest
        $manifestPath = Join-Path -Path $sessionFolder -ChildPath "session-manifest.json"
        $script:CurrentSession | ConvertTo-Json -Depth 3 | Out-File -FilePath $manifestPath -Encoding UTF8
        
        Write-Verbose "Session started: $SessionName"
        Write-Verbose "Output folder: $sessionFolder"
        
        return @{
            Success = $true
            SessionName = $SessionName
            FolderPath = $sessionFolder
        }
    }
    catch {
        Write-Error "Failed to start session: $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-NextCaptureNumber {
    <#
    .SYNOPSIS
        Gets the next sequential capture number for the current session.
    
    .DESCRIPTION
        Returns auto-incremented number in 3-digit format (001, 002, etc.)
    
    .EXAMPLE
        $num = Get-NextCaptureNumber  # Returns "001"
    #>
    [CmdletBinding()]
    param()
    
    if (-not $script:SessionActive) {
        throw "No active session. Start a session first."
    }
    
    $script:CurrentSession.CaptureCount++
    return $script:CurrentSession.CaptureCount.ToString("000")
}

function Get-NextCaptureFilePath {
    <#
    .SYNOPSIS
        Generates the full file path for the next capture.
    
    .DESCRIPTION
        Creates properly formatted file path with auto-incremented number
        and .jpg extension.
    
    .PARAMETER Description
        Optional description to include in filename
    
    .EXAMPLE
        $path = Get-NextCaptureFilePath -Description "Main-Window"
        # Returns: C:\...\Session_001_Main-Window.jpg
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Description = ""
    )
    
    if (-not $script:SessionActive) {
        throw "No active session. Start a session first."
    }
    
    $number = Get-NextCaptureNumber
    
    if ([string]::IsNullOrWhiteSpace($Description)) {
        $filename = "$($script:CurrentSession.Name)_$number.jpg"
    }
    else {
        # Sanitize description for filename
        $safeDescription = $Description -replace '[\\/:*?"<>|]', '-'
        $filename = "$($script:CurrentSession.Name)_$number`_$safeDescription.jpg"
    }
    
    return Join-Path -Path $script:CurrentSession.FolderPath -ChildPath $filename
}

function Add-CaptureToSession {
    <#
    .SYNOPSIS
        Records a capture in the current session metadata.
    
    .DESCRIPTION
        Tracks capture details for session manifest and documentation generation.
    
    .PARAMETER FilePath
        Path to the captured image file
    
    .PARAMETER Description
        Optional description of what was captured
    
    .EXAMPLE
        Add-CaptureToSession -FilePath "C:\...\capture.jpg" -Description "Login screen"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $false)]
        [string]$Description = ""
    )
    
    if (-not $script:SessionActive) {
        throw "No active session."
    }
    
    $captureInfo = @{
        Number = $script:CurrentSession.CaptureCount
        FilePath = $FilePath
        Filename = Split-Path -Path $FilePath -Leaf
        Description = $Description
        Timestamp = Get-Date
        FileSize = (Get-Item $FilePath -ErrorAction SilentlyContinue).Length
    }
    
    $script:CurrentSession.Captures += $captureInfo
    
    # Update manifest file
    $manifestPath = Join-Path -Path $script:CurrentSession.FolderPath -ChildPath "session-manifest.json"
    $script:CurrentSession | ConvertTo-Json -Depth 3 | Out-File -FilePath $manifestPath -Encoding UTF8
    
    Write-Verbose "Capture recorded: $($captureInfo.Filename)"
}

function Stop-CaptureSession {
    <#
    .SYNOPSIS
        Ends the current capture session.
    
    .DESCRIPTION
        Finalizes session, saves manifest, and optionally generates documentation.
    
    .PARAMETER GenerateSummary
        Create a summary markdown file of all captures
    
    .EXAMPLE
        Stop-CaptureSession -GenerateSummary
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$GenerateSummary
    )
    
    if (-not $script:SessionActive) {
        Write-Warning "No active session to stop."
        return $false
    }
    
    try {
        $script:CurrentSession.EndTime = Get-Date
        $duration = $script:CurrentSession.EndTime - $script:CurrentSession.StartTime
        $script:CurrentSession.Duration = $duration.ToString()
        
        # Save final manifest
        $manifestPath = Join-Path -Path $script:CurrentSession.FolderPath -ChildPath "session-manifest.json"
        $script:CurrentSession | ConvertTo-Json -Depth 3 | Out-File -FilePath $manifestPath -Encoding UTF8
        
        # Generate summary if requested
        if ($GenerateSummary) {
            New-SessionSummary
        }
        
        Write-Host "[INFO] Session completed: $($script:CurrentSession.Name)" -ForegroundColor Green
        Write-Host "[INFO] Total captures: $($script:CurrentSession.CaptureCount)" -ForegroundColor Green
        Write-Host "[INFO] Output folder: $($script:CurrentSession.FolderPath)" -ForegroundColor Cyan
        
        $result = @{
            Success = $true
            SessionName = $script:CurrentSession.Name
            CaptureCount = $script:CurrentSession.CaptureCount
            FolderPath = $script:CurrentSession.FolderPath
            Duration = $duration
        }
        
        # Clear session
        $script:CurrentSession = $null
        $script:SessionActive = $false
        
        return $result
    }
    catch {
        Write-Error "Error stopping session: $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-CurrentSession {
    <#
    .SYNOPSIS
        Returns information about the current active session.
    
    .EXAMPLE
        $session = Get-CurrentSession
        Write-Host "Active: $($session.Name)"
    #>
    [CmdletBinding()]
    param()
    
    if ($script:SessionActive) {
        return $script:CurrentSession
    }
    else {
        return $null
    }
}

function Test-SessionActive {
    <#
    .SYNOPSIS
        Checks if a capture session is currently active.
    
    .EXAMPLE
        if (Test-SessionActive) { Write-Host "Session running" }
    #>
    [CmdletBinding()]
    param()
    
    return $script:SessionActive
}

function New-SessionSummary {
    <#
    .SYNOPSIS
        Generates a markdown summary of the capture session.
    
    .DESCRIPTION
        Creates documentation.md with all captures and descriptions.
    
    .EXAMPLE
        New-SessionSummary
    #>
    [CmdletBinding()]
    param()
    
    if (-not $script:SessionActive -and $null -eq $script:CurrentSession) {
        throw "No session data available."
    }
    
    $session = if ($script:SessionActive) { $script:CurrentSession } else { $script:CurrentSession }
    
    $mdPath = Join-Path -Path $session.FolderPath -ChildPath "documentation.md"
    
    $markdown = @"
# $($session.Name)

**Created:** $($session.StartTime)
**Total Captures:** $($session.CaptureCount)

---

## Captures

"@
    
    foreach ($capture in $session.Captures) {
        $markdown += @"

### $($capture.Number). $($capture.Description)

![Screenshot]($($capture.Filename))

**Captured:** $($capture.Timestamp)

---

"@
    }
    
    $markdown | Out-File -FilePath $mdPath -Encoding UTF8
    Write-Verbose "Documentation generated: $mdPath"
}

# Export module functions
Export-ModuleMember -Function @(
    'Start-CaptureSession',
    'Stop-CaptureSession',
    'Get-CurrentSession',
    'Test-SessionActive',
    'Get-NextCaptureNumber',
    'Get-NextCaptureFilePath',
    'Add-CaptureToSession',
    'New-SessionSummary'
)
