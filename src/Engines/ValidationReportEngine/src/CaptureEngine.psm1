#Requires -Version 5.1
<#
.SYNOPSIS
    Capture Engine
    
.DESCRIPTION
    Screenshot capture operations using Snagit.
    Wraps SnagitController with simplified API.
    
.NOTES
    Author: P1MAM08
    Date: 2026-07-13
    Version: 1.2.0
    Type: Engine (Self-contained, integrable)
    Dependencies: SnagitController.psm1, InstallationDetectorEngine.psm1
#>

# Import required modules
$ModulePath = Split-Path -Parent $PSCommandPath
Import-Module "$ModulePath\SnagitController.psm1" -Force -ErrorAction Stop
Import-Module "$ModulePath\InstallationDetectorEngine.psm1" -Force -ErrorAction Stop

#region Private Variables

$script:CaptureSettings = @{
    OutputType = 'JPG'
    Quality = 90
    AutoSave = $true
}

#endregion

#region Public Functions

function Get-CaptureSettings {
    <#
    .SYNOPSIS
        Gets current capture settings
        
    .OUTPUTS
        Hashtable of current settings
    #>
    [CmdletBinding()]
    param()
    
    return $script:CaptureSettings.Clone()
}

function Set-CaptureSettings {
    <#
    .SYNOPSIS
        Updates capture settings
        
    .PARAMETER OutputType
        Output format (JPG or PNG)
        
    .PARAMETER Quality
        JPG quality (1-100)
        
    .PARAMETER AutoSave
        Whether to auto-save captures
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('JPG', 'PNG')]
        [string]$OutputType,
        
        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$Quality,
        
        [Parameter()]
        [bool]$AutoSave
    )
    
    if ($OutputType) {
        $script:CaptureSettings.OutputType = $OutputType
        Write-Verbose "Output type set to: $OutputType"
    }
    
    if ($Quality) {
        $script:CaptureSettings.Quality = $Quality
        Write-Verbose "Quality set to: $Quality"
    }
    
    if ($PSBoundParameters.ContainsKey('AutoSave')) {
        $script:CaptureSettings.AutoSave = $AutoSave
        Write-Verbose "AutoSave set to: $AutoSave"
    }
}

function Invoke-ScreenCapture {
    <#
    .SYNOPSIS
        Captures a screenshot using Snagit
        
    .PARAMETER OutputPath
        Path where screenshot should be saved
        
    .PARAMETER FigureNumber
        Optional figure number for documentation
        
    .PARAMETER Description
        Optional description of what's being captured
        
    .OUTPUTS
        Capture result object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [Parameter()]
        [int]$FigureNumber,
        
        [Parameter()]
        [string]$Description
    )
    
    Write-Verbose "Starting screen capture"
    if ($Description) {
        Write-Verbose "Description: $Description"
    }
    
    try {
        # Ensure output directory exists
        $outputDir = Split-Path -Path $OutputPath -Parent
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
            Write-Verbose "Created output directory: $outputDir"
        }
        
        # Perform capture
        Write-Verbose "Triggering capture to: $OutputPath"
        $result = Invoke-SnagitCapture -OutputPath $OutputPath -CaptureMode 'Region'
        
        if ($result.Success) {
            # Get image dimensions
            $dimensions = $null
            if (Test-Path $OutputPath) {
                try {
                    Add-Type -AssemblyName System.Drawing
                    $img = [System.Drawing.Image]::FromFile($OutputPath)
                    $dimensions = @{
                        Width = $img.Width
                        Height = $img.Height
                    }
                    $img.Dispose()
                } catch {
                    Write-Verbose "Could not get image dimensions"
                }
            }
            
            # Build result object
            $captureResult = [PSCustomObject]@{
                Success = $true
                OutputPath = $OutputPath
                FigureNumber = $FigureNumber
                Description = $Description
                Dimensions = $dimensions
                CaptureTime = Get-Date
                FileSize = (Get-Item $OutputPath).Length
            }
            
            Write-Verbose "Capture successful: $OutputPath"
            return $captureResult
            
        } else {
            Write-Warning "Capture failed or was cancelled"
            
            $captureResult = [PSCustomObject]@{
                Success = $false
                OutputPath = $null
                FigureNumber = $FigureNumber
                Description = $Description
                Dimensions = $null
                CaptureTime = Get-Date
                ErrorMessage = "Capture failed or cancelled"
            }
            
            return $captureResult
        }
        
    } catch {
        Write-Error "Capture error: $($_.Exception.Message)"
        
        $captureResult = [PSCustomObject]@{
            Success = $false
            OutputPath = $null
            FigureNumber = $FigureNumber
            Description = $Description
            Dimensions = $null
            CaptureTime = Get-Date
            ErrorMessage = $_.Exception.Message
        }
        
        return $captureResult
    }
}

function Set-AutomationSearchText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SearchText,

        [int]$PauseMilliseconds = 250
    )

    Add-Type -AssemblyName System.Windows.Forms

    # Clear any stale search text so override names replace defaults instead of appending.
    [System.Windows.Forms.SendKeys]::SendWait('^a')
    Start-Sleep -Milliseconds $PauseMilliseconds
    [System.Windows.Forms.SendKeys]::SendWait('{BACKSPACE}')
    Start-Sleep -Milliseconds $PauseMilliseconds

    if (-not [string]::IsNullOrWhiteSpace($SearchText)) {
        [System.Windows.Forms.SendKeys]::SendWait($SearchText)
    }
}

function Invoke-AutomatedInstalledAppsCapture {
    <#
    .SYNOPSIS
        Automates capture of Installed Apps showing specific application
    
    .DESCRIPTION
        Opens Windows 11 Settings to Installed Apps page, searches for
        the specified application, and triggers Snagit capture.
    
    .PARAMETER AppName
        Application name to search for
    
    .PARAMETER OutputPath
        Where to save the screenshot
    
    .OUTPUTS
        Capture result object
    
    .EXAMPLE
        Invoke-AutomatedInstalledAppsCapture -AppName "Microsoft Edge" -OutputPath "C:\temp\fig2.jpg"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppName,
        
        [Parameter(Mandatory)]
        [string]$OutputPath
    )
    
    Write-Verbose "Starting automated Installed Apps capture for: $AppName"
    
    try {
        # Step 1: Open Settings to Installed Apps
        Write-Verbose "Opening Windows Settings..."
        Start-Process "ms-settings:appsfeatures"
        Start-Sleep -Seconds 3
        
        # Step 2: Bring Settings window to foreground
        $settingsProc = Get-Process | Where-Object {
            $_.MainWindowTitle -like "*Settings*" -or 
            $_.ProcessName -eq "SystemSettings"
        } | Select-Object -First 1
        
        if ($settingsProc) {
            Add-Type @"
                using System;
                using System.Runtime.InteropServices;
                public class WindowHelper {
                    [DllImport("user32.dll")]
                    public static extern bool SetForegroundWindow(IntPtr hWnd);
                }
"@
            [WindowHelper]::SetForegroundWindow($settingsProc.MainWindowHandle) | Out-Null
            Start-Sleep -Milliseconds 500
            Write-Verbose "Settings window brought to foreground"
        }
        
        # Step 3: Send search text
        Write-Verbose "Searching for: $AppName"
        Add-Type -AssemblyName System.Windows.Forms
        Set-AutomationSearchText -SearchText $AppName
        Start-Sleep -Seconds 2
        
        Write-Verbose "Ready for user to capture"
        
        # Step 4: Trigger Snagit capture
        return Invoke-ScreenCapture -OutputPath $OutputPath -FigureNumber 2 -Description "Installed Apps: $AppName"
        
    } catch {
        Write-Error "Automation error: $($_.Exception.Message)"
        return [PSCustomObject]@{
            Success = $false
            ErrorMessage = $_.Exception.Message
            OutputPath = $null
        }
    }
}

function Invoke-AutomatedStartMenuCapture {
    <#
    .SYNOPSIS
        Automates capture of Start Menu showing specific application
    
    .DESCRIPTION
        Opens Windows 11 Start Menu, searches for the specified application,
        and triggers Snagit capture.
    
    .PARAMETER AppName
        Application name to search for
    
    .PARAMETER OutputPath
        Where to save the screenshot
    
    .OUTPUTS
        Capture result object
    
    .EXAMPLE
        Invoke-AutomatedStartMenuCapture -AppName "Node.js" -OutputPath "C:\temp\fig3.jpg"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppName,
        
        [Parameter(Mandatory)]
        [string]$OutputPath
    )
    
    Write-Verbose "Starting automated Start Menu capture for: $AppName"
    
    try {
        # Step 1: Open Start Menu
        Write-Verbose "Opening Start Menu..."
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.SendKeys]::SendWait("^{ESC}")
        Start-Sleep -Milliseconds 800
        
        # Step 2: Search for app
        Write-Verbose "Searching for: $AppName"
        Set-AutomationSearchText -SearchText $AppName
        Start-Sleep -Seconds 2
        
        Write-Verbose "Ready for user to capture"
        
        # Step 3: Trigger Snagit capture
        $captureResult = Invoke-ScreenCapture -OutputPath $OutputPath -FigureNumber 3 -Description "Start Menu: $AppName"

        # Step 4: Launch selected app so Figure 4 can capture opened UI.
        [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
        Start-Sleep -Seconds 4

        return $captureResult
        
    } catch {
        Write-Error "Automation error: $($_.Exception.Message)"
        return [PSCustomObject]@{
            Success = $false
            ErrorMessage = $_.Exception.Message
            OutputPath = $null
        }
    }
}

function Invoke-AutomatedApplicationOpenedCapture {
    <#
    .SYNOPSIS
        Captures the already opened application UI after Start Menu launch

    .DESCRIPTION
        Assumes the application was launched from the Figure 3 workflow,
        waits briefly for UI rendering, then triggers Snagit capture.

    .PARAMETER AppName
        Application name used for capture description

    .PARAMETER OutputPath
        Where to save the screenshot
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppName,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    Write-Verbose "Starting automated application opened capture for: $AppName"

    try {
        Start-Sleep -Seconds 2

        return Invoke-ScreenCapture -OutputPath $OutputPath -FigureNumber 4 -Description "Application Opened: $AppName"
    }
    catch {
        Write-Error "Automation error: $($_.Exception.Message)"
        return [PSCustomObject]@{
            Success = $false
            ErrorMessage = $_.Exception.Message
            OutputPath = $null
        }
    }
}

function Close-InstalledAppsWindow {
    [CmdletBinding()]
    param()

    try {
        $settingsProcesses = Get-Process -ErrorAction SilentlyContinue | Where-Object {
            $_.MainWindowTitle -like "*Settings*" -or $_.ProcessName -eq "SystemSettings"
        }

        foreach ($settingsProcess in $settingsProcesses) {
            if ($settingsProcess.MainWindowHandle -ne 0) {
                [void]$settingsProcess.CloseMainWindow()
            }
        }
    }
    catch {
        Write-Verbose "Unable to close Installed Apps window: $($_.Exception.Message)"
    }
}

function Test-SnagitAvailable {
    <#
    .SYNOPSIS
        Tests if Snagit is available and can be initialized
        
    .OUTPUTS
        Boolean - true if Snagit is available
    #>
    [CmdletBinding()]
    param()
    
    try {
        $snagit = Initialize-Snagit -ErrorAction Stop
        if ($snagit) {
            Write-Verbose "Snagit is available"
            return $true
        }
    } catch {
        Write-Verbose "Snagit is not available: $($_.Exception.Message)"
        return $false
    }
    
    return $false
}

#endregion

Export-ModuleMember -Function @(
    'Get-CaptureSettings',
    'Set-CaptureSettings',
    'Invoke-ScreenCapture',
    'Invoke-AutomatedInstalledAppsCapture',
    'Invoke-AutomatedStartMenuCapture',
    'Invoke-AutomatedApplicationOpenedCapture',
    'Close-InstalledAppsWindow',
    'Test-SnagitAvailable'
)