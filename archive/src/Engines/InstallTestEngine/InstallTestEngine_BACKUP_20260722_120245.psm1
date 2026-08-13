#Requires -Version 5.1

<#
.SYNOPSIS
    InstallTestEngine - Orchestrates installation and uninstallation testing workflow
.DESCRIPTION
    This engine manages the complete test cycle:
    1. Launch Install.exe
    2. Verify installation success with technician
    3. Generate validation report
    4. Run uninstallation
    5. Scan for leftovers
    6. Verify uninstallation success with technician
.NOTES
    Author: FRB Automation Team
    Created: June 6, 2026
    Version: 1.0.1
    PowerShell Version: 5.1
    Part of: FRB Package Creation Tool - Integrated Architecture
#>

Add-Type -AssemblyName System.Windows.Forms

function Start-InstallationTest {
    <#
    .SYNOPSIS
        Runs installation test and prompts technician for verification
    .PARAMETER InstallExePath
        Full path to Install.exe
    .PARAMETER AppName
        Application name for messaging
    .PARAMETER AppVersion
        Application version for messaging
    .PARAMETER Vendor
        Vendor name for scanning
    .OUTPUTS
        Hashtable with Success, UserConfirmed, ExitCode, ErrorMessage
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallExePath,
        
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [Parameter(Mandatory = $true)]
        [string]$AppVersion,
        
        [Parameter(Mandatory = $true)]
        [string]$Vendor,
        
        [Parameter(Mandatory = $false)]
        [bool]$UserContext = $false
    )
    
    Write-Verbose "InstallTestEngine: Starting installation test for $AppName $AppVersion"
    
    $result = @{
        Success = $false
        UserConfirmed = $false
        ExitCode = -1
        ErrorMessage = ""
    }
    
    try {
        # Validate Install.exe exists
        if (-not (Test-Path $InstallExePath)) {
            $result.ErrorMessage = "Install.exe not found: $InstallExePath"
            Write-Error $result.ErrorMessage
            return $result
        }
        
        Write-Verbose "InstallTestEngine: Launching Install.exe with UAC elevation..."
        
        # Build command line arguments
        $arguments = ""
        if ($UserContext) {
            $arguments = "/usercontext /silent"
            Write-Verbose "InstallTestEngine: Using /usercontext switch (no elevation)"
        } else {
            $arguments = "/silent"
            Write-Verbose "InstallTestEngine: Using standard elevation"
        }
        
        # Create process start info
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $InstallExePath
        $processInfo.Arguments = $arguments
        $processInfo.UseShellExecute = $true
        if (-not $UserContext) {
            $processInfo.Verb = "runas"  # Only use runas if NOT user context
        }
        $processInfo.WindowStyle = "Normal"
        
        # Launch Install.exe (returns shell process)
        [void][System.Diagnostics.Process]::Start($processInfo)
        
        # Wait for Install.exe to actually start
        Start-Sleep -Seconds 2
        
        # Find the ACTUAL Install.exe process by name
        $installProcess = Get-Process -Name "Install" -ErrorAction SilentlyContinue
        
        if ($installProcess) {
            Write-Verbose "InstallTestEngine: Found Install.exe process (PID: $($installProcess.Id))"
            
            # Wait for the ACTUAL Install.exe process to complete
            $installProcess.WaitForExit()
            
            $result.ExitCode = $installProcess.ExitCode
            Write-Verbose "InstallTestEngine: Installation completed (Exit Code: $($result.ExitCode))"
            
            # Give system time to settle
            Start-Sleep -Seconds 2
            
            # Prompt technician for verification
            $userResponse = [System.Windows.Forms.MessageBox]::Show(
                "Did the installation of $AppName $AppVersion function as designed?",
                "Installation Verification",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
            
            if ($userResponse -eq 'Yes') {
                $result.Success = $true
                $result.UserConfirmed = $true
                Write-Verbose "InstallTestEngine: Installation confirmed by technician"
            } else {
                $result.Success = $false
                $result.UserConfirmed = $false
                $result.ErrorMessage = "Technician indicated installation did not function as designed"
                Write-Warning $result.ErrorMessage
            }
        } else {
            $result.ErrorMessage = "Failed to find Install.exe process after launch"
            Write-Error $result.ErrorMessage
        }
    }
    catch {
        $result.ErrorMessage = "Installation test failed: $($_.Exception.Message)"
        Write-Error $result.ErrorMessage
    }
    
    return $result
}

function Start-UninstallationTest {
    <#
    .SYNOPSIS
        Runs uninstallation test, scans for leftovers, and prompts technician
    .PARAMETER InstallExePath
        Full path to Install.exe (will add /uninstall)
    .PARAMETER AppName
        Application name for messaging and scanning
    .PARAMETER AppVersion
        Application version for messaging
    .PARAMETER Vendor
        Vendor name for scanning leftovers
    .PARAMETER PackagePath
        Path to package folder for saving leftover report
    .OUTPUTS
        Hashtable with Success, UserConfirmed, LeftoversFound, LeftoverDetails, ErrorMessage
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallExePath,
        
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [Parameter(Mandatory = $true)]
        [string]$AppVersion,
        
        [Parameter(Mandatory = $true)]
        [string]$Vendor,
        
        [Parameter(Mandatory = $false)]
        [string]$PackagePath = "",
        
        [Parameter(Mandatory = $false)]
        [bool]$UserContext = $false
    )
    
    Write-Verbose "InstallTestEngine: Starting uninstallation test for $AppName $AppVersion"
    
    $result = @{
        Success = $false
        UserConfirmed = $false
        ExitCode = -1
        LeftoversFound = $false
        LeftoverDetails = @()
        CleanupPerformed = $false
        CleanupResults = $null
        ErrorMessage = ""
    }
    
    try {
        # Validate Install.exe exists
        if (-not (Test-Path $InstallExePath)) {
            $result.ErrorMessage = "Install.exe not found: $InstallExePath"
            Write-Error $result.ErrorMessage
            return $result
        }
        
        Write-Verbose "InstallTestEngine: Launching Install.exe /uninstall..."
        
        # Build command line arguments for uninstall
        $uninstallArgs = "/uninstall"
        if ($UserContext) {
            $uninstallArgs += " /usercontext /silent"
            Write-Verbose "InstallTestEngine: Using /usercontext switch (no elevation)"
        } else {
            $uninstallArgs += " /silent"
            Write-Verbose "InstallTestEngine: Using standard elevation"
        }
        
        # Use Start-Process with conditional elevation
        if ($UserContext) {
            $uninstallProcess = Start-Process -FilePath $InstallExePath -ArgumentList $uninstallArgs -PassThru -Wait
        } else {
            $uninstallProcess = Start-Process -FilePath $InstallExePath -ArgumentList $uninstallArgs -Verb RunAs -PassThru -Wait
        }
        
        if ($uninstallProcess) {
            Write-Verbose "InstallTestEngine: Uninstallation process completed"
            $result.ExitCode = $uninstallProcess.ExitCode
            Write-Verbose "InstallTestEngine: Uninstallation completed (Exit Code: $($result.ExitCode))"
            
            # Give system extra time to settle and release file locks
            Write-Verbose "InstallTestEngine: Waiting for system to settle and release file locks..."
            Start-Sleep -Seconds 5
            
            # Scan for leftovers (for reporting only - technician will handle via Custom Post-Uninstall commands if needed)
            Write-Verbose "InstallTestEngine: Scanning for leftover files and registry entries..."
            $leftovers = Get-UninstallLeftovers -AppName $AppName -Vendor $Vendor
            
            $result.LeftoversFound = $leftovers.Found
            $result.LeftoverDetails = $leftovers.Details
            
            # Prompt technician for verification (leftovers should be handled in Custom Post-Uninstall commands)
            $userResponse = [System.Windows.Forms.MessageBox]::Show(
                "Did the uninstallation of $AppName $AppVersion function as designed?",
                "Uninstallation Verification",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
            
            if ($userResponse -eq 'Yes') {
                # User confirmed - NOW do final verification scan
                Write-Verbose "InstallTestEngine: Performing final verification scan..."
                $finalScan = Get-UninstallLeftovers -AppName $AppName -Vendor $Vendor
                
                # ALWAYS generate uninstall report (whether clean or with leftovers)
                if (-not [string]::IsNullOrWhiteSpace($PackagePath)) {
                    try {
                        $docsFolder = Join-Path $PackagePath "Docs"
                        if (-not (Test-Path $docsFolder)) {
                            New-Item -Path $docsFolder -ItemType Directory -Force | Out-Null
                        }
                        
                        $reportFileName = "Uninstall_Report_" + $Vendor + "_" + $AppName + "_" + $AppVersion + ".html"
                        $reportFileName = $reportFileName -replace '[<>:"/\|?*]', '_'
                        $reportPath = Join-Path $docsFolder $reportFileName
                        
                        # Generate report with uninstall command info and cleanup results
                        $reportParams = @{
                            AppName = $AppName
                            AppVersion = $AppVersion
                            Vendor = $Vendor
                            LeftoverData = $finalScan
                            UninstallCommand = "$InstallExePath /uninstall"
                            OutputPath = $reportPath
                        }
                        
                        # Add cleanup results if cleanup was performed
                        if ($result.CleanupPerformed -and $result.CleanupResults) {
                            $reportParams.CleanupResults = $result.CleanupResults
                        }
                        
                        $reportResult = New-HTMLUninstallReport @reportParams
                        
                        if ($reportResult.Success) {
                            Write-Verbose "InstallTestEngine: Uninstall report generated at $reportPath"
                            Start-Process $reportPath
                            Start-Sleep -Milliseconds 500
                        }
                    } catch {
                        Write-Warning "InstallTestEngine: Failed to generate uninstall report: $($_.Exception.Message)"
                    }
                }
                
                if ($finalScan.Found) {
                    # Still have leftovers after confirmation
                    $finalParts = @(
                        "Warning: Final verification scan detected remaining leftover items:",
                        "",
                        ($finalScan.Summary -join [Environment]::NewLine),
                        "",
                        "Packaging will proceed. Review these items and consider manual cleanup."
                    )
                    $finalMsg = $finalParts -join [Environment]::NewLine
                    [System.Windows.Forms.MessageBox]::Show(
                        $finalMsg,
                        "Leftovers Detected",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Warning
                    )
                    Write-Warning "InstallTestEngine: Leftovers remain after uninstallation"
                } else {
                    # Clean uninstall verified
                    Write-Verbose "InstallTestEngine: Final verification scan clean - No leftovers detected"
                }
                
                $result.Success = $true
                $result.UserConfirmed = $true
                $result.LeftoversFound = $finalScan.Found
                $result.LeftoverDetails = $finalScan.Details
                Write-Verbose "InstallTestEngine: Uninstallation confirmed by technician"
            } else {
                $result.Success = $false
                $result.UserConfirmed = $false
                $result.ErrorMessage = "Technician indicated uninstallation did not function as designed"
                Write-Warning $result.ErrorMessage
            }
        } else {
            $result.ErrorMessage = "Failed to find Install.exe process after launch"
            Write-Error $result.ErrorMessage
        }
    }
    catch {
        $result.ErrorMessage = "Uninstallation test failed: $($_.Exception.Message)"
        Write-Error $result.ErrorMessage
    }
    
    return $result
}

function Remove-UninstallLeftovers {
    <#
    .SYNOPSIS
        Removes leftover files, folders, and registry entries
    .PARAMETER LeftoverData
        Hashtable containing leftover details from Get-UninstallLeftovers
    .OUTPUTS
        Hashtable with Success, TotalCleaned, TotalFailed, ErrorMessage
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$LeftoverData
    )
    
    Write-Verbose "InstallTestEngine: Starting cleanup of leftovers..."
    
    $result = @{
        Success = $true
        TotalCleaned = 0
        TotalFailed = 0
        ErrorMessage = ""
    }
    
    # Check if there's anything to clean
    if (-not $LeftoverData.Found -or $LeftoverData.Details.Count -eq 0) {
        Write-Verbose "InstallTestEngine: No leftovers found to clean"
        return $result
    }
    
    # Loop through all leftover items and delete them
    foreach ($item in $LeftoverData.Details) {
        try {
            if (Test-Path $item.Location) {
                # Delete with force and recurse (handles folders and registry keys)
                Remove-Item -Path $item.Location -Recurse -Force -ErrorAction Stop
                $result.TotalCleaned++
                Write-Verbose "InstallTestEngine: Removed $($item.Type) - $($item.Location)"
            } else {
                Write-Verbose "InstallTestEngine: Item already removed - $($item.Location)"
            }
        }
        catch {
            $result.TotalFailed++
            Write-Warning "InstallTestEngine: Failed to remove $($item.Type) - $($item.Location): $($_.Exception.Message)"
        }
    }
    
    Write-Verbose "InstallTestEngine: Cleanup complete - Removed: $($result.TotalCleaned), Failed: $($result.TotalFailed)"
    
    return $result
}

function Get-UninstallLeftovers {
    <#
    .SYNOPSIS
        Scans for leftover files, folders, and registry entries after uninstallation
    .PARAMETER AppName
        Application name to search for
    .PARAMETER Vendor
        Vendor name to search for
    .OUTPUTS
        Hashtable with Found (bool), Details (array), Summary (array)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [Parameter(Mandatory = $true)]
        [string]$Vendor,
        
        [Parameter(Mandatory = $false)]
        [bool]$UserContext = $false
    )
    
    Write-Verbose "InstallTestEngine: Scanning for leftovers..."
    
    $leftovers = @{
        Found = $false
        Details = @()
        Summary = @()
    }
    
    # Check common installation folders
    $foldersToCheck = @(
        "C:\Program Files\$Vendor",
        "C:\Program Files (x86)\$Vendor",
        "C:\ProgramData\$Vendor",
        "$env:APPDATA\$Vendor",
        "$env:LOCALAPPDATA\$Vendor"
    )
    
    foreach ($folder in $foldersToCheck) {
        if (Test-Path $folder) {
            $leftovers.Found = $true
            $leftovers.Details += [PSCustomObject]@{
                Type = "Folder"
                Location = $folder
            }
            $leftovers.Summary += "--- Folder: $folder"
            Write-Verbose "InstallTestEngine: Found leftover folder - $folder"
        }
    }
    
    # Check registry keys
    $registryPaths = @(
        "HKLM:\Software\$Vendor",
        "HKLM:\Software\Wow6432Node\$Vendor",
        "HKCU:\Software\$Vendor"
    )
    
    foreach ($regPath in $registryPaths) {
        if (Test-Path $regPath) {
            $leftovers.Found = $true
            $leftovers.Details += [PSCustomObject]@{
                Type = "Registry"
                Location = $regPath
            }
            $leftovers.Summary += "--- Registry: $regPath"
            Write-Verbose "InstallTestEngine: Found leftover registry key - $regPath"
        }
    }
    
    # Check Uninstall registry entries
    $uninstallPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    
    foreach ($uninstallPath in $uninstallPaths) {
        try {
            if (Test-Path $uninstallPath) {
                $subKeys = Get-ChildItem -Path $uninstallPath -ErrorAction SilentlyContinue
                foreach ($subKey in $subKeys) {
                    $app = Get-ItemProperty -Path $subKey.PSPath -ErrorAction SilentlyContinue
                    if ($app -and $app.DisplayName) {
                        if (($app.DisplayName -like "*$AppName*") -or ($app.Publisher -like "*$Vendor*")) {
                            $leftovers.Found = $true
                            $leftovers.Details += [PSCustomObject]@{
                                Type = "Uninstall Entry"
                                Location = $subKey.PSPath
                                DisplayName = $app.DisplayName
                            }
                            $leftovers.Summary += "--- Uninstall Entry: $($app.DisplayName)"
                            Write-Verbose "InstallTestEngine: Found leftover uninstall entry - $($app.DisplayName)"
                        }
                    }
                }
            }
        } catch {
            Write-Verbose "InstallTestEngine: Error scanning $uninstallPath"
        }
    }
    
    # Check Start Menu shortcuts (All Users and Current User)
    $startMenuPaths = @(
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
    )
    
    foreach ($startMenuPath in $startMenuPaths) {
        try {
            if (Test-Path $startMenuPath) {
                # Search for shortcuts containing vendor or app name
                $shortcuts = Get-ChildItem -Path $startMenuPath -Filter "*.lnk" -Recurse -ErrorAction SilentlyContinue
                
                foreach ($shortcut in $shortcuts) {
                    $shortcutName = $shortcut.Name -replace '\.lnk$', ''
                    $folderName = $shortcut.Directory.Name
                    
                    # Check if shortcut name or parent folder contains vendor/app name
                    if (($shortcutName -like "*$Vendor*") -or ($shortcutName -like "*$AppName*") -or 
                        ($folderName -like "*$Vendor*") -or ($folderName -like "*$AppName*")) {
                        $leftovers.Found = $true
                        $leftovers.Details += [PSCustomObject]@{
                            Type = "Start Menu Shortcut"
                            Location = $shortcut.FullName
                            ShortcutName = $shortcutName
                        }
                        $leftovers.Summary += "--- Start Menu: $($shortcut.FullName)"
                        Write-Verbose "InstallTestEngine: Found leftover Start Menu shortcut - $($shortcut.FullName)"
                    }
                }
                
                # Also check for vendor/app-named folders in Start Menu
                $folders = Get-ChildItem -Path $startMenuPath -Directory -Recurse -ErrorAction SilentlyContinue | 
                           Where-Object { $_.Name -like "*$Vendor*" -or $_.Name -like "*$AppName*" }
                
                foreach ($folder in $folders) {
                    # Only add if folder is empty or only contains shortcuts we already found
                    $folderContents = Get-ChildItem -Path $folder.FullName -Recurse -ErrorAction SilentlyContinue
                    if ($folderContents.Count -eq 0 -or ($folderContents | Where-Object { $_.Extension -ne '.lnk' }).Count -eq 0) {
                        $leftovers.Found = $true
                        $leftovers.Details += [PSCustomObject]@{
                            Type = "Start Menu Folder"
                            Location = $folder.FullName
                            FolderName = $folder.Name
                        }
                        $leftovers.Summary += "--- Start Menu Folder: $($folder.FullName)"
                        Write-Verbose "InstallTestEngine: Found leftover Start Menu folder - $($folder.FullName)"
                    }
                }
            }
        } catch {
            Write-Verbose "InstallTestEngine: Error scanning Start Menu at $startMenuPath"
        }
    }
    
    if (-not $leftovers.Found) {
        Write-Verbose "InstallTestEngine: No leftovers found - Clean uninstall"
    }
    
    return $leftovers
}

function Show-CompletionMessage {
    <#
    .SYNOPSIS
        Displays congratulations banner for successful packaging and testing
    .PARAMETER AppName
        Application name
    .PARAMETER AppVersion
        Application version
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [Parameter(Mandatory = $true)]
        [string]$AppVersion
    )
    
    $message = @"
CONGRATULATIONS!

$AppName $AppVersion

has been successfully:
[OK] Packaged
[OK] Installed & Tested
[OK] Validated
[OK] Uninstalled & Verified

Package is ready to move to Intune!
"@
    
    [System.Windows.Forms.MessageBox]::Show(
        $message,
        "Packaging Complete!",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
    
    Write-Verbose "InstallTestEngine: Packaging cycle completed successfully!"
}

# Export public functions
Export-ModuleMember -Function Start-InstallationTest, Start-UninstallationTest, Get-UninstallLeftovers, Remove-UninstallLeftovers, Show-CompletionMessage








