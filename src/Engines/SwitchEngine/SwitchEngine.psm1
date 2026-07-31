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

$script:WebSuggestionCache = @{}

function Get-WebSuggestionCachePath {
    $cacheRoot = Join-Path $env:LOCALAPPDATA "FRB-Packaging-Tool"
    if (-not (Test-Path $cacheRoot)) {
        New-Item -Path $cacheRoot -ItemType Directory -Force | Out-Null
    }

    return (Join-Path $cacheRoot "web-switch-cache.json")
}

function Initialize-WebSuggestionCache {
    if ($script:WebSuggestionCache.Count -gt 0) {
        return
    }

    $cachePath = Get-WebSuggestionCachePath
    if (-not (Test-Path $cachePath)) {
        return
    }

    try {
        $cacheJson = Get-Content -Path $cachePath -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($cacheJson)) { return }
        $cacheObject = $cacheJson | ConvertFrom-Json -ErrorAction Stop
        foreach ($prop in $cacheObject.PSObject.Properties) {
            $script:WebSuggestionCache[$prop.Name] = $prop.Value
        }
    }
    catch {
        # Ignore cache read errors and continue with fresh in-memory cache.
    }
}

function Save-WebSuggestionCache {
    try {
        $cachePath = Get-WebSuggestionCachePath
        $cacheObject = [ordered]@{}
        foreach ($key in $script:WebSuggestionCache.Keys) {
            $cacheObject[$key] = $script:WebSuggestionCache[$key]
        }
        $cacheObject | ConvertTo-Json -Depth 8 | Set-Content -Path $cachePath -Encoding UTF8 -Force
    }
    catch {
        # Cache persistence failures should not block helper generation.
    }
}

function Get-SimplifiedWebText {
    [CmdletBinding()]
    param(
        [string]$RawHtml = ""
    )

    if ([string]::IsNullOrWhiteSpace($RawHtml)) {
        return ""
    }

    $text = $RawHtml
    $text = [regex]::Replace($text, '(?is)<script.*?</script>', ' ')
    $text = [regex]::Replace($text, '(?is)<style.*?</style>', ' ')
    $text = [regex]::Replace($text, '(?is)<[^>]+>', ' ')
    $text = [regex]::Replace($text, '&nbsp;|&#160;', ' ')
    $text = [regex]::Replace($text, '&quot;|&#34;', '"')
    $text = [regex]::Replace($text, '&#39;|&apos;', "'")
    $text = [regex]::Replace($text, '&amp;', '&')
    $text = [regex]::Replace($text, '\s+', ' ')
    return $text.Trim()
}

function Extract-SilentSwitchesFromText {
    [CmdletBinding()]
    param(
        [string]$Text = "",
        [ValidateSet("Install", "Uninstall")]
        [string]$Mode = "Install"
    )

    $results = New-Object System.Collections.Generic.List[string]
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }

    $normalized = $Text -replace '[\r\n]+', ' '
    $candidates = New-Object System.Collections.Generic.List[string]

    $patternA = '(?i)(/(?:SILENT|VERYSILENT|S|Q|QN|QB!?|PASSIVE|QUIET|NORESTART|SUPPRESSMSGBOXES|SP-|NOICONS)(?:\s+[^\r\n]{0,80})?)'
    $patternB = '(?i)(--?(?:silent|quiet|norestart|uninstall)(?:[=: ]+[^\s\r\n<>]{1,40})?)'

    foreach ($match in [regex]::Matches($normalized, $patternA)) {
        $value = $match.Groups[1].Value.Trim(' ', ';', ',', '.', ':')
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            [void]$candidates.Add($value)
        }
    }

    foreach ($match in [regex]::Matches($normalized, $patternB)) {
        $value = $match.Groups[1].Value.Trim(' ', ';', ',', '.', ':')
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            [void]$candidates.Add($value)
        }
    }

    $cluster = @($candidates | Select-Object -Unique)
    foreach ($item in $cluster) {
        $v = $item.Trim()
        if ([string]::IsNullOrWhiteSpace($v)) { continue }

        $lower = $v.ToLowerInvariant()
        $switchTokens = New-Object System.Collections.Generic.List[string]

        if ($lower -match '(^|\s)/verysilent(\s|$)') { [void]$switchTokens.Add('/VERYSILENT') }
        if ($lower -match '(^|\s)/silent(\s|$)') { [void]$switchTokens.Add('/SILENT') }
        if ($lower -match '(^|\s)/s(\s|$)') { [void]$switchTokens.Add('/S') }
        if ($lower -match '(^|\s)/qn(\s|$)') { [void]$switchTokens.Add('/qn') }
        if ($lower -match '(^|\s)/qb!?(\s|$)') { [void]$switchTokens.Add('/qb!') }
        if ($lower -match '(^|\s)/quiet(\s|$)') { [void]$switchTokens.Add('/quiet') }
        if ($lower -match '(^|\s)/passive(\s|$)') { [void]$switchTokens.Add('/passive') }
        if ($lower -match '(^|\s)/norestart(\s|$)') { [void]$switchTokens.Add('/norestart') }
        if ($lower -match 'suppressmsgboxes') { [void]$switchTokens.Add('/SUPPRESSMSGBOXES') }
        if ($lower -match '(^|\s)/sp-(\s|$)') { [void]$switchTokens.Add('/SP-') }
        if ($lower -match '(^|\s)/noicons(\s|$)') { [void]$switchTokens.Add('/NOICONS') }
        if ($lower -match '(^|\s)--silent(\s|$)') { [void]$switchTokens.Add('--silent') }
        if ($lower -match '(^|\s)--quiet(\s|$)') { [void]$switchTokens.Add('--quiet') }
        if ($lower -match '(^|\s)-silent(\s|$)') { [void]$switchTokens.Add('-silent') }

        if ($Mode -eq "Uninstall") {
            if ($lower -match '(^|\s)/x(\s|$)') { [void]$switchTokens.Add('/x') }
            if ($lower -match 'uninstall') { [void]$switchTokens.Add('/uninstall') }
            if ($lower -match '_\?=') { [void]$switchTokens.Add('_?=') }
        }

        if ($v -match '(?i)\bREBOOT=ReallySuppress\b') {
            [void]$switchTokens.Add('REBOOT=ReallySuppress')
        }
        if ($v -match '(?i)/noUpdater') {
            [void]$switchTokens.Add('/noUpdater')
        }
        if ($v -match '(?i)/closeRunningNpp') {
            [void]$switchTokens.Add('/closeRunningNpp')
        }

        $switchLine = (@($switchTokens | Select-Object -Unique | Select-Object -First 8) -join ' ').Trim()
        if ([string]::IsNullOrWhiteSpace($switchLine)) {
            continue
        }

        $looksSilent = $switchLine -match '(?i)silent|quiet|/qn|/qb|/s|norestart|verysilent|suppressmsgboxes'
        if (-not $looksSilent) { continue }

        if ($Mode -eq "Uninstall") {
            if ($switchLine -match '(?i)install' -and $switchLine -notmatch '(?i)uninstall') { continue }
            if ($switchLine -match '(?i)^/i\b') { continue }
        }

        [void]$results.Add($switchLine)
    }

    return @($results | Select-Object -Unique | Select-Object -First 8)
}

function Invoke-BingSearchLinks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,

        [int]$MaxLinks = 6
    )

    $links = New-Object System.Collections.Generic.List[string]
    try {
        $uri = "https://www.bing.com/search?q=$([uri]::EscapeDataString($Query))&count=12&setlang=en-us"
        $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 12 -ErrorAction Stop
        $html = $response.Content
        if ([string]::IsNullOrWhiteSpace($html)) {
            return @()
        }

        foreach ($match in [regex]::Matches($html, '(?i)<a\s+href="(https?://[^"]+)"')) {
            $url = $match.Groups[1].Value
            if ([string]::IsNullOrWhiteSpace($url)) { continue }
            if ($url -match '(?i)bing\.com|microsofttranslator|r\.bing\.com|go\.microsoft\.com') { continue }
            if ($url -match '(?i)javascript:|mailto:') { continue }
            [void]$links.Add($url)
            if ($links.Count -ge $MaxLinks) { break }
        }
    }
    catch {
        return @()
    }

    return @($links | Select-Object -Unique)
}

function Invoke-DuckDuckGoSearchLinks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,

        [int]$MaxLinks = 8
    )

    $links = New-Object System.Collections.Generic.List[string]
    try {
        $uri = "https://duckduckgo.com/html/?q=$([uri]::EscapeDataString($Query))"
        $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 12 -ErrorAction Stop
        $html = $response.Content
        if ([string]::IsNullOrWhiteSpace($html)) {
            return @()
        }

        foreach ($match in [regex]::Matches($html, 'uddg=([^&"]+)')) {
            $encoded = $match.Groups[1].Value
            if ([string]::IsNullOrWhiteSpace($encoded)) { continue }
            $url = [uri]::UnescapeDataString($encoded)
            if ([string]::IsNullOrWhiteSpace($url)) { continue }
            if ($url -notmatch '^https?://') { continue }
            if ($url -match '(?i)duckduckgo\.com') { continue }
            [void]$links.Add($url)
            if ($links.Count -ge $MaxLinks) { break }
        }
    }
    catch {
        return @()
    }

    return @($links | Select-Object -Unique)
}

function Get-WebSilentSwitchSuggestions {
    [CmdletBinding()]
    param(
        [string]$Vendor = "",
        [string]$AppName = "",
        [string]$Version = "",
        [string]$InstallerType = "Generic"
    )

    Initialize-WebSuggestionCache

    $safeVendor = if ([string]::IsNullOrWhiteSpace($Vendor)) { "" } else { $Vendor.Trim() }
    $safeAppName = if ([string]::IsNullOrWhiteSpace($AppName)) { "" } else { $AppName.Trim() }
    $safeVersion = if ([string]::IsNullOrWhiteSpace($Version)) { "" } else { $Version.Trim() }
    $safeInstallerType = if ([string]::IsNullOrWhiteSpace($InstallerType)) { "Generic" } else { $InstallerType.Trim() }

    if ([string]::IsNullOrWhiteSpace($safeAppName)) {
        return @{ Install = @(); Uninstall = @(); Sources = @(); Notes = @("Web lookup skipped: app name missing.") }
    }

    $cacheKey = ("{0}|{1}|{2}|{3}" -f $safeVendor.ToLowerInvariant(), $safeAppName.ToLowerInvariant(), $safeVersion.ToLowerInvariant(), $safeInstallerType.ToLowerInvariant())
    if ($script:WebSuggestionCache.ContainsKey($cacheKey)) {
        $cached = $script:WebSuggestionCache[$cacheKey]
        if ($cached -and $cached.GeneratedAt) {
            try {
                $generated = [DateTime]::Parse($cached.GeneratedAt)
                if ((New-TimeSpan -Start $generated -End (Get-Date)).TotalDays -lt 30) {
                    return $cached
                }
            }
            catch {
            }
        }
    }

    $installValues = New-Object System.Collections.Generic.List[string]
    $uninstallValues = New-Object System.Collections.Generic.List[string]
    $sources = New-Object System.Collections.Generic.List[string]
    $notes = New-Object System.Collections.Generic.List[string]

    $productBits = @($safeVendor, $safeAppName, $safeVersion, $safeInstallerType) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $productQuery = ($productBits -join ' ')

    $queries = @(
        "$productQuery silent install",
        "$productQuery unattended install",
        "$productQuery silent uninstall",
        "$productQuery quiet uninstall",
        "$productQuery vendor documentation silent install"
    )

    $allLinks = New-Object System.Collections.Generic.List[string]
    foreach ($query in $queries) {
        foreach ($link in @(Invoke-DuckDuckGoSearchLinks -Query $query -MaxLinks 6)) {
            [void]$allLinks.Add($link)
        }
        foreach ($link in @(Invoke-BingSearchLinks -Query $query -MaxLinks 5)) {
            [void]$allLinks.Add($link)
        }
    }
    $candidateLinks = @($allLinks | Select-Object -Unique | Select-Object -First 10)

    foreach ($link in $candidateLinks) {
        try {
            $web = Invoke-WebRequest -Uri $link -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
            $raw = $web.Content
            if ([string]::IsNullOrWhiteSpace($raw)) { continue }

            $text = Get-SimplifiedWebText -RawHtml $raw
            if ([string]::IsNullOrWhiteSpace($text)) { continue }

            $host = ""
            try { $host = ([uri]$link).Host } catch { $host = "web" }
            [void]$sources.Add("$host - $link")

            foreach ($candidate in @(Extract-SilentSwitchesFromText -Text $text -Mode "Install")) {
                [void]$installValues.Add($candidate)
            }
            foreach ($candidate in @(Extract-SilentSwitchesFromText -Text $text -Mode "Uninstall")) {
                [void]$uninstallValues.Add($candidate)
            }
        }
        catch {
            continue
        }
    }

    $installFinal = @($installValues | Select-Object -Unique | Select-Object -First 8)
    $uninstallFinal = @($uninstallValues | Select-Object -Unique | Select-Object -First 8)

    if ($installFinal.Count -eq 0 -and $uninstallFinal.Count -eq 0) {
        [void]$notes.Add("Web lookup completed but no reliable silent switches were extracted.")
    }
    elseif ($sources.Count -gt 0) {
        [void]$notes.Add("Web lookup produced source-backed silent switch candidates.")
    }

    $result = [ordered]@{
        Install = $installFinal
        Uninstall = $uninstallFinal
        Sources = @($sources | Select-Object -Unique | Select-Object -First 8)
        Notes = @($notes | Select-Object -Unique)
        GeneratedAt = (Get-Date).ToString("o")
    }

    $script:WebSuggestionCache[$cacheKey] = $result
    Save-WebSuggestionCache

    return $result
}

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

function Get-WrapperAwareSectionSuggestions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SectionKey,

        [string]$InstallerType = "Generic",
        [string]$AppName = "Application",
        [string]$Vendor = "Vendor",
        [string]$InstallContext = "System"
    )

    $safeInstallerType = if ([string]::IsNullOrWhiteSpace($InstallerType)) { "Generic" } else { $InstallerType }
    $safeAppName = if ([string]::IsNullOrWhiteSpace($AppName)) { "Application" } else { $AppName.Trim() }
    $safeVendor = if ([string]::IsNullOrWhiteSpace($Vendor)) { "Vendor" } else { $Vendor.Trim() }
    $safeContext = if ($InstallContext -eq "User") { "User" } else { "System" }

    switch ($SectionKey) {
        "PreInstallCommands" {
            return @(
@"
# Wrapper-aware pre-install check using Globals.ps1 cmdlets
Write-Log -Message 'Preparing to install $safeAppName in $safeContext context.' -Source 'Pre-Install'
Show-InstallationProgress -StatusMessage 'Preparing $safeAppName for installation...'
Block-AppExecution -ProcessName '$($safeAppName -replace '\s+', '')' -ErrorAction SilentlyContinue
"@,
@"
# Stop vendor-related services before install if they can lock files
if (Test-ServiceExists -Name '$($safeVendor -replace '\s+', '')') {
    Stop-ServiceAndDependencies -Name '$($safeVendor -replace '\s+', '')' -ErrorAction SilentlyContinue
}
"@
            )
        }
        "CustomInstallCommands" {
            if ($safeInstallerType -eq "MSI") {
                return @(
@"
# Wrapper-aware MSI install example
Write-Log -Message 'Executing MSI install for $safeAppName.' -Source 'Install'
Execute-MSI -Action Install -Path `$appMsiName -Parameters `$appInstallCommandLine
"@
                )
            }

            return @(
@"
# Wrapper-aware EXE install example
Write-Log -Message 'Executing installer for $safeAppName.' -Source 'Install'
Execute-Process -Path `$installPhasePath -Parameters `$appInstallCommandLine -WindowStyle Hidden -PassThru
"@
            )
        }
        "PostInstallCommands" {
            return @(
@"
# Wrapper-aware post-install validation example
Write-Log -Message 'Validating $safeAppName install footprint.' -Source 'Post-Install'
Get-InstalledApplication -Name '$safeAppName' -Exact -ErrorAction SilentlyContinue | Out-Null
Update-SessionEnvironmentVariables
"@,
@"
# Refresh shell and session so shortcuts and environment changes are visible
Write-Log -Message 'Refreshing desktop and session state after install.' -Source 'Post-Install'
[PSADT.Explorer]::RefreshDesktopAndEnvironmentVariables()
"@
            )
        }
        "PreUninstallCommands" {
            return @(
@"
# Wrapper-aware pre-uninstall preparation
Write-Log -Message 'Preparing to uninstall $safeAppName.' -Source 'Pre-Uninstall'
Show-InstallationProgress -StatusMessage 'Preparing $safeAppName for uninstall...'
Block-AppExecution -ProcessName '$($safeAppName -replace '\s+', '')' -ErrorAction SilentlyContinue
"@
            )
        }
        "CustomUninstallCommands" {
            if ($safeInstallerType -eq "MSI") {
                return @(
@"
# Wrapper-aware MSI uninstall example
Write-Log -Message 'Executing MSI uninstall for $safeAppName.' -Source 'Uninstall'
Execute-MSI -Action Uninstall -Path `$appMsiName -Parameters `$appUninstallCommandLine
"@
                )
            }

            return @(
@"
# Wrapper-aware EXE uninstall example
Write-Log -Message 'Executing uninstall command for $safeAppName.' -Source 'Uninstall'
Execute-Process -Path `$appUninstallExeName -Parameters `$appUninstallCommandLine -WindowStyle Hidden -PassThru
"@
            )
        }
        "PostUninstallCommands" {
            return @(
@"
# Wrapper-aware post-uninstall cleanup example
Write-Log -Message 'Cleaning residual machine folders for $safeAppName if they remain.' -Source 'Post-Uninstall'
Remove-Folder -Path (Join-Path `$env:ProgramFiles '$safeAppName') -ContinueOnError `$true
Remove-Folder -Path (Join-Path `$env:ProgramFiles '${safeVendor}') -ContinueOnError `$true
"@,
@"
# Preserve user-level items by policy but log what should be checked manually
Write-Log -Message 'User-level leftovers such as AppData or HKCU keys should be reviewed per package policy.' -Source 'Post-Uninstall'
"@
            )
        }
        default {
            return @()
        }
    }
}

function Get-PlaywrightScrapedPackageHelperSections {
    [CmdletBinding()]
    param(
        [string]$InstallMediaPath = "",
        [string]$AppName = ""
    )

    $emptyResult = @{
        Success = $false
        Sections = @{}
        Error = ""
        DurationSeconds = 0
        OutputFile = ""
    }

    $writeProcessLine = {
        param([string]$Message, [string]$Level = "INFO")
        if (Get-Command Write-ProcessOutputLine -ErrorAction SilentlyContinue) {
            Write-ProcessOutputLine -Message $Message -Level $Level
        }
    }

    function ConvertTo-HighSignalScraperLine {
        param([string]$Line)

        if ([string]::IsNullOrWhiteSpace($Line)) {
            return $null
        }

        $trimmed = $Line.Trim()

        if ($trimmed -match '^\[STEP\s+\d+\]') { return $trimmed }
        if ($trimmed -match '^\[(SUCCESS|ERROR|WARN)\]') { return $trimmed }
        if ($trimmed -match '^\[INFO\]\s+Scraping\s+') { return $trimmed }
        if ($trimmed -match '^\[INFO\]\s+\s*->\s+(Loading page|Following|Total kept|Landing page candidates|Link candidates)') { return $trimmed }
        if ($trimmed -match '^\[ERROR\]') { return $trimmed }

        return $null
    }

    function Remove-WriteHostLines {
        param([string]$Text)

        if ([string]::IsNullOrWhiteSpace($Text)) {
            return ""
        }

        $lines = $Text -split "`r?`n"
        $filtered = @()
        foreach ($line in $lines) {
            if ($line -match '(?i)^\s*Write-(Host|Output|Verbose|Debug|Warning|Information|Progress)\b') {
                continue
            }
            if ($line -match '(?i)^\s*echo\b') {
                continue
            }
            $filtered += $line
        }

        return (($filtered -join "`r`n").Trim())
    }

    function Get-CodeOnlySnippet {
        param([string]$Text)

        if ([string]::IsNullOrWhiteSpace($Text)) {
            return ""
        }

        $lines = $Text -split "`r?`n"
        $kept = @()

        foreach ($rawLine in $lines) {
            $line = [string]$rawLine
            $trimmed = $line.Trim()

            if ([string]::IsNullOrWhiteSpace($trimmed)) {
                continue
            }

            if ($trimmed -match '(?i)^(source|summary|suggestions? found|section\s*\d+|deployment method)\b') {
                continue
            }

            if ($trimmed -match '(?i)^(to install|to uninstall|learn more|add to script builder)\b') {
                continue
            }

            if ($trimmed -match '(?i)^\s*#\s*(source|summary|suggestion|context|documentation)\b') {
                continue
            }

            if ($trimmed -match '(?i)^\s*Write-(Host|Output|Verbose|Debug|Warning|Information|Progress)\b') {
                continue
            }

            if ($trimmed -match '(?i)^\s*echo\b') {
                continue
            }

            $kept += $line
        }

        return (($kept -join "`r`n").Trim())
    }

    function Test-IsUsefulCodeSnippet {
        param([string]$Text)

        if ([string]::IsNullOrWhiteSpace($Text)) {
            return $false
        }

        $sample = ($Text -replace "`r", " " -replace "`n", " ").Trim()
        if ([string]::IsNullOrWhiteSpace($sample)) {
            return $false
        }

        if ($sample.Length -lt 6) {
            return $false
        }

        if ($sample -match '^(https?://|www\.)') {
            return $false
        }

        $commandPattern = '(?i)\b(msiexec|choco|winget|setup\.exe|install\.exe|uninstall\.exe|execute-process|execute-msi|start-process|remove-item|get-itemproperty|test-path|stop-process|block-appexecution|show-installationprogress|if\s*\(|foreach\s*\(|\$appInstallCommandLine|\$appUninstallCommandLine|/q[nb]?|/quiet|/silent|--silent|--quiet)\b'
        if ($sample -match $commandPattern) {
            return $true
        }

        # Accept concise assignment-style snippets even when command tokens are absent.
        if ($sample -match '(?i)^\s*\$[a-z0-9_]+\s*=\s*.+$') {
            return $true
        }

        return $false
    }

    if ([string]::IsNullOrWhiteSpace($InstallMediaPath) -or -not (Test-Path $InstallMediaPath)) {
        $emptyResult.Error = "Installer media path is missing or not accessible."
        return $emptyResult
    }

    $toolRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\.."))
    $scraperScriptPath = Join-Path $toolRoot "Playwright_Scraping_POC\Test-Scraper.ps1"
    $scraperOutputPath = Join-Path $toolRoot "Playwright_Scraping_POC\output"

    if (-not (Test-Path $scraperScriptPath)) {
        $emptyResult.Error = "Playwright scraper script was not found."
        return $emptyResult
    }

    if (-not (Test-Path $scraperOutputPath)) {
        $emptyResult.Error = "Playwright output folder was not found."
        return $emptyResult
    }

    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if (-not $pythonCmd) {
        $emptyResult.Error = "Python command was not found on PATH for Playwright scraping."
        & $writeProcessLine -Message "Package Helper scrape skipped: Python command not found on PATH." -Level "WARN"
        return $emptyResult
    }

    & $writeProcessLine -Message "Package Helper scrape: precheck passed." -Level "INFO"

    try {
        & python -c "import playwright" 2>$null
        if ($LASTEXITCODE -ne 0) {
            $emptyResult.Error = "Python is available but Playwright module is not installed in that environment."
            & $writeProcessLine -Message "Package Helper scrape skipped: Playwright Python module not installed." -Level "WARN"
            return $emptyResult
        }
    }
    catch {
        $emptyResult.Error = "Playwright import precheck failed: $($_.Exception.Message)"
        & $writeProcessLine -Message ("Package Helper scrape precheck failed: {0}" -f $_.Exception.Message) -Level "WARN"
        return $emptyResult
    }

    $runStartedUtc = [DateTime]::UtcNow
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    & $writeProcessLine -Message "Package Helper scrape: running Playwright extraction (may take up to a minute)." -Level "INFO"

    try {
        $psRunner = "powershell.exe"
        if (-not (Get-Command $psRunner -ErrorAction SilentlyContinue)) {
            $psRunner = (Join-Path $PSHOME "powershell.exe")
        }

        $scrapeOutput = & $psRunner -NoProfile -ExecutionPolicy Bypass -File $scraperScriptPath -InstallerPath $InstallMediaPath 2>&1

        foreach ($entry in @($scrapeOutput)) {
            if ($null -eq $entry) { continue }

            $line = ""
            if ($entry -is [System.Management.Automation.ErrorRecord]) {
                $line = [string]$entry.ToString()
            }
            else {
                $line = [string]$entry
            }

            if ([string]::IsNullOrWhiteSpace($line)) { continue }

            $line = $line.Trim()
            $highSignal = ConvertTo-HighSignalScraperLine -Line $line
            if ([string]::IsNullOrWhiteSpace($highSignal)) {
                continue
            }

            $lineLevel = "INFO"
            if ($highSignal -match '^\[(ERROR|WARN)\]') {
                $lineLevel = "WARN"
            }

            & $writeProcessLine -Message ("[Scraper] {0}" -f $highSignal) -Level $lineLevel
        }

        $stopwatch.Stop()
        $emptyResult.DurationSeconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 2)

        if ($LASTEXITCODE -ne 0) {
            $logTail = ""
            $scraperLogPath = Join-Path $toolRoot "Playwright_Scraping_POC\logs\scraper.log"
            if (Test-Path $scraperLogPath) {
                try {
                    $logTail = (Get-Content -Path $scraperLogPath -Tail 4 -ErrorAction SilentlyContinue | Out-String).Trim()
                }
                catch {
                }
            }

            $emptyResult.Error = "Playwright scraper exited with code $LASTEXITCODE after $($emptyResult.DurationSeconds)s."
            if (-not [string]::IsNullOrWhiteSpace($logTail)) {
                $emptyResult.Error += " Log tail: $logTail"
            }
            & $writeProcessLine -Message $emptyResult.Error -Level "WARN"
            return $emptyResult
        }
    }
    catch {
        $stopwatch.Stop()
        $emptyResult.DurationSeconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
        $emptyResult.Error = "Playwright scraper execution failed: $($_.Exception.Message)"
        & $writeProcessLine -Message $emptyResult.Error -Level "WARN"
        return $emptyResult
    }

    $latestOutput = Get-ChildItem -Path $scraperOutputPath -Filter "*.json" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1

    if (-not $latestOutput) {
        $emptyResult.Error = "No Playwright output JSON file was found."
        & $writeProcessLine -Message $emptyResult.Error -Level "WARN"
        return $emptyResult
    }

    if ($latestOutput.LastWriteTimeUtc -lt $runStartedUtc.AddMinutes(-2)) {
        $emptyResult.Error = "Latest Playwright output appears stale and was not produced by this run."
        & $writeProcessLine -Message $emptyResult.Error -Level "WARN"
        return $emptyResult
    }

    $emptyResult.OutputFile = $latestOutput.FullName

    try {
        & $writeProcessLine -Message "Package Helper scrape: processing scraper output..." -Level "INFO"
        $json = Get-Content -Path $latestOutput.FullName -Raw -Encoding UTF8
        $parsed = $json | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        $emptyResult.Error = "Failed to parse Playwright output JSON: $($_.Exception.Message)"
        & $writeProcessLine -Message $emptyResult.Error -Level "WARN"
        return $emptyResult
    }

    $sections = @{}
    foreach ($section in @($parsed)) {
        $sectionNumber = 0
        try { $sectionNumber = [int]$section.SectionNumber } catch { $sectionNumber = 0 }
        if ($sectionNumber -lt 1 -or $sectionNumber -gt 10) {
            continue
        }

        $formattedSuggestions = @()
        foreach ($suggestion in @($section.Suggestions)) {
            if (-not $suggestion) { continue }
            $text = Remove-WriteHostLines -Text ([string]$suggestion.Text)
            $text = Get-CodeOnlySnippet -Text $text
            if ([string]::IsNullOrWhiteSpace($text)) { continue }
            if (-not (Test-IsUsefulCodeSnippet -Text $text)) { continue }

            $confidence = ""
            if ($null -ne $suggestion.Confidence) {
                try {
                    $confidence = [string]::Format("{0:N2}", [double]$suggestion.Confidence)
                }
                catch {
                }
            }

            $formattedSuggestions += $text
        }

        if ($formattedSuggestions.Count -gt 0) {
            $sections[$sectionNumber] = @($formattedSuggestions | Select-Object -Unique)
        }
    }

    if ($sections.Count -gt 0) {
        $sectionSummary = @()
        foreach ($key in @($sections.Keys | Sort-Object)) {
            $count = @($sections[$key]).Count
            $sectionSummary += ("S{0}={1}" -f $key, $count)
        }
        & $writeProcessLine -Message ("Playwright section counts: {0}" -f ($sectionSummary -join ", ")) -Level "INFO"
    }

    if ($sections.Count -eq 0) {
        $emptyResult.Error = "Playwright completed but no section suggestions were extracted."
        & $writeProcessLine -Message $emptyResult.Error -Level "WARN"
        return $emptyResult
    }

    & $writeProcessLine -Message ("Package Helper scrape: completed in {0}s. Sections with data: {1}." -f $emptyResult.DurationSeconds, $sections.Count) -Level "INFO"

    return @{
        Success = $true
        Sections = $sections
        Error = ""
        DurationSeconds = $emptyResult.DurationSeconds
        OutputFile = $emptyResult.OutputFile
    }
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
        [hashtable]$ContextRecommendation = @{},
        [switch]$DisableWebLookup,
        [switch]$DisablePlaywrightLookup
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

    $webSuggestions = @{ Install = @(); Uninstall = @(); Sources = @(); Notes = @() }
    if (-not $DisableWebLookup) {
        $webSuggestions = Get-WebSilentSwitchSuggestions -Vendor $safeVendor -AppName $safeAppName -Version $safeVersion -InstallerType $safeInstallerType
    }

    $playwrightSuggestions = @{ Success = $false; Sections = @{}; Error = ""; DurationSeconds = 0; OutputFile = "" }
    $playwrightLookupStatus = "Disabled"
    $playwrightLookupMessage = "Playwright lookup disabled by request."
    $playwrightLookupDurationSeconds = 0
    if (-not $DisablePlaywrightLookup) {
        $playwrightSuggestions = Get-PlaywrightScrapedPackageHelperSections -InstallMediaPath $InstallMediaPath -AppName $safeAppName
        $playwrightLookupDurationSeconds = $playwrightSuggestions.DurationSeconds
        if ($playwrightSuggestions.Success) {
            $playwrightLookupStatus = "Succeeded"
            $playwrightLookupMessage = "Playwright lookup succeeded. Sections populated: $($playwrightSuggestions.Sections.Count)."
        }
        elseif (-not [string]::IsNullOrWhiteSpace($playwrightSuggestions.Error)) {
            $playwrightLookupStatus = "Failed"
            $playwrightLookupMessage = $playwrightSuggestions.Error
        }
        else {
            $playwrightLookupStatus = "Skipped"
            $playwrightLookupMessage = "Playwright lookup returned no data."
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($CurrentInstallSwitch)) {
        $installSwitches = @($CurrentInstallSwitch.Trim()) + ($installSwitches | Where-Object { $_ -ne $CurrentInstallSwitch.Trim() })
    }
    if (-not [string]::IsNullOrWhiteSpace($CurrentUninstallSwitch)) {
        $uninstallSwitches = @($CurrentUninstallSwitch.Trim()) + ($uninstallSwitches | Where-Object { $_ -ne $CurrentUninstallSwitch.Trim() })
    }

    $extension = ""
    $mediaFileName = ""
    $mediaFileNameNoExt = ""
    if (-not [string]::IsNullOrWhiteSpace($InstallMediaPath)) {
        try {
            $extension = [System.IO.Path]::GetExtension($InstallMediaPath).ToLower()
            $mediaFileName = [System.IO.Path]::GetFileName($InstallMediaPath)
            $mediaFileNameNoExt = [System.IO.Path]::GetFileNameWithoutExtension($InstallMediaPath)
        }
        catch {
            $extension = ""
            $mediaFileName = ""
            $mediaFileNameNoExt = ""
        }
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

    # Use already-entered values as first-priority suggestions so helper output stays grounded in real package data.
    if (-not [string]::IsNullOrWhiteSpace($CurrentInstallSwitch)) {
        $installCommandSuggestions = @("`$appInstallCommandLine = '$($CurrentInstallSwitch.Trim())'") + $installCommandSuggestions
    }

    foreach ($webInstall in @($webSuggestions.Install)) {
        if ([string]::IsNullOrWhiteSpace($webInstall)) { continue }
        $sourceTag = if ($webSuggestions.Sources.Count -gt 0) { $webSuggestions.Sources[0] } else { "Web lookup" }
        $installCommandSuggestions = @("# Source: $sourceTag`r`n`$appInstallCommandLine = '$webInstall'") + $installCommandSuggestions
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

    # Additional uninstall switch candidates inferred from install switch and media type.
    if (-not [string]::IsNullOrWhiteSpace($CurrentInstallSwitch)) {
        $currentInstallTrim = $CurrentInstallSwitch.Trim()
        if ($extension -eq ".msi" -or $safeInstallerType -eq "MSI") {
            if ($currentInstallTrim -match '(?i)REBOOT=ReallySuppress|/norestart') {
                $uninstallCommandSuggestions += "`$appUninstallCommandLine = '/qn REBOOT=ReallySuppress'"
            }
            if ($currentInstallTrim -match '(?i)/qb!|/passive') {
                $uninstallCommandSuggestions += "`$appUninstallCommandLine = '/qb! REBOOT=ReallySuppress'"
            }
        }
        elseif ($currentInstallTrim -match '(?i)VERYSILENT') {
            $uninstallCommandSuggestions += "`$appUninstallCommandLine = '/VERYSILENT /NORESTART /SUPPRESSMSGBOXES'"
        }
        elseif ($currentInstallTrim -match '(?i)SILENT') {
            $uninstallCommandSuggestions += "`$appUninstallCommandLine = '/SILENT /NORESTART'"
        }
        elseif ($currentInstallTrim -match '(?i)(^|\s)/S(\s|$)') {
            $uninstallCommandSuggestions += "`$appUninstallCommandLine = '/S'"
        }
    }

    if ($safeInstallerType -eq "NSIS") {
        $uninstallCommandSuggestions += "`$appUninstallCommandLine = '/S _?=`"`$dirFiles`"'"
    }

    if (-not [string]::IsNullOrWhiteSpace($CurrentUninstallSwitch)) {
        $uninstallCommandSuggestions = @("`$appUninstallCommandLine = '$($CurrentUninstallSwitch.Trim())'") + $uninstallCommandSuggestions
    }

    foreach ($webUninstall in @($webSuggestions.Uninstall)) {
        if ([string]::IsNullOrWhiteSpace($webUninstall)) { continue }
        $sourceTag = if ($webSuggestions.Sources.Count -gt 0) { $webSuggestions.Sources[0] } else { "Web lookup" }
        $uninstallCommandSuggestions = @("# Source: $sourceTag`r`n`$appUninstallCommandLine = '$webUninstall'") + $uninstallCommandSuggestions
    }

    $defaultUninstallExeOptions = @(
        "`$appUninstallExeName = 'unins000.exe'",
        "`$appUninstallExeName = '$($safeAppName -replace '\\s+', '')_Uninstall.exe'",
        "`$appUninstallExeName = '$safeAppName-uninstall.exe'",
        "`$appUninstallExeName = '' # Use MSI/product code uninstall path"
    )

    if ($safeInstallerType -eq "MSI" -or $extension -eq ".msi") {
        $defaultUninstallExeOptions = @(
            "`$appUninstallExeName = '' # MSI uninstall path (no EXE name needed)",
            "`$appUninstallExeName = '' # Use app product code with Execute-MSI -Action Uninstall"
        ) + $defaultUninstallExeOptions
    }

    if ($safeInstallerType -eq "InnoSetup") {
        $defaultUninstallExeOptions = @(
            "`$appUninstallExeName = 'unins000.exe'",
            "`$appUninstallExeName = 'unins001.exe'"
        ) + $defaultUninstallExeOptions
    }

    if ($safeInstallerType -eq "NSIS") {
        $defaultUninstallExeOptions = @(
            "`$appUninstallExeName = 'uninstall.exe'",
            "`$appUninstallExeName = 'Uninstall.exe'",
            "`$appUninstallExeName = 'uninst.exe'"
        ) + $defaultUninstallExeOptions
    }

    if ($safeInstallerType -eq "InstallShield") {
        $defaultUninstallExeOptions = @(
            "`$appUninstallExeName = 'setup.exe'",
            "`$appUninstallExeName = 'uninstall.exe'"
        ) + $defaultUninstallExeOptions
    }

    if (-not [string]::IsNullOrWhiteSpace($mediaFileName)) {
        $defaultUninstallExeOptions = @(
            "`$appUninstallExeName = '$mediaFileName' # Try media executable as uninstall launcher"
        ) + $defaultUninstallExeOptions
    }

    if (-not [string]::IsNullOrWhiteSpace($mediaFileNameNoExt)) {
        $trimmedMediaStem = $mediaFileNameNoExt.Trim()
        $defaultUninstallExeOptions = @(
            "`$appUninstallExeName = '$trimmedMediaStem.exe'",
            "`$appUninstallExeName = '${trimmedMediaStem}_uninstall.exe'"
        ) + $defaultUninstallExeOptions
    }

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
`$rebootPending = Test-PendingReboot -ErrorAction SilentlyContinue
if (`$rebootPending) {
    Write-Log -Message 'Pending reboot detected. Request reboot before install.' -Source 'Pre-Install'
    Show-InstallationPrompt -Message 'A reboot is pending. Reboot the device and rerun installation.' -ButtonRightText 'OK' -Icon Warning
    Exit-Script -ExitCode 69001
}
"@,
@"
# Stop application processes before install
`$blockedProcesses = @('$($safeAppName -replace '\\s+', '')','${safeAppName}.exe','$($safeVendor -replace '\\s+', '')') | Where-Object { -not [string]::IsNullOrWhiteSpace(`$_) }
if (`$blockedProcesses.Count -gt 0) {
    Block-AppExecution -ProcessName `$blockedProcesses -ErrorAction SilentlyContinue
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

    $preInstallChecks += Get-WrapperAwareSectionSuggestions -SectionKey "PreInstallCommands" -InstallerType $safeInstallerType -AppName $safeAppName -Vendor $safeVendor -InstallContext $safeContext
    $customInstallSuggestions += Get-WrapperAwareSectionSuggestions -SectionKey "CustomInstallCommands" -InstallerType $safeInstallerType -AppName $safeAppName -Vendor $safeVendor -InstallContext $safeContext
    $postInstallSuggestions += Get-WrapperAwareSectionSuggestions -SectionKey "PostInstallCommands" -InstallerType $safeInstallerType -AppName $safeAppName -Vendor $safeVendor -InstallContext $safeContext
    $preUninstallSuggestions += Get-WrapperAwareSectionSuggestions -SectionKey "PreUninstallCommands" -InstallerType $safeInstallerType -AppName $safeAppName -Vendor $safeVendor -InstallContext $safeContext
    $customUninstallSuggestions += Get-WrapperAwareSectionSuggestions -SectionKey "CustomUninstallCommands" -InstallerType $safeInstallerType -AppName $safeAppName -Vendor $safeVendor -InstallContext $safeContext
    $postUninstallSuggestions += Get-WrapperAwareSectionSuggestions -SectionKey "PostUninstallCommands" -InstallerType $safeInstallerType -AppName $safeAppName -Vendor $safeVendor -InstallContext $safeContext

    $preInstallChecks = @($preInstallChecks | Select-Object -Unique)
    $customInstallSuggestions = @($customInstallSuggestions | Select-Object -Unique)
    $postInstallSuggestions = @($postInstallSuggestions | Select-Object -Unique)
    $preUninstallSuggestions = @($preUninstallSuggestions | Select-Object -Unique)
    $customUninstallSuggestions = @($customUninstallSuggestions | Select-Object -Unique)
    $postUninstallSuggestions = @($postUninstallSuggestions | Select-Object -Unique)

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

    if ($playwrightSuggestions.Success) {
        if ($playwrightSuggestions.Sections.ContainsKey(1)) { $contextSelectionSuggestions = @($playwrightSuggestions.Sections[1]) + $contextSelectionSuggestions }
        if ($playwrightSuggestions.Sections.ContainsKey(2)) { $installCommandSuggestions = @($playwrightSuggestions.Sections[2]) + $installCommandSuggestions }
        if ($playwrightSuggestions.Sections.ContainsKey(3)) { $uninstallCommandSuggestions = @($playwrightSuggestions.Sections[3]) + $uninstallCommandSuggestions }
        if ($playwrightSuggestions.Sections.ContainsKey(4)) { $defaultUninstallExeOptions = @($playwrightSuggestions.Sections[4]) + $defaultUninstallExeOptions }
        if ($playwrightSuggestions.Sections.ContainsKey(5)) { $preInstallChecks = @($playwrightSuggestions.Sections[5]) + $preInstallChecks }
        if ($playwrightSuggestions.Sections.ContainsKey(6)) { $customInstallSuggestions = @($playwrightSuggestions.Sections[6]) + $customInstallSuggestions }
        if ($playwrightSuggestions.Sections.ContainsKey(7)) { $postInstallSuggestions = @($playwrightSuggestions.Sections[7]) + $postInstallSuggestions }
        if ($playwrightSuggestions.Sections.ContainsKey(8)) { $preUninstallSuggestions = @($playwrightSuggestions.Sections[8]) + $preUninstallSuggestions }
        if ($playwrightSuggestions.Sections.ContainsKey(9)) { $customUninstallSuggestions = @($playwrightSuggestions.Sections[9]) + $customUninstallSuggestions }
        if ($playwrightSuggestions.Sections.ContainsKey(10)) { $postUninstallSuggestions = @($playwrightSuggestions.Sections[10]) + $postUninstallSuggestions }
    }
    elseif (-not [string]::IsNullOrWhiteSpace($playwrightSuggestions.Error)) {
        $contextSelectionSuggestions += "Playwright scrape note: $($playwrightSuggestions.Error)"
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
            PlaywrightLookupStatus = $playwrightLookupStatus
            PlaywrightLookupMessage = $playwrightLookupMessage
            PlaywrightLookupDurationSeconds = $playwrightLookupDurationSeconds
            PlaywrightOutputFile = $playwrightSuggestions.OutputFile
        }
        Sections = [ordered]@{
            ContextSelection = [ordered]@{
                Title = "Context Selection"
                Summary = "Selected install context and detection rationale for $productDisplay."
                Suggestions = $contextSelectionSuggestions
            }
            InstallCommand = [ordered]@{
                Title = "Install Command Line"
                Summary = "Silent install switch options for $productDisplay ($safeInstallerType). Source-ordered from existing field value, live web lookup, vendor preset, installer defaults, and media hints."
                Suggestions = $installCommandSuggestions
            }
            UninstallCommand = [ordered]@{
                Title = "Uninstall Command Line"
                Summary = "Silent uninstall switch options for $productDisplay ($safeInstallerType). Source-ordered from existing field value, live web lookup, vendor preset, installer defaults, media hints, and install-switch parity."
                Suggestions = $uninstallCommandSuggestions
            }
            UninstallExecutable = [ordered]@{
                Title = "Uninstall Executable"
                Summary = "Uninstall executable candidates ordered from existing field value, installer family heuristics, and install-media filename patterns."
                Suggestions = $defaultUninstallExeOptions
            }
            PreInstallCommands = [ordered]@{
                Title = "Pre-Install Commands"
                Summary = "Wrapper-aware pre-install command snippets for $productDisplay using Globals.ps1 cmdlets where helpful."
                Suggestions = $preInstallChecks
            }
            CustomInstallCommands = [ordered]@{
                Title = "Custom Install Commands"
                Summary = "Wrapper-aware custom install commands for $productDisplay with executable/MSI patterns technicians can actually adapt."
                Suggestions = $customInstallSuggestions
            }
            PostInstallCommands = [ordered]@{
                Title = "Post-Install Commands"
                Summary = "Wrapper-aware post-install commands for $productDisplay including validation and shell refresh patterns."
                Suggestions = $postInstallSuggestions
            }
            PreUninstallCommands = [ordered]@{
                Title = "Pre-Uninstall Commands"
                Summary = "Wrapper-aware pre-uninstall commands for $productDisplay using package wrapper cmdlets."
                Suggestions = $preUninstallSuggestions
            }
            CustomUninstallCommands = [ordered]@{
                Title = "Custom Uninstall Commands"
                Summary = "Wrapper-aware custom uninstall commands for $productDisplay with MSI or executable examples."
                Suggestions = $customUninstallSuggestions
            }
            PostUninstallCommands = [ordered]@{
                Title = "Post-Uninstall Commands"
                Summary = "Wrapper-aware post-uninstall cleanup commands for $productDisplay, including machine-scope cleanup patterns."
                Suggestions = $postUninstallSuggestions
            }
        }
    }

    return $result
}

# Export public functions
Export-ModuleMember -Function Get-InstallSwitches, Get-UninstallSwitches, Get-SwitchesForInstaller, Get-PackageHelpSections, Get-WrapperAwareSectionSuggestions, Get-WebSilentSwitchSuggestions
