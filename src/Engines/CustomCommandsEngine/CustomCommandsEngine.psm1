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
        
        # Read file as line array for safe line-by-line manipulation
        $lines = Get-Content $StartupPssPath
        
        # Define sections with their markers and template code protection
        $insertionPoints = @(
            @{
                Marker = "## <Perform Pre-Installation tasks here>"
                FallbackMarker = "##* PRE-INSTALL"
                CommandKey = "PreInstall"
                Description = "Pre-Installation Commands"
                HasTemplateCode = $false
            },
            @{
                Marker = "#region <Perform Installation tasks here>"
                FallbackMarker = "##* INSTALL"
                CommandKey = "CustomInstall"
                Description = "Custom Installation Commands"
                HasTemplateCode = $true
                TemplateMarker = "## Installer is MSI"
            },
            @{
                Marker = "## <Perform Post-Installation tasks here>"
                FallbackMarker = "##* POST-INSTALL"
                CommandKey = "PostInstall"
                Description = "Post-Installation Commands"
                HasTemplateCode = $false
            },
            @{
                Marker = "## <Perform Pre-Uninstallation tasks here>"
                FallbackMarker = "##* PRE-UNINSTALL"
                CommandKey = "PreUninstall"
                Description = "Pre-Uninstallation Commands"
                HasTemplateCode = $false
            },
            @{
                Marker = "#region <Perform Uninstallation tasks here>"
                FallbackMarker = "##* UNINSTALL"
                CommandKey = "CustomUninstall"
                Description = "Custom Uninstallation Commands"
                HasTemplateCode = $true
                TemplateMarker = "## Uninstaller is Setup"
            },
            @{
                Marker = "## <Perform Post-Uninstallation tasks here>"
                FallbackMarker = "##* POST-UNINSTALL"
                CommandKey = "PostUninstall"
                Description = "Post-Uninstallation Commands"
                HasTemplateCode = $false
            }
        )
        
        # Process each section with INSERTION logic (not REPLACEMENT)
        foreach ($point in $insertionPoints) {
            # Find marker line index
            $markerIndex = -1
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i].Trim() -eq $point.Marker) {
                    $markerIndex = $i
                    break
                }
            }
            
            if ($markerIndex -lt 0) {
                continue  # Marker not found, skip this section
            }
            
            # Get user commands from GUI
            $commandKey = $point.CommandKey
            $userCommands = ""
            if ($CommandSections.ContainsKey($commandKey)) {
                $userCommands = $CommandSections[$commandKey]
            }
            
            # Find where user code currently exists (lines after marker, before template code)
            $userCodeStartIndex = $markerIndex + 1
            $userCodeEndIndex = $userCodeStartIndex
            
            # Determine where user code ends (before template marker or next section)
            if ($point.HasTemplateCode) {
                # Find template marker line
                for ($i = $userCodeStartIndex; $i -lt $lines.Count; $i++) {
                    if ($lines[$i].Trim() -eq $point.TemplateMarker) {
                        $userCodeEndIndex = $i
                        break
                    }
                }
            } else {
                # Find next section marker (##* or #endregion or ## <Perform)
                for ($i = $userCodeStartIndex; $i -lt $lines.Count; $i++) {
                    $trimmed = $lines[$i].Trim()
                    if ($trimmed.StartsWith("##*") -or $trimmed -eq "#endregion" -or $trimmed.StartsWith("## <Perform")) {
                        $userCodeEndIndex = $i
                        break
                    }
                }
            }
            
            # Remove existing user code lines (preserve empty lines structure)
            $linesToRemove = @()
            for ($i = $userCodeStartIndex; $i -lt $userCodeEndIndex; $i++) {
                $trimmed = $lines[$i].Trim()
                # Only remove lines that look like user code (indented, non-empty)
                if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
                    $linesToRemove += $i
                }
            }
            
            # Remove in reverse order to maintain indices
            for ($i = $linesToRemove.Count - 1; $i -ge 0; $i--) {
                $lines = $lines[0..($linesToRemove[$i]-1)] + $lines[($linesToRemove[$i]+1)..($lines.Count-1)]
                $userCodeEndIndex--  # Adjust end index after removal
            }
            
            # Insert new user code from GUI (if any)
            if (-not [string]::IsNullOrWhiteSpace($userCommands)) {
                $formattedCommands = Format-CommandSection -Commands $userCommands -IndentLevel 2
                $newLines = $formattedCommands -split [Environment]::NewLine
                
                # Insert blank line, user code, blank line
                $insertLines = @("") + $newLines + @("")
                
                # Insert after marker
                $insertPosition = $markerIndex + 1
                $lines = $lines[0..$markerIndex] + $insertLines + $lines[$insertPosition..($lines.Count-1)]
                
                $result.InsertedSections += $point.Description
            }
        }
        
        # Write updated content back to file
        $content = $lines -join [Environment]::NewLine
        [System.IO.File]::WriteAllText($StartupPssPath, $content, [System.Text.Encoding]::UTF8)
        
        $result.Success = $true
        if ($result.InsertedSections.Count -gt 0) {
            $result.Message = "Successfully inserted custom commands in $($result.InsertedSections.Count) section(s): " + ($result.InsertedSections -join ", ")
        } else {
            $result.Message = "No custom commands to insert (all sections empty)"
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
        
        $lines = Get-Content $StartupPssPath
        
        # STEP 1: Extract metadata variables from VARIABLE DECLARATION section ONLY
        $inVarDeclaration = $false
        $foundUninstallExe = $false
        $foundInstallCmd = $false
        $foundUninstallCmd = $false
        $assignmentRegex = '^\s*\[string\]\s*\$(?<varName>appUninstallExeName|appInstallCommandLine|appUninstallCommandLine)\s*=\s*[\x27\x22](?<value>.*?)[\x27\x22]'
        
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
                if ($line -match $assignmentRegex) {
                    $varName = $matches['varName']
                    $value = $matches['value']

                    if ($varName -eq 'appUninstallExeName' -and -not $foundUninstallExe) {
                        $result.AppUninstallExeName = $value
                        $foundUninstallExe = $true
                    }
                    elseif ($varName -eq 'appInstallCommandLine' -and -not $foundInstallCmd) {
                        $result.AppInstallCommandLine = $value
                        $foundInstallCmd = $true
                    }
                    elseif ($varName -eq 'appUninstallCommandLine' -and -not $foundUninstallCmd) {
                        $result.AppUninstallCommandLine = $value
                        $foundUninstallCmd = $true
                    }
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
                FallbackMarker = "##* PRE-INSTALL"
                EndMarker = "##*==============================================="
                FallbackEndMarker = "##* INSTALL"
                CommandKey = "PreInstall"
                HasTemplateCode = $false
            },
            @{
                Marker = "#region <Perform Installation tasks here>"
                FallbackMarker = "##* INSTALL"
                EndMarker = "#endregion"
                FallbackEndMarker = "##* END-INSTALL"
                CommandKey = "CustomInstall"
                HasTemplateCode = $true
                TemplateStartMarker = "## Installer is MSI"
            },
            @{
                Marker = "## <Perform Post-Installation tasks here>"
                FallbackMarker = "##* POST-INSTALL"
                EndMarker = "##*==============================================="
                FallbackEndMarker = "##* PRE-UNINSTALL"
                CommandKey = "PostInstall"
                HasTemplateCode = $false
            },
            @{
                Marker = "## <Perform Pre-Uninstallation tasks here>"
                FallbackMarker = "##* PRE-UNINSTALL"
                EndMarker = "##*==============================================="
                FallbackEndMarker = "##* UNINSTALL"
                CommandKey = "PreUninstall"
                HasTemplateCode = $false
            },
            @{
                Marker = "#region <Perform Uninstallation tasks here>"
                FallbackMarker = "##* UNINSTALL"
                EndMarker = "#endregion"
                FallbackEndMarker = "##* END-UNINSTALL"
                CommandKey = "CustomUninstall"
                HasTemplateCode = $true
                TemplateStartMarker = "## Uninstaller is Setup"
            },
            @{
                Marker = "## <Perform Post-Uninstallation tasks here>"
                FallbackMarker = "##* POST-UNINSTALL"
                EndMarker = "##*==============================================="
                FallbackEndMarker = "##* END-UNINSTALL"
                CommandKey = "PostUninstall"
                HasTemplateCode = $false
            }
        )
        
        foreach ($point in $extractionPoints) {
            $markerUsed = $point.Marker
            $endMarkerToUse = $point.EndMarker
            $startLineIndex = -1

            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i].Trim() -eq $point.Marker) {
                    $startLineIndex = $i
                    break
                }
            }

            if ($startLineIndex -lt 0 -and $point.ContainsKey('FallbackMarker')) {
                for ($i = 0; $i -lt $lines.Count; $i++) {
                    if ($lines[$i].Trim() -eq $point.FallbackMarker) {
                        $startLineIndex = $i
                        $markerUsed = $point.FallbackMarker
                        $endMarkerToUse = $point.FallbackEndMarker
                        break
                    }
                }
            }

            if ($startLineIndex -lt 0) {
                continue
            }

            $sectionLines = New-Object System.Collections.Generic.List[string]
            for ($i = ($startLineIndex + 1); $i -lt $lines.Count; $i++) {
                $trimmed = $lines[$i].Trim()

                if ($trimmed -eq $endMarkerToUse) {
                    break
                }

                if ($point.HasTemplateCode -and $point.TemplateStartMarker -and $trimmed -eq $point.TemplateStartMarker) {
                    break
                }

                if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
                    [void]$sectionLines.Add($lines[$i].TrimStart())
                }
            }

            if ($sectionLines.Count -gt 0) {
                $result[$point.CommandKey] = ($sectionLines -join [Environment]::NewLine).Trim()
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
