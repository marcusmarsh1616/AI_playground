#Requires -Version 5.1

<#
.SYNOPSIS
    DeploymentEngine - Manage package deployment to network share
.DESCRIPTION
    This engine handles copying completed packages to the network share for Intune deployment.
    Includes progress tracking, integrity verification, and error handling.
.NOTES
    Author: FRB Automation Team
    Created: 2025-01-23
    Version: 1.0.0
    Part of: FRB Packaging Tool v3.1 - Enhancement 3
#>

function Test-NetworkShareAccess {
    <#
    .SYNOPSIS
        Tests access to the network share
    .DESCRIPTION
        Verifies that the network share path is accessible and writable
    .PARAMETER NetworkSharePath
        Path to network share (e.g., \\server\share\packages)
    .EXAMPLE
        $result = Test-NetworkShareAccess -NetworkSharePath "\\rb\k1\shared\DSC_Pkgs\PkgMedia\LSS Packages"
    .OUTPUTS
        Hashtable with keys: Accessible (bool), CanWrite (bool), Message (string)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$NetworkSharePath
    )
    
    Write-Verbose "DeploymentEngine: Testing network share access: $NetworkSharePath"
    
    try {
        # Check if path exists
        if (-not (Test-Path $NetworkSharePath)) {
            return @{
                Accessible = $false
                CanWrite = $false
                Message = "Network share path does not exist or is not accessible"
            }
        }
        
        # Test write access by creating a temporary file
        $testFileName = ".frb_deploy_test_$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
        $testFilePath = Join-Path $NetworkSharePath $testFileName
        
        try {
            Set-Content -Path $testFilePath -Value "FRB Deployment Test" -ErrorAction Stop
            Remove-Item -Path $testFilePath -Force -ErrorAction SilentlyContinue
            
            Write-Verbose "DeploymentEngine: Network share is accessible and writable"
            
            return @{
                Accessible = $true
                CanWrite = $true
                Message = "Network share is accessible with write permissions"
            }
        }
        catch {
            Write-Verbose "DeploymentEngine: Network share is read-only or permission denied"
            
            return @{
                Accessible = $true
                CanWrite = $false
                Message = "Network share is accessible but write permission denied: $($_.Exception.Message)"
            }
        }
    }
    catch {
        Write-Error "DeploymentEngine: Error testing network share - $($_.Exception.Message)"
        return @{
            Accessible = $false
            CanWrite = $false
            Message = $_.Exception.Message
        }
    }
}

function Copy-PackageToNetworkShare {
    <#
    .SYNOPSIS
        Copies a package to the network share
    .DESCRIPTION
        Copies the entire package folder to the network share with progress tracking.
        Mirrors the local folder structure (Vendor\ProductName\Version) and intelligently
        reuses existing Vendor folders, only adding new version folders.
    .PARAMETER PackagePath
        Path to the local package folder
    .PARAMETER NetworkSharePath
        Path to network share destination
    .PARAMETER Vendor
        Vendor/company name (for folder structure)
    .PARAMETER ProductName
        Product name (for folder structure)
    .PARAMETER Version
        Product version (for folder structure)
    .PARAMETER OverwriteExisting
        If true, overwrites existing package. If false, creates backup.
    .PARAMETER VerifyAfterCopy
        If true, verifies file integrity after copy
    .PARAMETER ProgressCallback
        Optional scriptblock to call for progress updates
    .EXAMPLE
        $result = Copy-PackageToNetworkShare -PackagePath "C:\Packages\Adobe\Reader\23.1.0" -NetworkSharePath "\\server\packages" -Vendor "Adobe" -ProductName "Reader" -Version "23.1.0"
    .OUTPUTS
        Hashtable with keys: Success (bool), TargetPath (string), FilesCopied (int), SizeMB (decimal), Message (string)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackagePath,
        
        [Parameter(Mandatory = $true)]
        [string]$NetworkSharePath,
        
        [Parameter(Mandatory = $true)]
        [string]$Vendor,
        
        [Parameter(Mandatory = $true)]
        [string]$ProductName,
        
        [Parameter(Mandatory = $true)]
        [string]$Version,
        
        [Parameter(Mandatory = $false)]
        [bool]$OverwriteExisting = $false,
        
        [Parameter(Mandatory = $false)]
        [bool]$VerifyAfterCopy = $true,
        
        [Parameter(Mandatory = $false)]
        [scriptblock]$ProgressCallback = $null
    )
    
    Write-Verbose "DeploymentEngine: Copying package to network share"
    Write-Verbose "  Source: $PackagePath"
    Write-Verbose "  Destination: $NetworkSharePath"
    Write-Verbose "  Vendor: $Vendor"
    Write-Verbose "  Product: $ProductName"
    Write-Verbose "  Version: $Version"
    
    try {
        # Verify source exists
        if (-not (Test-Path $PackagePath)) {
            throw "Source package path not found: $PackagePath"
        }
        
        # Verify network share is accessible
        $shareTest = Test-NetworkShareAccess -NetworkSharePath $NetworkSharePath
        if (-not $shareTest.Accessible -or -not $shareTest.CanWrite) {
            throw "Network share not accessible or writable: $($shareTest.Message)"
        }
        
        # Build target path mirroring local folder structure: Vendor\ProductName\Version
        # This ensures organized deployment and reuses existing Vendor folders
        $targetPath = Join-Path $NetworkSharePath $Vendor
        $targetPath = Join-Path $targetPath $ProductName
        $targetPath = Join-Path $targetPath $Version
        
        Write-Verbose "DeploymentEngine: Target structure - Vendor\ProductName\Version"
        Write-Verbose "DeploymentEngine: Full target path: $targetPath"
        
        # Check if Vendor folder exists - if so, reuse it
        $vendorPath = Join-Path $NetworkSharePath $Vendor
        if (Test-Path $vendorPath) {
            Write-Verbose "DeploymentEngine: Reusing existing Vendor folder: $Vendor"
            if ($ProgressCallback) {
                & $ProgressCallback "Reusing existing vendor folder: $Vendor"
            }
        }
        
        # Check if Product folder exists under Vendor - if so, reuse it
        $productPath = Join-Path $vendorPath $ProductName
        if (Test-Path $productPath) {
            Write-Verbose "DeploymentEngine: Reusing existing Product folder: $ProductName"
            if ($ProgressCallback) {
                & $ProgressCallback "Reusing existing product folder: $ProductName"
            }
        }
        
        # Check if version folder already exists
        if (Test-Path $targetPath) {
            if ($OverwriteExisting) {
                Write-Verbose "DeploymentEngine: Removing existing version: $Version"
                if ($ProgressCallback) {
                    & $ProgressCallback "Removing existing version folder: $Version"
                }
                Remove-Item -Path $targetPath -Recurse -Force -ErrorAction Stop
            } else {
                # Create backup of version folder only (not entire product)
                $backupName = "$Version`_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                $backupPath = Join-Path $productPath $backupName
                Write-Verbose "DeploymentEngine: Creating backup at: $backupPath"
                if ($ProgressCallback) {
                    & $ProgressCallback "Creating backup of existing version..."
                }
                Move-Item -Path $targetPath -Destination $backupPath -Force -ErrorAction Stop
            }
        } else {
            # New version being added to existing product structure
            Write-Verbose "DeploymentEngine: Adding new version $Version to existing product structure"
            if ($ProgressCallback) {
                & $ProgressCallback "Adding new version: $Version"
            }
        }
        
        # Get list of all files to copy
        if ($ProgressCallback) {
            & $ProgressCallback "Calculating package size..."
        }
        
        $allFiles = Get-ChildItem -Path $PackagePath -Recurse -File
        $totalFiles = $allFiles.Count
        $totalSize = ($allFiles | Measure-Object -Property Length -Sum).Sum
        $totalSizeMB = [math]::Round($totalSize / 1MB, 2)
        
        Write-Verbose "DeploymentEngine: Copying $totalFiles files ($totalSizeMB MB)"
        
        # Copy files with progress
        $filesCopied = 0
        $bytesCopied = 0
        
        # Create target directory
        New-Item -Path $targetPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
        
        foreach ($file in $allFiles) {
            $relativePath = $file.FullName.Substring($PackagePath.Length)
            $targetFile = Join-Path $targetPath $relativePath
            
            # Ensure target directory exists
            $targetDir = Split-Path $targetFile -Parent
            if (-not (Test-Path $targetDir)) {
                New-Item -Path $targetDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
            }
            
            # Copy file
            Copy-Item -Path $file.FullName -Destination $targetFile -Force -ErrorAction Stop
            
            $filesCopied++
            $bytesCopied += $file.Length
            
            # Update progress every 5 files or for large files
            if (($filesCopied % 5 -eq 0) -or ($file.Length -gt 10MB)) {
                $percentComplete = [math]::Round(($bytesCopied / $totalSize) * 100, 1)
                $copiedMB = [math]::Round($bytesCopied / 1MB, 2)
                
                if ($ProgressCallback) {
                    & $ProgressCallback "Copying files: $filesCopied/$totalFiles ($percentComplete%) - $copiedMB MB / $totalSizeMB MB"
                }
            }
        }
        
        Write-Verbose "DeploymentEngine: Copied $filesCopied files successfully"
        
        # Verify copy integrity if requested
        if ($VerifyAfterCopy) {
            if ($ProgressCallback) {
                & $ProgressCallback "Verifying copy integrity..."
            }
            
            $verifyResult = Test-PackageCopyIntegrity -SourcePath $PackagePath -TargetPath $targetPath
            
            if (-not $verifyResult.IntegrityValid) {
                throw "Copy integrity verification failed: $($verifyResult.Message)"
            }
            
            Write-Verbose "DeploymentEngine: Copy integrity verified"
        }
        
        if ($ProgressCallback) {
            & $ProgressCallback "Copy complete!"
        }
        
        return @{
            Success = $true
            TargetPath = $targetPath
            FilesCopied = $filesCopied
            SizeMB = $totalSizeMB
            Message = "Package copied successfully to network share"
        }
    }
    catch {
        Write-Error "DeploymentEngine: Error copying package - $($_.Exception.Message)"
        
        # Attempt cleanup of partial copy
        if (Test-Path $targetPath) {
            try {
                Write-Verbose "DeploymentEngine: Cleaning up partial copy"
                Remove-Item -Path $targetPath -Recurse -Force -ErrorAction SilentlyContinue
            }
            catch {
                Write-Verbose "DeploymentEngine: Could not clean up partial copy: $($_.Exception.Message)"
            }
        }
        
        return @{
            Success = $false
            TargetPath = ""
            FilesCopied = 0
            SizeMB = 0
            Message = $_.Exception.Message
        }
    }
}

function Test-PackageCopyIntegrity {
    <#
    .SYNOPSIS
        Verifies integrity of copied package
    .DESCRIPTION
        Compares file count and sizes between source and target to verify copy integrity
    .PARAMETER SourcePath
        Source package path
    .PARAMETER TargetPath
        Target package path on network share
    .EXAMPLE
        $result = Test-PackageCopyIntegrity -SourcePath "C:\Packages\Adobe\Reader\23.1.0" -TargetPath "\\server\packages\Adobe_Reader_23.1.0"
    .OUTPUTS
        Hashtable with keys: IntegrityValid (bool), SourceFiles (int), TargetFiles (int), Message (string)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        
        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )
    
    Write-Verbose "DeploymentEngine: Verifying copy integrity"
    
    try {
        # Get file counts
        $sourceFiles = Get-ChildItem -Path $SourcePath -Recurse -File
        $targetFiles = Get-ChildItem -Path $TargetPath -Recurse -File
        
        $sourceCount = $sourceFiles.Count
        $targetCount = $targetFiles.Count
        
        Write-Verbose "DeploymentEngine: Source files: $sourceCount, Target files: $targetCount"
        
        if ($sourceCount -ne $targetCount) {
            return @{
                IntegrityValid = $false
                SourceFiles = $sourceCount
                TargetFiles = $targetCount
                Message = "File count mismatch: Source=$sourceCount, Target=$targetCount"
            }
        }
        
        # Get total sizes
        $sourceSize = ($sourceFiles | Measure-Object -Property Length -Sum).Sum
        $targetSize = ($targetFiles | Measure-Object -Property Length -Sum).Sum
        
        Write-Verbose "DeploymentEngine: Source size: $sourceSize bytes, Target size: $targetSize bytes"
        
        if ($sourceSize -ne $targetSize) {
            return @{
                IntegrityValid = $false
                SourceFiles = $sourceCount
                TargetFiles = $targetCount
                Message = "Total size mismatch: Source=$sourceSize bytes, Target=$targetSize bytes"
            }
        }
        
        # Verify critical files exist (Install.exe)
        $installExeSource = Join-Path $SourcePath "Install.exe"
        $installExeTarget = Join-Path $TargetPath "Install.exe"
        
        if ((Test-Path $installExeSource) -and -not (Test-Path $installExeTarget)) {
            return @{
                IntegrityValid = $false
                SourceFiles = $sourceCount
                TargetFiles = $targetCount
                Message = "Critical file Install.exe missing in target"
            }
        }
        
        Write-Verbose "DeploymentEngine: Copy integrity verification passed"
        
        return @{
            IntegrityValid = $true
            SourceFiles = $sourceCount
            TargetFiles = $targetCount
            Message = "Copy integrity verified successfully"
        }
    }
    catch {
        Write-Error "DeploymentEngine: Error verifying copy integrity - $($_.Exception.Message)"
        return @{
            IntegrityValid = $false
            SourceFiles = 0
            TargetFiles = 0
            Message = $_.Exception.Message
        }
    }
}

function Get-PackageFolderSize {
    <#
    .SYNOPSIS
        Calculates total size of a package folder
    .DESCRIPTION
        Returns the total size in bytes and MB of all files in a package folder
    .PARAMETER PackagePath
        Path to package folder
    .EXAMPLE
        $result = Get-PackageFolderSize -PackagePath "C:\Packages\Adobe\Reader\23.1.0"
    .OUTPUTS
        Hashtable with keys: Success (bool), SizeBytes (long), SizeMB (decimal), FileCount (int), Message (string)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackagePath
    )
    
    Write-Verbose "DeploymentEngine: Calculating package folder size"
    
    try {
        if (-not (Test-Path $PackagePath)) {
            throw "Package path not found: $PackagePath"
        }
        
        $files = Get-ChildItem -Path $PackagePath -Recurse -File
        $fileCount = $files.Count
        $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
        $totalSizeMB = [math]::Round($totalSize / 1MB, 2)
        
        Write-Verbose "DeploymentEngine: Package size: $totalSizeMB MB ($fileCount files)"
        
        return @{
            Success = $true
            SizeBytes = $totalSize
            SizeMB = $totalSizeMB
            FileCount = $fileCount
            Message = "Package size calculated successfully"
        }
    }
    catch {
        Write-Error "DeploymentEngine: Error calculating package size - $($_.Exception.Message)"
        return @{
            Success = $false
            SizeBytes = 0
            SizeMB = 0
            FileCount = 0
            Message = $_.Exception.Message
        }
    }
}

function New-PackageBackup {
    <#
    .SYNOPSIS
        Creates a backup of an existing package
    .DESCRIPTION
        Creates a timestamped backup copy of a package before overwriting
    .PARAMETER PackagePath
        Path to package to backup
    .PARAMETER BackupLocation
        Location where backup should be created
    .EXAMPLE
        $result = New-PackageBackup -PackagePath "\\server\packages\Adobe_Reader_23.1.0" -BackupLocation "\\server\packages"
    .OUTPUTS
        Hashtable with keys: Success (bool), BackupPath (string), Message (string)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackagePath,
        
        [Parameter(Mandatory = $true)]
        [string]$BackupLocation
    )
    
    Write-Verbose "DeploymentEngine: Creating package backup"
    
    try {
        if (-not (Test-Path $PackagePath)) {
            throw "Package path not found: $PackagePath"
        }
        
        $packageName = Split-Path $PackagePath -Leaf
        $backupName = "$packageName`_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        $backupPath = Join-Path $BackupLocation $backupName
        
        Write-Verbose "DeploymentEngine: Backup path: $backupPath"
        
        Copy-Item -Path $PackagePath -Destination $backupPath -Recurse -Force -ErrorAction Stop
        
        Write-Verbose "DeploymentEngine: Backup created successfully"
        
        return @{
            Success = $true
            BackupPath = $backupPath
            Message = "Backup created successfully"
        }
    }
    catch {
        Write-Error "DeploymentEngine: Error creating backup - $($_.Exception.Message)"
        return @{
            Success = $false
            BackupPath = ""
            Message = $_.Exception.Message
        }
    }
}

# Export public functions
Export-ModuleMember -Function Test-NetworkShareAccess, Copy-PackageToNetworkShare, Test-PackageCopyIntegrity, Get-PackageFolderSize, New-PackageBackup