#Requires -Version 5.1

<#
.SYNOPSIS
    SwitchEngine - Provide installer-specific command-line switches
.DESCRIPTION
    This engine provides install and uninstall command-line switches based on
    detected installer type. Contains switch templates for all major installer technologies.
.NOTES
    Author: FRB Automation Team
    Created: June 4, 2026
    Version: 1.0.0
    Part of: FRB Packaging Tool Modular Architecture
#>

function Get-InstallSwitches {
    <#
    .SYNOPSIS
        Get install switches for a specific installer type
    .DESCRIPTION
        Returns an array of common install switches for the specified installer type.
        Switches are ordered from most silent/comprehensive to least.
    .PARAMETER InstallerType
        The installer type (InnoSetup, NSIS, InstallShield, MSI, Archiver, Generic)
    .EXAMPLE
        $switches = Get-InstallSwitches -InstallerType "InnoSetup"
        Returns array of InnoSetup install switches
    .OUTPUTS
        String[] - Array of install switches
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallerType
    )
    
    Write-Verbose "SwitchEngine: Getting install switches for $InstallerType"
    
    $switches = @()
    
    switch ($InstallerType) {
        "InnoSetup" {
            $switches = @(
                "/VERYSILENT /NORESTART /SUPPRESSMSGBOXES /SP- /NOICONS",
                "/SILENT /NORESTART /SUPPRESSMSGBOXES /SP-",
                "/VERYSILENT /NORESTART /SUPPRESSMSGBOXES",
                "/SILENT /NORESTART"
            )
        }
        "NSIS" {
            $switches = @(
                "/S /NCRC /D=",
                "/S",
                "/SILENT",
                "/VERYSILENT"
            )
        }
        "InstallShield" {
            $switches = @(
                "/s /v`"/qn REBOOT=ReallySuppress`"",
                "/s /v`"/qb! REBOOT=ReallySuppress`"",
                "/s /SMS",
                "/s /f1setup.iss /f2C:\install.log"
            )
        }
        "MSI" {
            $switches = @(
                "/qn REBOOT=ReallySuppress ALLUSERS=1",
                "/qb! REBOOT=ReallySuppress",
                "/quiet /norestart",
                "/passive /norestart"
            )
        }
        "Archiver" {
            $switches = @(
                "/S",
                "/SILENT",
                "/VERYSILENT /NORESTART"
            )
        }
        "Generic" {
            $switches = @(
                "/S",
                "/SILENT",
                "/VERYSILENT",
                "/quiet",
                "/qn",
                "-silent",
                "--silent",
                "/s /v`"/qn`""
            )
        }
        default {
            Write-Warning "SwitchEngine: Unknown installer type '$InstallerType', using Generic switches"
            $switches = @(
                "/S",
                "/SILENT",
                "/VERYSILENT",
                "/quiet",
                "/qn",
                "-silent",
                "--silent",
                "/s /v`"/qn`""
            )
        }
    }
    
    Write-Verbose "SwitchEngine: Returning $($switches.Count) install switch options"
    return $switches
}

function Get-UninstallSwitches {
    <#
    .SYNOPSIS
        Get uninstall switches for a specific installer type
    .DESCRIPTION
        Returns an array of common uninstall switches for the specified installer type.
        Switches are ordered from most silent/comprehensive to least.
    .PARAMETER InstallerType
        The installer type (InnoSetup, NSIS, InstallShield, MSI, Archiver, Generic)
    .EXAMPLE
        $switches = Get-UninstallSwitches -InstallerType "NSIS"
        Returns array of NSIS uninstall switches
    .OUTPUTS
        String[] - Array of uninstall switches
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallerType
    )
    
    Write-Verbose "SwitchEngine: Getting uninstall switches for $InstallerType"
    
    $switches = @()
    
    switch ($InstallerType) {
        "InnoSetup" {
            $switches = @(
                "/VERYSILENT /NORESTART /SUPPRESSMSGBOXES",
                "/SILENT /NORESTART",
                "/VERYSILENT"
            )
        }
        "NSIS" {
            $switches = @(
                "/S",
                "/SILENT",
                "_?="
            )
        }
        "InstallShield" {
            $switches = @(
                "/s /x /v`"/qn REBOOT=ReallySuppress`"",
                "/s /x",
                "-uninst"
            )
        }
        "MSI" {
            $switches = @(
                "/qn REBOOT=ReallySuppress",
                "/quiet /norestart",
                "/passive /norestart"
            )
        }
        "Archiver" {
            $switches = @(
                "/S",
                "/SILENT",
                "/VERYSILENT"
            )
        }
        "Generic" {
            $switches = @(
                "/S",
                "/SILENT",
                "/VERYSILENT",
                "/uninstall /quiet",
                "/x /quiet",
                "-uninstall -silent",
                "--uninstall --silent"
            )
        }
        default {
            Write-Warning "SwitchEngine: Unknown installer type '$InstallerType', using Generic switches"
            $switches = @(
                "/S",
                "/SILENT",
                "/VERYSILENT",
                "/uninstall /quiet",
                "/x /quiet",
                "-uninstall -silent",
                "--uninstall --silent"
            )
        }
    }
    
    Write-Verbose "SwitchEngine: Returning $($switches.Count) uninstall switch options"
    return $switches
}

function Get-SwitchesForInstaller {
    <#
    .SYNOPSIS
        Get both install and uninstall switches for an installer file
    .DESCRIPTION
        Convenience function that detects installer type and returns both install and uninstall switches.
        Requires DetectionEngine to be loaded.
    .PARAMETER FilePath
        Full path to the installer file
    .EXAMPLE
        $allSwitches = Get-SwitchesForInstaller -FilePath "C:\Installers\Setup.exe"
        Returns hashtable with InstallSwitches and UninstallSwitches arrays
    .OUTPUTS
        Hashtable with keys: InstallerType, InstallSwitches, UninstallSwitches
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    Write-Verbose "SwitchEngine: Getting all switches for $FilePath"
    
    # Detect installer type (requires DetectionEngine)
    if (Get-Command Get-InstallerType -ErrorAction SilentlyContinue) {
        $installerType = Get-InstallerType -FilePath $FilePath
    } else {
        Write-Warning "SwitchEngine: DetectionEngine not loaded, using Generic"
        $installerType = "Generic"
    }
    
    $result = @{
        InstallerType = $installerType
        InstallSwitches = Get-InstallSwitches -InstallerType $installerType
        UninstallSwitches = Get-UninstallSwitches -InstallerType $installerType
    }
    
    return $result
}

# Export public functions
Export-ModuleMember -Function Get-InstallSwitches, Get-UninstallSwitches, Get-SwitchesForInstaller
