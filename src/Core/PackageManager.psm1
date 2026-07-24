#Requires -Version 5.1

<#
.SYNOPSIS
    PackageManager Module - High-level package orchestration
.DESCRIPTION
    Manages the complete package creation, update, and build lifecycle.
    Orchestrates calls to various engines and manages package state.
.NOTES
    Author: FRB Automation Team
    Created: June 5, 2026
    Version: 1.0.0
#>

function New-FRBPackage {
    <#
    .SYNOPSIS
        Create a new FRB package
    .PARAMETER Vendor
        Vendor/company name
    .PARAMETER ProductName
        Product name
    .PARAMETER Version
        Product version
    .PARAMETER InstallerPath
        Path to installer file
    .PARAMETER InstallSwitch
        Install command line switch
    .PARAMETER UninstallSwitch
        Uninstall command line switch
    .PARAMETER UninstallExecutable
        Uninstall executable name
    .PARAMETER Config
        Configuration object
    .PARAMETER ProgressCallback
        Callback for progress updates
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Vendor,
        
        [Parameter(Mandatory = $true)]
        [string]$ProductName,
        
        [Parameter(Mandatory = $true)]
        [string]$Version,
        
        [Parameter(Mandatory = $false)]
        [string]$InstallerPath,
        
        [Parameter(Mandatory = $false)]
        [string]$InstallSwitch,
        
        [Parameter(Mandatory = $false)]
        [string]$UninstallSwitch,
        
        [Parameter(Mandatory = $false)]
        [string]$UninstallExecutable,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $false)]
        [ScriptBlock]$ProgressCallback
    )
    
    if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
        Write-AppLog "Creating package: $Vendor $ProductName $Version" -Level Info -Component "PackageManager"
    }
    
    try {
        # Step 1: Validate inputs (10%)
        if ($ProgressCallback) { & $ProgressCallback @{ Percent = 10; Message = "Validating inputs..." } }
        
        $validation = Test-SoftwareInputs -SoftwareName $ProductName -Vendor $Vendor -Version $Version
        if (-not $validation.IsValid) {
            throw "Validation failed: $($validation.ErrorMessages -join ', ')"
        }
        
        # Step 2: Determine paths (20%)
        if ($ProgressCallback) { & $ProgressCallback @{ Percent = 20; Message = "Determining paths..." } }
        
        $basePackagingPath = if ($Config) {
            Get-ConfigValue -Config $Config -Path "Paths.packaging.basePackagingPath"
        } else {
            "C:\temp\packaging folder"
        }
        
        $masterTemplatePath = if ($Config) {
            Get-ConfigValue -Config $Config -Path "Paths.templates.masterTemplatePath"
        } else {
            "C:\Temp\Packaging folders\Master Template"
        }
        
        $projectFileName = if ($Config) {
            Get-ConfigValue -Config $Config -Path "Paths.packaging.projectFileName"
        } else {
            "Startup.pss"
        }
        
        $packagePath = Join-Path $basePackagingPath (Join-Path $Vendor (Join-Path $ProductName $Version))
        
        # Step 3: Check if package exists (30%)
        if ($ProgressCallback) { & $ProgressCallback @{ Percent = 30; Message = "Checking if package exists..." } }
        
        $folderExists = Test-Path $packagePath
        
        if (-not $folderExists) {
            # CREATE MODE: New package
            if ($ProgressCallback) { & $ProgressCallback @{ Percent = 40; Message = "Creating folder structure..." } }
            
            $folderResult = New-PackagingFolderStructure -BasePath $basePackagingPath `
                                                          -Vendor $Vendor `
                                                          -ProductName $ProductName `
                                                          -Version $Version `
                                                          -OverwriteIfExists $true
            
            if (-not $folderResult.Success) {
                throw $folderResult.Message
            }
            
            $packagePath = $folderResult.FolderPath
            
            # Step 4: Copy template files (50%)
            if ($ProgressCallback) { & $ProgressCallback @{ Percent = 50; Message = "Copying template files..." } }
            
            $copyResult = Copy-TemplateFiles -TemplatePath $masterTemplatePath `
                                             -DestinationPath $packagePath
            
            if (-not $copyResult.Success) {
                throw $copyResult.Message
            }
            
            if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
                Write-AppLog "Template files copied: $($copyResult.FilesCopied) files" -Level Info -Component "PackageManager"
            }
        } else {
            # UPDATE MODE: Package exists
            if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
                Write-AppLog "Package exists, updating: $packagePath" -Level Info -Component "PackageManager"
            }
        }
        
        # Step 5: Copy installer if provided (60%)
        if ($InstallerPath -and (Test-Path $InstallerPath)) {
            if ($ProgressCallback) { & $ProgressCallback @{ Percent = 60; Message = "Copying installer..." } }
            
            $mediaResult = Copy-InstallerToPackage -InstallerPath $InstallerPath `
                                                    -PackagePath $packagePath
            
            if (-not $mediaResult.Success) {
                throw $mediaResult.Message
            }
        }
        
        # Step 6: Update Startup.pss (70%)
        if ($ProgressCallback) { & $ProgressCallback @{ Percent = 70; Message = "Updating Startup.pss..." } }
        
        $startupPath = Join-Path $packagePath $projectFileName
        
        if (Test-Path $startupPath) {
            $mediaFileName = if ($InstallerPath) {
                [System.IO.Path]::GetFileName($InstallerPath)
            } else { "" }
            
            $mediaExtension = if ($mediaFileName) {
                [System.IO.Path]::GetExtension($InstallerPath).ToLower()
            } else { "" }
            
            # Detect installer type if we have installer path
            $installerType = if ($InstallerPath) {
                Get-InstallerType -FilePath $InstallerPath
            } else { "Unknown" }
            
            # Detect required processes
            $requiredProcesses = ""
            try {
                $processResult = Get-RequiredProcessesToClose -Vendor $Vendor -ProductName $ProductName -InstallerType $installerType
                if ($processResult.Success) { $requiredProcesses = $processResult.FormattedString }
            } catch { }
            
            $updateResult = Update-FRBStartupFile -StartupPath $startupPath `
                                                  -Vendor $Vendor `
                                                  -ProductName $ProductName `
                                                  -Version $Version `
                                                  -MediaFileName $mediaFileName `
                                                  -MediaExtension $mediaExtension `
                                                  -UninstallExeName $UninstallExecutable `
                                                  -InstallSwitch $InstallSwitch `
                                                  -UninstallSwitch $UninstallSwitch `
                                                  -RequiredProcesses $requiredProcesses
            
            if (-not $updateResult.Success) {
                throw $updateResult.Message
            }
        }
        
        # Step 7: Verify project file (90%)
        if ($ProgressCallback) { & $ProgressCallback @{ Percent = 90; Message = "Verifying project file..." } }
        
        $projectPath = Find-ProjectFile -PackagePath $packagePath
        
        # Wait up to 5 seconds for project file to appear
        $maxWaitTime = 5
        $waitInterval = 0.2
        $elapsed = 0
        
        while ([string]::IsNullOrWhiteSpace($projectPath) -and $elapsed -lt $maxWaitTime) {
            Start-Sleep -Milliseconds ($waitInterval * 1000)
            $elapsed += $waitInterval
            $projectPath = Find-ProjectFile -PackagePath $packagePath
        }
        
        # Step 8: Complete (100%)
        if ($ProgressCallback) { & $ProgressCallback @{ Percent = 100; Message = "Package created successfully!" } }
        
        if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
            Write-AppLog "Package created successfully: $packagePath" -Level Info -Component "PackageManager"
        }
        
        # Update state if StateManager is available
        if (Get-Command Set-PackageState -ErrorAction SilentlyContinue) {
            Set-PackageState -Property "PackagePath" -Value $packagePath
            Set-PackageState -Property "ProjectPath" -Value $projectPath
            Set-PackageState -Property "PackageCreated" -Value $true
        }
        
        return @{
            Success = $true
            Message = "Package created successfully"
            PackagePath = $packagePath
            ProjectPath = $projectPath
            ExistedBefore = $folderExists
        }
    }
    catch {
        if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
            Write-AppLog "Failed to create package: $($_.Exception.Message)" -Level Error -Component "PackageManager" -Exception $_.Exception
        }
        
        return @{
            Success = $false
            Message = $_.Exception.Message
            PackagePath = $null
            ProjectPath = $null
        }
    }
}

function Update-FRBStartupFile {
    <#
    .SYNOPSIS
        Update the Startup.pss file with package details
    .PARAMETER StartupPath
        Path to Startup.pss file
    .PARAMETER Vendor
        Vendor name
    .PARAMETER ProductName
        Product name
    .PARAMETER Version
        Product version
    .PARAMETER MediaFileName
        Installation media filename
    .PARAMETER MediaExtension
        Installation media extension (.exe or .msi)
    .PARAMETER UninstallExeName
        Uninstall executable name
    .PARAMETER InstallSwitch
        Install command line switch
    .PARAMETER UninstallSwitch
        Uninstall command line switch
    .PARAMETER RequiredProcesses
        Comma-separated list of processes to close
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StartupPath,
        
        [Parameter(Mandatory = $true)]
        [string]$Vendor,
        
        [Parameter(Mandatory = $true)]
        [string]$ProductName,
        
        [Parameter(Mandatory = $true)]
        [string]$Version,
        
        [Parameter(Mandatory = $false)]
        [string]$MediaFileName = "",
        
        [Parameter(Mandatory = $false)]
        [string]$MediaExtension = "",
        
        [Parameter(Mandatory = $false)]
        [string]$UninstallExeName = "",
        
        [Parameter(Mandatory = $false)]
        [string]$InstallSwitch = "",
        
        [Parameter(Mandatory = $false)]
        [string]$UninstallSwitch = "",
        
        [Parameter(Mandatory = $false)]
        [string]$RequiredProcesses = ""
    )
    
    try {
        if (-not (Test-Path $StartupPath)) {
            throw "Startup.pss file not found: $StartupPath"
        }
        
        if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
            Write-AppLog "Updating Startup.pss: $StartupPath" -Level Info -Component "PackageManager"
        }
        
        # Read file content
        $content = Get-Content -Path $StartupPath -Raw -Encoding UTF8
        
        # Get current user and date
        $currentUser = $env:USERNAME
        $currentDate = Get-Date -Format "yyyy-MM-dd"
        
        # Parse and update variables
        $lines = $content -split "`r?`n"
        $inVarDeclaration = $false
        
        $updates = @{
            appVendor = $Vendor
            appName = $ProductName
            appVersion = $Version
            appInstallerExeName = if ($MediaExtension -eq ".exe") { $MediaFileName } else { $null }
            appMsiName = if ($MediaExtension -eq ".msi") { $MediaFileName } else { $null }
            appInstallCommandLine = $InstallSwitch
            appUninstallCommandLine = $UninstallSwitch
            appUninstallExeName = if ($MediaExtension -eq ".exe") {
                if ($UninstallExeName) { $UninstallExeName } else { $MediaFileName }
            } else { $null }
            appScriptAuthor = $currentUser
            appStopRequiredProcesses = $RequiredProcesses
        }
        
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '##\*\s*VARIABLE DECLARATION') {
                $inVarDeclaration = $true
            }
            elseif ($lines[$i] -match '##\*\s*END VARIABLE DECLARATION') {
                $inVarDeclaration = $false
            }
            
            if ($inVarDeclaration) {
                foreach ($key in $updates.Keys) {
                    $value = $updates[$key]
                    if ($null -ne $value -and $value -ne "") {
                        if ($lines[$i] -match "^\s*\[.*?\]\`$$key\s*=\s*[\x27\x22].*?[\x27\x22]") {
                            $lines[$i] = "`t[string]`$$key = '$value'"
                        }
                    }
                }
                
                # Handle version increment for appScriptBuildVersion
                if ($lines[$i] -match '^\s*\[version\]\$appScriptBuildVersion\s*=\s*[\x27\x22](.*?)[\x27\x22]') {
                    $existingVersion = $matches[1]
                    if (-not [string]::IsNullOrWhiteSpace($existingVersion) -and $existingVersion -ne '0.0.0') {
                        try {
                            $versionObj = [version]$existingVersion
                            $newVersion = "{0}.{1}.{2}" -f $versionObj.Major, $versionObj.Minor, ($versionObj.Build + 1)
                        } catch { $newVersion = "1.0.1" }
                    } else { $newVersion = "1.0.0" }
                    $lines[$i] = "`t[version]`$appScriptBuildVersion = '$newVersion'"
                }
            }
        }
        
        $content = $lines -join "`r`n"
        
        # Write back to file
        Set-Content -Path $StartupPath -Value $content -Encoding UTF8 -Force
        
        if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
            Write-AppLog "Startup.pss updated successfully" -Level Info -Component "PackageManager"
        }
        
        return @{
            Success = $true
            Message = "Startup.pss updated successfully"
        }
    }
    catch {
        if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
            Write-AppLog "Failed to update Startup.pss: $($_.Exception.Message)" -Level Error -Component "PackageManager"
        }
        
        return @{
            Success = $false
            Message = $_.Exception.Message
        }
    }
}

function Build-FRBPackage {
    <#
    .SYNOPSIS
        Build the package EXE using PowerShell Studio
    .PARAMETER PackagePath
        Path to package folder
    .PARAMETER Config
        Configuration object
    .PARAMETER ProgressCallback
        Callback for progress updates
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackagePath,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $false)]
        [ScriptBlock]$ProgressCallback
    )
    
    if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
        Write-AppLog "Building package: $PackagePath" -Level Info -Component "PackageManager"
    }
    
    try {
        # Step 1: Find project file (20%)
        if ($ProgressCallback) { & $ProgressCallback @{ Percent = 20; Message = "Finding project file..." } }
        
        $projectPath = Find-ProjectFile -PackagePath $PackagePath
        
        if ([string]::IsNullOrWhiteSpace($projectPath)) {
            throw "Project file not found in: $PackagePath"
        }
        
        # Step 2: Verify PSBuild (40%)
        if ($ProgressCallback) { & $ProgressCallback @{ Percent = 40; Message = "Verifying PSBuild..." } }
        
        $psbuildCheck = Test-PSBuildAvailable
        if (-not $psbuildCheck.Available) {
            throw "PSBuild.exe not found at: $($psbuildCheck.Path)"
        }
        
        # Step 3: Build (60%)
        if ($ProgressCallback) { & $ProgressCallback @{ Percent = 60; Message = "Building EXE..." } }
        
        $buildResult = Invoke-ProjectBuild -ProjectPath $projectPath -BuildType "PACKAGE"
        
        # Step 4: Complete (100%)
        if ($ProgressCallback) { & $ProgressCallback @{ Percent = 100; Message = "Build complete!" } }
        
        if ($buildResult.Success) {
            if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
                Write-AppLog "Build successful: $($buildResult.OutputPath)" -Level Info -Component "PackageManager"
            }
            
            # Update state
            if (Get-Command Set-PackageState -ErrorAction SilentlyContinue) {
                Set-PackageState -Property "ProjectBuilt" -Value $true
                Set-PackageState -Property "BuildPath" -Value $buildResult.OutputPath
            }
        }
        
        return $buildResult
    }
    catch {
        if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
            Write-AppLog "Build failed: $($_.Exception.Message)" -Level Error -Component "PackageManager" -Exception $_.Exception
        }
        
        return @{
            Success = $false
            Message = $_.Exception.Message
            OutputPath = $null
        }
    }
}

# Export functions
Export-ModuleMember -Function New-FRBPackage, Update-FRBStartupFile, Build-FRBPackage
