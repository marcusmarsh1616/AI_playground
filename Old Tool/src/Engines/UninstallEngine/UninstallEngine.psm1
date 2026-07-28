#Requires -Version 5.1

<#
.SYNOPSIS
    UninstallEngine - Determine likely uninstall executable names
.DESCRIPTION
    This engine provides lists of common uninstall executable names based on
    installer type. Helps users select the correct uninstaller for their package.
.NOTES
    Author: FRB Automation Team
    Created: June 4, 2026
    Version: 1.0.0
    Part of: FRB Packaging Tool Modular Architecture
#>

function Get-UninstallExecutableOptions {
    <#
    .SYNOPSIS
        Get likely uninstall executable names for an installer type
    .DESCRIPTION
        Returns an array of common uninstall executable names based on the installer type.
        Names are ordered from most common to least common.
    .PARAMETER InstallerType
        The installer type (InnoSetup, NSIS, InstallShield, MSI, Archiver, Generic)
    .EXAMPLE
        $uninstallers = Get-UninstallExecutableOptions -InstallerType "InnoSetup"
        Returns array like: "unins000.exe", "unins001.exe", etc.
    .OUTPUTS
        String[] - Array of likely uninstaller executable names
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallerType
    )
    
    Write-Verbose "UninstallEngine: Getting uninstall executable options for $InstallerType"
    
    $executables = @()
    
    switch ($InstallerType) {
        "InnoSetup" {
            $executables = @(
                "unins000.exe",
                "unins001.exe",
                "unins002.exe",
                "uninstall.exe",
                "uninst.exe"
            )
            Write-Verbose "UninstallEngine: InnoSetup typically uses unins*.exe pattern"
        }
        "NSIS" {
            $executables = @(
                "uninstall.exe",
                "Uninstall.exe",
                "uninst.exe",
                "Un_A.exe",
                "uninstaller.exe"
            )
            Write-Verbose "UninstallEngine: NSIS typically uses uninstall.exe or Un_A.exe"
        }
        "InstallShield" {
            $executables = @(
                "setup.exe",
                "uninstall.exe",
                "uninst.exe",
                "isuninst.exe",
                "unwise.exe"
            )
            Write-Verbose "UninstallEngine: InstallShield varies, often setup.exe or isuninst.exe"
        }
        "MSI" {
            $executables = @(
                "msiexec.exe",
                "uninstall.exe",
                "setup.exe"
            )
            Write-Verbose "UninstallEngine: MSI should use msiexec.exe with product code"
        }
        "Archiver" {
            $executables = @(
                "uninstall.exe",
                "uninst.exe",
                "Uninstall.exe"
            )
            Write-Verbose "UninstallEngine: Archiver-based installers typically use uninstall.exe"
        }
        "Generic" {
            $executables = @(
                "uninstall.exe",
                "uninst.exe",
                "unins000.exe",
                "Uninstall.exe",
                "uninstaller.exe",
                "setup.exe",
                "Un_A.exe",
                "unwise.exe",
                "isuninst.exe"
            )
            Write-Verbose "UninstallEngine: Generic - returning all common patterns"
        }
        default {
            Write-Warning "UninstallEngine: Unknown installer type '$InstallerType', using Generic options"
            $executables = @(
                "uninstall.exe",
                "uninst.exe",
                "unins000.exe",
                "Uninstall.exe",
                "uninstaller.exe",
                "setup.exe",
                "Un_A.exe",
                "unwise.exe",
                "isuninst.exe"
            )
        }
    }
    
    Write-Verbose "UninstallEngine: Returning $($executables.Count) uninstaller options"
    return $executables
}

function Get-UninstallOptionsForInstaller {
    <#
    .SYNOPSIS
        Get uninstall executable options for an installer file
    .DESCRIPTION
        Convenience function that detects installer type and returns uninstaller options.
        Requires DetectionEngine to be loaded.
    .PARAMETER FilePath
        Full path to the installer file
    .EXAMPLE
        $options = Get-UninstallOptionsForInstaller -FilePath "C:\Installers\Setup.exe"
        Returns hashtable with InstallerType and UninstallExecutables array
    .OUTPUTS
        Hashtable with keys: InstallerType, UninstallExecutables
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    Write-Verbose "UninstallEngine: Getting uninstall options for $FilePath"
    
    # Detect installer type (requires DetectionEngine)
    if (Get-Command Get-InstallerType -ErrorAction SilentlyContinue) {
        $installerType = Get-InstallerType -FilePath $FilePath
    } else {
        Write-Warning "UninstallEngine: DetectionEngine not loaded, using Generic"
        $installerType = "Generic"
    }
    
    $result = @{
        InstallerType = $installerType
        UninstallExecutables = Get-UninstallExecutableOptions -InstallerType $installerType
    }
    
    return $result
}

# Export public functions
Export-ModuleMember -Function Get-UninstallExecutableOptions, Get-UninstallOptionsForInstaller
