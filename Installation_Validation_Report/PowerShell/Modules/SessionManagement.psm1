#Requires -Version 5.1
<#
.SYNOPSIS
    Session Management Module for Installation Validation

.DESCRIPTION
    Integrates validation runs with AI session management system
    Tracks metrics, errors, and outcomes for analysis
#>

function Start-ValidationSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ApplicationName,
        
        [Parameter(Mandatory=$false)]
        [string]$Version,
        
        [Parameter(Mandatory=$false)]
        [string]$InstallerPath
    )
    
    $sessionId = [guid]::NewGuid().ToString()
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    
    $session = [ordered]@{
        session_id = $sessionId
        start_time = $timestamp
        user = $env:USERNAME
        computer = $env:COMPUTERNAME
        application = $ApplicationName
        version = $Version
        installer_path = $InstallerPath
        status = 'running'
        metrics = @{}
        errors = @()
        end_time = $null
        success = $null
        report_path = $null
        duration_seconds = $null
    }
    
    Write-Host "[SESSION] Started: $sessionId" -ForegroundColor Cyan
    
    return [PSCustomObject]$session
}

function Save-ValidationSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Session,
        
        [Parameter(Mandatory=$true)]
        [bool]$Success,
        
        [Parameter(Mandatory=$false)]
        [hashtable]$Metrics = @{},
        
        [Parameter(Mandatory=$false)]
        [array]$Errors = @(),
        
        [Parameter(Mandatory=$false)]
        [string]$ReportPath
    )
    
    $scriptRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $sessionsPath = Join-Path $scriptRoot "Sessions"
    
    # Ensure directory exists
    if (-not (Test-Path $sessionsPath)) {
        New-Item -Path $sessionsPath -ItemType Directory -Force | Out-Null
    }
    
    # Update session data
    $Session.status = if ($Success) { 'completed' } else { 'failed' }
    $Session.end_time = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $Session.success = $Success
    $Session.metrics = $Metrics
    $Session.errors = $Errors
    $Session.report_path = $ReportPath
    
    # Calculate duration
    $startTime = [DateTime]::ParseExact($Session.start_time, 'yyyy-MM-dd HH:mm:ss', $null)
    $endTime = [DateTime]::ParseExact($Session.end_time, 'yyyy-MM-dd HH:mm:ss', $null)
    $Session.duration_seconds = ($endTime - $startTime).TotalSeconds
    
    # Save to file
    $fileName = "SESSION_$($Session.session_id)_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $filePath = Join-Path $sessionsPath $fileName
    
    $Session | ConvertTo-Json -Depth 10 | Set-Content $filePath -Encoding UTF8
    
    Write-Host "[SESSION] Saved: $filePath" -ForegroundColor Green
    
    return $filePath
}

function Get-ValidationSessions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [int]$Last = 0,
        
        [Parameter(Mandatory=$false)]
        [string]$Application,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('completed', 'failed', 'all')]
        [string]$Status = 'all'
    )
    
    $scriptRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $sessionsPath = Join-Path $scriptRoot "Sessions"
    
    if (-not (Test-Path $sessionsPath)) {
        Write-Host "[INFO] No sessions found" -ForegroundColor Yellow
        return @()
    }
    
    $sessionFiles = Get-ChildItem -Path $sessionsPath -Filter "SESSION_*.json" | Sort-Object LastWriteTime -Descending
    
    $sessions = @()
    foreach ($file in $sessionFiles) {
        try {
            $session = Get-Content $file.FullName -Raw | ConvertFrom-Json
            
            # Filter by application
            if ($Application -and $session.application -ne $Application) {
                continue
            }
            
            # Filter by status
            if ($Status -ne 'all' -and $session.status -ne $Status) {
                continue
            }
            
            $sessions += $session
        } catch {
            Write-Host "[WARNING] Could not read session file: $($file.Name)" -ForegroundColor Yellow
        }
    }
    
    # Limit results
    if ($Last -gt 0 -and $sessions.Count -gt $Last) {
        $sessions = $sessions[0..($Last-1)]
    }
    
    return $sessions
}

function Get-ValidationStatistics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [int]$DaysBack = 30
    )
    
    $cutoffDate = (Get-Date).AddDays(-$DaysBack)
    $sessions = Get-ValidationSessions
    
    # Filter by date
    $recentSessions = $sessions | Where-Object {
        $sessionDate = [DateTime]::ParseExact($_.start_time, 'yyyy-MM-dd HH:mm:ss', $null)
        $sessionDate -gt $cutoffDate
    }
    
    $total = $recentSessions.Count
    $successful = ($recentSessions | Where-Object { $_.success -eq $true }).Count
    $failed = ($recentSessions | Where-Object { $_.success -eq $false }).Count
    
    # Cache statistics
    $cacheHits = ($recentSessions | Where-Object { $_.metrics.cache_hit -eq $true }).Count
    $cacheMisses = ($recentSessions | Where-Object { $_.metrics.cache_hit -eq $false }).Count
    
    # Average duration
    $avgDuration = if ($total -gt 0) {
        ($recentSessions | Measure-Object -Property duration_seconds -Average).Average
    } else { 0 }
    
    # Top applications
    $topApps = $recentSessions | Group-Object -Property application | Sort-Object Count -Descending | Select-Object -First 10
    
    $stats = @{
        period_days = $DaysBack
        total_validations = $total
        successful = $successful
        failed = $failed
        success_rate = if ($total -gt 0) { [math]::Round(($successful / $total) * 100, 2) } else { 0 }
        cache_hits = $cacheHits
        cache_misses = $cacheMisses
        cache_hit_rate = if (($cacheHits + $cacheMisses) -gt 0) { 
            [math]::Round(($cacheHits / ($cacheHits + $cacheMisses)) * 100, 2) 
        } else { 0 }
        average_duration_seconds = [math]::Round($avgDuration, 2)
        top_applications = $topApps | ForEach-Object { 
            @{
                name = $_.Name
                count = $_.Count
            }
        }
    }
    
    return [PSCustomObject]$stats
}

function Export-ValidationSessions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )
    
    $sessions = Get-ValidationSessions
    
    $sessions | ConvertTo-Json -Depth 10 | Set-Content $OutputPath -Encoding UTF8
    
    Write-Host "[SUCCESS] Exported $($sessions.Count) sessions to $OutputPath" -ForegroundColor Green
}

Export-ModuleMember -Function Start-ValidationSession, Save-ValidationSession, Get-ValidationSessions, Get-ValidationStatistics, Export-ValidationSessions
