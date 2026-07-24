#Requires -Version 5.1
<#
.SYNOPSIS
    ProcessEngine - Detect and suggest processes to close before installation
.NOTES
    Author: FRB Automation Team
    Created: June 5, 2026
    Version: 1.0.0
#>

function Get-ProcessDatabase {
    $configPath = Join-Path $PSScriptRoot "..\..\..\config\ProcessEngine\process-mappings.json"
    if (Test-Path $configPath) {
        try {
            return Get-Content $configPath -Raw | ConvertFrom-Json
        }
        catch {
            Write-Warning "ProcessEngine: Failed to load database - $($_.Exception.Message)"
            return $null
        }
    }
    return $null
}

function Get-RequiredProcessesToClose {
    [CmdletBinding()]
    param(
        [string]$Vendor = "",
        [string]$ProductName = "",
        [string]$InstallerType = ""
    )
    
    Write-Verbose "ProcessEngine: Analyzing Vendor='$Vendor', Product='$ProductName'"
    
    try {
        $database = Get-ProcessDatabase
        $allProcesses = @()
        
        # Search by Vendor
        if ($Vendor -and $database.vendors) {
            foreach ($v in $database.vendors) {
                if ($Vendor -match $v.pattern) {
                    $allProcesses += $v.processes
                }
            }
        }
        
        # Search by Product
        if ($ProductName -and $database.products) {
            foreach ($p in $database.products) {
                if ($ProductName -match $p.pattern) {
                    $allProcesses += $p.processes
                }
            }
        }
        
        # Intelligent guess if no matches
        if ($allProcesses.Count -eq 0 -and $ProductName) {
            $cleanName = $ProductName -replace '\s+(Software|Pro|Standard|Enterprise)\s*', '' -replace '[^\w]', ''
            if ($cleanName) {
                $allProcesses += @{displayName=$ProductName; processName="$($cleanName.ToLower()).exe"; closeProcess=$true}
            }
        }
        
        # Remove duplicates
        $unique = @()
        $names = @()
        foreach ($proc in $allProcesses) {
            if ($proc.processName -notin $names) {
                $unique += $proc
                $names += $proc.processName
            }
        }
        
        # Format: "DisplayName,process.exe,true;..."
        $formatted = ($unique | ForEach-Object { "$($_.displayName),$($_.processName),$($_.closeProcess)" }) -join ';'
        
        return @{
            Success = $true
            Processes = $unique
            FormattedString = $formatted
            Message = "Detected $($unique.Count) process(es)"
        }
    }
    catch {
        return @{Success=$false; Processes=@(); FormattedString=""; Message="Error: $($_.Exception.Message)"}
    }
}

Export-ModuleMember -Function Get-RequiredProcessesToClose
