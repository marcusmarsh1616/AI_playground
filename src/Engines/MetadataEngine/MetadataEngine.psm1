#Requires -Version 5.1

<#
.SYNOPSIS
    MetadataEngine - Extract metadata from installer files
.DESCRIPTION
    This engine is responsible for extracting vendor, product name, and version 
    information from installer files by reading file properties and metadata.
.NOTES
    Author: FRB Automation Team
    Created: June 4, 2026
    Version: 1.0.0
    Part of: FRB Packaging Tool Modular Architecture
#>

function Get-InstallerMetadata {
    <#
    .SYNOPSIS
        Extracts metadata from an installer file
    .DESCRIPTION
        Reads file properties to extract vendor (company), product name, and version information.
        Works with both EXE and MSI installer files.
    .PARAMETER FilePath
        Full path to the installer file
    .EXAMPLE
        $metadata = Get-InstallerMetadata -FilePath "C:\Installers\Setup.exe"
        Returns hashtable with Vendor, ProductName, and Version
    .OUTPUTS
        Hashtable with keys: Vendor, ProductName, Version
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    Write-Verbose "MetadataEngine: Extracting metadata from $FilePath"
    
    $metadata = @{
        Vendor = ""
        ProductName = ""
        Version = ""
    }
    
    if (-not (Test-Path $FilePath)) {
        Write-Warning "MetadataEngine: File not found - $FilePath"
        return $metadata
    }
    
    try {
        $fileInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($FilePath)
        
        # Extract Company/Vendor
        if (-not [string]::IsNullOrWhiteSpace($fileInfo.CompanyName)) {
            $metadata.Vendor = $fileInfo.CompanyName
            Write-Verbose "MetadataEngine: Vendor found - $($metadata.Vendor)"
        }
        
        # Extract Product Name
        if (-not [string]::IsNullOrWhiteSpace($fileInfo.ProductName)) {
            $metadata.ProductName = $fileInfo.ProductName
            Write-Verbose "MetadataEngine: Product found - $($metadata.ProductName)"
        }
        
        # Extract Version
        if (-not [string]::IsNullOrWhiteSpace($fileInfo.ProductVersion)) {
            $metadata.Version = $fileInfo.ProductVersion
            Write-Verbose "MetadataEngine: Version found - $($metadata.Version)"
        }
        elseif (-not [string]::IsNullOrWhiteSpace($fileInfo.FileVersion)) {
            $metadata.Version = $fileInfo.FileVersion
            Write-Verbose "MetadataEngine: Version found (from FileVersion) - $($metadata.Version)"
        }
        
        Write-Verbose "MetadataEngine: Extraction complete"
    }
    catch {
        Write-Warning "MetadataEngine: Failed to extract metadata - $($_.Exception.Message)"
        # Return empty metadata on error (silent fail)
    }
    
    return $metadata
}

function Get-MsiProductCode {
    <#
    .SYNOPSIS
        Reads the ProductCode property from an MSI file
    .DESCRIPTION
        Opens the MSI's Property table via the WindowsInstaller.Installer COM
        object (the standard way to read MSI summary/property data without
        actually running msiexec) and returns the ProductCode GUID.
    .PARAMETER FilePath
        Full path to the .msi file
    .OUTPUTS
        String - the ProductCode GUID (with braces, as stored in the MSI), or
        an empty string if it could not be read.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        Write-Warning "MetadataEngine: MSI file not found - $FilePath"
        return ""
    }

    $installer = $null
    $database = $null
    $view = $null
    try {
        $installer = New-Object -ComObject WindowsInstaller.Installer
        $database = $installer.OpenDatabase($FilePath, 0)
        $view = $database.OpenView("SELECT `Value` FROM `Property` WHERE `Property` = 'ProductCode'")
        $view.Execute()
        $record = $view.Fetch()
        if ($record) {
            $productCode = [string]$record.StringData(1)
            Write-Verbose "MetadataEngine: MSI ProductCode found - $productCode"
            return $productCode
        }
        return ""
    }
    catch {
        Write-Warning "MetadataEngine: Failed to read MSI ProductCode - $($_.Exception.Message)"
        return ""
    }
    finally {
        if ($view) { try { $view.Close() } catch { } }
        foreach ($comObject in @($view, $database, $installer)) {
            if ($comObject) {
                [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($comObject)
            }
        }
    }
}

function Get-MatchingTransformFile {
    <#
    .SYNOPSIS
        Finds an .mst transform file matching an MSI's basename
    .DESCRIPTION
        Mirrors the zero-config MST auto-detection already used in
        Master Template\Startup.pss ([IO.Path]::ChangeExtension pattern) so
        the GUI can offer the same auto-detection when a technician selects
        MSI install media.
    .PARAMETER MsiPath
        Full path to the selected .msi file
    .OUTPUTS
        String - full path to the matching .mst file, or an empty string if
        none is found.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MsiPath
    )

    $candidateMstPath = [System.IO.Path]::ChangeExtension($MsiPath, 'mst')
    if (Test-Path -LiteralPath $candidateMstPath -PathType Leaf) {
        Write-Verbose "MetadataEngine: Matching MST found - $candidateMstPath"
        return $candidateMstPath
    }

    return ""
}

# Export public functions
Export-ModuleMember -Function Get-InstallerMetadata, Get-MsiProductCode, Get-MatchingTransformFile
