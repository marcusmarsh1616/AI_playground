#Requires -Version 5.1
<#
.SYNOPSIS
    Invoke Python Playwright research module

.DESCRIPTION
    Calls the Python research_requirements.py script to perform
    automated web research of application requirements

.PARAMETER ApplicationName
    Name of the application to research

.PARAMETER Version
    Optional version number

.OUTPUTS
    PSCustomObject with research results
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ApplicationName,
    
    [Parameter(Mandatory=$false)]
    [string]$Version
)

function Invoke-WebResearch {
    param(
        [string]$ApplicationName,
        [string]$Version
    )
    
    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
    $projectRoot = if ($scriptRoot) { Split-Path -Parent $scriptRoot } else { $PWD.Path }
    $pythonScript = Join-Path $projectRoot "Python\research_requirements.py"
    
    # Verify Python script exists
    if (-not (Test-Path $pythonScript)) {
        Write-Host "[ERROR] Python script not found: $pythonScript" -ForegroundColor Red
        return @{
            success = $false
            error = "Python research script not found"
        }
    }
    
    # Resolve a usable Python interpreter on Windows or other systems
    $pythonExe = $null
    $candidatePaths = @(
        $env:PYTHON_EXE,
        $env:VIRTUAL_ENV,
        'C:\Users\marcu\AppData\Roaming\uv\python\cpython-3.14.6-windows-x86_64-none\python.exe',
        'C:\Users\marcu\AppData\Local\Programs\Python\Python311\python.exe',
        'C:\Users\marcu\AppData\Local\Programs\Python\Python312\python.exe',
        'C:\Program Files\Python311\python.exe',
        'C:\Program Files\Python312\python.exe',
        'python'
    )

    foreach ($candidate in $candidatePaths) {
        if (-not $candidate) { continue }
        if ($candidate -eq 'python') {
            try {
                $pythonVersion = & python --version 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $pythonExe = 'python'
                    break
                }
            } catch { }
            continue
        }

        if (Test-Path $candidate) {
            $pythonExe = $candidate
            break
        }
    }

    if (-not $pythonExe) {
        Write-Host "[ERROR] Python interpreter could not be located. Install Python 3.x and ensure it is available on the machine." -ForegroundColor Red
        return @{
            success = $false
            error = "Python interpreter not found"
        }
    }

    try {
        $pythonVersion = & $pythonExe --version 2>&1
        Write-Host "[INFO] Using $pythonVersion" -ForegroundColor Cyan
    } catch {
        Write-Host "[ERROR] Python was found but could not be executed: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            success = $false
            error = "Python interpreter could not be executed"
        }
    }
    
    # Check if Playwright is installed
    try {
        $playwrightCheck = & $pythonExe -c "import playwright; print('OK')" 2>&1
        if ($LASTEXITCODE -ne 0 -or $playwrightCheck -notmatch 'OK') {
            Write-Host "[WARNING] Playwright may not be installed for $pythonExe" -ForegroundColor Yellow
            Write-Host "[INFO] Run: & '$pythonExe' -m pip install -r $projectRoot\Python\requirements.txt" -ForegroundColor Cyan
        }
    } catch {
        Write-Host "[WARNING] Could not verify Playwright installation" -ForegroundColor Yellow
    }
    
    # Build command arguments
    $arguments = @($pythonScript, $ApplicationName)
    
    if ($Version) {
        $arguments += @("--version", $Version)
    }
    
    # Create temp file for output
    $tempOutput = Join-Path $env:TEMP "validation_research_$(Get-Date -Format 'yyyyMMddHHmmss').json"
    $arguments += @("--output", $tempOutput)
    
    Write-Host "[EXECUTE] $pythonExe $($arguments -join ' ')" -ForegroundColor Cyan
    
    # Execute Python script
    try {
        $process = Start-Process -FilePath $pythonExe `
                                 -ArgumentList $arguments `
                                 -NoNewWindow `
                                 -Wait `
                                 -PassThru
        
        if ($process.ExitCode -eq 0) {
            # Read results
            if (Test-Path $tempOutput) {
                $jsonContent = Get-Content $tempOutput -Raw -Encoding UTF8
                $result = $jsonContent | ConvertFrom-Json
                
                # Clean up temp file
                Remove-Item $tempOutput -Force
                
                return $result
            } else {
                Write-Host "[ERROR] Output file not created" -ForegroundColor Red
                return @{
                    success = $false
                    error = "Python script did not generate output"
                }
            }
        } else {
            Write-Host "[ERROR] Python script failed with exit code: $($process.ExitCode)" -ForegroundColor Red
            return @{
                success = $false
                error = "Python script execution failed"
            }
        }
    } catch {
        Write-Host "[ERROR] Failed to execute Python script: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            success = $false
            error = $_.Exception.Message
        }
    }
}

# If run directly (not dot-sourced)
if ($MyInvocation.InvocationName -ne '.') {
    $result = Invoke-WebResearch -ApplicationName $ApplicationName -Version $Version
    
    if ($result.success) {
        Write-Host "`n[SUCCESS] Research Complete" -ForegroundColor Green
        $result | ConvertTo-Json -Depth 10
    } else {
        Write-Host "`n[FAILED] Research Failed" -ForegroundColor Red
        Write-Host "[ERROR] $($result.error)" -ForegroundColor Red
    }
}
