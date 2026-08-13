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

function Export-InstallMediaIconToDocs {
    <#
    .SYNOPSIS
        Extracts installer icon and exports it as JPG to package Docs folder
    .DESCRIPTION
        Uses the install media associated icon and saves a deterministic JPG artifact in Docs.
    .PARAMETER InstallerPath
        Path to installer file (EXE/MSI/etc.)
    .PARAMETER PackagePath
        Path to packaging folder
    .PARAMETER AppName
        Optional app name used for output file naming
    .OUTPUTS
        Hashtable with keys: Success (bool), OutputPath (string), Message (string)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallerPath,

        [Parameter(Mandatory = $true)]
        [string]$PackagePath,

        [Parameter(Mandatory = $false)]
        [string]$AppName = ""
    )

    Write-Verbose "FolderEngine: Exporting install media icon to Docs"

    $icon = $null
    $bitmap = $null
    try {
        if (-not (Test-Path $InstallerPath)) {
            throw "Installer file not found: $InstallerPath"
        }

        if (-not (Test-Path $PackagePath)) {
            throw "Package path not found: $PackagePath"
        }

        $docsFolder = Join-Path $PackagePath "Docs"
        if (-not (Test-Path $docsFolder)) {
            New-Item -Path $docsFolder -ItemType Directory -Force | Out-Null
        }

        Add-Type -AssemblyName System.Drawing

        $baseName = if (-not [string]::IsNullOrWhiteSpace($AppName)) { $AppName } else { [System.IO.Path]::GetFileNameWithoutExtension($InstallerPath) }
        $safeBaseName = [regex]::Replace($baseName, '[^A-Za-z0-9._-]', '_').Trim('_')
        if ([string]::IsNullOrWhiteSpace($safeBaseName)) {
            $safeBaseName = "install-media"
        }

        $outputPath = Join-Path $docsFolder ("{0}-icon.jpg" -f $safeBaseName)

        $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($InstallerPath)
        if ($null -eq $icon) {
            throw "Unable to extract icon from install media"
        }

        $bitmap = $icon.ToBitmap()
        $bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Jpeg)

        Write-Verbose "FolderEngine: Install media icon exported to $outputPath"
        return @{
            Success = $true
            OutputPath = $outputPath
            Message = "Install media icon exported successfully"
        }
    }
    catch {
        Write-Error "FolderEngine: Error exporting install media icon - $($_.Exception.Message)"
        return @{
            Success = $false
            OutputPath = ""
            Message = $_.Exception.Message
        }
    }
    finally {
        if ($bitmap) {
            $bitmap.Dispose()
        }
        if ($icon) {
            $icon.Dispose()
        }
    }
}

function New-PackageMetadataFile {
    <#
    .SYNOPSIS
        Generates a per-package metadata.json from the Master Template's
        metadata_template.json, populated with values already known to the
        GUI (Vendor/Name/Version/RITM/switches/InstallContext).
    .DESCRIPTION
        Reads the template with ConvertFrom-Json (matching the structured
        JSON convention used everywhere else in this codebase, e.g.
        app.config.json), sets properties on the resulting object, and
        writes <PackagePath>\Docs\metadata.json with ConvertTo-Json. Fields
        with no GUI equivalent (deployment target groups, dependencies,
        testing tracking, etc.) are left at template defaults for manual
        fill-in later.
    .PARAMETER TemplatePath
        Path to Master Template\Docs\metadata_template.json
    .PARAMETER PackagePath
        Path to the per-package folder (metadata.json is written under its
        Docs subfolder)
    .OUTPUTS
        Hashtable with keys: Success (bool), OutputPath (string), Message (string)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TemplatePath,

        [Parameter(Mandatory = $true)]
        [string]$PackagePath,

        [Parameter(Mandatory = $true)]
        [string]$Vendor,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $false)]
        [string]$Ritm = "",

        [Parameter(Mandatory = $false)]
        [string]$InstallCommandLine = "",

        [Parameter(Mandatory = $false)]
        [string]$UninstallCommandLine = "",

        [Parameter(Mandatory = $false)]
        [string]$InstallContext = "System",

        [Parameter(Mandatory = $false)]
        [string]$PackagedBy = ""
    )

    Write-Verbose "FolderEngine: Generating package metadata.json"

    try {
        if (-not (Test-Path $TemplatePath)) {
            throw "Metadata template not found: $TemplatePath"
        }

        $docsFolder = Join-Path $PackagePath "Docs"
        if (-not (Test-Path $docsFolder)) {
            New-Item -Path $docsFolder -ItemType Directory -Force | Out-Null
        }

        $metadata = Get-Content -Path $TemplatePath -Raw -Encoding UTF8 | ConvertFrom-Json

        $displayName = "{0} {1}" -f $Name, $Version
        $metadata.package.ritm_number = $Ritm
        $metadata.package.display_name = $displayName
        $metadata.package.publisher = $Vendor
        $metadata.package.developer = $Vendor
        $metadata.package.version = $Version

        if (-not [string]::IsNullOrWhiteSpace($InstallCommandLine)) {
            $metadata.installation.install_command_line = $InstallCommandLine
        }
        if (-not [string]::IsNullOrWhiteSpace($UninstallCommandLine)) {
            $metadata.installation.uninstall_command_line = $UninstallCommandLine
        }
        $runAsAccount = if ($InstallContext -eq "User") { "user" } else { "system" }
        $metadata.installation.install_experience.run_as_account = $runAsAccount
        $metadata.deployment.deployment_type = $InstallContext

        $metadata.audit.servicenow_ritm = $Ritm

        if (-not [string]::IsNullOrWhiteSpace($PackagedBy)) {
            $metadata.metadata.packaged_by = $PackagedBy
            $metadata.metadata.last_modified_by = $PackagedBy
        }
        $nowIso = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $metadata.metadata.packaged_date = $nowIso
        $metadata.metadata.last_modified_date = $nowIso

        $outputPath = Join-Path $docsFolder "metadata.json"
        $metadata | ConvertTo-Json -Depth 12 | Set-Content -Path $outputPath -Encoding UTF8 -Force

        Write-Verbose "FolderEngine: metadata.json written to $outputPath"
        return @{
            Success = $true
            OutputPath = $outputPath
            Message = "metadata.json generated successfully"
        }
    }
    catch {
        Write-Error "FolderEngine: Error generating metadata.json - $($_.Exception.Message)"
        return @{
            Success = $false
            OutputPath = ""
            Message = $_.Exception.Message
        }
    }
}

function New-PackageDocFiles {
    <#
    .SYNOPSIS
        Generates per-package README.md and CHANGELOG.md from the Master
        Template's README_Template.md/CHANGELOG_Template.md.
    .DESCRIPTION
        Fills each template's placeholders with chained literal .Replace()
        calls, matching the substitution technique already established in
        ValidationReportEngine's DocumentGeneratorEngine.psm1 (New-ValidationDocument),
        rather than introducing a new templating convention. The two
        templates use different placeholder styles as shipped
        (README_Template.md's "# Package Name" heading is literal text, not
        a {token}; CHANGELOG_Template.md uses {Application Name}/{version}/
        {revision}/{Author Name}) - both are handled here.
    .PARAMETER TemplateFolderPath
        Path to the Master Template root (contains README_Template.md and
        CHANGELOG_Template.md)
    .PARAMETER PackagePath
        Path to the per-package folder (README.md/CHANGELOG.md are written
        at the package root, matching where the *_Template.md files
        themselves live)
    .OUTPUTS
        Hashtable with keys: Success (bool), GeneratedFiles (string[]), Message (string)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TemplateFolderPath,

        [Parameter(Mandatory = $true)]
        [string]$PackagePath,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $false)]
        [string]$PackagedBy = ""
    )

    Write-Verbose "FolderEngine: Generating README.md/CHANGELOG.md"

    $generatedFiles = @()

    try {
        $readmeTemplatePath = Join-Path $TemplateFolderPath "README_Template.md"
        if (Test-Path $readmeTemplatePath) {
            $readmeContent = Get-Content -Path $readmeTemplatePath -Raw -Encoding UTF8
            $readmeContent = $readmeContent.Replace("# Package Name", ("# {0} {1}" -f $Name, $Version))

            $readmeOutputPath = Join-Path $PackagePath "README.md"
            $readmeContent | Set-Content -Path $readmeOutputPath -Encoding UTF8 -Force
            $generatedFiles += $readmeOutputPath
        }

        $changelogTemplatePath = Join-Path $TemplateFolderPath "CHANGELOG_Template.md"
        if (Test-Path $changelogTemplatePath) {
            $changelogContent = Get-Content -Path $changelogTemplatePath -Raw -Encoding UTF8
            $changelogContent = $changelogContent.Replace("{Application Name}", $Name)
            $changelogContent = $changelogContent.Replace("{version}", $Version)
            $changelogContent = $changelogContent.Replace("{revision}", "1")
            $changelogContent = $changelogContent.Replace("{Author Name}", $PackagedBy)

            $changelogOutputPath = Join-Path $PackagePath "CHANGELOG.md"
            $changelogContent | Set-Content -Path $changelogOutputPath -Encoding UTF8 -Force
            $generatedFiles += $changelogOutputPath
        }

        Write-Verbose "FolderEngine: Generated $($generatedFiles.Count) doc file(s)"
        return @{
            Success = $true
            GeneratedFiles = $generatedFiles
            Message = "README.md/CHANGELOG.md generated successfully"
        }
    }
    catch {
        Write-Error "FolderEngine: Error generating README/CHANGELOG - $($_.Exception.Message)"
        return @{
            Success = $false
            GeneratedFiles = $generatedFiles
            Message = $_.Exception.Message
        }
    }
}

# Export public functions
Export-ModuleMember -Function New-PackagingFolderStructure, Copy-TemplateFiles, Copy-InstallerToPackage, Export-InstallMediaIconToDocs, New-PackageMetadataFile, New-PackageDocFiles
