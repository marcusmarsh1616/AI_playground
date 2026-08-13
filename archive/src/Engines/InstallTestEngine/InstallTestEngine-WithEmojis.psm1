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
    Version: 1.0.0
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
        [string]$Vendor
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
        
        Write-Verbose "InstallTestEngine: Launching Install.exe..."
        
        # Create process start info with UAC elevation
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $InstallExePath
        $processInfo.Verb = "runas"  # Request UAC elevation
        $processInfo.UseShellExecute = $true
        
        # Start installation
        $process = [System.Diagnostics.Process]::Start($processInfo)
        
        if ($process) {
            Write-Verbose "InstallTestEngine: Process started (PID: $($process.Id))"
            
            # Wait for installation to complete
            $process.WaitForExit()
            
            $result.ExitCode = $process.ExitCode
            Write-Verbose "InstallTestEngine: Installation completed with exit code: $($result.ExitCode)"
            
            # Wait for system to settle
            Start-Sleep -Seconds 3
            
            # Prompt technician for verification
            $response = [System.Windows.Forms.MessageBox]::Show(
                "Installation of $AppName $AppVersion has completed.`n`nExit Code: $($result.ExitCode)`n`nDid the INSTALLATION function as designed?`n`nYES = Proceed with validation report`nNO = Return to GUI to adjust switches",
                "Installation Verification",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
            
            if ($response -eq [System.Windows.Forms.DialogResult]::Yes) {
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
            $result.ErrorMessage = "Failed to start Install.exe process"
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
        [string]$Vendor
    )
    
    Write-Verbose "InstallTestEngine: Starting uninstallation test for $AppName $AppVersion"
    
    $result = @{
        Success = $false
        UserConfirmed = $false
        ExitCode = -1
        LeftoversFound = $false
        LeftoverDetails = @()
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
        
        # Create process start info with UAC elevation
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $InstallExePath
        $processInfo.Arguments = "/uninstall"
        $processInfo.Verb = "runas"  # Request UAC elevation
        $processInfo.UseShellExecute = $true
        
        # Start uninstallation
        $process = [System.Diagnostics.Process]::Start($processInfo)
        
        if ($process) {
            Write-Verbose "InstallTestEngine: Process started (PID: $($process.Id))"
            
            # Wait for uninstallation to complete
            $process.WaitForExit()
            
            $result.ExitCode = $process.ExitCode
            Write-Verbose "InstallTestEngine: Uninstallation completed with exit code: $($result.ExitCode)"
            
            # Wait for system to settle
            Start-Sleep -Seconds 3
            
            # Scan for leftovers
            Write-Verbose "InstallTestEngine: Scanning for leftover files and registry entries..."
            $leftovers = Get-UninstallLeftovers -AppName $AppName -Vendor $Vendor
            
            $result.LeftoversFound = $leftovers.Found
            $result.LeftoverDetails = $leftovers.Details
            
            # Build leftover report message
            $leftoverMsg = if ($leftovers.Found) {
                "`n`n⚠ LEFTOVERS DETECTED:`n" + ($leftovers.Summary -join "`n")
            } else {
                "`n`n✓ No leftovers detected - Clean uninstall!"
            }
            
            # Prompt technician for verification
            $response = [System.Windows.Forms.MessageBox]::Show(
                "Uninstallation of $AppName $AppVersion has completed.`n`nExit Code: $($result.ExitCode)$leftoverMsg`n`nDid the UNINSTALLATION function as designed?`n`nYES = Complete packaging`nNO = Return to GUI to adjust uninstall settings",
                "Uninstallation Verification",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
            
            if ($response -eq [System.Windows.Forms.DialogResult]::Yes) {
                $result.Success = $true
                $result.UserConfirmed = $true
                Write-Verbose "InstallTestEngine: Uninstallation confirmed by technician"
            } else {
                $result.Success = $false
                $result.UserConfirmed = $false
                $result.ErrorMessage = "Technician indicated uninstallation did not function as designed"
                Write-Warning $result.ErrorMessage
            }
        } else {
            $result.ErrorMessage = "Failed to start Install.exe /uninstall process"
            Write-Error $result.ErrorMessage
        }
    }
    catch {
        $result.ErrorMessage = "Uninstallation test failed: $($_.Exception.Message)"
        Write-Error $result.ErrorMessage
    }
    
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
        [string]$Vendor
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
            $leftovers.Summary += "• Folder: $folder"
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
            $leftovers.Summary += "• Registry: $regPath"
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
                            $leftovers.Summary += "• Uninstall Entry: $($app.DisplayName)"
                            Write-Verbose "InstallTestEngine: Found leftover uninstall entry - $($app.DisplayName)"
                        }
                    }
                }
            }
        } catch {
            Write-Verbose "InstallTestEngine: Error scanning $uninstallPath"
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
🎉 CONGRATULATIONS! 🎉

$AppName $AppVersion

has been successfully:
✓ Packaged
✓ Installed & Tested
✓ Validated
✓ Uninstalled & Verified

📦 Package is ready to move to Intune! 📦
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
Export-ModuleMember -Function Start-InstallationTest, Start-UninstallationTest, Get-UninstallLeftovers, Show-CompletionMessage
