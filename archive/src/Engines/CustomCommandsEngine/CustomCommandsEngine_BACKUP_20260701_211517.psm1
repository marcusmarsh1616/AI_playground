<#
.SYNOPSIS
    Custom Commands Engine for PSADTWrapper Integration
.DESCRIPTION
    Handles insertion of custom PowerShell commands into Startup.pss at 6 defined insertion points
.NOTES
    Author: FRB Automation Team
    Created: December 2024
    Version: 1.0.0
#>

#region Functions

function Add-CustomCommandsToStartupPss {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StartupPssPath,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$CommandSections
    )
    
    $result = @{
        Success = $false
        Message = ""
        InsertedSections = @()
    }
    
    try {
        if (-not (Test-Path $StartupPssPath)) {
            $result.Message = "Startup.pss not found at: $StartupPssPath"
            return $result
        }
        
        $lines = Get-Content $StartupPssPath
        
        $insertionPoints = @(
            @{
                Marker = "## <Perform Pre-Installation tasks here>"
                CommandKey = "PreInstall"
                Description = "Pre-Installation Commands"
            },
            @{
                Marker = "#region <Perform Installation tasks here>"
                CommandKey = "CustomInstall"
                Description = "Custom Installation Commands"
            },
            @{
                Marker = "## <Perform Post-Installation tasks here>"
                CommandKey = "PostInstall"
                Description = "Post-Installation Commands"
            },
            @{
                Marker = "## <Perform Pre-Uninstallation tasks here>"
                CommandKey = "PreUninstall"
                Description = "Pre-Uninstallation Commands"
            },
            @{
                Marker = "#region <Perform Uninstallation tasks here>"
                CommandKey = "CustomUninstall"
                Description = "Custom Uninstallation Commands"
            },
            @{
                Marker = "## <Perform Post-Uninstallation tasks here>"
                CommandKey = "PostUninstall"
                Description = "Post-Uninstallation Commands"
            }
        )
        
        $newLines = @()
        
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $currentLine = $lines[$i]
            $newLines += $currentLine
            
            foreach ($point in $insertionPoints) {
                if ($currentLine.Trim() -eq $point.Marker) {
                    $commandKey = $point.CommandKey
                    
                    if ($CommandSections.ContainsKey($commandKey)) {
                        $commands = $CommandSections[$commandKey]
                        
                        if (-not [string]::IsNullOrWhiteSpace($commands)) {
                            $formattedCommands = Format-CommandSection -Commands $commands -IndentLevel 2
                            $commandLines = $formattedCommands -split [Environment]::NewLine
                            $newLines += $commandLines
                            $result.InsertedSections += $point.Description
                        }
                    }
                    break
                }
            }
        }
        
        $newLines | Set-Content -Path $StartupPssPath -Force
        
        $result.Success = $true
        if ($result.InsertedSections.Count -gt 0) {
            $result.Message = "Successfully inserted custom commands into $($result.InsertedSections.Count) section(s): " + ($result.InsertedSections -join ", ")
        } else {
            $result.Message = "No custom commands to insert (all sections were empty)"
        }
    }
    catch {
        $result.Message = "Error inserting custom commands: $($_.Exception.Message)"
    }
    
    return $result
}

function Format-CommandSection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Commands,
        
        [Parameter(Mandatory = $false)]
        [int]$IndentLevel = 2
    )
    
    # Build indent string (PowerShell 5.1 compatible)
    $indent = ""
    for ($i = 0; $i -lt $IndentLevel; $i++) {
        $indent += [char]9
    }
    
    $lines = $Commands -split [Environment]::NewLine
    
    $formattedLines = foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            ""
        } else {
            $trimmedLine = $line.TrimStart()
            "$indent$trimmedLine"
        }
    }
    
    return ($formattedLines -join [Environment]::NewLine)
}

function Test-StartupPssMarkers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StartupPssPath
    )
    
    $result = @{
        Valid = $false
        MissingMarkers = @()
        Message = ""
    }
    
    try {
        if (-not (Test-Path $StartupPssPath)) {
            $result.Message = "Startup.pss not found at: $StartupPssPath"
            return $result
        }
        
        $content = Get-Content $StartupPssPath -Raw
        
        $requiredMarkers = @(
            "## <Perform Pre-Installation tasks here>",
            "#region <Perform Installation tasks here>",
            "## <Perform Post-Installation tasks here>",
            "## <Perform Pre-Uninstallation tasks here>",
            "#region <Perform Uninstallation tasks here>",
            "## <Perform Post-Uninstallation tasks here>"
        )
        
        foreach ($marker in $requiredMarkers) {
            if ($content -notmatch [regex]::Escape($marker)) {
                $result.MissingMarkers += $marker
            }
        }
        
        if ($result.MissingMarkers.Count -eq 0) {
            $result.Valid = $true
            $result.Message = "All 6 custom command markers found in Startup.pss"
        } else {
            $result.Message = "Missing $($result.MissingMarkers.Count) marker(s) in Startup.pss:" + [Environment]::NewLine + "- " + ($result.MissingMarkers -join ([Environment]::NewLine + "- "))
        }
    }
    catch {
        $result.Message = "Error validating markers: $($_.Exception.Message)"
    }
    
    return $result
}

function Save-StartupPss {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StartupPssPath
    )
    
    $result = @{
        Success = $false
        BackupPath = ""
        Message = ""
    }
    
    try {
        if (-not (Test-Path $StartupPssPath)) {
            $result.Message = "Startup.pss not found at: $StartupPssPath"
            return $result
        }
        
        $directory = Split-Path $StartupPssPath -Parent
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupFileName = "Startup_backup_$timestamp.pss"
        $backupPath = Join-Path $directory $backupFileName
        
        Copy-Item -Path $StartupPssPath -Destination $backupPath -Force
        
        $result.Success = $true
        $result.BackupPath = $backupPath
        $result.Message = "Backup created: $backupFileName"
    }
    catch {
        $result.Message = "Error creating backup: $($_.Exception.Message)"
    }
    
    return $result
}

function Get-CustomCommandsFromStartupPss {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StartupPssPath
    )
    
    $result = @{
        PreInstall = ""
        CustomInstall = ""
        PostInstall = ""
        PreUninstall = ""
        CustomUninstall = ""
        PostUninstall = ""
        AppUninstallExeName = ""
        AppInstallCommandLine = ""
        AppUninstallCommandLine = ""
    }
    
    try {
        if (-not (Test-Path $StartupPssPath)) {
            return $result
        }
        
        $content = Get-Content $StartupPssPath -Raw
        $lines = Get-Content $StartupPssPath
        
        # STEP 1: Extract metadata variables from VARIABLE DECLARATION section
        # Look for pattern: [string]$variableName = 'value'
        foreach ($line in $lines) {
            if ($line -match "\[string\]\s*\`$appUninstallExeName\s*=\s*'([^']*)'") {
                $result.AppUninstallExeName = $matches[1]
            }
            elseif ($line -match "\[string\]\s*\`$appInstallCommandLine\s*=\s*'([^']*)'") {
                $result.AppInstallCommandLine = $matches[1]
            }
            elseif ($line -match "\[string\]\s*\`$appUninstallCommandLine\s*=\s*'([^']*)'") {
                $result.AppUninstallCommandLine = $matches[1]
            }
        }
        
        # STEP 2: Extract custom commands from 6 sections
        # Template code markers - code that starts with these is template code, NOT user code
        $templateMarkers = @(
            "## Installer is MSI",
            "## Uninstaller is Setup"
        )
        
        $extractionPoints = @(
            @{
                Marker = "## <Perform Pre-Installation tasks here>"
                EndMarker = "##*==============================================="
                CommandKey = "PreInstall"
                HasTemplateCode = $false
            },
            @{
                Marker = "#region <Perform Installation tasks here>"
                EndMarker = "#endregion"
                CommandKey = "CustomInstall"
                HasTemplateCode = $true
                TemplateStartMarker = "## Installer is MSI"
            },
            @{
                Marker = "## <Perform Post-Installation tasks here>"
                EndMarker = "##*==============================================="
                CommandKey = "PostInstall"
                HasTemplateCode = $false
            },
            @{
                Marker = "## <Perform Pre-Uninstallation tasks here>"
                EndMarker = "##*==============================================="
                CommandKey = "PreUninstall"
                HasTemplateCode = $false
            },
            @{
                Marker = "#region <Perform Uninstallation tasks here>"
                EndMarker = "#endregion"
                CommandKey = "CustomUninstall"
                HasTemplateCode = $true
                TemplateStartMarker = "## Uninstaller is Setup"
            },
            @{
                Marker = "## <Perform Post-Uninstallation tasks here>"
                EndMarker = "##*==============================================="
                CommandKey = "PostUninstall"
                HasTemplateCode = $false
            }
        )
        
        foreach ($point in $extractionPoints) {
            $startIndex = $content.IndexOf($point.Marker)
            if ($startIndex -ge 0) {
                $startIndex += $point.Marker.Length
                $endIndex = $content.IndexOf($point.EndMarker, $startIndex)
                
                if ($endIndex -gt $startIndex) {
                    $sectionContent = $content.Substring($startIndex, $endIndex - $startIndex)
                    
                    # If this section has template code, find where it starts
                    if ($point.HasTemplateCode -and $point.TemplateStartMarker) {
                        $templateStartIndex = $sectionContent.IndexOf($point.TemplateStartMarker)
                        if ($templateStartIndex -gt 0) {
                            # Extract only the user code (before template marker)
                            $sectionContent = $sectionContent.Substring(0, $templateStartIndex)
                        }
                    }
                    
                    $sectionContent = $sectionContent.Trim()
                    
                    if (-not [string]::IsNullOrWhiteSpace($sectionContent)) {
                        $sectionLines = $sectionContent -split [Environment]::NewLine
                        $cleanedLines = @()
                        
                        foreach ($line in $sectionLines) {
                            $trimmed = $line.TrimStart()
                            if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
                                $cleanedLines += $trimmed
                            }
                        }
                        
                        if ($cleanedLines.Count -gt 0) {
                            $result[$point.CommandKey] = ($cleanedLines -join [Environment]::NewLine)
                        }
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Error extracting custom commands: $($_.Exception.Message)"
    }
    
    return $result
}

#endregion Functions

Export-ModuleMember -Function Add-CustomCommandsToStartupPss, Format-CommandSection, Test-StartupPssMarkers, Save-StartupPss, Get-CustomCommandsFromStartupPss
