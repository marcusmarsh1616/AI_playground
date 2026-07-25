#Requires -Version 5.1
<#
.SYNOPSIS
    Documentation Capture Tool - Launcher
    
.DESCRIPTION
    Launches the documentation capture tool GUI.
    Thin launcher that imports and invokes the UI engine.
    
.NOTES
    Author: P1MAM08
    Date: 2026-07-09
    Version: 2.0.0
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$AppName,

    [Parameter(Mandatory = $true)]
    [string]$AppVersion
)

# Import UI Engine
$ModulePath = "$PSScriptRoot\src"
Import-Module "$ModulePath\DocumentationUIEngine.psm1" -Force -ErrorAction Stop

# Run context-driven workflow (no data-entry GUI)
Write-Host ""
Write-Host "=== Documentation Capture Tool ===" -ForegroundColor Cyan
Write-Host "Running integrated capture workflow..." -ForegroundColor Yellow
Write-Host ""

Invoke-DocumentationCaptureFromContext -AppName $AppName -AppVersion $AppVersion
