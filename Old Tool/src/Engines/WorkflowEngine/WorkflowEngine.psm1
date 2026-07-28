<#
.SYNOPSIS
    Workflow Engine - Orchestrates the complete package creation and testing workflow
.DESCRIPTION
    Manages the end-to-end workflow:
    1. Package creation
    2. Build EXE
    3. Install testing (with retry loop)
    4. Validation report
    5. Uninstall testing (with retry loop)
    6. Leftover detection
    7. Completion confirmation
.NOTES
    Engine: WorkflowEngine
    Version: 1.0.0
    Part of: FRB Package Creation Tool
#>

$script:WorkflowState = @{
    Stage = "Initial"
    PackagePath = $null
    InstallExePath = $null
    SoftwareInfo = @{
        Name = ""
        Version = ""
        Vendor = ""
    }
    InstallSwitches = ""
    UninstallSwitches = ""
    TestResults = @{
        InstallCompleted = $false
        UninstallCompleted = $false
        ValidationReportPath = $null
        LeftoverReportPath = $null
    }
}

function Initialize-Workflow {
    <#
    .SYNOPSIS
        Initializes a new workflow session
    .PARAMETER SoftwareName
        Name of the software
    .PARAMETER Version
        Version of the software
    .PARAMETER Vendor
        Vendor/Publisher
    .PARAMETER PackagePath
        Path to the package folder
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SoftwareName,
        
        [Parameter(Mandatory)]
        [string]$Version,
        
        [Parameter(Mandatory)]
        [string]$Vendor,
        
        [Parameter(Mandatory)]
        [string]$PackagePath
    )
    
    $script:WorkflowState.Stage = "Initialized"
    $script:WorkflowState.PackagePath = $PackagePath
    $script:WorkflowState.SoftwareInfo.Name = $SoftwareName
    $script:WorkflowState.SoftwareInfo.Version = $Version
    $script:WorkflowState.SoftwareInfo.Vendor = $Vendor
    
    Write-Verbose "Workflow initialized for $SoftwareName v$Version"
    
    return @{
        Success = $true
        Stage = $script:WorkflowState.Stage
    }
}

function Start-TestingWorkflow {
    <#
    .SYNOPSIS
        Starts the complete testing workflow after Build EXE
    .PARAMETER InstallExePath
        Path to the built Install.exe
    .PARAMETER ReturnToGUICallback
        ScriptBlock to return to GUI for retry
    .RETURNS
        Hashtable with workflow results
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InstallExePath,
        
        [scriptblock]$ReturnToGUICallback
    )
    
    $result = @{
        Success = $false
        Stage = ""
        CompletedSuccessfully = $false
        Reports = @()
    }
    
    try {
        $script:WorkflowState.InstallExePath = $InstallExePath
        $script:WorkflowState.Stage = "Testing"
        
        Write-Verbose "=== STARTING TESTING WORKFLOW ==="
        Write-Verbose "Install.exe: $InstallExePath"
        
        # STAGE 1: INSTALLATION TEST LOOP
        $installSuccess = $false
        $installAttempts = 0
        $maxAttempts = 10  # Prevent infinite loops
        
        while (-not $installSuccess -and $installAttempts -lt $maxAttempts) {
            $installAttempts++
            Write-Verbose "Installation test attempt #$installAttempts"
            
            $installResult = Start-InstallationTest `
                -InstallExePath $InstallExePath `
                -SoftwareName $script:WorkflowState.SoftwareInfo.Name `
                -Version $script:WorkflowState.SoftwareInfo.Version `
                -Vendor $script:WorkflowState.SoftwareInfo.Vendor `
                -OnRetry $ReturnToGUICallback
            
            if ($installResult.UserRequestedRetry) {
                # User wants to adjust switches - return to GUI
                Write-Verbose "User requested retry - returning to GUI"
                $result.Stage = "RetryRequested"
                $result.RetryType = "Install"
                return $result
            }
            
            if ($installResult.InstalledSuccessfully) {
                $installSuccess = $true
                $script:WorkflowState.TestResults.InstallCompleted = $true
                
                # STAGE 2: GENERATE VALIDATION REPORT
                Write-Verbose "Generating validation report..."
                
                $reportDir = Join-Path $script:WorkflowState.PackagePath "ValidationReports"
                if (-not (Test-Path $reportDir)) {
                    New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
                }
                
                $reportName = "$($script:WorkflowState.SoftwareInfo.Name) $($script:WorkflowState.SoftwareInfo.Version) Validation Report.html"
                $reportPath = Join-Path $reportDir $reportName
                
                New-HTMLValidationReport -InstallData $installResult.ValidationData -OutputPath $reportPath | Out-Null
                
                $script:WorkflowState.TestResults.ValidationReportPath = $reportPath
                $result.Reports += $reportPath
                
                # Show report to user
                $viewReport = [System.Windows.Forms.MessageBox]::Show(
                    "Validation report generated successfully!`r`n`r`n$reportPath`r`n`r`nWould you like to view the report?",
                    "Validation Report Ready",
                    [System.Windows.Forms.MessageBoxButtons]::YesNo,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
                
                if ($viewReport -eq [System.Windows.Forms.DialogResult]::Yes) {
                    Start-Process $reportPath
                }
            }
            else {
                # Installation failed unexpectedly
                [System.Windows.Forms.MessageBox]::Show(
                    "Installation failed: $($installResult.ErrorMessage)`r`n`r`nPlease check the installer and try again.",
                    "Installation Error",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
                $result.Stage = "InstallFailed"
                return $result
            }
        }
        
        # STAGE 3: CONFIRM READY FOR UNINSTALL
        $readyForUninstall = [System.Windows.Forms.MessageBox]::Show(
            "Installation testing complete!`r`n`r`nThe software is now installed on this system.`r`n`r`nAre you ready to test the UNINSTALLATION?",
            "Ready to Test Uninstall?",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        
        if ($readyForUninstall -ne [System.Windows.Forms.DialogResult]::Yes) {
            $result.Stage = "UserCancelled"
            return $result
        }
        
        # STAGE 4: UNINSTALLATION TEST LOOP
        $uninstallSuccess = $false
        $uninstallAttempts = 0
        
        while (-not $uninstallSuccess -and $uninstallAttempts -lt $maxAttempts) {
            $uninstallAttempts++
            Write-Verbose "Uninstallation test attempt #$uninstallAttempts"
            
            $uninstallResult = Start-UninstallationTest `
                -InstallExePath $InstallExePath `
                -SoftwareName $script:WorkflowState.SoftwareInfo.Name `
                -Version $script:WorkflowState.SoftwareInfo.Version `
                -Vendor $script:WorkflowState.SoftwareInfo.Vendor `
                -OnRetry $ReturnToGUICallback
            
            if ($uninstallResult.UserRequestedRetry) {
                # User wants to adjust switches - return to GUI
                Write-Verbose "User requested retry - returning to GUI"
                $result.Stage = "RetryRequested"
                $result.RetryType = "Uninstall"
                return $result
            }
            
            if ($uninstallResult.UninstalledSuccessfully) {
                $uninstallSuccess = $true
                $script:WorkflowState.TestResults.UninstallCompleted = $true
                
                # STAGE 5: GENERATE LEFTOVER REPORT
                Write-Verbose "Generating leftover report..."
                
                $leftoverReportName = "$($script:WorkflowState.SoftwareInfo.Name) $($script:WorkflowState.SoftwareInfo.Version) Leftover Report.html"
                $leftoverReportPath = Join-Path $reportDir $leftoverReportName
                
                New-LeftoverReport `
                    -LeftoverData $uninstallResult.LeftoverData `
                    -OutputPath $leftoverReportPath `
                    -SoftwareName $script:WorkflowState.SoftwareInfo.Name `
                    -Version $script:WorkflowState.SoftwareInfo.Version | Out-Null
                
                $script:WorkflowState.TestResults.LeftoverReportPath = $leftoverReportPath
                $result.Reports += $leftoverReportPath
                
                # Show leftover report
                $viewLeftoverReport = [System.Windows.Forms.MessageBox]::Show(
                    "Leftover scan complete!`r`n`r`n$leftoverReportPath`r`n`r`nWould you like to view the report?",
                    "Leftover Report Ready",
                    [System.Windows.Forms.MessageBoxButtons]::YesNo,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
                
                if ($viewLeftoverReport -eq [System.Windows.Forms.DialogResult]::Yes) {
                    Start-Process $leftoverReportPath
                }
            }
            else {
                # Uninstallation failed unexpectedly
                [System.Windows.Forms.MessageBox]::Show(
                    "Uninstallation failed: $($uninstallResult.ErrorMessage)`r`n`r`nPlease check and try again.",
                    "Uninstallation Error",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
                $result.Stage = "UninstallFailed"
                return $result
            }
        }
        
        # STAGE 6: COMPLETION!
        $script:WorkflowState.Stage = "Complete"
        
        Show-CompletionBanner `
            -SoftwareName $script:WorkflowState.SoftwareInfo.Name `
            -Version $script:WorkflowState.SoftwareInfo.Version
        
        $result.Success = $true
        $result.CompletedSuccessfully = $true
        $result.Stage = "Complete"
        
        Write-Verbose "=== WORKFLOW COMPLETE ==="
    }
    catch {
        Write-Error "Workflow error: $($_.Exception.Message)"
        $result.Success = $false
        $result.ErrorMessage = $_.Exception.Message
        $result.Stage = "Error"
    }
    
    return $result
}

function Get-WorkflowState {
    <#
    .SYNOPSIS
        Returns the current workflow state
    #>
    return $script:WorkflowState
}

function Reset-Workflow {
    <#
    .SYNOPSIS
        Resets workflow to initial state
    #>
    $script:WorkflowState = @{
        Stage = "Initial"
        PackagePath = $null
        InstallExePath = $null
        SoftwareInfo = @{
            Name = ""
            Version = ""
            Vendor = ""
        }
        InstallSwitches = ""
        UninstallSwitches = ""
        TestResults = @{
            InstallCompleted = $false
            UninstallCompleted = $false
            ValidationReportPath = $null
            LeftoverReportPath = $null
        }
    }
    
    Write-Verbose "Workflow reset to initial state"
}

# Export functions
Export-ModuleMember -Function Initialize-Workflow, Start-TestingWorkflow, Get-WorkflowState, Reset-Workflow
