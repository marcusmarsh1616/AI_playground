# INTERNAL FR/OFFICIAL USE // FRSONLY
#Requires -Version 5.1

<#
.SYNOPSIS
    Version-aware web scraping for Package Helper suggestions
.DESCRIPTION
    Extracts version from installer, builds version-specific config, scrapes documentation
    All-in-one tool - just provide installer path
.PARAMETER InstallerPath
    Path to the installer EXE/MSI
.EXAMPLE
    .\Test-Scraper.ps1 -InstallerPath "C:\Users\P1MAM08\Downloads\camtasia.exe"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$InstallerPath
)

$ErrorActionPreference = "Continue"
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content "$ScriptPath\logs\scraper.log" $logMessage
}

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
            ProductName = $versionInfo.ProductName
            ProductVersion = $versionInfo.ProductVersion
            CompanyName = $versionInfo.CompanyName
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
    
    # Search terms for content extraction
    $searchTerms = @(
        "silent"
        "install"
        "command line"
        "switches"
        "/s"
        "/quiet"
        "unattended"
        "deployment"
        "sccm"
        "intune"
        "powershell"
        "msiexec"
        "uninstall"
        "mst"
        "transform"
    )
    
    $config = @{
        target_application = $productName
        version = $version
        vendor = $vendor
        installer_path = $Metadata.FullPath
        search_terms = $searchTerms
        target_websites = @(
            @{
                name = "TechSmith - Camtasia Silent Install"
                url = "https://support.techsmith.com/hc/en-us/articles/203731008-Camtasia-Silent-Installation"
                priority = 1
                search_enabled = $true
            }
            @{
                name = "TechSmith - MSI Deployment Guide"
                url = "https://support.techsmith.com/hc/en-us/articles/115005442063-Deploy-Camtasia-via-MSI"
                priority = 2
                search_enabled = $true
            }
            @{
                name = "Silent Install HQ - Camtasia"
                url = "https://silentinstallhq.com/camtasia-silent-install/"
                priority = 3
                search_enabled = $true
            }
            @{
                name = "Chocolatey - Camtasia Package"
                url = "https://community.chocolatey.org/packages/camtasia"
                priority = 4
                search_enabled = $true
            }
            @{
                name = "ITNinja - Camtasia Software Page"
                url = "https://www.itninja.com/software/techsmith/camtasia"
                priority = 5
                search_enabled = $true
            }
            @{
                name = "AppDeploy - Camtasia Repackaging"
                url = "https://www.appdeploy.com/packages/detail.asp?id=2896"
                priority = 6
                search_enabled = $true
            }
        )
        scraping_config = @{
            timeout_seconds = 30
            max_results_per_site = 10
            headless = $true
            user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
            follow_secondary_links = $true
            max_secondary_pages = 4
            max_candidates_per_page = 30
            min_confidence = 0.30
            include_page_text_fallback = $true
        }
    }
    
    return $config
}
function Test-Prerequisites {
    Write-Host "[1/3] Checking Python..." -ForegroundColor Cyan
    $pythonVersion = python --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    [FAIL] Python not found" -ForegroundColor Red
        return $false
    }
    Write-Host "    [PASS] $pythonVersion" -ForegroundColor Green
    
    Write-Host "[2/3] Checking Microsoft Edge..." -ForegroundColor Cyan
    $edgePath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    if (Test-Path $edgePath) {
        Write-Host "    [PASS] Microsoft Edge found" -ForegroundColor Green
    } else {
        Write-Host "    [WARN] Edge not found at expected location" -ForegroundColor Yellow
    }
    
    Write-Host "[3/3] Checking Playwright library..." -ForegroundColor Cyan
    $playwrightCheck = python -c "import playwright; print('installed')" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    [PASS] Playwright is installed" -ForegroundColor Green
        Write-Host ""
        return $true
    }
    
    Write-Host "    [MISSING] Playwright library not installed" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Run: .\Install-Playwright.ps1" -ForegroundColor Yellow
    return $false
}

function Invoke-Scraper {
    param([string]$ConfigJson)
    
    $scraperPath = Join-Path $ScriptPath "scraper.py"
    $output = $ConfigJson | python $scraperPath
    
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Scraper completed successfully"
        return $output | ConvertFrom-Json
    } else {
        Write-Log "Scraper failed with exit code: $LASTEXITCODE" "ERROR"
        return $null
    }
}

function Get-FallbackSuggestions {
    param(
        [int]$SectionNumber,
        [string]$AppName
    )

    switch ($SectionNumber) {
        2 {
            return @(
                @{Text="$AppName.exe /S"; Context="Template fallback for common EXE silent install"; Source="Local Template"; Confidence=0.30; WhySelected="fallback_template"; SourceType="template"},
                @{Text="msiexec /i `"$AppName.msi`" /qn /norestart"; Context="Template fallback for MSI silent install"; Source="Local Template"; Confidence=0.30; WhySelected="fallback_template"; SourceType="template"}
            )
        }
        3 {
            return @(
                @{Text="msiexec /x {PRODUCT-CODE-GUID} /qn /norestart"; Context="Template fallback for MSI silent uninstall"; Source="Local Template"; Confidence=0.30; WhySelected="fallback_template"; SourceType="template"},
                @{Text="$AppName.exe /uninstall /S"; Context="Template fallback for EXE uninstall"; Source="Local Template"; Confidence=0.30; WhySelected="fallback_template"; SourceType="template"}
            )
        }
        4 {
            return @(
                @{Text="Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' | Where-Object { $_.DisplayName -like '*$AppName*' } | Select-Object DisplayName, UninstallString"; Context="Template to locate uninstall command"; Source="Local Template"; Confidence=0.30; WhySelected="fallback_template"; SourceType="template"}
            )
        }
        5 {
            return @(
                @{Text="if (Get-Process -Name '$AppName' -ErrorAction SilentlyContinue) { Stop-Process -Name '$AppName' -Force }"; Context="Template pre-install process cleanup"; Source="Local Template"; Confidence=0.30; WhySelected="fallback_template"; SourceType="template"}
            )
        }
        default {
            return @()
        }
    }
}

function Get-NormalizedSuggestionKey {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $normalized = $Text.ToLower()
    $normalized = [regex]::Replace($normalized, "\s+", " ").Trim()
    return $normalized
}

function Test-IsLinkOnlyText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $true
    }

    $trimmed = $Text.Trim().ToLower()
    if ($trimmed -match "^https?://") { return $true }
    if ($trimmed -match "^www\.") { return $true }
    if ($trimmed -match "^\S+\.(com|org|net|io|edu|gov)(/\S*)?$" -and $trimmed -notmatch "\s") { return $true }

    return $false
}

function Add-Suggestion {
    param(
        [ref]$Section,
        $Item,
        [string]$Source,
        [double]$DefaultConfidence = 0.40
    )

    $text = [string]$Item.text
    $contextValue = [string]$Item.context
    if ([string]::IsNullOrWhiteSpace($text)) {
        return
    }
    if (Test-IsLinkOnlyText -Text $text) {
        return
    }

    $confidence = $DefaultConfidence
    if ($null -ne $Item.confidence) {
        $confidence = [double]$Item.confidence
    }

    $whySelected = "pattern_match"
    if ($null -ne $Item.why_selected -and -not [string]::IsNullOrWhiteSpace([string]$Item.why_selected)) {
        $whySelected = [string]$Item.why_selected
    }

    $sourceType = "page_text"
    if ($null -ne $Item.source_type -and -not [string]::IsNullOrWhiteSpace([string]$Item.source_type)) {
        $sourceType = [string]$Item.source_type
    }

    $entry = @{
        Text = $text
        Context = $contextValue
        Source = $Source
        Confidence = [Math]::Round($confidence, 3)
        WhySelected = $whySelected
        SourceType = $sourceType
    }

    $Section.Value.Suggestions += $entry
}

function Format-PackageHelperSections {
    param(
        [array]$ScrapedData,
        [string]$AppName
    )
    
    $sections = @(
        @{SectionNumber=1; Title="Context Selection"; Summary="User or System installation context"; Suggestions=@()}
        @{SectionNumber=2; Title="Install Command Line"; Summary="Silent installation command line switches"; Suggestions=@()}
        @{SectionNumber=3; Title="Uninstall Command Line"; Summary="Silent uninstallation switches"; Suggestions=@()}
        @{SectionNumber=4; Title="Uninstall Executable"; Summary="Location of uninstaller"; Suggestions=@()}
        @{SectionNumber=5; Title="Pre-Install Commands"; Summary="PowerShell to run before installation"; Suggestions=@()}
        @{SectionNumber=6; Title="Custom Install Commands"; Summary="PowerShell to run during installation"; Suggestions=@()}
        @{SectionNumber=7; Title="Post-Install Commands"; Summary="PowerShell to run after installation"; Suggestions=@()}
        @{SectionNumber=8; Title="Pre-Uninstall Commands"; Summary="PowerShell to run before uninstallation"; Suggestions=@()}
        @{SectionNumber=9; Title="Custom Uninstall Commands"; Summary="PowerShell to run during uninstallation"; Suggestions=@()}
        @{SectionNumber=10; Title="Post-Uninstall Commands"; Summary="PowerShell to run after uninstallation"; Suggestions=@()}
    )
    
    $hintToSection = @{
        context_selection = 1
        install_command_line = 2
        uninstall_command_line = 3
        uninstall_executable = 4
        pre_install_commands = 5
        custom_install_commands = 6
        post_install_commands = 7
        pre_uninstall_commands = 8
        custom_uninstall_commands = 9
        post_uninstall_commands = 10
    }

    foreach ($site in $ScrapedData) {
        if ($site.success) {
            foreach ($item in $site.data) {
                $matchedLine = ([string]$item.text).ToLower()
                $context = ([string]$item.context).ToLower()
                $source = "$($site.site_name) - $($site.url)"
                
                $fullText = "$matchedLine $context"

                # Use section hints from Python first.
                if ($null -ne $item.section_hints) {
                    foreach ($hint in @($item.section_hints)) {
                        if ($hintToSection.ContainsKey([string]$hint)) {
                            $sectionNumber = [int]$hintToSection[[string]$hint]
                            $targetSection = $sections[$sectionNumber - 1]
                            Add-Suggestion -Section ([ref]$targetSection) -Item $item -Source $source
                            $sections[$sectionNumber - 1] = $targetSection
                        }
                    }
                }
                
                if ($fullText -match "allusers|per-user|per-machine|context|hkcu|hklm") {
                    $targetSection = $sections[0]
                    Add-Suggestion -Section ([ref]$targetSection) -Item $item -Source $source
                    $sections[0] = $targetSection
                }
                
                if ($fullText -match "choco uninstall|msiexec.*/x|uninst\.exe" -and $fullText -notmatch "choco install") {
                    $targetSection = $sections[2]
                    Add-Suggestion -Section ([ref]$targetSection) -Item $item -Source $source
                    $sections[2] = $targetSection
                }
                
                if ($fullText -match "choco install|choco upgrade|/s|/silent|/quiet|/qn|setup\.exe|install\.exe|msiexec.*/i") {
                    $targetSection = $sections[1]
                    Add-Suggestion -Section ([ref]$targetSection) -Item $item -Source $source
                    $sections[1] = $targetSection
                }
                
                if ($fullText -match "uninstall.*registry|hklm.*uninstall|program files.*uninstall|uninst\.exe.*path") {
                    $targetSection = $sections[3]
                    Add-Suggestion -Section ([ref]$targetSection) -Item $item -Source $source
                    $sections[3] = $targetSection
                }
                
                if ($fullText -match "prerequisite|requirement|before.*install|pre-install|check.*version|remove.*old") {
                    $targetSection = $sections[4]
                    Add-Suggestion -Section ([ref]$targetSection) -Item $item -Source $source
                    $sections[4] = $targetSection
                }
                
                if ($fullText -match "powershell|script|transform|mst|customize|modify.*install") {
                    $targetSection = $sections[5]
                    Add-Suggestion -Section ([ref]$targetSection) -Item $item -Source $source
                    $sections[5] = $targetSection
                }
                
                if ($fullText -match "after.*install|post-install|cleanup|shortcut|settings|configure") {
                    $targetSection = $sections[6]
                    Add-Suggestion -Section ([ref]$targetSection) -Item $item -Source $source
                    $sections[6] = $targetSection
                }
                
                if ($fullText -match "before.*uninstall|pre-uninstall|backup.*settings") {
                    $targetSection = $sections[7]
                    Add-Suggestion -Section ([ref]$targetSection) -Item $item -Source $source
                    $sections[7] = $targetSection
                }
                
                if ($fullText -match "force.*remove|manual.*uninstall|cleanup.*files|remove.*registry") {
                    $targetSection = $sections[8]
                    Add-Suggestion -Section ([ref]$targetSection) -Item $item -Source $source
                    $sections[8] = $targetSection
                }
                
                if ($fullText -match "after.*uninstall|post-uninstall|verify.*removed|final.*cleanup") {
                    $targetSection = $sections[9]
                    Add-Suggestion -Section ([ref]$targetSection) -Item $item -Source $source
                    $sections[9] = $targetSection
                }
            }
        }
    }

    # Sort by confidence, dedupe by normalized text, and cap list size.
    for ($i = 0; $i -lt $sections.Count; $i++) {
        $rawSuggestions = @($sections[$i].Suggestions)
        $ordered = $rawSuggestions | Sort-Object Confidence -Descending
        $seen = @{}
        $deduped = @()

        foreach ($suggestion in $ordered) {
            $key = Get-NormalizedSuggestionKey -Text ([string]$suggestion.Text)
            if ([string]::IsNullOrWhiteSpace($key)) {
                continue
            }
            if ($seen.ContainsKey($key)) {
                continue
            }
            $seen[$key] = $true
            $deduped += $suggestion
            if ($deduped.Count -ge 7) {
                break
            }
        }

        $sections[$i].Suggestions = $deduped

        # Critical sections get deterministic fallback templates.
        if ($sections[$i].Suggestions.Count -eq 0 -and $sections[$i].SectionNumber -in @(2, 3, 4, 5)) {
            $fallbacks = Get-FallbackSuggestions -SectionNumber $sections[$i].SectionNumber -AppName $AppName
            foreach ($fallback in $fallbacks) {
                $sections[$i].Suggestions += $fallback
            }
        }
    }
    
    return $sections
}

function Show-Results {
    param([array]$Sections)
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "PACKAGE HELPER SCRAPED SUGGESTIONS" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($section in $Sections) {
        Write-Host "SECTION $($section.SectionNumber): $($section.Title)" -ForegroundColor Yellow
        Write-Host "Summary: $($section.Summary)" -ForegroundColor Gray
        Write-Host ""
        
        if ($section.Suggestions.Count -gt 0) {
            Write-Host "  Suggestions Found: $($section.Suggestions.Count)" -ForegroundColor Green
            for ($i = 0; $i -lt [Math]::Min(5, $section.Suggestions.Count); $i++) {
                $suggestion = $section.Suggestions[$i]
                $confidenceLabel = "n/a"
                if ($null -ne $suggestion.Confidence) {
                    $confidenceLabel = [string]$suggestion.Confidence
                }
                Write-Host "  [$($i + 1)] $($suggestion.Text)" -ForegroundColor White
                Write-Host "      Source: $($suggestion.Source)" -ForegroundColor DarkGray
                Write-Host "      Confidence: $confidenceLabel" -ForegroundColor DarkGray
            }
            if ($section.Suggestions.Count -gt 5) {
                Write-Host "  ... and $($section.Suggestions.Count - 5) more" -ForegroundColor DarkGray
            }
        } else {
            Write-Host "  No suggestions found (will use templates)" -ForegroundColor DarkYellow
        }
        Write-Host ""
    }
}

# =========================================
# MAIN EXECUTION
# =========================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Version-Aware Web Scraping Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Extract installer metadata
Write-Host "[STEP 1] Extracting installer metadata..." -ForegroundColor Cyan
$metadata = Get-InstallerMetadata -Path $InstallerPath

if ($null -eq $metadata) {
    exit 1
}

Write-Host "  Product: $($metadata.ProductName)" -ForegroundColor White
Write-Host "  Version: $($metadata.ProductVersion)" -ForegroundColor White
Write-Host "  Vendor: $($metadata.CompanyName)" -ForegroundColor White
Write-Host ""

# Step 2: Check prerequisites
Write-Host "[STEP 2] Checking prerequisites..." -ForegroundColor Cyan
if (-not (Test-Prerequisites)) {
    Write-Host "[ERROR] Prerequisites check failed. Exiting." -ForegroundColor Red
    exit 1
}
Write-Host "[SUCCESS] All prerequisites satisfied" -ForegroundColor Green
Write-Host ""

# Step 3: Build version-specific config
Write-Host "[STEP 3] Building version-specific scraping configuration..." -ForegroundColor Cyan
$config = Build-VersionAwareConfig -Metadata $metadata
Write-Host "  Search terms: $($config.search_terms.Count)" -ForegroundColor White
Write-Host "  Target websites: $($config.target_websites.Count)" -ForegroundColor White
Write-Host ""

# Step 4: Run scraper
Write-Host "[STEP 4] Scraping version-specific documentation..." -ForegroundColor Cyan
$configJson = $config | ConvertTo-Json -Depth 10
$scrapedData = Invoke-Scraper -ConfigJson $configJson

if ($null -eq $scrapedData) {
    Write-Log "Scraping failed. See logs for details." "ERROR"
    exit 1
}
Write-Host ""

# Step 5: Format results
Write-Host "[STEP 5] Formatting results for Package Helper..." -ForegroundColor Cyan
$sections = Format-PackageHelperSections -ScrapedData $scrapedData -AppName $metadata.ProductName

Write-Log "Section coverage summary:"
foreach ($section in $sections) {
    Write-Log "Section $($section.SectionNumber) [$($section.Title)] suggestions: $($section.Suggestions.Count)"
}

# Step 6: Save and display
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$appName = $metadata.ProductName -replace "[^a-zA-Z0-9]", "_"
$outputPath = Join-Path $ScriptPath "output\$($appName)_$($metadata.ProductVersion)_$timestamp.json"
$sections | ConvertTo-Json -Depth 10 | Set-Content $outputPath -Encoding UTF8
Write-Host "[SUCCESS] Results saved to: $outputPath" -ForegroundColor Green
Write-Host ""

Show-Results -Sections $sections

Write-Host ""
Write-Host "[SUCCESS] Scraping Complete" -ForegroundColor Green
Write-Host "Output file: $outputPath" -ForegroundColor Cyan









