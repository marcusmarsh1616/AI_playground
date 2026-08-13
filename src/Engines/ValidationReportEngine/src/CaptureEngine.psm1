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

function Get-HelpAboutAutomationModulePath {
    $candidatePaths = @(
        (Join-Path $PSScriptRoot "..\..\..\..\Installation_Validation_Report\PowerShell\Modules\AboutDialogAutomation.psm1"),
        (Join-Path (Split-Path -Parent $PSScriptRoot) "Installation_Validation_Report\PowerShell\Modules\AboutDialogAutomation.psm1"),
        (Join-Path (Get-Location).Path "Installation_Validation_Report\PowerShell\Modules\AboutDialogAutomation.psm1")
    )

    foreach ($candidatePath in $candidatePaths) {
        if (Test-Path $candidatePath) {
            return (Resolve-Path $candidatePath).Path
        }
    }

    return $null
}

function Get-HelpAboutDetectionModulePath {
    $candidatePaths = @(
        (Join-Path $PSScriptRoot "..\..\..\..\Installation_Validation_Report\PowerShell\Modules\HelpAboutDetection.psm1"),
        (Join-Path (Split-Path -Parent $PSScriptRoot) "Installation_Validation_Report\PowerShell\Modules\HelpAboutDetection.psm1"),
        (Join-Path (Get-Location).Path "Installation_Validation_Report\PowerShell\Modules\HelpAboutDetection.psm1")
    )

    foreach ($candidatePath in $candidatePaths) {
        if (Test-Path $candidatePath) {
            return (Resolve-Path $candidatePath).Path
        }
    }

    return $null
}

function Test-HelpAboutVersionMatch {
    <#
    .SYNOPSIS
        Compares Help/About window evidence against the claimed app name/version.

    .DESCRIPTION
        Calls Get-HelpAboutVerification to enumerate visible About/Version-like
        windows and their owning executable's FileVersionInfo, then checks whether
        any candidate's ProductName/FileVersion/ProductVersion plausibly matches
        the technician-entered AppName/AppVersion. Returns a structured result so
        the report can state explicitly whether verification matched, mismatched,
        or found no evidence at all.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppName,

        [Parameter(Mandatory)]
        [string]$AppVersion
    )

    $result = [PSCustomObject]@{
        Verified = $false
        Matched = $false
        Evidence = $null
        Reason = "Help/About verification was not attempted."
    }

    $modulePath = Get-HelpAboutDetectionModulePath
    if ([string]::IsNullOrWhiteSpace($modulePath)) {
        $result.Reason = "Help/About detection module not found."
        return $result
    }

    try {
        Import-Module $modulePath -Force -ErrorAction Stop
    }
    catch {
        $result.Reason = "Failed to load Help/About detection module: $($_.Exception.Message)"
        return $result
    }

    try {
        $candidates = @(Get-HelpAboutVerification -ApplicationName $AppName)
    }
    catch {
        $result.Reason = "Help/About window scan failed: $($_.Exception.Message)"
        return $result
    }

    $result.Verified = $true

    if ($candidates.Count -eq 0) {
        $result.Reason = "No About/Version-style window was found for '$AppName'."
        return $result
    }

    $nameNormalized = ($AppName -replace '[^a-zA-Z0-9]', '').ToLowerInvariant()
    $versionNormalized = ($AppVersion -replace '[^0-9.]', '')

    $bestMatch = $null
    foreach ($candidate in $candidates) {
        $candidateNameFields = @($candidate.ProductName, $candidate.CompanyName, $candidate.WindowTitle, $candidate.ProcessName) |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        $nameHit = $false
        foreach ($field in $candidateNameFields) {
            $fieldNormalized = ($field -replace '[^a-zA-Z0-9]', '').ToLowerInvariant()
            if (-not [string]::IsNullOrWhiteSpace($fieldNormalized) -and
                (-not [string]::IsNullOrWhiteSpace($nameNormalized)) -and
                ($fieldNormalized -like "*$nameNormalized*" -or $nameNormalized -like "*$fieldNormalized*")) {
                $nameHit = $true
                break
            }
        }

        $candidateVersionFields = @($candidate.FileVersion, $candidate.ProductVersion) | Where-Object { $_ }
        $versionHit = $false
        foreach ($versionField in $candidateVersionFields) {
            if (-not [string]::IsNullOrWhiteSpace($versionNormalized) -and
                ([string]$versionField).Contains($versionNormalized)) {
                $versionHit = $true
                break
            }
        }

        if ($nameHit -and $versionHit) {
            $bestMatch = $candidate
            break
        }
        if ($nameHit -and -not $bestMatch) {
            $bestMatch = $candidate
        }
    }

    if (-not $bestMatch) {
        $bestMatch = $candidates[0]
    }

    $result.Evidence = $bestMatch

    if ($bestMatch) {
        $nameField = @($bestMatch.ProductName, $bestMatch.WindowTitle, $bestMatch.ProcessName) | Where-Object { $_ } | Select-Object -First 1
        $nameFieldNormalized = if ($nameField) { ($nameField -replace '[^a-zA-Z0-9]', '').ToLowerInvariant() } else { "" }
        $nameMatched = (-not [string]::IsNullOrWhiteSpace($nameNormalized)) -and (-not [string]::IsNullOrWhiteSpace($nameFieldNormalized)) -and
            ($nameFieldNormalized -like "*$nameNormalized*" -or $nameNormalized -like "*$nameFieldNormalized*")

        $versionField = @($bestMatch.FileVersion, $bestMatch.ProductVersion) | Where-Object { $_ } | Select-Object -First 1
        $versionMatched = (-not [string]::IsNullOrWhiteSpace($versionNormalized)) -and $versionField -and
            ([string]$versionField).Contains($versionNormalized)

        if ($nameMatched -and $versionMatched) {
            $result.Matched = $true
            $result.Reason = "Matched claimed name and version against Help/About evidence."
        }
        elseif ($nameMatched) {
            $result.Matched = $false
            $result.Reason = "Name matched but version could not be confirmed from Help/About evidence (found: $versionField)."
        }
        else {
            $result.Matched = $false
            $result.Reason = "Help/About evidence found but did not match the claimed application name or version."
        }
    }

    return $result
}

function Get-ForegroundProcessId {
    [CmdletBinding()]
    param()

    try {
        if (-not ('ValidationReport.WindowApi' -as [type])) {
            Add-Type -Namespace ValidationReport -Name WindowApi -MemberDefinition @'
    [System.Runtime.InteropServices.DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [System.Runtime.InteropServices.DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
'@
        }

        $hWnd = [ValidationReport.WindowApi]::GetForegroundWindow()
        if ($hWnd -eq [IntPtr]::Zero) {
            return 0
        }

        $pid = 0
        [void][ValidationReport.WindowApi]::GetWindowThreadProcessId($hWnd, [ref]$pid)
        return [int]$pid
    }
    catch {
        return 0
    }
}

function Invoke-FallbackAboutShortcut {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppName,

        [int]$ForegroundProcessId = 0
    )

    try {
        Add-Type -AssemblyName System.Windows.Forms

        $beforeTitle = ""
        if ($ForegroundProcessId -gt 0) {
            $beforeTitle = (Get-Process -Id $ForegroundProcessId -ErrorAction SilentlyContinue).MainWindowTitle
        }

        # Best-effort keystrokes used by common desktop apps.
        $sequences = @(
            @{ Menu = '%h'; Item = 'a'; Name = 'Alt+H,A' },
            @{ Menu = '%f'; Item = 'a'; Name = 'Alt+F,A' },
            @{ Menu = '%h'; Item = 'v'; Name = 'Alt+H,V' }
        )

        foreach ($sequence in $sequences) {
            [System.Windows.Forms.SendKeys]::SendWait($sequence.Menu)
            Start-Sleep -Milliseconds 300
            [System.Windows.Forms.SendKeys]::SendWait($sequence.Item)
            Start-Sleep -Milliseconds 1200

            $activePid = Get-ForegroundProcessId
            $activeProcess = if ($activePid -gt 0) { Get-Process -Id $activePid -ErrorAction SilentlyContinue } else { $null }
            $activeTitle = if ($activeProcess) { [string]$activeProcess.MainWindowTitle } else { "" }

            if ($activeTitle -match '(?i)about|version|information|info|license|licence') {
                return [PSCustomObject]@{
                    Success = $true
                    Message = "Fallback About shortcut succeeded via $($sequence.Name)."
                }
            }

            if (-not [string]::IsNullOrWhiteSpace($beforeTitle) -and $activeTitle -and $activeTitle -ne $beforeTitle -and $activeTitle -match [regex]::Escape($AppName)) {
                return [PSCustomObject]@{
                    Success = $true
                    Message = "Fallback About shortcut likely succeeded via $($sequence.Name)."
                }
            }
        }

        return [PSCustomObject]@{
            Success = $false
            Message = "Fallback About shortcuts did not open a detectable dialog."
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            Message = "Fallback About shortcut failed: $($_.Exception.Message)"
        }
    }
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
            $failureReason = if ($result.Error) { [string]$result.Error } else { "Capture failed or cancelled" }
            
            $captureResult = [PSCustomObject]@{
                Success = $false
                OutputPath = $null
                FigureNumber = $FigureNumber
                Description = $Description
                Dimensions = $null
                CaptureTime = Get-Date
                ErrorMessage = $failureReason
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

function Invoke-AutomatedAboutWindowCapture {
    <#
    .SYNOPSIS
        Captures Figure 5 (Help/About window)

    .DESCRIPTION
        Assumes the technician has opened the target application's Help/About surface
        and triggers Snagit capture for the active window area.

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
        [string]$OutputPath,

        [Parameter()]
        [string]$AppVersion = ""
    )

    Write-Verbose "Starting automated Help/About capture for: $AppName"

    try {
        $modulePath = Get-HelpAboutAutomationModulePath
        $failureReasons = New-Object System.Collections.Generic.List[string]
        $detectionSucceeded = $false
        $foregroundPid = Get-ForegroundProcessId

        if (-not [string]::IsNullOrWhiteSpace($modulePath)) {
            Import-Module $modulePath -Force -ErrorAction Stop

            $attempts = @()
            if (-not [string]::IsNullOrWhiteSpace($AppName)) {
                $attempts += @{ ApplicationName = $AppName; ProcessId = 0; Label = "AppName" }
            }
            if ($foregroundPid -gt 0) {
                $attempts += @{ ApplicationName = ""; ProcessId = $foregroundPid; Label = "ForegroundPid" }
            }

            foreach ($attempt in $attempts) {
                $detectionResult = Invoke-AboutDialogAutomation -ApplicationName $attempt.ApplicationName -ProcessId $attempt.ProcessId -LeaveOpen
                if ($detectionResult.Success) {
                    $detectionSucceeded = $true
                    break
                }

                $reason = if ($detectionResult.Message) { [string]$detectionResult.Message } else { "unknown detection failure" }
                $failureReasons.Add("$($attempt.Label): $reason")
            }
        }
        else {
            $failureReasons.Add("About automation module not found.")
        }

        if (-not $detectionSucceeded) {
            $fallbackResult = Invoke-FallbackAboutShortcut -AppName $AppName -ForegroundProcessId $foregroundPid
            if ($fallbackResult.Success) {
                $detectionSucceeded = $true
            }
            else {
                $failureReasons.Add($fallbackResult.Message)
            }
        }

        if (-not $detectionSucceeded) {
            $failureReason = if ($failureReasons.Count -gt 0) { $failureReasons -join " | " } else { "Help/About detection did not find a window." }
            return [PSCustomObject]@{
                Success = $false
                ErrorMessage = $failureReason
                OutputPath = $null
                Verification = [PSCustomObject]@{
                    Verified = $false
                    Matched = $false
                    Evidence = $null
                    Reason = "About window could not be opened; no evidence to verify."
                }
            }
        }

        Start-Sleep -Seconds 1

        $verification = Test-HelpAboutVersionMatch -AppName $AppName -AppVersion $AppVersion
        $captureResult = Invoke-ScreenCapture -OutputPath $OutputPath -FigureNumber 5 -Description "Help/About: $AppName"

        return [PSCustomObject]@{
            Success = $captureResult.Success
            ErrorMessage = $captureResult.ErrorMessage
            OutputPath = $captureResult.OutputPath
            Verification = $verification
        }
    }
    catch {
        Write-Error "Automation error: $($_.Exception.Message)"
        return [PSCustomObject]@{
            Success = $false
            ErrorMessage = $_.Exception.Message
            OutputPath = $null
            Verification = [PSCustomObject]@{
                Verified = $false
                Matched = $false
                Evidence = $null
                Reason = "Verification not attempted due to an automation error: $($_.Exception.Message)"
            }
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
    'Invoke-AutomatedAboutWindowCapture',
    'Close-InstalledAppsWindow',
    'Test-SnagitAvailable'
)