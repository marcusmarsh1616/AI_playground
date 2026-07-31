# INTERNAL FR/OFFICIAL USE // FRSONLY
#Requires -Version 5.1

<#
.SYNOPSIS
    Extract installer metadata for version-specific scraping
.DESCRIPTION
    Reads installer file properties to get exact version, product name
    Creates search queries based on actual installer version
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$InstallerPath
)

function Get-InstallerMetadata {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        Write-Host "[ERROR] Installer not found: $Path" -ForegroundColor Red
        return $null
    }
    
    try {
        $file = Get-Item $Path
        $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path)
        
        $metadata = @{
            FileName = $file.Name
            FullPath = $file.FullName
            FileSize = $file.Length
            ProductName = $versionInfo.ProductName
            ProductVersion = $versionInfo.ProductVersion
            FileVersion = $versionInfo.FileVersion
            CompanyName = $versionInfo.CompanyName
            FileDescription = $versionInfo.FileDescription
            InternalName = $versionInfo.InternalName
            OriginalFilename = $versionInfo.OriginalFilename
        }
        
        return $metadata
    } catch {
        Write-Host "[ERROR] Failed to extract metadata: $_" -ForegroundColor Red
        return $null
    }
}

function Build-VersionAwareConfig {
    param($Metadata)
    
    $productName = $Metadata.ProductName
    $version = $Metadata.ProductVersion
    $vendor = $Metadata.CompanyName
    
    # Build version-specific search terms
    $searchTerms = @(
        "$productName $version silent install"
        "$productName $version command line"
        "$productName $version deployment"
        "$productName $version switches"
        "$productName $version uninstall"
        "$productName $version msi"
        "$productName silent"
        "/s"
        "/quiet"
        "command line switches"
    )
    
    # Build version-specific URLs
    $urls = @(
        "https://support.techsmith.com/hc/en-us/search?query=$productName+$version+silent+install"
        "https://support.techsmith.com/hc/en-us/search?query=$productName+deployment"
        "https://support.techsmith.com/hc/en-us/articles/203731148"
    )
    
    $config = @{
        target_application = $productName
        version = $version
        vendor = $vendor
        installer_path = $Metadata.FullPath
        installer_filename = $Metadata.FileName
        search_terms = $searchTerms
        target_websites = @(
            @{
                name = "$productName $version Documentation"
                url = $urls[0]
                priority = 1
                search_enabled = $true
            }
            @{
                name = "$productName Deployment Guide"
                url = $urls[1]
                priority = 2
                search_enabled = $true
            }
            @{
                name = "TechSmith Mass Deployment"
                url = $urls[2]
                priority = 3
                search_enabled = $true
            }
        )
        scraping_config = @{
            timeout_seconds = 30
            max_results_per_site = 10
            headless = $true
            user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        }
    }
    
    return $config
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installer Metadata Extractor" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Extracting metadata from installer..." -ForegroundColor Cyan
$metadata = Get-InstallerMetadata -Path $InstallerPath

if ($null -eq $metadata) {
    exit 1
}

Write-Host "[SUCCESS] Metadata extracted" -ForegroundColor Green
Write-Host ""
Write-Host "Installer Details:" -ForegroundColor Yellow
Write-Host "  Product: $($metadata.ProductName)" -ForegroundColor White
Write-Host "  Version: $($metadata.ProductVersion)" -ForegroundColor White
Write-Host "  Vendor: $($metadata.CompanyName)" -ForegroundColor White
Write-Host "  File: $($metadata.FileName)" -ForegroundColor White
Write-Host ""

Write-Host "Building version-specific scraping configuration..." -ForegroundColor Cyan
$config = Build-VersionAwareConfig -Metadata $metadata

Write-Host "[SUCCESS] Configuration built" -ForegroundColor Green
Write-Host ""
Write-Host "Search Terms (Version-Specific):" -ForegroundColor Yellow
foreach ($term in $config.search_terms) {
    Write-Host "  - $term" -ForegroundColor Gray
}
Write-Host ""

Write-Host "Target URLs:" -ForegroundColor Yellow
foreach ($site in $config.target_websites) {
    Write-Host "  - $($site.name)" -ForegroundColor White
    Write-Host "    $($site.url)" -ForegroundColor Gray
}
Write-Host ""

# Save config
$configPath = "C:\Temp\AI_Tools\Playwright_Scraping_POC\config.json"
$config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8

Write-Host "[SUCCESS] Configuration saved to config.json" -ForegroundColor Green
Write-Host ""
Write-Host "Next step: Run .\Test-Scraper.ps1" -ForegroundColor Cyan
