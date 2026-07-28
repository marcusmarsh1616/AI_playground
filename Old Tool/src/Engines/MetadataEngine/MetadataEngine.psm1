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

# Export public functions
Export-ModuleMember -Function Get-InstallerMetadata
