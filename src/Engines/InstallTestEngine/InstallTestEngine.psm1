#Requires -Version 5.1

<#
.SYNOPSIS
    InstallTestEngine - Orchestrates installation and uninstallation testing workflow
.DESCRIPTION
    This engine manages the complete test cycle:
    1. Launch Install.exe
    2. Verify installation success with technician
    3. Generate validation report
    4. Run uninstallation
    5. Scan for leftovers
    6. Verify uninstallation success with technician
.NOTES
    Author: FRB Automation Team
    Created: June 6, 2026
    Version: 1.0.1
    PowerShell Version: 5.1
    Part of: FRB Package Creation Tool - Integrated Architecture
#>

Add-Type -AssemblyName System.Windows.Forms

function Test-IsAdministrator {
    [CmdletBinding()]
    param()

    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Get-SearchTokens {
    [CmdletBinding()]
    param(
        [string]$AppName,
        [string]$Vendor
    )

    $tokens = @()
    foreach ($raw in @($AppName, $Vendor)) {
        if ([string]::IsNullOrWhiteSpace($raw)) {
            continue
        }

        $trimmed = $raw.Trim()
        if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
            $tokens += $trimmed
        }

        foreach ($part in ($trimmed -split '[^A-Za-z0-9]+')) {
            if (-not [string]::IsNullOrWhiteSpace($part) -and $part.Length -ge 3) {
                $tokens += $part
            }
        }
    }

    return @($tokens | Sort-Object -Unique)
}

function Get-ShortcutTargetPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ShortcutPath
    )

    $targetPath = ""
    $shell = $null
    try {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($ShortcutPath)
        if ($shortcut -and -not [string]::IsNullOrWhiteSpace($shortcut.TargetPath)) {
            $targetPath = [string]$shortcut.TargetPath
        }
    }
    catch {
    }
    finally {
        if ($shell) {
            try {
                [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
            }
            catch {
            }
        }
    }

    return $targetPath
}

function Stop-RunningAppExecutables {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppName,

        [Parameter(Mandatory = $true)]
        [string]$Vendor
    )

    $result = @{
        Attempted = $false
        Terminated = @()
        Failed = @()
    }

    $tokens = Get-SearchTokens -AppName $AppName -Vendor $Vendor
    if ($tokens.Count -eq 0) {
        return $result
    }

    $result.Attempted = $true
    $currentPid = $PID
    $candidates = Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.Id -ne $currentPid -and $_.ProcessName -notin @('Idle', 'System', 'Registry', 'Memory Compression')
    }

    foreach ($proc in @($candidates)) {
        $processName = [string]$proc.ProcessName
        $processPath = ""
        try {
            $processPath = [string]$proc.Path
        }
        catch {
        }

        $matched = $false
        foreach ($token in $tokens) {
            if ($processName -like "*$token*" -or (-not [string]::IsNullOrWhiteSpace($processPath) -and $processPath -like "*$token*")) {
                $matched = $true
                break
            }
        }

        if (-not $matched) {
            continue
        }

        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
            $result.Terminated += [PSCustomObject]@{
                Name = $processName
                Id = $proc.Id
                Path = $processPath
            }
            Write-Verbose "InstallTestEngine: Terminated running process before uninstall - $processName (PID: $($proc.Id))"
        }
        catch {
            $result.Failed += [PSCustomObject]@{
                Name = $processName
                Id = $proc.Id
                Path = $processPath
                Error = $_.Exception.Message
            }
            Write-Warning "InstallTestEngine: Failed to terminate process $processName (PID: $($proc.Id)): $($_.Exception.Message)"
        }
    }

    return $result
}

function Remove-InstalledDesktopShortcuts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppName,

        [Parameter(Mandatory = $false)]
        [string]$Vendor = ""
    )

    $result = @{
        Removed = @()
        Failed = @()
    }

    if ([string]::IsNullOrWhiteSpace($AppName) -and [string]::IsNullOrWhiteSpace($Vendor)) {
        return $result
    }

    $tokens = Get-SearchTokens -AppName $AppName -Vendor $Vendor
    if ($tokens.Count -eq 0) {
        return $result
    }

    $PublicDesktop = [Environment]::GetFolderPath("CommonDesktopDirectory")
    $UserDesktop = [Environment]::GetFolderPath("Desktop")
    $DesktopPaths = @($PublicDesktop, $UserDesktop)

    foreach ($DesktopPath in $DesktopPaths) {
        if ([string]::IsNullOrWhiteSpace($DesktopPath) -or -not (Test-Path $DesktopPath)) {
            continue
        }

        $scope = if ($DesktopPath -eq $PublicDesktop) { "Machine" } else { "User" }
        $Shortcuts = Get-ChildItem -Path $DesktopPath -Filter "*.lnk" -File -ErrorAction SilentlyContinue

        foreach ($Shortcut in $Shortcuts) {
            $shortcutName = [string]$Shortcut.Name
            $shortcutTarget = Get-ShortcutTargetPath -ShortcutPath $Shortcut.FullName
            $isMatch = $false
            foreach ($token in $tokens) {
                if ($shortcutName -like "*$token*" -or (-not [string]::IsNullOrWhiteSpace($shortcutTarget) -and $shortcutTarget -like "*$token*")) {
                    $isMatch = $true
                    break
                }
            }

            if (-not $isMatch) {
                continue
            }

            try {
                Remove-Item -Path $Shortcut.FullName -Force -ErrorAction Stop
                $result.Removed += [PSCustomObject]@{
                    Path = $Shortcut.FullName
                    Scope = $scope
                    Name = $Shortcut.Name
                }
            }
            catch {
                $result.Failed += [PSCustomObject]@{
                    Path = $Shortcut.FullName
                    Scope = $scope
                    Name = $Shortcut.Name
                    Error = $_.Exception.Message
                }
            }
        }
    }

    return $result
}

function Get-ExecutionEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SearchRoot,

        [Parameter(Mandatory = $true)]
        [datetime]$OperationStart,

        [Parameter(Mandatory = $true)]
        [string]$OperationName,

        [string[]]$AdditionalSearchRoots = @()
    )

    $result = @{
        SearchedRoots = @()
        Files = @()
        TailLines = @()
    }

    $candidateRoots = New-Object System.Collections.Generic.List[string]
    foreach ($root in @($SearchRoot) + @($AdditionalSearchRoots) + @("${env:CommonProgramFiles(x86)}\InstallLogs", "$env:TEMP\InstallLogs")) {
        if ([string]::IsNullOrWhiteSpace($root)) {
            continue
        }

        if ($candidateRoots -notcontains $root) {
            [void]$candidateRoots.Add($root)
        }
    }

    $validRoots = @($candidateRoots | Where-Object { Test-Path $_ })
    $result.SearchedRoots = @($validRoots)

    if ($validRoots.Count -eq 0) {
        return $result
    }

    try {
        $cutoff = $OperationStart.AddMinutes(-2)
        $candidateFiles = New-Object System.Collections.Generic.List[object]

        foreach ($root in $validRoots) {
            $rootFiles = Get-ChildItem -Path $root -Recurse -File -Include *.log, *.txt -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.LastWriteTime -ge $cutoff -and
                    $_.Name -match '(?i)(install|uninstall|setup|error|fail|msi|process|log|psi_)'
                } |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 10

            foreach ($rootFile in @($rootFiles)) {
                [void]$candidateFiles.Add($rootFile)
            }
        }

        $selectedFiles = New-Object System.Collections.Generic.List[object]
        $seenPaths = @{}
        foreach ($candidate in @($candidateFiles | Sort-Object LastWriteTime -Descending)) {
            if (-not $candidate -or [string]::IsNullOrWhiteSpace($candidate.FullName)) {
                continue
            }

            if ($seenPaths.ContainsKey($candidate.FullName)) {
                continue
            }

            $seenPaths[$candidate.FullName] = $true
            [void]$selectedFiles.Add($candidate)
            if ($selectedFiles.Count -ge 12) {
                break
            }
        }

        foreach ($file in @($selectedFiles)) {
            $result.Files += [PSCustomObject]@{
                Path = $file.FullName
                LastWriteTime = $file.LastWriteTime
                Size = $file.Length
            }

            try {
                $tail = Get-Content -Path $file.FullName -Tail 4 -ErrorAction Stop
                foreach ($line in @($tail)) {
                    if (-not [string]::IsNullOrWhiteSpace([string]$line)) {
                        $result.TailLines += "[$OperationName] $($file.Name): $line"
                    }
                }
            }
            catch {
            }
        }
    }
    catch {
    }

    return $result
}

function Start-InstallationTest {
    <#
    .SYNOPSIS
        Runs installation test and prompts technician for verification
    .PARAMETER InstallExePath
        Full path to Install.exe
    .PARAMETER AppName
        Application name for messaging
    .PARAMETER AppVersion
        Application version for messaging
    .PARAMETER Vendor
        Vendor name for scanning
    .OUTPUTS
        Hashtable with Success, UserConfirmed, ExitCode, ErrorMessage
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallExePath,
        
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [Parameter(Mandatory = $true)]
        [string]$AppVersion,
        
        [Parameter(Mandatory = $true)]
        [string]$Vendor
    )
    
    Write-Verbose "InstallTestEngine: Starting installation test for $AppName $AppVersion"
    
    $result = @{
        Success = $false
        UserConfirmed = $false
        ExitCode = -1
        ErrorMessage = ""
        InstallExePath = $InstallExePath
        Arguments = ""
        WorkingDirectory = ""
        ProcessId = $null
        Diagnostics = $null
        RemovedDesktopShortcuts = @()
        FailedDesktopShortcutRemovals = @()
    }
    
    try {
        # Validate Install.exe exists
        if (-not (Test-Path $InstallExePath)) {
            $result.ErrorMessage = "Install.exe not found: $InstallExePath"
            Write-Error $result.ErrorMessage
            return $result
        }
        
        Write-Verbose "InstallTestEngine: Launching Install.exe (using embedded manifest)..."
        $installWorkingDirectory = Split-Path -Path $InstallExePath -Parent
        $result.WorkingDirectory = $installWorkingDirectory
        $operationStart = Get-Date
        
        # Create process start info for UAC elevation  
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $InstallExePath
        $processInfo.WorkingDirectory = $installWorkingDirectory
        $processInfo.UseShellExecute = $true
        # Removed: Verb = runas (let manifest control)
        $processInfo.WindowStyle = "Normal"
        
        # Launch Install.exe (returns shell process)
        [void][System.Diagnostics.Process]::Start($processInfo)
        
        # Wait for Install.exe to actually start
        Start-Sleep -Seconds 2
        
        # Find the ACTUAL Install.exe process by name
        $installProcess = Get-Process -Name "Install" -ErrorAction SilentlyContinue
        
        if ($installProcess) {
            Write-Verbose "InstallTestEngine: Found Install.exe process (PID: $($installProcess.Id))"
            $result.ProcessId = $installProcess.Id
            
            # Wait for the ACTUAL Install.exe process to complete
            $installProcess.WaitForExit()
            
            $result.ExitCode = $installProcess.ExitCode
            Write-Verbose "InstallTestEngine: Installation completed (Exit Code: $($result.ExitCode))"
            
            # Give system time to settle
            Start-Sleep -Seconds 2

            $result.Diagnostics = Get-ExecutionEvidence -SearchRoot $installWorkingDirectory -OperationStart $operationStart -OperationName "Install"

            $shortcutCleanup = Remove-InstalledDesktopShortcuts -AppName $AppName -Vendor $Vendor
            $result.RemovedDesktopShortcuts = @($shortcutCleanup.Removed)
            $result.FailedDesktopShortcutRemovals = @($shortcutCleanup.Failed)
            
            # Prompt technician for verification
            $userResponse = [System.Windows.Forms.MessageBox]::Show(
                "Did the installation of $AppName $AppVersion function as designed?",
                "Installation Verification",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
            
            if ($userResponse -eq 'Yes') {
                $result.Success = $true
                $result.UserConfirmed = $true
                Write-Verbose "InstallTestEngine: Installation confirmed by technician"
            } else {
                $result.Success = $false
                $result.UserConfirmed = $false
                $result.ErrorMessage = "Technician indicated installation did not function as designed"
                Write-Warning $result.ErrorMessage
            }
        } else {
            $result.ErrorMessage = "Failed to find Install.exe process after launch"
            Write-Error $result.ErrorMessage
        }
    }
    catch {
        $result.ErrorMessage = "Installation test failed: $($_.Exception.Message)"
        Write-Error $result.ErrorMessage
    }
    
    return $result
}

function Start-UninstallationTest {
    <#
    .SYNOPSIS
        Runs uninstallation test, scans for leftovers, and prompts technician
    .PARAMETER InstallExePath
        Full path to Install.exe (will add /uninstall)
    .PARAMETER AppName
        Application name for messaging and scanning
    .PARAMETER AppVersion
        Application version for messaging
    .PARAMETER Vendor
        Vendor name for scanning leftovers
    .PARAMETER PackagePath
        Path to package folder for saving leftover report
    .OUTPUTS
        Hashtable with Success, UserConfirmed, LeftoversFound, LeftoverDetails, ErrorMessage
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallExePath,
        
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [Parameter(Mandatory = $true)]
        [string]$AppVersion,
        
        [Parameter(Mandatory = $true)]
        [string]$Vendor,
        
        [Parameter(Mandatory = $false)]
        [string]$PackagePath = ""
    )
    
    Write-Verbose "InstallTestEngine: Starting uninstallation test for $AppName $AppVersion"
    
    $result = @{
        Success = $false
        UserConfirmed = $false
        ExitCode = -1
        LeftoversFound = $false
        LeftoverDetails = @()
        CleanupPerformed = $false
        CleanupResults = $null
        InstallExePath = $InstallExePath
        Arguments = "/uninstall"
        WorkingDirectory = ""
        ProcessId = $null
        ReportPath = ""
        Diagnostics = $null
        ErrorMessage = ""
        TerminatedProcesses = @()
        FailedProcessTerminations = @()
    }
    
    try {
        # Validate Install.exe exists
        if (-not (Test-Path $InstallExePath)) {
            $result.ErrorMessage = "Install.exe not found: $InstallExePath"
            Write-Error $result.ErrorMessage
            return $result
        }
        
        Write-Verbose "InstallTestEngine: Launching Install.exe /uninstall (using embedded manifest)..."
        $installWorkingDirectory = Split-Path -Path $InstallExePath -Parent
        $result.WorkingDirectory = $installWorkingDirectory
        $operationStart = Get-Date

        Write-Verbose "InstallTestEngine: Terminating running application executables before uninstall..."
        $terminationResult = Stop-RunningAppExecutables -AppName $AppName -Vendor $Vendor
        $result.TerminatedProcesses = @($terminationResult.Terminated)
        $result.FailedProcessTerminations = @($terminationResult.Failed)
        Start-Sleep -Seconds 1
        
        # Use Start-Process (no elevation - use embedded manifest)
        $uninstallProcess = Start-Process -FilePath $InstallExePath `
                                          -ArgumentList "/uninstall" `
                          -WorkingDirectory $installWorkingDirectory `
                                          -PassThru `
                                          -Wait
        
        if ($uninstallProcess) {
            Write-Verbose "InstallTestEngine: Uninstallation process completed"
            $result.ProcessId = $uninstallProcess.Id
            $result.ExitCode = $uninstallProcess.ExitCode
            Write-Verbose "InstallTestEngine: Uninstallation completed (Exit Code: $($result.ExitCode))"
            
            # Give system extra time to settle and release file locks
            Write-Verbose "InstallTestEngine: Waiting for system to settle and release file locks..."
            Start-Sleep -Seconds 5
            
            # Scan for leftovers and run automated cleanup for machine-level items only.
            Write-Verbose "InstallTestEngine: Scanning for leftover files and registry entries..."
            $leftovers = Get-UninstallLeftovers -AppName $AppName -Vendor $Vendor
            
            $result.LeftoversFound = $leftovers.Found
            $result.LeftoverDetails = $leftovers.Details

            Write-Verbose "InstallTestEngine: Running automated cleanup (machine-level leftovers only; user-level preserved)..."
            $cleanupResults = Remove-UninstallLeftovers -LeftoverData $leftovers -PreserveUserLevel $true
            $result.CleanupPerformed = $cleanupResults.Attempted
            $result.CleanupResults = $cleanupResults

            # Delay to allow post-uninstall command windows/processes to close before final scan/report generation.
            Write-Verbose "InstallTestEngine: Waiting 10 seconds before generating uninstall validation report..."
            Start-Sleep -Seconds 10

            # Perform final verification scan and generate report BEFORE technician confirmation prompt.
            Write-Verbose "InstallTestEngine: Performing final verification scan..."
            $finalScan = Get-UninstallLeftovers -AppName $AppName -Vendor $Vendor

            if (-not [string]::IsNullOrWhiteSpace($PackagePath)) {
                try {
                    $docsFolder = Join-Path $PackagePath "Docs"
                    if (-not (Test-Path $docsFolder)) {
                        New-Item -Path $docsFolder -ItemType Directory -Force | Out-Null
                    }

                    $reportFileName = "Uninstall_Report_" + $Vendor + "_" + $AppName + "_" + $AppVersion + ".html"
                    $reportFileName = $reportFileName -replace '[<>:"/\|?*]', '_'
                    $reportPath = Join-Path $docsFolder $reportFileName

                    $reportParams = @{
                        AppName = $AppName
                        AppVersion = $AppVersion
                        Vendor = $Vendor
                        LeftoverData = $finalScan
                        UninstallCommand = "$InstallExePath /uninstall"
                        OutputPath = $reportPath
                    }

                    if ($result.CleanupPerformed -and $result.CleanupResults) {
                        $reportParams.CleanupResults = $result.CleanupResults
                    }

                    $reportResult = New-HTMLUninstallReport @reportParams

                    if ($reportResult.Success) {
                        $result.ReportPath = $reportPath
                        Write-Verbose "InstallTestEngine: Uninstall report generated at $reportPath"
                        Start-Process $reportPath
                        Start-Sleep -Milliseconds 500
                    }
                }
                catch {
                    Write-Warning "InstallTestEngine: Failed to generate uninstall report: $($_.Exception.Message)"
                }
            }

            $result.Diagnostics = Get-ExecutionEvidence -SearchRoot $installWorkingDirectory -OperationStart $operationStart -OperationName "Uninstall"

            $remainingMachineItems = @($finalScan.Details | Where-Object { $_.Scope -eq "Machine" })

            if ($remainingMachineItems.Count -gt 0) {
                $finalParts = @(
                    "Final verification scan detected machine-level leftover items:",
                    "",
                    (($remainingMachineItems | ForEach-Object { "--- $($_.Type): $($_.Location)" }) -join [Environment]::NewLine),
                    "",
                    "Review report/leftovers before confirming. User-level items are preserved by policy.",
                    "",
                    "Did the uninstallation of $AppName $AppVersion function as designed?"
                )
            }
            else {
                $finalParts = @(
                    "Uninstall validation report is ready.",
                    "",
                    "No machine-level leftovers were detected in final verification.",
                    "",
                    "Did the uninstallation of $AppName $AppVersion function as designed?"
                )
            }

            $userResponse = [System.Windows.Forms.MessageBox]::Show(
                ($finalParts -join [Environment]::NewLine),
                "Uninstallation Verification",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )

            if ($userResponse -eq 'Yes') {
                if ($remainingMachineItems.Count -gt 0) {
                    Write-Warning "InstallTestEngine: Machine-level leftovers remain after uninstallation"
                }
                else {
                    Write-Verbose "InstallTestEngine: Final verification scan clean for machine-level leftovers"
                }

                $result.Success = $true
                $result.UserConfirmed = $true
                $result.LeftoversFound = ($remainingMachineItems.Count -gt 0)
                $result.LeftoverDetails = $finalScan.Details
                Write-Verbose "InstallTestEngine: Uninstallation confirmed by technician"
            }
            else {
                $result.Success = $false
                $result.UserConfirmed = $false
                $result.ErrorMessage = "Technician indicated uninstallation did not function as designed"
                Write-Warning $result.ErrorMessage
            }
        } else {
            $result.ErrorMessage = "Failed to find Install.exe process after launch"
            Write-Error $result.ErrorMessage
        }
    }
    catch {
        $result.ErrorMessage = "Uninstallation test failed: $($_.Exception.Message)"
        Write-Error $result.ErrorMessage
    }
    
    return $result
}

function Remove-UninstallLeftovers {
    <#
    .SYNOPSIS
        Removes leftover files, folders, and registry entries
    .PARAMETER LeftoverData
        Hashtable containing leftover details from Get-UninstallLeftovers
    .OUTPUTS
        Hashtable with Success, TotalCleaned, TotalFailed, ErrorMessage
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$LeftoverData,

        [Parameter(Mandatory = $false)]
        [bool]$PreserveUserLevel = $true
    )
    
    Write-Verbose "InstallTestEngine: Starting cleanup of leftovers..."
    
    $result = @{
        Success = $true
        Attempted = $false
        TotalCandidates = 0
        TotalCleaned = 0
        TotalFailed = 0
        PreservedCount = 0
        CleanedItems = @()
        FailedItems = @()
        PreservedItems = @()
        ErrorMessage = ""
        Message = ""
    }

    $preservedItems = @()
    if ($PreserveUserLevel -and $LeftoverData.ContainsKey('PreservedItems') -and $LeftoverData.PreservedItems) {
        $preservedItems = @($LeftoverData.PreservedItems)
    }
    $result.PreservedItems = $preservedItems
    $result.PreservedCount = $preservedItems.Count

    $cleanupCandidates = @()
    if ($LeftoverData.ContainsKey('CleanupCandidates') -and $LeftoverData.CleanupCandidates) {
        $cleanupCandidates = @($LeftoverData.CleanupCandidates)
    }
    else {
        $cleanupCandidates = @($LeftoverData.Details | Where-Object { $_.Scope -eq "Machine" })
    }

    if ($PreserveUserLevel) {
        $userDesktopShortcuts = @($LeftoverData.Details | Where-Object { $_.Scope -eq "User" -and $_.Type -eq "Desktop Shortcut" })
        if ($userDesktopShortcuts.Count -gt 0) {
            Write-Verbose "InstallTestEngine: Adding user desktop shortcuts to cleanup list by policy override"
            $cleanupCandidates += $userDesktopShortcuts
        }
    }

    if ($cleanupCandidates.Count -eq 0) {
        Write-Verbose "InstallTestEngine: No machine-level leftovers found to clean"
        $result.Message = "No machine-level leftovers required cleanup."
        return $result
    }

    $result.TotalCandidates = $cleanupCandidates.Count

    if (-not (Test-IsAdministrator)) {
        $result.Success = $false
        $result.Message = "Cleanup skipped: administrative rights are required to remove machine-level leftovers."
        Write-Warning $result.Message
        return $result
    }

    $result.Attempted = $true

    # Remove deeper paths first to avoid parent/child ordering issues.
    $cleanupCandidates = $cleanupCandidates |
        Group-Object -Property Location, Type |
        ForEach-Object { $_.Group[0] } |
        Sort-Object { $_.Location.Length } -Descending
    
    # Loop through machine-level leftover items and delete them.
    foreach ($item in $cleanupCandidates) {
        try {
            if (Test-Path $item.Location) {
                Remove-Item -Path $item.Location -Recurse -Force -ErrorAction Stop
                $result.TotalCleaned++
                $result.CleanedItems += $item
                Write-Verbose "InstallTestEngine: Removed $($item.Type) - $($item.Location)"
            } else {
                Write-Verbose "InstallTestEngine: Item already removed - $($item.Location)"
            }
        }
        catch {
            $result.TotalFailed++
            $result.FailedItems += [PSCustomObject]@{
                Type = $item.Type
                Location = $item.Location
                Scope = $item.Scope
                Error = $_.Exception.Message
            }
            Write-Warning "InstallTestEngine: Failed to remove $($item.Type) - $($item.Location): $($_.Exception.Message)"
        }
    }
    
    Write-Verbose "InstallTestEngine: Cleanup complete - Removed: $($result.TotalCleaned), Failed: $($result.TotalFailed)"
    
    return $result
}

function Get-UninstallLeftovers {
    <#
    .SYNOPSIS
        Scans for leftover files, folders, and registry entries after uninstallation
    .PARAMETER AppName
        Application name to search for
    .PARAMETER Vendor
        Vendor name to search for
    .OUTPUTS
        Hashtable with Found (bool), Details (array), Summary (array)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [Parameter(Mandatory = $true)]
        [string]$Vendor
    )
    
    Write-Verbose "InstallTestEngine: Scanning for leftovers..."
    
    $leftovers = @{
        Found = $false
        Details = @()
        Summary = @()
        CleanupCandidates = @()
        PreservedItems = @()
        MachineLeftoverCount = 0
        UserLeftoverCount = 0
    }

    $searchTokens = @()
    if (-not [string]::IsNullOrWhiteSpace($AppName)) { $searchTokens += $AppName }
    if (-not [string]::IsNullOrWhiteSpace($Vendor)) { $searchTokens += $Vendor }
    $searchTokens = $searchTokens | Sort-Object -Unique

    if ($searchTokens.Count -eq 0) {
        return $leftovers
    }

    $collected = New-Object System.Collections.ArrayList

    function Add-LeftoverItem {
        param(
            [string]$Type,
            [string]$Location,
            [string]$Scope,
            [string]$DisplayName = ""
        )

        if ([string]::IsNullOrWhiteSpace($Location)) {
            return
        }

        $item = [PSCustomObject]@{
            Type = $Type
            Location = $Location
            Scope = $Scope
            DisplayName = $DisplayName
        }

        [void]$collected.Add($item)
    }
    
    # Machine-level folders (eligible for cleanup).
    $machineRoots = @(
        $env:ProgramFiles,
        ${env:ProgramFiles(x86)},
        $env:ProgramData
    )

    foreach ($root in $machineRoots) {
        if ([string]::IsNullOrWhiteSpace($root) -or -not (Test-Path $root)) {
            continue
        }

        foreach ($token in $searchTokens) {
            $candidate = Join-Path $root $token
            if (Test-Path $candidate) {
                Add-LeftoverItem -Type "Folder" -Location $candidate -Scope "Machine"
                Write-Verbose "InstallTestEngine: Found machine-level leftover folder - $candidate"
            }
        }
    }

    # User-level folders (preserved by policy).
    $userRoots = @(
        $env:APPDATA,
        $env:LOCALAPPDATA
    )

    foreach ($root in $userRoots) {
        if ([string]::IsNullOrWhiteSpace($root) -or -not (Test-Path $root)) {
            continue
        }

        foreach ($token in $searchTokens) {
            $candidate = Join-Path $root $token
            if (Test-Path $candidate) {
                Add-LeftoverItem -Type "User Folder" -Location $candidate -Scope "User"
                Write-Verbose "InstallTestEngine: Found user-level leftover folder (preserved) - $candidate"
            }
        }
    }
    
    # Machine-level registry keys (eligible for cleanup).
    $machineRegistryRoots = @(
        "HKLM:\Software",
        "HKLM:\Software\Wow6432Node"
    )

    foreach ($root in $machineRegistryRoots) {
        if (-not (Test-Path $root)) {
            continue
        }

        foreach ($token in $searchTokens) {
            $candidate = Join-Path $root $token
            if (Test-Path $candidate) {
                Add-LeftoverItem -Type "Registry" -Location $candidate -Scope "Machine"
                Write-Verbose "InstallTestEngine: Found machine-level leftover registry key - $candidate"
            }
        }
    }

    # User-level registry keys (preserved by policy).
    if (Test-Path "HKCU:\Software") {
        foreach ($token in $searchTokens) {
            $candidate = Join-Path "HKCU:\Software" $token
            if (Test-Path $candidate) {
                Add-LeftoverItem -Type "User Registry" -Location $candidate -Scope "User"
                Write-Verbose "InstallTestEngine: Found user-level registry key (preserved) - $candidate"
            }
        }
    }
    
    # Check Uninstall registry entries
    $uninstallPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    
    foreach ($uninstallPath in $uninstallPaths) {
        try {
            if (Test-Path $uninstallPath) {
                $subKeys = Get-ChildItem -Path $uninstallPath -ErrorAction SilentlyContinue
                foreach ($subKey in $subKeys) {
                    $app = Get-ItemProperty -Path $subKey.PSPath -ErrorAction SilentlyContinue
                    if ($app -and $app.DisplayName) {
                        if (($app.DisplayName -like "*$AppName*") -or ($app.Publisher -like "*$Vendor*")) {
                            $scope = if ($uninstallPath -like "HKCU:*") { "User" } else { "Machine" }
                            Add-LeftoverItem -Type "Uninstall Entry" -Location $subKey.PSPath -Scope $scope -DisplayName $app.DisplayName
                            Write-Verbose "InstallTestEngine: Found leftover uninstall entry - $($app.DisplayName)"
                        }
                    }
                }
            }
        } catch {
            Write-Verbose "InstallTestEngine: Error scanning $uninstallPath"
        }
    }
    
    # Check Desktop shortcuts (machine + user scope).
    $desktopScopes = @(
        @{ Path = "$env:PUBLIC\Desktop"; Scope = "Machine" },
        @{ Path = "$env:USERPROFILE\Desktop"; Scope = "User" }
    )

    foreach ($desktopScope in $desktopScopes) {
        if ([string]::IsNullOrWhiteSpace($desktopScope.Path) -or -not (Test-Path $desktopScope.Path)) {
            continue
        }

        $shortcuts = Get-ChildItem -Path $desktopScope.Path -Filter "*.lnk" -File -ErrorAction SilentlyContinue
        foreach ($shortcut in $shortcuts) {
            foreach ($token in $searchTokens) {
                if ($shortcut.Name -like "*$token*") {
                    Add-LeftoverItem -Type "Desktop Shortcut" -Location $shortcut.FullName -Scope $desktopScope.Scope -DisplayName $shortcut.Name
                    Write-Verbose "InstallTestEngine: Found desktop shortcut leftover - $($shortcut.FullName)"
                    break
                }
            }
        }
    }

    # Check Start Menu shortcuts/folders (machine + user scope).
    $startMenuPaths = @(
        @{ Path = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"; Scope = "Machine" },
        @{ Path = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"; Scope = "User" }
    )
    
    foreach ($startMenuScope in $startMenuPaths) {
        try {
            $startMenuPath = $startMenuScope.Path
            if (Test-Path $startMenuPath) {
                # Search for shortcuts containing vendor or app name
                $shortcuts = Get-ChildItem -Path $startMenuPath -Filter "*.lnk" -Recurse -ErrorAction SilentlyContinue
                
                foreach ($shortcut in $shortcuts) {
                    $shortcutName = $shortcut.Name -replace '\.lnk$', ''
                    $folderName = $shortcut.Directory.Name
                    
                    # Check if shortcut name or parent folder contains vendor/app name
                    if (($shortcutName -like "*$Vendor*") -or ($shortcutName -like "*$AppName*") -or 
                        ($folderName -like "*$Vendor*") -or ($folderName -like "*$AppName*")) {
                        Add-LeftoverItem -Type "Start Menu Shortcut" -Location $shortcut.FullName -Scope $startMenuScope.Scope -DisplayName $shortcutName
                        Write-Verbose "InstallTestEngine: Found leftover Start Menu shortcut - $($shortcut.FullName)"
                    }
                }
                
                # Also check for vendor/app-named folders in Start Menu
                $folders = Get-ChildItem -Path $startMenuPath -Directory -Recurse -ErrorAction SilentlyContinue | 
                           Where-Object { $_.Name -like "*$Vendor*" -or $_.Name -like "*$AppName*" }
                
                foreach ($folder in $folders) {
                    # Only add if folder is empty or only contains shortcuts we already found
                    $folderContents = Get-ChildItem -Path $folder.FullName -Recurse -ErrorAction SilentlyContinue
                    if ($folderContents.Count -eq 0 -or ($folderContents | Where-Object { $_.Extension -ne '.lnk' }).Count -eq 0) {
                        Add-LeftoverItem -Type "Start Menu Folder" -Location $folder.FullName -Scope $startMenuScope.Scope -DisplayName $folder.Name
                        Write-Verbose "InstallTestEngine: Found leftover Start Menu folder - $($folder.FullName)"
                    }
                }
            }
        } catch {
            Write-Verbose "InstallTestEngine: Error scanning Start Menu at $startMenuPath"
        }
    }

    # Deduplicate and categorize items.
    $leftovers.Details = @($collected |
        Group-Object -Property Type, Location |
        ForEach-Object { $_.Group[0] })

    $leftovers.CleanupCandidates = @($leftovers.Details | Where-Object { $_.Scope -eq "Machine" })
    $leftovers.PreservedItems = @($leftovers.Details | Where-Object { $_.Scope -eq "User" })
    $leftovers.MachineLeftoverCount = $leftovers.CleanupCandidates.Count
    $leftovers.UserLeftoverCount = $leftovers.PreservedItems.Count

    foreach ($item in $leftovers.Details) {
        $scopeTag = if ($item.Scope -eq "User") { "[PRESERVED]" } else { "[CLEANUP]" }
        $leftovers.Summary += "--- $scopeTag $($item.Type): $($item.Location)"
    }

    $leftovers.Found = ($leftovers.Details.Count -gt 0)
    
    if (-not $leftovers.Found) {
        Write-Verbose "InstallTestEngine: No leftovers found - Clean uninstall"
    }
    
    return $leftovers
}

function Show-CompletionMessage {
    <#
    .SYNOPSIS
        Displays congratulations banner for successful packaging and testing
    .PARAMETER AppName
        Application name
    .PARAMETER AppVersion
        Application version
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [Parameter(Mandatory = $true)]
        [string]$AppVersion
    )
    
    $message = @"
CONGRATULATIONS!

$AppName $AppVersion

has been successfully:
[OK] Packaged
[OK] Installed & Tested
[OK] Validated
[OK] Uninstalled & Verified

Package is ready to move to Intune!
"@
    
    [System.Windows.Forms.MessageBox]::Show(
        $message,
        "Packaging Complete!",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
    
    Write-Verbose "InstallTestEngine: Packaging cycle completed successfully!"
}

# Export public functions
Export-ModuleMember -Function Start-InstallationTest, Start-UninstallationTest, Get-UninstallLeftovers, Remove-UninstallLeftovers, Show-CompletionMessage










