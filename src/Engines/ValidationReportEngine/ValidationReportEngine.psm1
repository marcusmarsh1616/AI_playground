#Requires -Version 5.1
<#
.SYNOPSIS
    Validation Report Engine
.DESCRIPTION
    Runs integrated validation documentation capture and saves the generated report to a package docs folder.
#>

Add-Type -AssemblyName System.Windows.Forms

function Show-ValidationCaptureModeDialog {
    [CmdletBinding()]
    param(
        [string]$AppName = "",
        [string]$AppVersion = ""
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Validation Report Mode"
    $form.Size = New-Object System.Drawing.Size(560, 250)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true

    $title = New-Object System.Windows.Forms.Label
    $title.Text = "Select validation report mode"
    $title.Location = New-Object System.Drawing.Point(20, 15)
    $title.Size = New-Object System.Drawing.Size(510, 28)
    $title.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($title)

    $appText = if (-not [string]::IsNullOrWhiteSpace($AppName)) {
        "Application: $AppName $AppVersion"
    } else {
        "Application details are available from the current package context."
    }

    $prompt = New-Object System.Windows.Forms.Label
    $prompt.Text = "Choose Automated, Manual, or skip report generation for now." + [Environment]::NewLine + "Automated includes retry/skip/cancel and then enforces manual completion for missing Figure 2-5 captures before report generation." + [Environment]::NewLine + $appText
    $prompt.Location = New-Object System.Drawing.Point(20, 50)
    $prompt.Size = New-Object System.Drawing.Size(510, 55)
    $prompt.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $form.Controls.Add($prompt)

    $script:ValidationModeSelection = ""

    $btnAutomated = New-Object System.Windows.Forms.Button
    $btnAutomated.Text = "Automated"
    $btnAutomated.Location = New-Object System.Drawing.Point(20, 140)
    $btnAutomated.Size = New-Object System.Drawing.Size(160, 35)
    $btnAutomated.BackColor = [System.Drawing.Color]::FromArgb(0, 176, 80)
    $btnAutomated.ForeColor = [System.Drawing.Color]::White
    $btnAutomated.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnAutomated.Add_Click({
        $script:ValidationModeSelection = "Automated"
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })
    $form.Controls.Add($btnAutomated)

    $btnManual = New-Object System.Windows.Forms.Button
    $btnManual.Text = "Manual"
    $btnManual.Location = New-Object System.Drawing.Point(195, 140)
    $btnManual.Size = New-Object System.Drawing.Size(160, 35)
    $btnManual.BackColor = [System.Drawing.Color]::FromArgb(0, 105, 160)
    $btnManual.ForeColor = [System.Drawing.Color]::White
    $btnManual.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnManual.Add_Click({
        $script:ValidationModeSelection = "Manual"
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })
    $form.Controls.Add($btnManual)

    $btnNone = New-Object System.Windows.Forms.Button
    $btnNone.Text = "No Report or One Already Exists"
    $btnNone.Location = New-Object System.Drawing.Point(370, 140)
    $btnNone.Size = New-Object System.Drawing.Size(160, 35)
    $btnNone.BackColor = [System.Drawing.Color]::FromArgb(145, 145, 145)
    $btnNone.ForeColor = [System.Drawing.Color]::White
    $btnNone.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnNone.Add_Click({
        $script:ValidationModeSelection = "None"
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })
    $form.Controls.Add($btnNone)

    [void]$form.ShowDialog()

    if ([string]::IsNullOrWhiteSpace($script:ValidationModeSelection)) {
        return "None"
    }

    return $script:ValidationModeSelection
}

function Start-ValidationReportCapture {
    [CmdletBinding()]
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
        [string]$AppVersion,

        [Parameter(Mandatory = $false)]
        [ValidateSet('System', 'User')]
        [string]$InstallContext = 'System'
    )

    $result = @{
        Success = $false
        Launched = $false
        Mode = ""
        ReportCopied = $false
        CopiedReportPath = ""
        Message = ""
    }

    try {
        $engineRoot = $PSScriptRoot
        $uiEnginePath = Join-Path $engineRoot "src\DocumentationUIEngine.psm1"

        $mode = Show-ValidationCaptureModeDialog -AppName $AppName -AppVersion $AppVersion
        $result.Mode = $mode
        if ($mode -eq "None") {
            [System.Windows.Forms.MessageBox]::Show(
                "Validation report generation was skipped.`n`nIf you want to capture this report later, you will need to reinstall the software so the full capture sequence can be performed again.",
                "Validation Report Deferred",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )

            $result.Success = $true
            $result.Message = "Validation report deferred by technician (Mode: None). Reinstall is required to capture later."
            return $result
        }

        if (-not (Test-Path $uiEnginePath)) {
            $result.Message = "Validation documentation UI engine not found: $uiEnginePath"
            return $result
        }

        $docsFolder = Join-Path $PackagePath "Docs"
        if (-not (Test-Path $docsFolder)) {
            New-Item -Path $docsFolder -ItemType Directory -Force | Out-Null
        }
        $imagesFolder = Join-Path $docsFolder "images"
        if (-not (Test-Path $imagesFolder)) {
            New-Item -Path $imagesFolder -ItemType Directory -Force | Out-Null
        }

        $nameParts = @($AppVendor, $AppName)
        if (-not [string]::IsNullOrWhiteSpace($AppEdition)) {
            $nameParts += $AppEdition
        }
        $nameParts += $AppVersion

        $reportFileName = (($nameParts -join " ") + " Validation report.html")
        $reportFileName = $reportFileName -replace '[<>:"/\\|?*]', '_'
        $targetReportPath = Join-Path $docsFolder $reportFileName

        if (Test-Path $targetReportPath) {
            $promptResult = [System.Windows.Forms.MessageBox]::Show(
                "A validation report already exists for this package.`n`nSelect Yes to generate a new report and replace it, or No to keep the existing report and skip validation report generation.",
                "Validation Report Already Exists",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )

            if ($promptResult -eq [System.Windows.Forms.DialogResult]::No) {
                try {
                    Start-Process -FilePath $targetReportPath | Out-Null
                }
                catch {
                }

                $result.Success = $true
                $result.ReportCopied = $true
                $result.CopiedReportPath = $targetReportPath
                $result.Message = "Existing validation report retained and opened from package docs (Mode: $mode)."
                return $result
            }
        }

        $startTime = Get-Date
        $launcherResult = $null
        $previousLocation = Get-Location
        try {
            Push-Location $engineRoot
            Import-Module $uiEnginePath -Force -ErrorAction Stop
            $result.Launched = $true
            if ($mode -eq "Manual") {
                $launcherResult = Show-DocumentationCaptureUI -AppName $AppName -AppVersion $AppVersion -CaptureWorkingDirectory $imagesFolder -DocumentationOutputFolder $docsFolder -InstallContext $InstallContext
            }
            else {
                $launcherResult = Invoke-DocumentationCaptureFromContext -AppVendor $AppVendor -AppName $AppName -AppVersion $AppVersion -CaptureWorkingDirectory $imagesFolder -DocumentationOutputFolder $docsFolder -InstallContext $InstallContext
            }
        }
        finally {
            Pop-Location
        }

        $sourceReportPath = ""
        if ($launcherResult -and $launcherResult.PSObject.Properties.Name -contains 'OutputPath' -and -not [string]::IsNullOrWhiteSpace([string]$launcherResult.OutputPath)) {
            $candidateOutputPath = [string]$launcherResult.OutputPath
            $candidatePaths = @($candidateOutputPath)

            if (-not [System.IO.Path]::IsPathRooted($candidateOutputPath)) {
                $candidatePaths += (Join-Path $engineRoot $candidateOutputPath)
                $candidatePaths += (Join-Path $previousLocation.Path $candidateOutputPath)
            }

            foreach ($candidatePath in ($candidatePaths | Select-Object -Unique)) {
                if (Test-Path $candidatePath) {
                    $sourceReportPath = (Resolve-Path $candidatePath).Path
                    break
                }
            }
        }

        if ($launcherResult -and $launcherResult.PSObject.Properties.Name -contains 'Success' -and -not $launcherResult.Success) {
            $result.Message = if ($launcherResult.Message) { "Validation documentation tool failed: $($launcherResult.Message)" } else { "Validation documentation tool reported failure." }
            return $result
        }

        if ([string]::IsNullOrWhiteSpace($sourceReportPath)) {
            $outputFoldersToProbe = @(
                $docsFolder,
                (Join-Path $PackagePath "Docs")
            ) | Select-Object -Unique

            $resolvedOutputFolder = ""
            foreach ($candidateFolder in $outputFoldersToProbe) {
                if (Test-Path $candidateFolder) {
                    $resolvedOutputFolder = (Resolve-Path $candidateFolder).Path
                    break
                }
            }

            if ([string]::IsNullOrWhiteSpace($resolvedOutputFolder)) {
                $result.Message = "Validation tool did not produce a documentation output folder."
                return $result
            }

            $latestReport = Get-ChildItem -Path $resolvedOutputFolder -Filter "*.html" -File -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -ge $startTime } |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1

            if (-not $latestReport) {
                $latestReport = Get-ChildItem -Path $resolvedOutputFolder -Filter "*.html" -File -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1
            }

            if (-not $latestReport) {
                $result.Message = "Validation tool closed without generating a report file."
                return $result
            }

            $sourceReportPath = $latestReport.FullName
        }

        if ((Resolve-Path $sourceReportPath).Path -ne (Resolve-Path (Split-Path -Path $targetReportPath -Parent)).Path + "\" + (Split-Path -Path $targetReportPath -Leaf)) {
            Copy-Item -Path $sourceReportPath -Destination $targetReportPath -Force
        }

        try {
            Start-Process -FilePath $targetReportPath | Out-Null
        }
        catch {
            # Non-fatal: report is still generated and copied successfully.
        }

        $result.ReportCopied = $true
        $result.CopiedReportPath = $targetReportPath
        $result.Success = $true
        $result.Message = "Validation report saved to package docs (Mode: $mode): $reportFileName"
    }
    catch {
        $result.Message = "Validation report engine error: $($_.Exception.Message)"
    }

    return $result
}

Export-ModuleMember -Function Start-ValidationReportCapture
