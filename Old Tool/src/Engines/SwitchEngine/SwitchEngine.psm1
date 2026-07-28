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

function Get-PackageHelpSections {
    <#
    .SYNOPSIS
        Build copy/paste-ready package helper sections with alternate suggestions
    .DESCRIPTION
        Returns structured package-help content for install/uninstall command lines,
        uninstall executable guidance, and pre-install prerequisite checks.
    .PARAMETER InstallerType
        Detected installer type
    .PARAMETER Vendor
        Application vendor
    .PARAMETER AppName
        Application name
    .PARAMETER Edition
        Application edition (optional)
    .PARAMETER Version
        Application version (optional)
    .PARAMETER InstallMediaPath
        Full path to installer media
    .PARAMETER CurrentInstallSwitch
        Current install switch from GUI (optional)
    .PARAMETER CurrentUninstallSwitch
        Current uninstall switch from GUI (optional)
    .PARAMETER CurrentUninstallExecutable
        Current uninstall executable from GUI (optional)
    .PARAMETER InstallContext
        Selected install context (User or System)
    .PARAMETER ContextRecommendation
        Recommendation object returned by context detection
    .OUTPUTS
        Hashtable with section metadata and suggestions
    #>
    [CmdletBinding()]
    param(
        [string]$InstallerType = "Generic",
        [string]$Vendor = "",
        [string]$AppName = "",
        [string]$Edition = "",
        [string]$Version = "",
        [string]$InstallMediaPath = "",
        [string]$CurrentInstallSwitch = "",
        [string]$CurrentUninstallSwitch = "",
        [string]$CurrentUninstallExecutable = "",
        [string]$InstallContext = "System",
        [hashtable]$ContextRecommendation = @{}
    )

    $safeInstallerType = if ([string]::IsNullOrWhiteSpace($InstallerType)) { "Generic" } else { $InstallerType }
    $safeAppName = if ([string]::IsNullOrWhiteSpace($AppName)) { "Application" } else { $AppName.Trim() }
    $safeVendor = if ([string]::IsNullOrWhiteSpace($Vendor)) { "Vendor" } else { $Vendor.Trim() }
    $safeEdition = if ([string]::IsNullOrWhiteSpace($Edition)) { "" } else { $Edition.Trim() }
    $safeVersion = if ([string]::IsNullOrWhiteSpace($Version)) { "" } else { $Version.Trim() }
    $safeContext = if ($InstallContext -eq "User") { "User" } else { "System" }

    $productDisplay = $safeAppName
    if (-not [string]::IsNullOrWhiteSpace($safeEdition)) { $productDisplay = "$productDisplay $safeEdition" }
    if (-not [string]::IsNullOrWhiteSpace($safeVersion)) { $productDisplay = "$productDisplay $safeVersion" }

    $installSwitches = @(Get-InstallSwitches -InstallerType $safeInstallerType)
    $uninstallSwitches = @(Get-UninstallSwitches -InstallerType $safeInstallerType)

    if (-not [string]::IsNullOrWhiteSpace($CurrentInstallSwitch)) {
        $installSwitches = @($CurrentInstallSwitch.Trim()) + ($installSwitches | Where-Object { $_ -ne $CurrentInstallSwitch.Trim() })
    }
    if (-not [string]::IsNullOrWhiteSpace($CurrentUninstallSwitch)) {
        $uninstallSwitches = @($CurrentUninstallSwitch.Trim()) + ($uninstallSwitches | Where-Object { $_ -ne $CurrentUninstallSwitch.Trim() })
    }

    $extension = ""
    if (-not [string]::IsNullOrWhiteSpace($InstallMediaPath)) {
        try { $extension = [System.IO.Path]::GetExtension($InstallMediaPath).ToLower() } catch { $extension = "" }
    }

    $presetName = "General"
    $presetInstallCommandSuggestions = @()
    $presetUninstallCommandSuggestions = @()
    $presetUninstallExeOptions = @()
    $presetPreInstallChecks = @()
    $presetPrerequisiteSuggestions = @()
    $presetPreUninstallSuggestions = @()
    $presetCustomInstallSuggestions = @()
    $presetPostInstallSuggestions = @()
    $presetCustomUninstallSuggestions = @()
    $presetPostUninstallSuggestions = @()

    $vendorLower = $safeVendor.ToLowerInvariant()
    $appLower = $safeAppName.ToLowerInvariant()

    if ($vendorLower -match "adobe" -or $appLower -match "acrobat|reader|creative cloud") {
        $presetName = "Adobe"
        $presetInstallCommandSuggestions = @(
            "`$appInstallCommandLine = '--silent --norestart'",
            "`$appInstallCommandLine = '/sAll /rs /rps /msi EULA_ACCEPT=YES'"
        )
        $presetUninstallCommandSuggestions = @(
            "`$appUninstallCommandLine = '--silent --remove'",
            "`$appUninstallCommandLine = '/sAll /rs /rps /uninstall'"
        )
        $presetUninstallExeOptions = @(
            "`$appUninstallExeName = 'setup.exe'",
            "`$appUninstallExeName = 'AcroRd32.exe'"
        )
        $presetPrerequisiteSuggestions = @(
@"
# Adobe services can lock files during update/install windows
Get-Service -Name 'AdobeARMservice' -ErrorAction SilentlyContinue | ForEach-Object {
    if (`$_.Status -eq 'Running') { Stop-Service -Name `$_.Name -Force -ErrorAction SilentlyContinue }
}
"@
        )
    }
    elseif ($vendorLower -match "oracle" -or $appLower -match "java|jre|jdk") {
        $presetName = "Oracle Java"
        $presetInstallCommandSuggestions = @(
            "`$appInstallCommandLine = '/s REBOOT=Disable AUTO_UPDATE=0'",
            "`$appInstallCommandLine = '/qn REBOOT=ReallySuppress JU=0 JAVAUPDATE=0'"
        )
        $presetUninstallCommandSuggestions = @(
            "`$appUninstallCommandLine = '/qn REBOOT=ReallySuppress'",
            "`$appUninstallCommandLine = '/quiet /norestart'"
        )
        $presetPrerequisiteSuggestions = @(
@"
# Remove legacy Java auto-updater if present to reduce repair prompts
Get-Process -Name 'jusched' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
"@
        )
    }
    elseif ($vendorLower -match "microsoft" -or $appLower -match "teams|edge|visual c\+\+|office") {
        $presetName = "Microsoft"
        $presetInstallCommandSuggestions = @(
            "`$appInstallCommandLine = '/quiet /norestart'",
            "`$appInstallCommandLine = '/passive /norestart'"
        )
        $presetUninstallCommandSuggestions = @(
            "`$appUninstallCommandLine = '/quiet /norestart'",
            "`$appUninstallCommandLine = '/qn REBOOT=ReallySuppress'"
        )
        $presetPrerequisiteSuggestions = @(
@"
# Ensure WebView2 runtime exists when package depends on modern Microsoft UI stack
`$webView2 = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients' -ErrorAction SilentlyContinue | Where-Object { `$_.PSChildName -eq '{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}' }
if (-not `$webView2) {
    Write-Log -Message 'WebView2 runtime not found. Validate whether this app requires WebView2.' -Source 'Pre-Install'
}
"@
        )
    }
    elseif ($vendorLower -match "autodesk" -or $appLower -match "autocad|revit|inventor") {
        $presetName = "Autodesk"
        $presetInstallCommandSuggestions = @(
            "`$appInstallCommandLine = '--silent --norestart'",
            "`$appInstallCommandLine = '/W /q /I'"
        )
        $presetUninstallCommandSuggestions = @(
            "`$appUninstallCommandLine = '--silent --norestart'",
            "`$appUninstallCommandLine = '/q /x'"
        )
        $presetPreInstallChecks = @(
@"
# Autodesk deployments often require adequate temp space for extraction
`$tempDrive = Get-PSDrive -Name C -ErrorAction SilentlyContinue
if (`$tempDrive -and `$tempDrive.Free -lt 6GB) {
    Show-InstallationPrompt -Message 'At least 6 GB free space is recommended for Autodesk extraction/install.' -ButtonRightText 'OK' -Icon Warning
}
"@
        )
    }

    # Keep custom command suggestions empty by default.
    # Technicians can populate these manually when app-specific logic is required.

    $installCommandSuggestions = @()
    if ($presetInstallCommandSuggestions.Count -gt 0) {
        $installCommandSuggestions += $presetInstallCommandSuggestions
    }
    if ($extension -eq ".msi" -or $safeInstallerType -eq "MSI") {
        foreach ($switch in $installSwitches | Select-Object -First 4) {
            $installCommandSuggestions += "`$appInstallCommandLine = '/i `"`$appMsiName`" $switch'"
        }
    } else {
        foreach ($switch in $installSwitches | Select-Object -First 4) {
            $installCommandSuggestions += "`$appInstallCommandLine = '$switch'"
        }
    }

    $uninstallCommandSuggestions = @()
    if ($presetUninstallCommandSuggestions.Count -gt 0) {
        $uninstallCommandSuggestions += $presetUninstallCommandSuggestions
    }
    if ($extension -eq ".msi" -or $safeInstallerType -eq "MSI") {
        foreach ($switch in $uninstallSwitches | Select-Object -First 4) {
            $uninstallCommandSuggestions += "`$appUninstallCommandLine = '/x `"`$appMsiName`" $switch'"
        }
    } else {
        foreach ($switch in $uninstallSwitches | Select-Object -First 4) {
            $uninstallCommandSuggestions += "`$appUninstallCommandLine = '$switch'"
        }
    }

    $defaultUninstallExeOptions = @(
        "`$appUninstallExeName = 'unins000.exe'",
        "`$appUninstallExeName = '$($safeAppName -replace '\\s+', '')_Uninstall.exe'",
        "`$appUninstallExeName = '$safeAppName-uninstall.exe'",
        "`$appUninstallExeName = '' # Use MSI/product code uninstall path"
    )

    if ($presetUninstallExeOptions.Count -gt 0) {
        $defaultUninstallExeOptions = $presetUninstallExeOptions + $defaultUninstallExeOptions
    }

    if (-not [string]::IsNullOrWhiteSpace($CurrentUninstallExecutable)) {
        $trimmedUninstallExe = $CurrentUninstallExecutable.Trim()
        $defaultUninstallExeOptions = @("`$appUninstallExeName = '$trimmedUninstallExe'") + ($defaultUninstallExeOptions | Where-Object { $_ -notmatch [regex]::Escape($trimmedUninstallExe) })
    }

    $preInstallChecks = @(
@"
# Check pending reboot (common silent install blocker)
`$rebootPending = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
if (`$rebootPending) {
    Write-Log -Message 'Pending reboot detected. Request reboot before install.' -Source 'Pre-Install'
    Show-InstallationPrompt -Message 'A reboot is pending. Reboot the device and rerun installation.' -ButtonRightText 'OK' -Icon Warning
    Exit-Script -ExitCode 69001
}
"@,
@"
# Stop application processes before install
`$blockedProcesses = @('$($safeAppName -replace '\\s+', '')','${safeAppName}.exe','$($safeVendor -replace '\\s+', '')') | Where-Object { -not [string]::IsNullOrWhiteSpace(`$_) }
foreach (`$processName in `$blockedProcesses) {
    Get-Process -Name `$processName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
"@,
@"
# Ensure installer path is accessible and not blocked
if (-not (Test-Path -Path `"$InstallMediaPath`")) {
    Write-Log -Message 'Installer media was not found at expected path.' -Source 'Pre-Install'
    Exit-Script -ExitCode 69002
}
Unblock-File -Path `"$InstallMediaPath`" -ErrorAction SilentlyContinue
"@,
@"
# Validate free disk space before install (minimum 2 GB)
`$systemDrive = Get-PSDrive -Name C -ErrorAction SilentlyContinue
if (`$systemDrive -and `$systemDrive.Free -lt 2GB) {
    Show-InstallationPrompt -Message 'At least 2 GB of free space is required before installation.' -ButtonRightText 'OK' -Icon Error
    Exit-Script -ExitCode 69003
}
"@
    )

    if ($presetPreInstallChecks.Count -gt 0) {
        $preInstallChecks = $presetPreInstallChecks + $preInstallChecks
    }

    $prerequisiteSuggestions = @(
@"
# .NET prerequisite check (sample - adjust minimum release as needed)
`$netRelease = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release -ErrorAction SilentlyContinue).Release
if (-not `$netRelease -or `$netRelease -lt 528040) {
    Show-InstallationPrompt -Message 'Microsoft .NET Framework 4.8 or later is required.' -ButtonRightText 'OK' -Icon Error
    Exit-Script -ExitCode 69010
}
"@,
@"
# VC++ runtime presence check (x64)
`$vcKey = 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64'
`$vcInstalled = (Get-ItemProperty -Path `$vcKey -Name Installed -ErrorAction SilentlyContinue).Installed
if (`$vcInstalled -ne 1) {
    Write-Log -Message 'VC++ runtime x64 not detected. Install prerequisite first.' -Source 'Pre-Install'
    Exit-Script -ExitCode 69011
}
"@,
@"
# Windows Installer service check (important for MSI packages)
`$msiService = Get-Service -Name msiserver -ErrorAction SilentlyContinue
if (`$msiService -and `$msiService.Status -ne 'Running') {
    Start-Service -Name msiserver -ErrorAction SilentlyContinue
}
"@,
@"
# User context sanity check (if package expects non-elevated context)
if (`$installContext -eq 'User' -and [Security.Principal.WindowsIdentity]::GetCurrent().IsSystem) {
    Write-Log -Message 'User context package executed as SYSTEM. Validate deployment intent.' -Source 'Pre-Install'
}
"@
    )

    if ($presetPrerequisiteSuggestions.Count -gt 0) {
        $prerequisiteSuggestions = $presetPrerequisiteSuggestions + $prerequisiteSuggestions
    }

    $installCommandSuggestions = @($installCommandSuggestions | Select-Object -Unique)
    $uninstallCommandSuggestions = @($uninstallCommandSuggestions | Select-Object -Unique)
    $defaultUninstallExeOptions = @($defaultUninstallExeOptions | Select-Object -Unique)
    $preInstallChecks = @($preInstallChecks | Select-Object -Unique)
    $prerequisiteSuggestions = @($prerequisiteSuggestions | Select-Object -Unique)
    $preUninstallSuggestions = @($presetPreUninstallSuggestions | Select-Object -Unique)
    $customInstallSuggestions = @($presetCustomInstallSuggestions | Select-Object -Unique)
    $postInstallSuggestions = @($presetPostInstallSuggestions | Select-Object -Unique)
    $customUninstallSuggestions = @($presetCustomUninstallSuggestions | Select-Object -Unique)
    $postUninstallSuggestions = @($presetPostUninstallSuggestions | Select-Object -Unique)

    $contextSelectionSuggestions = @()
    $contextSelectionSuggestions += "Selected Context: $safeContext"
    if ($safeContext -eq "User") {
        $contextSelectionSuggestions += "Use user-context packaging behavior and avoid machine-only assumptions in custom command blocks."
        $contextSelectionSuggestions += "Validation focus: confirm shortcut/registry/file footprint in user profile scope (HKCU/AppData)."
    }
    else {
        $contextSelectionSuggestions += "Use system-context packaging behavior for machine-wide deployment and elevated operations."
        $contextSelectionSuggestions += "Validation focus: confirm machine-wide footprint (Program Files/ProgramData/HKLM)."
    }

    if ($ContextRecommendation -and $ContextRecommendation.Count -gt 0) {
        if ($ContextRecommendation.ContainsKey('Recommendation')) {
            $contextSelectionSuggestions += "Detection Recommendation: $($ContextRecommendation.Recommendation)"
        }
        if ($ContextRecommendation.ContainsKey('Confidence')) {
            $contextSelectionSuggestions += "Detection Confidence: $($ContextRecommendation.Confidence)"
        }
        if ($ContextRecommendation.ContainsKey('Reasons') -and $ContextRecommendation.Reasons) {
            foreach ($reason in @($ContextRecommendation.Reasons)) {
                $contextSelectionSuggestions += "Reason: $reason"
            }
        }
    }

    $contextSelectionSuggestions = @($contextSelectionSuggestions | Select-Object -Unique)

    $result = [ordered]@{
        Context = [ordered]@{
            Vendor = $safeVendor
            AppName = $safeAppName
            Edition = $safeEdition
            Version = $safeVersion
            ProductDisplayName = $productDisplay
            InstallerType = $safeInstallerType
            InstallMediaPath = $InstallMediaPath
            Preset = $presetName
            InstallContext = $safeContext
        }
        Sections = [ordered]@{
            ContextSelection = [ordered]@{
                Title = "Context Selection"
                Summary = "Selected install context and detection rationale for $productDisplay."
                Suggestions = $contextSelectionSuggestions
            }
            InstallCommand = [ordered]@{
                Title = "Install Command Line"
                Summary = "Silent install switch options for $productDisplay ($safeInstallerType). Preset: $presetName."
                Suggestions = $installCommandSuggestions
            }
            UninstallCommand = [ordered]@{
                Title = "Uninstall Command Line"
                Summary = "Silent uninstall switch options for $productDisplay ($safeInstallerType). Preset: $presetName."
                Suggestions = $uninstallCommandSuggestions
            }
            UninstallExecutable = [ordered]@{
                Title = "Uninstall Executable"
                Summary = "Possible uninstall executable names/strategies to try. Preset: $presetName."
                Suggestions = $defaultUninstallExeOptions
            }
            PreInstallCommands = [ordered]@{
                Title = "Pre-Install Commands"
                Summary = "Optional pre-install command snippets for $productDisplay."
                Suggestions = $preInstallChecks
            }
            CustomInstallCommands = [ordered]@{
                Title = "Custom Install Commands"
                Summary = "Optional custom install commands for $productDisplay. Left blank when no app-specific steps are suggested."
                Suggestions = $customInstallSuggestions
            }
            PostInstallCommands = [ordered]@{
                Title = "Post-Install Commands"
                Summary = "Optional post-install commands for $productDisplay. Left blank when no app-specific steps are suggested."
                Suggestions = $postInstallSuggestions
            }
            PreUninstallCommands = [ordered]@{
                Title = "Pre-Uninstall Commands"
                Summary = "Optional pre-uninstall commands for $productDisplay. Left blank when no app-specific steps are suggested."
                Suggestions = $preUninstallSuggestions
            }
            CustomUninstallCommands = [ordered]@{
                Title = "Custom Uninstall Commands"
                Summary = "Optional custom uninstall commands for $productDisplay. Left blank when no app-specific steps are suggested."
                Suggestions = $customUninstallSuggestions
            }
            PostUninstallCommands = [ordered]@{
                Title = "Post-Uninstall Commands"
                Summary = "Optional post-uninstall commands for $productDisplay. Left blank when no app-specific steps are suggested."
                Suggestions = $postUninstallSuggestions
            }
        }
    }

    return $result
}

# Export public functions
Export-ModuleMember -Function Get-InstallSwitches, Get-UninstallSwitches, Get-SwitchesForInstaller, Get-PackageHelpSections
