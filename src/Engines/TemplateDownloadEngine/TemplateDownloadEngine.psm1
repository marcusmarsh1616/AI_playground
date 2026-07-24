#Requires -Version 5.1

<#
.SYNOPSIS
    TemplateDownloadEngine - GitLab Master Template Download
.DESCRIPTION
    Engine 14 of 15 - Downloads and manages Master Template from GitLab
    Now uses Playwright + Okta authentication
.NOTES
    Engine Number: 14
    Dependencies: Python, Playwright
    Authentication: Okta SSO via browser automation
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Playwright wrapper script path
$playwrightScript = Join-Path $PSScriptRoot "Download-GitLabTemplate.ps1"


function Show-DownloadProgress {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        
        [Parameter(Mandatory = $true)]
        [scriptblock]$DownloadAction
    )
    
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.Size = New-Object System.Drawing.Size(500, 180)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true
    
    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Downloading Master Template from GitLab..."
    $label.Location = New-Object System.Drawing.Point(20, 30)
    $label.Size = New-Object System.Drawing.Size(460, 30)
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $form.Controls.Add($label)
    
    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Text = "Please wait... This may take a moment..."
    $statusLabel.Location = New-Object System.Drawing.Point(20, 80)
    $statusLabel.Size = New-Object System.Drawing.Size(460, 40)
    $statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $statusLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $statusLabel.ForeColor = [System.Drawing.Color]::Gray
    $form.Controls.Add($statusLabel)
    
    # Blinking colors array
    $colors = @(
        [System.Drawing.Color]::FromArgb(0, 120, 215),    # Blue
        [System.Drawing.Color]::FromArgb(16, 185, 129),   # Green
        [System.Drawing.Color]::FromArgb(234, 88, 12),    # Orange
        [System.Drawing.Color]::FromArgb(139, 92, 246),   # Purple
        [System.Drawing.Color]::FromArgb(236, 72, 153)    # Pink
    )
    $colorIndex = 0
    
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 300
    $timer.Add_Tick({
        $script:colorIndex = ($script:colorIndex + 1) % $colors.Count
        $label.ForeColor = $colors[$script:colorIndex]
        $form.Refresh()
        [System.Windows.Forms.Application]::DoEvents()
    })
    
    $result = $null
    $form.Add_Shown({
        $timer.Start()
        try {
            $script:result = & $DownloadAction
        }
        finally {
            $timer.Stop()
            $form.Close()
        }
    })
    
    [void]$form.ShowDialog()
    $form.Dispose()
    
    return $script:result
}

function Test-TemplateAge {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TemplatePath
    )
    
    try {
        if (-not (Test-Path $TemplatePath)) {
            return @{
                Exists = $false
                AgeInDays = 0
                NeedsUpdate = $true
                Message = "Template does not exist"
            }
        }
        
        $folder = Get-Item $TemplatePath
        $ageInDays = (New-TimeSpan -Start $folder.LastWriteTime -End (Get-Date)).Days
        $needsUpdate = $ageInDays -gt 30
        
        return @{
            Exists = $true
            AgeInDays = $ageInDays
            NeedsUpdate = $needsUpdate
            Message = "Template is $ageInDays days old"
            LastModified = $folder.LastWriteTime
        }
    }
    catch {
        return @{
            Exists = $false
            AgeInDays = 0
            NeedsUpdate = $true
            Message = "Error checking template: $($_.Exception.Message)"
        }
    }
}

function Get-GitLabArchive {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GitLabUrl,
        
        [Parameter(Mandatory = $false)]
        [string]$Branch = "master",
        
        [Parameter(Mandatory = $false)]
        [string]$AccessToken = "",
        
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )
    
    $downloadScript = {
        try {
            if (-not (Test-Path $DestinationPath)) {
                New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
            }
            
            $sessionFile = Join-Path $DestinationPath "session_state.json"
            
            # Determine Python path (packaging folder or system)
            $pythonExePath = "python"
            $packagingPythonPath = Join-Path (Split-Path $DestinationPath -Parent) "python\python.exe"
            if (Test-Path $packagingPythonPath) {
                $pythonExePath = $packagingPythonPath
            }
            
            $result = & $playwrightScript -GitLabUrl $GitLabUrl -DownloadPath $DestinationPath -SessionFile $sessionFile -PythonPath $pythonExePath
            
            if ($result) {
                $downloadedFile = Get-ChildItem -Path $DestinationPath -Filter "master-template-*.zip" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                
                if ($downloadedFile) {
                    return @{
                        Success = $true
                        FilePath = $downloadedFile.FullName
                        Message = "Template downloaded successfully via Okta"
                    }
                } else {
                    throw "Download completed but file not found"
                }
            } else {
                throw "Playwright download failed"
            }
        }
        catch {
            return @{
                Success = $false
                FilePath = ""
                Message = "Failed to download: $($_.Exception.Message)"
            }
        }
    }
    
    return Show-DownloadProgress -Title "GitLab Download" -DownloadAction $downloadScript
}

function Expand-TemplateArchive {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ZipPath,
        
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )
    
    try {
        if (Test-Path $DestinationPath) {
            $backupPath = "$DestinationPath`_backup_$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Rename-Item -Path $DestinationPath -NewName (Split-Path $backupPath -Leaf) -Force
        }
        
        New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
        
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $DestinationPath)
        
        $extractedFolder = Get-ChildItem -Path $DestinationPath -Directory | Select-Object -First 1
        if ($extractedFolder) {
            $tempPath = "$DestinationPath`_temp"
            Move-Item -Path $extractedFolder.FullName -Destination $tempPath -Force
            
            Get-ChildItem -Path $tempPath | Move-Item -Destination $DestinationPath -Force
            Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
        }
        
        Remove-Item -Path $ZipPath -Force -ErrorAction SilentlyContinue
        
        return @{
            Success = $true
            Path = $DestinationPath
            Message = "Template extracted successfully"
        }
    }
    catch {
        return @{
            Success = $false
            Path = ""
            Message = "Failed to extract: $($_.Exception.Message)"
        }
    }
}

function Update-MasterTemplate {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GitLabUrl,
        
        [Parameter(Mandatory = $false)]
        [string]$AccessToken = "",
        
        [Parameter(Mandatory = $true)]
        [string]$TemplatePath,
        
        [Parameter(Mandatory = $false)]
        [string]$Branch = "master",
        
        [Parameter(Mandatory = $false)]
        [switch]$ForceUpdate
    )
    
    try {
        $ageCheck = Test-TemplateAge -TemplatePath $TemplatePath
        
        if (-not $ForceUpdate -and $ageCheck.Exists -and -not $ageCheck.NeedsUpdate) {
            return @{
                Success = $true
                Message = "Template is current ($($ageCheck.AgeInDays) days old)"
                Action = "None"
                TemplateAge = $ageCheck.AgeInDays
            }
        }
        
        # Okta authentication handled by Playwright - no token needed
        
        $tempPath = [System.IO.Path]::GetTempPath()
        
        $downloadResult = Get-GitLabArchive -GitLabUrl $GitLabUrl -Branch $Branch -AccessToken $AccessToken -DestinationPath $tempPath
        
        if (-not $downloadResult.Success) {
            throw $downloadResult.Message
        }
        
        $extractResult = Expand-TemplateArchive -ZipPath $downloadResult.FilePath -DestinationPath $TemplatePath
        
        if (-not $extractResult.Success) {
            throw $extractResult.Message
        }
        
        return @{
            Success = $true
            Message = "Master Template updated successfully"
            Action = "Updated"
            PreviousAge = $ageCheck.AgeInDays
        }
    }
    catch {
        return @{
            Success = $false
            Message = "Failed to update: $($_.Exception.Message)"
            Action = "Failed"
        }
    }
}

Export-ModuleMember -Function Test-TemplateAge, Get-GitLabArchive, Expand-TemplateArchive, Update-MasterTemplate, Show-DownloadProgress


