# SnagitController.psm1 - CORRECT Implementation (Take 2)
# Based EXACTLY on TechSmith samples with proper enums

<#
.SYNOPSIS
    Snagit COM automation - NO DIALOGS
    
.NOTES
    Based on: https://github.com/TechSmith/Snagit-COM-Samples
    Key: Use LoadImageDefaults() and FileNamingMethod = 2 (sofnmAuto)
#>

# Define enums (critical!)
Add-Type -TypeDefinition @"
public enum snagImageInput {
    siiWindow = 1,
    siiRegion = 4
}
"@

Add-Type -TypeDefinition @"
public enum snagImageOutput {
    sioFile = 2
}
"@

Add-Type -TypeDefinition @"
public enum snagImageFileType {
    siftJPEG = 3
}
"@

Add-Type -TypeDefinition @"
public enum snagOuputFileNamingMethod {
    sofnmPrompt = 0,
    sofnmFixed = 1,
    sofnmAuto = 2
}
"@

# Module variables
$script:SnagitCOM = $null
$script:IsInitialized = $false
$script:SnagitBaselinePids = @()

function Get-SnagitProcessCandidates {
    [CmdletBinding()]
    param(
        [switch]$OnlyAutomationStarted
    )

    $snagitProcesses = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
            $_.ProcessName -match '(?i)^snag' -or
            ($_.MainWindowTitle -and $_.MainWindowTitle -match '(?i)snagit')
        })

    if ($OnlyAutomationStarted -and $script:SnagitBaselinePids) {
        return @($snagitProcesses | Where-Object { $_.Id -notin $script:SnagitBaselinePids })
    }

    return $snagitProcesses
}

function Wait-ForSnagitCaptureFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [int]$TimeoutSeconds = 15
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $lastLength = -1
    $stableSamples = 0

    while ($sw.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        if (Test-Path -Path $FilePath) {
            try {
                $item = Get-Item -Path $FilePath -ErrorAction Stop
                $length = [int64]$item.Length

                if ($length -gt 0) {
                    if ($length -eq $lastLength) {
                        $stableSamples++
                    } else {
                        $stableSamples = 0
                    }

                    $lastLength = $length

                    # Require one stable sample to reduce races with delayed writes.
                    if ($stableSamples -ge 1) {
                        return $true
                    }
                }
            }
            catch {
            }
        }

        Start-Sleep -Milliseconds 250
    }

    return $false
}

function Close-SnagitWindows {
    [CmdletBinding()]
    param(
        [switch]$OnlyAutomationStarted,

        [int]$CloseTimeoutSeconds = 8,

        [switch]$ForceTerminate
    )

    try {
        $snagitProcesses = @(Get-SnagitProcessCandidates -OnlyAutomationStarted:$OnlyAutomationStarted)

        foreach ($snagitProcess in $snagitProcesses) {
            try {
                if ($snagitProcess.MainWindowHandle -ne 0) {
                    [void]$snagitProcess.CloseMainWindow()
                }
            }
            catch {
            }
        }

        $deadline = (Get-Date).AddSeconds($CloseTimeoutSeconds)
        do {
            Start-Sleep -Milliseconds 300
            $remaining = @(Get-SnagitProcessCandidates -OnlyAutomationStarted:$OnlyAutomationStarted)
        } while ($remaining.Count -gt 0 -and (Get-Date) -lt $deadline)

        if ($ForceTerminate -and $remaining.Count -gt 0) {
            foreach ($snagitProcess in $remaining) {
                try {
                    Stop-Process -Id $snagitProcess.Id -Force -ErrorAction Stop
                }
                catch {
                }
            }
        }

        $finalRemaining = @(Get-SnagitProcessCandidates -OnlyAutomationStarted:$OnlyAutomationStarted)
        return [PSCustomObject]@{
            Success = ($finalRemaining.Count -eq 0)
            RemainingProcessCount = $finalRemaining.Count
            RemainingProcesses = @($finalRemaining | ForEach-Object { "$($_.ProcessName)#$($_.Id)" })
        }
    }
    catch {
        Write-Error "Error closing Snagit windows: $_"
        return [PSCustomObject]@{
            Success = $false
            RemainingProcessCount = -1
            RemainingProcesses = @()
        }
    }
}

function Initialize-Snagit {
    [CmdletBinding()]
    param()
    
    try {
        Write-Verbose "Initializing Snagit COM object..."
        
        $script:SnagitCOM = New-Object -ComObject SNAGIT.ImageCapture
        
        if ($null -eq $script:SnagitCOM) {
            throw "Failed to create Snagit COM object"
        }
        
        # Set input to Region
        $script:SnagitCOM.Input = [snagImageInput]::siiRegion
        
        # Set output to File
        $script:SnagitCOM.Output = [snagImageOutput]::sioFile
        
        # Disable preview (CRITICAL!)
        $script:SnagitCOM.EnablePreviewWindow = $false
        
        # Load image defaults for JPEG (CRITICAL STEP!)
        $script:SnagitCOM.OutputImageFile.LoadImageDefaults([snagImageFileType]::siftJPEG)
        
        # Set file naming to AUTO (NOT PROMPT!) (CRITICAL!)
        $script:SnagitCOM.OutputImageFile.FileNamingMethod = [snagOuputFileNamingMethod]::sofnmAuto
        
        # Set quality
        $script:SnagitCOM.OutputImageFile.Quality = 90

        # Record baseline Snagit processes so cleanup can avoid killing pre-existing user sessions.
        $script:SnagitBaselinePids = @((Get-SnagitProcessCandidates).Id)
        
        $script:IsInitialized = $true
        Write-Verbose "Snagit initialized (auto-save mode, no dialogs)"
        
        return $true
    }
    catch {
        Write-Error "Failed to initialize Snagit: $_"
        $script:IsInitialized = $false
        return $false
    }
}

function Test-SnagitInstalled {
    [CmdletBinding()]
    param()
    
    try {
        $testCOM = New-Object -ComObject SNAGIT.ImageCapture -ErrorAction Stop
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($testCOM) | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Invoke-SnagitCapture {
    <#
    .SYNOPSIS
        Captures screen - NO DIALOGS!
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Region', 'Window')]
        [string]$CaptureMode = 'Region'
    )
    
    if (-not $script:IsInitialized) {
        if (-not (Initialize-Snagit)) {
            throw "Failed to initialize Snagit"
        }
    }
    
    try {
        Write-Verbose "Preparing capture: $OutputPath"
        
        # Ensure output directory exists
        $outputDir = Split-Path -Path $OutputPath -Parent
        if (-not (Test-Path -Path $outputDir)) {
            New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
        }
        
        # Set temporary directory for auto-save
        $tempDir = [System.IO.Path]::GetTempPath()
        $script:SnagitCOM.OutputImageFile.Directory = $tempDir
        
        # Set capture mode
        if ($CaptureMode -eq 'Window') {
            $script:SnagitCOM.Input = [snagImageInput]::siiWindow
        } else {
            $script:SnagitCOM.Input = [snagImageInput]::siiRegion
        }
        
        Write-Verbose "Triggering capture (Mode: $CaptureMode)..."
        
        # Trigger capture
        $script:SnagitCOM.Capture()
        
        # Wait for capture to complete
        Write-Verbose "Waiting for capture..."
        $timeout = 60
        $elapsed = 0
        
        while (-not $script:SnagitCOM.IsCaptureDone) {
            Start-Sleep -Milliseconds 500
            $elapsed += 0.5
            
            if ($elapsed -ge $timeout) {
                throw "Capture timeout"
            }
        }
        
        # Get auto-saved file
        $capturedFile = $script:SnagitCOM.LastFileWritten
        
        if ([string]::IsNullOrWhiteSpace($capturedFile)) {
            throw "Capture cancelled or failed"
        }

        if (-not (Wait-ForSnagitCaptureFile -FilePath $capturedFile -TimeoutSeconds 20)) {
            throw "Capture cancelled or failed"
        }
        
        Write-Verbose "Auto-saved to: $capturedFile"
        
        # Copy then remove from temp so we can verify output deterministically.
        if (Test-Path $OutputPath) {
            Remove-Item $OutputPath -Force
        }
        Copy-Item $capturedFile $OutputPath -Force

        if (-not (Wait-ForSnagitCaptureFile -FilePath $OutputPath -TimeoutSeconds 10)) {
            throw "Capture saved path was not created correctly"
        }

        Remove-Item $capturedFile -Force -ErrorAction SilentlyContinue
        
        Write-Verbose "Moved to: $OutputPath"
        [void](Close-SnagitWindows -OnlyAutomationStarted -ForceTerminate)
        
        return @{
            Success = $true
            FilePath = $OutputPath
            FileSize = (Get-Item $OutputPath).Length
            Timestamp = Get-Date
        }
    }
    catch {
        [void](Close-SnagitWindows -OnlyAutomationStarted -ForceTerminate)
        Write-Error "Capture failed: $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Set-SnagitCaptureSettings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 100)]
        [int]$Quality = 90,
        
        [Parameter(Mandatory = $false)]
        [bool]$IncludeCursor = $false
    )
    
    if (-not $script:IsInitialized) {
        throw "Snagit not initialized"
    }
    
    try {
        $script:SnagitCOM.OutputImageFile.Quality = $Quality
        $script:SnagitCOM.IncludeCursor = $IncludeCursor
        Write-Verbose "Settings updated"
    }
    catch {
        Write-Error "Failed to set settings: $_"
    }
}

function Close-Snagit {
    [CmdletBinding()]
    param()
    
    try {
        [void](Close-SnagitWindows -OnlyAutomationStarted -ForceTerminate)

        if ($null -ne $script:SnagitCOM) {
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($script:SnagitCOM) | Out-Null
            $script:SnagitCOM = $null
            $script:IsInitialized = $false
            $script:SnagitBaselinePids = @()
            Write-Verbose "Snagit closed"
        }
    }
    catch {
        Write-Error "Error closing Snagit: $_"
    }
}

Export-ModuleMember -Function @(
    'Initialize-Snagit',
    'Test-SnagitInstalled',
    'Invoke-SnagitCapture',
    'Set-SnagitCaptureSettings',
    'Close-Snagit',
    'Close-SnagitWindows'
)