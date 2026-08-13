#Requires -Version 5.1

<##
.SYNOPSIS
    PythonScraperEngine - Direct Python Playwright integration for Package Helper.
.DESCRIPTION
    Runs the co-located scraper.py with in-memory JSON config and returns parsed results.
##>

function Test-PythonScraperPrerequisites {
    [CmdletBinding()]
    param()

    $result = [ordered]@{
        Success = $false
        Error = ""
        PythonPath = ""
        ScraperPath = ""
    }

    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if (-not $pythonCmd) {
        $result.Error = "Python command was not found on PATH."
        return $result
    }

    $scraperPath = Join-Path $PSScriptRoot "scraper.py"
    if (-not (Test-Path $scraperPath)) {
        $result.Error = "Python scraper engine file was not found: $scraperPath"
        return $result
    }

    try {
        & $pythonCmd.Source -c "import playwright" 2>$null
        if ($LASTEXITCODE -ne 0) {
            $result.Error = "Python is available but Playwright module is not installed in that environment."
            return $result
        }
    }
    catch {
        $result.Error = "Playwright import precheck failed: $($_.Exception.Message)"
        return $result
    }

    $result.Success = $true
    $result.PythonPath = $pythonCmd.Source
    $result.ScraperPath = $scraperPath
    return $result
}

function Invoke-PythonScraperForPackageHelper {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallMediaPath,

        [string]$AppName = "",
        [string]$Vendor = "",
        [string]$Version = "",

        [int]$TimeoutSeconds = 30,
        [int]$MaxResultsPerSite = 12,

        # Optional callback invoked immediately for each stderr progress line
        # as the scraper produces it (scraper.py prints step-by-step [INFO]/
        # [STEP]/[ERROR] lines to stderr in real time). Lets callers stream
        # live progress instead of only seeing output after the process exits.
        [scriptblock]$OnOutputLine = $null
    )

    $result = [ordered]@{
        Success = $false
        Error = ""
        DurationSeconds = 0
        Results = @()
        StderrLines = @()
        Diagnostics = @{}
    }

    if ([string]::IsNullOrWhiteSpace($InstallMediaPath) -or -not (Test-Path $InstallMediaPath)) {
        $result.Error = "Installer media path is missing or not accessible."
        return $result
    }

    $precheck = Test-PythonScraperPrerequisites
    if (-not $precheck.Success) {
        $result.Error = $precheck.Error
        $result.Diagnostics = @{ Precheck = $precheck }
        return $result
    }

    $safeAppName = if ([string]::IsNullOrWhiteSpace($AppName)) { "application" } else { $AppName.Trim() }
    $safeVendor = if ([string]::IsNullOrWhiteSpace($Vendor)) { "" } else { $Vendor.Trim() }
    $safeVersion = if ([string]::IsNullOrWhiteSpace($Version)) { "" } else { $Version.Trim() }

    $appSlug = (($safeAppName -replace '[^a-zA-Z0-9]+', '-') -replace '^-|-$', '').ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($appSlug)) {
        $appSlug = "application"
    }

    $searchTerms = @(
        "$safeAppName silent install",
        "$safeAppName command line switches",
        "$safeAppName unattended install",
        "$safeAppName uninstall",
        "$safeAppName powershell deployment",
        "msiexec /i /qn",
        "msiexec /x /qn",
        "Execute-Process",
        "Execute-MSI"
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

    if (-not [string]::IsNullOrWhiteSpace($safeVendor)) {
        $searchTerms += "$safeVendor $safeAppName silent"
    }
    if (-not [string]::IsNullOrWhiteSpace($safeVersion)) {
        $searchTerms += "$safeAppName $safeVersion silent install"
    }

    $config = [ordered]@{
        target_application = $safeAppName
        version = $safeVersion
        vendor = $safeVendor
        installer_path = $InstallMediaPath
        search_terms = @($searchTerms | Select-Object -First 20)
        target_websites = @(
            @{ name = "Silent Install HQ Search"; url = "https://silentinstallhq.com/?s=$([uri]::EscapeDataString($safeAppName))"; priority = 1; search_enabled = $true },
            @{ name = "Chocolatey Package"; url = "https://community.chocolatey.org/packages/$appSlug"; priority = 2; search_enabled = $true },
            @{ name = "ITNinja Search"; url = "https://www.itninja.com/search?query=$([uri]::EscapeDataString($safeAppName))"; priority = 3; search_enabled = $true },
            @{ name = "Vendor Support Search"; url = "https://duckduckgo.com/html/?q=$([uri]::EscapeDataString("$safeVendor $safeAppName silent install"))"; priority = 4; search_enabled = $true }
        )
        scraping_config = @{
            timeout_seconds = $TimeoutSeconds
            max_results_per_site = $MaxResultsPerSite
            headless = $true
            user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
            follow_secondary_links = $true
            max_secondary_pages = 4
            max_candidates_per_page = 30
            min_confidence = 0.30
            include_page_text_fallback = $true
        }
    }

    $configJson = $config | ConvertTo-Json -Depth 10 -Compress

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # Accumulators shared with the async event handlers below. These are
    # PowerShell collections captured by reference into the event action
    # scriptblocks via -MessageData, since event handlers run on a separate
    # thread and can't close over local variables directly.
    $stdoutBuilder = New-Object System.Text.StringBuilder
    $stderrLinesList = New-Object System.Collections.Generic.List[string]

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $precheck.PythonPath
        $psi.Arguments = '"' + $precheck.ScraperPath + '"'
        $psi.UseShellExecute = $false
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        $proc.EnableRaisingEvents = $true

        $outputHandlerState = [PSCustomObject]@{
            StdoutBuilder = $stdoutBuilder
        }
        $errorHandlerState = [PSCustomObject]@{
            StderrLines = $stderrLinesList
            OnOutputLine = $OnOutputLine
        }

        $outputAction = {
            param($sender, $e)
            if ($null -ne $e.Data) {
                [void]$Event.MessageData.StdoutBuilder.AppendLine($e.Data)
            }
        }
        $errorAction = {
            param($sender, $e)
            if ($null -ne $e.Data -and -not [string]::IsNullOrWhiteSpace($e.Data)) {
                [void]$Event.MessageData.StderrLines.Add($e.Data)
                if ($Event.MessageData.OnOutputLine) {
                    try {
                        & $Event.MessageData.OnOutputLine $e.Data
                    }
                    catch {
                        # Never let a callback failure break the scrape itself.
                    }
                }
            }
        }

        $outputSub = Register-ObjectEvent -InputObject $proc -EventName OutputDataReceived -Action $outputAction -MessageData $outputHandlerState
        $errorSub = Register-ObjectEvent -InputObject $proc -EventName ErrorDataReceived -Action $errorAction -MessageData $errorHandlerState

        try {
            [void]$proc.Start()
            $proc.BeginOutputReadLine()
            $proc.BeginErrorReadLine()

            $proc.StandardInput.Write($configJson)
            $proc.StandardInput.Close()

            # Poll rather than block on WaitForExit(): a blocking wait on this
            # thread prevents PowerShell from pumping the queued
            # OutputDataReceived/ErrorDataReceived events until the process
            # has already exited, which defeats live streaming entirely.
            while (-not $proc.HasExited) {
                Start-Sleep -Milliseconds 100
            }

            # Drain any events still queued immediately after exit.
            Start-Sleep -Milliseconds 100
        }
        finally {
            Unregister-Event -SourceIdentifier $outputSub.Name -ErrorAction SilentlyContinue
            Unregister-Event -SourceIdentifier $errorSub.Name -ErrorAction SilentlyContinue
            Remove-Job -Job $outputSub -Force -ErrorAction SilentlyContinue
            Remove-Job -Job $errorSub -Force -ErrorAction SilentlyContinue
        }

        $stopwatch.Stop()
        $result.DurationSeconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 2)

        $stdout = $stdoutBuilder.ToString()
        $stderrLines = @($stderrLinesList)

        $result.StderrLines = $stderrLines
        $result.Diagnostics = @{ Precheck = $precheck; ExitCode = $proc.ExitCode }

        if ($proc.ExitCode -ne 0) {
            $tail = @($stderrLines | Select-Object -Last 3) -join " | "
            $result.Error = "Integrated Python scraper exited with code $($proc.ExitCode). $tail"
            return $result
        }

        if ([string]::IsNullOrWhiteSpace($stdout)) {
            $result.Error = "Integrated Python scraper returned no JSON output."
            return $result
        }

        $parsed = $stdout | ConvertFrom-Json -ErrorAction Stop
        $result.Results = @($parsed)
        $result.Success = $true
        return $result
    }
    catch {
        $stopwatch.Stop()
        $result.DurationSeconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
        $result.Error = "Integrated Python scraper execution failed: $($_.Exception.Message)"
        return $result
    }
}

Export-ModuleMember -Function Test-PythonScraperPrerequisites, Invoke-PythonScraperForPackageHelper
