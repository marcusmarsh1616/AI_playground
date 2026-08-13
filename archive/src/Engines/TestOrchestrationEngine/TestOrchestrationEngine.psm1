<#
.SYNOPSIS
    Test Orchestration Engine - Manages installation and uninstallation testing workflow
.DESCRIPTION
    Orchestrates the complete test cycle including:
    - Install testing with success verification loop
    - Validation report generation
    - Uninstall testing with success verification loop
    - Leftover detection and reporting
.NOTES
    Engine: TestOrchestrationEngine
    Version: 1.0.0
    Part of: FRB Package Creation Tool
#>

function Start-InstallationTest {
    <#
    .SYNOPSIS
        Orchestrates installation testing with loop-until-success
    .PARAMETER InstallExePath
        Path to the Install.exe file to test
    .PARAMETER SoftwareName
        Name of the software being installed
    .PARAMETER Version
        Version of the software
    .PARAMETER Vendor
        Vendor/Publisher of the software
    .PARAMETER OnRetry
        ScriptBlock to execute when user wants to retry (return to GUI with data)
    .RETURNS
        Hashtable with Success, InstalledSuccessfully, ValidationData
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InstallExePath,
        
        [Parameter(Mandatory)]
        [string]$SoftwareName,
        
        [Parameter(Mandatory)]
        [string]$Version,
        
        [Parameter(Mandatory)]
        [string]$Vendor,
        
        [scriptblock]$OnRetry
    )
    
    $result = @{
        Success = $false
        InstalledSuccessfully = $false
        ValidationData = $null
        UserRequestedRetry = $false
    }
    
    try {
        # Launch installation
        Write-Verbose "Launching installation: $InstallExePath"
        $installResult = Start-SoftwareInstallation -InstallerPath $InstallExePath
        
        if ($installResult.Success) {
            # Wait for system to settle
            Start-Sleep -Seconds 5
            
            # Ask user if installation worked
            $confirmResult = [System.Windows.Forms.MessageBox]::Show(
                "Installation completed with exit code: $($installResult.ExitCode)`r`n`r`nDid the INSTALLATION function as designed?`r`n`r`nYES - Continue to validation`r`nNO - Return to adjust install switches",
                "Installation Verification",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
            
            if ($confirmResult -eq [System.Windows.Forms.DialogResult]::Yes) {
                # Installation successful - proceed with validation
                Write-Verbose "User confirmed installation success"
                
                # Scan for installed software
                $scanData = Get-InstalledSoftwareData -Software $SoftwareName -Vendor $Vendor -Version $Version
                
                $result.Success = $true
                $result.InstalledSuccessfully = $true
                $result.ValidationData = $scanData
            }
            else {
                # User wants to retry - return to GUI
                Write-Verbose "User indicated installation failed - retry requested"
                $result.UserRequestedRetry = $true
                
                if ($OnRetry) {
                    & $OnRetry
                }
            }
        }
        else {
            # Installation failed
            $result.Success = $false
            $result.ErrorMessage = "Installation failed with exit code: $($installResult.ExitCode)"
        }
    }
    catch {
        $result.Success = $false
        $result.ErrorMessage = $_.Exception.Message
    }
    
    return $result
}

function Start-UninstallationTest {
    <#
    .SYNOPSIS
        Orchestrates uninstallation testing with loop-until-success and leftover detection
    .PARAMETER InstallExePath
        Path to the Install.exe file to run with /uninstall
    .PARAMETER SoftwareName
        Name of the software being uninstalled
    .PARAMETER Version
        Version of the software
    .PARAMETER Vendor
        Vendor/Publisher of the software
    .PARAMETER OnRetry
        ScriptBlock to execute when user wants to retry (return to GUI with data)
    .RETURNS
        Hashtable with Success, UninstalledSuccessfully, LeftoverData
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InstallExePath,
        
        [Parameter(Mandatory)]
        [string]$SoftwareName,
        
        [Parameter(Mandatory)]
        [string]$Version,
        
        [Parameter(Mandatory)]
        [string]$Vendor,
        
        [scriptblock]$OnRetry
    )
    
    $result = @{
        Success = $false
        UninstalledSuccessfully = $false
        LeftoverData = $null
        UserRequestedRetry = $false
    }
    
    try {
        # Launch uninstallation
        Write-Verbose "Launching uninstallation: $InstallExePath /uninstall"
        $uninstallResult = Start-SoftwareInstallation -InstallerPath $InstallExePath -Arguments "/uninstall"
        
        if ($uninstallResult.Success) {
            # Wait for system to settle
            Start-Sleep -Seconds 5
            
            # Scan for leftovers
            Write-Verbose "Scanning for leftover files and registry entries..."
            $leftoverData = Get-UninstallLeftovers -SoftwareName $SoftwareName -Vendor $Vendor
            
            $hasLeftovers = ($leftoverData.Files.Count -gt 0) -or ($leftoverData.RegistryKeys.Count -gt 0)
            
            # Build leftover message
            $leftoverMessage = if ($hasLeftovers) {
                "WARNING - Leftovers Detected:`r`n" +
                "  Files: $($leftoverData.Files.Count)`r`n" +
                "  Registry Keys: $($leftoverData.RegistryKeys.Count)`r`n`r`n"
            }
            else {
                "No leftovers detected`r`n`r`n"
            }
            
            # Ask user if uninstallation worked
            $confirmResult = [System.Windows.Forms.MessageBox]::Show(
                "Uninstallation completed with exit code: $($uninstallResult.ExitCode)`r`n`r`n" +
                $leftoverMessage +
                "Did the UNINSTALLATION function as designed?`r`n`r`n" +
                "YES - Package is ready for deployment`r`n" +
                "NO - Return to adjust uninstall media/switches",
                "Uninstallation Verification",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
            
            if ($confirmResult -eq [System.Windows.Forms.DialogResult]::Yes) {
                # Uninstallation successful
                Write-Verbose "User confirmed uninstallation success"
                $result.Success = $true
                $result.UninstalledSuccessfully = $true
                $result.LeftoverData = $leftoverData
            }
            else {
                # User wants to retry
                Write-Verbose "User indicated uninstallation failed - retry requested"
                $result.UserRequestedRetry = $true
                
                if ($OnRetry) {
                    & $OnRetry
                }
            }
        }
        else {
            $result.Success = $false
            $result.ErrorMessage = "Uninstallation failed with exit code: $($uninstallResult.ExitCode)"
        }
    }
    catch {
        $result.Success = $false
        $result.ErrorMessage = $_.Exception.Message
    }
    
    return $result
}

function Show-CompletionBanner {
    <#
    .SYNOPSIS
        Displays congratulations banner when package testing is complete
    .PARAMETER SoftwareName
        Name of the software
    .PARAMETER Version
        Version of the software
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SoftwareName,
        
        [Parameter(Mandatory)]
        [string]$Version
    )
    
    $message = @"
PACKAGE TESTING COMPLETE

Package: $SoftwareName
Version: $Version

Installation tested successfully
Validation report generated
Uninstallation tested successfully
Leftover scan completed

Ready for deployment to Intune
"@
    
    [System.Windows.Forms.MessageBox]::Show(
        $message,
        "Package Testing Complete",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
}

# Export functions
Export-ModuleMember -Function Start-InstallationTest, Start-UninstallationTest, Show-CompletionBanner
