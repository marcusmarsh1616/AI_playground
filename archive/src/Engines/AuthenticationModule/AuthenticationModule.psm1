#Requires -Version 5.1

<#
.SYNOPSIS
    AuthenticationModule - Handles Python and Playwright installation for GitLab/Okta authentication
.DESCRIPTION
    This module manages the one-time installation of Python and Playwright prerequisites
    required for GitLab/Okta authentication. Installation status is tracked in app.config.json.
.NOTES
    Module: AuthenticationModule
    Created: 2026-07-06
    Purpose: One-time Python/Playwright setup for each technician
#>

function Initialize-PlaywrightAuthentication {
    <#
    .SYNOPSIS
        Installs Python and Playwright prerequisites if not already installed
    .DESCRIPTION
        Checks if Python/Playwright are installed. If not, copies from prereq folder
        to local folder. Updates app.config.json to track installation status.
        This should only run once per technician.
    .PARAMETER ConfigPath
        Path to app.config.json file
    .PARAMETER PackagingPath
        Packaging folder path where tool copy resides
    .EXAMPLE
        $result = Initialize-PlaywrightAuthentication -ConfigPath "C:\...\app.config.json" -PackagingPath "C:\Temp\FRB-Packager"
        if ($result.Success) { Write-Host "Authentication ready!" }
    .OUTPUTS
        Hashtable with Success (bool), Message (string), AlreadyInstalled (bool)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,
        
        [Parameter(Mandatory = $true)]
        [string]$PackagingPath
    )
    
    try {
        # Check config file first
        if (Test-Path $ConfigPath) {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            if ($config.settings.pythonPlaywrightInstalled -eq $true) {
                return @{
                    Success = $true
                    Message = "Python and Playwright already installed"
                    AlreadyInstalled = $true
                }
            }
        }
        
        # Calculate ToolRoot from module location (same pattern as quick-test.ps1)
        $moduleRoot = Split-Path -Parent $PSCommandPath
        $engineRoot = Split-Path -Parent $moduleRoot
        $srcRoot = Split-Path -Parent $engineRoot
        $ToolRoot = Split-Path -Parent $srcRoot
        
        # Define paths
        $localPythonPath = Join-Path $PackagingPath "python"
        $prereqPythonPath = Join-Path $ToolRoot "prereq\python"
        $prereqBrowserPath = Join-Path $ToolRoot "prereq\playwright-browsers"
        $localBrowserPath = Join-Path $env:LOCALAPPDATA "ms-playwright"
        
        # Check if local Python already exists (physical check)
        if (Test-Path $localPythonPath) {
            # Already installed but not marked in config - mark it now
            if (Test-Path $ConfigPath) {
                try {
                    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
                    
                    # Add pythonPlaywrightInstalled field
                    if (-not ($config.settings.PSObject.Properties.Name -contains 'pythonPlaywrightInstalled')) {
                        $config.settings | Add-Member -NotePropertyName 'pythonPlaywrightInstalled' -NotePropertyValue $true -Force
                    } else {
                        $config.settings.pythonPlaywrightInstalled = $true
                    }
                    
                    $config | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8 -Force
                } catch {
                    Write-Warning "Could not update config: $($_.Exception.Message)"
                }
            }
            
            return @{
                Success = $true
                Message = "Python and Playwright already installed"
                AlreadyInstalled = $true
            }
        }
        
        # Installation needed - check if prereq folder exists
        if (-not (Test-Path $prereqPythonPath)) {
            return @{
                Success = $false
                Message = "Prerequisites not found! Expected Python at: $prereqPythonPath"
                AlreadyInstalled = $false
            }
        }
        
        # Show professional progress banner (Requirement: 12pt Segoe UI Bold)
        Add-Type -AssemblyName System.Windows.Forms
        $progressForm = New-Object System.Windows.Forms.Form
        $progressForm.Text = "Installing Prerequisites"
        $progressForm.Size = New-Object System.Drawing.Size(450, 180)
        $progressForm.StartPosition = "CenterScreen"
        $progressForm.FormBorderStyle = "FixedDialog"
        $progressForm.ControlBox = $false
        $progressForm.BackColor = [System.Drawing.Color]::White
        
        $progressLabel = New-Object System.Windows.Forms.Label
        $progressLabel.Text = "Installing Python and Playwright..."
        $progressLabel.Location = New-Object System.Drawing.Point(20, 40)
        $progressLabel.Size = New-Object System.Drawing.Size(410, 30)
        $progressLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
        $progressLabel.TextAlign = "MiddleCenter"
        $progressLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 122, 204)
        $progressForm.Controls.Add($progressLabel)
        
        $progressSubLabel = New-Object System.Windows.Forms.Label
        $progressSubLabel.Text = "This is a large file and could take a few minutes. Please wait..."
        $progressSubLabel.Location = New-Object System.Drawing.Point(20, 80)
        $progressSubLabel.Size = New-Object System.Drawing.Size(410, 25)
        $progressSubLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
        $progressSubLabel.TextAlign = "MiddleCenter"
        $progressSubLabel.ForeColor = [System.Drawing.Color]::Gray
        $progressForm.Controls.Add($progressSubLabel)
        
        # Show form and copy in background
        $progressForm.Add_Shown({
            $progressForm.Refresh()
            try {
                Copy-Item -Path $prereqPythonPath -Destination $localPythonPath -Recurse -Force -ErrorAction Stop
                
                # Update message and color for browser components
                $progressLabel.Text = "Installing browser components..."
                $progressLabel.ForeColor = [System.Drawing.Color]::FromArgb(16, 185, 129)
                $progressForm.Refresh()
                
                Copy-Item -Path $prereqBrowserPath -Destination $localBrowserPath -Recurse -Force -ErrorAction Stop
                $progressForm.Close()
            } catch {
                $progressForm.Close()
                throw
            }
        })
        
        try {
            [void]$progressForm.ShowDialog()
        } catch {
            return @{
                Success = $false
                Message = "Failed to copy Python: $($_.Exception.Message)"
                AlreadyInstalled = $false
            }
        }
        
        # Update config to mark as installed
        if (Test-Path $ConfigPath) {
            try {
                $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
                
                # Add pythonPlaywrightInstalled field
                if (-not ($config.settings.PSObject.Properties.Name -contains 'pythonPlaywrightInstalled')) {
                    $config.settings | Add-Member -NotePropertyName 'pythonPlaywrightInstalled' -NotePropertyValue $true -Force
                } else {
                    $config.settings.pythonPlaywrightInstalled = $true
                }
                
                $config | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8 -Force
            } catch {
                Write-Warning "Could not update config: $($_.Exception.Message)"
                # Don''t fail if config update fails - installation was successful
            }
        }
        
        return @{
            Success = $true
            Message = "Python and Playwright installed successfully!"
            AlreadyInstalled = $false
        }
        
    } catch {
        return @{
            Success = $false
            Message = "Installation failed: $($_.Exception.Message)"
            AlreadyInstalled = $false
        }
    }
}

# Export the function
Export-ModuleMember -Function Initialize-PlaywrightAuthentication



function Invoke-GitLabOktaAuthentication {
    <#
    .SYNOPSIS
        Performs GitLab Okta authentication and downloads Master Template
    .DESCRIPTION
        Opens Edge browser, navigates to GitLab, waits for user to complete Okta MFA,
        downloads template, and extracts it to Master Template folder.
    .PARAMETER GitLabUrl
        GitLab project URL
    .PARAMETER PackagingPath
        Packaging folder path (where Master Template will be extracted)
    .EXAMPLE
        $result = Invoke-GitLabOktaAuthentication -GitLabUrl "https://gitlab.example.com/project" -PackagingPath "C:\Temp\Packager"
        if ($result.Success) { Write-Host "Template downloaded!" }
    .OUTPUTS
        Hashtable with Success (bool), Message (string)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$GitLabUrl,
        
        [Parameter(Mandatory = $true)]
        [string]$PackagingPath
    )
    
    try {
        # Determine Python path
        $localPythonPath = Join-Path $PackagingPath "python"
        $pythonExe = Join-Path $localPythonPath "python.exe"
        
        if (-not (Test-Path $pythonExe)) {
            return @{
                Success = $false
                Message = "Python not found at: $pythonExe. Run Initialize-PlaywrightAuthentication first."
            }
        }
        
        # Calculate script path from module location
        $moduleRoot = Split-Path -Parent $PSCommandPath
        $engineRoot = Split-Path -Parent $moduleRoot
        $pythonScript = Join-Path $engineRoot "TemplateDownloadEngine\gitlab_okta_download.py"
        
        if (-not (Test-Path $pythonScript)) {
            return @{
                Success = $false
                Message = "Python script not found: $pythonScript"
            }
        }
        
        # Set download path to packaging folder
        $downloadPath = Join-Path $PackagingPath "temp_download"
        if (-not (Test-Path $downloadPath)) {
            New-Item -Path $downloadPath -ItemType Directory -Force | Out-Null
        }
        
        # Set working directory to script location (same as quick-test.ps1)
        $scriptDir = Split-Path -Parent $pythonScript
        Push-Location $scriptDir
        
        try {
            Write-Host "Starting GitLab download with Okta authentication..." -ForegroundColor Cyan
            Write-Host "Edge browser will open for Okta login..." -ForegroundColor Yellow
            Write-Host "" 
            
            # Use call operator - SAME AS quick-test.ps1 (no --auth-only flag)
            & $pythonExe $pythonScript --gitlab-url $GitLabUrl --download-path $downloadPath
            
            if ($LASTEXITCODE -ne 0) {
                return @{
                    Success = $false
                    Message = "Download failed - exit code $LASTEXITCODE"
                }
            }
            
            # Find downloaded zip file
            $zipFile = Get-ChildItem -Path $downloadPath -Filter "*.zip" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            
            if (-not $zipFile) {
                return @{
                    Success = $false
                    Message = "No zip file found in download folder"
                }
            }
            
            Write-Host "Download complete: $($zipFile.Name)" -ForegroundColor Green
            Write-Host "Extracting to Master Template folder..." -ForegroundColor Cyan
            
            # Extract to Master Template folder
            $masterTemplatePath = Join-Path $PackagingPath "Master Template"
            
            # Remove old Master Template if exists
            if (Test-Path $masterTemplatePath) {
                Remove-Item -Path $masterTemplatePath -Recurse -Force -ErrorAction Stop
            }
            
            # Extract zip
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile.FullName, $masterTemplatePath)
            
            # The zip contains a folder with the project name - move contents up one level
            $extractedFolder = Get-ChildItem -Path $masterTemplatePath -Directory | Select-Object -First 1
            if ($extractedFolder) {
                $tempPath = Join-Path $PackagingPath "temp_extract"
                Move-Item -Path $extractedFolder.FullName -Destination $tempPath -Force
                Remove-Item -Path $masterTemplatePath -Recurse -Force
                Move-Item -Path $tempPath -Destination $masterTemplatePath -Force
            }
            
            # Clean up download folder
            Remove-Item -Path $downloadPath -Recurse -Force -ErrorAction SilentlyContinue
            
            Write-Host "Master Template ready at: $masterTemplatePath" -ForegroundColor Green
            
            return @{
                Success = $true
                Message = "Template downloaded and extracted successfully"
            }
        }
        finally {
            Pop-Location
        }
        
    } catch {
        return @{
            Success = $false
            Message = "Download error: $($_.Exception.Message)"
        }
    }
}

# Export module members
Export-ModuleMember -Function Initialize-PlaywrightAuthentication, Invoke-GitLabOktaAuthentication