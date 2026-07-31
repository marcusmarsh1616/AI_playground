# INTERNAL FR/OFFICIAL USE // FRSONLY
#Requires -Version 5.1

<#
.SYNOPSIS
    Install Playwright library for web scraping
.DESCRIPTION
    Installs Playwright Python library (uses Microsoft Edge, no browser download)
    Checks if already installed before attempting installation
.EXAMPLE
    .\Install-Playwright.ps1
#>

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Playwright Installation Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check Python
Write-Host "[1/3] Checking Python..." -ForegroundColor Cyan
$pythonVersion = python --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "    [FAIL] Python not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Python 3.8+ from: https://www.python.org/downloads/" -ForegroundColor Yellow
    exit 1
}
Write-Host "    [PASS] $pythonVersion" -ForegroundColor Green

# Step 2: Check if Playwright already installed
Write-Host "[2/3] Checking if Playwright already installed..." -ForegroundColor Cyan
$playwrightCheck = python -c "import playwright; print('installed')" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "    [ALREADY INSTALLED] Playwright is installed" -ForegroundColor Green
    Write-Host ""
    Write-Host "[SUCCESS] Playwright is already installed and ready to use" -ForegroundColor Green
    Write-Host "Configuration: Uses Microsoft Edge browser" -ForegroundColor Cyan
    exit 0
}
Write-Host "    [NOT INSTALLED] Playwright needs to be installed" -ForegroundColor Yellow

# Step 3: Install Playwright
Write-Host "[3/3] Installing Playwright library..." -ForegroundColor Cyan
Write-Host "    This will install ONLY the library (uses Microsoft Edge)" -ForegroundColor Gray
Write-Host "    Installation size: ~5MB" -ForegroundColor Gray
Write-Host ""

python -m pip install playwright

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[FAIL] Playwright installation failed" -ForegroundColor Red
    Write-Host "Check your internet connection and try again" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Verifying Installation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Verify installation
$verifyCheck = python -c "import playwright; print('installed')" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] Playwright installed successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Cyan
    Write-Host "  - Library: Playwright (Python)" -ForegroundColor White
    Write-Host "  - Browser: Microsoft Edge (already installed)" -ForegroundColor White
    Write-Host "  - No additional downloads required" -ForegroundColor White
    Write-Host ""
    Write-Host "Ready to use for web scraping!" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Installation verification failed" -ForegroundColor Red
    Write-Host "Output: $verifyCheck" -ForegroundColor Yellow
    exit 1
}
