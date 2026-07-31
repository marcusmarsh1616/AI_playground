#Requires -Version 5.1
<#
.SYNOPSIS
    Installation Validation Report - Main Entry Point with Session Management

.DESCRIPTION
    Orchestrates the complete validation workflow:
    1. Initializes session tracking
    2. Analyzes application installer
    3. Researches requirements via Python/Playwright
    4. Generates comprehensive HTML validation report
    5. Logs session results

.PARAMETER InstallerPath
    Path to application installer (MSI, EXE, etc.)

.PARAMETER ApplicationName
    Name of the application (optional if can be extracted)

.PARAMETER Version
    Version of the application (optional if can be extracted)

.PARAMETER OutputPath
    Path for generated validation report

.PARAMETER SkipWebResearch
    Skip automated web research (use installer analysis only)

.PARAMETER NoSession
    Skip session tracking

.EXAMPLE
    .\Start-ValidationResearch.ps1 -InstallerPath "C:\Installers\Snagit.exe"

.EXAMPLE
    .\Start-ValidationResearch.ps1 -ApplicationName "Adobe Acrobat DC" -Version "2024"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$InstallerPath,
    
    [Parameter(Mandatory=$false)]
    [string]$ApplicationName,
    
    [Parameter(Mandatory=$false)]
    [string]$Version,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\Reports",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipWebResearch,
    
    [Parameter(Mandatory=$false)]
    [switch]$NoSession
)

# Script root
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptRoot

# Load report generator script so its function is available
. (Join-Path $scriptRoot "New-ValidationReport.ps1")

# Import modules
Import-Module (Join-Path $scriptRoot "Modules\InstallerAnalysis.psm1") -Force
Import-Module (Join-Path $scriptRoot "Modules\CacheManagement.psm1") -Force
Import-Module (Join-Path $scriptRoot "Modules\SessionManagement.psm1") -Force

Write-Host "[START] Installation Validation Research" -ForegroundColor Cyan
Write-Host "========================================"

# Initialize session tracking
$session = $null
$errors = @()
$metrics = @{
    installer_analysis_time = 0
    web_research_time = 0
    report_generation_time = 0
    cache_hit = $false
    research_method = 'none'
}

if (-not $NoSession) {
    # Will initialize session once we know application name
}

# Phase 1: Analyze Installer (if provided)
$installerData = $null
if ($InstallerPath) {
    Write-Host "`n[PHASE 1] Analyzing Installer" -ForegroundColor Yellow
    
    if (-not (Test-Path $InstallerPath)) {
        $errorMsg = "Installer not found: $InstallerPath"
        Write-Host "[ERROR] $errorMsg" -ForegroundColor Red
        $errors += $errorMsg
        
        # Save failed session if possible
        if ($session -and -not $NoSession) {
            Save-ValidationSession -Session $session -Success $false -Errors $errors -Metrics $metrics | Out-Null
        }
        exit 1
    }
    
    $startTime = Get-Date
    try {
        $installerData = Invoke-InstallerAnalysis -Path $InstallerPath
        $metrics.installer_analysis_time = ((Get-Date) - $startTime).TotalSeconds
        
        # Extract app name/version if not provided
        if (-not $ApplicationName) {
            $ApplicationName = $installerData.ProductName
            Write-Host "[INFO] Detected application: $ApplicationName"
        }
        
        if (-not $Version) {
            $Version = $installerData.ProductVersion
            Write-Host "[INFO] Detected version: $Version"
        }
    } catch {
        $errorMsg = "Installer analysis failed: $($_.Exception.Message)"
        Write-Host "[ERROR] $errorMsg" -ForegroundColor Red
        $errors += $errorMsg
    }
}

# Verify we have application name
if (-not $ApplicationName) {
    $errorMsg = "Application name required (use -ApplicationName parameter)"
    Write-Host "[ERROR] $errorMsg" -ForegroundColor Red
    $errors += $errorMsg
    exit 1
}

# Initialize session now that we have application name
if (-not $NoSession) {
    $session = Start-ValidationSession -ApplicationName $ApplicationName -Version $Version -InstallerPath $InstallerPath
}

# Phase 2: Web Research (if enabled)
$webResearchData = $null
if (-not $SkipWebResearch) {
    Write-Host "`n[PHASE 2] Researching Requirements" -ForegroundColor Yellow
    
    $startTime = Get-Date
    try {
        $webResearchData = Invoke-WebResearch -ApplicationName $ApplicationName -Version $Version
        $metrics.web_research_time = ((Get-Date) - $startTime).TotalSeconds
        
        if ($webResearchData.success) {
            Write-Host "[SUCCESS] Requirements research complete" -ForegroundColor Green
            
            $metrics.cache_hit = $webResearchData.cached
            $metrics.research_method = $webResearchData.research_method
            
            if ($webResearchData.cached) {
                Write-Host "[INFO] Data from cache" -ForegroundColor Cyan
            } else {
                Write-Host "[INFO] Data from: $($webResearchData.research_method)" -ForegroundColor Cyan
            }
        } else {
            $errorMsg = "Web research failed: $($webResearchData.error)"
            Write-Host "[WARNING] $errorMsg" -ForegroundColor Yellow
            Write-Host "[INFO] Continuing with installer analysis only"
            $errors += $errorMsg
        }
    } catch {
        $errorMsg = "Web research error: $($_.Exception.Message)"
        Write-Host "[ERROR] $errorMsg" -ForegroundColor Red
        $errors += $errorMsg
    }
} else {
    Write-Host "`n[PHASE 2] Web Research Skipped" -ForegroundColor Yellow
    $metrics.research_method = 'skipped'
}

# Phase 3: Generate Report
Write-Host "`n[PHASE 3] Generating Validation Report" -ForegroundColor Yellow

$reportPath = $null
$startTime = Get-Date
try {
    $reportData = @{
        Application = $ApplicationName
        Version = $Version
        InstallerAnalysis = $installerData
        WebResearch = $webResearchData
        GeneratedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        GeneratedBy = $env:USERNAME
    }

    $reportPath = New-ValidationReport -Data $reportData -OutputPath $OutputPath
    $metrics.report_generation_time = ((Get-Date) - $startTime).TotalSeconds
    
    Write-Host "`n[COMPLETE] Validation report generated" -ForegroundColor Green
    Write-Host "[REPORT] $reportPath" -ForegroundColor Cyan
} catch {
    $errorMsg = "Report generation failed: $($_.Exception.Message)"
    Write-Host "[ERROR] $errorMsg" -ForegroundColor Red
    $errors += $errorMsg
}

# Save session
if ($session -and -not $NoSession) {
    $success = ($errors.Count -eq 0)
    $sessionFile = Save-ValidationSession -Session $session -Success $success -Errors $errors -Metrics $metrics -ReportPath $reportPath
    Write-Host "[SESSION] Logged to: $sessionFile" -ForegroundColor Cyan
}

# Display metrics
Write-Host "`n[METRICS]" -ForegroundColor Yellow
Write-Host "  Installer Analysis: $($metrics.installer_analysis_time) seconds"
Write-Host "  Web Research: $($metrics.web_research_time) seconds"
Write-Host "  Report Generation: $($metrics.report_generation_time) seconds"
$totalTime = $metrics.installer_analysis_time + $metrics.web_research_time + $metrics.report_generation_time
Write-Host "  Total Time: $totalTime seconds"
if ($metrics.cache_hit) {
    Write-Host "  Cache: HIT" -ForegroundColor Green
} else {
    Write-Host "  Cache: MISS" -ForegroundColor Yellow
}

# Open report
if ($reportPath) {
    $openReport = Read-Host "`nOpen report in browser? (Y/N)"
    if ($openReport -eq 'Y') {
        Start-Process $reportPath
    }
}

# Exit with appropriate code
if ($errors.Count -gt 0) {
    Write-Host "`n[WARNING] Completed with $($errors.Count) error(s)" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "`n[SUCCESS] Validation complete" -ForegroundColor Green
    exit 0
}
