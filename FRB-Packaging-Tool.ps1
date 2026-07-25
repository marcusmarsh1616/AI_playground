#Requires -Version 5.1

#Requires -Version 5.1

# Python/Playwright moved to AuthenticationModule


<#
.SYNOPSIS
    FRB Packaging Tool - Main Application
.DESCRIPTION
    Creates folder structure and updates PowerShell Studio project with App details
    using a modular engine-based architecture for maximum maintainability.
.PARAMETER SkipSplash
    Skips the splash screen display (used for relaunches)
.NOTES
    Author: FRB Automation Team
    Created: June 4, 2026
    Version: 5.0.0 - Okta Integration & MSI Enhancement Edition
    Architecture: Modular Engine-Based
    
    Previous Version: v3.2.0 (Custom Commands Edition)
    
.CHANGELOG
    v5.0.0 - July 6, 2026
      - MAJOR: GitLab/Okta authentication integration for Master Template downloads
      - MAJOR: MSI metadata extraction now works identically to EXE files
      - Enhancement: Python/Playwright prerequisites bundled for network deployment
      - Enhancement: First-run automatic Python installation from prereq folder
      - Enhancement: MSI files now show all controls (switches, uninstall executable, Find Switches button)
      - Fix: MSI detection engine integration
      - Architecture: Fully portable with embedded prerequisites
    v3.1.0 - January 23, 2025
      - Enhancement 1: Manual entry only with "Copy Search Terms" helper button
      - Enhancement 2: PathEngine integration for portable folder selection
      - Enhancement 3: DeploymentEngine integration for network deployment
      - Removed Auto-Search/WebSearch (unreliable in production)
      - Added Settings menu for folder and network management
      - Added status bar showing packaging folder and network status
      - Clean rebuild from v3.0.0 - no legacy code
    v3.0.0 - June 11, 2026
      - Integrated InstallValidationTool workflow
      - Added testing and validation engines
      - Complete automated packaging and testing workflow
#>

param(
    [switch]$SkipSplash
)

# Hide PowerShell console window
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'

$consolePtr = [Console.Window]::GetConsoleWindow()
[Console.Window]::ShowWindow($consolePtr, 0) | Out-Null

#region Development Error Logging
# DEVELOPMENT MODE - Set to $false for production
$script:DevelopmentMode = $false

if ($script:DevelopmentMode) {
        # Set up error logging
    $script:ErrorLogPath = Join-Path $PSScriptRoot "logs\error_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $script:TranscriptPath = Join-Path $PSScriptRoot "logs\transcript_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    
    # Ensure logs folder exists
    $logsFolder = Split-Path $script:ErrorLogPath -Parent
    if (-not (Test-Path $logsFolder)) {
        New-Item -Path $logsFolder -ItemType Directory -Force | Out-Null
    }
    
    # Start transcript logging
    Start-Transcript -Path $script:TranscriptPath -Append
    
    # Function to log errors
    function Write-ErrorLog {
        param(
            [string]$Message,
            [string]$ErrorRecord = "",
            [string]$StackTrace = ""
        )
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] ERROR: $Message"
        
        if ($ErrorRecord) {
            $logEntry += "`n  ErrorRecord: $ErrorRecord"
        }
        
        if ($StackTrace) {
            $logEntry += "`n  StackTrace:`n$StackTrace"
        }
        
        $logEntry += "`n" + ("-" * 80) + "`n"
        
        # Write to error log file
        Add-Content -Path $script:ErrorLogPath -Value $logEntry -Encoding UTF8
        
        # Also write to console
        Write-Host $logEntry -ForegroundColor Red
    }
    
    # Set global error action preference
    $ErrorActionPreference = "Continue"
    
    # Log script start
    $startMessage = "FRB Package Creation Tool v2.0.0 - Development Mode`nStarted: $(Get-Date)`nScript: $PSCommandPath`nUser: $env:USERNAME`nComputer: $env:COMPUTERNAME"
    Add-Content -Path $script:ErrorLogPath -Value $startMessage -Encoding UTF8
    Add-Content -Path $script:ErrorLogPath -Value ("=" * 80 + "`n") -Encoding UTF8
    
    Write-Host "`n[DEVELOPMENT MODE] Error logging enabled" -ForegroundColor Yellow
    Write-Host "  Error Log: $script:ErrorLogPath" -ForegroundColor Gray
    Write-Host "  Transcript: $script:TranscriptPath`n" -ForegroundColor Gray
}
#endregion Development Error Logging

# Import required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# GUI State Persistence Variables for test workflow
$script:SavedVendor = ""
$script:SavedName = ""
$script:SavedEdition = ""
$script:SavedVersion = ""
$script:SavedInstallSwitch = ""
$script:SavedUninstallSwitch = ""
$script:SavedUninstallExecutable = ""
$script:SelectedInstallContext = "System"
$script:ContextRecommendation = @{}
$script:PackageHelperControls = @{}
$script:PackageHelperData = $null
$script:CodeEditorToolTip = $null

#region Configuration

# ========================================
# CRITICAL: DO NOT MOVE THIS SECTION!
# See: session_management/SPLASH_SCREEN_FLOW.md
# ========================================

# STANDALONE MODE: Load config from script location (script is now in root folder)
$script:ToolRoot = $PSScriptRoot  # Script is in root directory
$configPath = Join-Path $script:ToolRoot "config\app.config.json"

# Variables to control splash screen display based on config
$script:ShouldShowSplash = -not $SkipSplash
$script:FirstRunCompleted = $false

if (Test-Path $configPath) {
    try {
        $appConfig = Get-Content $configPath -Raw | ConvertFrom-Json
        $script:MasterTemplatePath = $appConfig.paths.masterTemplatePath
        $script:BasePackagingPath = if ($appConfig.paths.basePackagingPath) { $appConfig.paths.basePackagingPath } else { "" }
        $script:ProjectFileName = $appConfig.paths.projectFileName
        $script:PowerShellStudioExe = $appConfig.paths.powerShellStudioExe
        $script:OpenInPSStudio = $appConfig.settings.openInPowerShellStudio
        
        # Check first-run status
        if ($appConfig.settings.PSObject.Properties.Name -contains 'firstRunCompleted') {
            $script:FirstRunCompleted = $appConfig.settings.firstRunCompleted
        }
        
        # Configuration loaded successfully
    }
    catch {
        Write-Warning "Failed to load configuration, using defaults"
        # Fallback to defaults
        $script:MasterTemplatePath = "C:\Temp\Packaging folders\Master Template"
        $script:BasePackagingPath = ""
        $script:ProjectFileName = "Startup.pss"
        $script:PowerShellStudioExe = "C:\Program Files\SAPIEN Technologies, Inc\PowerShell Studio 2026\PowerShell Studio.exe"
        $script:OpenInPSStudio = $false
    }
}
else {
        # No config found - will use PathEngine for first-run setup
    $script:MasterTemplatePath = "C:\Temp\Packaging folders\Master Template"
    $script:BasePackagingPath = ""
    $script:ProjectFileName = "Startup.pss"
    $script:PowerShellStudioExe = "C:\Program Files\SAPIEN Technologies, Inc\PowerShell Studio 2026\PowerShell Studio.exe"
    $script:OpenInPSStudio = $false
}

# Script state variables
$script:InstallationMediaPath = ""
$script:DetectedInstallerType = ""
$script:LastCreatedPackagePath = ""

#endregion Configuration

#region Splash Screen Function

function Show-SplashScreen {
    param(
        [System.Windows.Forms.Form]$SplashForm,
        [System.Windows.Forms.Label]$StatusLabel,
        [string]$Message
    )
    
    if ($SplashForm -and $StatusLabel) {
        $StatusLabel.Text = $Message
        $SplashForm.Refresh()
        [System.Windows.Forms.Application]::DoEvents()
    }
}

#endregion Splash Screen Function

#region Prerequisite Detection

function Get-PrerequisiteDetectionStatus {
    $status = @{
        PowerShellStudio2026Found = $false
        VSCodeFound = $false
        PowerShell7Found = $false
        Python3Found = $false
        PlaywrightFound = $false
        PythonPlaywrightInstalled = $false
        LastChecked = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }

    try {
        $studioExe = "C:\Program Files\SAPIEN Technologies, Inc\PowerShell Studio 2026\PowerShell Studio.exe"
        $sapienCmd = "C:\Program Files\SAPIEN Technologies, Inc\PowerShell Studio 2026\SAPIENCommandLine.exe"
        $status.PowerShellStudio2026Found = (Test-Path $studioExe) -and (Test-Path $sapienCmd)
    } catch {
    }

    try {
        $vsCodePaths = @(
            "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
            "$env:ProgramFiles\Microsoft VS Code\Code.exe",
            "${env:ProgramFiles(x86)}\Microsoft VS Code\Code.exe"
        )
        $status.VSCodeFound = ($vsCodePaths | Where-Object { Test-Path $_ } | Measure-Object).Count -gt 0
    } catch {
    }

    try {
        $status.PowerShell7Found = [bool](Get-Command pwsh.exe -ErrorAction SilentlyContinue)
    } catch {
    }

    $pythonExec = $null
    try {
        $pythonCmd = Get-Command python.exe -ErrorAction SilentlyContinue
        if ($pythonCmd) {
            $pythonExec = $pythonCmd.Source
            $pythonOutput = (& $pythonExec --version 2>&1 | Select-Object -First 1).ToString().Trim()
            if ($pythonOutput -match '^Python\s+(\d+)\.') {
                $status.Python3Found = ([int]$matches[1] -ge 3)
            }
        }
    } catch {
    }

    if (-not $status.Python3Found) {
        try {
            $pyCmd = Get-Command py.exe -ErrorAction SilentlyContinue
            if ($pyCmd) {
                $pythonExec = $pyCmd.Source
                $pythonOutput = (& $pythonExec -3 --version 2>&1 | Select-Object -First 1).ToString().Trim()
                if ($pythonOutput -match '^Python\s+(\d+)\.') {
                    $status.Python3Found = ([int]$matches[1] -ge 3)
                }
            }
        } catch {
        }
    }

    try {
        if ($status.Python3Found -and $pythonExec) {
            if ($pythonExec -like '*py.exe') {
                & $pythonExec -3 -c "import playwright" 2>$null
            } else {
                & $pythonExec -c "import playwright" 2>$null
            }

            if ($LASTEXITCODE -eq 0) {
                $status.PlaywrightFound = $true
            }
        }

        if (-not $status.PlaywrightFound) {
            $playwrightCache = Join-Path $env:LOCALAPPDATA "ms-playwright"
            if (Test-Path $playwrightCache) {
                $status.PlaywrightFound = (Get-ChildItem -Path $playwrightCache -Force -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0
            }
        }
    } catch {
    }

    $status.PythonPlaywrightInstalled = $status.Python3Found -and $status.PlaywrightFound
    return $status
}

function Update-PrerequisiteStatusInConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [string]$TechnicianPackagingFolder = ""
    )

    try {
        if (-not (Test-Path $ConfigPath)) {
            return @{ Success = $false; Message = "Config file not found" }
        }

        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        $prereq = Get-PrerequisiteDetectionStatus

        # Remove deprecated sections/fields.
        if ($config.PSObject.Properties.Name -contains 'gitlab') {
            $config.PSObject.Properties.Remove('gitlab')
        }
        if ($config.settings.PSObject.Properties.Name -contains 'setupCompletedDate') {
            $config.settings.PSObject.Properties.Remove('setupCompletedDate')
        }

        if (-not ($config.settings.PSObject.Properties.Name -contains 'prerequisites')) {
            $config.settings | Add-Member -NotePropertyName 'prerequisites' -NotePropertyValue ([PSCustomObject]@{}) -Force
        }

        $config.settings.prerequisites | Add-Member -NotePropertyName 'powerShellStudio2026Found' -NotePropertyValue $prereq.PowerShellStudio2026Found -Force
        $config.settings.prerequisites | Add-Member -NotePropertyName 'vsCodeFound' -NotePropertyValue $prereq.VSCodeFound -Force
        $config.settings.prerequisites | Add-Member -NotePropertyName 'powerShell7Found' -NotePropertyValue $prereq.PowerShell7Found -Force
        $config.settings.prerequisites | Add-Member -NotePropertyName 'python3Found' -NotePropertyValue $prereq.Python3Found -Force
        $config.settings.prerequisites | Add-Member -NotePropertyName 'playwrightFound' -NotePropertyValue $prereq.PlaywrightFound -Force
        $config.settings.prerequisites | Add-Member -NotePropertyName 'lastChecked' -NotePropertyValue $prereq.LastChecked -Force
        $config.settings.pythonPlaywrightInstalled = $prereq.PythonPlaywrightInstalled

        # Enforce deployment defaults.
        if (-not ($config.PSObject.Properties.Name -contains 'deployment')) {
            $config | Add-Member -NotePropertyName 'deployment' -NotePropertyValue ([PSCustomObject]@{}) -Force
        }
        $config.deployment.networkSharePath = "\\rb.win.frb.org\k1\shared\DSC_Pkgs\Pkgxfer"
        $config.deployment.overwriteExisting = $true

        if (-not ($config.PSObject.Properties.Name -contains 'launcher')) {
            $config | Add-Member -NotePropertyName 'launcher' -NotePropertyValue ([PSCustomObject]@{}) -Force
        }

        if (-not [string]::IsNullOrWhiteSpace($TechnicianPackagingFolder)) {
            $config.launcher | Add-Member -NotePropertyName 'technicianPackagingFolder' -NotePropertyValue $TechnicianPackagingFolder -Force
        }

        $config | ConvertTo-Json -Depth 12 | Set-Content $ConfigPath -Encoding UTF8 -Force
        return @{ Success = $true; Message = "Prerequisite status updated" }
    }
    catch {
        return @{ Success = $false; Message = $_.Exception.Message }
    }
}

#endregion Prerequisite Detection

#region Engine Imports

# Import all engine modules (use $script:ToolRoot for portability)
$enginePath = Join-Path $script:ToolRoot "src\Engines"

# List of engines to load
$enginesToLoad = @(
    @{ Name = "MetadataEngine"; Path = "MetadataEngine\MetadataEngine.psm1" },
    @{ Name = "DetectionEngine"; Path = "DetectionEngine\DetectionEngine.psm1" },
    @{ Name = "SwitchEngine"; Path = "SwitchEngine\SwitchEngine.psm1" },
    @{ Name = "UninstallEngine"; Path = "UninstallEngine\UninstallEngine.psm1" },
    @{ Name = "ValidationEngine"; Path = "ValidationEngine\ValidationEngine.psm1" },
    @{ Name = "FolderEngine"; Path = "FolderEngine\FolderEngine.psm1" },
    @{ Name = "ProcessEngine"; Path = "ProcessEngine\ProcessEngine.psm1" },
    @{ Name = "BuildEngine"; Path = "BuildEngine\BuildEngine.psm1" },
    @{ Name = "ScanEngine"; Path = "ScanEngine\ScanEngine.psm1" },
    @{ Name = "ReportEngine"; Path = "ReportEngine\ReportEngine.psm1" },
    @{ Name = "InstallTestEngine"; Path = "InstallTestEngine\InstallTestEngine.psm1" },
    @{ Name = "ValidationReportEngine"; Path = "ValidationReportEngine\ValidationReportEngine.psm1" },
    @{ Name = "PathEngine"; Path = "PathEngine\PathEngine.psm1" },
    @{ Name = "DeploymentEngine"; Path = "DeploymentEngine\DeploymentEngine.psm1" },
    @{ Name = "CustomCommandsEngine"; Path = "CustomCommandsEngine\CustomCommandsEngine.psm1" }
)

# Create splash screen form
$splash = New-Object System.Windows.Forms.Form
$splash.FormBorderStyle = 'None'
$splash.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
$splash.Size = New-Object System.Drawing.Size(500, 300)
$splash.StartPosition = 'CenterScreen'
$splash.TopMost = $true

# Add logo/title
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "FRB Packaging Tool"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.Color]::White
$lblTitle.AutoSize = $false
$lblTitle.TextAlign = 'MiddleCenter'
$lblTitle.Location = New-Object System.Drawing.Point(0, 60)
$lblTitle.Size = New-Object System.Drawing.Size(500, 50)
$splash.Controls.Add($lblTitle)

# Add version
$lblVersion = New-Object System.Windows.Forms.Label
$lblVersion.Text = "Version 5.0.0"
$lblVersion.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$lblVersion.ForeColor = [System.Drawing.Color]::LightGray
$lblVersion.AutoSize = $false
$lblVersion.TextAlign = 'MiddleCenter'
$lblVersion.Location = New-Object System.Drawing.Point(0, 115)
$lblVersion.Size = New-Object System.Drawing.Size(500, 20)
$splash.Controls.Add($lblVersion)

# Add status label
$lblSplashStatus = New-Object System.Windows.Forms.Label
$lblSplashStatus.Text = "Initializing..."
$lblSplashStatus.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$lblSplashStatus.ForeColor = [System.Drawing.Color]::FromArgb(0, 122, 204)
$lblSplashStatus.AutoSize = $false
$lblSplashStatus.TextAlign = 'MiddleCenter'
$lblSplashStatus.Location = New-Object System.Drawing.Point(0, 180)
$lblSplashStatus.Size = New-Object System.Drawing.Size(500, 30)
$splash.Controls.Add($lblSplashStatus)

# Add progress label
$lblProgress = New-Object System.Windows.Forms.Label
$lblProgress.Text = ""
$lblProgress.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblProgress.ForeColor = [System.Drawing.Color]::Gray
$lblProgress.AutoSize = $false
$lblProgress.TextAlign = 'MiddleCenter'
$lblProgress.Location = New-Object System.Drawing.Point(0, 215)
$lblProgress.Size = New-Object System.Drawing.Size(500, 20)
$splash.Controls.Add($lblProgress)

# Show splash screen based on config logic (determined above)
if ($script:ShouldShowSplash) {
    $splash.Show()
    $splash.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
}

try {
    # Track progress
    $totalEngines = $enginesToLoad.Count
    $currentEngine = 0
    
        if ($script:ShouldShowSplash) {
        Show-SplashScreen -SplashForm $splash -StatusLabel $lblSplashStatus -Message "Loading engines..."
        Start-Sleep -Milliseconds 500
    }
    
                foreach ($engine in $enginesToLoad) {
        $currentEngine++
        
        # Update splash screen
        if ($script:ShouldShowSplash) {
            Show-SplashScreen -SplashForm $splash -StatusLabel $lblSplashStatus -Message "Loading $($engine.Name)..."
            $lblProgress.Text = "[$currentEngine/$totalEngines]"
            $splash.Refresh()
            [System.Windows.Forms.Application]::DoEvents()
        }
        
        # Load the engine
        $modulePath = Join-Path $enginePath $engine.Path
        Import-Module $modulePath -Force -ErrorAction Stop
        
        if ($script:ShouldShowSplash) {
            Start-Sleep -Milliseconds 100
        }
    }
    
        # Show completion
    if ($script:ShouldShowSplash) {
        Show-SplashScreen -SplashForm $splash -StatusLabel $lblSplashStatus -Message "All engines loaded successfully!"
        $lblSplashStatus.ForeColor = [System.Drawing.Color]::FromArgb(16, 185, 129)
        $splash.Refresh()
        Start-Sleep -Milliseconds 800
    }
    
        Write-Verbose "All engines loaded successfully"
    
}
catch {
    # Close splash screen if error occurs
    if ($splash) {
        $splash.Close()
        $splash.Dispose()
    }
    
    # Log to error log if development mode is enabled
    if ($script:DevelopmentMode -and (Test-Path Function:\Write-ErrorLog)) {
        Write-ErrorLog -Message "Failed to load engine modules" `
                       -ErrorRecord $_.Exception.Message `
                       -StackTrace $_.ScriptStackTrace
    }
    
    [System.Windows.Forms.MessageBox]::Show(
        "Failed to load required engine modules.`n`nError: $($_.Exception.Message)`n`nPlease ensure all engine files are present in the src\Engines folder.",
        "Engine Load Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    
    exit 1
}
finally {
    # Close and dispose splash screen
    if ($splash) {
        $splash.Close()
        $splash.Dispose()
    }
}

#endregion Engine Imports

#region First-Time Setup and Master Template Check

# ========================================
# CRITICAL SECTION ORDER - DO NOT CHANGE!
# Order: 1. First-run detection, 2. Template check/token dialog, 3. Show GUI
# ========================================

#region Step 1: First-Run Packaging Folder Initialization
# Check if first-time setup has been completed on this PC
$configPath = Join-Path $script:ToolRoot "config\app.config.json"

if (Test-Path $configPath) {
    try {
        # Check if first run has been completed
        $firstRunResult = Test-FirstRunComplete -ConfigPath $configPath
        
        if (-not $firstRunResult.Completed) {
            # First run on this PC - copy tool and setup packaging folder
            [System.Windows.Forms.MessageBox]::Show(
                "Welcome to FRB Packaging Tool!`n`nThis tool will be copied to your selected folder.`nEach technician gets their own personal copy with individual settings.`n`nClick OK to select your packaging folder.",
                "First-Time Setup",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
            
            $folderResult = Show-FolderBrowserDialog -Description "Select your packaging folder (tool will be copied here)" -SelectedPath "C:\"
            
            if ($folderResult.Success) {
                $toolFolderName = "FRB-Packaging-Tool"
                $destinationToolPath = Join-Path $folderResult.Path $toolFolderName
                
                try {
                    if (Test-Path $destinationToolPath) {
                        $overwriteMessage = @(
                            "Tool already exists at: $destinationToolPath",
                            "",
                            "Overwrite?"
                        ) -join [Environment]::NewLine
                        $overwriteResponse = [System.Windows.Forms.MessageBox]::Show(
                            $overwriteMessage,
                            "Overwrite?",
                            [System.Windows.Forms.MessageBoxButtons]::YesNo,
                            [System.Windows.Forms.MessageBoxIcon]::Question
                        )
                        
                        if ($overwriteResponse -ne [System.Windows.Forms.DialogResult]::Yes) {
                            [System.Windows.Forms.MessageBox]::Show("Setup cancelled.", "Cancelled", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                            exit 0
                        }
                        
                        Remove-Item -Path $destinationToolPath -Recurse -Force -ErrorAction Stop
                    }
                    
                    # Copy only needed folders and files.
                    $srcPath = Join-Path $script:ToolRoot "src"
                    $configDir = Join-Path $script:ToolRoot "config"
                    $mainScript = Join-Path $script:ToolRoot "FRB-Packaging-Tool.ps1"
                    $sourceMasterTemplatePath = Join-Path $script:ToolRoot "Master Template"
                    $destinationMasterTemplatePath = Join-Path $folderResult.Path "Master Template"
                    
                    Copy-Item -Path $srcPath -Destination (Join-Path $destinationToolPath "src") -Recurse -Force -ErrorAction Stop
                    Copy-Item -Path $configDir -Destination (Join-Path $destinationToolPath "config") -Recurse -Force -ErrorAction Stop
                    Copy-Item -Path $mainScript -Destination (Join-Path $destinationToolPath "FRB-Packaging-Tool.ps1") -Force -ErrorAction Stop

                    if (-not (Test-Path $sourceMasterTemplatePath)) {
                        throw "Master Template not found at source path: $sourceMasterTemplatePath"
                    }

                    if (Test-Path $destinationMasterTemplatePath) {
                        Remove-Item -Path $destinationMasterTemplatePath -Recurse -Force -ErrorAction Stop
                    }

                    Copy-Item -Path $sourceMasterTemplatePath -Destination $destinationMasterTemplatePath -Recurse -Force -ErrorAction Stop
                    
                    $newConfigPath = Join-Path $destinationToolPath "config\app.config.json"
                    
                    if (Test-Path $newConfigPath) {
                        $setPathResult = Set-PackagingPath -ConfigPath $newConfigPath -PackagingPath $folderResult.Path
                        
                        if ($setPathResult.Success) {
                            $initResult = Initialize-PackagingFolder -PackagingPath $folderResult.Path
                            
                            if ($initResult.Success) {
                                # Mark complete ONLY in the new local copy - NOT the network share copy
                                # This ensures each technician sees the first-run dialog
                                $markCompleteResult = Set-FirstRunComplete -ConfigPath $newConfigPath
                                
                                if ($markCompleteResult.Success) {
                                    $newToolScriptPath = Join-Path $destinationToolPath "FRB-Packaging-Tool.ps1"

                                    # Persist local runtime settings for this technician.
                                    $updateConfigResult = Update-PrerequisiteStatusInConfig -ConfigPath $newConfigPath -TechnicianPackagingFolder $folderResult.Path
                                    if (-not $updateConfigResult.Success) {
                                        Write-Warning "Config update warning: $($updateConfigResult.Message)"
                                    }

                                    $newConfig = Get-Content $newConfigPath -Raw | ConvertFrom-Json
                                    $newConfig.paths.masterTemplatePath = $destinationMasterTemplatePath
                                    $newConfig.paths.basePackagingPath = $folderResult.Path
                                    $newConfig.paths.basePackagingPathConfigured = $true
                                    $newConfig | ConvertTo-Json -Depth 12 | Set-Content $newConfigPath -Encoding UTF8 -Force
                                    
                                    # Create Start Menu shortcut to local copy
                                    try {
                                        $WshShell = New-Object -ComObject WScript.Shell
                                        $StartMenuPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
                                        $ShortcutPath = Join-Path $StartMenuPath "FRB Packaging Tool.lnk"
                                        $ShortcutIconPath = Join-Path $destinationToolPath "config\pf_logo.ico"
                                        $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
                                        $Shortcut.TargetPath = "powershell.exe"
                                        $Shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$newToolScriptPath`""
                                        $Shortcut.WorkingDirectory = $destinationToolPath
                                        $Shortcut.IconLocation = "$ShortcutIconPath,0"
                                        $Shortcut.Description = "FRB Packaging Tool"
                                        $Shortcut.Save()
                                        Write-Verbose "Start Menu shortcut created: $ShortcutPath"
                                    } catch {
                                        Write-Warning "Failed to create Start Menu shortcut: $($_.Exception.Message)"
                                    }
                                    
                                    [System.Windows.Forms.MessageBox]::Show(
                                        "Setup Complete!`n`nTool copied to:`n$destinationToolPath`n`nYour packaging folder:`n$($folderResult.Path)`n`nA Start Menu shortcut has been created.`n`nThe tool will now continue loading from your local copy.",
                                        "Setup Complete",
                                        [System.Windows.Forms.MessageBoxButtons]::OK,
                                        [System.Windows.Forms.MessageBoxIcon]::Information
                                    )
                                    
                                    Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$newToolScriptPath`""
                                    exit 0
                                    
                                }
                            }
                        } else {
                            throw "Config update failed: $($setPathResult.Message)"
                        }
                    } else {
                        throw "Config file not found"
                    }
                }
                catch {
                    [System.Windows.Forms.MessageBox]::Show("Copy failed: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                    exit 1
                }
            } else {
                [System.Windows.Forms.MessageBox]::Show("Setup cancelled - no folder selected.", "Cancelled", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                exit 0
            }
        }
    } catch {
        # Silently continue if first run check fails
        Write-Verbose "PathEngine first-run check failed: $($_.Exception.Message)"
    }
}
#endregion Step 1: First-Run Packaging Folder Initialization

#region Step 1.5: Prerequisite Detection and Local Template Validation
if (Test-Path $configPath) {
    $prereqUpdateResult = Update-PrerequisiteStatusInConfig -ConfigPath $configPath -TechnicianPackagingFolder $script:BasePackagingPath
    if (-not $prereqUpdateResult.Success) {
        Write-Warning "Prerequisite detection warning: $($prereqUpdateResult.Message)"
    }
}

if (-not [string]::IsNullOrWhiteSpace($script:BasePackagingPath)) {
    $script:MasterTemplatePath = Join-Path $script:BasePackagingPath "Master Template"
}

if ([string]::IsNullOrWhiteSpace($script:MasterTemplatePath) -or -not (Test-Path $script:MasterTemplatePath)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Master Template was not found in the technician packaging folder.`n`nExpected path:`n$script:MasterTemplatePath`n`nPlease rerun first-time setup or copy Master Template to the packaging folder.",
        "Master Template Missing",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}
#endregion Step 1.5: Prerequisite Detection and Local Template Validation

#endregion First-Time Setup and Master Template Check


#region Helper Functions

# Function to update status
function Update-Status {
    param([string]$Message, [string]$Color = "Blue")
    $lblStatus.Text = $Message
    $lblStatus.ForeColor = [System.Drawing.Color]::$Color
    $form.Refresh()
}

# Function to update the Startup.pss file
function Update-StartupFile {
    param(
        [string]$StartupPath,
        [string]$Vendor,
        [string]$Name,
        [string]$Version,
        [string]$MediaFileName = "",
        [string]$MediaExtension = "",
        [string]$UninstallExeName = "",
        [string]$InstallSwitch = "",
        [string]$UninstallSwitch = ""
    ,
        [string]$RequiredProcesses = ""
    )
    
    try {
        if (-not (Test-Path $StartupPath)) {
            throw "Startup.pss file not found: $StartupPath"
        }
        
        # Read the Startup.pss file content  
        $content = Get-Content -Path $StartupPath -Raw -Encoding UTF8

        # Get current Windows username and date
        # Try to resolve user's full name via ADSI (Active Directory)
        try {
            $objUser = [ADSI]("WinNT://$env:USERDOMAIN/$env:USERNAME,user")
            $currentUser = if (-not [string]::IsNullOrWhiteSpace($objUser.FullName)) {
                $objUser.FullName[0]
            } else {
                $env:USERNAME  # Fallback to username if FullName is empty
            }
        } catch {
            # Fallback to username if ADSI fails (workgroup/standalone)
            $currentUser = $env:USERNAME
        }
        $currentDate = Get-Date -Format "yyyy-MM-dd"
        
        # Update variables in the VARIABLE DECLARATION section
        $lines = $content -split "`r?`n"
                $inVarDeclaration = $false
        $vendorUpdated = $false
        $nameUpdated = $false
        $nameMaskUpdated = $false
        $versionUpdated = $false
        $installerExeUpdated = $false
        $msiNameUpdated = $false
        $uninstallExeUpdated = $false
        $installCmdUpdated = $false
        $uninstallCmdUpdated = $false
        $scriptAuthorUpdated = $false
        $scriptDateUpdated = $false
        $scriptBuildVersionUpdated = $false
        $stopProcessesUpdated = $false
        
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '##\*\s*VARIABLE DECLARATION') {
                $inVarDeclaration = $true
            }
            elseif ($lines[$i] -match '##\*\s*END VARIABLE DECLARATION') {
                $inVarDeclaration = $false
            }
            
            if ($inVarDeclaration) {
                # Update appVendor
                if (-not $vendorUpdated -and $lines[$i] -match '^\s*\[string\]\$appVendor\s*=\s*[\x27\x22].*?[\x27\x22]\s*$') {
                    $lines[$i] = "`t[string]`$appVendor = '$Vendor'"
                    $vendorUpdated = $true
                }
                                # Update appName
                elseif (-not $nameUpdated -and $lines[$i] -match '^\s*\[string\]\$appName\s*=\s*[\x27\x22].*?[\x27\x22]\s*$') {
                    $lines[$i] = "`t[string]`$appName = '$Name'"
                    $nameUpdated = $true
                }
                # Update appNameMask
                elseif (-not $nameMaskUpdated -and $lines[$i] -match '^\s*\[string\]\$appNameMask\s*=\s*[\x27\x22].*?[\x27\x22]') {
                    $lines[$i] = "`t[string]`$appNameMask = '$Name'"
                    $nameMaskUpdated = $true
                }
                # Update appVersion
                elseif (-not $versionUpdated -and $lines[$i] -match '^\s*\[string\]\$appVersion\s*=\s*[\x27\x22].*?[\x27\x22]\s*$') {
                    $lines[$i] = "`t[string]`$appVersion = '$Version'"
                    $versionUpdated = $true
                }
                # Update appInstallerExeName if media is EXE
                elseif (-not $installerExeUpdated -and $lines[$i] -match '^\s*\[string\]\$appInstallerExeName\s*=\s*[\x27\x22].*?[\x27\x22]\s*$') {
                    if ($MediaExtension -eq ".exe") {
                        $lines[$i] = "`t[string]`$appInstallerExeName = '$MediaFileName'"
                    }
                    $installerExeUpdated = $true
                }

                # Update appMsiName if media is MSI
                elseif (-not $msiNameUpdated -and $lines[$i] -match '^\s*\[string\]\$appMsiName\s*=\s*[\x27\x22].*?[\x27\x22]\s*$') {
                    if ($MediaExtension -eq ".msi") {
                        $lines[$i] = "`t[string]`$appMsiName = '$MediaFileName'"
                    }
                    $msiNameUpdated = $true
                }
                                # Update appInstallCommandLine - ALWAYS update (use GUI as source of truth)
                elseif (-not $installCmdUpdated -and $lines[$i] -match '^\s*\[string\]\$appInstallCommandLine\s*=\s*[\x27\x22].*?[\x27\x22]') {
                    # If GUI field has content, use it; if blank, clear it
                    if (-not [string]::IsNullOrWhiteSpace($InstallSwitch)) {
                        $lines[$i] = "`t[string]`$appInstallCommandLine = '$InstallSwitch'"
                    } else {
                        $lines[$i] = "`t[string]`$appInstallCommandLine = ''"
                    }
                    $installCmdUpdated = $true
				}
				
				# Update appUninstallCommandLine - ALWAYS update (use GUI as source of truth)
				elseif (-not $uninstallCmdUpdated -and $lines[$i] -match '^\s*\[string\]\$appUninstallCommandLine\s*=\s*[\x27\x22].*?[\x27\x22]')
				{
                    # If GUI field has content, use it; if blank, clear it
					if (-not [string]::IsNullOrWhiteSpace($UninstallSwitch))
					{
						$lines[$i] = "`t[string]`$appUninstallCommandLine = '$UninstallSwitch'"
					} else {
                        $lines[$i] = "`t[string]`$appUninstallCommandLine = ''"
                    }
					$uninstallCmdUpdated = $true
				}
				
								# Update appUninstallExeName - ALWAYS update (use GUI as source of truth)
                elseif (-not $uninstallExeUpdated -and $lines[$i] -match '^\s*\[string\]\$appUninstallExeName\s*=\s*[\x27\x22].*?[\x27\x22]\s*$') {
                    # If GUI field has content, use it; if blank, clear it
                    if ($MediaExtension -eq ".exe" -and -not [string]::IsNullOrWhiteSpace($UninstallExeName)) {
                        $lines[$i] = "`t[string]`$appUninstallExeName = '$UninstallExeName'"
                    } else {
                        $lines[$i] = "`t[string]`$appUninstallExeName = ''"
                    }
                    $uninstallExeUpdated = $true
                }
                # ENHANCEMENT 1: appScriptAuthor
                elseif (-not $scriptAuthorUpdated -and $lines[$i] -match '^\s*\[string\]\$appScriptAuthor\s*=\s*[\x27\x22].*?[\x27\x22]') {
                    $lines[$i] = "`t[string]`$appScriptAuthor = '$currentUser'"
                    $scriptAuthorUpdated = $true
                }
                # ENHANCEMENT 2: appScriptBuildVersion
                elseif (-not $scriptBuildVersionUpdated -and $lines[$i] -match '^\s*\[version\]\$appScriptBuildVersion\s*=\s*[\x27\x22](.*?)[\x27\x22]') {
                    $existingVersion = $matches[1]
                    if (-not [string]::IsNullOrWhiteSpace($existingVersion) -and $existingVersion -ne '0.0.0') {
                        try {
                            $versionObj = [version]$existingVersion
                            $newVersion = "{0}.{1}.{2}" -f $versionObj.Major, $versionObj.Minor, ($versionObj.Build + 1)
                        } catch { $newVersion = "1.0.1" }
                    } else { $newVersion = "1.0.1" }
                    $lines[$i] = "`t[version]`$appScriptBuildVersion = '$newVersion'"
                    $scriptBuildVersionUpdated = $true
                }
                                # ENHANCEMENT 3: appStopRequiredProcesses - leave as empty string
                # User can manually populate this in Startup.pss if needed
                elseif (-not $stopProcessesUpdated -and $lines[$i] -match '^\s*\[string\]\$appStopRequiredProcesses\s*=\s*[\x27\x22].*?[\x27\x22]') {
                    # Always leave empty - don't auto-populate
                    $stopProcessesUpdated = $true
                }
            }
        }
        
        $content = $lines -join "`r`n"
        
        # Write the updated content back
        Set-Content -Path $StartupPath -Value $content -Encoding UTF8 -Force
        
        $statusMsg = "Startup.pss updated!"
        if ($MediaExtension -eq ".exe") {
            $statusMsg += " (EXE + switches)"
        } elseif ($MediaExtension -eq ".msi") {
            $statusMsg += " (MSI)"
        }
        Update-Status $statusMsg "Green"
    }
    catch {
        throw "Failed to update Startup.pss file: $($_.Exception.Message)"
    }
}

# Function to create folder structure using FolderEngine
function New-PackagingFolder {
    param(
        [string]$Vendor,
        [string]$Name,
        [string]$Edition,
        [string]$Version
    )
    
    try {
        $progressBar.Value = 10
        Update-Status "Creating folder structure..."
        
        # Create the new folder path
        $newFolderPath = Join-Path $script:BasePackagingPath $Vendor
        $newFolderPath = Join-Path $newFolderPath $Name
        if (-not [string]::IsNullOrWhiteSpace($Edition)) {
            $newFolderPath = Join-Path $newFolderPath $Edition
        }
        $newFolderPath = Join-Path $newFolderPath $Version
        
        # Check if folder already exists - UPDATE MODE
        $folderExists = Test-Path $newFolderPath
        
        if ($folderExists) {
            # UPDATE MODE: Folder exists, only update Startup.pss
            Update-Status "Package exists - updating Startup.pss with new settings..." "Orange"
            $progressBar.Value = 20
            
            # Skip to Startup.pss update (jump to line ~350)
            $progressBar.Value = 80
        } else {
            # CREATE MODE: New package, create full folder structure
            Update-Status "Creating new package..." "Blue"
            $progressBar.Value = 30
        
        # Use FolderEngine to create folder structure
        $progressBar.Value = 30
        Update-Status "Using FolderEngine to create structure..."
        
        $folderResult = New-PackagingFolderStructure -BasePath $script:BasePackagingPath `
                                                      -Vendor $Vendor `
                                                      -ProductName $Name `
                                                      -Edition $Edition `
                                                      -Version $Version `
                                                      -OverwriteIfExists $true
        
        if (-not $folderResult.Success) {
            throw $folderResult.Message
        }
        
        $newFolderPath = $folderResult.FolderPath
        $progressBar.Value = 40
        Update-Status "Folder created: $newFolderPath"


        # Use FolderEngine to copy template files
        $progressBar.Value = 50
        Update-Status "Copying template files..."
        
        $copyResult = Copy-TemplateFiles -TemplatePath $script:MasterTemplatePath `
                                         -DestinationPath $newFolderPath
        
        if (-not $copyResult.Success) {
            throw $copyResult.Message
        }
        $progressBar.Value = 70
        Update-Status "Template files copied: $($copyResult.FilesCopied) files"
        
        # Copy installation media if provided using FolderEngine
        if (-not [string]::IsNullOrWhiteSpace($script:InstallationMediaPath) -and (Test-Path $script:InstallationMediaPath)) {
            $progressBar.Value = 75
            Update-Status "Copying installation media..."
            
            $mediaResult = Copy-InstallerToPackage -InstallerPath $script:InstallationMediaPath `
                                                    -PackagePath $newFolderPath
            
            if (-not $mediaResult.Success) {
                throw $mediaResult.Message
            }
            
            Update-Status "Installation media copied to Data folder"
        }
        
        $progressBar.Value = 80
        Update-Status "Files copied successfully. Updating Startup.pss file..."
        }  # End of CREATE MODE
        
        # Update Startup.pss file
        $startupPath = Join-Path $newFolderPath $script:ProjectFileName
        
        if (Test-Path $startupPath) {
            $mediaFileName = if (-not [string]::IsNullOrWhiteSpace($script:InstallationMediaPath)) {
                [System.IO.Path]::GetFileName($script:InstallationMediaPath)
            } else { "" }
            
            $mediaExtension = if ($mediaFileName) {
                [System.IO.Path]::GetExtension($script:InstallationMediaPath).ToLower()
            } else { "" }
            
                        # Get switches from manual text boxes (v3.1: Manual-only mode)
            $installSwitch = $txtInstallSwitch.Text
            $uninstallSwitch = $txtUninstallSwitch.Text
            $uninstallExeName = $txtUninstallExecutable.Text
            

                        # Process detection removed - leave $appStopRequiredProcesses as empty string
            # User can manually populate this in Startup.pss if needed

            Update-StartupFile -StartupPath $startupPath `
                              -Vendor $Vendor `
                              -Name $Name `
                              -Version $Version `
                              -MediaFileName $mediaFileName `
                              -MediaExtension $mediaExtension `
                              -UninstallMediaFileName "" `
                              -UninstallExeName $uninstallExeName `
                              -InstallSwitch $installSwitch `
                              -UninstallSwitch $uninstallSwitch `
                              -RequiredProcesses ""
        } else {
            throw "Startup.pss file not found: $startupPath"
        }
        
        # Insert custom commands if any provided (v3.2 CustomCommandsEngine integration)
        # Always process custom commands (v3.2 CustomCommandsEngine - FIXED 2026-07-23)
        # This ensures GUI is source of truth for BOTH adding AND removing commands
        $commandSections = @{
            PreInstall = $txtPreInstall.Text
            CustomInstall = $txtCustomInstall.Text
            PostInstall = $txtPostInstall.Text
            PreUninstall = $txtPreUninstall.Text
            CustomUninstall = $txtCustomUninstall.Text
            PostUninstall = $txtPostUninstall.Text
        }
        
        Update-Status "Updating custom commands in Startup.pss..." "Blue"
        $form.Refresh()
        
        try {
            $insertResult = Add-CustomCommandsToStartupPss -StartupPssPath $startupPath -CommandSections $commandSections
            
            if ($insertResult.Success) {
                if ($insertResult.InsertedSections.Count -gt 0) {
                    Update-Status "Custom commands updated: $($insertResult.InsertedSections.Count) section(s)" "Green"
                } else {
                    Update-Status "Custom commands cleared (no sections provided)" "Green"
                }
            } else {
                Write-Warning "Custom commands update failed: $($insertResult.Message)"
            }
        }
        catch {
            Write-Warning "Error updating custom commands: $($_.Exception.Message)"
        }
        $progressBar.Value = 95
        Update-Status "Package created! Verifying files..." "Blue"
        
        # Store package path
        $script:LastCreatedPackagePath = $newFolderPath
        
        # Wait for file system to complete all operations
        Start-Sleep -Milliseconds 1000
        
        # Verify the BUILD project file exists before enabling Build button
        $projectFilePath = Find-ProjectFile -PackagePath $newFolderPath
        $maxWaitTime = 5  # Wait up to 5 seconds
        $waitInterval = 0.2
        $elapsed = 0
        
        while ([string]::IsNullOrWhiteSpace($projectFilePath) -and $elapsed -lt $maxWaitTime) {
            Start-Sleep -Milliseconds ($waitInterval * 1000)
            $elapsed += $waitInterval
            Update-Status "Waiting for project file... ($([math]::Round($elapsed, 1))s)" "Orange"
            $form.Refresh()
            $projectFilePath = Find-ProjectFile -PackagePath $newFolderPath
        }
        
        $progressBar.Value = 100
        
        if (-not [string]::IsNullOrWhiteSpace($projectFilePath) -and (Test-Path $projectFilePath)) {
            Update-Status "Package created successfully!`n$newFolderPath" "Green"
            Update-Status "FRB Installer.psproj verified!" "Green"
            
                        # Build workflow will start automatically after package creation
            
            # Start build/test/deploy workflow
            Start-BuildTestDeployWorkflow -PackagePath $newFolderPath `
                                          -Form $form `
                                          -ProgressBar $progressBar `
                                          -CreateButton $btnCreate `
                                          -CancelButton $btnCancel `
                                          -VendorTextBox $txtVendor `
                                          -NameTextBox $txtName `
                                          -VersionTextBox $txtVersion `
                                          -InstallSwitchTextBox $txtInstallSwitch `
                                          -UninstallSwitchTextBox $txtUninstallSwitch `
                                          -UninstallExecutableTextBox $txtUninstallExecutable `
                                          -ConfigPath $configPath
            
            # Open Startup.pss in PowerShell Studio for review if enabled
            if ($script:OpenInPSStudio -and (Test-Path $script:PowerShellStudioExe)) {
                Update-Status "Opening project in PowerShell Studio..." "Blue"
                $form.Refresh()
                Start-Process -FilePath $script:PowerShellStudioExe -ArgumentList "`"$startupFileToReview`""
                Start-Sleep -Milliseconds 500
                Update-Status "Package created successfully!`n$newFolderPath" "Green"
            }
        } else {
                        Update-Status "Warning: FRB Installer.psproj not found after $maxWaitTime seconds." "Orange"
        }
        
        return $true
    }
    catch {
        $progressBar.Value = 0
        $errorMsg = "Error: $($_.Exception.Message)"
        Update-Status $errorMsg "Red"
        
        # Show error banner with reason
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to create package!`n`nReason: $($_.Exception.Message)`n`nPlease check:`n- Master Template exists`n- Paths are accessible`n- No files are locked",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return $false
    }
}

function Start-BuildTestDeployWorkflow {
    param(
        [string]$PackagePath,
        [System.Windows.Forms.Form]$Form,
        [System.Windows.Forms.ProgressBar]$ProgressBar,
        [System.Windows.Forms.Button]$CreateButton,
        [System.Windows.Forms.Button]$CancelButton,
        [System.Windows.Forms.TextBox]$VendorTextBox,
        [System.Windows.Forms.TextBox]$NameTextBox,
        [System.Windows.Forms.TextBox]$VersionTextBox,
        [System.Windows.Forms.TextBox]$InstallSwitchTextBox,
        [System.Windows.Forms.TextBox]$UninstallSwitchTextBox,
        [System.Windows.Forms.TextBox]$UninstallExecutableTextBox,
        [string]$ConfigPath
    )
    
    # Store package path in script scope for workflow to access
    $script:LastCreatedPackagePath = $PackagePath
    
# AUTO-CONTINUE: Build and test workflow
    if ([string]::IsNullOrWhiteSpace($script:LastCreatedPackagePath)) {
        [System.Windows.Forms.MessageBox]::Show(
            "No package has been created yet. Please create a package first.",
            "No Package",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    
    $btnCreate.Enabled = $false
    $btnCancel.Enabled = $false
    $progressBar.Value = 0
    
    Update-Status "Locating FRB Installer.psproj file..." "Blue"
    $form.Refresh()
    
    $projPath = Find-ProjectFile -PackagePath $script:LastCreatedPackagePath
    
    if ([string]::IsNullOrWhiteSpace($projPath)) {
        Update-Status "ERROR: FRB Installer.psproj not found" "Red"
        [System.Windows.Forms.MessageBox]::Show(
            "Could not locate FRB Installer.psproj in:`n$($script:LastCreatedPackagePath)`n`nExpected: SAPIEN Technologies, Inc\PowerShell Studio 2026\...\FRB Installer.psproj",
            "Project File Not Found",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        $btnCreate.Enabled = $true
    $btnCreate.Visible = $true
    $btnCancel.Enabled = $true
    $btnCancel.Visible = $true
        return
    }
    
    $progressBar.Value = 20
    Update-Status "Found: FRB Installer.psproj`nStarting PSBuild.exe..." "Blue"
    $form.Refresh()
    
    $psbuildCheck = Test-SAPIENBuildAvailable
    if (-not $psbuildCheck.Available) {
        Update-Status "ERROR: PSBuild.exe not found" "Red"
        [System.Windows.Forms.MessageBox]::Show(
            "PSBuild.exe not found at:`n$($psbuildCheck.Path)`n`nPlease ensure PowerShell Studio 2026 is installed.",
            "PSBuild Not Found",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        $btnCreate.Enabled = $true
    $btnCreate.Visible = $true
    $btnCancel.Enabled = $true
    $btnCancel.Visible = $true
        return
    }
    
    $progressBar.Value = 40

    # USER CONTEXT: Modify files BEFORE building if checkbox is checked
    if ($chkUserContext.Checked) {
        Update-Status "User Context enabled - Modifying Startup.pss and .psbuild..." "Blue"
        $form.Refresh()

        # Modify Startup.pss - Change installContext from System to User
        $startupPath = Join-Path $script:LastCreatedPackagePath "Startup.pss"
        if (Test-Path $startupPath) {
            $startupContent = Get-Content $startupPath -Raw -Encoding UTF8
            $startupContent = $startupContent -replace "installContext = 'System'", "installContext = 'User'"
            Set-Content -Path $startupPath -Value $startupContent -Encoding UTF8 -Force
            Write-Verbose "Startup.pss: installContext set to User"
        }

        # Modify .psbuild - Change ManifestType from 2 to 1
        $psbuildPath = $projPath + ".psbuild"
        if (Test-Path $psbuildPath) {
            $psbuildContent = Get-Content $psbuildPath -Raw -Encoding Unicode
            $psbuildContent = $psbuildContent -replace "ManifestType\s*=\s*\d+", "ManifestType = 3"
            Set-Content -Path $psbuildPath -Value $psbuildContent -Encoding Unicode -Force
            Write-Verbose ".psbuild: ManifestType set to 3 (embed default manifest - no elevation)"
        }

        Update-Status "User Context modifications complete. Building..." "Green"
        $form.Refresh()
    } else {
        # System Context (DEFAULT): Set for elevated installation
        Update-Status "System Context (elevated) - Modifying Startup.pss and .psbuild..." "Blue"
        $form.Refresh()
        
        # Modify Startup.pss - Ensure installContext is System
        $startupPath = Join-Path $script:LastCreatedPackagePath "Startup.pss"
        if (Test-Path $startupPath) {
            $startupContent = Get-Content $startupPath -Raw -Encoding UTF8
            $startupContent = $startupContent -replace "installContext = 'User'", "installContext = 'System'"
            Set-Content -Path $startupPath -Value $startupContent -Encoding UTF8 -Force
            Write-Verbose "Startup.pss: installContext set to System"
        }
        
        # Modify .psbuild - Set ManifestType to 2 (requireAdministrator)
        $psbuildPath = $projPath + ".psbuild"
        if (Test-Path $psbuildPath) {
            $psbuildContent = Get-Content $psbuildPath -Raw -Encoding Unicode
            $psbuildContent = $psbuildContent -replace "ManifestType\s*=\s*\d+", "ManifestType = 2"
            Set-Content -Path $psbuildPath -Value $psbuildContent -Encoding Unicode -Force
            Write-Verbose ".psbuild: ManifestType set to 2 (requireAdministrator)"
        }
        
        Update-Status "System Context modifications complete. Building..." "Green"
        $form.Refresh()
    }

    Update-Status "Building Install.exe...`nThis may take a minute..." "Blue"
    $form.Refresh()
    
    $buildResult = Invoke-ProjectBuild -ProjectPath $projPath
    
    $progressBar.Value = 60
    
    if (-not $buildResult.Success) {
        Update-Status "BUILD FAILED!`n`n$($buildResult.Message)" "Red"
        $btnCreate.Enabled = $true
    $btnCreate.Visible = $true
    $btnCancel.Enabled = $true
    $btnCancel.Visible = $true
        
        $response = [System.Windows.Forms.MessageBox]::Show(
            "$($buildResult.Message)`n`nWould you like to view the detailed build log?",
            "Build Failed",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        
        if ($response -eq [System.Windows.Forms.DialogResult]::Yes) {
            $logForm = New-Object System.Windows.Forms.Form
            $logForm.Text = "Build Log"
            $logForm.Size = New-Object System.Drawing.Size(800, 600)
            $logForm.StartPosition = "CenterParent"
            
            $logTextBox = New-Object System.Windows.Forms.TextBox
            $logTextBox.Multiline = $true
            $logTextBox.ScrollBars = "Both"
            $logTextBox.Dock = "Fill"
            $logTextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
            $logTextBox.Text = $buildResult.BuildLog
            $logTextBox.ReadOnly = $true
            
            $logForm.Controls.Add($logTextBox)
            [void]$logForm.ShowDialog()
        }
        return
    }
    
    # BUILD SUCCESS - Begin Integrated Testing Workflow
    Update-Status "BUILD SUCCESS! Starting installation testing workflow..." "Green"
    $form.Refresh()
    $progressBar.Value = 70
    
        # Save current GUI state for potential loops (v3.1: Manual-only mode)
    $script:SavedVendor = $txtVendor.Text
    $script:SavedName = $txtName.Text
    $script:SavedEdition = $txtEdition.Text
    $script:SavedVersion = $txtVersion.Text
    $script:SavedInstallSwitch = $txtInstallSwitch.Text
    $script:SavedUninstallSwitch = $txtUninstallSwitch.Text
    $script:SavedUninstallExecutable = $txtUninstallExecutable.Text
    
    # Find Install.exe in build output
    Update-Status "Locating Install.exe in build output..." "Blue"
    $form.Refresh()
    
    $installExePath = $null
    $searchPaths = @(
        $buildResult.OutputPath,
        (Split-Path $buildResult.OutputPath -Parent),
        $script:LastCreatedPackagePath
    )
    
    foreach ($searchPath in $searchPaths) {
        if (Test-Path $searchPath) {
            $foundExe = Get-ChildItem -Path $searchPath -Filter "Install.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($foundExe) {
                $installExePath = $foundExe.FullName
                break
            }
        }
    }
    
    if (-not $installExePath -or -not (Test-Path $installExePath)) {
        Update-Status "ERROR: Install.exe not found in build output" "Red"
        [System.Windows.Forms.MessageBox]::Show(
            "Install.exe was not found in the expected build output location.`n`nSearched in:`n" + ($searchPaths -join "`n") + "`n`nPlease verify the build completed successfully.",
            "Install.exe Not Found",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        $btnCreate.Enabled = $true
    $btnCreate.Visible = $true
    $btnCancel.Enabled = $true
    $btnCancel.Visible = $true
        return
    }
    
    Update-Status "Found Install.exe at: $installExePath" "Green"
    $form.Refresh()
    $progressBar.Value = 75
    
    # INSTALLATION TESTING LOOP
    :InstallLoop while ($true) {
        Update-Status "Launching Install.exe for installation testing..." "Blue"
        $form.Refresh()
        
        $installTestResult = Start-InstallationTest -InstallExePath $installExePath -AppName $script:SavedName -AppVersion $script:SavedVersion -Vendor $script:SavedVendor
        
                if (-not $installTestResult.Success) {
            Update-Status "Make any changes needed to make your package function in the fashion you would like" "Blue"
            [System.Windows.Forms.MessageBox]::Show(
                "Package design may need to change.`n`nError: $($installTestResult.ErrorMessage)`n`nTechnician has indicated that the installation did not function as designed. You will be returned to the GUI to make any needed changes and try again.",
                "Installation Test Loop",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            
            # Restore GUI state and allow user to modify
            $txtVendor.Text = $script:SavedVendor
            $txtName.Text = $script:SavedName
            $txtVersion.Text = $script:SavedVersion
            
            $btnCreate.Enabled = $true
    $btnCreate.Visible = $true
    $btnCancel.Enabled = $true
    $btnCancel.Visible = $true
            return
        }
        
        # User confirmed installation worked
        if ($installTestResult.UserConfirmed) {
            Update-Status "Installation confirmed successful by technician!" "Green"
            $form.Refresh()

            $docResult = Start-IntegratedValidationDocumentation -PackagePath $script:LastCreatedPackagePath -AppVendor $script:SavedVendor -AppName $script:SavedName -AppEdition $script:SavedEdition -AppVersion $script:SavedVersion
            if (-not $docResult.Success) {
                Update-Status "Validation documentation warning: $($docResult.Message)" "Orange"
                $form.Refresh()
            }
            elseif ($docResult.ReportCopied) {
                Update-Status "Validation documentation report copied to package Docs." "Green"
                $form.Refresh()
            }
            else {
                Update-Status $docResult.Message "Blue"
                $form.Refresh()
            }

            break :InstallLoop
        } else {
            # User said NO - allow modification and retry
            Update-Status "Installation not confirmed. Returning to GUI for modifications..." "Orange"
            $form.Refresh()
            
                        # Restore GUI state (v3.1: Manual-only mode)
            $txtVendor.Text = $script:SavedVendor
            $txtName.Text = $script:SavedName
            $txtVersion.Text = $script:SavedVersion
            $txtInstallSwitch.Text = $script:SavedInstallSwitch
            $txtUninstallSwitch.Text = $script:SavedUninstallSwitch
            $txtUninstallExecutable.Text = $script:SavedUninstallExecutable
            
            [System.Windows.Forms.MessageBox]::Show(
                "Please modify the installation switches or media if needed, then click 'Build EXE' again to retry.",
                "Modify and Retry",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            
            $btnCreate.Enabled = $true
    $btnCreate.Visible = $true
    $btnCancel.Enabled = $true
    $btnCancel.Visible = $true
            return
        }
    }
    
    $progressBar.Value = 80
    
    # Validation documentation now runs from the installation verification YES path.
    
    $progressBar.Value = 85
    
    # Prompt for uninstall
    $uninstallPrompt = [System.Windows.Forms.MessageBox]::Show(
        "Installation validation complete!`n`nReady to test the uninstallation process?",
        "Begin Uninstall Testing",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    
    if ($uninstallPrompt -ne [System.Windows.Forms.DialogResult]::Yes) {
        Update-Status "Uninstallation testing skipped by technician." "Orange"
        $btnCreate.Enabled = $true
    $btnCreate.Visible = $true
    $btnCancel.Enabled = $true
    $btnCancel.Visible = $true
        return
    }
    
    $progressBar.Value = 90
    
    # UNINSTALLATION TESTING LOOP
    :UninstallLoop while ($true) {
        Update-Status "Launching Install.exe /uninstall for uninstallation testing..." "Blue"
        $form.Refresh()
        
        $uninstallTestResult = Start-UninstallationTest -InstallExePath $installExePath -AppName $script:SavedName -AppVersion $script:SavedVersion -Vendor $script:SavedVendor -PackagePath $script:LastCreatedPackagePath
        
                if (-not $uninstallTestResult.Success) {
            Update-Status "Make any changes needed to make your package function in the fashion you would like" "Blue"
            [System.Windows.Forms.MessageBox]::Show(
                "Package design may need to change.`n`nError: $($uninstallTestResult.ErrorMessage)`n`nTechnician has indicated that the uninstallation did not function as designed. You will be returned to the GUI to make any needed changes and try again.",
                "Uninstallation Test Loop",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            
            # Restore GUI state
            $txtVendor.Text = $script:SavedVendor
            $txtName.Text = $script:SavedName
            $txtVersion.Text = $script:SavedVersion
            
            $btnCreate.Enabled = $true
    $btnCreate.Visible = $true
    $btnCancel.Enabled = $true
    $btnCancel.Visible = $true
            return
        }
        
        # User confirmed uninstallation worked
        if ($uninstallTestResult.UserConfirmed) {
            Update-Status "Uninstallation confirmed successful by technician!" "Green"
            $form.Refresh()
            break :UninstallLoop
        } else {
            # User said NO - allow modification and retry
            Update-Status "Uninstallation not confirmed. Returning to GUI for modifications..." "Orange"
            $form.Refresh()
            
                        # Restore GUI state (v3.1: Manual-only mode)
            $txtVendor.Text = $script:SavedVendor
            $txtName.Text = $script:SavedName
            $txtVersion.Text = $script:SavedVersion
            $txtInstallSwitch.Text = $script:SavedInstallSwitch
            $txtUninstallSwitch.Text = $script:SavedUninstallSwitch
            $txtUninstallExecutable.Text = $script:SavedUninstallExecutable
            
            [System.Windows.Forms.MessageBox]::Show(
                "Please modify the uninstall switches or media if needed, then rebuild and retest.",
                "Modify and Retry",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            
            $btnCreate.Enabled = $true
    $btnCreate.Visible = $true
    $btnCancel.Enabled = $true
    $btnCancel.Visible = $true
            return
        }
    }
    
                # FINAL STEP: Deploy to Network Share
        Write-Verbose "Network deployment: Starting final step..."
        Update-Status "Checking network deployment settings..." "Blue"
        $form.Refresh()
        try {
        # Load config to get deployment settings
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        
        if ($config.deployment.autoCopyEnabled) {
            Update-Status "Deploying package to network share..." "Blue"
            $form.Refresh()
            
            $deployResult = Copy-PackageToNetworkShare -PackagePath $script:LastCreatedPackagePath `
                                                           -NetworkSharePath $config.deployment.networkSharePath `
                                                           -Vendor $script:SavedVendor `
                                                           -ProductName $script:SavedName `
                                                            -Edition $script:SavedEdition `
                                                           -Version $script:SavedVersion `
                                                           -OverwriteExisting (-not $config.deployment.createBackupBeforeCopy) `
                                                           -VerifyAfterCopy $config.deployment.verifyAfterCopy `
                                                           -ProgressCallback {
                                                               param($message)
                                                               Update-Status "Network Deployment: $message" "Blue"
                                                               $form.Refresh()
                                                           }
            
            if ($deployResult.Success) {
                Update-Status "Package deployed successfully to network share!" "Green"
                [System.Windows.Forms.MessageBox]::Show(
                    "Package deployed to network share!`n`nLocation: $($deployResult.TargetPath)`n`nFiles: $($deployResult.FilesCopied)`nSize: $($deployResult.SizeMB) MB", 
                    "Deployment Complete",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
            } else {
                Update-Status "Network deployment failed: $($deployResult.Message)" "Red"
                [System.Windows.Forms.MessageBox]::Show(
                    "Failed to deploy to network share!`n`nError: $($deployResult.Message)`n`nPackage remains in local folder.", 
                    "Deployment Failed",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                )
            }
        }
    } catch {
        Write-Verbose "Network deployment error: $($_.Exception.Message)"
    }
    $progressBar.Value = 95
    
    # ALL TESTS PASSED - Show completion message
    Update-Status "All testing complete! Package ready for Intune deployment." "Green"
    $form.Refresh()
    
    Show-CompletionMessage -AppName $script:SavedName -AppVersion $script:SavedVersion
    
    $progressBar.Value = 100
    
        # Clear fields after successful workflow completion (v3.1: Manual-only mode)
    $txtVendor.Clear()
    $txtName.Clear()
    $txtVersion.Clear()
    $txtEdition.Clear()
    $txtMedia.Clear()
    $lblMediaType.Text = ""
    
    # Hide all switch and uninstall executable controls
    $lblUninstallExecutable.Visible = $false
    $lblInstallSwitch.Visible = $false
    $lblUninstallSwitch.Visible = $false
    $txtUninstallExecutable.Visible = $false
    $txtUninstallExecutable.Clear()
    $txtInstallSwitch.Visible = $false
    $txtInstallSwitch.Clear()
    $txtUninstallSwitch.Visible = $false
    $txtUninstallSwitch.Clear()
    
        # Clear and collapse custom command sections (v3.2)
    if ($script:txtPreInstall) { $script:txtPreInstall.Clear() }
    if ($script:txtCustomInstall) { $script:txtCustomInstall.Clear() }
    if ($script:txtPostInstall) { $script:txtPostInstall.Clear() }
    if ($script:txtPreUninstall) { $script:txtPreUninstall.Clear() }
    if ($script:txtCustomUninstall) { $script:txtCustomUninstall.Clear() }
    if ($script:txtPostUninstall) { $script:txtPostUninstall.Clear() }
    
    # Collapse all sections, hide textboxes, and reset to original tight spacing
    foreach ($control in $panel.Controls) {
        if ($control -is [System.Windows.Forms.Label] -and $control.Text -match '\[-\]') {
            # This section is expanded, collapse it
            $control.Text = $control.Text -replace '\[-\]', '[+]'
            if ($control.Tag -and $control.Tag.TextBox) {
                $control.Tag.TextBox.Visible = $false
                $control.Tag.IsExpanded = $false
            }
        }
    }
    
    # Reset all custom command section labels to ORIGINAL tight positions
    $customCmdStartY = 380  # Starting Y position
    $tightSpacing = 25      # Tight collapsed spacing (NOT the 35px used when creating sections)
    $currentY = $customCmdStartY
    
    foreach ($control in $panel.Controls) {
        if ($control -is [System.Windows.Forms.Label] -and 
            ($control.Text -like "*Pre-Installation Commands*" -or
             $control.Text -like "*Custom Installation Commands*" -or
             $control.Text -like "*Post-Installation Commands*" -or
             $control.Text -like "*Pre-Uninstallation Commands*" -or
             $control.Text -like "*Custom Uninstallation Commands*" -or
             $control.Text -like "*Post-Uninstallation Commands*")) {
            # Reset to tight collapsed spacing
            $control.Top = $currentY
            $currentY += $tightSpacing
        }
    }
    
    # Reset status area controls to initial startup positions.
    $lblStatus.Top = 10
    $progressBar.Top = 50
    $btnCreate.Top = 65
    $btnCancel.Top = 65

    # Restore initial launch behavior: Cancel visible, Start Packaging hidden until media is selected.
    $btnCreate.Visible = $false
    $btnCreate.Enabled = $true
    $btnCancel.Visible = $true
    $btnCancel.Enabled = $true
    
    $script:InstallationMediaPath = ""
    $script:DetectedInstallerType = ""
    $progressBar.Value = 0

}

function Start-IntegratedValidationDocumentation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackagePath,

        [Parameter(Mandatory = $true)]
        [string]$AppVendor,

        [Parameter(Mandatory = $true)]
        [string]$AppName,

        [Parameter(Mandatory = $false)]
        [string]$AppEdition,

        [Parameter(Mandatory = $true)]
        [string]$AppVersion
    )

    $result = @{
        Success = $false
        Launched = $false
        ReportCopied = $false
        CopiedReportPath = ""
        Message = ""
    }

    try {
        $result = Start-ValidationReportCapture -PackagePath $PackagePath -AppVendor $AppVendor -AppName $AppName -AppEdition $AppEdition -AppVersion $AppVersion
    }
    catch {
        $result.Message = "Validation documentation integration error: $($_.Exception.Message)"
    }

    return $result
}

function Set-PackageHelperSectionSuggestion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SectionKey,

        [Parameter(Mandatory = $true)]
        [int]$SuggestionIndex,

        [string]$FeedbackText = ""
    )

    if (-not $script:PackageHelperControls.ContainsKey($SectionKey)) {
        return
    }

    $sectionState = $script:PackageHelperControls[$SectionKey]
    if (-not $sectionState -or -not $sectionState.Suggestions -or $sectionState.Suggestions.Count -eq 0) {
        return
    }

    $maxIndex = $sectionState.Suggestions.Count - 1
    if ($SuggestionIndex -lt 0) { $SuggestionIndex = 0 }
    if ($SuggestionIndex -gt $maxIndex) { $SuggestionIndex = $maxIndex }

    $sectionState.CurrentIndex = $SuggestionIndex
    $sectionState.OutputTextBox.Text = $sectionState.Suggestions[$SuggestionIndex]
    $sectionState.IndexLabel.Text = "Suggestion $($SuggestionIndex + 1) of $($sectionState.Suggestions.Count)"

    if (-not [string]::IsNullOrWhiteSpace($FeedbackText)) {
        $sectionState.FeedbackLabel.Text = $FeedbackText
    }

    $script:PackageHelperControls[$SectionKey] = $sectionState
}

function Write-PackageHelperFeedback {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SectionKey,

        [Parameter(Mandatory = $true)]
        [string]$Response,

        [string]$SuggestionText = "",

        [string]$Note = ""
    )

    try {
        $logDir = Join-Path $script:ToolRoot "logs"
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }

        $feedbackPath = Join-Path $logDir "package_helper_feedback.jsonl"
        $feedbackRecord = [ordered]@{
            Timestamp = (Get-Date).ToString("s")
            SectionKey = $SectionKey
            Response = $Response
            Note = $Note
            InstallerType = $script:DetectedInstallerType
            Vendor = $txtVendor.Text
            AppName = $txtName.Text
            Edition = $txtEdition.Text
            Version = $txtVersion.Text
            Suggestion = $SuggestionText
        }

        ($feedbackRecord | ConvertTo-Json -Compress) | Add-Content -Path $feedbackPath -Encoding UTF8
    }
    catch {
        Write-Verbose "Package helper feedback logging failed: $($_.Exception.Message)"
    }
}

function Get-PackageHelperSuggestionValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Snippet,

        [Parameter(Mandatory = $true)]
        [string]$VariableName
    )

    if ([string]::IsNullOrWhiteSpace($Snippet)) {
        return ""
    }

    $escapedVar = [regex]::Escape($VariableName)
    $singlePattern = '(?s)\$' + $escapedVar + '\s*=\s*''([^'']*)'''
    $doublePattern = '(?s)\$' + $escapedVar + '\s*=\s*"([^"]*)"'

    if ($Snippet -match $singlePattern) {
        return $matches[1]
    }
    if ($Snippet -match $doublePattern) {
        return $matches[1]
    }

    return ""
}

function Add-UniqueHelperSnippet {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.TextBox]$TargetTextBox,

        [Parameter(Mandatory = $true)]
        [string]$Snippet
    )

    if ([string]::IsNullOrWhiteSpace($Snippet)) {
        return $false
    }

    $existing = $TargetTextBox.Text
    if (-not [string]::IsNullOrWhiteSpace($existing) -and $existing.Contains($Snippet)) {
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($existing)) {
        $TargetTextBox.Text = Format-CodeEditorText -Text $Snippet.Trim()
    } else {
        $TargetTextBox.Text = Format-CodeEditorText -Text ($existing.TrimEnd() + "`r`n`r`n" + $Snippet.Trim())
    }

    return $true
}

function Format-CodeEditorText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $normalized = $Text -replace "`r`n|`r", "`n"
    $lines = $normalized -split "`n"
    $formattedLines = New-Object System.Collections.Generic.List[string]
    $indentLevel = 0
    $previousBlank = $false

    foreach ($line in $lines) {
        $trimmed = $line.Trim()

        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            if (-not $previousBlank) {
                [void]$formattedLines.Add("")
            }
            $previousBlank = $true
            continue
        }

        $previousBlank = $false
        $leadingClose = $trimmed.StartsWith('}') -or $trimmed.StartsWith(')') -or $trimmed.StartsWith(']')
        if ($leadingClose) {
            $indentLevel = [Math]::Max(0, $indentLevel - 1)
        }

        $indent = ''
        for ($i = 0; $i -lt $indentLevel; $i++) {
            $indent += [char]9
        }

        [void]$formattedLines.Add($indent + $trimmed)

        $openCount = ([regex]::Matches($trimmed, '\{')).Count
        $closeCount = ([regex]::Matches($trimmed, '\}')).Count
        if ($openCount -gt $closeCount) {
            $indentLevel += ($openCount - $closeCount)
        }
        elseif (-not $leadingClose -and $closeCount -gt $openCount) {
            $indentLevel = [Math]::Max(0, $indentLevel - ($closeCount - $openCount))
        }
    }

    return (($formattedLines -join "`r`n").TrimEnd())
}

function Get-CodeEditorActionSummary {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $actions = New-Object System.Collections.Generic.List[string]
    $code = if ([string]::IsNullOrWhiteSpace($Text)) { "" } else { $Text }

    if ($code -match '(?i)Stop-Process|Get-Process') { [void]$actions.Add('Stops or checks running processes to avoid file locks.') }
    if ($code -match '(?i)Remove-Item|Delete|Clear-Item') { [void]$actions.Add('Removes files, folders, or registry paths.') }
    if ($code -match '(?i)Copy-Item|Move-Item') { [void]$actions.Add('Copies or moves files/folders.') }
    if ($code -match '(?i)Set-ItemProperty|New-ItemProperty|Set-Item') { [void]$actions.Add('Writes or updates registry or file-system settings.') }
    if ($code -match '(?i)Start-Process|Invoke-Command') { [void]$actions.Add('Launches another executable or command.') }
    if ($code -match '(?i)Get-Service|Start-Service|Stop-Service') { [void]$actions.Add('Checks or controls Windows services.') }
    if ($code -match '(?i)Test-Path|Get-ChildItem') { [void]$actions.Add('Checks whether files, folders, or keys exist.') }
    if ($code -match '(?i)Write-Log|Write-Verbose') { [void]$actions.Add('Writes status information for troubleshooting.') }
    if ($code -match '(?i)Show-InstallationPrompt|Show-InstallationProgress') { [void]$actions.Add('Shows technician-facing prompts or progress UI.') }

    if ($actions.Count -eq 0) {
        [void]$actions.Add('General PowerShell code block. Review the section description for intent.')
    }

    return ($actions | Select-Object -Unique) -join [Environment]::NewLine
}

function Get-CodeEditorHelpText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SectionTitle,

        [Parameter(Mandatory = $true)]
        [string]$SectionDescription,

        [Parameter(Mandatory = $true)]
        [string]$CodeText
    )

    $summary = Get-CodeEditorActionSummary -Text $CodeText
    return @(
        $SectionTitle,
        "",
        $SectionDescription,
        "",
        "What this code currently appears to do:",
        $summary,
        "",
        "Leave the box to hide this help."
    ) -join [Environment]::NewLine
}

function Show-CodeEditorHelp {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.RichTextBox]$Editor
    )

    if (-not $script:CodeEditorToolTip) { return }
    if (-not $Editor.Tag -or -not $Editor.Tag.HelpTitle) { return }

    $helpText = Get-CodeEditorHelpText -SectionTitle $Editor.Tag.HelpTitle -SectionDescription $Editor.Tag.HelpDescription -CodeText $Editor.Text
    $script:CodeEditorToolTip.Hide($Editor)
    $script:CodeEditorToolTip.Show($helpText, $Editor, 15, $Editor.Height + 8, 12000)
}

function Hide-CodeEditorHelp {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.Control]$Editor
    )

    if ($script:CodeEditorToolTip) {
        $script:CodeEditorToolTip.Hide($Editor)
    }
}

function Register-CodeEditorBehavior {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.RichTextBox]$Editor,

        [Parameter(Mandatory = $true)]
        [string]$HelpTitle,

        [Parameter(Mandatory = $true)]
        [string]$HelpDescription
    )

    $Editor.Tag = @{ HelpTitle = $HelpTitle; HelpDescription = $HelpDescription }
    $Editor.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $Editor.ForeColor = [System.Drawing.Color]::FromArgb(212, 212, 212)
    $Editor.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $Editor.DetectUrls = $false
    $Editor.ShortcutsEnabled = $true
    $Editor.HideSelection = $false
    $Editor.WordWrap = $false
    $Editor.Font = $FontCode

    $Editor.Add_MouseEnter({ Show-CodeEditorHelp -Editor $this })
    $Editor.Add_MouseHover({ Show-CodeEditorHelp -Editor $this })
    $Editor.Add_Leave({
        Hide-CodeEditorHelp -Editor $this
        if (-not [string]::IsNullOrWhiteSpace($this.Text)) {
            $formatted = Format-CodeEditorText -Text $this.Text
            if ($formatted -ne $this.Text) {
                $this.Text = $formatted
                $this.SelectionStart = $this.TextLength
                $this.ScrollToCaret()
            }
        }
    })
}

function Apply-PackageHelperSectionToGui {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SectionKey,

        [string]$SnippetOverride = ""
    )

    if (-not $script:PackageHelperControls.ContainsKey($SectionKey)) {
        return $false
    }

    $state = $script:PackageHelperControls[$SectionKey]
    $snippet = if (-not [string]::IsNullOrWhiteSpace($SnippetOverride)) { $SnippetOverride } else { $state.OutputTextBox.Text }
    if ([string]::IsNullOrWhiteSpace($snippet)) {
        return $false
    }

    $applied = $false
    switch ($SectionKey) {
        "InstallCommand" {
            $value = Get-PackageHelperSuggestionValue -Snippet $snippet -VariableName "appInstallCommandLine"
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                $txtInstallSwitch.Text = $value
                $applied = $true
            }
        }
        "UninstallCommand" {
            $value = Get-PackageHelperSuggestionValue -Snippet $snippet -VariableName "appUninstallCommandLine"
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                $txtUninstallSwitch.Text = $value
                $applied = $true
            }
        }
        "UninstallExecutable" {
            $value = Get-PackageHelperSuggestionValue -Snippet $snippet -VariableName "appUninstallExeName"
            if ($value -ne $null) {
                $txtUninstallExecutable.Text = $value
                $applied = $true
            }
        }
        "PreInstallChecks" {
            $applied = Add-UniqueHelperSnippet -TargetTextBox $txtPreInstall -Snippet $snippet
        }
        "Prerequisites" {
            $applied = Add-UniqueHelperSnippet -TargetTextBox $txtPreInstall -Snippet $snippet
        }
    }

    if ($applied) {
        $state.FeedbackLabel.Text = "Applied to GUI"
        $script:PackageHelperControls[$SectionKey] = $state
    }

    return $applied
}

function Apply-AllPackageHelperSuggestionsToGui {
    $applyOrder = @("InstallCommand", "UninstallCommand", "UninstallExecutable", "PreInstallChecks", "Prerequisites")
    $appliedCount = 0

    foreach ($sectionKey in $applyOrder) {
        if (Apply-PackageHelperSectionToGui -SectionKey $sectionKey) {
            $appliedCount++
        }
    }

    if ($script:lblPackageHelperContext) {
        $script:lblPackageHelperContext.Text = "Applied $appliedCount section(s) into package fields and command areas."
        $script:lblPackageHelperContext.ForeColor = [System.Drawing.Color]::FromArgb(0, 110, 0)
    }

    return $appliedCount
}

function Set-PackageHelperTabContent {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$HelperData
    )

    $script:PackageHelperData = $HelperData

    foreach ($sectionKey in $script:PackageHelperControls.Keys) {
        $sectionState = $script:PackageHelperControls[$sectionKey]
        if ($HelperData.Sections.Contains($sectionKey)) {
            $section = $HelperData.Sections[$sectionKey]
            $sectionState.Group.Text = $section.Title
            $sectionState.SummaryLabel.Text = $section.Summary
            $sectionState.Suggestions = @($section.Suggestions)
            $sectionState.CurrentIndex = 0
            $sectionState.FeedbackLabel.Text = "Did this help?"

            if ($sectionState.Suggestions.Count -eq 0) {
                $sectionState.OutputTextBox.Text = "No suggestions available for this section."
                $sectionState.IndexLabel.Text = "Suggestion 0 of 0"
            } else {
                Set-PackageHelperSectionSuggestion -SectionKey $sectionKey -SuggestionIndex 0
            }
        } else {
            $sectionState.Group.Text = $sectionState.DefaultTitle
            $sectionState.SummaryLabel.Text = "No data generated for this section yet."
            $sectionState.OutputTextBox.Text = ""
            $sectionState.IndexLabel.Text = "Suggestion 0 of 0"
            $sectionState.FeedbackLabel.Text = "Did this help?"
            $sectionState.Suggestions = @()
            $sectionState.CurrentIndex = 0
        }

        $script:PackageHelperControls[$sectionKey] = $sectionState
    }

    if ($script:lblPackageHelperContext -and $HelperData.Context) {
        $contextLine = "Package Helper ready for: {0} | Installer: {1} | Context: {2} | Preset: {3}" -f $HelperData.Context.ProductDisplayName, $HelperData.Context.InstallerType, $HelperData.Context.InstallContext, $HelperData.Context.Preset
        $script:lblPackageHelperContext.Text = $contextLine
        $script:lblPackageHelperContext.ForeColor = [System.Drawing.Color]::FromArgb(0, 110, 0)
    }
}

function Invoke-PackageHelperGeneration {
    if ([string]::IsNullOrWhiteSpace($txtVendor.Text) -or [string]::IsNullOrWhiteSpace($txtName.Text)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please enter at least App Vendor and App Name first.",
            "Package Helper",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        return
    }

    if ([string]::IsNullOrWhiteSpace($script:DetectedInstallerType)) {
        $script:DetectedInstallerType = "Generic"
    }

    try {
        $helperData = Get-PackageHelpSections -InstallerType $script:DetectedInstallerType `
                                              -Vendor $txtVendor.Text.Trim() `
                                              -AppName $txtName.Text.Trim() `
                                              -Edition $txtEdition.Text.Trim() `
                                              -Version $txtVersion.Text.Trim() `
                                              -InstallMediaPath $script:InstallationMediaPath `
                                              -CurrentInstallSwitch $txtInstallSwitch.Text.Trim() `
                                              -CurrentUninstallSwitch $txtUninstallSwitch.Text.Trim() `
                                              -CurrentUninstallExecutable $txtUninstallExecutable.Text.Trim() `
                                              -InstallContext $script:SelectedInstallContext `
                                              -ContextRecommendation $script:ContextRecommendation

        Set-PackageHelperTabContent -HelperData $helperData
        $tabControl.SelectedTab = $tabPackageHelper
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to generate package helper suggestions.`n`n$($_.Exception.Message)",
            "Package Helper Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

function Set-InstallContextState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Context,

        [string]$Reason = ""
    )

    $normalized = if ($Context -eq "User") { "User" } else { "System" }
    $script:SelectedInstallContext = $normalized

    if ($script:chkUserContext) {
        $script:chkUserContext.Checked = ($normalized -eq "User")
    }

    if ($script:lblPackageHelperContext) {
        $suffix = ""
        if (-not [string]::IsNullOrWhiteSpace($Reason)) {
            $suffix = " | $Reason"
        }
        $script:lblPackageHelperContext.Text = "Install context selected: $normalized$suffix"
        $script:lblPackageHelperContext.ForeColor = [System.Drawing.Color]::FromArgb(0, 110, 0)
    }
}

function Invoke-InstallContextDetectionPrompt {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string]$InstallerType
    )

    $script:ContextRecommendation = @{}

    try {
        $contextResult = Get-InstallContextRecommendation -FilePath $FilePath -InstallerType $InstallerType
        if ($contextResult) {
            $script:ContextRecommendation = $contextResult
        }

        if (-not $contextResult -or -not $contextResult.Success) {
            Set-InstallContextState -Context "System" -Reason "Detection unavailable"
            return
        }

        $recommended = if ($contextResult.Recommendation -eq "User") { "User" } else { "System" }
        $alternate = if ($recommended -eq "User") { "System" } else { "User" }
        $reasons = if ($contextResult.Reasons -and $contextResult.Reasons.Count -gt 0) {
            ($contextResult.Reasons | ForEach-Object { "- $_" }) -join [Environment]::NewLine
        } else {
            "- No strong signals were detected."
        }

        $message = @(
            "Context detection complete for selected install media.",
            "",
            "Recommended: $recommended ($($contextResult.Confidence) confidence)",
            "",
            "Reasons:",
            $reasons,
            "",
            "Choose context:",
            "Yes = Use recommended ($recommended)",
            "No = Use alternate ($alternate)",
            "Cancel = Keep current context ($script:SelectedInstallContext)"
        ) -join [Environment]::NewLine

        $response = [System.Windows.Forms.MessageBox]::Show(
            $message,
            "Install Context Selection",
            [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )

        if ($response -eq [System.Windows.Forms.DialogResult]::Yes) {
            Set-InstallContextState -Context $recommended -Reason "Recommended by detection"
        }
        elseif ($response -eq [System.Windows.Forms.DialogResult]::No) {
            Set-InstallContextState -Context $alternate -Reason "Technician override"
        }
        else {
            Set-InstallContextState -Context $script:SelectedInstallContext -Reason "Technician kept existing selection"
        }
    }
    catch {
        Set-InstallContextState -Context "System" -Reason "Detection error"
        Write-Warning "Install context detection failed: $($_.Exception.Message)"
    }
}


#endregion Helper Functions

#region GUI Creation

# Create the main form

#region GUI Creation

# Form creation with modern layout
$form = New-Object System.Windows.Forms.Form
$form.Text = "FRB Packaging Tool v5.0.0"
$form.Size = New-Object System.Drawing.Size(920, 900)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "Sizable"
$form.MaximizeBox = $true
$form.MinimizeBox = $true
$form.AutoScroll = $true
$form.Icon = New-Object System.Drawing.Icon("$script:ToolRoot\config\pf_logo.ico")
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

# Color palette
$Colors = @{
    Background = [System.Drawing.Color]::FromArgb(245, 245, 245)
    GroupBackground = [System.Drawing.Color]::White
    AccentTeal = [System.Drawing.Color]::FromArgb(0, 139, 139)
    SuccessGreen = [System.Drawing.Color]::FromArgb(45, 125, 45)
    WarningYellow = [System.Drawing.Color]::FromArgb(201, 168, 0)
    TextDark = [System.Drawing.Color]::FromArgb(51, 51, 51)
}
$FontCode = New-Object System.Drawing.Font("Consolas", 10)
$script:CodeEditorToolTip = New-Object System.Windows.Forms.ToolTip
$script:CodeEditorToolTip.IsBalloon = $true
$script:CodeEditorToolTip.ShowAlways = $true
$script:CodeEditorToolTip.AutoPopDelay = 12000
$script:CodeEditorToolTip.InitialDelay = 250
$script:CodeEditorToolTip.ReshowDelay = 75
$script:CodeEditorToolTip.ToolTipTitle = "Code Help"
$script:CodeEditorToolTip.BackColor = [System.Drawing.Color]::FromArgb(255, 255, 245)
$script:CodeEditorToolTip.ForeColor = [System.Drawing.Color]::FromArgb(40, 40, 40)

# TabControl creation# TabControl creation
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(20, 40)
$tabControl.Size = New-Object System.Drawing.Size(860, 670)
$tabControl.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($tabControl)

#region Tab 1: Main Settings
$tabMain = New-Object System.Windows.Forms.TabPage
$tabMain.Text = "Main Settings"
$tabMain.BackColor = $Colors.Background
$tabControl.Controls.Add($tabMain)

# Metadata GroupBox
$grpMetadata = New-Object System.Windows.Forms.GroupBox
$grpMetadata.Text = "Package Metadata"
$grpMetadata.Location = New-Object System.Drawing.Point(20, 20)
$grpMetadata.Size = New-Object System.Drawing.Size(800, 350)
$grpMetadata.BackColor = $Colors.GroupBackground
$tabMain.Controls.Add($grpMetadata)

# Install Media controls
$lblMedia = New-Object System.Windows.Forms.Label
$lblMedia.Text = "Install Media: *"
$lblMedia.Location = New-Object System.Drawing.Point(20, 30)
$lblMedia.Size = New-Object System.Drawing.Size(150, 20)
$grpMetadata.Controls.Add($lblMedia)

$txtMedia = New-Object System.Windows.Forms.TextBox
$txtMedia.Location = New-Object System.Drawing.Point(180, 28)
$txtMedia.Size = New-Object System.Drawing.Size(520, 25)
$txtMedia.ReadOnly = $true
$grpMetadata.Controls.Add($txtMedia)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Browse..."
$btnBrowse.Location = New-Object System.Drawing.Point(710, 26)
$btnBrowse.Size = New-Object System.Drawing.Size(70, 28)
$btnBrowse.BackColor = $Colors.AccentTeal
$btnBrowse.ForeColor = [System.Drawing.Color]::White
$btnBrowse.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnBrowse.FlatAppearance.BorderSize = 0
$grpMetadata.Controls.Add($btnBrowse)

# Media Type label
$lblMediaType = New-Object System.Windows.Forms.Label
$lblMediaType.Text = ""
$lblMediaType.Location = New-Object System.Drawing.Point(180, 58)
$lblMediaType.Size = New-Object System.Drawing.Size(600, 20)
$lblMediaType.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Italic)
$lblMediaType.ForeColor = [System.Drawing.Color]::Gray
$grpMetadata.Controls.Add($lblMediaType)

# Uninstall Media
$lblUninstallExecutable = New-Object System.Windows.Forms.Label
$lblUninstallExecutable.Text = "Uninstall Media:"
$lblUninstallExecutable.Location = New-Object System.Drawing.Point(20, 90)
$lblUninstallExecutable.Size = New-Object System.Drawing.Size(150, 20)
$lblUninstallExecutable.Visible = $false
$grpMetadata.Controls.Add($lblUninstallExecutable)

$txtUninstallExecutable = New-Object System.Windows.Forms.TextBox
$txtUninstallExecutable.Location = New-Object System.Drawing.Point(180, 88)
$txtUninstallExecutable.Size = New-Object System.Drawing.Size(600, 25)
$txtUninstallExecutable.Visible = $false
$grpMetadata.Controls.Add($txtUninstallExecutable)

# Vendor
$lblVendor = New-Object System.Windows.Forms.Label
$lblVendor.Text = "App Vendor: *"
$lblVendor.Location = New-Object System.Drawing.Point(20, 130)
$lblVendor.Size = New-Object System.Drawing.Size(150, 20)
$grpMetadata.Controls.Add($lblVendor)

$txtVendor = New-Object System.Windows.Forms.TextBox
$txtVendor.Location = New-Object System.Drawing.Point(180, 128)
$txtVendor.Size = New-Object System.Drawing.Size(600, 25)
$grpMetadata.Controls.Add($txtVendor)

# App Name
$lblName = New-Object System.Windows.Forms.Label
$lblName.Text = "App Name: *"
$lblName.Location = New-Object System.Drawing.Point(20, 170)
$lblName.Size = New-Object System.Drawing.Size(150, 20)
$grpMetadata.Controls.Add($lblName)

$txtName = New-Object System.Windows.Forms.TextBox
$txtName.Location = New-Object System.Drawing.Point(180, 168)
$txtName.Size = New-Object System.Drawing.Size(600, 25)
$grpMetadata.Controls.Add($txtName)

  # App Edition (Optional)
  $lblEdition = New-Object System.Windows.Forms.Label
  $lblEdition.Text = "App Edition:"
  $lblEdition.Location = New-Object System.Drawing.Point(20, 210)
  $lblEdition.Size = New-Object System.Drawing.Size(150, 20)
  $grpMetadata.Controls.Add($lblEdition)

  $txtEdition = New-Object System.Windows.Forms.TextBox
  $txtEdition.Location = New-Object System.Drawing.Point(180, 208)
  $txtEdition.Size = New-Object System.Drawing.Size(600, 25)
  $grpMetadata.Controls.Add($txtEdition)

# Version
$lblVersion = New-Object System.Windows.Forms.Label
$lblVersion.Text = "App Version: *"
$lblVersion.Location = New-Object System.Drawing.Point(20, 250)
$lblVersion.Size = New-Object System.Drawing.Size(150, 20)
$grpMetadata.Controls.Add($lblVersion)

$txtVersion = New-Object System.Windows.Forms.TextBox
$txtVersion.Location = New-Object System.Drawing.Point(180, 248)
$txtVersion.Size = New-Object System.Drawing.Size(600, 25)
$grpMetadata.Controls.Add($txtVersion)

# User Context Checkbox
$chkUserContext = New-Object System.Windows.Forms.CheckBox
$chkUserContext.Text = "User Context Installation (no elevation required)"
$chkUserContext.Location = New-Object System.Drawing.Point(180, 288)
$chkUserContext.Size = New-Object System.Drawing.Size(600, 20)
$chkUserContext.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$grpMetadata.Controls.Add($chkUserContext)
$script:chkUserContext = $chkUserContext

# Folder Exists Flag
$lblFolderExistsFlag = New-Object System.Windows.Forms.Label
$lblFolderExistsFlag.Text = "Folder exists - will update"
$lblFolderExistsFlag.Location = New-Object System.Drawing.Point(180, 315)
$lblFolderExistsFlag.Size = New-Object System.Drawing.Size(600, 25)
$lblFolderExistsFlag.BackColor = $Colors.WarningYellow
$lblFolderExistsFlag.ForeColor = $Colors.TextDark
$lblFolderExistsFlag.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblFolderExistsFlag.Visible = $false
$grpMetadata.Controls.Add($lblFolderExistsFlag)

# Switches GroupBox
$grpSwitches = New-Object System.Windows.Forms.GroupBox
$grpSwitches.Text = "Installation Switches"
$grpSwitches.Location = New-Object System.Drawing.Point(20, 410)
$grpSwitches.Size = New-Object System.Drawing.Size(800, 130)
$grpSwitches.BackColor = $Colors.GroupBackground
$tabMain.Controls.Add($grpSwitches)

$lblInstallSwitch = New-Object System.Windows.Forms.Label
$lblInstallSwitch.Text = "Install Switch:"
$lblInstallSwitch.Location = New-Object System.Drawing.Point(20, 35)
$lblInstallSwitch.Size = New-Object System.Drawing.Size(150, 20)
$lblInstallSwitch.Visible = $false
$grpSwitches.Controls.Add($lblInstallSwitch)

$txtInstallSwitch = New-Object System.Windows.Forms.TextBox
$txtInstallSwitch.Location = New-Object System.Drawing.Point(180, 33)
$txtInstallSwitch.Size = New-Object System.Drawing.Size(410, 25)
$txtInstallSwitch.Font = $FontCode
$txtInstallSwitch.Visible = $false
$grpSwitches.Controls.Add($txtInstallSwitch)

$btnCopySearchTerms = New-Object System.Windows.Forms.Button
$btnCopySearchTerms.Text = "Help package"
$btnCopySearchTerms.Location = New-Object System.Drawing.Point(600, 31)
$btnCopySearchTerms.Size = New-Object System.Drawing.Size(190, 30)
$btnCopySearchTerms.BackColor = $Colors.AccentTeal
$btnCopySearchTerms.ForeColor = [System.Drawing.Color]::White
$btnCopySearchTerms.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnCopySearchTerms.FlatAppearance.BorderSize = 0
$btnCopySearchTerms.Visible = $false
$grpSwitches.Controls.Add($btnCopySearchTerms)

$lblUninstallSwitch = New-Object System.Windows.Forms.Label
$lblUninstallSwitch.Text = "Uninstall Switch:"
$lblUninstallSwitch.Location = New-Object System.Drawing.Point(20, 75)
$lblUninstallSwitch.Size = New-Object System.Drawing.Size(150, 20)
$lblUninstallSwitch.Visible = $false
$grpSwitches.Controls.Add($lblUninstallSwitch)

$txtUninstallSwitch = New-Object System.Windows.Forms.TextBox
$txtUninstallSwitch.Location = New-Object System.Drawing.Point(180, 73)
$txtUninstallSwitch.Size = New-Object System.Drawing.Size(600, 25)
$txtUninstallSwitch.Font = $FontCode
$txtUninstallSwitch.Visible = $false
$grpSwitches.Controls.Add($txtUninstallSwitch)

# Package Info GroupBox
$grpPackageInfo = New-Object System.Windows.Forms.GroupBox
$grpPackageInfo.Text = "Package Information"
$grpPackageInfo.Location = New-Object System.Drawing.Point(20, 510)
$grpPackageInfo.Size = New-Object System.Drawing.Size(800, 90)
$grpPackageInfo.BackColor = $Colors.GroupBackground
$tabMain.Controls.Add($grpPackageInfo)

$panelPackagingPath = New-Object System.Windows.Forms.Label
$panelPackagingPath.Text = "Packaging Folder: " + $script:BasePackagingPath
$panelPackagingPath.Location = New-Object System.Drawing.Point(20, 30)
$panelPackagingPath.Size = New-Object System.Drawing.Size(760, 20)
$grpPackageInfo.Controls.Add($panelPackagingPath)



#endregion Tab 1

#region Tab 2: Custom Installation
$tabInstall = New-Object System.Windows.Forms.TabPage
$tabInstall.Text = "Installation Commands"
$tabInstall.BackColor = $Colors.Background
$tabControl.Controls.Add($tabInstall)

# Pre-Install Commands Section
$lblPreInstallHeader = New-Object System.Windows.Forms.Label
$lblPreInstallHeader.Text = "[+] Pre-Install Commands"
$lblPreInstallHeader.Location = New-Object System.Drawing.Point(20, 20)
$lblPreInstallHeader.Size = New-Object System.Drawing.Size(800, 30)
$lblPreInstallHeader.BackColor = $Colors.AccentTeal
$lblPreInstallHeader.ForeColor = [System.Drawing.Color]::White
$lblPreInstallHeader.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$lblPreInstallHeader.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$lblPreInstallHeader.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
$lblPreInstallHeader.Cursor = [System.Windows.Forms.Cursors]::Hand
$lblPreInstallHeader.Tag = @{ IsExpanded = $false; TargetControl = $null }
$tabInstall.Controls.Add($lblPreInstallHeader)

$txtPreInstall = New-Object System.Windows.Forms.RichTextBox
$txtPreInstall.Location = New-Object System.Drawing.Point(20, 50)
$txtPreInstall.Size = New-Object System.Drawing.Size(800, 150)
$txtPreInstall.ScrollBars = 'Both'
$txtPreInstall.AcceptsTab = $true
$txtPreInstall.Visible = $false
$txtPreInstall.ReadOnly = $false
$tabInstall.Controls.Add($txtPreInstall)
$lblPreInstallHeader.Tag.TargetControl = $txtPreInstall
Register-CodeEditorBehavior -Editor $txtPreInstall -HelpTitle "Pre-Install Commands" -HelpDescription "Runs before the installer starts. Use this section for prerequisite checks, process stops, service checks, and anything that prevents a bad install from starting."

# Custom Install Commands Section
$lblCustomInstallHeader = New-Object System.Windows.Forms.Label
$lblCustomInstallHeader.Text = "[+] Custom Install Commands"
$lblCustomInstallHeader.Location = New-Object System.Drawing.Point(20, 210)
$lblCustomInstallHeader.Size = New-Object System.Drawing.Size(800, 30)
$lblCustomInstallHeader.BackColor = $Colors.AccentTeal
$lblCustomInstallHeader.ForeColor = [System.Drawing.Color]::White
$lblCustomInstallHeader.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$lblCustomInstallHeader.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$lblCustomInstallHeader.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
$lblCustomInstallHeader.Cursor = [System.Windows.Forms.Cursors]::Hand
$lblCustomInstallHeader.Tag = @{ IsExpanded = $false; TargetControl = $null }
$tabInstall.Controls.Add($lblCustomInstallHeader)

$txtCustomInstall = New-Object System.Windows.Forms.RichTextBox
$txtCustomInstall.Location = New-Object System.Drawing.Point(20, 240)
$txtCustomInstall.Size = New-Object System.Drawing.Size(800, 150)
$txtCustomInstall.ScrollBars = 'Both'
$txtCustomInstall.AcceptsTab = $true
$txtCustomInstall.Visible = $false
$txtCustomInstall.ReadOnly = $false
$tabInstall.Controls.Add($txtCustomInstall)
$lblCustomInstallHeader.Tag.TargetControl = $txtCustomInstall
Register-CodeEditorBehavior -Editor $txtCustomInstall -HelpTitle "Custom Install Commands" -HelpDescription "Runs during installation. Use this section for custom install steps, vendor-specific logic, or extra commands that must happen while the app is being installed."

# Post-Install Commands Section
$lblPostInstallHeader = New-Object System.Windows.Forms.Label
$lblPostInstallHeader.Text = "[+] Post-Install Commands"
$lblPostInstallHeader.Location = New-Object System.Drawing.Point(20, 400)
$lblPostInstallHeader.Size = New-Object System.Drawing.Size(800, 30)
$lblPostInstallHeader.BackColor = $Colors.AccentTeal
$lblPostInstallHeader.ForeColor = [System.Drawing.Color]::White
$lblPostInstallHeader.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$lblPostInstallHeader.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$lblPostInstallHeader.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
$lblPostInstallHeader.Cursor = [System.Windows.Forms.Cursors]::Hand
$lblPostInstallHeader.Tag = @{ IsExpanded = $false; TargetControl = $null }
$tabInstall.Controls.Add($lblPostInstallHeader)

$txtPostInstall = New-Object System.Windows.Forms.RichTextBox
$txtPostInstall.Location = New-Object System.Drawing.Point(20, 430)
$txtPostInstall.Size = New-Object System.Drawing.Size(800, 150)
$txtPostInstall.ScrollBars = 'Both'
$txtPostInstall.AcceptsTab = $true
$txtPostInstall.Visible = $false
$txtPostInstall.ReadOnly = $false
$tabInstall.Controls.Add($txtPostInstall)
$lblPostInstallHeader.Tag.TargetControl = $txtPostInstall
Register-CodeEditorBehavior -Editor $txtPostInstall -HelpTitle "Post-Install Commands" -HelpDescription "Runs after installation finishes. Use this section for cleanup, shortcut creation, verification, or any final actions after the install completes."

# Click event handlers for expand/collapse
$lblPreInstallHeader.Add_Click({
    $label = $this
    $textbox = $label.Tag.TargetControl
    if ($label.Tag.IsExpanded) {
        $textbox.Visible = $false
        $label.Text = $label.Text.Replace('[-]', '[+]')
        $label.Tag.IsExpanded = $false
    } else {
        $textbox.Visible = $true
        $label.Text = $label.Text.Replace('[+]', '[-]')
        $label.Tag.IsExpanded = $true
    }
})


$lblCustomInstallHeader.Add_Click({
    $label = $this
    $textbox = $label.Tag.TargetControl
    if ($label.Tag.IsExpanded) {
        $textbox.Visible = $false
        $label.Text = $label.Text.Replace('[-]', '[+]')
        $label.Tag.IsExpanded = $false
    } else {
        $textbox.Visible = $true
        $label.Text = $label.Text.Replace('[+]', '[-]')
        $label.Tag.IsExpanded = $true
    }
})

$lblPostInstallHeader.Add_Click({
    $label = $this
    $textbox = $label.Tag.TargetControl
    if ($label.Tag.IsExpanded) {
        $textbox.Visible = $false
        $label.Text = $label.Text.Replace('[-]', '[+]')
        $label.Tag.IsExpanded = $false
    } else {
        $textbox.Visible = $true
        $label.Text = $label.Text.Replace('[+]', '[-]')
        $label.Tag.IsExpanded = $true
    }
})

# Auto-expand textboxes when content is added
$txtPreInstall.Add_TextChanged({
    $label = $lblPreInstallHeader
    if (-not [string]::IsNullOrWhiteSpace($txtPreInstall.Text) -and -not $label.Tag.IsExpanded) {
        $txtPreInstall.Visible = $true
        $label.Text = $label.Text.Replace('[+]', '[-]')
        $label.Tag.IsExpanded = $true
    }
})

$txtCustomInstall.Add_TextChanged({
    $label = $lblCustomInstallHeader
    if (-not [string]::IsNullOrWhiteSpace($txtCustomInstall.Text) -and -not $label.Tag.IsExpanded) {
        $txtCustomInstall.Visible = $true
        $label.Text = $label.Text.Replace('[+]', '[-]')
        $label.Tag.IsExpanded = $true
    }
})

$txtPostInstall.Add_TextChanged({
    $label = $lblPostInstallHeader
    if (-not [string]::IsNullOrWhiteSpace($txtPostInstall.Text) -and -not $label.Tag.IsExpanded) {
        $txtPostInstall.Visible = $true
        $label.Text = $label.Text.Replace('[+]', '[-]')
        $label.Tag.IsExpanded = $true
    }
})

#endregion Tab 2

#region Tab 3: Custom Uninstallation
$tabUninstall = New-Object System.Windows.Forms.TabPage
$tabUninstall.Text = "Uninstallation Commands"
$tabUninstall.BackColor = $Colors.Background
$tabControl.Controls.Add($tabUninstall)

# Pre-Uninstall Commands Section
$lblPreUninstallHeader = New-Object System.Windows.Forms.Label
$lblPreUninstallHeader.Text = "[+] Pre-Uninstall Commands"
$lblPreUninstallHeader.Location = New-Object System.Drawing.Point(20, 20)
$lblPreUninstallHeader.Size = New-Object System.Drawing.Size(800, 30)
$lblPreUninstallHeader.BackColor = $Colors.AccentTeal
$lblPreUninstallHeader.ForeColor = [System.Drawing.Color]::White
$lblPreUninstallHeader.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$lblPreUninstallHeader.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$lblPreUninstallHeader.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
$lblPreUninstallHeader.Cursor = [System.Windows.Forms.Cursors]::Hand
$lblPreUninstallHeader.Tag = @{ IsExpanded = $false; TargetControl = $null }
$tabUninstall.Controls.Add($lblPreUninstallHeader)

$txtPreUninstall = New-Object System.Windows.Forms.RichTextBox
$txtPreUninstall.Location = New-Object System.Drawing.Point(20, 50)
$txtPreUninstall.Size = New-Object System.Drawing.Size(800, 150)
$txtPreUninstall.ScrollBars = 'Both'
$txtPreUninstall.AcceptsTab = $true
$txtPreUninstall.Visible = $false
$txtPreUninstall.ReadOnly = $false
$tabUninstall.Controls.Add($txtPreUninstall)
$lblPreUninstallHeader.Tag.TargetControl = $txtPreUninstall
Register-CodeEditorBehavior -Editor $txtPreUninstall -HelpTitle "Pre-Uninstall Commands" -HelpDescription "Runs before the uninstall starts. Use this section to stop processes, close apps, or prepare the machine so removal can succeed cleanly."

# Custom Uninstall Commands Section
$lblCustomUninstallHeader = New-Object System.Windows.Forms.Label
$lblCustomUninstallHeader.Text = "[+] Custom Uninstall Commands"
$lblCustomUninstallHeader.Location = New-Object System.Drawing.Point(20, 210)
$lblCustomUninstallHeader.Size = New-Object System.Drawing.Size(800, 30)
$lblCustomUninstallHeader.BackColor = $Colors.AccentTeal
$lblCustomUninstallHeader.ForeColor = [System.Drawing.Color]::White
$lblCustomUninstallHeader.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$lblCustomUninstallHeader.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$lblCustomUninstallHeader.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
$lblCustomUninstallHeader.Cursor = [System.Windows.Forms.Cursors]::Hand
$lblCustomUninstallHeader.Tag = @{ IsExpanded = $false; TargetControl = $null }
$tabUninstall.Controls.Add($lblCustomUninstallHeader)

$txtCustomUninstall = New-Object System.Windows.Forms.RichTextBox
$txtCustomUninstall.Location = New-Object System.Drawing.Point(20, 240)
$txtCustomUninstall.Size = New-Object System.Drawing.Size(800, 150)
$txtCustomUninstall.ScrollBars = 'Both'
$txtCustomUninstall.AcceptsTab = $true
$txtCustomUninstall.Visible = $false
$txtCustomUninstall.ReadOnly = $false
$tabUninstall.Controls.Add($txtCustomUninstall)
$lblCustomUninstallHeader.Tag.TargetControl = $txtCustomUninstall
Register-CodeEditorBehavior -Editor $txtCustomUninstall -HelpTitle "Custom Uninstall Commands" -HelpDescription "Runs during uninstall. Use this section for the vendor's uninstall command, machine cleanup steps, or other actions that should happen while removing the app."

# Post-Uninstall Commands Section
$lblPostUninstallHeader = New-Object System.Windows.Forms.Label
$lblPostUninstallHeader.Text = "[+] Post-Uninstall Commands"
$lblPostUninstallHeader.Location = New-Object System.Drawing.Point(20, 400)
$lblPostUninstallHeader.Size = New-Object System.Drawing.Size(800, 30)
$lblPostUninstallHeader.BackColor = $Colors.AccentTeal
$lblPostUninstallHeader.ForeColor = [System.Drawing.Color]::White
$lblPostUninstallHeader.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$lblPostUninstallHeader.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$lblPostUninstallHeader.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
$lblPostUninstallHeader.Cursor = [System.Windows.Forms.Cursors]::Hand
$lblPostUninstallHeader.Tag = @{ IsExpanded = $false; TargetControl = $null }
$tabUninstall.Controls.Add($lblPostUninstallHeader)

$txtPostUninstall = New-Object System.Windows.Forms.RichTextBox
$txtPostUninstall.Location = New-Object System.Drawing.Point(20, 430)
$txtPostUninstall.Size = New-Object System.Drawing.Size(800, 150)
$txtPostUninstall.ScrollBars = 'Both'
$txtPostUninstall.AcceptsTab = $true
$txtPostUninstall.Visible = $false
$txtPostUninstall.ReadOnly = $false
$tabUninstall.Controls.Add($txtPostUninstall)
$lblPostUninstallHeader.Tag.TargetControl = $txtPostUninstall
Register-CodeEditorBehavior -Editor $txtPostUninstall -HelpTitle "Post-Uninstall Commands" -HelpDescription "Runs after uninstall completes. Use this section for leftover cleanup, report-related cleanup, or preserving user-level data while removing machine-level artifacts."

# Click event handlers for expand/collapse
$lblPreUninstallHeader.Add_Click({
    $label = $this
    $textbox = $label.Tag.TargetControl
    if ($label.Tag.IsExpanded) {
        $textbox.Visible = $false
        $label.Text = $label.Text.Replace('[-]', '[+]')
        $label.Tag.IsExpanded = $false
    } else {
        $textbox.Visible = $true
        $label.Text = $label.Text.Replace('[+]', '[-]')
        $label.Tag.IsExpanded = $true
    }
})

$lblCustomUninstallHeader.Add_Click({
    $label = $this
    $textbox = $label.Tag.TargetControl
    if ($label.Tag.IsExpanded) {
        $textbox.Visible = $false
        $label.Text = $label.Text.Replace('[-]', '[+]')
        $label.Tag.IsExpanded = $false
    } else {
        $textbox.Visible = $true
        $label.Text = $label.Text.Replace('[+]', '[-]')
        $label.Tag.IsExpanded = $true
    }
})

$lblPostUninstallHeader.Add_Click({
    $label = $this
    $textbox = $label.Tag.TargetControl
    if ($label.Tag.IsExpanded) {
        $textbox.Visible = $false
        $label.Text = $label.Text.Replace('[-]', '[+]')
        $label.Tag.IsExpanded = $false
    } else {
        $textbox.Visible = $true
        $label.Text = $label.Text.Replace('[+]', '[-]')
        $label.Tag.IsExpanded = $true
    }
})

# Auto-expand textboxes when content is added
$txtPreUninstall.Add_TextChanged({
    $label = $lblPreUninstallHeader
    if (-not [string]::IsNullOrWhiteSpace($txtPreUninstall.Text) -and -not $label.Tag.IsExpanded) {
        $txtPreUninstall.Visible = $true
        $label.Text = $label.Text.Replace('[+]', '[-]')
        $label.Tag.IsExpanded = $true
    }
})

$txtCustomUninstall.Add_TextChanged({
    $label = $lblCustomUninstallHeader
    if (-not [string]::IsNullOrWhiteSpace($txtCustomUninstall.Text) -and -not $label.Tag.IsExpanded) {
        $txtCustomUninstall.Visible = $true
        $label.Text = $label.Text.Replace('[+]', '[-]')
        $label.Tag.IsExpanded = $true
    }
})

$txtPostUninstall.Add_TextChanged({
    $label = $lblPostUninstallHeader
    if (-not [string]::IsNullOrWhiteSpace($txtPostUninstall.Text) -and -not $label.Tag.IsExpanded) {
        $txtPostUninstall.Visible = $true
        $label.Text = $label.Text.Replace('[+]', '[-]')
        $label.Tag.IsExpanded = $true
    }
})

#endregion Tab 3

#region Tab 4: Package Helper
$tabPackageHelper = New-Object System.Windows.Forms.TabPage
$tabPackageHelper.Text = "Package Helper"
$tabPackageHelper.BackColor = $Colors.Background
$tabControl.Controls.Add($tabPackageHelper)

$lblPackageHelperHeader = New-Object System.Windows.Forms.Label
$lblPackageHelperHeader.Text = "Package Helper - Copy/Paste Ready Suggestions"
$lblPackageHelperHeader.Location = New-Object System.Drawing.Point(20, 15)
$lblPackageHelperHeader.Size = New-Object System.Drawing.Size(800, 24)
$lblPackageHelperHeader.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$tabPackageHelper.Controls.Add($lblPackageHelperHeader)

$script:lblPackageHelperContext = New-Object System.Windows.Forms.Label
$script:lblPackageHelperContext.Text = "Click Help package to generate section guidance for this app."
$script:lblPackageHelperContext.Location = New-Object System.Drawing.Point(20, 42)
$script:lblPackageHelperContext.Size = New-Object System.Drawing.Size(620, 20)
$script:lblPackageHelperContext.ForeColor = [System.Drawing.Color]::Gray
$tabPackageHelper.Controls.Add($script:lblPackageHelperContext)

$btnRefreshPackageHelper = New-Object System.Windows.Forms.Button
$btnRefreshPackageHelper.Text = "Refresh Helper"
$btnRefreshPackageHelper.Location = New-Object System.Drawing.Point(670, 38)
$btnRefreshPackageHelper.Size = New-Object System.Drawing.Size(130, 28)
$btnRefreshPackageHelper.BackColor = $Colors.AccentTeal
$btnRefreshPackageHelper.ForeColor = [System.Drawing.Color]::White
$btnRefreshPackageHelper.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnRefreshPackageHelper.FlatAppearance.BorderSize = 0
$tabPackageHelper.Controls.Add($btnRefreshPackageHelper)

$btnApplyAllPackageHelper = New-Object System.Windows.Forms.Button
$btnApplyAllPackageHelper.Text = "Apply All to GUI"
$btnApplyAllPackageHelper.Location = New-Object System.Drawing.Point(530, 38)
$btnApplyAllPackageHelper.Size = New-Object System.Drawing.Size(130, 28)
$btnApplyAllPackageHelper.BackColor = $Colors.SuccessGreen
$btnApplyAllPackageHelper.ForeColor = [System.Drawing.Color]::White
$btnApplyAllPackageHelper.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnApplyAllPackageHelper.FlatAppearance.BorderSize = 0
$tabPackageHelper.Controls.Add($btnApplyAllPackageHelper)

$panelPackageHelper = New-Object System.Windows.Forms.Panel
$panelPackageHelper.Location = New-Object System.Drawing.Point(20, 72)
$panelPackageHelper.Size = New-Object System.Drawing.Size(820, 540)
$panelPackageHelper.AutoScroll = $true
$panelPackageHelper.BackColor = $Colors.Background
$tabPackageHelper.Controls.Add($panelPackageHelper)

$sectionLayout = @(
    @{ Key = "ContextSelection"; Title = "Context Selection" },
    @{ Key = "InstallCommand"; Title = "Install Command Line" },
    @{ Key = "UninstallCommand"; Title = "Uninstall Command Line" },
    @{ Key = "UninstallExecutable"; Title = "Uninstall Executable" },
    @{ Key = "PreInstallChecks"; Title = "Pre-Install Checks" },
    @{ Key = "Prerequisites"; Title = "Prerequisite Checks" }
)

$helperTop = 0
foreach ($sectionInfo in $sectionLayout) {
    $group = New-Object System.Windows.Forms.GroupBox
    $group.Text = $sectionInfo.Title
    $group.Location = New-Object System.Drawing.Point(0, $helperTop)
    $group.Size = New-Object System.Drawing.Size(790, 190)
    $group.BackColor = $Colors.GroupBackground
    $panelPackageHelper.Controls.Add($group)

    $lblSummary = New-Object System.Windows.Forms.Label
    $lblSummary.Text = "Generate helper data to populate this section."
    $lblSummary.Location = New-Object System.Drawing.Point(15, 25)
    $lblSummary.Size = New-Object System.Drawing.Size(760, 20)
    $lblSummary.ForeColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
    $group.Controls.Add($lblSummary)

    $txtOutput = New-Object System.Windows.Forms.TextBox
    $txtOutput.Location = New-Object System.Drawing.Point(15, 48)
    $txtOutput.Size = New-Object System.Drawing.Size(760, 92)
    $txtOutput.Multiline = $true
    $txtOutput.ScrollBars = 'Both'
    $txtOutput.WordWrap = $false
    $txtOutput.Font = $FontCode
    $txtOutput.ReadOnly = $true
    $group.Controls.Add($txtOutput)

    $lblIndex = New-Object System.Windows.Forms.Label
    $lblIndex.Text = "Suggestion 0 of 0"
    $lblIndex.Location = New-Object System.Drawing.Point(15, 148)
    $lblIndex.Size = New-Object System.Drawing.Size(180, 20)
    $group.Controls.Add($lblIndex)

    $lblFeedback = New-Object System.Windows.Forms.Label
    $lblFeedback.Text = "Did this help?"
    $lblFeedback.Location = New-Object System.Drawing.Point(200, 148)
    $lblFeedback.Size = New-Object System.Drawing.Size(140, 20)
    $group.Controls.Add($lblFeedback)

    $btnCopy = New-Object System.Windows.Forms.Button
    $btnCopy.Text = "Copy Snippet"
    $btnCopy.Location = New-Object System.Drawing.Point(405, 145)
    $btnCopy.Size = New-Object System.Drawing.Size(85, 28)
    $btnCopy.BackColor = $Colors.AccentTeal
    $btnCopy.ForeColor = [System.Drawing.Color]::White
    $btnCopy.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnCopy.FlatAppearance.BorderSize = 0
    $btnCopy.Tag = $sectionInfo.Key
    $group.Controls.Add($btnCopy)

    $btnApply = New-Object System.Windows.Forms.Button
    $btnApply.Text = "Apply to GUI"
    $btnApply.Location = New-Object System.Drawing.Point(495, 145)
    $btnApply.Size = New-Object System.Drawing.Size(95, 28)
    $btnApply.BackColor = [System.Drawing.Color]::FromArgb(0, 105, 160)
    $btnApply.ForeColor = [System.Drawing.Color]::White
    $btnApply.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnApply.FlatAppearance.BorderSize = 0
    $btnApply.Tag = $sectionInfo.Key
    $group.Controls.Add($btnApply)

    $btnHelpYes = New-Object System.Windows.Forms.Button
    $btnHelpYes.Text = "Yes"
    $btnHelpYes.Location = New-Object System.Drawing.Point(595, 145)
    $btnHelpYes.Size = New-Object System.Drawing.Size(55, 28)
    $btnHelpYes.BackColor = $Colors.SuccessGreen
    $btnHelpYes.ForeColor = [System.Drawing.Color]::White
    $btnHelpYes.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnHelpYes.FlatAppearance.BorderSize = 0
    $btnHelpYes.Tag = $sectionInfo.Key
    $group.Controls.Add($btnHelpYes)

    $btnHelpNo = New-Object System.Windows.Forms.Button
    $btnHelpNo.Text = "No"
    $btnHelpNo.Location = New-Object System.Drawing.Point(660, 145)
    $btnHelpNo.Size = New-Object System.Drawing.Size(115, 28)
    $btnHelpNo.BackColor = [System.Drawing.Color]::FromArgb(205, 130, 30)
    $btnHelpNo.ForeColor = [System.Drawing.Color]::White
    $btnHelpNo.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnHelpNo.FlatAppearance.BorderSize = 0
    $btnHelpNo.Tag = $sectionInfo.Key
    $btnHelpNo.Text = "No, try another"
    $group.Controls.Add($btnHelpNo)

    $script:PackageHelperControls[$sectionInfo.Key] = @{
        Group = $group
        DefaultTitle = $sectionInfo.Title
        SummaryLabel = $lblSummary
        OutputTextBox = $txtOutput
        ApplyButton = $btnApply
        IndexLabel = $lblIndex
        FeedbackLabel = $lblFeedback
        Suggestions = @()
        CurrentIndex = 0
    }

    $btnCopy.Add_Click({
        $sectionKey = $this.Tag
        if (-not $script:PackageHelperControls.ContainsKey($sectionKey)) { return }

        $state = $script:PackageHelperControls[$sectionKey]
        if ([string]::IsNullOrWhiteSpace($state.OutputTextBox.Text)) {
            return
        }

        try {
            [System.Windows.Forms.Clipboard]::SetText($state.OutputTextBox.Text)
            $state.FeedbackLabel.Text = "Copied to clipboard"
            $script:PackageHelperControls[$sectionKey] = $state
        }
        catch {
            $state.FeedbackLabel.Text = "Copy failed"
            $script:PackageHelperControls[$sectionKey] = $state
        }
    })

    $btnApply.Add_Click({
        $sectionKey = $this.Tag
        if (-not $script:PackageHelperControls.ContainsKey($sectionKey)) { return }

        $state = $script:PackageHelperControls[$sectionKey]
        $applied = Apply-PackageHelperSectionToGui -SectionKey $sectionKey
        if ($applied) {
            Write-PackageHelperFeedback -SectionKey $sectionKey -Response "Applied" -SuggestionText $state.OutputTextBox.Text -Note "Manual apply from section"
        }
    })

    $btnHelpYes.Add_Click({
        $sectionKey = $this.Tag
        if (-not $script:PackageHelperControls.ContainsKey($sectionKey)) { return }

        $state = $script:PackageHelperControls[$sectionKey]
        $state.FeedbackLabel.Text = "Great - kept and applied"
        $script:PackageHelperControls[$sectionKey] = $state

        Apply-PackageHelperSectionToGui -SectionKey $sectionKey | Out-Null
        Write-PackageHelperFeedback -SectionKey $sectionKey -Response "Yes" -SuggestionText $state.OutputTextBox.Text -Note "Technician accepted section"
    })

    $btnHelpNo.Add_Click({
        $sectionKey = $this.Tag
        if (-not $script:PackageHelperControls.ContainsKey($sectionKey)) { return }

        $state = $script:PackageHelperControls[$sectionKey]
        if (-not $state.Suggestions -or $state.Suggestions.Count -eq 0) {
            $state.FeedbackLabel.Text = "No more suggestions available"
            $script:PackageHelperControls[$sectionKey] = $state
            Write-PackageHelperFeedback -SectionKey $sectionKey -Response "No" -SuggestionText $state.OutputTextBox.Text -Note "No suggestions available"
            return
        }

        $nextIndex = $state.CurrentIndex + 1
        if ($nextIndex -ge $state.Suggestions.Count) {
            $nextIndex = 0
        }

        Set-PackageHelperSectionSuggestion -SectionKey $sectionKey -SuggestionIndex $nextIndex -FeedbackText "Loaded another suggestion"
        Write-PackageHelperFeedback -SectionKey $sectionKey -Response "No" -SuggestionText $state.OutputTextBox.Text -Note "Requested alternate suggestion"
    })

    $helperTop += 200
}

$panelPackageHelper.AutoScrollMinSize = New-Object System.Drawing.Size(780, $helperTop + 10)

$btnApplyAllPackageHelper.Add_Click({
    $count = Apply-AllPackageHelperSuggestionsToGui
    Write-PackageHelperFeedback -SectionKey "ALL" -Response "Applied" -SuggestionText "" -Note "Applied $count section(s) using Apply All"
})

#endregion Tab 4

#region Status Area
$statusBar = New-Object System.Windows.Forms.Panel
$statusBar.Location = New-Object System.Drawing.Point(20, 720)
$statusBar.Size = New-Object System.Drawing.Size(860, 100)
$statusBar.BackColor = $Colors.GroupBackground
$form.Controls.Add($statusBar)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = ""
$lblStatus.Location = New-Object System.Drawing.Point(10, 10)
$lblStatus.Size = New-Object System.Drawing.Size(840, 35)
$lblStatus.ForeColor = [System.Drawing.Color]::Blue
$lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$statusBar.Controls.Add($lblStatus)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10, 50)
$progressBar.Size = New-Object System.Drawing.Size(840, 10)
$progressBar.Style = "Continuous"
$statusBar.Controls.Add($progressBar)

$btnCreate = New-Object System.Windows.Forms.Button
$btnCreate.Text = "Start Packaging"
$btnCreate.Location = New-Object System.Drawing.Point(580, 65)
$btnCreate.Size = New-Object System.Drawing.Size(130, 35)
$btnCreate.BackColor = $Colors.AccentTeal
$btnCreate.ForeColor = [System.Drawing.Color]::White
$btnCreate.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnCreate.FlatAppearance.BorderSize = 0
$btnCreate.Visible = $false
$statusBar.Controls.Add($btnCreate)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancel"
$btnCancel.Location = New-Object System.Drawing.Point(720, 65)
$btnCancel.Size = New-Object System.Drawing.Size(130, 35)
$btnCancel.BackColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
$btnCancel.ForeColor = $Colors.TextDark
$btnCancel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnCancel.FlatAppearance.BorderSize = 0
$statusBar.Controls.Add($btnCancel)
#endregion Status Area


#endregion GUI Creation

# Event handlers extracted but not found in original


#region Event Handlers

function Load-ExistingPackageDataIfPresent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackagePath
    )

    $existingStartupPath = Join-Path $PackagePath $script:ProjectFileName
    if (-not (Test-Path $existingStartupPath)) {
        return
    }

    if (-not $script:LastLoadedStartupPath) {
        $script:LastLoadedStartupPath = ""
    }

    # Avoid reloading the same Startup.pss repeatedly while fields are unchanged.
    if ($script:LastLoadedStartupPath -eq $existingStartupPath) {
        return
    }

    Update-Status "Loading custom commands from existing package..." "Blue"
    $form.Refresh()

    try {
        $loadResult = Get-CustomCommandsFromStartupPss -StartupPssPath $existingStartupPath

        if ($script:txtPreInstall) { $script:txtPreInstall.Text = Format-CodeEditorText -Text $loadResult.PreInstall }
        if ($script:txtCustomInstall) { $script:txtCustomInstall.Text = Format-CodeEditorText -Text $loadResult.CustomInstall }
        if ($script:txtPostInstall) { $script:txtPostInstall.Text = Format-CodeEditorText -Text $loadResult.PostInstall }
        if ($script:txtPreUninstall) { $script:txtPreUninstall.Text = Format-CodeEditorText -Text $loadResult.PreUninstall }
        if ($script:txtCustomUninstall) { $script:txtCustomUninstall.Text = Format-CodeEditorText -Text $loadResult.CustomUninstall }
        if ($script:txtPostUninstall) { $script:txtPostUninstall.Text = Format-CodeEditorText -Text $loadResult.PostUninstall }

        if ($script:txtUninstallExecutable) {
            $script:txtUninstallExecutable.Text = $loadResult.AppUninstallExeName
            $script:txtUninstallExecutable.Visible = $true
        }
        if ($script:lblUninstallExecutable) { $script:lblUninstallExecutable.Visible = $true }

        if ($script:txtInstallSwitch) {
            $script:txtInstallSwitch.Text = $loadResult.AppInstallCommandLine
            $script:txtInstallSwitch.Visible = $true
        }
        if ($script:lblInstallSwitch) { $script:lblInstallSwitch.Visible = $true }

        if ($script:txtUninstallSwitch) {
            $script:txtUninstallSwitch.Text = $loadResult.AppUninstallCommandLine
            $script:txtUninstallSwitch.Visible = $true
        }
        if ($script:lblUninstallSwitch) { $script:lblUninstallSwitch.Visible = $true }

        $script:LastLoadedStartupPath = $existingStartupPath
        Update-Status "Custom commands and metadata loaded from existing package!" "Green"
    }
    catch {
        Write-Warning "Failed to load existing package data from Startup.pss: $($_.Exception.Message)"
    }
}

# Function to check if package folder exists
function Check-PackageFolderExists {
    if (-not [string]::IsNullOrWhiteSpace($txtVendor.Text) -and 
        -not [string]::IsNullOrWhiteSpace($txtName.Text) -and 
        -not [string]::IsNullOrWhiteSpace($txtVersion.Text)) {
        
        $checkPath = Join-Path $script:BasePackagingPath $txtVendor.Text
        $checkPath = Join-Path $checkPath $txtName.Text
        if (-not [string]::IsNullOrWhiteSpace($txtEdition.Text)) {
            $checkPath = Join-Path $checkPath $txtEdition.Text
        }
        $checkPath = Join-Path $checkPath $txtVersion.Text
        
        if (Test-Path $checkPath) {
            $lblFolderExistsFlag.Visible = $true
            Load-ExistingPackageDataIfPresent -PackagePath $checkPath
        } else {
            $lblFolderExistsFlag.Visible = $false
            $script:LastLoadedStartupPath = ""
        }
    } else {
        $lblFolderExistsFlag.Visible = $false
        $script:LastLoadedStartupPath = ""
    }
}

# TextBox Change Events - Check if folder exists
$txtVendor.Add_TextChanged({ Check-PackageFolderExists })
$txtName.Add_TextChanged({ Check-PackageFolderExists })
$txtEdition.Add_TextChanged({ Check-PackageFolderExists })
$txtVersion.Add_TextChanged({ Check-PackageFolderExists })

$chkUserContext.Add_CheckedChanged({
    $script:SelectedInstallContext = if ($chkUserContext.Checked) { "User" } else { "System" }
    if (-not [string]::IsNullOrWhiteSpace($script:InstallationMediaPath) -and -not [string]::IsNullOrWhiteSpace($txtVendor.Text) -and -not [string]::IsNullOrWhiteSpace($txtName.Text)) {
        Invoke-PackageHelperGeneration
    }
})

$btnRefreshPackageHelper.Add_Click({
    Invoke-PackageHelperGeneration
})

# Browse Button Click Event
$btnBrowse.Add_Click({
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Title = "Select Installation Media"
    $openFileDialog.Filter = "Installation Files (*.exe;*.msi)|*.exe;*.msi|EXE Files (*.exe)|*.exe|MSI Files (*.msi)|*.msi|All Files (*.*)|*.*"
    $openFileDialog.FilterIndex = 1
    
    if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:InstallationMediaPath = $openFileDialog.FileName
        $txtMedia.Text = [System.IO.Path]::GetFileName($script:InstallationMediaPath)
        
        # Use MetadataEngine to extract metadata
        $lblMediaType.Text = "Using MetadataEngine to extract metadata..."
        $lblMediaType.ForeColor = [System.Drawing.Color]::Blue
        $form.Refresh()
        
        $metadata = Get-InstallerMetadata -FilePath $script:InstallationMediaPath
        
        # Auto-populate fields if metadata found
        if (-not [string]::IsNullOrWhiteSpace($metadata.Vendor)) {
            $txtVendor.Text = $metadata.Vendor
        }
        if (-not [string]::IsNullOrWhiteSpace($metadata.ProductName)) {
            $txtName.Text = $metadata.ProductName
        }
        if (-not [string]::IsNullOrWhiteSpace($metadata.Version)) {
            $txtVersion.Text = $metadata.Version
        }
        
        # Folder recognition is the single trigger for Startup.pss rehydrate.
        Check-PackageFolderExists
        # Show Start Packaging button
        $btnCreate.Visible = $true
        
        $extension = [System.IO.Path]::GetExtension($script:InstallationMediaPath).ToLower()
        
        if ($extension -eq ".exe") {
            $lblMediaType.Text = "Type: EXE - Using DetectionEngine..."
            $lblMediaType.ForeColor = [System.Drawing.Color]::Blue
            $form.Refresh()
            
            try {
                # Use DetectionEngine to detect installer type
                $detectionResult = Get-InstallerType -FilePath $script:InstallationMediaPath
                $script:DetectedInstallerType = $detectionResult
            }
            catch {
                Write-Warning "DetectionEngine failed: $($_.Exception.Message)"
                $script:DetectedInstallerType = "Generic"
            }

            Invoke-InstallContextDetectionPrompt -FilePath $script:InstallationMediaPath -InstallerType $script:DetectedInstallerType
            $lblMediaType.Text = "Type: EXE ($($script:DetectedInstallerType) detected) | Context: $($script:SelectedInstallContext)"
            $lblMediaType.ForeColor = [System.Drawing.Color]::Green
            
            # Show EXE-specific controls
            $lblUninstallExecutable.Visible = $true
            $lblInstallSwitch.Visible = $true
            $lblUninstallSwitch.Visible = $true
            $txtUninstallExecutable.Visible = $true
            $txtInstallSwitch.Visible = $true
            $txtUninstallSwitch.Visible = $true
            $btnCopySearchTerms.Visible = $true

        } elseif ($extension -eq ".msi") {
            $lblMediaType.Text = "Type: MSI - Using DetectionEngine..."
            $lblMediaType.ForeColor = [System.Drawing.Color]::Blue
            $form.Refresh()
            
            try {
                # Use DetectionEngine to detect MSI installer type
                $detectionResult = Get-InstallerType -FilePath $script:InstallationMediaPath
                $script:DetectedInstallerType = $detectionResult
            }
            catch {
                Write-Warning "DetectionEngine failed: $($_.Exception.Message)"
                $script:DetectedInstallerType = "Generic"
            }

            Invoke-InstallContextDetectionPrompt -FilePath $script:InstallationMediaPath -InstallerType $script:DetectedInstallerType
            
            # Show MSI-specific controls (same as EXE)
            $lblUninstallExecutable.Visible = $true
            $lblInstallSwitch.Visible = $true
            $lblUninstallSwitch.Visible = $true
            $txtUninstallExecutable.Visible = $true
            $txtInstallSwitch.Visible = $true
            $txtUninstallSwitch.Visible = $true
            $btnCopySearchTerms.Visible = $true
            
            $lblMediaType.Text = "Type: MSI ($($script:DetectedInstallerType) detected)"
            $lblMediaType.ForeColor = [System.Drawing.Color]::Green
        }
        else {
            $lblMediaType.Text = "Type: Unknown - Manual entry required"
            $lblMediaType.ForeColor = [System.Drawing.Color]::Orange
            # Hide all switch controls
            $lblInstallSwitch.Visible = $false
            $lblUninstallSwitch.Visible = $false
            $txtInstallSwitch.Visible = $false
            $txtUninstallSwitch.Visible = $false
            $btnCopySearchTerms.Visible = $false
        }

        if (-not [string]::IsNullOrWhiteSpace($txtVendor.Text) -and -not [string]::IsNullOrWhiteSpace($txtName.Text)) {
            Invoke-PackageHelperGeneration
        }
    }

})

# Help package Button Click Event
$btnCopySearchTerms.Add_Click({
    Invoke-PackageHelperGeneration
})

# Start Packaging Button Click Event (validation only - workflow in New-PackagingFolder)
$btnCreate.Add_Click({
    # Use ValidationEngine to validate inputs
    $errors = @()
    
    if ([string]::IsNullOrWhiteSpace($txtVendor.Text)) {
        $errors += "App Vendor is required"
    } elseif (-not (Test-FolderNameValid -FolderName $txtVendor.Text)) {
        $errors += "App Vendor contains invalid characters"
    }
    
    if ([string]::IsNullOrWhiteSpace($txtName.Text)) {
        $errors += "App Name is required"
    } elseif (-not (Test-FolderNameValid -FolderName $txtName.Text)) {
        $errors += "App Name contains invalid characters"
    }
    
    if ([string]::IsNullOrWhiteSpace($txtVersion.Text)) {
        $errors += "App Version is required"
    } elseif (-not (Test-FolderNameValid -FolderName $txtVersion.Text)) {
        $errors += "App Version contains invalid characters"
    }
    
    if ($errors.Count -gt 0) {
        [System.Windows.Forms.MessageBox]::Show(
            ($errors -join "`n"), 
            "Validation Error", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return
    }
    
    # Validation passed - call New-PackagingFolder
    $btnCreate.Enabled = $false
    $btnCancel.Enabled = $false
    $btnBrowse.Enabled = $false
    $progressBar.Value = 0
    
    $success = New-PackagingFolder -Vendor $txtVendor.Text.Trim() `
                                   -Name $txtName.Text.Trim() `
                                   -Edition $txtEdition.Text.Trim() `
                                   -Version $txtVersion.Text.Trim()
    
    $btnCreate.Enabled = $true
    $btnCreate.Visible = $true
    $btnCancel.Enabled = $true
    $btnCancel.Visible = $true
    $btnBrowse.Enabled = $true
})

# Cancel Button Click Event
$btnCancel.Add_Click({
    $form.Close()
})

#endregion Event Handlers

[void]$form.ShowDialog()







# Script cleanup - Stop transcript if in development mode
if ($script:DevelopmentMode) {
    try {
        Stop-Transcript
        Write-Host "`n[DEVELOPMENT MODE] Transcript saved to: $script:TranscriptPath" -ForegroundColor Yellow
        Write-Host "[DEVELOPMENT MODE] Error log saved to: $script:ErrorLogPath`n" -ForegroundColor Yellow
    } catch {
        # Transcript may not be running
    }
}


















