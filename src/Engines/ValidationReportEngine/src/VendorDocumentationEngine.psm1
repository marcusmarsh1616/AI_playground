#Requires -Version 5.1
<#
.SYNOPSIS
    Vendor Documentation Engine

.DESCRIPTION
    Performs live web research for validation section data.
    Uses configured vendor source hints plus real-time search/crawl.
#>

$script:NoDataMessage = "The Vendor has nothing to report"

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
    $text = $text -replace '&nbsp;', ' '
    $text = $text -replace '&amp;', '&'
    $text = $text -replace '&quot;', '"'
    $text = $text -replace '&#39;', "'"
    $text = $text -replace '\s+', ' '
    return $text.Trim()
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

        $hit = $false
        foreach ($keyword in $Keywords) {
            if ($candidate -match $keyword) {
                $hit = $true
                break
            }
        }

        if (-not $hit) { continue }

        $line = "[$SourceLabel] $candidate"
        [void]$results.Add($line)
        if ($results.Count -ge $MaxItems) { break }
    }

    return @($results | Select-Object -Unique)
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
        "$productQuery vendor documentation"
    )

    $linkPool = New-Object System.Collections.Generic.List[string]
    foreach ($seed in $seedSources) {
        [void]$linkPool.Add($seed)
    }

    foreach ($query in $queries) {
        foreach ($url in @(Invoke-DuckDuckGoSearchLinks -Query $query -MaxLinks 8)) {
            [void]$linkPool.Add($url)
        }
        foreach ($url in @(Invoke-BingSearchLinks -Query $query -MaxLinks 6)) {
            [void]$linkPool.Add($url)
        }
    }

    $uniqueLinks = @($linkPool | Select-Object -Unique)
    $candidateLinks = New-Object System.Collections.Generic.List[string]
    foreach ($link in $uniqueLinks) {
        if (Test-IsTrustedDocumentationUrl -Url $link -Vendor $safeVendor -AppName $safeApp) {
            [void]$candidateLinks.Add($link)
        }
        if ($candidateLinks.Count -ge 24) { break }
    }

    $allOsSnippets = New-Object System.Collections.Generic.List[string]
    $allPrereqSnippets = New-Object System.Collections.Generic.List[string]
    $allConflictSnippets = New-Object System.Collections.Generic.List[string]
    $allUpgradeSnippets = New-Object System.Collections.Generic.List[string]
    $usedSources = New-Object System.Collections.Generic.List[string]

    foreach ($link in @($candidateLinks)) {
        try {
            $response = Invoke-WebRequest -Uri $link -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop
            $raw = [string]$response.Content
            if ([string]::IsNullOrWhiteSpace($raw)) { continue }

            $text = Convert-HtmlToText -Html $raw
            if ([string]::IsNullOrWhiteSpace($text)) { continue }

            $normalizedText = ($text -replace '[^A-Za-z0-9]', '').ToLowerInvariant()
            $appToken = ($safeApp -replace '[^A-Za-z0-9]', '').ToLowerInvariant()
            if (-not [string]::IsNullOrWhiteSpace($appToken) -and $normalizedText -notlike "*$appToken*") {
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

            foreach ($item in @(Get-SectionSnippets -Text $text -SourceLabel $sourceLabel -Keywords @('(?i)supported\s+operating\s+system', '(?i)operating\s+system', '(?i)windows\s+(10|11|server)', '(?i)supported\s+platform') -MaxItems 2)) {
                [void]$allOsSnippets.Add($item)
            }

            foreach ($item in @(Get-SectionSnippets -Text $text -SourceLabel $sourceLabel -Keywords @('(?i)prereq', '(?i)requirement', '(?i)dependency', '(?i)install\s+requires', '(?i)minimum\s+requirement') -MaxItems 2)) {
                [void]$allPrereqSnippets.Add($item)
            }

            foreach ($item in @(Get-SectionSnippets -Text $text -SourceLabel $sourceLabel -Keywords @('(?i)conflict', '(?i)incompatib', '(?i)known\s+issue', '(?i)not\s+supported', '(?i)serious\s+conflict') -MaxItems 2)) {
                [void]$allConflictSnippets.Add($item)
            }

            foreach ($item in @(Get-SectionSnippets -Text $text -SourceLabel $sourceLabel -Keywords @('(?i)upgrade', '(?i)migration', '(?i)previous\s+version', '(?i)in-place', '(?i)coexist', '(?i)deprecated') -MaxItems 2)) {
                [void]$allUpgradeSnippets.Add($item)
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

    if ($result.SourcesUsed.Count -eq 0) {
        $result.Message = $script:NoDataMessage
    }
    else {
        $result.Message = "Live web scraping completed using $($result.SourcesUsed.Count) source(s)."
    }

    return $result
}

Export-ModuleMember -Function Get-VendorDocumentationSources, Get-VendorDocumentationSummary
