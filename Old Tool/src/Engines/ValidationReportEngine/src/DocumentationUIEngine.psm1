#Requires -Version 5.1
<#
.SYNOPSIS
    Documentation UI Engine - Fully Automated
    
.DESCRIPTION
    Simplified GUI that automates the entire documentation workflow.
    Fill in App Name and Version, click Start, everything else is automatic.
#>

# Import required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Import required engines
Import-Module (Join-Path $PSScriptRoot "SnagitController.psm1") -Force -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot "DocumentationSessionEngine.psm1") -Force -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot "CaptureEngine.psm1") -Force -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot "InstallationDetectorEngine.psm1") -Force -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot "DocumentGeneratorEngine.psm1") -Force -ErrorAction Stop

#region Private Variables

$script:CurrentSession = $null
$script:Form = $null
$script:Controls = @{}
$script:UiRunResult = $null

#endregion

#region Private Functions

function Write-UIStatus {
    param([string]$Message, [string]$Color = "Black")
    
    if ($script:Controls.StatusLabel) {
        $script:Controls.StatusLabel.Text = $Message
        $script:Controls.StatusLabel.ForeColor = [System.Drawing.Color]::FromName($Color)
        $script:Form.Refresh()
        [System.Windows.Forms.Application]::DoEvents()
    }
}

function Start-AutomatedDocumentation {
    # Validate inputs
    if ([string]::IsNullOrWhiteSpace($script:Controls.txtAppName.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter Application Name", "Required", 'OK', 'Warning')
        return
    }
    
    if ([string]::IsNullOrWhiteSpace($script:Controls.txtAppVersion.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter Application Version", "Required", 'OK', 'Warning')
        return
    }
    
    # Disable button during processing
    $script:Controls.btnStart.Enabled = $false
    $script:Controls.txtAppName.Enabled = $false
    $script:Controls.txtAppVersion.Enabled = $false
    
    try {
        if (-not (SnagitController\Test-SnagitInstalled)) {
            throw "Snagit is required for validation capture, but it is not installed or the Snagit COM automation interface is unavailable."
        }

        # Step 1: Create session
        Write-UIStatus "Creating documentation session..." "Blue"
        $script:CurrentSession = New-DocumentationSession `
            -AppName $script:Controls.txtAppName.Text `
            -AppVersion $script:Controls.txtAppVersion.Text `
            -TicketNumber "AUTO" `
            -TechName $env:USERNAME
        
        Start-Sleep -Milliseconds 500
        
        # Step 2: Capture Figure 2
        Write-UIStatus "Capturing Figure 2 (Programs & Features)..." "Blue"
        $script:Form.WindowState = 'Minimized'
        Start-Sleep -Milliseconds 500
        
        $outputPath2 = Join-Path $script:CurrentSession.WorkingDirectory "Figure2.jpg"
        $result2 = Invoke-AutomatedInstalledAppsCapture -AppName $script:CurrentSession.AppName -OutputPath $outputPath2
        
        if ($result2.Success) {
            $script:CurrentSession = Update-DocumentationSessionCapture -Session $script:CurrentSession -FigureNumber 2 -FilePath $outputPath2
            Write-UIStatus "Figure 2 captured successfully" "Green"
        } else {
            throw "Figure 2 capture failed"
        }
        
        Start-Sleep -Milliseconds 500
        $script:Form.WindowState = 'Normal'
        $script:Form.BringToFront()
        Start-Sleep -Milliseconds 500
        
        # Step 3: Capture Figure 3
        Write-UIStatus "Capturing Figure 3 (Start Menu)..." "Blue"
        $script:Form.WindowState = 'Minimized'
        Start-Sleep -Milliseconds 500
        
        $outputPath3 = Join-Path $script:CurrentSession.WorkingDirectory "Figure3.jpg"
        $result3 = Invoke-AutomatedStartMenuCapture -AppName $script:CurrentSession.AppName -OutputPath $outputPath3
        
        if ($result3.Success) {
            $script:CurrentSession = Update-DocumentationSessionCapture -Session $script:CurrentSession -FigureNumber 3 -FilePath $outputPath3
            Write-UIStatus "Figure 3 captured successfully" "Green"
        } else {
            throw "Figure 3 capture failed"
        }
        
        Start-Sleep -Milliseconds 500
        $script:Form.WindowState = 'Normal'
        $script:Form.BringToFront()
        Start-Sleep -Milliseconds 500
        
        # Step 4: Collect installation details (elevated)
        Write-UIStatus "Collecting installation details (will prompt for elevation)..." "Blue"
        
        $tempFile = [System.IO.Path]::GetTempFileName()
        $tempFile = $tempFile.Replace('.tmp', '.txt')
        
        $helperScript = ".\scripts\Get-ElevatedInstallInfo.ps1"
        
        if (-not (Test-Path $helperScript)) {
            throw "Helper script not found: $helperScript"
        }
        
        $helperFullPath = (Resolve-Path $helperScript).Path
        
        $wrapperScript = [System.IO.Path]::GetTempFileName()
        $wrapperScript = $wrapperScript.Replace('.tmp', '.ps1')
        
        $wrapperContent = @"
#Requires -Version 5.1
`$helperScriptPath = '$($helperFullPath.Replace("'", "''"))'
`$appName = '$($script:CurrentSession.AppName.Replace("'", "''"))'
`$outputFile = '$($tempFile.Replace("'", "''"))'

& "`$helperScriptPath" -AppName "`$appName" -OutputFile "`$outputFile"
exit `$LASTEXITCODE
"@
        
        $utf8 = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($wrapperScript, $wrapperContent, $utf8)
        
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$wrapperScript`""
        $process = Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments -Wait -PassThru
        
        Remove-Item $wrapperScript -Force -ErrorAction SilentlyContinue
        
        if ($process.ExitCode -ne 0) {
            throw "Installation details collection failed or was cancelled"
        }
        
        if (Test-Path $tempFile) {
            $rawOutput = Get-Content $tempFile -Raw -Encoding UTF8
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            
            # Parse the helper output into sections
            $parsed = Parse-HelperOutput -RawOutput $rawOutput
            
            $script:CurrentSession = Update-DocumentationSessionDetails `
                -Session $script:CurrentSession `
                -InstallDirectory $parsed.InstallDirs `
                -RegistryKeys $parsed.ConfigKeys `
                -ServicesCreated $parsed.Services `
                -UninstallKeys $parsed.UninstallKeys
            
            Write-UIStatus "Installation details collected successfully" "Green"
        } else {
            throw "Installation details file not created"
        }
        
        Start-Sleep -Milliseconds 500
        
        # Step 5: Generate validation document
        Write-UIStatus "Generating validation document..." "Blue"
        
        $doc = New-ValidationDocument `
            -AppName $script:CurrentSession.AppName `
            -AppVersion $script:CurrentSession.AppVersion `
            -TicketNumber "AUTO-GENERATED" `
            -TechName $env:USERNAME `
            -OSVersion $script:CurrentSession.OSVersion
        
        if ($script:CurrentSession.Captures.Figure2) {
            $doc = Add-ValidationScreenshot -HtmlContent $doc -FigureNumber 2 -ImagePath $script:CurrentSession.Captures.Figure2
        }
        if ($script:CurrentSession.Captures.Figure3) {
            $doc = Add-ValidationScreenshot -HtmlContent $doc -FigureNumber 3 -ImagePath $script:CurrentSession.Captures.Figure3
        }
        # Format data for HTML (replace newlines with <br> tags)
        $formattedDirs = $script:CurrentSession.InstallDetails.InstallDirectory.Replace([Environment]::NewLine, '<br>')
        $formattedKeys = $script:CurrentSession.InstallDetails.RegistryKeys.Replace([Environment]::NewLine, '<br>')
        $formattedUninstall = $script:CurrentSession.InstallDetails.UninstallKeys.Replace([Environment]::NewLine, '<br>')
        
        $doc = Set-ValidationDetails `
            -HtmlContent $doc `
            -InstallDirectory $formattedDirs `
            -RegistryKeys $formattedKeys `
            -ServicesCreated $script:CurrentSession.InstallDetails.ServicesCreated `
            -UninstallKeys $formattedUninstall
        
        $docFolder = ".\documentation"
        if (-not (Test-Path $docFolder)) {
            New-Item -ItemType Directory -Path $docFolder -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $fileName = "$($script:CurrentSession.AppName)_$($script:CurrentSession.AppVersion)_Validation_$timestamp.html"
        $fileName = $fileName.Replace(' ', '_')
        $outputPath = Join-Path $docFolder $fileName
        
        Export-ValidationDocument -HtmlContent $doc -OutputPath $outputPath
        
        # Session cleanup handled by setting to null
        
        Write-UIStatus "Documentation complete." "Green"
        
        # Reset UI
        $script:CurrentSession = $null
        $script:Controls.txtAppName.Text = ""
        $script:Controls.txtAppVersion.Text = ""
        $script:Controls.txtAppName.Enabled = $true
        $script:Controls.txtAppVersion.Enabled = $true
        $script:Controls.btnStart.Enabled = $true
        Write-UIStatus "Ready for next documentation session" "Black"

        return @{
            Success = $true
            Message = "Validation documentation completed successfully."
            OutputPath = $outputPath
        }
        
    } catch {
        Write-UIStatus "Error: $($_.Exception.Message)" "Red"
        [System.Windows.Forms.MessageBox]::Show("Error occurred:" + [Environment]::NewLine + [Environment]::NewLine + $_.Exception.Message, "Error", 'OK', 'Error')
        
        # Re-enable UI
        $script:Controls.txtAppName.Enabled = $true
        $script:Controls.txtAppVersion.Enabled = $true
        $script:Controls.btnStart.Enabled = $true

        return @{
            Success = $false
            Message = $_.Exception.Message
            OutputPath = ""
        }
    }
}

#endregion

function Invoke-DocumentationCaptureFromContext {
    <#
    .SYNOPSIS
        Runs automated documentation workflow without manual data-entry GUI.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppName,

        [Parameter(Mandatory = $true)]
        [string]$AppVersion
    )

    if ([string]::IsNullOrWhiteSpace($AppName)) {
        throw "AppName is required."
    }
    if ([string]::IsNullOrWhiteSpace($AppVersion)) {
        throw "AppVersion is required."
    }

    # Create lightweight hidden UI objects so existing workflow can run unchanged.
    $script:Form = New-Object System.Windows.Forms.Form
    $script:Controls = @{}
    $script:Controls.StatusLabel = New-Object System.Windows.Forms.Label
    $script:Controls.txtAppName = New-Object System.Windows.Forms.TextBox
    $script:Controls.txtAppVersion = New-Object System.Windows.Forms.TextBox
    $script:Controls.btnStart = New-Object System.Windows.Forms.Button

    $script:Controls.txtAppName.Text = $AppName
    $script:Controls.txtAppVersion.Text = $AppVersion

    return (Start-AutomatedDocumentation)
}


function Parse-HelperOutput {
    param([string]$RawOutput)
    
    $sections = @{
        UninstallKeys = ""
        ConfigKeys = ""
        StartMenu = ""
        Services = ""
        InstallDirs = ""
    }
    
    # Parse UNINSTALL REGISTRY KEYS
    $uninstallStart = $RawOutput.IndexOf('[UNINSTALL REGISTRY KEYS]')
    $configStart = $RawOutput.IndexOf('[CONFIGURATION REGISTRY KEYS]')
    if ($uninstallStart -ge 0 -and $configStart -gt $uninstallStart) {
        $sections.UninstallKeys = $RawOutput.Substring($uninstallStart + 26, $configStart - $uninstallStart - 26).Trim()
    }
    
    # Parse CONFIGURATION REGISTRY KEYS
    $startMenuStart = $RawOutput.IndexOf('[START MENU ENTRIES]')
    if ($configStart -ge 0 -and $startMenuStart -gt $configStart) {
        $sections.ConfigKeys = $RawOutput.Substring($configStart + 28, $startMenuStart - $configStart - 28).Trim()
    }
    
    # Parse START MENU ENTRIES
    $servicesStart = $RawOutput.IndexOf('[SERVICES]')
    if ($startMenuStart -ge 0 -and $servicesStart -gt $startMenuStart) {
        $sections.StartMenu = $RawOutput.Substring($startMenuStart + 20, $servicesStart - $startMenuStart - 20).Trim()
    }
    
    # Parse SERVICES
    $installDirsStart = $RawOutput.IndexOf('[INSTALLATION DIRECTORIES]')
    if ($servicesStart -ge 0 -and $installDirsStart -gt $servicesStart) {
        $sections.Services = $RawOutput.Substring($servicesStart + 10, $installDirsStart - $servicesStart - 10).Trim()
    }
    
    # Parse INSTALLATION DIRECTORIES
    $completeMarker = $RawOutput.IndexOf('=== COLLECTION COMPLETE ===')
    if ($installDirsStart -ge 0) {
        if ($completeMarker -gt $installDirsStart) {
            $sections.InstallDirs = $RawOutput.Substring($installDirsStart + 27, $completeMarker - $installDirsStart - 27).Trim()
        } else {
            $sections.InstallDirs = $RawOutput.Substring($installDirsStart + 27).Trim()
        }
    }
    
    return $sections
}
#region Public Functions

function Show-DocumentationCaptureUI {
    <#
    .SYNOPSIS
        Displays the simplified automated documentation GUI
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$AppName = "",

        [Parameter(Mandatory = $false)]
        [string]$AppVersion = ""
    )

    $script:UiRunResult = $null
    
    # Create form
    $script:Form = New-Object System.Windows.Forms.Form
    $Form.Text = "Automated Documentation Tool"
    $Form.Size = New-Object System.Drawing.Size(600, 400)
    $Form.StartPosition = "CenterScreen"
    $Form.FormBorderStyle = "FixedDialog"
    $Form.MaximizeBox = $false
    $Form.TopMost = $true
    $Form.BackColor = [System.Drawing.Color]::WhiteSmoke
    
    # Title
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Location = New-Object System.Drawing.Point(20, 20)
    $lblTitle.Size = New-Object System.Drawing.Size(560, 40)
    $lblTitle.Text = "Automated Validation Documentation"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(112, 48, 160)
    $lblTitle.TextAlign = "MiddleCenter"
    $Form.Controls.Add($lblTitle)
    
    # Instructions
    $lblInst = New-Object System.Windows.Forms.Label
    $lblInst.Location = New-Object System.Drawing.Point(40, 70)
    $lblInst.Size = New-Object System.Drawing.Size(520, 40)
    $lblInst.Text = "Fill in the application details and click Start Documentation." + [Environment]::NewLine + "Everything else will be automated!"
    $lblInst.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $lblInst.TextAlign = "TopCenter"
    $Form.Controls.Add($lblInst)
    
    # App Name
    $lblApp = New-Object System.Windows.Forms.Label
    $lblApp.Location = New-Object System.Drawing.Point(80, 130)
    $lblApp.Size = New-Object System.Drawing.Size(120, 25)
    $lblApp.Text = "App Name:"
    $lblApp.Font = New-Object System.Drawing.Font("Segoe UI", 12)
    $Form.Controls.Add($lblApp)
    
    $script:Controls.txtAppName = New-Object System.Windows.Forms.TextBox
    $Controls.txtAppName.Location = New-Object System.Drawing.Point(210, 130)
    $Controls.txtAppName.Size = New-Object System.Drawing.Size(300, 25)
    $Controls.txtAppName.Font = New-Object System.Drawing.Font("Segoe UI", 12)
    $Form.Controls.Add($Controls.txtAppName)

    if (-not [string]::IsNullOrWhiteSpace($AppName)) {
        $script:Controls.txtAppName.Text = $AppName
    }
    
    # Version
    $lblVer = New-Object System.Windows.Forms.Label
    $lblVer.Location = New-Object System.Drawing.Point(80, 170)
    $lblVer.Size = New-Object System.Drawing.Size(120, 25)
    $lblVer.Text = "Version:"
    $lblVer.Font = New-Object System.Drawing.Font("Segoe UI", 12)
    $Form.Controls.Add($lblVer)
    
    $script:Controls.txtAppVersion = New-Object System.Windows.Forms.TextBox
    $Controls.txtAppVersion.Location = New-Object System.Drawing.Point(210, 170)
    $Controls.txtAppVersion.Size = New-Object System.Drawing.Size(300, 25)
    $Controls.txtAppVersion.Font = New-Object System.Drawing.Font("Segoe UI", 12)
    $Form.Controls.Add($Controls.txtAppVersion)

    if (-not [string]::IsNullOrWhiteSpace($AppVersion)) {
        $script:Controls.txtAppVersion.Text = $AppVersion
    }
    
    # Start Button
    $script:Controls.btnStart = New-Object System.Windows.Forms.Button
    $Controls.btnStart.Location = New-Object System.Drawing.Point(150, 220)
    $Controls.btnStart.Size = New-Object System.Drawing.Size(300, 50)
    $Controls.btnStart.Text = "Start Documentation"
    $Controls.btnStart.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $Controls.btnStart.BackColor = [System.Drawing.Color]::FromArgb(0, 176, 80)
    $Controls.btnStart.ForeColor = [System.Drawing.Color]::White
    $Controls.btnStart.FlatStyle = "Flat"
    $Controls.btnStart.Add_Click({
        $runResult = Start-AutomatedDocumentation
        if ($runResult) {
            $script:UiRunResult = $runResult
            if ($runResult.Success) {
                $script:Form.DialogResult = [System.Windows.Forms.DialogResult]::OK
                $script:Form.Close()
            }
        }
    })
    $Form.Controls.Add($Controls.btnStart)
    
    # Status
    $script:Controls.StatusLabel = New-Object System.Windows.Forms.Label
    $Controls.StatusLabel.Location = New-Object System.Drawing.Point(20, 290)
    $Controls.StatusLabel.Size = New-Object System.Drawing.Size(560, 30)
    $Controls.StatusLabel.Text = "Ready - Enter app details and click Start"
    $Controls.StatusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Italic)
    $Controls.StatusLabel.TextAlign = "MiddleCenter"
    $Form.Controls.Add($Controls.StatusLabel)
    
    # Footer
    $lblFooter = New-Object System.Windows.Forms.Label
    $lblFooter.Location = New-Object System.Drawing.Point(20, 320)
    $lblFooter.Size = New-Object System.Drawing.Size(560, 30)
    $lblFooter.Text = "Automated workflow: Figure 2 -> Figure 3 -> Installation Details -> Report"
    $lblFooter.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
    $lblFooter.ForeColor = [System.Drawing.Color]::Gray
    $lblFooter.TextAlign = "MiddleCenter"
    $Form.Controls.Add($lblFooter)
    
    # Show form
    [void]$Form.ShowDialog()

    if ($script:UiRunResult) {
        return $script:UiRunResult
    }

    return @{
        Success = $false
        Message = "Validation documentation was closed before completion."
        OutputPath = ""
    }
}

#endregion

# Export public functions
Export-ModuleMember -Function @(
    'Show-DocumentationCaptureUI',
    'Invoke-DocumentationCaptureFromContext'
)