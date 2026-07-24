#Requires -Version 5.1

<#
.SYNOPSIS
    InstallEngine - Handles software installation execution
.DESCRIPTION
    This engine is responsible for launching software installers with UAC elevation,
    monitoring installation progress, and handling exit codes.
.NOTES
    Author: IT Automation Team
    Created: June 4, 2026
    Version: 1.0.0
    PowerShell Version: 5.1
    Part of: Install Validation Tool Modular Architecture
#>

function Start-SoftwareInstallation {
    <#
    .SYNOPSIS
        Executes a software installer with UAC elevation
    .DESCRIPTION
        Launches an installer executable or MSI with elevation, waits for completion,
        and returns the exit code.
    .PARAMETER InstallerPath
        Full path to the installer file
    .PARAMETER Arguments
        Command-line arguments to pass to the installer (optional)
    .EXAMPLE
        $result = Start-SoftwareInstallation -InstallerPath "C:\Installers\setup.exe" -Arguments "/silent"
    .OUTPUTS
        Hashtable with keys: Success (bool), ExitCode (int), ProcessId (int), ErrorMessage (string)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$InstallerPath,
        
        [Parameter(Mandatory = $false)]
        [string]$Arguments = ""
    )
    
    Write-Verbose "InstallEngine: Starting installation - $InstallerPath"
    
    $result = @{
        Success = $false
        ExitCode = -1
        ProcessId = 0
        ErrorMessage = ""
    }
    
    # Validate installer exists
    if (-not (Test-Path $InstallerPath)) {
        $result.ErrorMessage = "Installer file not found: $InstallerPath"
        Write-Error $result.ErrorMessage
        return $result
    }
    
    try {
        # Create process start info with UAC elevation
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $InstallerPath
        $processInfo.Arguments = $Arguments
        $processInfo.Verb = "runas"  # Request UAC elevation
        $processInfo.UseShellExecute = $true
        
        Write-Verbose "InstallEngine: Launching installer with UAC elevation"
        $process = [System.Diagnostics.Process]::Start($processInfo)
        
        if ($process) {
            $result.ProcessId = $process.Id
            Write-Verbose "InstallEngine: Process started (PID: $($process.Id))"
            
            # Wait for installation to complete
            Write-Verbose "InstallEngine: Waiting for installation to complete..."
            $process.WaitForExit()
            
            $result.ExitCode = $process.ExitCode
            Write-Verbose "InstallEngine: Installation completed with exit code: $($result.ExitCode)"
            
            # Exit code 0 typically means success
            if ($result.ExitCode -eq 0) {
                $result.Success = $true
            } else {
                $result.ErrorMessage = "Installation completed with non-zero exit code: $($result.ExitCode)"
                Write-Warning $result.ErrorMessage
            }
        } else {
            $result.ErrorMessage = "Failed to start installer process"
            Write-Error $result.ErrorMessage
        }
    }
    catch {
        $result.ErrorMessage = "Installation failed: $($_.Exception.Message)"
        Write-Error $result.ErrorMessage
    }
    
    return $result
}

function Test-InstallationResult {
    <#
    .SYNOPSIS
        Evaluates installation result and provides user feedback options
    .DESCRIPTION
        Checks exit code and prompts user to confirm if installation performed as designed.
        Returns whether to proceed with validation.
    .PARAMETER ExitCode
        The exit code from the installer process
    .EXAMPLE
        $shouldValidate = Test-InstallationResult -ExitCode 0
    .OUTPUTS
        Boolean - True if should proceed with validation, False otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode
    )
    
    Write-Verbose "InstallEngine: Evaluating installation result (Exit Code: $ExitCode)"
    
    # Exit code 0 is typically success
    if ($ExitCode -eq 0) {
        Write-Verbose "InstallEngine: Exit code indicates success"
        return $true
    }
    # Exit codes 3010 and 3011 mean success but reboot required
    elseif ($ExitCode -eq 3010 -or $ExitCode -eq 3011) {
        Write-Verbose "InstallEngine: Exit code indicates success with reboot required"
        return $true
    }
    # Other exit codes may indicate failure or user cancellation
    else {
        Write-Warning "InstallEngine: Exit code $ExitCode may indicate an issue"
        return $false
    }
}

# Export public functions
Export-ModuleMember -Function Start-SoftwareInstallation, Test-InstallationResult
