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

function Get-InstallContextRecommendation {
    <#
    .SYNOPSIS
        Detects likely install-context support and recommends User or System context.
    .DESCRIPTION
        Uses installer metadata, extension, installer type, and manifest text hints to produce
        a best-effort recommendation with confidence and rationale.
    .PARAMETER FilePath
        Full path to installer media
    .PARAMETER InstallerType
        Detected installer type (optional)
    .OUTPUTS
        Hashtable with recommendation details
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [string]$InstallerType = ""
    )

    $result = [ordered]@{
        Success = $false
        Recommendation = "System"
        SupportsUser = $true
        SupportsSystem = $true
        Confidence = "Low"
        Title = "Context Detection"
        Reasons = @()
        Details = @()
    }

    if (-not (Test-Path $FilePath)) {
        $result.Reasons += "Installer file was not found."
        return $result
    }

    try {
        $extension = [System.IO.Path]::GetExtension($FilePath).ToLowerInvariant()
        $fileName = [System.IO.Path]::GetFileName($FilePath).ToLowerInvariant()
        $detectedType = if ([string]::IsNullOrWhiteSpace($InstallerType)) { Get-InstallerType -FilePath $FilePath } else { $InstallerType }

        $result.Details += "Installer Type: $detectedType"
        $result.Details += "Media Extension: $extension"

        $recommended = "System"
        $supportsUser = $true
        $supportsSystem = $true
        $confidence = "Medium"
        $reasons = @()
        $explicitUserSignals = 0

        if ($extension -eq ".msi") {
            $recommended = "System"
            $supportsUser = $true
            $supportsSystem = $true
            $confidence = "Medium"
            $reasons += "MSI supports enterprise system deployment patterns and can often run per-user depending on package authoring."

            if ($fileName -match "peruser|per-user|user") {
                $explicitUserSignals++
                $confidence = "Medium"
                $reasons += "Filename suggests per-user install intent, but system remains the safer default for packaging."
            }
        }
        else {
            $fileInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($FilePath)
            $company = if ($fileInfo.CompanyName) { $fileInfo.CompanyName } else { "" }
            $product = if ($fileInfo.ProductName) { $fileInfo.ProductName } else { "" }
            $detailsBlob = ("{0} {1} {2}" -f $company, $product, $fileName).ToLowerInvariant()

            $manifestHint = ""
            try {
                $bytes = [System.IO.File]::ReadAllBytes($FilePath)
                $asciiText = [System.Text.Encoding]::ASCII.GetString($bytes)
                if ($asciiText -match "requestedExecutionLevel" -and $asciiText -match "requireAdministrator") {
                    $manifestHint = "requireAdministrator"
                }
                elseif ($asciiText -match "requestedExecutionLevel" -and $asciiText -match "asInvoker") {
                    $manifestHint = "asInvoker"
                }
            }
            catch {
                # Best-effort hint only.
            }

            if ($manifestHint -eq "requireAdministrator") {
                $recommended = "System"
                $supportsUser = $false
                $supportsSystem = $true
                $confidence = "High"
                $reasons += "Manifest indicates requireAdministrator, which requires elevated/system-style install context."
            }
            elseif ($manifestHint -eq "asInvoker") {
                $recommended = "System"
                $supportsUser = $true
                $supportsSystem = $true
                $confidence = "Medium"
                $reasons += "Manifest indicates asInvoker, so user context may be possible when explicitly required."
            }

            if ($detailsBlob -match "machine-wide|all users|allusers") {
                $recommended = "System"
                $confidence = "High"
                $reasons += "Installer metadata suggests machine-wide deployment."
            }
            elseif ($detailsBlob -match "per-user|current user|for me only") {
                $explicitUserSignals++
                $reasons += "Installer metadata suggests per-user deployment."
            }

            if ($fileName -match "peruser|per-user|currentuser|formeonly|user-only") {
                $explicitUserSignals++
                $reasons += "Filename contains per-user indicators."
            }

            if ($supportsUser -and $supportsSystem -and $explicitUserSignals -ge 2 -and $manifestHint -ne "requireAdministrator") {
                $recommended = "User"
                $confidence = "High"
                $reasons += "Multiple per-user indicators detected; recommending user context for this installer."
            }
            elseif ($supportsUser -and $supportsSystem -and $explicitUserSignals -eq 1 -and $manifestHint -ne "requireAdministrator") {
                $recommended = "System"
                if ($confidence -eq "Low") { $confidence = "Medium" }
                $reasons += "Some per-user indicators detected; keeping system as the default recommendation unless user context is specifically requested."
            }

            if ($reasons.Count -eq 0) {
                $recommended = "System"
                $confidence = "Low"
                $reasons += "No strong context signals were detected; defaulting to system context for enterprise packaging safety."
            }
        }

        $result.Success = $true
        $result.Recommendation = $recommended
        $result.SupportsUser = $supportsUser
        $result.SupportsSystem = $supportsSystem
        $result.Confidence = $confidence
        $result.Title = "Context Detection: Recommended $recommended ($confidence confidence)"
        $result.Reasons = $reasons
    }
    catch {
        $result.Success = $false
        $result.Reasons += "Context detection failed: $($_.Exception.Message)"
    }

    return $result
}

function New-PackageDetectionScript {
    <#
    .SYNOPSIS
        Generates a per-package Intune detection script from the Master
        Template's PhoenixFrame-DetectionScript-Template.ps1.
    .DESCRIPTION
        Substitutes the 6 placeholders documented in
        PhoenixFrame-DetectionScript-Guide.md ({CREATION_DATE}, {RITM},
        {APP_NAME}, {APPLICATION_DISPLAY_NAME}, {TARGET_VERSION},
        {VENDOR_NAME}) via literal string replace, matching the convention
        already used for README/CHANGELOG generation. The System/User
        registry context is driven by the GUI's own InstallContext value
        (the same one already written into Startup.pss) rather than a
        separate input, so there is one source of truth for context.
        Output is written at the package root as
        RITM{number}_{AppName}_Detect_R1.ps1, per the Guide's documented
        naming convention.
    .PARAMETER TemplatePath
        Path to Master Template\PhoenixFrame-DetectionScript-Template.ps1
    .PARAMETER PackagePath
        Path to the per-package folder (detection script is written at its root)
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
        [string]$AppName,

        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $false)]
        [string]$Ritm = "",

        [Parameter(Mandatory = $false)]
        [string]$InstallContext = "System"
    )

    Write-Verbose "DetectionEngine: Generating package detection script"

    try {
        if (-not (Test-Path $TemplatePath)) {
            throw "Detection script template not found: $TemplatePath"
        }

        $safeAppName = [regex]::Replace($AppName, '[^A-Za-z0-9]', '')
        $safeRitm = if ([string]::IsNullOrWhiteSpace($Ritm)) { "RITM00000000" } else { $Ritm.Trim() }

        $content = Get-Content -Path $TemplatePath -Raw -Encoding UTF8
        $content = $content.Replace('{CREATION_DATE}', (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
        $content = $content.Replace('{RITM}', $safeRitm)
        $content = $content.Replace('{APP_NAME}', $safeAppName)
        $content = $content.Replace('{APPLICATION_DISPLAY_NAME}', $AppName)
        $content = $content.Replace('{TARGET_VERSION}', $Version)
        $content = $content.Replace('{VENDOR_NAME}', $Vendor)

        $normalizedContext = if ($InstallContext -eq "User") { "User" } else { "System" }
        $content = $content -replace "\`$installContext\s*=\s*'[^']*'", "`$installContext = '$normalizedContext'"

        $outputFileName = "{0}_{1}_Detect_R1.ps1" -f $safeRitm, $safeAppName
        $outputPath = Join-Path $PackagePath $outputFileName
        $content | Set-Content -Path $outputPath -Encoding UTF8 -Force

        Write-Verbose "DetectionEngine: Detection script written to $outputPath"
        return @{
            Success = $true
            OutputPath = $outputPath
            Message = "Detection script generated successfully"
        }
    }
    catch {
        Write-Error "DetectionEngine: Error generating detection script - $($_.Exception.Message)"
        return @{
            Success = $false
            OutputPath = ""
            Message = $_.Exception.Message
        }
    }
}

# Export public functions
Export-ModuleMember -Function Get-InstallerType, Get-InstallContextRecommendation, New-PackageDetectionScript
