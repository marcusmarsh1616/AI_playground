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
        
        $content = Get-Content $StartupPssPath -Raw
        
        # Define sections with their start/end markers
        $insertionPoints = @(
            @{
                Marker = "## <Perform Pre-Installation tasks here>"
                EndMarker = "##*==============================================="
                CommandKey = "PreInstall"
                Description = "Pre-Installation Commands"
            },
            @{
                Marker = "#region <Perform Installation tasks here>"
                EndMarker = "#endregion"
                CommandKey = "CustomInstall"
                Description = "Custom Installation Commands"
            },
            @{
                Marker = "## <Perform Post-Installation tasks here>"
                EndMarker = "##*==============================================="
                CommandKey = "PostInstall"
                Description = "Post-Installation Commands"
            },
            @{
                Marker = "## <Perform Pre-Uninstallation tasks here>"
                EndMarker = "##*==============================================="
                CommandKey = "PreUninstall"
                Description = "Pre-Uninstallation Commands"
            },
            @{
                Marker = "#region <Perform Uninstallation tasks here>"
                EndMarker = "#endregion"
                CommandKey = "CustomUninstall"
                Description = "Custom Uninstallation Commands"
            },
            @{
                Marker = "## <Perform Post-Uninstallation tasks here>"
                EndMarker = "##*==============================================="
                CommandKey = "PostUninstall"
                Description = "Post-Uninstallation Commands"
            }
        )
        
        # Process each section: REPLACE content between markers with GUI content
        foreach ($point in $insertionPoints) {
            $startIndex = $content.IndexOf($point.Marker)
            
            if ($startIndex -ge 0) {
                # Find the line after the marker (this is where user code starts)
                $startIndex += $point.Marker.Length
                $endIndex = $content.IndexOf($point.EndMarker, $startIndex)
                
                if ($endIndex -gt $startIndex) {
                    # Extract everything BEFORE and AFTER this section
                    $beforeSection = $content.Substring(0, $startIndex)
                    $afterSection = $content.Substring($endIndex)
                    
                    # Get commands from GUI for this section
                    $commandKey = $point.CommandKey
                    $newCommands = ""
                    
                    if ($CommandSections.ContainsKey($commandKey)) {
                        $commands = $CommandSections[$commandKey]
                        
                        if (-not [string]::IsNullOrWhiteSpace($commands)) {
                            # Format with proper indentation
                            $formattedCommands = Format-CommandSection -Commands $commands -IndentLevel 2
                            $newCommands = [Environment]::NewLine + $formattedCommands + [Environment]::NewLine + [char]9
                            $result.InsertedSections += $point.Description
                        } else {
                            # GUI has empty/cleared field - insert empty line
                            $newCommands = [Environment]::NewLine + [char]9
                        }
                    } else {
                        # No key found - insert empty line
                        $newCommands = [Environment]::NewLine + [char]9
                    }
                    
                    # REPLACE section: Before + NewCommands + After
                    $content = $beforeSection + $newCommands + $afterSection
                }
            }
        }
        
        # Write updated content back to file
        [System.IO.File]::WriteAllText($StartupPssPath, $content, [System.Text.Encoding]::UTF8)
        
        $result.Success = $true
        if ($result.InsertedSections.Count -gt 0) {
            $result.Message = "Successfully updated custom commands in $($result.InsertedSections.Count) section(s): " + ($result.InsertedSections -join ", ")
        } else {
            $result.Message = "All custom command sections cleared (GUI had no commands)"
        }
    }
    catch {
        $result.Message = "Error updating custom commands: $($_.Exception.Message)"
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
            if (-not $content.Contains($marker)) {
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
        
        # STEP 1: Extract metadata variables from VARIABLE DECLARATION section ONLY
        $inVarDeclaration = $false
        $foundUninstallExe = $false
        $foundInstallCmd = $false
        $foundUninstallCmd = $false
        
        foreach ($line in $lines) {
            # Find section boundaries
            if ($line.Contains("VARIABLE DECLARATION")) {
                $inVarDeclaration = $true
                continue
            }
            if ($line.Contains("END VARIABLE DECLARATION")) {
                break  # Stop looking after this section
            }
            
            # Only extract if we are inside VARIABLE DECLARATION section
            if ($inVarDeclaration) {
                if (-not $foundUninstallExe -and $line.Contains("[string]`$appUninstallExeName")) {
                    $startQuote = $line.IndexOf("'") + 1
                    $endQuote = $line.IndexOf("'", $startQuote)
                    if ($startQuote -gt 0 -and $endQuote -gt $startQuote) {
                        $result.AppUninstallExeName = $line.Substring($startQuote, $endQuote - $startQuote)
                    }
                    $foundUninstallExe = $true
                }
                elseif (-not $foundInstallCmd -and $line.Contains("[string]`$appInstallCommandLine")) {
                    $startQuote = $line.IndexOf("'") + 1
                    $endQuote = $line.IndexOf("'", $startQuote)
                    if ($startQuote -gt 0 -and $endQuote -gt $startQuote) {
                        $result.AppInstallCommandLine = $line.Substring($startQuote, $endQuote - $startQuote)
                    }
                    $foundInstallCmd = $true
                }
                elseif (-not $foundUninstallCmd -and $line.Contains("[string]`$appUninstallCommandLine")) {
                    $startQuote = $line.IndexOf("'") + 1
                    $endQuote = $line.IndexOf("'", $startQuote)
                    if ($startQuote -gt 0 -and $endQuote -gt $startQuote) {
                        $result.AppUninstallCommandLine = $line.Substring($startQuote, $endQuote - $startQuote)
                    }
                    $foundUninstallCmd = $true
                }
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
