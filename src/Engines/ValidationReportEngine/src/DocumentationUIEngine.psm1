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
Import-Module (Join-Path $PSScriptRoot "VendorDocumentationEngine.psm1") -Force -ErrorAction Stop

#region Private Variables

$script:CurrentSession = $null
$script:Form = $null
$script:Controls = @{}
$script:UiRunResult = $null
$script:CurrentAppVendor = ""

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

function Resolve-ElevatedInstallInfoScriptPath {
    [CmdletBinding()]
    param()

    $candidatePaths = @(
        (Join-Path (Split-Path -Parent $PSScriptRoot) "scripts\Get-ElevatedInstallInfo.ps1"),
        (Join-Path $PSScriptRoot "..\..\..\..\Validation Report\scripts\Get-ElevatedInstallInfo.ps1"),
        (Join-Path (Get-Location).Path "scripts\Get-ElevatedInstallInfo.ps1")
    )

    foreach ($candidatePath in $candidatePaths) {
        if (Test-Path $candidatePath) {
            return (Resolve-Path $candidatePath).Path
        }
    }

    throw "Get-ElevatedInstallInfo.ps1 not found. Checked: $($candidatePaths -join '; ')"
}

function Show-CaptureNameOverrideDialog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InitialName,

        [int]$CountdownSeconds = 20
    )

    $remaining = if ($CountdownSeconds -lt 5) { 5 } else { $CountdownSeconds }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Validation Capture Name"
    $form.Size = New-Object System.Drawing.Size(620, 300)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true

    $lblPrompt = New-Object System.Windows.Forms.Label
    $lblPrompt.Location = New-Object System.Drawing.Point(20, 20)
    $lblPrompt.Size = New-Object System.Drawing.Size(560, 48)
    $lblPrompt.Text = "Set names independently for each capture target. Use only the boxes that need changes."
    $lblPrompt.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $form.Controls.Add($lblPrompt)

    $lblInstalledApps = New-Object System.Windows.Forms.Label
    $lblInstalledApps.Location = New-Object System.Drawing.Point(20, 76)
    $lblInstalledApps.Size = New-Object System.Drawing.Size(560, 20)
    $lblInstalledApps.Text = "Installed Apps Name (Figure 2):"
    $lblInstalledApps.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lblInstalledApps)

    $txtInstalledAppsName = New-Object System.Windows.Forms.TextBox
    $txtInstalledAppsName.Location = New-Object System.Drawing.Point(20, 98)
    $txtInstalledAppsName.Size = New-Object System.Drawing.Size(560, 28)
    $txtInstalledAppsName.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $txtInstalledAppsName.Text = $InitialName
    $form.Controls.Add($txtInstalledAppsName)

    $lblStartMenu = New-Object System.Windows.Forms.Label
    $lblStartMenu.Location = New-Object System.Drawing.Point(20, 136)
    $lblStartMenu.Size = New-Object System.Drawing.Size(560, 20)
    $lblStartMenu.Text = "Start Menu Name (Figure 3 / Figure 4):"
    $lblStartMenu.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lblStartMenu)

    $txtStartMenuName = New-Object System.Windows.Forms.TextBox
    $txtStartMenuName.Location = New-Object System.Drawing.Point(20, 158)
    $txtStartMenuName.Size = New-Object System.Drawing.Size(560, 28)
    $txtStartMenuName.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $txtStartMenuName.Text = $InitialName
    $form.Controls.Add($txtStartMenuName)

    $lblCountdown = New-Object System.Windows.Forms.Label
    $lblCountdown.Location = New-Object System.Drawing.Point(20, 196)
    $lblCountdown.Size = New-Object System.Drawing.Size(560, 24)
    $lblCountdown.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Italic)
    $lblCountdown.ForeColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
    $lblCountdown.Text = "Capture begins automatically in $remaining seconds."
    $form.Controls.Add($lblCountdown)

    $btnStart = New-Object System.Windows.Forms.Button
    $btnStart.Text = "Start Capture Now"
    $btnStart.Location = New-Object System.Drawing.Point(420, 226)
    $btnStart.Size = New-Object System.Drawing.Size(160, 32)
    $btnStart.BackColor = [System.Drawing.Color]::FromArgb(0, 176, 80)
    $btnStart.ForeColor = [System.Drawing.Color]::White
    $btnStart.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnStart.Add_Click({
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })
    $form.Controls.Add($btnStart)

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000
    $timer.Add_Tick({
        $remaining--
        $lblCountdown.Text = "Capture begins automatically in $remaining seconds."
        if ($remaining -le 0) {
            $timer.Stop()
            $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $form.Close()
        }
    })

    $form.Add_Shown({ $timer.Start() })
    $form.Add_FormClosed({ $timer.Stop(); $timer.Dispose() })

    [void]$form.ShowDialog()

    $selectedInstalledAppsName = if (-not [string]::IsNullOrWhiteSpace($txtInstalledAppsName.Text)) {
        $txtInstalledAppsName.Text.Trim()
    }
    else {
        $InitialName
    }

    $selectedStartMenuName = if (-not [string]::IsNullOrWhiteSpace($txtStartMenuName.Text)) {
        $txtStartMenuName.Text.Trim()
    }
    else {
        $InitialName
    }

    if ([string]::IsNullOrWhiteSpace($selectedInstalledAppsName)) {
        $selectedInstalledAppsName = $InitialName
    }
    if ([string]::IsNullOrWhiteSpace($selectedStartMenuName)) {
        $selectedStartMenuName = $InitialName
    }

    return @{
        InstalledAppsName = $selectedInstalledAppsName
        StartMenuName = $selectedStartMenuName
    }
}

function Get-MissingCaptureFigures {
    param([Parameter(Mandatory = $true)]$Session)

    $missing = New-Object System.Collections.Generic.List[int]
    if (-not $Session.Captures.Figure2) { $missing.Add(2) }
    if (-not $Session.Captures.Figure3) { $missing.Add(3) }
    if (-not $Session.Captures.Figure4) { $missing.Add(4) }
    if (-not $Session.Captures.Figure5) { $missing.Add(5) }
    return @($missing)
}

function Get-ManualCaptureFilePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Folder,

        [Parameter(Mandatory = $true)]
        [int]$FigureNumber
    )

    $candidates = @(
        (Join-Path $Folder ("Figure{0}.jpg" -f $FigureNumber)),
        (Join-Path $Folder ("Figure{0}.jpeg" -f $FigureNumber)),
        (Join-Path $Folder ("Figure{0}.png" -f $FigureNumber))
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }

    return $null
}

function Show-CaptureFailureActionDialog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$FigureNumber,

        [Parameter(Mandatory = $true)]
        [string]$FailureReason
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Capture Step Needs Action"
    $form.Size = New-Object System.Drawing.Size(700, 300)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true
    $form.KeyPreview = $true

    $lblMessage = New-Object System.Windows.Forms.Label
    $lblMessage.Location = New-Object System.Drawing.Point(20, 20)
    $lblMessage.Size = New-Object System.Drawing.Size(650, 120)
    $lblMessage.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $lblMessage.Text = "Figure $FigureNumber capture failed.`r`n`r`nReason: $FailureReason`r`n`r`nChoose Retry to try automated capture again, Skip (Alt+S or Esc) to continue to the next figure, or Cancel to stop the run."
    $form.Controls.Add($lblMessage)

    $decision = 'Cancel'

    $btnRetry = New-Object System.Windows.Forms.Button
    $btnRetry.Text = "&Retry"
    $btnRetry.Location = New-Object System.Drawing.Point(330, 200)
    $btnRetry.Size = New-Object System.Drawing.Size(100, 32)
    $btnRetry.Add_Click({
        $script:DecisionValue = 'Retry'
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })
    $form.Controls.Add($btnRetry)

    $btnSkip = New-Object System.Windows.Forms.Button
    $btnSkip.Text = "&Skip"
    $btnSkip.Location = New-Object System.Drawing.Point(440, 200)
    $btnSkip.Size = New-Object System.Drawing.Size(100, 32)
    $btnSkip.Add_Click({
        $script:DecisionValue = 'Skip'
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })
    $form.Controls.Add($btnSkip)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Cancel"
    $btnCancel.Location = New-Object System.Drawing.Point(550, 200)
    $btnCancel.Size = New-Object System.Drawing.Size(100, 32)
    $btnCancel.Add_Click({
        $script:DecisionValue = 'Cancel'
        $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $form.Close()
    })
    $form.Controls.Add($btnCancel)

    $form.CancelButton = $btnSkip
    $script:DecisionValue = 'Cancel'

    $form.Add_KeyDown({
        if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
            $script:DecisionValue = 'Skip'
            $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $form.Close()
        }
    })

    [void]$form.ShowDialog()
    $decision = $script:DecisionValue
    Remove-Variable -Scope Script -Name DecisionValue -ErrorAction SilentlyContinue
    return $decision
}

function Show-ManualCaptureChecklistDialog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Session
    )

    $folder = $Session.WorkingDirectory
    $status = @{}
    $status[2] = $null
    $status[3] = $null
    $status[4] = $null
    $status[5] = $null

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Manual Screenshot Checklist"
    $form.Size = New-Object System.Drawing.Size(760, 470)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true

    $lblIntro = New-Object System.Windows.Forms.Label
    $lblIntro.Location = New-Object System.Drawing.Point(20, 20)
    $lblIntro.Size = New-Object System.Drawing.Size(700, 65)
    $lblIntro.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $lblIntro.Text = "Manual capture mode is active. Save screenshots into the folder below using the exact names Figure2, Figure3, Figure4, and Figure5 (jpg, jpeg, or png).`r`nThe report will only generate after all required files are present."
    $form.Controls.Add($lblIntro)

    $txtFolder = New-Object System.Windows.Forms.TextBox
    $txtFolder.Location = New-Object System.Drawing.Point(20, 92)
    $txtFolder.Size = New-Object System.Drawing.Size(700, 24)
    $txtFolder.ReadOnly = $true
    $txtFolder.Text = $folder
    $form.Controls.Add($txtFolder)

    $lstChecklist = New-Object System.Windows.Forms.ListBox
    $lstChecklist.Location = New-Object System.Drawing.Point(20, 130)
    $lstChecklist.Size = New-Object System.Drawing.Size(700, 220)
    $lstChecklist.Font = New-Object System.Drawing.Font("Consolas", 10)
    $form.Controls.Add($lstChecklist)

    $lblHint = New-Object System.Windows.Forms.Label
    $lblHint.Location = New-Object System.Drawing.Point(20, 360)
    $lblHint.Size = New-Object System.Drawing.Size(700, 24)
    $lblHint.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
    $lblHint.Text = "Use Refresh after each screenshot. Click Continue when all are marked Ready."
    $form.Controls.Add($lblHint)

    $btnOpenFolder = New-Object System.Windows.Forms.Button
    $btnOpenFolder.Text = "Open Folder"
    $btnOpenFolder.Location = New-Object System.Drawing.Point(20, 395)
    $btnOpenFolder.Size = New-Object System.Drawing.Size(120, 32)
    $btnOpenFolder.Add_Click({
        Start-Process explorer.exe $folder
    })
    $form.Controls.Add($btnOpenFolder)

    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text = "Refresh"
    $btnRefresh.Location = New-Object System.Drawing.Point(150, 395)
    $btnRefresh.Size = New-Object System.Drawing.Size(120, 32)
    $form.Controls.Add($btnRefresh)

    $btnContinue = New-Object System.Windows.Forms.Button
    $btnContinue.Text = "Continue"
    $btnContinue.Location = New-Object System.Drawing.Point(470, 395)
    $btnContinue.Size = New-Object System.Drawing.Size(120, 32)
    $btnContinue.Enabled = $false
    $form.Controls.Add($btnContinue)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Cancel"
    $btnCancel.Location = New-Object System.Drawing.Point(600, 395)
    $btnCancel.Size = New-Object System.Drawing.Size(120, 32)
    $form.Controls.Add($btnCancel)

    $refreshState = {
        $lstChecklist.Items.Clear()
        foreach ($figure in 2..5) {
            $path = Get-ManualCaptureFilePath -Folder $folder -FigureNumber $figure
            $status[$figure] = $path
            if ($path) {
                [void]$lstChecklist.Items.Add(("[Ready] Figure{0} -> {1}" -f $figure, $path))
            } else {
                [void]$lstChecklist.Items.Add(("[Missing] Figure{0} -> save as Figure{0}.jpg/.jpeg/.png" -f $figure))
            }
        }

        $allReady = $true
        foreach ($figure in 2..5) {
            if (-not $status[$figure]) { $allReady = $false; break }
        }
        $btnContinue.Enabled = $allReady
    }

    $btnRefresh.Add_Click({ & $refreshState })
    $btnContinue.Add_Click({
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })
    $btnCancel.Add_Click({
        $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $form.Close()
    })

    & $refreshState
    [void]$form.ShowDialog()

    if ($form.DialogResult -ne [System.Windows.Forms.DialogResult]::OK) {
        return $false
    }

    foreach ($figure in 2..5) {
        if ($status[$figure]) {
            $script:CurrentSession = Update-DocumentationSessionCapture -Session $script:CurrentSession -FigureNumber $figure -FilePath $status[$figure]
        }
    }

    return $true
}

function Start-AutomatedDocumentation {
    param(
        [switch]$ManualOnly,

        [string]$CaptureWorkingDirectory,

        [string]$DocumentationOutputFolder,

        [ValidateSet('System', 'User')]
        [string]$InstallContext = 'System'
    )
    # Validate inputs
    if ([string]::IsNullOrWhiteSpace($script:Controls.txtAppName.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter Application Name", "Required", 'OK', 'Warning')
        return
    }
    
    if ([string]::IsNullOrWhiteSpace($script:Controls.txtAppVersion.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter Application Version", "Required", 'OK', 'Warning')
        return
    }
    
    # Disable controls during processing
    $script:Controls.btnStart.Enabled = $false
    if ($script:Controls.btnManual) { $script:Controls.btnManual.Enabled = $false }
    $script:Controls.txtAppName.Enabled = $false
    $script:Controls.txtAppVersion.Enabled = $false
    
    try {
        # Step 1: Create session
        Write-UIStatus "Creating documentation session..." "Blue"
        if ([string]::IsNullOrWhiteSpace($CaptureWorkingDirectory)) {
            $script:CurrentSession = New-DocumentationSession `
                -AppName $script:Controls.txtAppName.Text `
                -AppVersion $script:Controls.txtAppVersion.Text `
                -TicketNumber "AUTO" `
                -TechName $env:USERNAME
        }
        else {
            $script:CurrentSession = New-DocumentationSession `
                -AppName $script:Controls.txtAppName.Text `
                -AppVersion $script:Controls.txtAppVersion.Text `
                -TicketNumber "AUTO" `
                -TechName $env:USERNAME `
                -WorkingDirectory $CaptureWorkingDirectory
        }
        
        Start-Sleep -Milliseconds 500

        $captureNames = Show-CaptureNameOverrideDialog -InitialName $script:CurrentSession.AppName -CountdownSeconds 20
        $captureInstalledAppsName = if ($captureNames -and -not [string]::IsNullOrWhiteSpace([string]$captureNames.InstalledAppsName)) {
            [string]$captureNames.InstalledAppsName
        } else {
            $script:CurrentSession.AppName
        }
        $captureStartMenuName = if ($captureNames -and -not [string]::IsNullOrWhiteSpace([string]$captureNames.StartMenuName)) {
            [string]$captureNames.StartMenuName
        } else {
            $script:CurrentSession.AppName
        }
        Write-UIStatus "Capture names set. Figure2='$captureInstalledAppsName' Figure3/4/5='$captureStartMenuName'" "Blue"
        Start-Sleep -Milliseconds 500

        # Section 1 vendor documentation is intentionally collected before capture steps.
        $vendorSummary = $null
        Write-UIStatus "Collecting Section 1 vendor documentation..." "Blue"
        try {
            $vendorSummary = Get-VendorDocumentationSummary -Vendor $script:CurrentAppVendor -AppName $script:CurrentSession.AppName -AppVersion $script:CurrentSession.AppVersion
            $sourceCount = 0
            if ($vendorSummary -and $vendorSummary.SourcesUsed) {
                $sourceCount = @($vendorSummary.SourcesUsed).Count
            }
            Write-UIStatus "Section 1 vendor documentation collected (sources: $sourceCount)." "Blue"
            if ($vendorSummary -and -not [string]::IsNullOrWhiteSpace([string]$vendorSummary.Message)) {
                Write-UIStatus "Section 1 details: $([string]$vendorSummary.Message)" "Blue"
            }
        }
        catch {
            $vendorSummary = @{
                OSCompatibility = "The Vendor has nothing to report"
                Prerequisites = "The Vendor has nothing to report"
                ApplicationConflicts = "The Vendor has nothing to report"
                UpgradePaths = "The Vendor has nothing to report"
                SourcesUsed = @()
                Message = "The Vendor has nothing to report"
            }
            Write-UIStatus "Section 1 vendor documentation collection failed; default fallback text will be used." "Orange"
        }
        
        if (-not $ManualOnly) {
            $captureSteps = @(
                @{ Figure = 2; Label = "Programs & Features"; Runner = { param($outPath) Invoke-AutomatedInstalledAppsCapture -AppName $captureInstalledAppsName -OutputPath $outPath } },
                @{ Figure = 3; Label = "Start Menu"; Runner = { param($outPath) Invoke-AutomatedStartMenuCapture -AppName $captureStartMenuName -OutputPath $outPath } },
                @{ Figure = 4; Label = "Application Opened"; Runner = { param($outPath) Invoke-AutomatedApplicationOpenedCapture -AppName $captureStartMenuName -OutputPath $outPath } },
                @{ Figure = 5; Label = "Help/About Window"; Runner = { param($outPath) Invoke-AutomatedAboutWindowCapture -AppName $captureStartMenuName -OutputPath $outPath } }
            )

            foreach ($step in $captureSteps) {
                $captured = $false
                while (-not $captured) {
                    Write-UIStatus ("Capturing Figure {0} ({1})..." -f $step.Figure, $step.Label) "Blue"
                    $script:Form.WindowState = 'Minimized'
                    Start-Sleep -Milliseconds 500

                    $outputPath = Join-Path $script:CurrentSession.WorkingDirectory ("Figure{0}.jpg" -f $step.Figure)
                    $result = & $step.Runner $outputPath

                    Start-Sleep -Milliseconds 500
                    $script:Form.WindowState = 'Normal'
                    $script:Form.BringToFront()
                    Start-Sleep -Milliseconds 500

                    if ($result.Success) {
                        $script:CurrentSession = Update-DocumentationSessionCapture -Session $script:CurrentSession -FigureNumber $step.Figure -FilePath $outputPath
                        Write-UIStatus ("Figure {0} captured successfully" -f $step.Figure) "Green"
                        $captured = $true
                        continue
                    }

                    $reason = if ($result.ErrorMessage) { [string]$result.ErrorMessage } else { "unknown reason" }
                    $action = Show-CaptureFailureActionDialog -FigureNumber $step.Figure -FailureReason $reason
                    if ($action -eq 'Retry') {
                        continue
                    }
                    if ($action -eq 'Skip') {
                        if ($step.Figure -eq 5) {
                            Write-UIStatus "Figure 5 automation skipped. Capture Help/About manually with Snagit and save as Figure5.jpg in the images folder." "Orange"
                            try {
                                Start-Process explorer.exe $script:CurrentSession.WorkingDirectory | Out-Null
                            }
                            catch {
                            }

                            $manualFigure5Path = Get-ManualCaptureFilePath -Folder $script:CurrentSession.WorkingDirectory -FigureNumber 5
                            if (-not $manualFigure5Path) {
                                $manualReady = Show-ManualCaptureChecklistDialog -Session $script:CurrentSession
                                if (-not $manualReady) {
                                    throw "Manual Figure 5 capture was cancelled by technician."
                                }
                                $manualFigure5Path = Get-ManualCaptureFilePath -Folder $script:CurrentSession.WorkingDirectory -FigureNumber 5
                            }

                            if ($manualFigure5Path) {
                                $script:CurrentSession = Update-DocumentationSessionCapture -Session $script:CurrentSession -FigureNumber 5 -FilePath $manualFigure5Path
                                Write-UIStatus "Figure 5 captured manually and accepted." "Green"
                                $captured = $true
                                continue
                            }

                            throw "Manual Figure 5 capture did not produce Figure5.jpg/.jpeg/.png in the images folder."
                        }

                        Write-UIStatus ("Figure {0} skipped. Manual capture will be required later." -f $step.Figure) "Orange"
                        $captured = $true
                        continue
                    }
                    throw "Capture workflow cancelled by technician at Figure $($step.Figure)."
                }
            }
        }

        $missingBeforeManual = Get-MissingCaptureFigures -Session $script:CurrentSession
        if ($missingBeforeManual.Count -gt 0) {
            Write-UIStatus ("Manual capture required for Figure(s): {0}" -f ($missingBeforeManual -join ', ')) "Orange"
            $manualReady = Show-ManualCaptureChecklistDialog -Session $script:CurrentSession
            if (-not $manualReady) {
                throw "Manual capture checklist was cancelled. Report was not generated."
            }
        }

        $missingAfterManual = Get-MissingCaptureFigures -Session $script:CurrentSession
        if ($missingAfterManual.Count -gt 0) {
            throw ("Missing required screenshots: Figure {0}. Report generation is blocked until all required images exist." -f ($missingAfterManual -join ', Figure '))
        }
        
        # Step 5: Collect installation details
        $detailsRunMode = if ($InstallContext -eq 'User') { 'User-level (non-elevated)' } else { 'System-level (elevated)' }
        Write-UIStatus "Collecting installation details ($detailsRunMode)..." "Blue"

        $helperFullPath = Resolve-ElevatedInstallInfoScriptPath
        Write-UIStatus "Installation details helper resolved: $helperFullPath" "Blue"
        $detailsCollected = $false
        $detailsAttempt = 0
        $detailLookupNames = New-Object System.Collections.Generic.List[string]
        if (-not [string]::IsNullOrWhiteSpace([string]$script:CurrentSession.AppName)) {
            [void]$detailLookupNames.Add([string]$script:CurrentSession.AppName)
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$captureInstalledAppsName) -and @($detailLookupNames) -notcontains [string]$captureInstalledAppsName) {
            [void]$detailLookupNames.Add([string]$captureInstalledAppsName)
        }

        while (-not $detailsCollected) {
            $detailsAttempt++
            $attemptFailureReason = "Unknown failure"
            foreach ($lookupName in @($detailLookupNames)) {
                if ([string]::IsNullOrWhiteSpace([string]$lookupName)) {
                    continue
                }

                $tempFile = [System.IO.Path]::GetTempFileName()
                $tempFile = $tempFile.Replace('.tmp', '.txt')

                $wrapperScript = [System.IO.Path]::GetTempFileName()
                $wrapperScript = $wrapperScript.Replace('.tmp', '.ps1')

                $wrapperContent = @"
#Requires -Version 5.1
`$helperScriptPath = '$($helperFullPath.Replace("'", "''"))'
`$appName = '$($lookupName.Replace("'", "''"))'
`$outputFile = '$($tempFile.Replace("'", "''"))'

& "`$helperScriptPath" -AppName "`$appName" -OutputFile "`$outputFile"
exit `$LASTEXITCODE
"@

                $utf8 = New-Object System.Text.UTF8Encoding $false
                [System.IO.File]::WriteAllText($wrapperScript, $wrapperContent, $utf8)

                $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$wrapperScript`""
                $process = $null
                try {
                    Write-UIStatus "Installation details lookup using app identity '$lookupName'..." "Blue"
                    if ($InstallContext -eq 'User') {
                        $process = Start-Process powershell.exe -ArgumentList $arguments -Wait -PassThru -ErrorAction Stop
                    }
                    else {
                        $process = Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments -Wait -PassThru -ErrorAction Stop
                    }
                }
                catch {
                    $attemptFailureReason = if ($InstallContext -eq 'User') {
                        "User-level helper launch failed: $($_.Exception.Message)"
                    }
                    else {
                        "Elevation launch failed: $($_.Exception.Message)"
                    }
                }

                Remove-Item $wrapperScript -Force -ErrorAction SilentlyContinue

                if ($null -ne $process -and $process.ExitCode -eq 0 -and (Test-Path $tempFile)) {
                    try {
                        $rawOutput = Get-Content $tempFile -Raw -Encoding UTF8

                        # Parse the helper output into sections
                        $parsed = Parse-HelperOutput -RawOutput $rawOutput

                        $script:CurrentSession = Update-DocumentationSessionDetails `
                            -Session $script:CurrentSession `
                            -InstallDirectory $parsed.InstallDirs `
                            -RegistryKeys $parsed.ConfigKeys `
                            -ServicesCreated $parsed.Services `
                            -UninstallKeys $parsed.UninstallKeys

                        $detailsCollected = $true
                        Write-UIStatus "Installation details collected successfully" "Green"
                        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                        break
                    }
                    catch {
                        $attemptFailureReason = "Helper output parsing failed for '$lookupName': $($_.Exception.Message)"
                    }
                    finally {
                        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                    }
                }
                else {
                    $exitCode = if ($null -ne $process) { [string]$process.ExitCode } else { "no process" }
                    if (Test-Path $tempFile) {
                        $rawOutput = Get-Content $tempFile -Raw -Encoding UTF8
                        $preview = if ([string]::IsNullOrWhiteSpace($rawOutput)) { "(no output)" } else { $rawOutput.Trim() }
                        if ($preview.Length -gt 300) {
                            $preview = $preview.Substring(0, 300) + "..."
                        }
                        $attemptFailureReason = "Helper exited with code $exitCode for '$lookupName'. Output: $preview"
                    }
                    else {
                        $attemptFailureReason = "Helper exited with code $exitCode for '$lookupName' and produced no output file."
                    }
                }

                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            }

            if ($detailsCollected) {
                continue
            }

            Write-UIStatus "Installation details attempt $detailsAttempt failed: $attemptFailureReason" "Orange"

            $response = [System.Windows.Forms.MessageBox]::Show(
                "Installation details collection failed.`n`nMode: $detailsRunMode`nReason: $attemptFailureReason`n`nYes = Retry collection`nNo = Continue without details`nCancel = Stop validation workflow",
                "Installation Details Collection",
                [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )

            if ($response -eq [System.Windows.Forms.DialogResult]::Yes) {
                Write-UIStatus "Retrying installation details collection..." "Orange"
                continue
            }

            if ($response -eq [System.Windows.Forms.DialogResult]::No) {
                Write-UIStatus "Installation details skipped by technician." "Orange"
                break
            }

            throw "Installation details collection failed: $attemptFailureReason"
        }
        
        Start-Sleep -Milliseconds 500
        
        # Step 6: Generate validation document
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
        if ($script:CurrentSession.Captures.Figure4) {
            $doc = Add-ValidationScreenshot -HtmlContent $doc -FigureNumber 4 -ImagePath $script:CurrentSession.Captures.Figure4
        }
        if ($script:CurrentSession.Captures.Figure5) {
            $doc = Add-ValidationScreenshot -HtmlContent $doc -FigureNumber 5 -ImagePath $script:CurrentSession.Captures.Figure5
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

        $doc = Set-VendorDocumentationDetails `
            -HtmlContent $doc `
            -OSCompatibilityText $vendorSummary.OSCompatibility `
            -PrerequisitesText $vendorSummary.Prerequisites `
            -ApplicationConflictsText $vendorSummary.ApplicationConflicts `
            -UpgradePathsText $vendorSummary.UpgradePaths

        if ($doc -match '\[OS_COMPATIBILITY_CONTENT\]|\[CONFLICT_CONTENT\]|\[PREREQUISITE_CONTENT\]|\[UPGRADE_PATH_CONTENT\]') {
            Write-UIStatus "Section 1 placeholders remained after rendering; applying explicit fallback content." "Orange"
            $doc = $doc.Replace('[OS_COMPATIBILITY_CONTENT]', '<li>The Vendor has nothing to report</li>')
            $doc = $doc.Replace('[CONFLICT_CONTENT]', '<li>The Vendor has nothing to report</li>')
            $doc = $doc.Replace('[PREREQUISITE_CONTENT]', '<li>The Vendor has nothing to report</li>')
            $doc = $doc.Replace('[UPGRADE_PATH_CONTENT]', '<li>The Vendor has nothing to report</li>')
        }
        if ($doc -match '\[INSTALLATION_DETAILS_CONTENT\]') {
            Write-UIStatus "Section 3 placeholder remained after rendering; applying explicit fallback content." "Orange"
            $doc = $doc.Replace('[INSTALLATION_DETAILS_CONTENT]', '<p>The Publisher has not provided additional system details</p>')
        }
        
        $docFolder = if ([string]::IsNullOrWhiteSpace($DocumentationOutputFolder)) {
            ".\documentation"
        }
        else {
            $DocumentationOutputFolder
        }
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
        Close-Snagit
        Close-InstalledAppsWindow
        
        # Reset UI
        $script:CurrentSession = $null
        $script:Controls.txtAppName.Text = ""
        $script:Controls.txtAppVersion.Text = ""
        $script:Controls.txtAppName.Enabled = $true
        $script:Controls.txtAppVersion.Enabled = $true
        $script:Controls.btnStart.Enabled = $true
        if ($script:Controls.btnManual) { $script:Controls.btnManual.Enabled = $true }
        Write-UIStatus "Ready for next documentation session" "Black"

        return @{
            Success = $true
            Message = "Validation documentation completed successfully."
            OutputPath = $outputPath
        }
        
    } catch {
        Close-Snagit
        Close-InstalledAppsWindow
        Write-UIStatus "Error: $($_.Exception.Message)" "Red"
        [System.Windows.Forms.MessageBox]::Show("Error occurred:" + [Environment]::NewLine + [Environment]::NewLine + $_.Exception.Message, "Error", 'OK', 'Error')
        
        # Re-enable UI
        $script:Controls.txtAppName.Enabled = $true
        $script:Controls.txtAppVersion.Enabled = $true
        $script:Controls.btnStart.Enabled = $true
        if ($script:Controls.btnManual) { $script:Controls.btnManual.Enabled = $true }

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
        [Parameter(Mandatory = $false)]
        [string]$AppVendor = "",

        [Parameter(Mandatory = $true)]
        [string]$AppName,

        [Parameter(Mandatory = $true)]
        [string]$AppVersion

        ,

        [Parameter(Mandatory = $false)]
        [string]$CaptureWorkingDirectory = ""

        ,

        [Parameter(Mandatory = $false)]
        [string]$DocumentationOutputFolder = ""

        ,

        [Parameter(Mandatory = $false)]
        [ValidateSet('System', 'User')]
        [string]$InstallContext = 'System'
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
    $script:CurrentAppVendor = $AppVendor

    return (Start-AutomatedDocumentation -CaptureWorkingDirectory $CaptureWorkingDirectory -DocumentationOutputFolder $DocumentationOutputFolder -InstallContext $InstallContext)
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
        [string]$AppVersion = "",

        [Parameter(Mandatory = $false)]
        [string]$CaptureWorkingDirectory = "",

        [Parameter(Mandatory = $false)]
        [string]$DocumentationOutputFolder = "",

        [Parameter(Mandatory = $false)]
        [ValidateSet('System', 'User')]
        [string]$InstallContext = 'System'
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
    $Controls.btnStart.Location = New-Object System.Drawing.Point(80, 220)
    $Controls.btnStart.Size = New-Object System.Drawing.Size(240, 50)
    $Controls.btnStart.Text = "Start Auto/Hybrid"
    $Controls.btnStart.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $Controls.btnStart.BackColor = [System.Drawing.Color]::FromArgb(0, 176, 80)
    $Controls.btnStart.ForeColor = [System.Drawing.Color]::White
    $Controls.btnStart.FlatStyle = "Flat"
    $Controls.btnStart.Add_Click({
        $runResult = Start-AutomatedDocumentation -CaptureWorkingDirectory $CaptureWorkingDirectory -DocumentationOutputFolder $DocumentationOutputFolder -InstallContext $InstallContext
        if ($runResult) {
            $script:UiRunResult = $runResult
            if ($runResult.Success) {
                $script:Form.DialogResult = [System.Windows.Forms.DialogResult]::OK
                $script:Form.Close()
            }
        }
    })
    $Form.Controls.Add($Controls.btnStart)

    # Manual Button
    $script:Controls.btnManual = New-Object System.Windows.Forms.Button
    $Controls.btnManual.Location = New-Object System.Drawing.Point(330, 220)
    $Controls.btnManual.Size = New-Object System.Drawing.Size(190, 50)
    $Controls.btnManual.Text = "Manual Capture"
    $Controls.btnManual.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $Controls.btnManual.BackColor = [System.Drawing.Color]::FromArgb(255, 192, 0)
    $Controls.btnManual.ForeColor = [System.Drawing.Color]::Black
    $Controls.btnManual.FlatStyle = "Flat"
    $Controls.btnManual.Add_Click({
        $runResult = Start-AutomatedDocumentation -ManualOnly -CaptureWorkingDirectory $CaptureWorkingDirectory -DocumentationOutputFolder $DocumentationOutputFolder -InstallContext $InstallContext
        if ($runResult) {
            $script:UiRunResult = $runResult
            if ($runResult.Success) {
                $script:Form.DialogResult = [System.Windows.Forms.DialogResult]::OK
                $script:Form.Close()
            }
        }
    })
    $Form.Controls.Add($Controls.btnManual)
    
    # Status
    $script:Controls.StatusLabel = New-Object System.Windows.Forms.Label
    $Controls.StatusLabel.Location = New-Object System.Drawing.Point(20, 290)
    $Controls.StatusLabel.Size = New-Object System.Drawing.Size(560, 30)
    $Controls.StatusLabel.Text = "Ready - Use Auto/Hybrid or Manual Capture"
    $Controls.StatusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Italic)
    $Controls.StatusLabel.TextAlign = "MiddleCenter"
    $Form.Controls.Add($Controls.StatusLabel)
    
    # Footer
    $lblFooter = New-Object System.Windows.Forms.Label
    $lblFooter.Location = New-Object System.Drawing.Point(20, 320)
    $lblFooter.Size = New-Object System.Drawing.Size(560, 30)
    $lblFooter.Text = "Workflow: Figure 2 -> Figure 3 -> Figure 4 -> Figure 5 -> Details -> Report (manual fallback supported)"
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