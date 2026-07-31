#Requires -Version 5.1
<#!
.SYNOPSIS
    GUI launcher for the Installation Validation Report workflow.

.DESCRIPTION
    Opens a simple Windows Forms dialog that lets the user pick an installer,
    then launches the validation report workflow using the selected file.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Installation Validation Report'
$form.Size = New-Object System.Drawing.Size(620, 260)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false

$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(20, 20)
$label.Size = New-Object System.Drawing.Size(560, 24)
$label.Text = 'Select an installer file to validate:'
$form.Controls.Add($label)

$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Location = New-Object System.Drawing.Point(20, 50)
$textBox.Size = New-Object System.Drawing.Size(430, 24)
$textBox.ReadOnly = $true
$form.Controls.Add($textBox)

$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Location = New-Object System.Drawing.Point(460, 48)
$browseButton.Size = New-Object System.Drawing.Size(120, 28)
$browseButton.Text = 'Browse...'
$browseButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = 'Select installer file'
    $dialog.Filter = 'Installer files (*.msi;*.exe)|*.msi;*.exe|All files (*.*)|*.*'
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $textBox.Text = $dialog.FileName
    }
})
$form.Controls.Add($browseButton)

$checkBox = New-Object System.Windows.Forms.CheckBox
$checkBox.Location = New-Object System.Drawing.Point(20, 95)
$checkBox.Size = New-Object System.Drawing.Size(560, 24)
$checkBox.Text = 'Skip web research and use installer metadata only'
$checkBox.Checked = $false
$form.Controls.Add($checkBox)

$infoLabel = New-Object System.Windows.Forms.Label
$infoLabel.Location = New-Object System.Drawing.Point(20, 130)
$infoLabel.Size = New-Object System.Drawing.Size(560, 48)
$infoLabel.Text = 'The workflow will use the installer metadata to build the report and then launch the validation process.'
$infoLabel.ForeColor = [System.Drawing.Color]::DarkSlateGray
$form.Controls.Add($infoLabel)

$runButton = New-Object System.Windows.Forms.Button
$runButton.Location = New-Object System.Drawing.Point(20, 190)
$runButton.Size = New-Object System.Drawing.Size(120, 32)
$runButton.Text = 'Run'
$runButton.Add_Click({
    if ([string]::IsNullOrWhiteSpace($textBox.Text)) {
        [System.Windows.Forms.MessageBox]::Show('Please select an installer file first.', 'Validation Report', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    $scriptPath = Join-Path $PSScriptRoot 'Start-ValidationResearch.ps1'
    $launchArgs = @('-ExecutionPolicy', 'Bypass', '-File', $scriptPath, '-InstallerPath', $textBox.Text)
    if ($checkBox.Checked) {
        $launchArgs += '-SkipWebResearch'
    }

    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $runButton.Enabled = $false
    $browseButton.Enabled = $false

    try {
        Start-Process -FilePath 'powershell.exe' -ArgumentList $launchArgs -Wait -NoNewWindow
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to start the workflow: $($_.Exception.Message)", 'Validation Report', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    } finally {
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        $runButton.Enabled = $true
        $browseButton.Enabled = $true
    }
})
$form.Controls.Add($runButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Location = New-Object System.Drawing.Point(150, 190)
$cancelButton.Size = New-Object System.Drawing.Size(120, 32)
$cancelButton.Text = 'Cancel'
$cancelButton.Add_Click({ $form.Close() })
$form.Controls.Add($cancelButton)

$form.ShowDialog() | Out-Null
