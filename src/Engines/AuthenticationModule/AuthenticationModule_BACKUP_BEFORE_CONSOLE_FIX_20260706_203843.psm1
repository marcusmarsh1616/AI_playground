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
    .PARAMETER ToolRoot
        Tool root path on network share (where prereq folder lives)
    .EXAMPLE
        $result = Initialize-PlaywrightAuthentication -ConfigPath "C:\...\app.config.json" -PackagingPath "C:\Temp\FRB-Packager" -ToolRoot "\\network\share\FRB-Tool"
        if ($result.Success) { Write-Host "Authentication ready!" }
    .OUTPUTS
        Hashtable with Success (bool), Message (string), AlreadyInstalled (bool)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,
        
        [Parameter(Mandatory = $true)]
        [string]$PackagingPath,
        
        [Parameter(Mandatory = $true)]
        [string]$ToolRoot
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
        
        # Show progress message
        Write-Host "Installing Python and Playwright for first time..." -ForegroundColor Cyan
        Write-Host "  Source: $prereqPythonPath" -ForegroundColor Gray
        Write-Host "  Destination: $localPythonPath" -ForegroundColor Gray
        Write-Host ""
        Write-Host "This may take a minute. Please wait..." -ForegroundColor Yellow
        
        # Copy Python from prereq to local
        try {
            Copy-Item -Path $prereqPythonPath -Destination $localPythonPath -Recurse -Force -ErrorAction Stop
            Write-Host "  [OK] Python copied successfully!" -ForegroundColor Green
        } catch {
            Write-Host "  [ERROR] Python copy failed: $($_.Exception.Message)" -ForegroundColor Red
            return @{
                Success = $false
                Message = "Failed to copy Python: $($_.Exception.Message)"
                AlreadyInstalled = $false
            }
        }
        
        # Copy Playwright browsers if they exist in prereq
        if (Test-Path $prereqBrowserPath) {
            Write-Host "  Copying Playwright browsers..." -ForegroundColor Yellow
            try {
                # Create parent directory if it doesn't exist
                if (-not (Test-Path $localBrowserPath)) {
                    New-Item -Path $localBrowserPath -ItemType Directory -Force | Out-Null
                }
                
                # Copy browser folders directly into ms-playwright (not as subfolder)
                Get-ChildItem -Path $prereqBrowserPath -Directory | ForEach-Object {
                    $targetPath = Join-Path $localBrowserPath $_.Name
                    Copy-Item -Path $_.FullName -Destination $targetPath -Recurse -Force -ErrorAction Stop
                    Write-Host "    [OK] $($_.Name) copied" -ForegroundColor Green
                }
            } catch {
                Write-Warning "Failed to copy Playwright browsers: $($_.Exception.Message)"
                # Don't fail the entire operation if browser copy fails
            }
        }
        
        Write-Host ""
        Write-Host "Installation complete! Continuing..." -ForegroundColor Green
        Start-Sleep -Seconds 2
        
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
                # Don't fail if config update fails - installation was successful
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

