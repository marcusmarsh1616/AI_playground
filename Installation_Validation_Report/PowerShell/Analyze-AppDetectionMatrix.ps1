[CmdletBinding()]
param(
    [string]$OutputRoot,
    [int]$MaxApps = 200,
    [switch]$SkipLaunch,
    [switch]$IncludeSystemApps
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    $OutputRoot = Join-Path $scriptRoot '..\Output\AppDetectionAnalysis'
}

$modulePath = Join-Path $PSScriptRoot 'Modules\AboutDialogAutomation.psm1'
if (-not (Test-Path $modulePath)) {
    throw "AboutDialogAutomation module was not found at $modulePath"
}

Import-Module $modulePath -Force

$null = New-Item -ItemType Directory -Path $OutputRoot -Force -ErrorAction SilentlyContinue

$results = New-Object System.Collections.Generic.List[object]
$skipped = New-Object System.Collections.Generic.List[object]
$registryPaths = @(
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

function Get-RegistryValueSafe {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [Parameter(Mandatory=$true)]
        [string]$Name
    )

    if (-not (Test-Path $Path)) { return $null }
    try {
        $value = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name
        return $value
    } catch {
        return $null
    }
}

function Resolve-ExecutableCandidate {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }

    $trimmed = $Value.Trim().Trim('"')
    if ($trimmed -match '^(\".*\")') { $trimmed = $matches[1].Trim('"') }

    if ($trimmed -match '^[A-Za-z]:\\') {
        if ($trimmed -like '*.exe') { return $trimmed }
        if ($trimmed -like '*.lnk') { return $trimmed }
    }

    if ($trimmed -match '^(?:[A-Za-z]:\\|\\\\)') {
        return $trimmed
    }

    return $null
}

function Get-ExecutableCandidates {
    param([psobject]$App)

    $candidates = New-Object System.Collections.Generic.List[string]
    $displayIcon = $null
    $installLocation = $null
    $uninstallString = $null
    $quietUninstallString = $null

    if ($null -ne $App) {
        if (Get-Member -InputObject $App -Name 'DisplayIcon' -ErrorAction SilentlyContinue) { $displayIcon = $App.DisplayIcon }
        if (Get-Member -InputObject $App -Name 'InstallLocation' -ErrorAction SilentlyContinue) { $installLocation = $App.InstallLocation }
        if (Get-Member -InputObject $App -Name 'UninstallString' -ErrorAction SilentlyContinue) { $uninstallString = $App.UninstallString }
        if (Get-Member -InputObject $App -Name 'QuietUninstallString' -ErrorAction SilentlyContinue) { $quietUninstallString = $App.QuietUninstallString }
    }

    $rawValues = @($displayIcon, $installLocation, $uninstallString, $quietUninstallString)

    foreach ($raw in $rawValues) {
        if ([string]::IsNullOrWhiteSpace($raw)) { continue }

        if ($raw -match '"([^"]+)"') {
            $parsed = Resolve-ExecutableCandidate -Value $matches[1]
            if ($parsed) { $candidates.Add($parsed) }
        }

        $parsed2 = Resolve-ExecutableCandidate -Value $raw
        if ($parsed2) { $candidates.Add($parsed2) }
    }

    foreach ($candidate in @($candidates)) {
        if ($candidate -match '^[A-Za-z]:\\') {
            if (Test-Path $candidate) {
                if ($candidate -like '*.exe') { return @($candidate) }
                if (Test-Path $candidate -PathType Container) {
                    $child = Get-ChildItem -Path $candidate -Filter *.exe -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 5
                    if ($child) { return @($child.FullName) }
                }
            }
        }
    }

    return @($candidates | Select-Object -Unique)
}

function Test-LikelyGuiApp {
    param([psobject]$App)

    $name = [string]$App.DisplayName
    if ([string]::IsNullOrWhiteSpace($name)) { return $false }

    $skipPatterns = @('driver', 'redistributable', 'runtime', 'service', 'plugin service', 'health', 'update', 'sdk', 'visual c\+\+', 'microsoft visual', 'supportassist', 'device software', 'package manager', 'add-in', 'extension', 'plugin', 'installer', 'uninstall', 'setup', 'msiexec', 'driver', 'bluetooth', 'wireless', 'audio', 'intel', 'nvidia', 'amd', 'dell ', 'alienware', 'hp ', 'logi', 'wd ', 'killer')
    foreach ($pattern in $skipPatterns) {
        if ($name -match $pattern) { return $false }
    }

    $skipNames = @('Microsoft Edge', 'Google Chrome', 'Mozilla Firefox', 'Opera', 'Brave', 'Vivaldi')
    if ($skipNames -contains $name) { return $false }

    return $true
}

function Get-AppPriority {
    param([string]$AppName)

    $name = [string]::Empty
    if ($null -ne $AppName) { $name = $AppName.ToLowerInvariant() }

    if ($name -match '7-zip|git(hub)?|visual studio code|powershell|microsoft office|onedrive|teams|zoom|slack|discord|vnc|putty|winscp|adobe|vlc|steam|camtasia|obs|virtualbox|vmware|teamviewer|anydesk|notepad|paint|git bash|moba') {
        return 1
    }

    if ($name -match 'github desktop|microsoft 365|sql server|visual studio|docker|node\.js|python|jetbrains|winrar|winmerge|sumatrapdf|firefox|thunderbird') {
        return 2
    }

    return 3
}

function Get-AppCategory {
    param([string]$AppName)

    $name = [string]::Empty
    if ($null -ne $AppName) { $name = $AppName.ToLowerInvariant() }

    if ($name -match 'office|outlook|onenote|excel|word|powerpoint') { return 'Productivity' }
    if ($name -match 'visual studio|git|github|node|python|powershell|vscode|docker|jetbrains') { return 'Developer' }
    if ($name -match 'adobe|vlc|camtasia|obs|steam|discord|slack|zoom|teams') { return 'CommunicationMedia' }
    if ($name -match 'teamviewer|anydesk|winscp|putty|moba|remote') { return 'RemoteSupport' }
    if ($name -match 'onedrive|backup|sync') { return 'CloudSync' }
    return 'General'
}

function Get-DifferenceClass {
    param([psobject]$Result)

    if ($Result.Success) { return 'Matched' }
    if ($Result.Message -match 'no menu bar') { return 'NoMenuBar' }
    if ($Result.Message -match 'Help menu found but it contains no About item') { return 'HelpMenuNoAbout' }
    if ($Result.Message -match 'About command was invoked but no dialog appeared') { return 'AboutCommandNoDialog' }
    if ($Result.Message -match 'No Help/About menu entry') { return 'NoHelpAboutEntry' }
    return 'Other'
}

function Get-NextAction {
    param([psobject]$Result, [string]$AppName)

    switch (Get-DifferenceClass -Result $Result) {
        'Matched' { return 'No follow-up needed; capture the About dialog text for the report.' }
        'NoMenuBar' { return "Inspect the app's UIA tree for MenuBar/Menu/MenuItem patterns and Win32 HMENU. If it is Electron or Chromium-based, look for Application menu and MenuItem descendants inside the main window. Add a new branch for $AppName." }
        'HelpMenuNoAbout' { return "The app has a Help menu but no About entry. Inspect the submenu labels for alternate verbs such as 'About App', 'Version', 'Info', or 'License'. If none exist, treat this as 'no About entry available' and capture version from the app's executable metadata instead." }
        'AboutCommandNoDialog' { return "The menu command was invoked but no dialog appeared. Inspect the window tree for a modal dialog, embedded webview, or a custom About surface; then add a branch to handle that control pattern." }
        default { return "Record the raw result and inspect the UIA tree manually to determine whether the app uses a custom menu or dialog model." }
    }
}

function Get-DetectionRuleHint {
    param([psobject]$Result)

    switch (Get-DifferenceClass -Result $Result) {
        'Matched' { return 'Keep current rule set' }
        'NoMenuBar' { return 'Try UIA MenuBar/Menu first, then Win32 HMENU; if no menu is exposed, record as menu-not-exposed' }
        'HelpMenuNoAbout' { return 'Look for alternate About-like labels in Help submenu; if none exist, use version metadata fallback' }
        'AboutCommandNoDialog' { return 'Inspect for modal dialog, embedded window, or webview after invoking the Help/About command' }
        default { return 'Unknown pattern; add a manual inspection branch' }
    }
}

$uninstallEntries = foreach ($path in $registryPaths) {
    if (-not (Test-Path $path)) { continue }
    try {
        Get-ItemProperty $path -ErrorAction Stop | Where-Object {
            $_.DisplayName -and -not [string]::IsNullOrWhiteSpace($_.DisplayName)
        }
    } catch {
        continue
    }
}

$apps = @($uninstallEntries | Where-Object {
    $_.DisplayName -and ((-not (Get-Member -InputObject $_ -Name 'SystemComponent' -ErrorAction SilentlyContinue)) -or (-not $_.SystemComponent) -or $IncludeSystemApps) -and (Test-LikelyGuiApp -App $_)
} | ForEach-Object {
    $_ | Add-Member -NotePropertyName Priority -NotePropertyValue (Get-AppPriority -AppName ([string]$_.DisplayName)) -Force
    $_ | Add-Member -NotePropertyName Category -NotePropertyValue (Get-AppCategory -AppName ([string]$_.DisplayName)) -Force
    $_
} | Sort-Object Priority, DisplayName -Unique)

$appCount = [math]::Min($MaxApps, $apps.Count)
Write-Host "Discovered $($apps.Count) likely GUI applications; analyzing the first $appCount..."

for ($i = 0; $i -lt $appCount; $i++) {
    $app = $apps[$i]
    $appName = [string]$app.DisplayName
    $exeCandidates = @(Get-ExecutableCandidates -App $app)

    if ($exeCandidates.Count -eq 0) {
        $skipped.Add([pscustomobject]@{
            DisplayName = $appName
            Reason = 'No executable candidate found'
        })
        continue
    }

    $launchPath = $exeCandidates[0]
    if ($SkipLaunch) {
        $results.Add([pscustomobject]@{
            DisplayName = $appName
            Executable = $launchPath
            LaunchOutcome = 'Skipped'
            Success = $false
            Method = $null
            Message = 'Launch skipped by parameter'
            DifferenceClass = 'Skipped'
            NextAction = 'Launch the app and re-run analysis on a real machine.'
            DetectionRuleHint = 'SkipLaunch'
            VersionText = @()
        })
        continue
    }

    $proc = $null
    $launchOutcome = 'Unknown'
    $versionText = @()
    $result = $null

    try {
        $proc = Start-Process -FilePath $launchPath -PassThru
        if ($proc) { $launchOutcome = 'Started' }
    } catch {
        $launchOutcome = "LaunchFailed:$($_.Exception.Message)"
    }

    if ($proc -and $proc.Id) {
        Start-Sleep -Seconds 6
        try {
            $result = Invoke-AboutDialogAutomation -ApplicationName $appName -ProcessId $proc.Id
        } catch {
            $result = [pscustomobject]@{ Success = $false; Method = $null; Message = $_.Exception.Message }
        }

        if ($result -and $result.DialogText) { $versionText = @($result.DialogText) }

        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        } catch {
            # leave process alone if it cannot be stopped cleanly
        }
    } else {
        $result = [pscustomobject]@{ Success = $false; Method = $null; Message = 'Unable to start the application' }
    }

    $results.Add([pscustomobject]@{
        DisplayName = $appName
        Executable = $launchPath
        Priority = $app.Priority
        Category = $app.Category
        LaunchOutcome = $launchOutcome
        Success = if ($result) { $result.Success } else { $false }
        Method = if ($result) { $result.Method } else { $null }
        Message = if ($result) { $result.Message } else { $null }
        DifferenceClass = Get-DifferenceClass -Result $result
        NextAction = Get-NextAction -Result $result -AppName $appName
        DetectionRuleHint = Get-DetectionRuleHint -Result $result
        VersionText = $versionText
    })

    Write-Host ("[{0}/{1}] {2} -> {3}" -f ($i + 1), $appCount, $appName, $launchOutcome)
}

$summaryPath = Join-Path $OutputRoot 'app-detection-analysis.json'
$csvPath = Join-Path $OutputRoot 'app-detection-analysis.csv'
$skippedPath = Join-Path $OutputRoot 'app-detection-skipped.csv'
$summaryTextPath = Join-Path $OutputRoot 'app-detection-summary.txt'

$results | ConvertTo-Json -Depth 6 | Set-Content -Path $summaryPath -Encoding UTF8
$results | Select-Object DisplayName, Executable, Priority, Category, LaunchOutcome, Success, Method, DifferenceClass, DetectionRuleHint, Message, @{Name='VersionText';Expression={($_.VersionText -join ' | ')}} | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
$skipped | Select-Object DisplayName, Reason | Export-Csv -Path $skippedPath -NoTypeInformation -Encoding UTF8

$counts = $results | Group-Object DifferenceClass | Sort-Object Count -Descending
$topPriority = @($results | Where-Object {
    $priority = $null
    if (Get-Member -InputObject $_ -Name 'Priority' -ErrorAction SilentlyContinue) { $priority = $_.Priority }
    ($null -ne $priority) -and ($priority -eq 1)
} | Select-Object -First 20 DisplayName, Category, DifferenceClass, Message)
$nextActions = @($results | Where-Object { $_.DifferenceClass -ne 'Matched' } | Select-Object -First 20 DisplayName, DifferenceClass, NextAction)

$summaryLines = New-Object System.Collections.Generic.List[string]
$summaryLines.Add('Application Detection Analysis Summary')
$summaryLines.Add('====================================')
$summaryLines.Add("Analyzed apps: $($results.Count)")
$summaryLines.Add("Skipped apps: $($skipped.Count)")
$summaryLines.Add('')
$summaryLines.Add('Difference class counts:')
foreach ($group in $counts) {
    $summaryLines.Add("- $($group.Name): $($group.Count)")
}
$summaryLines.Add('')
$summaryLines.Add('Highest-priority apps to review first:')
foreach ($row in $topPriority) {
    $summaryLines.Add("- $($row.DisplayName) [$($row.Category)] -> $($row.DifferenceClass)")
}
$summaryLines.Add('')
$summaryLines.Add('Suggested next actions:')
foreach ($row in $nextActions) {
    $summaryLines.Add("- $($row.DisplayName): $($row.NextAction)")
}
$summaryLines.Add('')
$summaryLines.Add('Use the CSV/JSON outputs to feed a follow-on pass or to hand this workload to a technician with minimal effort.')
[System.IO.File]::WriteAllLines($summaryTextPath, $summaryLines)

Write-Host "Results written to $summaryPath"
Write-Host "CSV written to $csvPath"
Write-Host "Skipped entries written to $skippedPath"
Write-Host "Summary text written to $summaryTextPath"
