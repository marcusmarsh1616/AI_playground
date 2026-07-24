#Requires -Version 5.1

<#
.SYNOPSIS
    ReportEngine - Generates HTML validation reports
.DESCRIPTION
    Creates professional HTML reports from scan data
.NOTES
    Author: FRB Automation Team
    Created: 2026-06-06
    Version: 1.0.0
    PowerShell Version: 5.1
    Source: Extracted from working PostInstallValidation.psm1
    NO EMOJIS - Professional text only
#>

function New-HTMLValidationReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Vendor,
        
        [Parameter(Mandatory = $true)]
        [string]$ProductName,
        
        [Parameter(Mandatory = $true)]
        [string]$Version,
        
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$ScanData,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )
    
    Write-Verbose "ReportEngine: Generating HTML report for $ProductName"
    
    $result = @{
        Success = $false
        ReportPath = ""
        ErrorMessage = ""
    }
    
    try {
        # Determine validation status
        $validationStatus = if ($ScanData.InstancesFound -gt 0) {
            "Success"
        } else {
            "Failed"
        }
        
        # Determine status styling (NO EMOJIS)
        $statusColor = switch ($validationStatus) {
            "Success" { "#28a745" }
            "Warning" { "#ffc107" }
            "Failed" { "#dc3545" }
            default { "#6c757d" }
        }
        
        $statusIcon = switch ($validationStatus) {
            "Success" { "[PASS]" }
            "Warning" { "[WARN]" }
            "Failed" { "[FAIL]" }
            default { "[INFO]" }
        }
        
        # Build instances HTML
        $instancesHTML = ""
        if ($ScanData.Instances -and $ScanData.Instances.Count -gt 0) {
            $num = 1
            foreach ($inst in $ScanData.Instances) {
                if ($ScanData.Instances.Count -gt 1) {
                    $instancesHTML += "<div class='instance-header'>[INSTANCE] $num of $($ScanData.Instances.Count)</div>"
                }
                
                $displayName = if ($inst.DisplayName) { $inst.DisplayName } else { "N/A" }
                $instVersion = if ($inst.DisplayVersion) { $inst.DisplayVersion } else { "N/A" }
                $publisher = if ($inst.Publisher) { $inst.Publisher } else { "N/A" }
                $installLocation = if ($inst.InstallLocation) { $inst.InstallLocation } else { "N/A" }
                $installDate = if ($inst.InstallDate) { $inst.InstallDate } else { "N/A" }
                $estimatedSize = if ($inst.EstimatedSize) { "$($inst.EstimatedSize) KB" } else { "N/A" }
                $registryKey = if ($inst.PSPath) { $inst.PSPath -replace 'Microsoft.PowerShell.Core\\Registry::', '' } else { "N/A" }
                
                $instancesHTML += "<div class='info-grid'>"
                $instancesHTML += "<div class='info-card'><div class='info-label'>Display Name</div><div class='info-value'>$displayName</div></div>"
                $instancesHTML += "<div class='info-card'><div class='info-label'>Version</div><div class='info-value'>$instVersion</div></div>"
                $instancesHTML += "<div class='info-card'><div class='info-label'>Publisher</div><div class='info-value'>$publisher</div></div>"
                $instancesHTML += "<div class='info-card'><div class='info-label'>Install Location</div><div class='info-value'>$installLocation</div></div>"
                $instancesHTML += "<div class='info-card'><div class='info-label'>Install Date</div><div class='info-value'>$installDate</div></div>"
                $instancesHTML += "<div class='info-card'><div class='info-label'>Estimated Size</div><div class='info-value'>$estimatedSize</div></div>"
                $instancesHTML += "<div class='info-card' style='grid-column: span 2;'><div class='info-label'>Registry Key</div><div class='info-value' style='font-size:0.85em;'>$registryKey</div></div>"
                $instancesHTML += "</div>"
                $num++
            }
        } else {
            $instancesHTML = "<p style='color:#999;font-style:italic;'>No instances found</p>"
        }
        
        # Build registry paths HTML
        $registryHTML = ""
        if ($ScanData.RegistryPaths -and $ScanData.RegistryPaths.Count -gt 0) {
            $registryHTML = "<div class='registry-list'>"
            foreach ($regPath in $ScanData.RegistryPaths) {
                $regType = if ($regPath -like "*Uninstall*") { "UNINSTALL" } elseif ($regPath -like "*Wow6432Node*") { "WOW64" } else { "STANDARD" }
                $registryHTML += "<div class='registry-key'><span class='key-type'>$regType</span><span class='key-path'>$regPath</span></div>"
            }
            $registryHTML += "</div>"
        } else {
            $registryHTML = "<p style='color:#999;font-style:italic;'>No registry keys scanned</p>"
        }
        
        # Get OS info
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        $osCaption = if ($os) { $os.Caption } else { "Unknown" }
        $osArch = if ($os) { $os.OSArchitecture } else { "Unknown" }
        
        # Build complete HTML (using string concatenation - NO HERE-STRINGS per Rule 13)
        $html = "<!DOCTYPE html>`n<html>`n<head>`n"
        $html += "<meta charset='UTF-8'>`n"
        $html += "<title>Validation Report - $ProductName</title>`n"
        $html += "<style>`n"
        $html += "body { font-family: 'Segoe UI', Arial, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 20px; margin: 0; }`n"
        $html += ".container { max-width: 1200px; margin: 0 auto; background: white; border-radius: 12px; box-shadow: 0 20px 60px rgba(0,0,0,0.3); overflow: hidden; }`n"
        $html += ".header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 40px; text-align: center; }`n"
        $html += ".header h1 { font-size: 2.5em; margin: 0 0 10px 0; font-weight: 300; }`n"
        $html += ".status-banner { background-color: $statusColor; color: white; padding: 20px; text-align: center; font-size: 1.5em; font-weight: bold; }`n"
        $html += ".status-icon { font-size: 2em; margin-right: 10px; }`n"
        $html += ".content { padding: 40px; }`n"
        $html += ".section { margin-bottom: 40px; }`n"
        $html += ".section-title { color: #667eea; font-size: 1.8em; margin-bottom: 20px; padding-bottom: 10px; border-bottom: 3px solid #667eea; }`n"
        $html += ".info-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin-bottom: 20px; }`n"
        $html += ".info-card { background: #f8f9fa; border-left: 4px solid #667eea; padding: 20px; border-radius: 8px; }`n"
        $html += ".info-label { color: #6c757d; font-size: 0.9em; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 8px; }`n"
        $html += ".info-value { font-size: 1.1em; color: #212529; word-break: break-all; white-space: pre-wrap; }`n"
        $html += ".instance-header { color: #667eea; margin: 30px 0 20px 0; padding: 15px; background: linear-gradient(to right, #f0f0f0, #fff); border-left: 5px solid #667eea; font-size: 1.3em; }`n"
        $html += ".registry-list { background: #f8f9fa; padding: 20px; border-radius: 8px; max-height: 400px; overflow-y: auto; border: 1px solid #dee2e6; }`n"
        $html += ".registry-key { background: white; margin-bottom: 8px; padding: 12px 15px; border-left: 3px solid #667eea; border-radius: 4px; font-family: 'Consolas', 'Courier New', monospace; font-size: 0.85em; word-break: break-all; }`n"
        $html += ".registry-key .key-type { display: inline-block; padding: 2px 8px; background: #667eea; color: white; border-radius: 3px; font-size: 0.75em; margin-right: 8px; }`n"
        $html += ".registry-key .key-path { color: #495057; }`n"
        $html += ".footer { background: #f8f9fa; padding: 30px; text-align: center; color: #6c757d; border-top: 1px solid #dee2e6; }`n"
        $html += ".badge { display: inline-block; padding: 5px 12px; background: #667eea; color: white; border-radius: 15px; font-size: 0.9em; margin-left: 10px; }`n"
        $html += "</style>`n</head>`n<body>`n"
        $html += "<div class='container'>`n"
        $html += "<div class='header'>`n<h1>Software Installation Validation Report</h1>`n<div>$ProductName $Version</div>`n</div>`n"
        $html += "<div class='status-banner'>`n<span class='status-icon'>$statusIcon</span>`nValidation Status: $validationStatus`n</div>`n"
        $html += "<div class='content'>`n"
        $html += "<div class='section'>`n<h2 class='section-title'>Software Information</h2>`n"
        $html += "<div class='info-grid'>`n"
        $html += "<div class='info-card'><div class='info-label'>Software Name</div><div class='info-value'>$ProductName</div></div>`n"
        $html += "<div class='info-card'><div class='info-label'>Expected Version</div><div class='info-value'>$Version</div></div>`n"
        $html += "<div class='info-card'><div class='info-label'>Vendor</div><div class='info-value'>$Vendor</div></div>`n"
        $html += "<div class='info-card'><div class='info-label'>Scan Date</div><div class='info-value'>$($ScanData.ScanTimestamp.ToString("MMMM dd, yyyy HH:mm:ss"))</div></div>`n"
        $html += "<div class='info-card'><div class='info-label'>Instances Found</div><div class='info-value'>$($ScanData.InstancesFound)</div></div>`n"
        $html += "</div>`n</div>`n"
        $html += "<div class='section'>`n<h2 class='section-title'>Installation Details</h2>`n$instancesHTML`n</div>`n"
        $html += "<div class='section'>`n<h2 class='section-title'>Registry Locations Scanned<span class='badge'>$($ScanData.RegistryPaths.Count) Paths</span></h2>`n$registryHTML`n</div>`n"
        $html += "<div class='section'>`n<h2 class='section-title'>System Information</h2>`n<div class='info-grid'>`n"
        $html += "<div class='info-card'><div class='info-label'>Computer Name</div><div class='info-value'>$env:COMPUTERNAME</div></div>`n"
        $html += "<div class='info-card'><div class='info-label'>User Name</div><div class='info-value'>$env:USERNAME</div></div>`n"
        $html += "<div class='info-card'><div class='info-label'>Operating System</div><div class='info-value'>$osCaption</div></div>`n"
        $html += "<div class='info-card'><div class='info-label'>OS Architecture</div><div class='info-value'>$osArch</div></div>`n"
        $html += "</div>`n</div>`n"
        $html += "</div>`n"
        $html += "<div class='footer'>`n<p><strong>FRB Package Creation Tool v3.0.0</strong></p>`n<p>Integrated Installation Validation</p>`n<p>Report Generated: $((Get-Date).ToString("MMMM dd, yyyy HH:mm:ss"))</p>`n</div>`n"
        $html += "</div>`n</body>`n</html>"
        
        # Save the report
        $html | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
        
        $result.Success = $true
        $result.ReportPath = $OutputPath
        Write-Verbose "ReportEngine: Report saved to $OutputPath"
    }
    catch {
        $result.Success = $false
        $result.ErrorMessage = "Failed to generate report: $($_.Exception.Message)"
        Write-Error $result.ErrorMessage
    }
    
    return $result
}

function New-HTMLLeftoverReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [Parameter(Mandatory = $true)]
        [string]$AppVersion,
        
        [Parameter(Mandatory = $true)]
        [string]$Vendor,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$LeftoverData,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )
    
    Write-Verbose "ReportEngine: Generating leftover detection HTML report for $AppName"
    
    $result = @{
        Success = $false
        ReportPath = ""
        ErrorMessage = ""
    }
    
    try {
        # Determine status
        $statusColor = if ($LeftoverData.Found) { "#ffc107" } else { "#28a745" }
        $statusIcon = if ($LeftoverData.Found) { "[WARN]" } else { "[PASS]" }
        $statusText = if ($LeftoverData.Found) { "Leftovers Detected" } else { "Clean Uninstall" }
        
        # Build leftovers HTML
        $leftoversHTML = ""
        if ($LeftoverData.Found -and $LeftoverData.Details.Count -gt 0) {
            $folders = $LeftoverData.Details | Where-Object { $_.Type -eq "Folder" }
            $registry = $LeftoverData.Details | Where-Object { $_.Type -eq "Registry" }
            $uninstallEntries = $LeftoverData.Details | Where-Object { $_.Type -eq "Uninstall Entry" }
            
            if ($folders) {
                $leftoversHTML += "<div class='leftover-section'>`n<h3>Leftover Folders</h3>`n<div class='leftover-list'>`n"
                foreach ($folder in $folders) {
                    $leftoversHTML += "<div class='leftover-item folder'><span class='item-type'>[FOLDER]</span><span class='item-path'>$($folder.Location)</span></div>`n"
                }
                $leftoversHTML += "</div>`n</div>`n"
            }
            
            if ($registry) {
                $leftoversHTML += "<div class='leftover-section'>`n<h3>Leftover Registry Keys</h3>`n<div class='leftover-list'>`n"
                foreach ($reg in $registry) {
                    $leftoversHTML += "<div class='leftover-item registry'><span class='item-type'>[REGISTRY]</span><span class='item-path'>$($reg.Location)</span></div>`n"
                }
                $leftoversHTML += "</div>`n</div>`n"
            }
            
            if ($uninstallEntries) {
                $leftoversHTML += "<div class='leftover-section'>`n<h3>Leftover Uninstall Entries</h3>`n<div class='leftover-list'>`n"
                foreach ($entry in $uninstallEntries) {
                    $leftoversHTML += "<div class='leftover-item uninstall'><span class='item-type'>[UNINSTALL]</span><span class='item-path'>$($entry.DisplayName)</span><div class='item-detail'>$($entry.Location)</div></div>`n"
                }
                $leftoversHTML += "</div>`n</div>`n"
            }
        } else {
            $leftoversHTML = "<div class='clean-message'>`n<div class='clean-icon'>[OK]</div>`n<div class='clean-text'>No leftovers detected. The uninstallation was clean!</div>`n</div>`n"
        }
        
        # Build HTML
        $html = "<!DOCTYPE html>`n<html>`n<head>`n"
        $html += "<meta charset='UTF-8'>`n"
        $html += "<title>Leftover Detection Report - $AppName</title>`n"
        $html += "<style>`n"
        $html += "body { font-family: 'Segoe UI', Arial, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 20px; margin: 0; }`n"
        $html += ".container { max-width: 1200px; margin: 0 auto; background: white; border-radius: 12px; box-shadow: 0 20px 60px rgba(0,0,0,0.3); overflow: hidden; }`n"
        $html += ".header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 40px; text-align: center; }`n"
        $html += ".header h1 { font-size: 2.5em; margin: 0 0 10px 0; font-weight: 300; }`n"
        $html += ".status-banner { background-color: $statusColor; color: white; padding: 20px; text-align: center; font-size: 1.5em; font-weight: bold; }`n"
        $html += ".status-icon { font-size: 2em; margin-right: 10px; }`n"
        $html += ".content { padding: 40px; }`n"
        $html += ".section { margin-bottom: 40px; }`n"
        $html += ".section-title { color: #667eea; font-size: 1.8em; margin-bottom: 20px; padding-bottom: 10px; border-bottom: 3px solid #667eea; }`n"
        $html += ".info-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin-bottom: 20px; }`n"
        $html += ".info-card { background: #f8f9fa; border-left: 4px solid #667eea; padding: 20px; border-radius: 8px; }`n"
        $html += ".info-label { color: #6c757d; font-size: 0.9em; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 8px; }`n"
        $html += ".info-value { font-size: 1.1em; color: #212529; word-break: break-all; }`n"
        $html += ".leftover-section { margin-bottom: 30px; }`n"
        $html += ".leftover-section h3 { color: #495057; font-size: 1.3em; margin-bottom: 15px; }`n"
        $html += ".leftover-list { background: #f8f9fa; padding: 20px; border-radius: 8px; border: 1px solid #dee2e6; }`n"
        $html += ".leftover-item { background: white; margin-bottom: 10px; padding: 15px; border-left: 4px solid #ffc107; border-radius: 4px; font-family: 'Consolas', 'Courier New', monospace; font-size: 0.9em; }`n"
        $html += ".leftover-item.folder { border-left-color: #ff6b6b; }`n"
        $html += ".leftover-item.registry { border-left-color: #ffc107; }`n"
        $html += ".leftover-item.uninstall { border-left-color: #f39c12; }`n"
        $html += ".leftover-item .item-type { display: inline-block; padding: 3px 10px; background: #ffc107; color: white; border-radius: 3px; font-size: 0.75em; margin-right: 10px; font-weight: bold; }`n"
        $html += ".leftover-item.folder .item-type { background: #ff6b6b; }`n"
        $html += ".leftover-item.registry .item-type { background: #ffc107; }`n"
        $html += ".leftover-item.uninstall .item-type { background: #f39c12; }`n"
        $html += ".leftover-item .item-path { color: #495057; word-break: break-all; }`n"
        $html += ".leftover-item .item-detail { margin-top: 8px; font-size: 0.85em; color: #6c757d; padding-left: 75px; }`n"
        $html += ".clean-message { background: linear-gradient(135deg, #28a745, #20c997); color: white; padding: 60px; text-align: center; border-radius: 12px; box-shadow: 0 10px 30px rgba(40, 167, 69, 0.3); }`n"
        $html += ".cleanup-section { background: #e7f3ff; border: 2px solid #0066cc; border-radius: 8px; padding: 20px; margin-bottom: 30px; }`n"
        $html += ".cleanup-header { color: #0066cc; font-size: 1.5em; margin-bottom: 15px; font-weight: bold; }`n"
        $html += ".cleanup-summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-bottom: 20px; }`n"
        $html += ".cleanup-stat { background: white; padding: 15px; border-radius: 6px; text-align: center; border-left: 4px solid #0066cc; }`n"
        $html += ".cleanup-stat.success { border-left-color: #28a745; }`n"
        $html += ".cleanup-stat.failed { border-left-color: #dc3545; }`n"
        $html += ".cleanup-stat-value { font-size: 2em; font-weight: bold; color: #0066cc; }`n"
        $html += ".cleanup-stat.success .cleanup-stat-value { color: #28a745; }`n"
        $html += ".cleanup-stat.failed .cleanup-stat-value { color: #dc3545; }`n"
        $html += ".cleanup-stat-label { font-size: 0.9em; color: #6c757d; text-transform: uppercase; letter-spacing: 1px; margin-top: 5px; }`n"
        $html += ".cleanup-items { background: white; padding: 15px; border-radius: 6px; margin-top: 15px; }`n"
        $html += ".cleanup-item { padding: 10px; margin-bottom: 8px; border-left: 3px solid #28a745; background: #f8f9fa; border-radius: 4px; font-family: 'Consolas', monospace; font-size: 0.85em; }`n"
        $html += ".cleanup-item.failed { border-left-color: #dc3545; }`n"
        $html += ".cleanup-item-type { display: inline-block; padding: 2px 8px; background: #28a745; color: white; border-radius: 3px; font-size: 0.75em; margin-right: 8px; }`n"
        $html += ".cleanup-item.failed .cleanup-item-type { background: #dc3545; }`n"
        $html += ".cleanup-item-error { margin-top: 5px; color: #dc3545; font-size: 0.8em; padding-left: 75px; }`n"
        $html += ".clean-icon { font-size: 4em; margin-bottom: 20px; }`n"
        $html += ".clean-text { font-size: 1.5em; font-weight: 300; }`n"
        $html += ".footer { background: #f8f9fa; padding: 30px; text-align: center; color: #6c757d; border-top: 1px solid #dee2e6; }`n"
        $html += "</style>`n</head>`n<body>`n"
        $html += "<div class='container'>`n"
        $html += "<div class='header'>`n<h1>Uninstallation Leftover Detection Report</h1>`n<div>$AppName $AppVersion</div>`n</div>`n"
        $html += "<div class='status-banner'>`n<span class='status-icon'>$statusIcon</span>`n$statusText`n</div>`n"
        $html += "<div class='content'>`n"
        $html += "<div class='section'>`n<h2 class='section-title'>Software Information</h2>`n"
        $html += "<div class='info-grid'>`n"
        $html += "<div class='info-card'><div class='info-label'>Software Name</div><div class='info-value'>$AppName</div></div>`n"
        $html += "<div class='info-card'><div class='info-label'>Version</div><div class='info-value'>$AppVersion</div></div>`n"
        $html += "<div class='info-card'><div class='info-label'>Vendor</div><div class='info-value'>$Vendor</div></div>`n"
        $html += "<div class='info-card'><div class='info-label'>Scan Date</div><div class='info-value'>$((Get-Date).ToString("MMMM dd, yyyy HH:mm:ss"))</div></div>`n"
        $html += "<div class='info-card'><div class='info-label'>Leftovers Found</div><div class='info-value'>$(if ($LeftoverData.Found) { $LeftoverData.Details.Count } else { "0" })</div></div>`n"
        $html += "</div>`n</div>`n"
        $html += "<div class='section'>`n<h2 class='section-title'>Leftover Detection Results</h2>`n$leftoversHTML`n</div>`n"
        $html += "</div>`n"
        $html += "<div class='footer'>`n<p><strong>FRB Package Creation Tool v3.0.0</strong></p>`n<p>Integrated Leftover Detection</p>`n<p>Report Generated: $((Get-Date).ToString("MMMM dd, yyyy HH:mm:ss"))</p>`n</div>`n"
        $html += "</div>`n</body>`n</html>"
        
        # Save the report
        $html | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
        
        $result.Success = $true
        $result.ReportPath = $OutputPath
        Write-Verbose "ReportEngine: Leftover report saved to $OutputPath"
    }
    catch {
        $result.Success = $false
        $result.ErrorMessage = "Failed to generate leftover report: $($_.Exception.Message)"
        Write-Error $result.ErrorMessage
    }
    
    return $result
}

function New-HTMLUninstallReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [Parameter(Mandatory = $true)]
        [string]$AppVersion,
        
        [Parameter(Mandatory = $true)]
        [string]$Vendor,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$LeftoverData,
        
        [Parameter(Mandatory = $true)]
        [string]$UninstallCommand,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$CleanupResults = $null
    )
    
    Write-Verbose "ReportEngine: Generating uninstall HTML report for $AppName"
    
    $result = @{
        Success = $false
        ReportPath = ""
        ErrorMessage = ""
    }
    
    try {
        # Determine status
        $statusColor = if ($LeftoverData.Found) { "#ffc107" } else { "#28a745" }
        $statusIcon = if ($LeftoverData.Found) { "[WARN]" } else { "[PASS]" }
        $statusText = if ($LeftoverData.Found) { "Leftovers Detected" } else { "Clean Uninstall" }
        
        # Build leftovers HTML
        $leftoversHTML = ""
        if ($LeftoverData.Found -and $LeftoverData.Details.Count -gt 0) {
            $folders = $LeftoverData.Details | Where-Object { $_.Type -eq "Folder" }
            $registry = $LeftoverData.Details | Where-Object { $_.Type -eq "Registry" }
            $uninstallEntries = $LeftoverData.Details | Where-Object { $_.Type -eq "Uninstall Entry" }
            
            if ($folders) {
                $leftoversHTML += "<div class='leftover-section'>`n<h3>Leftover Folders ($($folders.Count))</h3>`n<div class='leftover-list'>`n"
                foreach ($folder in $folders) {
                    $leftoversHTML += "<div class='leftover-item folder'><span class='item-type'>[FOLDER]</span><span class='item-path'>$($folder.Location)</span></div>`n"
                }
                $leftoversHTML += "</div>`n</div>`n"
            }
            
            if ($registry) {
                $leftoversHTML += "<div class='leftover-section'>`n<h3>Leftover Registry Keys ($($registry.Count))</h3>`n<div class='leftover-list'>`n"
                foreach ($reg in $registry) {
                    $leftoversHTML += "<div class='leftover-item registry'><span class='item-type'>[REGISTRY]</span><span class='item-path'>$($reg.Location)</span></div>`n"
                }
                $leftoversHTML += "</div>`n</div>`n"
            }
            
            if ($uninstallEntries) {
                $leftoversHTML += "<div class='leftover-section'>`n<h3>Leftover Uninstall Entries ($($uninstallEntries.Count))</h3>`n<div class='leftover-list'>`n"
                foreach ($entry in $uninstallEntries) {
                    $leftoversHTML += "<div class='leftover-item uninstall'><span class='item-type'>[UNINSTALL]</span><span class='item-path'>$($entry.DisplayName)</span><div class='item-detail'>$($entry.Location)</div></div>`n"
                }
                $leftoversHTML += "</div>`n</div>`n"
            }
        } else {
            $leftoversHTML = "<div class='clean-message'>`n<div class='clean-icon'>[OK]</div>`n<div class='clean-text'>No leftovers detected. The uninstallation was clean!</div>`n</div>`n"
        }
        
        # Get OS info
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        $osCaption = if ($os) { $os.Caption } else { "Unknown" }
        $osArch = if ($os) { $os.OSArchitecture } else { "Unknown" }
        $osVersion = if ($os) { $os.Version } else { "Unknown" }
        
        # Get computer info
        $computerInfo = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
        $manufacturer = if ($computerInfo) { $computerInfo.Manufacturer } else { "Unknown" }
        $model = if ($computerInfo) { $computerInfo.Model } else { "Unknown" }
        
        # Build HTML
        $html = "<!DOCTYPE html>`n<html>`n<head>`n"
        $html += "<meta charset='UTF-8'>`n"
        $html += "<title>Uninstallation Report - $AppName</title>`n"
        $html += "<style>`n"
        $html += "body { font-family: 'Segoe UI', Arial, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 20px; margin: 0; }`n"
        $html += ".container { max-width: 1200px; margin: 0 auto; background: white; border-radius: 12px; box-shadow: 0 20px 60px rgba(0,0,0,0.3); overflow: hidden; }`n"
        $html += ".header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 40px; text-align: center; }`n"
        $html += ".header h1 { font-size: 2.5em; margin: 0 0 10px 0; font-weight: 300; }`n"
        $html += ".status-banner { background-color: $statusColor; color: white; padding: 20px; text-align: center; font-size: 1.5em; font-weight: bold; }`n"
        $html += ".status-icon { font-size: 2em; margin-right: 10px; }`n"
        $html += ".content { padding: 40px; }`n"
        $html += ".section { margin-bottom: 40px; }`n"
        $html += ".section-title { color: #667eea; font-size: 1.8em; margin-bottom: 20px; padding-bottom: 10px; border-bottom: 3px solid #667eea; }`n"
        $html += ".info-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin-bottom: 20px; }`n"
        $html += ".info-card { background: #f8f9fa; border-left: 4px solid #667eea; padding: 20px; border-radius: 8px; }`n"
        $html += ".info-label { color: #6c757d; font-size: 0.9em; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 8px; }`n"
        $html += ".info-value { font-size: 1.1em; color: #212529; word-break: break-all; white-space: pre-wrap; }`n"
        $html += ".command-box { background: #2d2d2d; color: #f8f8f2; padding: 20px; border-radius: 8px; font-family: 'Consolas', 'Courier New', monospace; font-size: 0.95em; margin-top: 15px; border-left: 4px solid #667eea; overflow-x: auto; }`n"
        $html += ".leftover-section { margin-bottom: 30px; }`n"
        $html += ".leftover-section h3 { color: #495057; font-size: 1.3em; margin-bottom: 15px; }`n"
        $html += ".leftover-list { background: #f8f9fa; padding: 20px; border-radius: 8px; border: 1px solid #dee2e6; max-height: 400px; overflow-y: auto; }`n"
        $html += ".leftover-item { background: white; margin-bottom: 10px; padding: 15px; border-left: 4px solid #ffc107; border-radius: 4px; font-family: 'Consolas', 'Courier New', monospace; font-size: 0.9em; }`n"
        $html += ".leftover-item.folder { border-left-color: #ff6b6b; }`n"
        $html += ".leftover-item.registry { border-left-color: #ffc107; }`n"
        $html += ".leftover-item.uninstall { border-left-color: #f39c12; }`n"
        $html += ".leftover-item .item-type { display: inline-block; padding: 3px 10px; background: #ffc107; color: white; border-radius: 3px; font-size: 0.75em; margin-right: 10px; font-weight: bold; }`n"
        $html += ".leftover-item.folder .item-type { background: #ff6b6b; }`n"
        $html += ".leftover-item.registry .item-type { background: #ffc107; }`n"
        $html += ".leftover-item.uninstall .item-type { background: #f39c12; }`n"
        $html += ".leftover-item .item-path { color: #495057; word-break: break-all; }`n"
        $html += ".leftover-item .item-detail { margin-top: 8px; font-size: 0.85em; color: #6c757d; padding-left: 75px; }`n"
        $html += ".clean-message { background: linear-gradient(135deg, #28a745, #20c997); color: white; padding: 60px; text-align: center; border-radius: 12px; box-shadow: 0 10px 30px rgba(40, 167, 69, 0.3); }`n"
        $html += ".cleanup-section { background: #e7f3ff; border: 2px solid #0066cc; border-radius: 8px; padding: 20px; margin-bottom: 30px; }`n"
        $html += ".cleanup-header { color: #0066cc; font-size: 1.5em; margin-bottom: 15px; font-weight: bold; }`n"
        $html += ".cleanup-summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-bottom: 20px; }`n"
        $html += ".cleanup-stat { background: white; padding: 15px; border-radius: 6px; text-align: center; border-left: 4px solid #0066cc; }`n"
        $html += ".cleanup-stat.success { border-left-color: #28a745; }`n"
        $html += ".cleanup-stat.failed { border-left-color: #dc3545; }`n"
        $html += ".cleanup-stat-value { font-size: 2em; font-weight: bold; color: #0066cc; }`n"
        $html += ".cleanup-stat.success .cleanup-stat-value { color: #28a745; }`n"
        $html += ".cleanup-stat.failed .cleanup-stat-value { color: #dc3545; }`n"
        $html += ".cleanup-stat-label { font-size: 0.9em; color: #6c757d; text-transform: uppercase; letter-spacing: 1px; margin-top: 5px; }`n"
        $html += ".cleanup-items { background: white; padding: 15px; border-radius: 6px; margin-top: 15px; }`n"
        $html += ".cleanup-item { padding: 10px; margin-bottom: 8px; border-left: 3px solid #28a745; background: #f8f9fa; border-radius: 4px; font-family: 'Consolas', monospace; font-size: 0.85em; }`n"
        $html += ".cleanup-item.failed { border-left-color: #dc3545; }`n"
        $html += ".cleanup-item-type { display: inline-block; padding: 2px 8px; background: #28a745; color: white; border-radius: 3px; font-size: 0.75em; margin-right: 8px; }`n"
        $html += ".cleanup-item.failed .cleanup-item-type { background: #dc3545; }`n"
        $html += ".cleanup-item-error { margin-top: 5px; color: #dc3545; font-size: 0.8em; padding-left: 75px; }`n"
        $html += ".clean-icon { font-size: 4em; margin-bottom: 20px; }`n"
        $html += ".clean-text { font-size: 1.5em; font-weight: 300; }`n"
        $html += ".footer { background: #f8f9fa; padding: 30px; text-align: center; color: #6c757d; border-top: 1px solid #dee2e6; }`n"
        $html += "</style>`n</head>`n<body>`n"
        $html += "<div class='container'>`n"
        $html += "<div class='header'>`n<h1>Software Uninstallation Report</h1>`n<div>$AppName $AppVersion</div>`n</div>`n"
        $html += "<div class='status-banner'>`n<span class='status-icon'>$statusIcon</span>`n$statusText`n</div>`n"
        $html += "<div class='content'>`n"
        $html += "<div class='section'>`n<h2 class='section-title'>Application Information</h2>`n"
        $html += "<div class='info-grid'>`n"
        $html += "<div class='info-card'><div class='info-label'>Software Name</div><div class='info-value'>$AppName</div></div>`n"
        $html += "<div class='info-card'><div class='info-label'>Version</div><div class='info-value'>$AppVersion</div></div>`n"
        $html += "<div class='info-card'><div class='info-label'>Vendor</div><div class='info-value'>$Vendor</div></div>`n"
        $html += "<div class='info-card'><div class='info-label'>Uninstall Date</div><div class='info-value'>$((Get-Date).ToString("MMMM dd, yyyy HH:mm:ss"))</div></div>`n"
        $html += "<div class='info-card'><div class='info-label'>Leftovers Found</div><div class='info-value'>$(if ($LeftoverData.Found) { $LeftoverData.Details.Count } else { "0" })</div></div>`n"
        $html += "<div class='info-card'><div class='info-label'>Technician</div><div class='info-value'>$env:USERNAME</div></div>`n"
        $html += "</div>`n</div>`n"
        $html += "<div class='section'>`n<h2 class='section-title'>Uninstall Command Used</h2>`n"
        $html += "<div class='info-card'><div class='info-label'>Command</div><div class='command-box'>$UninstallCommand</div></div>`n"
        $html += "</div>`n"
        
        # Add cleanup section if cleanup was performed
        if ($CleanupResults -ne $null) {
            $html += "<div class='section'>`n<div class='cleanup-section'>`n"
            $html += "<div class='cleanup-header'>[CLEANUP] Leftover Removal Process</div>`n"
            $html += "<div class='cleanup-summary'>`n"
            $html += "<div class='cleanup-stat success'><div class='cleanup-stat-value'>$($CleanupResults.TotalCleaned)</div><div class='cleanup-stat-label'>Items Removed</div></div>`n"
            if ($CleanupResults.TotalFailed -gt 0) {
                $html += "<div class='cleanup-stat failed'><div class='cleanup-stat-value'>$($CleanupResults.TotalFailed)</div><div class='cleanup-stat-label'>Items Failed</div></div>`n"
            }
            $html += "</div>`n"
            
            # Show successfully cleaned items
            if ($CleanupResults.CleanedItems -and $CleanupResults.CleanedItems.Count -gt 0) {
                $html += "<h3 style='color:#28a745;margin-top:20px;'>Successfully Removed</h3>`n"
                $html += "<div class='cleanup-items'>`n"
                foreach ($item in $CleanupResults.CleanedItems) {
                    $html += "<div class='cleanup-item'><span class='cleanup-item-type'>[$($item.Type.ToUpper())]</span>$($item.Location)</div>`n"
                }
                $html += "</div>`n"
            }
            
            # Show failed items if any
            if ($CleanupResults.FailedItems -and $CleanupResults.FailedItems.Count -gt 0) {
                $html += "<h3 style='color:#dc3545;margin-top:20px;'>Failed to Remove</h3>`n"
                $html += "<div class='cleanup-items'>`n"
                foreach ($item in $CleanupResults.FailedItems) {
                    $html += "<div class='cleanup-item failed'><span class='cleanup-item-type'>[$($item.Type.ToUpper())]</span>$($item.Location)"
                    if ($item.Error) {
                        $html += "<div class='cleanup-item-error'>Error: $($item.Error)</div>"
                    }
                    $html += "</div>`n"
                }
                $html += "</div>`n"
            }
            
            $html += "</div>`n</div>`n"
        }
        
        $html += "<div class='section'>`n<h2 class='section-title'>Leftover Detection Results</h2>`n$leftoversHTML`n</div>`n"
        $html += "<div class='section'>`n<h2 class='section-title'>System Information</h2>`n<div class='info-grid'>`n"
        $html += "<div class='info-card'><div class='info-label'>Computer Name</div><div class='info-value'>$env:COMPUTERNAME</div></div>`n"
        $html += "<div class='info-card'><div class='info-label'>User Name</div><div class='info-value'>$env:USERNAME</div></div>`n"
        $html += "<div class='info-card'><div class='info-label'>Operating System</div><div class='info-value'>$osCaption</div></div>`n"
        $html += "<div class='info-card'><div class='info-label'>OS Architecture</div><div class='info-value'>$osArch</div></div>`n"
        $html += "<div class='info-card'><div class='info-label'>OS Version</div><div class='info-value'>$osVersion</div></div>`n"
        $html += "<div class='info-card'><div class='info-label'>Manufacturer</div><div class='info-value'>$manufacturer</div></div>`n"
        $html += "<div class='info-card'><div class='info-label'>Model</div><div class='info-value'>$model</div></div>`n"
        $html += "</div>`n</div>`n"
        $html += "</div>`n"
        $html += "<div class='footer'>`n<p><strong>FRB Package Creation Tool v3.1.0</strong></p>`n<p>Integrated Uninstallation Validation</p>`n<p>Report Generated: $((Get-Date).ToString("MMMM dd, yyyy HH:mm:ss"))</p>`n</div>`n"
        $html += "</div>`n</body>`n</html>"
        
        # Save the report
        $html | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
        
        $result.Success = $true
        $result.ReportPath = $OutputPath
        Write-Verbose "ReportEngine: Uninstall report saved to $OutputPath"
    }
    catch {
        $result.Success = $false
        $result.ErrorMessage = "Failed to generate uninstall report: $($_.Exception.Message)"
        Write-Error $result.ErrorMessage
    }
    
    return $result
}

Export-ModuleMember -Function New-HTMLValidationReport, New-HTMLLeftoverReport, New-HTMLUninstallReport
