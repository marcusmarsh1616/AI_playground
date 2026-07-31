#Requires -Version 5.1
<#
.SYNOPSIS
    Cache Management Module

.DESCRIPTION
    PowerShell interface to Python cache system
#>

function Get-CacheStatistics {
    [CmdletBinding()]
    param()
    
    $scriptRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
    $cacheFile = Join-Path $scriptRoot "Cache\research_cache.json"
    
    if (Test-Path $cacheFile) {
        $cache = Get-Content $cacheFile -Raw | ConvertFrom-Json
        
        $stats = @{
            CacheFile = $cacheFile
            TotalEntries = ($cache.PSObject.Properties | Measure-Object).Count
            Applications = $cache.PSObject.Properties.Name
            LastModified = (Get-Item $cacheFile).LastWriteTime
        }
        
        return [PSCustomObject]$stats
    } else {
        return [PSCustomObject]@{
            CacheFile = $cacheFile
            TotalEntries = 0
            Applications = @()
            LastModified = $null
        }
    }
}

function Clear-ResearchCache {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Application
    )
    
    $scriptRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
    $cacheFile = Join-Path $scriptRoot "Cache\research_cache.json"
    
    if (-not (Test-Path $cacheFile)) {
        Write-Host "[INFO] Cache file does not exist" -ForegroundColor Cyan
        return
    }
    
    if ($Application) {
        # Clear specific application
        $cache = Get-Content $cacheFile -Raw | ConvertFrom-Json
        
        if ($cache.PSObject.Properties.Name -contains $Application) {
            if ($PSCmdlet.ShouldProcess($Application, "Remove from cache")) {
                $cache.PSObject.Properties.Remove($Application)
                $cache | ConvertTo-Json -Depth 10 | Set-Content $cacheFile -Encoding UTF8
                Write-Host "[SUCCESS] Removed $Application from cache" -ForegroundColor Green
            }
        } else {
            Write-Host "[WARNING] $Application not found in cache" -ForegroundColor Yellow
        }
    } else {
        # Clear entire cache
        if ($PSCmdlet.ShouldProcess("Entire cache", "Clear")) {
            Remove-Item $cacheFile -Force
            Write-Host "[SUCCESS] Cache cleared" -ForegroundColor Green
        }
    }
}

Export-ModuleMember -Function Get-CacheStatistics, Clear-ResearchCache
