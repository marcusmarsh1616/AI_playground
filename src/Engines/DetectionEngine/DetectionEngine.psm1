#Requires -Version 5.1

<#
.SYNOPSIS
    DetectionEngine - Detect installer type and technology
.DESCRIPTION
    This engine is responsible for identifying the installer technology used
    (InnoSetup, NSIS, InstallShield, MSI, etc.) by analyzing file properties and signatures.
.NOTES
    Author: FRB Automation Team
    Created: June 4, 2026
    Version: 1.0.0
    Part of: FRB Packaging Tool Modular Architecture
#>

function Get-InstallerType {
    <#
    .SYNOPSIS
        Detects the installer type/technology
    .DESCRIPTION
        Analyzes file properties and name patterns to determine the installer technology.
        Supports: InnoSetup, NSIS, InstallShield, MSI, Archiver-based, and Generic.
    .PARAMETER FilePath
        Full path to the installer file
    .EXAMPLE
        $type = Get-InstallerType -FilePath "C:\Installers\Setup.exe"
        Returns "InnoSetup", "NSIS", "InstallShield", "MSI", "Archiver", or "Generic"
    .OUTPUTS
        String - Installer type
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    Write-Verbose "DetectionEngine: Analyzing installer type for $FilePath"
    
    if (-not (Test-Path $FilePath)) {
        Write-Warning "DetectionEngine: File not found - $FilePath"
        return "Unknown"
    }
    
    try {
        $fileInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($FilePath)
        $fileName = [System.IO.Path]::GetFileName($FilePath).ToLower()
        $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
        
        # MSI files are easy to detect by extension
        if ($extension -eq ".msi") {
            Write-Verbose "DetectionEngine: Detected MSI (by extension)"
            return "MSI"
        }
        
        $installerType = "Generic"
        
        # Check file properties and name patterns for EXE files
        if ($extension -eq ".exe") {
            # InnoSetup Detection
            if ($fileInfo.ProductName -match "Inno Setup" -or 
                $fileInfo.Comments -match "Inno Setup" -or
                $fileName -match "setup.*\.exe") {
                $installerType = "InnoSetup"
                Write-Verbose "DetectionEngine: Detected InnoSetup"
            }
            # InstallShield Detection
            elseif ($fileInfo.ProductName -match "InstallShield" -or 
                    $fileInfo.LegalCopyright -match "InstallShield" -or
                    $fileInfo.Comments -match "InstallShield") {
                $installerType = "InstallShield"
                Write-Verbose "DetectionEngine: Detected InstallShield"
            }
            # NSIS Detection
            elseif ($fileInfo.ProductName -match "NSIS" -or 
                    $fileInfo.Comments -match "Nullsoft" -or
                    $fileInfo.LegalCopyright -match "Nullsoft") {
                $installerType = "NSIS"
                Write-Verbose "DetectionEngine: Detected NSIS"
            }
            # WiX Detection
            elseif ($fileInfo.ProductName -match "WiX") {
                $installerType = "MSI"
                Write-Verbose "DetectionEngine: Detected WiX (MSI-based)"
            }
            # Archiver Detection
            elseif ($fileName -match "winrar|7zip|winzip") {
                $installerType = "Archiver"
                Write-Verbose "DetectionEngine: Detected Archiver-based"
            }
            else {
                Write-Verbose "DetectionEngine: Using Generic detection"
            }
        }
        
        return $installerType
    }
    catch {
        Write-Warning "DetectionEngine: Error during detection - $($_.Exception.Message)"
        return "Generic"
    }
}

# Export public functions
Export-ModuleMember -Function Get-InstallerType
