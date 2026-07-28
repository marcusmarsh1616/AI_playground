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
        $uiEnginePath = Join-Path $engineRoot "src\DocumentationUIEngine.psm1"
        $outputFolder = Join-Path $engineRoot "documentation"

        if (-not (Test-Path $uiEnginePath)) {
            $result.Message = "Validation documentation UI engine not found: $uiEnginePath"
            return $result
        }

        $startTime = Get-Date
        $launcherResult = $null
        $previousLocation = Get-Location
        try {
            Push-Location $engineRoot
            Import-Module $uiEnginePath -Force -ErrorAction Stop
            $result.Launched = $true
            $launcherResult = Invoke-DocumentationCaptureFromContext -AppName $AppName -AppVersion $AppVersion
        }
        finally {
            Pop-Location
        }

        $sourceReportPath = ""
        if ($launcherResult -and $launcherResult.PSObject.Properties.Name -contains 'OutputPath' -and -not [string]::IsNullOrWhiteSpace([string]$launcherResult.OutputPath)) {
            $candidateOutputPath = [string]$launcherResult.OutputPath
            $candidatePaths = @($candidateOutputPath)

            if (-not [System.IO.Path]::IsPathRooted($candidateOutputPath)) {
                $candidatePaths += (Join-Path $engineRoot $candidateOutputPath)
                $candidatePaths += (Join-Path $previousLocation.Path $candidateOutputPath)
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
                (Join-Path $previousLocation.Path "documentation")
            ) | Select-Object -Unique

            $resolvedOutputFolder = ""
            foreach ($candidateFolder in $outputFoldersToProbe) {
                if (Test-Path $candidateFolder) {
                    $resolvedOutputFolder = (Resolve-Path $candidateFolder).Path
                    break
                }
            }

            if ([string]::IsNullOrWhiteSpace($resolvedOutputFolder)) {
                $result.Message = "Validation tool did not produce a documentation output folder."
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
                $result.Message = "Validation tool closed without generating a report file."
                return $result
            }

            $sourceReportPath = $latestReport.FullName
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
        $result.Message = "Validation report saved to package docs: $reportFileName"
    }
    catch {
        $result.Message = "Validation report engine error: $($_.Exception.Message)"
    }

    return $result
}

Export-ModuleMember -Function Start-ValidationReportCapture
