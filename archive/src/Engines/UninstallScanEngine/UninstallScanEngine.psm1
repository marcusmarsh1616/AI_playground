<#
.SYNOPSIS
    Uninstall Scan Engine - Detects leftover files and registry entries after uninstallation
.DESCRIPTION
    Scans the system for remnants of uninstalled software including:
    - Program Files folders
    - AppData folders (Local, Roaming, LocalLow)
    - Registry entries (Uninstall, App Paths, etc.)
    - Start Menu shortcuts
.NOTES
    Engine: UninstallScanEngine
    Version: 1.0.0
    Part of: FRB Package Creation Tool
#>

function Get-UninstallLeftovers {
    <#
    .SYNOPSIS
        Scans for leftover files and registry entries after uninstallation
    .PARAMETER SoftwareName
        Name of the software to scan for
    .PARAMETER Vendor
        Vendor/Publisher name
    .RETURNS
        Hashtable with Files, RegistryKeys, Shortcuts arrays
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SoftwareName,
        
        [string]$Vendor
    )
    
    $result = @{
        Files = @()
        RegistryKeys = @()
        Shortcuts = @()
        ScanTime = Get-Date
    }
    
    # Build search terms
    $searchTerms = @($SoftwareName)
    if (-not [string]::IsNullOrWhiteSpace($Vendor)) {
        $searchTerms += $Vendor
    }
    
    Write-Verbose "Scanning for leftovers: $($searchTerms -join ', ')"
    
    # 1. SCAN FILESYSTEM
    $foldersToScan = @(
        "${env:ProgramFiles}",
        "${env:ProgramFiles(x86)}",
        "${env:ProgramData}",
        "${env:LOCALAPPDATA}",
        "${env:APPDATA}",
        "${env:PUBLIC}\Desktop",
        "${env:ALLUSERSPROFILE}\Start Menu\Programs"
    )
    
    foreach ($folder in $foldersToScan) {
        if (Test-Path $folder) {
            Write-Verbose "Scanning folder: $folder"
            
            foreach ($term in $searchTerms) {
                try {
                    # Search for folders matching software name
                    $foundFolders = Get-ChildItem -Path $folder -Directory -Recurse -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -like "*$term*" } |
                        Select-Object -First 50  # Limit to prevent massive results
                    
                    foreach ($foundFolder in $foundFolders) {
                        # Check if folder has contents
                        $fileCount = (Get-ChildItem -Path $foundFolder.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
                        
                        $result.Files += [PSCustomObject]@{
                            Path = $foundFolder.FullName
                            Type = "Folder"
                            FileCount = $fileCount
                            Size = (Get-ChildItem -Path $foundFolder.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                            LastModified = $foundFolder.LastWriteTime
                        }
                    }
                    
                    # Search for shortcut files
                    $foundShortcuts = Get-ChildItem -Path $folder -Filter "*.lnk" -Recurse -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -like "*$term*" }
                    
                    foreach ($shortcut in $foundShortcuts) {
                        $result.Shortcuts += [PSCustomObject]@{
                            Path = $shortcut.FullName
                            Name = $shortcut.Name
                            LastModified = $shortcut.LastWriteTime
                        }
                    }
                }
                catch {
                    Write-Verbose "Error scanning $folder : $($_.Exception.Message)"
                }
            }
        }
    }
    
    # 2. SCAN REGISTRY
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths",
        "HKCU:\SOFTWARE",
        "HKLM:\SOFTWARE"
    )
    
    foreach ($regPath in $registryPaths) {
        if (Test-Path $regPath) {
            Write-Verbose "Scanning registry: $regPath"
            
            foreach ($term in $searchTerms) {
                try {
                    # Search for registry keys matching software name
                    $foundKeys = Get-ChildItem -Path $regPath -Recurse -ErrorAction SilentlyContinue |
                        Where-Object { $_.PSChildName -like "*$term*" -or $_.Name -like "*$term*" } |
                        Select-Object -First 50  # Limit results
                    
                    foreach ($key in $foundKeys) {
                        # Get key properties
                        $properties = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue
                        $displayName = $properties.DisplayName
                        $publisher = $properties.Publisher
                        $version = $properties.DisplayVersion
                        
                        $result.RegistryKeys += [PSCustomObject]@{
                            Path = $key.Name
                            DisplayName = $displayName
                            Publisher = $publisher
                            Version = $version
                            ValueCount = ($key.GetValueNames()).Count
                        }
                    }
                }
                catch {
                    Write-Verbose "Error scanning registry $regPath : $($_.Exception.Message)"
                }
            }
        }
    }
    
    Write-Verbose "Scan complete. Files: $($result.Files.Count), Registry: $($result.RegistryKeys.Count), Shortcuts: $($result.Shortcuts.Count)"
    
    return $result
}

function New-LeftoverReport {
    <#
    .SYNOPSIS
        Generates HTML report of leftover items
    .PARAMETER LeftoverData
        Data from Get-UninstallLeftovers
    .PARAMETER OutputPath
        Path to save HTML report
    .PARAMETER SoftwareName
        Name of the software
    .PARAMETER Version
        Version of the software
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$LeftoverData,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [Parameter(Mandatory)]
        [string]$SoftwareName,
        
        [string]$Version
    )
    
    $hasLeftovers = ($LeftoverData.Files.Count -gt 0) -or 
                    ($LeftoverData.RegistryKeys.Count -gt 0) -or 
                    ($LeftoverData.Shortcuts.Count -gt 0)
    
    $statusColor = if ($hasLeftovers) { "#ff9800" } else { "#4caf50" }
    $statusIcon = if ($hasLeftovers) { "" } else { "" }
    $statusText = if ($hasLeftovers) { "LEFTOVERS DETECTED" } else { "CLEAN UNINSTALL" }
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Uninstall Leftover Report - $SoftwareName</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid $statusColor; padding-bottom: 10px; }
        .summary { background: $statusColor; color: white; padding: 20px; border-radius: 5px; margin: 20px 0; }
        .summary h2 { margin: 0; font-size: 24px; }
        .section { margin: 30px 0; }
        .section h3 { color: #555; border-left: 4px solid #2196f3; padding-left: 10px; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th { background: #2196f3; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        tr:hover { background: #f5f5f5; }
        .no-data { color: #999; font-style: italic; padding: 20px; text-align: center; background: #fafafa; border-radius: 5px; }
        .warning { color: #ff9800; font-weight: bold; }
        .success { color: #4caf50; font-weight: bold; }
        .path { font-family: 'Consolas', monospace; font-size: 12px; color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <h1>$statusIcon Uninstall Leftover Report</h1>
        
        <div class="summary">
            <h2>$statusText</h2>
            <p><strong>Software:</strong> $SoftwareName $(if($Version){"v$Version"})</p>
            <p><strong>Scan Date:</strong> $($LeftoverData.ScanTime.ToString('yyyy-MM-dd HH:mm:ss'))</p>
            <p><strong>Total Items Found:</strong> $(($LeftoverData.Files.Count) + ($LeftoverData.RegistryKeys.Count) + ($LeftoverData.Shortcuts.Count))</p>
        </div>
        
        <div class="section">
            <h3>- Leftover Files & Folders ($($LeftoverData.Files.Count))</h3>
"@
    
    if ($LeftoverData.Files.Count -gt 0) {
        $html += @"
            <table>
                <tr>
                    <th>Path</th>
                    <th>Type</th>
                    <th>Files</th>
                    <th>Size</th>
                    <th>Last Modified</th>
                </tr>
"@
        foreach ($file in $LeftoverData.Files) {
            $sizeFormatted = if ($file.Size) {
                if ($file.Size -gt 1MB) { "{0:N2} MB" -f ($file.Size / 1MB) }
                elseif ($file.Size -gt 1KB) { "{0:N2} KB" -f ($file.Size / 1KB) }
                else { "$($file.Size) bytes" }
            } else { "N/A" }
            
            $html += @"
                <tr>
                    <td class="path">$($file.Path)</td>
                    <td>$($file.Type)</td>
                    <td>$($file.FileCount)</td>
                    <td>$sizeFormatted</td>
                    <td>$($file.LastModified.ToString('yyyy-MM-dd HH:mm'))</td>
                </tr>
"@
        }
        $html += "</table>"
    }
    else {
        $html += '<div class="no-data success"> No leftover files or folders detected</div>'
    }
    
    $html += @"
        </div>
        
        <div class="section">
            <h3> Leftover Registry Keys ($($LeftoverData.RegistryKeys.Count))</h3>
"@
    
    if ($LeftoverData.RegistryKeys.Count -gt 0) {
        $html += @"
            <table>
                <tr>
                    <th>Registry Path</th>
                    <th>Display Name</th>
                    <th>Publisher</th>
                    <th>Version</th>
                </tr>
"@
        foreach ($regKey in $LeftoverData.RegistryKeys) {
            $html += @"
                <tr>
                    <td class="path">$($regKey.Path)</td>
                    <td>$($regKey.DisplayName)</td>
                    <td>$($regKey.Publisher)</td>
                    <td>$($regKey.Version)</td>
                </tr>
"@
        }
        $html += "</table>"
    }
    else {
        $html += '<div class="no-data success"> No leftover registry keys detected</div>'
    }
    
    $html += @"
        </div>
        
        <div class="section">
            <h3>- Leftover Shortcuts ($($LeftoverData.Shortcuts.Count))</h3>
"@
    
    if ($LeftoverData.Shortcuts.Count -gt 0) {
        $html += @"
            <table>
                <tr>
                    <th>Shortcut Path</th>
                    <th>Name</th>
                    <th>Last Modified</th>
                </tr>
"@
        foreach ($shortcut in $LeftoverData.Shortcuts) {
            $html += @"
                <tr>
                    <td class="path">$($shortcut.Path)</td>
                    <td>$($shortcut.Name)</td>
                    <td>$($shortcut.LastModified.ToString('yyyy-MM-dd HH:mm'))</td>
                </tr>
"@
        }
        $html += "</table>"
    }
    else {
        $html += '<div class="no-data success"> No leftover shortcuts detected</div>'
    }
    
    $html += @"
        </div>
        
        <div style="margin-top: 40px; padding: 20px; background: #f5f5f5; border-radius: 5px; text-align: center; color: #666;">
            <p>Generated by FRB Package Creation Tool - UninstallScanEngine</p>
        </div>
    </div>
</body>
</html>
"@
    
    Set-Content -Path $OutputPath -Value $html -Encoding UTF8
    Write-Verbose "Leftover report saved: $OutputPath"
    
    return @{
        Success = $true
        ReportPath = $OutputPath
        HasLeftovers = $hasLeftovers
    }
}

# Export functions
Export-ModuleMember -Function Get-UninstallLeftovers, New-LeftoverReport

