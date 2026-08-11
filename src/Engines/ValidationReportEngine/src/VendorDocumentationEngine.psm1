#Requires -Version 5.1
<#
.SYNOPSIS
    Vendor Documentation Engine

.DESCRIPTION
    Performs live web research for validation section data.
    Uses configured vendor source hints plus real-time search/crawl.
#>

$script:NoDataMessage = "Nothing to Report or Found."

function Convert-ToNormalizedToken {
    [CmdletBinding()]
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return "" }
    return (($Value -replace '[^A-Za-z0-9]', '').ToLowerInvariant())
}

function Get-AppAliasTokens {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$AppName)

    $tokens = New-Object System.Collections.Generic.List[string]
    $normalizedFull = Convert-ToNormalizedToken -Value $AppName
    if (-not [string]::IsNullOrWhiteSpace($normalizedFull)) {
        [void]$tokens.Add($normalizedFull)
        $trimmedTrailingDigits = ($normalizedFull -replace '\d+$', '')
        if (-not [string]::IsNullOrWhiteSpace($trimmedTrailingDigits) -and $trimmedTrailingDigits.Length -ge 4) {
            [void]$tokens.Add($trimmedTrailingDigits)
        }
    }

    foreach ($part in ($AppName -split '[\s\-_/\.]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        $partToken = Convert-ToNormalizedToken -Value $part
        if ($partToken.Length -ge 4) {
            [void]$tokens.Add($partToken)
            $partTrimmedDigits = ($partToken -replace '\d+$', '')
            if ($partTrimmedDigits.Length -ge 4) {
                [void]$tokens.Add($partTrimmedDigits)
            }
        }
    }

    return @($tokens | Select-Object -Unique)
}

function Get-SourceRelevanceScore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$NormalizedText,

        [Parameter(Mandatory = $true)]
        [string[]]$AppTokens,

        [string]$VendorToken = ""
    )

    $score = 0.0
    $appHits = 0
    foreach ($token in $AppTokens) {
        if (-not [string]::IsNullOrWhiteSpace($token) -and $NormalizedText -like "*$token*") {
            $appHits++
        }
    }

    if ($appHits -ge 1) { $score += 0.45 }
    if ($appHits -ge 2) { $score += 0.15 }

    if (-not [string]::IsNullOrWhiteSpace($VendorToken) -and $NormalizedText -like "*$VendorToken*") {
        $score += 0.20
    }

    if ($NormalizedText -match '(requirements|supported|compatib|prereq|dependency|upgrade|migration|install)') {
        $score += 0.20
    }

    if ($score -gt 1.0) { $score = 1.0 }
    return [Math]::Round($score, 2)
}

function Get-SectionFillCount {
    [CmdletBinding()]
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return 0 }
    if ($Value.Trim() -eq $script:NoDataMessage) { return 0 }
    return (@($Value -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count)
}

function Get-ConfiguredInterpreterCandidates {
    [CmdletBinding()]
    param()

    $paths = New-Object System.Collections.Generic.List[string]

    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")).Path
    $workspaceSettings = Join-Path $repoRoot ".vscode\settings.json"
    $userSettings = Join-Path $env:APPDATA "Code\User\settings.json"
    foreach ($settingsPath in @($workspaceSettings, $userSettings)) {
        if (-not (Test-Path $settingsPath)) { continue }
        try {
            $settings = Get-Content -Path $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($key in @('python.defaultInterpreterPath', 'python.pythonPath')) {
                $prop = $settings.PSObject.Properties[$key]
                if ($prop -and -not [string]::IsNullOrWhiteSpace([string]$prop.Value)) {
                    $candidatePath = ([string]$prop.Value).Trim()
                    if (-not [System.IO.Path]::IsPathRooted($candidatePath)) {
                        $candidatePath = Join-Path (Split-Path -Parent $settingsPath) $candidatePath
                    }
                    [void]$paths.Add($candidatePath)
                }
            }
        }
        catch {
            continue
        }
    }

    foreach ($envKey in @('FRB_VALIDATION_PYTHON_PATH', 'VALIDATION_PYTHON_PATH', 'PYTHON_EXECUTABLE')) {
        $envValue = [Environment]::GetEnvironmentVariable($envKey)
        if (-not [string]::IsNullOrWhiteSpace($envValue)) {
            [void]$paths.Add($envValue.Trim())
        }
    }

    return @($paths | Select-Object -Unique)
}

function Resolve-PythonRuntimeForPlaywright {
    [CmdletBinding()]
    param()

    $attempts = New-Object System.Collections.Generic.List[string]

    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")).Path
    $repoRootCandidates = @(
        (Join-Path $repoRoot "Installation_Validation_Report\.venv\Scripts\python.exe"),
        (Join-Path $repoRoot "Installation_Validation_Report\Python\.venv\Scripts\python.exe"),
        (Join-Path $repoRoot "Installation_Validation_Report\venv\Scripts\python.exe"),
        (Join-Path $repoRoot "Installation_Validation_Report\Python\venv\Scripts\python.exe")
    ) | Select-Object -Unique

    $pathCandidates = New-Object System.Collections.Generic.List[hashtable]
    foreach ($p in $repoRootCandidates) {
        [void]$pathCandidates.Add(@{ Name = "repo-local:$p"; Path = $p; PrefixArgs = @() })
    }
    foreach ($p in @(Get-ConfiguredInterpreterCandidates)) {
        [void]$pathCandidates.Add(@{ Name = "configured:$p"; Path = $p; PrefixArgs = @() })
    }

    foreach ($candidate in $pathCandidates) {
        $pathValue = [string]$candidate.Path
        if ([string]::IsNullOrWhiteSpace($pathValue)) { continue }
        if (-not [System.IO.Path]::IsPathRooted($pathValue)) {
            $pathValue = Join-Path $repoRoot $pathValue
        }

        if (-not (Test-Path $pathValue)) {
            [void]$attempts.Add("$($candidate.Name)=missing")
            continue
        }

        try {
            $ver = & $pathValue --version 2>&1
            if ($LASTEXITCODE -ne 0) {
                [void]$attempts.Add("$($candidate.Name)=version-failed")
                continue
            }

            & $pathValue -c "import playwright, playwright.sync_api" 2>$null
            if ($LASTEXITCODE -ne 0) {
                [void]$attempts.Add("$($candidate.Name)=playwright-import-failed")
                continue
            }

            return @{
                Name = [string]$candidate.Name
                CommandPath = $pathValue
                PrefixArgs = @()
                Version = ([string]$ver).Trim()
                Attempts = @($attempts)
            }
        }
        catch {
            [void]$attempts.Add("$($candidate.Name)=exception:$($_.Exception.Message)")
            continue
        }
    }

    $commandCandidates = @(
        @{ Name = 'python'; Command = 'python'; PrefixArgs = @() },
        @{ Name = 'py-3'; Command = 'py'; PrefixArgs = @('-3') },
        @{ Name = 'python3'; Command = 'python3'; PrefixArgs = @() }
    )

    foreach ($candidate in $commandCandidates) {
        $cmd = Get-Command $candidate.Command -ErrorAction SilentlyContinue
        if (-not $cmd) {
            [void]$attempts.Add("$($candidate.Name)=command-not-found")
            continue
        }

        $commandPath = $cmd.Source
        try {
            $versionOutput = & $commandPath @($candidate.PrefixArgs + @('--version')) 2>&1
            if ($LASTEXITCODE -ne 0) {
                [void]$attempts.Add("$($candidate.Name)=version-failed")
                continue
            }

            & $commandPath @($candidate.PrefixArgs + @('-c', 'import playwright, playwright.sync_api')) 2>$null
            if ($LASTEXITCODE -ne 0) {
                [void]$attempts.Add("$($candidate.Name)=playwright-import-failed")
                continue
            }

            return @{
                Name = $candidate.Name
                CommandPath = $commandPath
                PrefixArgs = @($candidate.PrefixArgs)
                Version = ([string]$versionOutput).Trim()
                Attempts = @($attempts)
            }
        }
        catch {
            [void]$attempts.Add("$($candidate.Name)=exception:$($_.Exception.Message)")
            continue
        }
    }

    return @{
        Name = ""
        CommandPath = ""
        PrefixArgs = @()
        Version = ""
        Attempts = @($attempts)
    }
}

function Resolve-RequirementsResearchScriptPath {
    [CmdletBinding()]
    param()

    $candidatePaths = @(
        (Join-Path $PSScriptRoot "..\..\..\..\Installation_Validation_Report\Python\research_requirements.py"),
        (Join-Path $PSScriptRoot "..\..\..\..\Validation Report\Python\research_requirements.py"),
        (Join-Path (Get-Location).Path "Installation_Validation_Report\Python\research_requirements.py")
    )

    foreach ($candidate in $candidatePaths) {
        if (Test-Path $candidate) {
            return (Resolve-Path $candidate).Path
        }
    }

    return $null
}

function Invoke-PlaywrightRequirementsResearch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Vendor,

        [Parameter(Mandatory = $true)]
        [string]$AppName,

        [Parameter(Mandatory = $false)]
        [string]$AppVersion
    )

    $result = [ordered]@{
        Success = $false
        OSCompatibility = $script:NoDataMessage
        Prerequisites = $script:NoDataMessage
        ApplicationConflicts = $script:NoDataMessage
        UpgradePaths = $script:NoDataMessage
        SourcesUsed = @()
        Message = ""
    }

    $researchScriptPath = Resolve-RequirementsResearchScriptPath
    if ([string]::IsNullOrWhiteSpace($researchScriptPath)) {
        $result.Message = "Playwright requirements research unavailable: research_requirements.py not found."
        return $result
    }

    $pythonRoot = Split-Path -Parent (Split-Path -Parent $researchScriptPath)
    $configPath = Join-Path $pythonRoot "Config\application_sources.json"
    $cachePath = Join-Path $pythonRoot "Cache\research_cache.json"

    if (-not (Test-Path $configPath)) {
        $result.Message = "Playwright requirements research unavailable: configuration file not found at $configPath"
        return $result
    }

    $pythonRuntime = Resolve-PythonRuntimeForPlaywright
    if (-not $pythonRuntime -or [string]::IsNullOrWhiteSpace([string]$pythonRuntime.CommandPath)) {
        $attemptText = ""
        if ($pythonRuntime -and $pythonRuntime.Attempts) {
            $attemptText = (@($pythonRuntime.Attempts) -join '; ')
        }
        $result.Message = "Playwright requirements research unavailable: no usable Python runtime with Playwright was found. Probes: $attemptText. Paths: script=$researchScriptPath; config=$configPath"
        return $result
    }

    $outputPath = [System.IO.Path]::GetTempFileName().Replace('.tmp', '.json')
    $stdoutPath = [System.IO.Path]::GetTempFileName().Replace('.tmp', '.log')
    $stderrPath = [System.IO.Path]::GetTempFileName().Replace('.tmp', '.log')

    try {
        $argList = New-Object System.Collections.Generic.List[string]
        foreach ($prefixArg in @($pythonRuntime.PrefixArgs)) {
            [void]$argList.Add([string]$prefixArg)
        }
        [void]$argList.Add($researchScriptPath)
        [void]$argList.Add($AppName)
        if (-not [string]::IsNullOrWhiteSpace($AppVersion)) {
            [void]$argList.Add("--version")
            [void]$argList.Add($AppVersion)
        }
        [void]$argList.Add("--config")
        [void]$argList.Add($configPath)
        [void]$argList.Add("--cache")
        [void]$argList.Add($cachePath)
        [void]$argList.Add("--output")
        [void]$argList.Add($outputPath)

        $process = Start-Process -FilePath $pythonRuntime.CommandPath -ArgumentList $argList.ToArray() -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -ErrorAction Stop

        if (-not (Test-Path $outputPath)) {
            $stderrTail = if (Test-Path $stderrPath) { (Get-Content $stderrPath -Tail 10 -ErrorAction SilentlyContinue) -join " | " } else { "" }
            $runtimeLabel = if ($pythonRuntime.Version) { "$($pythonRuntime.Name) [$($pythonRuntime.Version)]" } else { $pythonRuntime.Name }
            $result.Message = "Playwright requirements research did not produce output JSON (exit code $($process.ExitCode), runtime: $runtimeLabel). $stderrTail"
            return $result
        }

        $raw = Get-Content -Path $outputPath -Raw -Encoding UTF8
        $payload = $raw | ConvertFrom-Json -ErrorAction Stop
        if (-not $payload -or -not $payload.success) {
            $err = if ($payload -and $payload.error) { [string]$payload.error } else { "unknown error" }
            $result.Message = "Playwright requirements research failed: $err"
            return $result
        }

        $requirements = $payload.requirements
        $osLines = New-Object System.Collections.Generic.List[string]
        foreach ($line in @($requirements.operating_system)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$line)) {
                [void]$osLines.Add([string]$line)
            }
        }

        $prereqLines = New-Object System.Collections.Generic.List[string]
        foreach ($line in @($requirements.prerequisites)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$line)) {
                [void]$prereqLines.Add([string]$line)
            }
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$requirements.memory)) {
            [void]$prereqLines.Add("Memory: $($requirements.memory)")
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$requirements.disk_space)) {
            [void]$prereqLines.Add("Disk Space: $($requirements.disk_space)")
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$requirements.processor)) {
            [void]$prereqLines.Add("Processor: $($requirements.processor)")
        }

        $conflictLines = New-Object System.Collections.Generic.List[string]
        foreach ($line in @($requirements.conflicts)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$line)) {
                [void]$conflictLines.Add([string]$line)
            }
        }

        $upgradeLines = New-Object System.Collections.Generic.List[string]
        foreach ($line in @($requirements.upgrade_path)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$line)) {
                [void]$upgradeLines.Add([string]$line)
            }
        }

        if ($osLines.Count -gt 0) { $result.OSCompatibility = ($osLines | Select-Object -Unique) -join [Environment]::NewLine }
        if ($prereqLines.Count -gt 0) { $result.Prerequisites = ($prereqLines | Select-Object -Unique) -join [Environment]::NewLine }
        if ($conflictLines.Count -gt 0) { $result.ApplicationConflicts = ($conflictLines | Select-Object -Unique) -join [Environment]::NewLine }
        if ($upgradeLines.Count -gt 0) { $result.UpgradePaths = ($upgradeLines | Select-Object -Unique) -join [Environment]::NewLine }

        $sourceList = New-Object System.Collections.Generic.List[string]
        if ($payload.source_url) {
            [void]$sourceList.Add([string]$payload.source_url)
        }
        $result.SourcesUsed = @($sourceList | Select-Object -Unique)

        $method = if ($payload.research_method) { [string]$payload.research_method } else { "playwright" }
        $cacheNote = if ($payload.cached -eq $true) { " (cache hit)" } else { "" }
        $osFill = Get-SectionFillCount -Value $result.OSCompatibility
        $preFill = Get-SectionFillCount -Value $result.Prerequisites
        $confFill = Get-SectionFillCount -Value $result.ApplicationConflicts
        $upgFill = Get-SectionFillCount -Value $result.UpgradePaths
        $result.Message = "method=playwright_research_requirements; source_count=$(@($result.SourcesUsed).Count); fills=os:$osFill,pre:$preFill,conf:$confFill,upg:$upgFill; research_method=$method$cacheNote; script=$researchScriptPath; config=$configPath"
        $result.Success = $true
        return $result
    }
    catch {
        $runtimeLabel = if ($pythonRuntime -and $pythonRuntime.Version) { "$($pythonRuntime.Name) [$($pythonRuntime.Version)]" } elseif ($pythonRuntime) { $pythonRuntime.Name } else { 'unknown' }
        $result.Message = "Playwright requirements research execution failed (runtime: $runtimeLabel): $($_.Exception.Message)"
        return $result
    }
    finally {
        Remove-Item $outputPath -Force -ErrorAction SilentlyContinue
        Remove-Item $stdoutPath -Force -ErrorAction SilentlyContinue
        Remove-Item $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

function Get-VendorDocumentationSources {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Vendor,

        [Parameter(Mandatory = $false)]
        [string]$AppName,

        [Parameter(Mandatory = $false)]
        [string]$AppVersion
    )

    $sourceList = New-Object System.Collections.Generic.List[string]
    $engineRoot = Split-Path -Parent $PSScriptRoot
    $configPath = Join-Path $engineRoot "config\vendor-doc-sources.json"

    if (Test-Path $configPath) {
        try {
            $config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($config -and $config.vendors) {
                $vendorKey = ($Vendor -replace '\s+', '').ToLowerInvariant()
                foreach ($prop in $config.vendors.PSObject.Properties) {
                    $normalized = ($prop.Name -replace '\s+', '').ToLowerInvariant()
                    if ($normalized -eq $vendorKey -or $normalized -like "*$vendorKey*" -or $vendorKey -like "*$normalized*") {
                        foreach ($url in @($prop.Value)) {
                            if (-not [string]::IsNullOrWhiteSpace([string]$url)) {
                                [void]$sourceList.Add(([string]$url).Trim())
                            }
                        }
                    }
                }
            }
        }
        catch {
            # Ignore config parse errors and proceed with live scraping.
        }
    }

    return @($sourceList | Select-Object -Unique)
}

function Convert-HtmlToText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Html
    )

    $text = $Html -replace '(?is)<script[^>]*>.*?</script>', ' '
    $text = $text -replace '(?is)<style[^>]*>.*?</style>', ' '
    $text = $text -replace '(?is)<[^>]+>', ' '
    $text = [System.Net.WebUtility]::HtmlDecode($text)
    $text = $text -replace '&nbsp;', ' '
    $text = $text -replace '\s+', ' '
    return $text.Trim()
}

function Test-IsNoiseSnippet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) { return $true }
    $v = $Value.Trim()

    # Drop common chrome/footer/account text that appears in crawled pages.
    $noisePatterns = @(
        '(?i)^\s*(skip to|cookie|privacy policy|terms of service|all rights reserved)\b',
        '(?i)\b(view all files|footer|github,? inc\.|sign in|sign up|open (an|this) issue|pull requests?)\b',
        '(?i)^\s*#\s*\d+\s+in\s+[^\s]+',
        '(?i)\b(status:\s*open|opened on\s+[A-Za-z]{3,9}\s+\d{1,2},\s+\d{4})\b',
        '(?i)\btemplates\s+templates\b'
    )

    foreach ($pattern in $noisePatterns) {
        if ($v -match $pattern) {
            return $true
        }
    }

    return $false
}

function Invoke-DuckDuckGoSearchLinks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,

        [int]$MaxLinks = 10
    )

    $linkList = New-Object System.Collections.Generic.List[string]
    try {
        $uri = "https://duckduckgo.com/html/?q=$([uri]::EscapeDataString($Query))"
        $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
        $html = $response.Content
        if ([string]::IsNullOrWhiteSpace($html)) {
            return @()
        }

        foreach ($match in [regex]::Matches($html, 'uddg=([^&"]+)')) {
            $encoded = $match.Groups[1].Value
            if ([string]::IsNullOrWhiteSpace($encoded)) { continue }

            $candidateUrl = [uri]::UnescapeDataString($encoded)
            if ($candidateUrl -notmatch '^https?://') { continue }
            if ($candidateUrl -match '(?i)duckduckgo\.com') { continue }
            [void]$linkList.Add($candidateUrl)
            if ($linkList.Count -ge $MaxLinks) { break }
        }
    }
    catch {
        return @()
    }

    return @($linkList | Select-Object -Unique)
}

function Invoke-BingSearchLinks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,

        [int]$MaxLinks = 8
    )

    $linkList = New-Object System.Collections.Generic.List[string]
    try {
        $uri = "https://www.bing.com/search?q=$([uri]::EscapeDataString($Query))&count=12&setlang=en-us"
        $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
        $html = $response.Content
        if ([string]::IsNullOrWhiteSpace($html)) {
            return @()
        }

        foreach ($match in [regex]::Matches($html, '(?i)<a\s+href="(https?://[^"]+)"')) {
            $candidateUrl = $match.Groups[1].Value
            if ([string]::IsNullOrWhiteSpace($candidateUrl)) { continue }
            if ($candidateUrl -match '(?i)bing\.com|microsofttranslator|r\.bing\.com|go\.microsoft\.com') { continue }
            if ($candidateUrl -match '(?i)javascript:|mailto:') { continue }
            [void]$linkList.Add($candidateUrl)
            if ($linkList.Count -ge $MaxLinks) { break }
        }
    }
    catch {
        return @()
    }

    return @($linkList | Select-Object -Unique)
}

function Test-IsTrustedDocumentationUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [string]$Vendor = "",

        [string]$AppName = ""
    )

    try {
        $uri = [System.Uri]$Url
        $domain = $uri.Host.ToLowerInvariant()
        $pathAndQuery = ($uri.AbsolutePath + $uri.Query).ToLowerInvariant()

        $blockedDomains = @(
            'deepwiki.com',
            'reddit.com',
            'youtube.com',
            'stackoverflow.com',
            'facebook.com',
            'x.com',
            'twitter.com'
        )
        foreach ($blocked in $blockedDomains) {
            if ($domain -like "*$blocked") {
                return $false
            }
        }

        $vendorToken = ($Vendor -replace '[^A-Za-z0-9]', '').ToLowerInvariant()
        $appToken = ($AppName -replace '[^A-Za-z0-9]', '').ToLowerInvariant()
        $allowedDomains = @(
            'github.com',
            'learn.microsoft.com',
            'support.microsoft.com',
            'docs.microsoft.com',
            'support.google.com',
            'helpx.adobe.com',
            'docs.conda.io',
            'conda-forge.org',
            'anaconda.org',
            'readthedocs.io'
        )

        foreach ($allowed in $allowedDomains) {
            if ($domain -eq $allowed -or $domain -like "*.$allowed") {
                if ($domain -eq 'github.com') {
                    if ($pathAndQuery -match '^/[^/]+/[^/]+/(issues|pulls|discussions)' -or $pathAndQuery -match '\?q=') {
                        return $false
                    }

                    if ($pathAndQuery -notmatch '/(docs|releases|wiki|blob|tree|readme)') {
                        return $false
                    }
                }
                return $true
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($vendorToken) -and $domain -replace '[^a-z0-9]', '' -like "*$vendorToken*") {
            return $true
        }

        if (-not [string]::IsNullOrWhiteSpace($appToken) -and $domain -replace '[^a-z0-9]', '' -like "*$appToken*") {
            return $true
        }

        return $false
    }
    catch {
        return $false
    }
}

function Test-IsNoiseSnippet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) { return $true }
    $v = $Value.Trim()

    # Drop common chrome/footer/account text that appears in crawled pages.
    $noisePatterns = @(
        '(?i)^\s*(skip to|cookie|privacy policy|terms of service|all rights reserved)\b',
        '(?i)\b(view all files|footer|github,? inc\.|sign in|sign up|open (an|this) issue|pull requests?)\b',
        '(?i)^\s*#\s*\d+\s+in\s+[^\s]+',
        '(?i)\b(status:\s*open|opened on\s+[A-Za-z]{3,9}\s+\d{1,2},\s+\d{4})\b',
        '(?i)\btemplates\s+templates\b',
        '(?i)\broot\s+cause\s+hypothesis\b',
        '(?i)^\s*should\s+i\s+choose\s+one\s+or\s+another\b'
    )

    foreach ($pattern in $noisePatterns) {
        if ($v -match $pattern) {
            return $true
        }
    }

    return $false
}

function Get-SectionSnippets {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string[]]$Keywords,

        [Parameter(Mandatory = $true)]
        [string]$SourceLabel,

        [int]$MaxItems = 3
    )

    $results = New-Object System.Collections.Generic.List[string]
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }

    $sentences = $Text -split '(?<=[\.\!\?])\s+'
    foreach ($sentence in $sentences) {
        $candidate = $sentence.Trim()
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        if ($candidate.Length -lt 30) { continue }
        if ($candidate.Length -gt 420) { continue }
        if ((@($candidate -split '\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count) -lt 6) { continue }
        if (Test-IsNoiseSnippet -Value $candidate) { continue }

        $hit = $false
        foreach ($keyword in $Keywords) {
            if ($candidate -match $keyword) {
                $hit = $true
                break
            }
        }

        if (-not $hit) { continue }

        $line = $candidate
        [void]$results.Add($line)
        if ($results.Count -ge $MaxItems) { break }
    }

    return @($results | Select-Object -Unique)
}

function Get-RelevantSecondaryLinks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Html,

        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,

        [Parameter(Mandatory = $true)]
        [string[]]$AppTokens,

        [string]$VendorToken = "",

        [int]$MaxLinks = 3
    )

    $ranked = New-Object System.Collections.Generic.List[object]
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'

    try {
        $baseUri = [System.Uri]$BaseUrl
        $baseHost = $baseUri.Host.ToLowerInvariant()
    }
    catch {
        return @()
    }

    foreach ($match in [regex]::Matches($Html, '(?i)href\s*=\s*"([^"#]+)"|href\s*=\s*''([^''#]+)''')) {
        $href = $match.Groups[1].Value
        if ([string]::IsNullOrWhiteSpace($href)) {
            $href = $match.Groups[2].Value
        }
        if ([string]::IsNullOrWhiteSpace($href)) { continue }
        if ($href -match '^(?i)javascript:|mailto:') { continue }

        $absolute = $null
        try {
            if ($href -match '^https?://') {
                $absolute = [System.Uri]$href
            }
            else {
                $absolute = [System.Uri]::new($baseUri, $href)
            }
        }
        catch {
            continue
        }

        if ($absolute.Scheme -notin @('http', 'https')) { continue }
        $url = $absolute.AbsoluteUri
        if (-not $seen.Add($url)) { continue }

        $host = $absolute.Host.ToLowerInvariant()
        $sameHost = ($host -eq $baseHost)
        $trustedHost = Test-IsTrustedDocumentationUrl -Url $url -Vendor $VendorToken -AppName ($AppTokens -join ' ')
        if (-not $sameHost -and -not $trustedHost) { continue }

        $norm = Convert-ToNormalizedToken -Value $url
        $score = 0
        if ($norm -match '(docs|documentation|requirement|install|upgrade|release|faq|support|issue|wiki|readme)') { $score += 3 }
        if (-not [string]::IsNullOrWhiteSpace($VendorToken) -and $norm -like "*$VendorToken*") { $score += 2 }
        foreach ($token in $AppTokens) {
            if (-not [string]::IsNullOrWhiteSpace($token) -and $norm -like "*$token*") {
                $score += 2
                break
            }
        }

        if ($score -le 0) { continue }
        [void]$ranked.Add([pscustomobject]@{ Url = $url; Score = $score })
    }

    return @($ranked | Sort-Object -Property Score -Descending | Select-Object -ExpandProperty Url -First $MaxLinks)
}

function Get-VendorDocumentationSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Vendor,

        [Parameter(Mandatory = $true)]
        [string]$AppName,

        [Parameter(Mandatory = $false)]
        [string]$AppVersion
    )

    $result = [ordered]@{
        OSCompatibility = $script:NoDataMessage
        Prerequisites = $script:NoDataMessage
        ApplicationConflicts = $script:NoDataMessage
        UpgradePaths = $script:NoDataMessage
        SourcesUsed = @()
        Message = ""
    }

    $safeVendor = if ([string]::IsNullOrWhiteSpace($Vendor)) { "" } else { $Vendor.Trim() }
    $safeApp = if ([string]::IsNullOrWhiteSpace($AppName)) { "" } else { $AppName.Trim() }
    $safeVersion = if ([string]::IsNullOrWhiteSpace($AppVersion)) { "" } else { $AppVersion.Trim() }
    $vendorToken = Convert-ToNormalizedToken -Value $safeVendor
    $appTokens = @(Get-AppAliasTokens -AppName $safeApp)

    if ([string]::IsNullOrWhiteSpace($safeApp)) {
        $result.Message = $script:NoDataMessage
        return $result
    }

    $seedSources = @(Get-VendorDocumentationSources -Vendor $safeVendor -AppName $safeApp -AppVersion $safeVersion)

    $queryBase = @($safeVendor, $safeApp, $safeVersion) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $productQuery = ($queryBase -join ' ')
    $queries = @(
        "$productQuery requirements supported operating system",
        "$productQuery install prerequisites dependency",
        "$productQuery known issues conflicts incompatibility",
        "$productQuery upgrade migration previous version",
        "$productQuery vendor documentation",
        "$productQuery release notes upgrade guide",
        "$productQuery installation guide prerequisites",
        "$productQuery docs requirements windows"
    )

    $linkPool = New-Object System.Collections.Generic.List[string]
    foreach ($seed in $seedSources) {
        [void]$linkPool.Add($seed)
    }

    foreach ($query in $queries) {
        foreach ($url in @(Invoke-DuckDuckGoSearchLinks -Query $query -MaxLinks 12)) {
            [void]$linkPool.Add($url)
        }
        foreach ($url in @(Invoke-BingSearchLinks -Query $query -MaxLinks 10)) {
            [void]$linkPool.Add($url)
        }
    }

    $uniqueLinks = @($linkPool | Select-Object -Unique)
    $candidateLinks = New-Object System.Collections.Generic.List[string]
    foreach ($link in $uniqueLinks) {
        if (Test-IsTrustedDocumentationUrl -Url $link -Vendor $safeVendor -AppName $safeApp) {
            [void]$candidateLinks.Add($link)
        }
        if ($candidateLinks.Count -ge 48) { break }
    }

    $allOsSnippets = New-Object System.Collections.Generic.List[string]
    $allPrereqSnippets = New-Object System.Collections.Generic.List[string]
    $allConflictSnippets = New-Object System.Collections.Generic.List[string]
    $allUpgradeSnippets = New-Object System.Collections.Generic.List[string]
    $usedSources = New-Object System.Collections.Generic.List[string]
    $foundVendorAndAppSource = $false
    $visitedUrls = New-Object 'System.Collections.Generic.HashSet[string]'
    $crawlQueue = New-Object 'System.Collections.Generic.Queue[object]'
    $maxCrawlPages = 60
    $maxSecondaryPerPage = 4
    $maxDepth = 2
    $pagesFetched = 0
    $secondaryQueued = 0

    foreach ($seedUrl in @($candidateLinks)) {
        $crawlQueue.Enqueue([pscustomobject]@{ Url = $seedUrl; Depth = 0 })
    }

    while ($crawlQueue.Count -gt 0 -and $pagesFetched -lt $maxCrawlPages) {
        $queueItem = $crawlQueue.Dequeue()
        $link = [string]$queueItem.Url
        $depth = [int]$queueItem.Depth
        if ([string]::IsNullOrWhiteSpace($link)) { continue }
        if (-not $visitedUrls.Add($link)) { continue }

        try {
            $response = Invoke-WebRequest -Uri $link -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop
            $pagesFetched++
            $raw = [string]$response.Content
            if ([string]::IsNullOrWhiteSpace($raw)) { continue }

            $text = Convert-HtmlToText -Html $raw
            if ([string]::IsNullOrWhiteSpace($text)) { continue }

            $normalizedText = Convert-ToNormalizedToken -Value $text
            $appHits = @($appTokens | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $normalizedText -like "*$_*" }).Count
            $hasAnyApp = ($appHits -gt 0)
            $hasVendor = (-not [string]::IsNullOrWhiteSpace($vendorToken) -and $normalizedText -like "*$vendorToken*")
            $hasVendorAndApp = ($hasVendor -and $hasAnyApp)
            if ($hasVendorAndApp) { $foundVendorAndAppSource = $true }

            # Only app-relevant pages should populate section content.
            if (-not $hasAnyApp) {
                continue
            }

            $relevanceScore = Get-SourceRelevanceScore -NormalizedText $normalizedText -AppTokens $appTokens -VendorToken $vendorToken
            if ($relevanceScore -lt 0.30) {
                continue
            }

            $sourceLabel = "web"
            try {
                $sourceUri = [System.Uri]$link
                $sourceLabel = $sourceUri.Host
            }
            catch {
            }

            [void]$usedSources.Add($link)

            $allowAllSections = ($hasAnyApp -or $relevanceScore -ge 0.45)
            $allowConflictUpgrade = ($hasVendorAndApp -or $relevanceScore -ge 0.65)

            if ($allowAllSections) {
                foreach ($item in @(Get-SectionSnippets -Text $text -SourceLabel $sourceLabel -Keywords @('(?i)supported\s+operating\s+system', '(?i)operating\s+system', '(?i)windows\s+(10|11|server)', '(?i)supported\s+platform') -MaxItems 2)) {
                    [void]$allOsSnippets.Add($item)
                }

                foreach ($item in @(Get-SectionSnippets -Text $text -SourceLabel $sourceLabel -Keywords @('(?i)prereq', '(?i)requirement', '(?i)dependency', '(?i)install\s+requires', '(?i)minimum\s+requirement') -MaxItems 2)) {
                    [void]$allPrereqSnippets.Add($item)
                }
            }

            if ($allowConflictUpgrade) {
                foreach ($item in @(Get-SectionSnippets -Text $text -SourceLabel $sourceLabel -Keywords @('(?i)conflict', '(?i)incompatib', '(?i)known\s+issue', '(?i)not\s+supported', '(?i)serious\s+conflict') -MaxItems 2)) {
                    [void]$allConflictSnippets.Add($item)
                }

                foreach ($item in @(Get-SectionSnippets -Text $text -SourceLabel $sourceLabel -Keywords @('(?i)upgrade', '(?i)migration', '(?i)previous\s+version', '(?i)in-place', '(?i)coexist', '(?i)deprecated') -MaxItems 2)) {
                    [void]$allUpgradeSnippets.Add($item)
                }
            }

            if ($depth -lt $maxDepth) {
                foreach ($nextUrl in @(Get-RelevantSecondaryLinks -Html $raw -BaseUrl $link -AppTokens $appTokens -VendorToken $vendorToken -MaxLinks $maxSecondaryPerPage)) {
                    if ([string]::IsNullOrWhiteSpace([string]$nextUrl)) { continue }
                    if ($visitedUrls.Contains([string]$nextUrl)) { continue }
                    $crawlQueue.Enqueue([pscustomobject]@{ Url = [string]$nextUrl; Depth = ($depth + 1) })
                    $secondaryQueued++
                }
            }
        }
        catch {
            continue
        }
    }

    $finalOs = @($allOsSnippets | Select-Object -Unique | Select-Object -First 4)
    $finalPrereq = @($allPrereqSnippets | Select-Object -Unique | Select-Object -First 4)
    $finalConflict = @($allConflictSnippets | Select-Object -Unique | Select-Object -First 4)
    $finalUpgrade = @($allUpgradeSnippets | Select-Object -Unique | Select-Object -First 4)

    if ($finalOs.Count -gt 0) {
        $result.OSCompatibility = ($finalOs -join [Environment]::NewLine)
    }

    if ($finalPrereq.Count -gt 0) {
        $result.Prerequisites = ($finalPrereq -join [Environment]::NewLine)
    }

    if ($finalConflict.Count -gt 0) {
        $result.ApplicationConflicts = ($finalConflict -join [Environment]::NewLine)
    }

    if ($finalUpgrade.Count -gt 0) {
        $result.UpgradePaths = ($finalUpgrade -join [Environment]::NewLine)
    }

    $result.SourcesUsed = @($usedSources | Select-Object -Unique | Select-Object -First 20)

    $hasSectionData = ($finalOs.Count -gt 0 -or $finalPrereq.Count -gt 0 -or $finalConflict.Count -gt 0 -or $finalUpgrade.Count -gt 0)
    if (-not $hasSectionData) {
        $result.Message = $script:NoDataMessage
        $result.SourcesUsed = @()
    }
    else {
        $result.Message = ""
    }

    return $result
}

Export-ModuleMember -Function Get-VendorDocumentationSources, Get-VendorDocumentationSummary
