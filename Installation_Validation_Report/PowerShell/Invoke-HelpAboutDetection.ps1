#Requires -Version 5.1
<#!
.SYNOPSIS
    Standalone Help/About detection utility for proof-of-concept testing.

.DESCRIPTION
    Runs the Help/About window detection logic independently so it can be validated
    without going through the full validation report workflow.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ApplicationName = 'all'
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $scriptRoot 'Modules\HelpAboutDetection.psm1') -Force

$results = Get-HelpAboutVerification -ApplicationName $ApplicationName

if (-not $results -or $results.Count -eq 0) {
    Write-Host 'No matching Help/About-style windows were detected.' -ForegroundColor Yellow
    Write-Host 'Current visible window titles:' -ForegroundColor Cyan
    Get-Process | Where-Object { $_.MainWindowTitle -and $_.MainWindowTitle.Trim() } | ForEach-Object {
        Write-Host ("- {0} :: {1}" -f $_.ProcessName, $_.MainWindowTitle) -ForegroundColor Cyan
    }
    exit 0
}

Write-Host "Detected $($results.Count) matching window(s):" -ForegroundColor Green
foreach ($item in $results) {
    Write-Host "- Process: $($item.ProcessName)" -ForegroundColor Cyan
    Write-Host "  Window: $($item.WindowTitle)" -ForegroundColor Cyan
    Write-Host "  Pattern: $($item.MatchedPattern)" -ForegroundColor Cyan
    if ($item.ProductName) { Write-Host "  Product: $($item.ProductName)" -ForegroundColor Cyan }
    if ($item.ProductVersion) { Write-Host "  Version: $($item.ProductVersion)" -ForegroundColor Cyan }
    if ($item.CompanyName) { Write-Host "  Vendor: $($item.CompanyName)" -ForegroundColor Cyan }
}
