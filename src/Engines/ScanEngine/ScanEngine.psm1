#Requires -Version 5.1

<#
.SYNOPSIS
    ScanEngine - Scans for installed software
.DESCRIPTION
    Scans registry for installed software instances
.NOTES
    Author: FRB Automation Team
    Created: 2026-06-06
    Version: 1.0.0
    PowerShell Version: 5.1
    Source: Extracted from working PostInstallValidation.psm1
#>

function Get-InstalledSoftwareData {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Vendor,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ProductName
    )
    
    Write-Verbose "ScanEngine: Scanning for $ProductName by $Vendor"
    
    $scanData = [PSCustomObject]@{
        Vendor = $Vendor
        ProductName = $ProductName
        InstancesFound = 0
        Instances = @()
        RegistryPaths = @()
        ScanTimestamp = Get-Date
    }
    
    # Scan ALL registry locations
    $registryPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    
    foreach ($regPath in $registryPaths) {
        try {
            if (-not (Test-Path $regPath)) { continue }
            
            $scanData.RegistryPaths += $regPath
            
            $subKeys = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue
            
            foreach ($subKey in $subKeys) {
                try {
                    $app = Get-ItemProperty -Path $subKey.PSPath -ErrorAction SilentlyContinue
                    
                    if ($app -and $app.DisplayName) {
                        # FIXED: Search ONLY by ProductName with wildcards - Vendor may not match or be missing
                        # This ensures we find the software even if Publisher field is empty or different
                        if ($app.DisplayName -like "*$ProductName*") {
                            Write-Verbose "  Found match: $($app.DisplayName)"
                            
                            $scanData.Instances += $app
                            $scanData.InstancesFound++
                        }
                    }
                } catch {
                    Write-Verbose "  Error scanning subkey: $($_.Exception.Message)"
                }
            }
        } catch {
            Write-Verbose "  Error scanning path $regPath : $($_.Exception.Message)"
        }
    }
    
    Write-Verbose "ScanEngine: Found $($scanData.InstancesFound) instance(s)"
    
    return $scanData
}

Export-ModuleMember -Function Get-InstalledSoftwareData
