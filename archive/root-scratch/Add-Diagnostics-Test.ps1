#Requires -Version 5.1
# PHASE 2, TEST 3: Add Diagnostic Logging to GUI Browse Event

Write-Host "[TEST 3] Adding diagnostic logging to GUI Browse button event..." -ForegroundColor Cyan

$guiPath = "C:\Temp\AI_Tools\FRB-Packaging-Tool\FRB-Packaging-Tool.ps1"
$content = Get-Content $guiPath -Raw -Encoding UTF8

# Replace the try block with diagnostic version
$oldPattern = "try \{[^}]*Get-CustomCommandsFromStartupPss"

$insertDiagnostics = @"
try {
                    Write-Host "=== DIAGNOSTIC: Custom Commands Load ===" -ForegroundColor Magenta
                    Write-Host "DEBUG: About to call Get-CustomCommandsFromStartupPss" -ForegroundColor Magenta
                    Write-Host "DEBUG: Path: dollar existingStartupPath" -ForegroundColor Magenta
                    Write-Host "DEBUG: File exists: dollar (Test-Path dollar existingStartupPath)" -ForegroundColor Magenta
                    
                    dollar loadResult = Get-CustomCommandsFromStartupPss
"@

$content = $content -replace $oldPattern, $insertDiagnostics
Set-Content -Path $guiPath -Value $content -Encoding UTF8 -Force
Write-Host "[SUCCESS] Diagnostics added" -ForegroundColor Green
