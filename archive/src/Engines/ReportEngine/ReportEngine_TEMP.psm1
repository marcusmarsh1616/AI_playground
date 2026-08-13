#Requires -Version 5.1

<#
.SYNOPSIS
    ValidationEngine - Validates user inputs and system requirements
.DESCRIPTION
    This engine is responsible for validating all user inputs, checking system requirements,
    and ensuring data integrity before operations.
.NOTES
    Author: IT Automation Team
    Created: June 4, 2026
    Version: 1.0.0
    PowerShell Version: 5.1
    Part of: Install Validation Tool Modular Architecture
#>

function Test-SoftwareInputs {
    <#
    .SYNOPSIS
        Validates software name, vendor, and version inputs
    .DESCRIPTION
        Checks that required fields are not empty and contain valid characters.
    .PARAMETER SoftwareName
        The software/product name
    .PARAMETER Vendor
        The vendor/company name
    .PARAMETER Version
        The software version (optional)
    .EXAMPLE
        $validation = Test-SoftwareInputs -SoftwareName "XMLSpy" -Vendor "Altova" -Version "2026"
    .OUTPUTS
        Hashtable with keys: IsValid (bool), ErrorMessages (string array)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SoftwareName,
        
        [Parameter(Mandatory = $false)]
        [string]$Vendor,
        
        [Parameter(Mandatory = $false)]
        [string]$Version
    )
    
    Write-Verbose "ValidationEngine: Validating software inputs"
    
    $result = @{
        IsValid = $true
        ErrorMessages = @()
    }
    
    # Check required fields
    if ([string]::IsNullOrWhiteSpace($SoftwareName)) {
        $result.ErrorMessages += "Software Name is required"
        $result.IsValid = $false
    }
    
    if ([string]::IsNullOrWhiteSpace($Vendor)) {
        $result.ErrorMessages += "Vendor is required"
        $result.IsValid = $false
    }
    
    # Check for invalid characters (optional validation)
    $invalidChars = '[<>:"/\\|?*]'
    if ($SoftwareName -match $invalidChars) {
        $result.ErrorMessages += "Software Name contains invalid characters"
        $result.IsValid = $false
    }
    
    if ($Vendor -match $invalidChars) {
        $result.ErrorMessages += "Vendor contains invalid characters"
        $result.IsValid = $false
    }
    
    if ($result.IsValid) {
        Write-Verbose "ValidationEngine: All inputs are valid"
    } else {
        Write-Verbose "ValidationEngine: Validation failed with $($result.ErrorMessages.Count) error(s)"
    }
    
    return $result
}

function Test-InstallerFile {
    <#
    .SYNOPSIS
        Validates an installer file path
    .DESCRIPTION
        Checks that the installer file exists and has a valid extension.
    .PARAMETER InstallerPath
        Full path to the installer file
    .EXAMPLE
        $validation = Test-InstallerFile -InstallerPath "C:\Installers\setup.exe"
    .OUTPUTS
        Hashtable with keys: IsValid (bool), ErrorMessages (string array), FileType (string)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallerPath
    )
    
    Write-Verbose "ValidationEngine: Validating installer file - $InstallerPath"
    
    $result = @{
        IsValid = $true
        ErrorMessages = @()
        FileType = ""
    }
    
    # Check if file exists
    if (-not (Test-Path $InstallerPath)) {
        $result.ErrorMessages += "Installer file not found: $InstallerPath"
        $result.IsValid = $false
        return $result
    }
    
    # Check file extension
    $extension = [System.IO.Path]::GetExtension($InstallerPath).ToLower()
    $validExtensions = @(".exe", ".msi")
    
    if ($extension -notin $validExtensions) {
        $result.ErrorMessages += "Invalid installer file type. Expected .exe or .msi, got: $extension"
        $result.IsValid = $false
    } else {
        $result.FileType = $extension.TrimStart('.')
        Write-Verbose "ValidationEngine: Installer file type: $($result.FileType)"
    }
    
    if ($result.IsValid) {
        Write-Verbose "ValidationEngine: Installer file is valid"
    }
    
    return $result
}

function Test-OutputPath {
    <#
    .SYNOPSIS
        Validates an output path for report generation
    .DESCRIPTION
        Checks that the output directory exists or can be created.
    .PARAMETER OutputPath
        Full path where the report will be saved
    .EXAMPLE
        $validation = Test-OutputPath -OutputPath "C:\Reports\validation.html"
    .OUTPUTS
        Hashtable with keys: IsValid (bool), ErrorMessages (string array)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )
    
    Write-Verbose "ValidationEngine: Validating output path - $OutputPath"
    
    $result = @{
        IsValid = $true
        ErrorMessages = @()
    }
    
    try {
        $directory = [System.IO.Path]::GetDirectoryName($OutputPath)
        
        if (-not (Test-Path $directory)) {
            Write-Verbose "ValidationEngine: Output directory does not exist, attempting to create..."
            New-Item -Path $directory -ItemType Directory -Force | Out-Null
            Write-Verbose "ValidationEngine: Output directory created successfully"
        }
    }
    catch {
        $result.ErrorMessages += "Cannot access or create output directory: $($_.Exception.Message)"
        $result.IsValid = $false
    }
    
    if ($result.IsValid) {
        Write-Verbose "ValidationEngine: Output path is valid"
    }
    
    return $result
}

# Export public functions

function Test-FolderNameValid {
    <#
    .SYNOPSIS
        Validates a folder name for invalid characters
    .DESCRIPTION
        Checks if a folder name contains invalid characters that Windows doesn't allow
    .PARAMETER FolderName
        The folder name to validate
    .EXAMPLE
        Test-FolderNameValid -FolderName "My Folder"
    .OUTPUTS
        Boolean - True if valid, False if contains invalid characters
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FolderName
    )
    
    Write-Verbose "ValidationEngine: Validating folder name - $FolderName"
    
    # Windows invalid characters for folder names: < > : " / \ | ? *
    $invalidChars = '[<>:"/\\|?*]'
    
    if ($FolderName -match $invalidChars) {
        Write-Verbose "ValidationEngine: Folder name contains invalid characters"
        return $false
    }
    
    # Check for reserved names
    $reservedNames = @('CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9', 'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9')
    
    if ($FolderName.ToUpper() -in $reservedNames) {
        Write-Verbose "ValidationEngine: Folder name is a reserved Windows name"
        return $false
    }
    
    Write-Verbose "ValidationEngine: Folder name is valid"
    return $true
}

# Export public functions
Export-ModuleMember -Function Test-SoftwareInputs, Test-InstallerFile, Test-OutputPath, Test-FolderNameValid

