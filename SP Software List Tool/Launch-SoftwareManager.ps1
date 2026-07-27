<#
.SYNOPSIS
    Quick launcher for SharePoint Software Manager with Pre-Connect.

.DESCRIPTION
    This script connects to SharePoint FIRST (in the console),
    then launches the GUI already connected. No frozen forms!

.NOTES
    This is the recommended way to launch the app.
#>

#Requires -Version 7.0

Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  SharePoint Software Manager - Quick Launcher" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will connect to SharePoint BEFORE opening the GUI" -ForegroundColor White
Write-Host "to avoid form freezing issues." -ForegroundColor Gray
Write-Host ""

# Launch with PreConnect
& "$PSScriptRoot\SharePoint-Software-Manager.ps1" -PreConnect
