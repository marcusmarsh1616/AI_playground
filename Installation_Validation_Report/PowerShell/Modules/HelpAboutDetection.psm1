#Requires -Version 5.1
<#!
.SYNOPSIS
    Detect currently open Help/About style windows and capture verification info.

.DESCRIPTION
    Scans running processes for window titles that look like Help/About/Version dialogs
    and returns basic evidence such as the window title, process name, executable path,
    and version information from the executable.
#>

function Get-HelpAboutVerification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$ApplicationName
    )

    $patterns = @('about', 'help', 'version', 'info', 'license', 'properties', 'product', 'details')
    $results = New-Object System.Collections.Generic.List[object]

    try {
        $processes = @(Get-Process | Where-Object { $_.MainWindowTitle -and $_.MainWindowTitle.Trim() })
    } catch {
        return @()
    }

    foreach ($process in $processes) {
        $title = [string]$process.MainWindowTitle
        if ([string]::IsNullOrWhiteSpace($title)) {
            continue
        }

        $titleLower = $title.ToLowerInvariant()
        $matchedPattern = $null
        foreach ($pattern in $patterns) {
            if ($titleLower -like "*$pattern*") {
                $matchedPattern = $pattern
                break
            }
        }

        if (-not $matchedPattern) {
            $titleWords = $titleLower -split '[^a-z0-9]+'
            $hasDialogLikeText = ($titleWords -contains 'about') -or ($titleWords -contains 'help') -or ($titleWords -contains 'version') -or ($titleWords -contains 'information') -or ($titleWords -contains 'details')
            if (-not $hasDialogLikeText) {
                continue
            }
            $matchedPattern = 'dialog-like'
        }

        if ($ApplicationName) {
            $appNameLower = $ApplicationName.ToLowerInvariant()
            $processNameLower = $process.ProcessName.ToLowerInvariant()
            $nameMatches = $titleLower -like "*$appNameLower*" -or $processNameLower -like "*$appNameLower*"
            if ($appNameLower -ne 'all' -and -not $nameMatches) {
                continue
            }
        }

        $exePath = $null
        try {
            $processInfo = Get-CimInstance Win32_Process -Filter "ProcessId = $($process.Id)" -ErrorAction SilentlyContinue
            if ($processInfo -and $processInfo.ExecutablePath) {
                $exePath = $processInfo.ExecutablePath
            }
        } catch {
            $exePath = $null
        }

        $productName = $null
        $companyName = $null
        $fileVersion = $null
        $productVersion = $null

        if ($exePath -and (Test-Path $exePath)) {
            try {
                $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($exePath)
                $productName = $versionInfo.ProductName
                $companyName = $versionInfo.CompanyName
                $fileVersion = $versionInfo.FileVersion
                $productVersion = $versionInfo.ProductVersion
            } catch {
                $productName = $null
            }
        }

        $results.Add([PSCustomObject]@{
            ProcessName = $process.ProcessName
            WindowTitle = $title
            MatchedPattern = $matchedPattern
            ExecutablePath = $exePath
            ProductName = $productName
            CompanyName = $companyName
            FileVersion = $fileVersion
            ProductVersion = $productVersion
        })
    }

    return $results.ToArray()
}

Export-ModuleMember -Function Get-HelpAboutVerification
