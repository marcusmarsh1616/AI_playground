#Requires -Version 5.1

<#
.SYNOPSIS
    Logger Module - Comprehensive logging for troubleshooting
.DESCRIPTION
    Provides centralized logging with automatic rotation, component tagging,
    and multiple log levels for easy troubleshooting.
.NOTES
    Author: FRB Automation Team
    Created: June 5, 2026
    Version: 1.0.0
#>

# Module-level variables
$script:LogInitialized = $false
$script:LogPath = ""
$script:LogLevel = "Info"
$script:MaxLogSizeMB = 10
$script:MaxLogFiles = 5
$script:SeparateErrorLog = $true
$script:TimestampFormat = "yyyy-MM-dd HH:mm:ss.fff"

function Initialize-Logger {
    <#
    .SYNOPSIS
        Initialize the logging system
    .PARAMETER Config
        Configuration object with logging settings
    .PARAMETER LogPath
        Path to log folder (default: logs)
    .PARAMETER LogLevel
        Minimum log level (Debug, Verbose, Info, Warning, Error)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$Config,
        
        [Parameter(Mandatory = $false)]
        [string]$LogPath = "logs",
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Debug','Verbose','Info','Warning','Error')]
        [string]$LogLevel = "Info"
    )
    
    try {
        # Use config if provided, otherwise use parameters
        if ($Config) {
            $script:LogPath = if ($Config.logPath) { $Config.logPath } else { $LogPath }
            $script:LogLevel = if ($Config.logLevel) { $Config.logLevel } else { $LogLevel }
            $script:MaxLogSizeMB = if ($Config.maxLogSizeMB) { $Config.maxLogSizeMB } else { 10 }
            $script:MaxLogFiles = if ($Config.maxLogFiles) { $Config.maxLogFiles } else { 5 }
            $script:SeparateErrorLog = if ($null -ne $Config.separateErrorLog) { $Config.separateErrorLog } else { $true }
            $script:TimestampFormat = if ($Config.timestampFormat) { $Config.timestampFormat } else { "yyyy-MM-dd HH:mm:ss.fff" }
        } else {
            $script:LogPath = $LogPath
            $script:LogLevel = $LogLevel
        }
        
        # Ensure log path is absolute
        if (-not [System.IO.Path]::IsPathRooted($script:LogPath)) {
            $script:LogPath = Join-Path $PSScriptRoot "..\..\$($script:LogPath)"
        }
        
        # Create log directory if it doesn't exist
        if (-not (Test-Path $script:LogPath)) {
            New-Item -Path $script:LogPath -ItemType Directory -Force | Out-Null
        }
        
        # Rotate logs if needed
        Invoke-LogRotation
        
        $script:LogInitialized = $true
        
        Write-AppLog "Logger initialized (Level: $script:LogLevel, Path: $script:LogPath)" -Level Info -Component "Logger"
    }
    catch {
        Write-Warning "Failed to initialize logger: $($_.Exception.Message)"
        $script:LogInitialized = $false
    }
}

function Write-AppLog {
    <#
    .SYNOPSIS
        Write a log entry
    .PARAMETER Message
        The message to log
    .PARAMETER Level
        Log level (Debug, Verbose, Info, Warning, Error)
    .PARAMETER Component
        Component name (e.g., UI, Engine, Core)
    .PARAMETER Exception
        Exception object to log
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Debug','Verbose','Info','Warning','Error')]
        [string]$Level = 'Info',
        
        [Parameter(Mandatory = $false)]
        [string]$Component = 'Main',
        
        [Parameter(Mandatory = $false)]
        [System.Exception]$Exception
    )
    
    # If not initialized, write to console only
    if (-not $script:LogInitialized) {
        Write-Host "[$Level] [$Component] $Message"
        return
    }
    
    # Check if this log level should be recorded
    $levels = @('Debug','Verbose','Info','Warning','Error')
    $currentLevelIndex = $levels.IndexOf($script:LogLevel)
    $messageLevelIndex = $levels.IndexOf($Level)
    
    if ($messageLevelIndex -lt $currentLevelIndex) {
        return  # Skip this message
    }
    
    try {
        # Format timestamp
        $timestamp = Get-Date -Format $script:TimestampFormat
        
        # Format log entry
        $logEntry = "$timestamp [$Level] [$Component] $Message"
        
        # Add exception details if provided
        if ($Exception) {
            $logEntry += "`n    Exception: $($Exception.Message)"
            $logEntry += "`n    StackTrace: $($Exception.StackTrace)"
        }
        
        # Get log file paths
        $mainLogFile = Join-Path $script:LogPath "app_$(Get-Date -Format 'yyyy-MM-dd').log"
        $errorLogFile = Join-Path $script:LogPath "errors_$(Get-Date -Format 'yyyy-MM-dd').log"
        
        # Write to main log
        Add-Content -Path $mainLogFile -Value $logEntry -Encoding UTF8
        
        # Write to error log if error level and separate error log is enabled
        if ($Level -eq 'Error' -and $script:SeparateErrorLog) {
            Add-Content -Path $errorLogFile -Value $logEntry -Encoding UTF8
        }
        
        # Also write to console for Warning and Error
        if ($Level -in @('Warning','Error')) {
            $color = if ($Level -eq 'Error') { 'Red' } else { 'Yellow' }
            Write-Host $logEntry -ForegroundColor $color
        }
    }
    catch {
        Write-Warning "Failed to write log: $($_.Exception.Message)"
    }
}

function Get-AppLog {
    <#
    .SYNOPSIS
        Read recent log entries
    .PARAMETER Lines
        Number of lines to read (default: 100)
    .PARAMETER Level
        Filter by log level
    .PARAMETER Component
        Filter by component
    .PARAMETER Date
        Date to read logs from (default: today)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$Lines = 100,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Debug','Verbose','Info','Warning','Error')]
        [string]$Level,
        
        [Parameter(Mandatory = $false)]
        [string]$Component,
        
        [Parameter(Mandatory = $false)]
        [DateTime]$Date = (Get-Date)
    )
    
    if (-not $script:LogInitialized) {
        Write-Warning "Logger not initialized"
        return
    }
    
    $logFile = Join-Path $script:LogPath "app_$($Date.ToString('yyyy-MM-dd')).log"
    
    if (-not (Test-Path $logFile)) {
        Write-Warning "Log file not found: $logFile"
        return
    }
    
    # Read log file
    $entries = Get-Content $logFile -Tail $Lines
    
    # Filter by level if specified
    if ($Level) {
        $entries = $entries | Where-Object { $_ -match "\[$Level\]" }
    }
    
    # Filter by component if specified
    if ($Component) {
        $entries = $entries | Where-Object { $_ -match "\[$Component\]" }
    }
    
    return $entries
}

function Clear-AppLog {
    <#
    .SYNOPSIS
        Archive and clear old log files
    .PARAMETER OlderThanDays
        Delete logs older than this many days (default: 30)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$OlderThanDays = 30
    )
    
    if (-not $script:LogInitialized) {
        Write-Warning "Logger not initialized"
        return
    }
    
    try {
        $cutoffDate = (Get-Date).AddDays(-$OlderThanDays)
        $logFiles = Get-ChildItem -Path $script:LogPath -Filter "*.log" | 
            Where-Object { $_.LastWriteTime -lt $cutoffDate }
        
        foreach ($file in $logFiles) {
            Remove-Item $file.FullName -Force
            Write-AppLog "Deleted old log file: $($file.Name)" -Level Info -Component "Logger"
        }
        
        Write-AppLog "Cleared $($logFiles.Count) old log file(s)" -Level Info -Component "Logger"
    }
    catch {
        Write-Warning "Failed to clear logs: $($_.Exception.Message)"
    }
}

function Invoke-LogRotation {
    <#
    .SYNOPSIS
        Rotate log files if they exceed size limit
    #>
    [CmdletBinding()]
    param()
    
    try {
        $logFiles = Get-ChildItem -Path $script:LogPath -Filter "*.log" | 
            Where-Object { ($_.Length / 1MB) -gt $script:MaxLogSizeMB }
        
        foreach ($file in $logFiles) {
            # Create rotated filename
            $rotatedName = $file.BaseName + "_" + (Get-Date -Format 'yyyyMMdd_HHmmss') + $file.Extension
            $rotatedPath = Join-Path $script:LogPath $rotatedName
            
            # Rename current log
            Rename-Item $file.FullName $rotatedPath -Force
        }
        
        # Clean up old rotated logs (keep only MaxLogFiles)
        $allLogs = Get-ChildItem -Path $script:LogPath -Filter "*.log" | 
            Sort-Object LastWriteTime -Descending
        
        if ($allLogs.Count -gt $script:MaxLogFiles) {
            $logsToDelete = $allLogs | Select-Object -Skip $script:MaxLogFiles
            foreach ($log in $logsToDelete) {
                Remove-Item $log.FullName -Force
            }
        }
    }
    catch {
        Write-Warning "Failed to rotate logs: $($_.Exception.Message)"
    }
}

function Close-Logger {
    <#
    .SYNOPSIS
        Close the logger and perform cleanup
    #>
    [CmdletBinding()]
    param()
    
    if ($script:LogInitialized) {
        Write-AppLog "Logger closing" -Level Info -Component "Logger"
        $script:LogInitialized = $false
    }
}

# Export functions
Export-ModuleMember -Function Initialize-Logger, Write-AppLog, Get-AppLog, Clear-AppLog, Close-Logger
