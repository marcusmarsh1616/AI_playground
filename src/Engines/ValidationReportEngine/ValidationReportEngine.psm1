#Requires -Version 5.1
<#
.SYNOPSIS
    Validation Report Engine
.DESCRIPTION
    Runs integrated validation documentation capture and saves the generated report to a package docs folder.
#>

function Start-ValidationReportCapture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackagePath,

        [Parameter(Mandatory = $true)]
        [string]$AppVendor,

        [Parameter(Mandatory = $true)]
        [string]$AppName,

        [Parameter(Mandatory = $false)]
        [string]$AppEdition,

        [Parameter(Mandatory = $true)]
        [string]$AppVersion
    )

    $result = @{
        Success = $false
        Launched = $false
        ReportCopied = $false
        CopiedReportPath = ""
        Message = ""
    }

    try {
        $engineRoot = $PSScriptRoot
        $launcherPath = Join-Path $engineRoot "Start-DocumentationCaptureTool.ps1"
        $outputFolder = Join-Path $engineRoot "documentation"

        if (-not (Test-Path $launcherPath)) {
            $result.Message = "Validation documentation launcher not found: $launcherPath"
            return $result
        }

        $startTime = Get-Date
        $resultFilePath = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName() + '.json')

        $argList = @(
            "-NoProfile",
            "-STA",
            "-ExecutionPolicy", "Bypass",
            "-File", $launcherPath,
            "-AppName", $AppName,
            "-AppVersion", $AppVersion,
            "-Interactive",
            "-ResultFilePath", $resultFilePath
        )

        $docProcess = Start-Process -FilePath "powershell.exe" -ArgumentList $argList -WorkingDirectory $engineRoot -PassThru
        $result.Launched = $true
        $null = $docProcess.WaitForExit()

        $launcherResult = $null
        if (Test-Path $resultFilePath) {
            try {
                $launcherResult = Get-Content -Path $resultFilePath -Raw -Encoding UTF8 | ConvertFrom-Json
            }
            catch {
                $launcherResult = $null
            }
            Remove-Item -Path $resultFilePath -Force -ErrorAction SilentlyContinue
        }

        $sourceReportPath = ""
        if ($launcherResult -and $launcherResult.PSObject.Properties.Name -contains 'OutputPath' -and -not [string]::IsNullOrWhiteSpace([string]$launcherResult.OutputPath)) {
            $candidateOutputPath = [string]$launcherResult.OutputPath
            $candidatePaths = @($candidateOutputPath)

            if (-not [System.IO.Path]::IsPathRooted($candidateOutputPath)) {
                $candidatePaths += (Join-Path $engineRoot $candidateOutputPath)
                $candidatePaths += (Join-Path (Split-Path $launcherPath -Parent) $candidateOutputPath)
            }

            foreach ($candidatePath in ($candidatePaths | Select-Object -Unique)) {
                if (Test-Path $candidatePath) {
                    $sourceReportPath = (Resolve-Path $candidatePath).Path
                    break
                }
            }
        }

        if ([string]::IsNullOrWhiteSpace($sourceReportPath)) {
            $outputFoldersToProbe = @(
                $outputFolder,
                (Join-Path (Split-Path $launcherPath -Parent) "documentation"),
                (Join-Path (Get-Location).Path "documentation")
            ) | Select-Object -Unique

            $resolvedOutputFolder = ""
            foreach ($candidateFolder in $outputFoldersToProbe) {
                if (Test-Path $candidateFolder) {
                    $resolvedOutputFolder = (Resolve-Path $candidateFolder).Path
                    break
                }
            }

            if ([string]::IsNullOrWhiteSpace($resolvedOutputFolder)) {
                $result.Success = $true
                if ($launcherResult -and $launcherResult.Message) {
                    $result.Message = "Validation tool completed: $($launcherResult.Message)"
                }
                else {
                    $result.Message = "Validation tool closed. Documentation output folder was not found."
                }
                return $result
            }

            $latestReport = Get-ChildItem -Path $resolvedOutputFolder -Filter "*.html" -File -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -ge $startTime } |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1

            if (-not $latestReport) {
                $latestReport = Get-ChildItem -Path $resolvedOutputFolder -Filter "*.html" -File -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1
            }

            if (-not $latestReport) {
                $result.Success = $true
                if ($launcherResult -and $launcherResult.Message) {
                    $result.Message = "Validation tool completed: $($launcherResult.Message)"
                }
                else {
                    $result.Message = "Validation tool closed. No report file was found to copy."
                }
                return $result
            }

            $sourceReportPath = $latestReport.FullName
        }

        if ($docProcess.ExitCode -ne 0) {
            if ([string]::IsNullOrWhiteSpace($sourceReportPath)) {
                if ($launcherResult -and $launcherResult.Message) {
                    $result.Message = "Validation documentation tool failed: $($launcherResult.Message)"
                }
                else {
                    $result.Message = "Validation documentation tool exited with code $($docProcess.ExitCode)."
                }
                return $result
            }
        }

        if ($launcherResult -and $launcherResult.PSObject.Properties.Name -contains 'Success' -and -not $launcherResult.Success -and [string]::IsNullOrWhiteSpace($sourceReportPath)) {
            $result.Message = if ($launcherResult.Message) { "Validation documentation tool failed: $($launcherResult.Message)" } else { "Validation documentation tool reported failure." }
            return $result
        }

        $docsFolder = Join-Path $PackagePath "docs"
        if (-not (Test-Path $docsFolder)) {
            New-Item -Path $docsFolder -ItemType Directory -Force | Out-Null
        }

        $nameParts = @($AppVendor, $AppName)
        if (-not [string]::IsNullOrWhiteSpace($AppEdition)) {
            $nameParts += $AppEdition
        }
        $nameParts += $AppVersion

        $reportFileName = (($nameParts -join " ") + " Validation report.html")
        $reportFileName = $reportFileName -replace '[<>:"/\\|?*]', '_'

        $targetReportPath = Join-Path $docsFolder $reportFileName
        Copy-Item -Path $sourceReportPath -Destination $targetReportPath -Force

        try {
            Start-Process -FilePath $targetReportPath | Out-Null
        }
        catch {
            # Non-fatal: report is still generated and copied successfully.
        }

        $result.ReportCopied = $true
        $result.CopiedReportPath = $targetReportPath
        $result.Success = $true
        if ($docProcess.ExitCode -ne 0) {
            $result.Message = "Validation report saved to package docs: $reportFileName (launcher exit code $($docProcess.ExitCode) ignored because report was generated)."
        }
        else {
            $result.Message = "Validation report saved to package docs: $reportFileName"
        }
    }
    catch {
        $result.Message = "Validation report engine error: $($_.Exception.Message)"
    }

    return $result
}

Export-ModuleMember -Function Start-ValidationReportCapture
