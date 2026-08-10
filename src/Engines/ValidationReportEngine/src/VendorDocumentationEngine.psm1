#Requires -Version 5.1
<#
.SYNOPSIS
    Vendor Documentation Engine

.DESCRIPTION
    Pulls validation context from vendor documentation URLs only.
    If no vendor documentation is available, returns:
    "The Vendor has nothing to report"
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

    $sources = New-Object System.Collections.Generic.List[string]
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
                                [void]$sources.Add(([string]$url).Trim())
                            }
                        }
                    }
                }
            }
        }
        catch {
            # Ignore config parse errors and continue with conservative fallback behavior.
        }
    }

    return @($sources | Select-Object -Unique)
}

function Test-IsVendorSourceUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [Parameter(Mandatory = $true)]
        [string]$Vendor
    )

    try {
        $uri = [System.Uri]$Url
        $host = $uri.Host.ToLowerInvariant()
        $vendorToken = ($Vendor -replace '[^A-Za-z0-9]', '').ToLowerInvariant()
        if ([string]::IsNullOrWhiteSpace($vendorToken)) {
            return $false
        }

        return ($host -like "*$vendorToken*")
    }
    catch {
        return $false
    }
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

function Get-SnippetByKeywords {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string[]]$Keywords,

        [int]$MaxItems = 3
    )

    $sentences = $Text -split '(?<=[\.\!\?])\s+'
    $matches = New-Object System.Collections.Generic.List[string]

    foreach ($sentence in $sentences) {
        $candidate = $sentence.Trim()
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        if ($candidate.Length -lt 20) { continue }
        foreach ($keyword in $Keywords) {
            if ($candidate -match $keyword) {
                [void]$matches.Add($candidate)
                break
            }
        }
        if ($matches.Count -ge $MaxItems) { break }
    }

    if ($matches.Count -eq 0) {
        return @()
    }

    return @($matches | Select-Object -Unique)
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

    $sources = Get-VendorDocumentationSources -Vendor $Vendor -AppName $AppName -AppVersion $AppVersion
    if (-not $sources -or $sources.Count -eq 0) {
        $result.Message = $script:NoDataMessage
        return $result
    }

    $allText = New-Object System.Collections.Generic.List[string]
    $sourcesUsed = New-Object System.Collections.Generic.List[string]

    foreach ($source in $sources) {
        if (-not (Test-IsVendorSourceUrl -Url $source -Vendor $Vendor)) {
            continue
        }

        try {
            $response = Invoke-WebRequest -Uri $source -UseBasicParsing -TimeoutSec 25 -ErrorAction Stop
            $content = Convert-HtmlToText -Html $response.Content
            if (-not [string]::IsNullOrWhiteSpace($content)) {
                [void]$allText.Add($content)
                [void]$sourcesUsed.Add($source)
            }
        }
        catch {
            # Continue trying additional vendor sources.
        }
    }

    if ($allText.Count -eq 0) {
        $result.Message = $script:NoDataMessage
        return $result
    }

    $mergedText = ($allText -join ' ')

    $osSnippets = Get-SnippetByKeywords -Text $mergedText -Keywords @('(?i)supported\s+operating\s+system', '(?i)operating\s+system', '(?i)windows\s+(10|11|server)', '(?i)supported\s+platform')
    $prereqSnippets = Get-SnippetByKeywords -Text $mergedText -Keywords @('(?i)prereq', '(?i)requirement', '(?i)dependency', '(?i)supported\s+operating\s+system')
    $conflictSnippets = Get-SnippetByKeywords -Text $mergedText -Keywords @('(?i)conflict', '(?i)incompatib', '(?i)cannot\s+be\s+installed', '(?i)known\s+issue')
    $upgradeSnippets = Get-SnippetByKeywords -Text $mergedText -Keywords @('(?i)upgrade', '(?i)migration', '(?i)in-place\s+upgrade', '(?i)coexist', '(?i)previous\s+version')

    if ($osSnippets.Count -gt 0) {
        $result.OSCompatibility = ($osSnippets -join [Environment]::NewLine)
    }

    if ($prereqSnippets.Count -gt 0) {
        $result.Prerequisites = ($prereqSnippets -join [Environment]::NewLine)
    }

    if ($conflictSnippets.Count -gt 0) {
        $result.ApplicationConflicts = ($conflictSnippets -join [Environment]::NewLine)
    }

    if ($upgradeSnippets.Count -gt 0) {
        $result.UpgradePaths = ($upgradeSnippets -join [Environment]::NewLine)
    }

    $result.SourcesUsed = @($sourcesUsed | Select-Object -Unique)
    if ($result.SourcesUsed.Count -eq 0) {
        $result.Message = $script:NoDataMessage
    }
    else {
        $result.Message = "Vendor documentation summary generated from $($result.SourcesUsed.Count) source(s)."
    }

    return $result
}

Export-ModuleMember -Function Get-VendorDocumentationSources, Get-VendorDocumentationSummary
