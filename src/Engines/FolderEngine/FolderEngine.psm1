#Requires -Version 5.1

<#
.SYNOPSIS
    FolderEngine - Manage packaging folder structure
.DESCRIPTION
    This engine is responsible for creating packaging folder structures, copying template files,
    copying installer media, and updating project files.
.NOTES
    Author: FRB Automation Team
    Created: June 4, 2026
    Version: 1.0.0
    Part of: FRB Packaging Tool Modular Architecture
#>

function New-PackagingFolderStructure {
    <#
    .SYNOPSIS
        Creates the packaging folder structure
    .DESCRIPTION
        Creates the vendor/product/version folder hierarchy in the base packaging path.
    .PARAMETER BasePath
        Base packaging path
    .PARAMETER Vendor
        Vendor/company name
    .PARAMETER ProductName
        Product name
    .PARAMETER Edition
        Product edition (optional)
    .PARAMETER Version
        Product version
    .PARAMETER OverwriteIfExists
        If true, overwrites existing folder. If false, prompts user.
    .EXAMPLE
        $result = New-PackagingFolderStructure -BasePath "C:\Packages" -Vendor "Adobe" -ProductName "Reader" -Edition "Pro" -Version "2023.1"
    .OUTPUTS
        Hashtable with keys: Success (bool), FolderPath (string), Message (string)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,
        
        [Parameter(Mandatory = $true)]
        [string]$Vendor,
        
        [Parameter(Mandatory = $true)]
        [string]$ProductName,
        
        [Parameter(Mandatory = $false)]
        [string]$Edition = "",
        
        [Parameter(Mandatory = $true)]
        [string]$Version,
        
        [Parameter(Mandatory = $false)]
        [bool]$OverwriteIfExists = $false
    )
    
    Write-Verbose "FolderEngine: Creating packaging folder structure"
    
    try {
        # Build the folder path
        $folderPath = Join-Path $BasePath $Vendor
        $folderPath = Join-Path $folderPath $ProductName
        if (-not [string]::IsNullOrWhiteSpace($Edition)) {
            $folderPath = Join-Path $folderPath $Edition
        }
        $folderPath = Join-Path $folderPath $Version
        
        Write-Verbose "FolderEngine: Target path - $folderPath"
        
        # Check if folder already exists
        if (Test-Path $folderPath) {
            if ($OverwriteIfExists) {
                Write-Verbose "FolderEngine: Removing existing folder"
                Remove-Item -Path $folderPath -Recurse -Force
            } else {
                return @{
                    Success = $false
                    FolderPath = $folderPath
                    Message = "Folder already exists"
                }
            }
        }
        
        # Create the folder structure
        New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
        Write-Verbose "FolderEngine: Folder created successfully"
        
        return @{
            Success = $true
            FolderPath = $folderPath
            Message = "Folder created successfully"
        }
    }
    catch {
        Write-Error "FolderEngine: Error creating folder - $($_.Exception.Message)"
        return @{
            Success = $false
            FolderPath = ""
            Message = $_.Exception.Message
        }
    }
}

function Copy-TemplateFiles {
    <#
    .SYNOPSIS
        Copies template files to packaging folder
    .DESCRIPTION
        Copies all files from the master template to the target packaging folder.
    .PARAMETER TemplatePath
        Path to master template folder
    .PARAMETER DestinationPath
        Destination packaging folder path
    .EXAMPLE
        $result = Copy-TemplateFiles -TemplatePath "C:\Templates\Master" -DestinationPath "C:\Packages\Adobe\Reader\2023.1"
    .OUTPUTS
        Hashtable with keys: Success (bool), FilesCopied (int), Message (string)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TemplatePath,
        
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )
    
    Write-Verbose "FolderEngine: Copying template files"
    
    try {
        if (-not (Test-Path $TemplatePath)) {
            throw "Template path not found: $TemplatePath"
        }
        
        if (-not (Test-Path $DestinationPath)) {
            throw "Destination path not found: $DestinationPath"
        }
        
        # Get all items from template
        $items = Get-ChildItem -Path $TemplatePath -Recurse
        $filesCopied = 0
        
        foreach ($item in $items) {
            $relativePath = $item.FullName.Substring($TemplatePath.Length)
            $targetPath = Join-Path $DestinationPath $relativePath
            
            if ($item.PSIsContainer) {
                # Create directory
                if (-not (Test-Path $targetPath)) {
                    New-Item -Path $targetPath -ItemType Directory -Force | Out-Null
                }
            } else {
                # Copy file
                Copy-Item -Path $item.FullName -Destination $targetPath -Force
                $filesCopied++
            }
        }
        
        Write-Verbose "FolderEngine: Copied $filesCopied files"
        
        return @{
            Success = $true
            FilesCopied = $filesCopied
            Message = "Template files copied successfully"
        }
    }
    catch {
        Write-Error "FolderEngine: Error copying template files - $($_.Exception.Message)"
        return @{
            Success = $false
            FilesCopied = 0
            Message = $_.Exception.Message
        }
    }
}

function Copy-InstallerToPackage {
    <#
    .SYNOPSIS
        Copies installer media to package Data folder
    .DESCRIPTION
        Copies the installer file to the Data subfolder of the packaging folder.
    .PARAMETER InstallerPath
        Path to installer file
    .PARAMETER PackagePath
        Path to packaging folder
    .EXAMPLE
        $result = Copy-InstallerToPackage -InstallerPath "C:\Installers\Setup.exe" -PackagePath "C:\Packages\Adobe\Reader\2023.1"
    .OUTPUTS
        Hashtable with keys: Success (bool), DestinationPath (string), Message (string)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallerPath,
        
        [Parameter(Mandatory = $true)]
        [string]$PackagePath
    )
    
    Write-Verbose "FolderEngine: Copying installer to package"
    
    try {
        if (-not (Test-Path $InstallerPath)) {
            throw "Installer file not found: $InstallerPath"
        }
        
        # Ensure Data folder exists
        $dataFolder = Join-Path $PackagePath "Data"
        if (-not (Test-Path $dataFolder)) {
            New-Item -Path $dataFolder -ItemType Directory -Force | Out-Null
        }
        
        # Copy installer to Data folder
        $fileName = [System.IO.Path]::GetFileName($InstallerPath)
        $destination = Join-Path $dataFolder $fileName
        
        Copy-Item -Path $InstallerPath -Destination $destination -Force
        Write-Verbose "FolderEngine: Installer copied to $destination"
        
        return @{
            Success = $true
            DestinationPath = $destination
            Message = "Installer copied successfully"
        }
    }
    catch {
        Write-Error "FolderEngine: Error copying installer - $($_.Exception.Message)"
        return @{
            Success = $false
            DestinationPath = ""
            Message = $_.Exception.Message
        }
    }
}

# Export public functions
Export-ModuleMember -Function New-PackagingFolderStructure, Copy-TemplateFiles, Copy-InstallerToPackage
