#Requires -Version 5.1
# TEST 1: Load Function Isolation Test
# Purpose: Test Get-CustomCommandsFromStartupPss with real Miniconda package

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PHASE 1, TEST 1: Engine Load Function Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Import CustomCommandsEngine module
Write-Host "[1] Importing CustomCommandsEngine module..." -ForegroundColor Yellow
$modulePath = "C:\Temp\AI_Tools\FRB-Packaging-Tool\src\Engines\CustomCommandsEngine\CustomCommandsEngine.psm1"
Import-Module $modulePath -Force

if (Get-Module CustomCommandsEngine) {
    Write-Host "    [SUCCESS] Module loaded" -ForegroundColor Green
} else {
    Write-Host "    [FAIL] Module not loaded" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[2] Testing Get-CustomCommandsFromStartupPss function..." -ForegroundColor Yellow
$testPath = "J:\AI_playground\Packaging folder\Anaconda, Inc\Miniconda3\py314_26.5.3-1\Startup.pss"

if (-not (Test-Path $testPath)) {
    Write-Host "    [FAIL] Test file not found: $testPath" -ForegroundColor Red
    exit 1
}

Write-Host "    Test file: $testPath" -ForegroundColor Gray
Write-Host "    Calling function..." -ForegroundColor Gray

try {
    $result = Get-CustomCommandsFromStartupPss -StartupPssPath $testPath
    
    Write-Host ""
    Write-Host "[3] Function returned successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Results:" -ForegroundColor Yellow
    Write-Host "--------" -ForegroundColor Yellow
    
    # Check each section
    $sections = @('PreInstall', 'CustomInstall', 'PostInstall', 'PreUninstall', 'CustomUninstall', 'PostUninstall')
    
    foreach ($section in $sections) {
        $content = $result[$section]
        if ([string]::IsNullOrWhiteSpace($content)) {
            Write-Host "  $section : [EMPTY]" -ForegroundColor Gray
        } else {
            Write-Host "  $section : [HAS CONTENT - $($content.Length) chars]" -ForegroundColor Green
            Write-Host "    Preview: $($content.Substring(0, [Math]::Min(60, $content.Length)))..." -ForegroundColor Cyan
        }
    }
    
    # Check metadata fields
    Write-Host ""
    Write-Host "Metadata Fields:" -ForegroundColor Yellow
    Write-Host "----------------" -ForegroundColor Yellow
    Write-Host "  AppUninstallExeName: [$($result.AppUninstallExeName)]" -ForegroundColor $(if ($result.AppUninstallExeName) { "Green" } else { "Gray" })
    Write-Host "  AppInstallCommandLine: [$($result.AppInstallCommandLine)]" -ForegroundColor $(if ($result.AppInstallCommandLine) { "Green" } else { "Gray" })
    Write-Host "  AppUninstallCommandLine: [$($result.AppUninstallCommandLine)]" -ForegroundColor $(if ($result.AppUninstallCommandLine) { "Green" } else { "Gray" })
    
    Write-Host ""
    Write-Host "[DETAILED CONTENT] CustomInstall Section:" -ForegroundColor Yellow
    Write-Host "==========================================" -ForegroundColor Yellow
    if (-not [string]::IsNullOrWhiteSpace($result.CustomInstall)) {
        Write-Host $result.CustomInstall -ForegroundColor White
    } else {
        Write-Host "[EMPTY - NO CONTENT EXTRACTED]" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "TEST 1 RESULT: $(if ($result.CustomInstall) { 'PASS - Function extracts data' } else { 'FAIL - Function returns empty' })" -ForegroundColor $(if ($result.CustomInstall) { "Green" } else { "Red" })
    Write-Host "========================================" -ForegroundColor Cyan
    
} catch {
    Write-Host ""
    Write-Host "[FAIL] Function threw error:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
}
