#Requires -Version 5.1

<#
.SYNOPSIS
    PowerShell wrapper for GitLab Okta Download
.DESCRIPTION
    Calls Python script to download Master Template from GitLab using Okta authentication
.EXAMPLE
    .\Download-GitLabTemplate.ps1 -GitLabUrl 'https://gitlab.example.com/project'
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$GitLabUrl,
    
    [Parameter(Mandatory = $false)]
    [string]$OktaUrl = 'https://frbanks.okta.com',
    
    [Parameter(Mandatory = $false)]
    [string]$DownloadPath = '.\downloads',
    
    [Parameter(Mandatory = $false)]
    [string]$SessionFile = '.\session_state.json',
    
    [Parameter(Mandatory = $false)]
    [switch]$Headless,
    
    [Parameter(Mandatory = $false)]
    [switch]$ForceLogin,
    
    [Parameter(Mandatory = $false)]
    [string]$PythonPath = 'python'
)

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pythonScript = Join-Path $scriptDir 'gitlab_okta_download.py'

# Build arguments (script path passed separately, not in array)
$pythonArgs = @(
    '--gitlab-url', $GitLabUrl,
    '--okta-url', $OktaUrl,
    '--download-path', $DownloadPath,
    '--session-file', $SessionFile
)

if ($Headless) {
    $pythonArgs += '--headless'
}

if ($ForceLogin) {
    $pythonArgs += '--force-login'
}

Write-Host 'Starting GitLab download via Playwright + Okta...' -ForegroundColor Cyan
Write-Host ''

# Run Python script
try {
    $result = & $PythonPath $pythonScript $pythonArgs
    $exitCode = $LASTEXITCODE
    
    if ($exitCode -eq 0) {
        Write-Host ''
        Write-Host 'Download completed successfully!' -ForegroundColor Green
        return $true
    } else {
        Write-Host ''
        Write-Host 'Download failed!' -ForegroundColor Red
        return $false
    }
}
catch {
    Write-Host 'Error running Python script:' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    return $false
}

