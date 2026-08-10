#Requires -Version 5.1
<#
.SYNOPSIS
    Documentation Session Engine
    
.DESCRIPTION
    Manages documentation session lifecycle, state, and persistence.
    Pure state management engine with no external dependencies.
    
.NOTES
    Author: P1MAM08
    Date: 2026-07-09
    Version: 1.0.0
    Type: Engine (Self-contained, integrable)
#>


#region Helper Functions

function Get-OSVersion {
    <#
    .SYNOPSIS
        Gets the current operating system version in proper format
    #>
    try {
        $arch = $env:PROCESSOR_ARCHITECTURE
        if ($arch -eq 'AMD64') { $arch = '64x' }
        elseif ($arch -eq 'x86') { $arch = '32x' }
        
        $displayVersion = (Get-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion' -Name DisplayVersion -ErrorAction SilentlyContinue).DisplayVersion
        
        if ($displayVersion) {
            return "Windows 11 $arch ($displayVersion)"
        } else {
            return "Windows 11 $arch"
        }
    } catch {
        return "Windows 11 64x"
    }
}

#endregion
#region Public Functions

function New-DocumentationSession {
    <#
    .SYNOPSIS
        Creates a new documentation session
        
    .PARAMETER AppName
        Application name
        
    .PARAMETER AppVersion
        Application version
        
    .PARAMETER TicketNumber
        Ticket/work item number
        
    .PARAMETER TechName
        Technician name (defaults to current user)
        
    .PARAMETER OSVersion
        Operating system version
        
    .PARAMETER WorkingDirectory
        Directory for temporary files (auto-created if not specified)
        
    .OUTPUTS
        PSCustomObject representing the session
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppName,
        
        [Parameter(Mandatory)]
        [string]$AppVersion,
        
        [Parameter(Mandatory)]
        [string]$TicketNumber,
        
        [Parameter()]
        [string]$TechName = $env:USERNAME,
        
        [Parameter()]
        [string]$OSVersion,
        
        [Parameter()]
        [string]$WorkingDirectory
    )
    
    # Auto-detect OS if not provided
    if ([string]::IsNullOrWhiteSpace($OSVersion)) {
        $OSVersion = Get-OSVersion
    }
    
    Write-Verbose "Creating documentation session for $AppName $AppVersion"
    
    # Create working directory if not specified
    if ([string]::IsNullOrWhiteSpace($WorkingDirectory)) {
        # Use .\screenshots\ relative to module location (dynamic, portable)
        $moduleRoot = Split-Path -Parent $PSScriptRoot
        $WorkingDirectory = Join-Path $moduleRoot "screenshots"
    }
    
    # Ensure directory exists
    if (-not (Test-Path $WorkingDirectory)) {
        New-Item -ItemType Directory -Path $WorkingDirectory -Force | Out-Null
        Write-Verbose "Created working directory: $WorkingDirectory"
    }
    
    # Create session object
    $session = [PSCustomObject]@{
        SessionId = [guid]::NewGuid().ToString()
        AppName = $AppName
        AppVersion = $AppVersion
        TicketNumber = $TicketNumber
        TechName = $TechName
        OSVersion = $OSVersion
        WorkingDirectory = $WorkingDirectory
        CreatedDate = Get-Date
        Status = 'Active'
        Captures = @{
            Figure2 = $null
            Figure3 = $null
            Figure4 = $null
            Figure5 = $null
        }
        InstallDetails = @{
            InstallDirectory = ""
            ServicesCreated = "None"
            ConfigFiles = "None"
            RegistryKeys = ""
            UninstallKeys = ""
            RebootRequired = "No"
        }
        DeepDiveData = $null
    }
    
    Write-Verbose "Session created with ID: $($session.SessionId)"
    
    return $session
}

function Get-DocumentationSessionStatus {
    <#
    .SYNOPSIS
        Gets the current status of a documentation session
        
    .PARAMETER Session
        Session object
        
    .OUTPUTS
        Status summary object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]$Session
    )
    
    $captureCount = 0
    if ($Session.Captures.Figure2) { $captureCount++ }
    if ($Session.Captures.Figure3) { $captureCount++ }
    if ($Session.Captures.Figure4) { $captureCount++ }
    if ($Session.Captures.Figure5) { $captureCount++ }
    
    $detailsDetected = -not [string]::IsNullOrWhiteSpace($Session.InstallDetails.InstallDirectory)
    
    $status = [PSCustomObject]@{
        SessionId = $Session.SessionId
        AppName = $Session.AppName
        Status = $Session.Status
        CapturesCompleted = $captureCount
        TotalCaptures = 4
        DetailsDetected = $detailsDetected
        WorkingDirectory = $Session.WorkingDirectory
        IsReadyForGeneration = ($captureCount -eq 4)
    }
    
    return $status
}

function Update-DocumentationSessionCapture {
    <#
    .SYNOPSIS
        Updates a capture in the session
        
    .PARAMETER Session
        Session object
        
    .PARAMETER FigureNumber
        Figure number (2, 3, 4, or 5)
        
    .PARAMETER FilePath
        Path to the captured screenshot
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]$Session,
        
        [Parameter(Mandatory)]
        [ValidateSet(2, 3, 4, 5)]
        [int]$FigureNumber,
        
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Warning "Capture file not found: $FilePath"
        return $Session
    }
    
    Write-Verbose "Updating Figure $FigureNumber with $FilePath"
    
    switch ($FigureNumber) {
        2 { $Session.Captures.Figure2 = $FilePath }
        3 { $Session.Captures.Figure3 = $FilePath }
        4 { $Session.Captures.Figure4 = $FilePath }
        5 { $Session.Captures.Figure5 = $FilePath }
    }
    
    return $Session
}

function Update-DocumentationSessionDetails {
    <#
    .SYNOPSIS
        Updates installation details in the session
        
    .PARAMETER Session
        Session object
        
    .PARAMETER InstallDirectory
        Installation directory path
        
    .PARAMETER RegistryKeys
        Registry keys (comma-separated or single string)
        
    .PARAMETER DesktopShortcuts
        Desktop shortcuts
        
    .PARAMETER ServicesCreated
        Services created
        
    .PARAMETER ConfigFiles
        Configuration files
        
    .PARAMETER RebootRequired
        Whether reboot is required
        
    .PARAMETER DeepDiveData
        Deep dive data object from elevated collection
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]$Session,
        
        [Parameter()]
        [string]$InstallDirectory,
        
        [Parameter()]
        [string]$RegistryKeys,
        
        [Parameter()]
        [string]$ServicesCreated,
        
        [Parameter()]
        [string]$ConfigFiles,
        
        [Parameter()]
        [ValidateSet("Yes", "No")]
        [string]$RebootRequired,
        
        [Parameter()]
        [string]$UninstallKeys,
        
        [Parameter()]
        [PSCustomObject]$DeepDiveData
    )
    
    Write-Verbose "Updating installation details"
    
    if ($InstallDirectory) { $Session.InstallDetails.InstallDirectory = $InstallDirectory }
    if ($RegistryKeys) { $Session.InstallDetails.RegistryKeys = $RegistryKeys }
    if ($DesktopShortcuts) { $Session.InstallDetails.DesktopShortcuts = $DesktopShortcuts }
    if ($ServicesCreated) { $Session.InstallDetails.ServicesCreated = $ServicesCreated }
    if ($ConfigFiles) { $Session.InstallDetails.ConfigFiles = $ConfigFiles }
    if ($RebootRequired) { $Session.InstallDetails.RebootRequired = $RebootRequired }
    if ($UninstallKeys) { $Session.InstallDetails.UninstallKeys = $UninstallKeys }
    if ($DeepDiveData) { $Session.DeepDiveData = $DeepDiveData }
    
    return $Session
}
Export-ModuleMember -Function @(
    'New-DocumentationSession',
    'Get-DocumentationSessionStatus',
    'Update-DocumentationSessionCapture',
    'Update-DocumentationSessionDetails',
    'Close-DocumentationSession',
    'Save-DocumentationSession',
    'Restore-DocumentationSession'
)
