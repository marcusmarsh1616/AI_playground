# SnagitController.psm1

<#
.SYNOPSIS
    Snagit COM automation helper

.DESCRIPTION
    Provides simple capture helpers that run Snagit in auto-save mode.
#>

$script:SnagitCOM = $null
$script:IsInitialized = $false
$script:LastInitializeError = ""

function Register-SnagitEnumTypes {
    [CmdletBinding()]
    param()

    if (-not ("snagImageInput" -as [type])) {
        Add-Type -TypeDefinition @"
public enum snagImageInput {
    siiWindow = 1,
    siiRegion = 4
}
"@
    }

    if (-not ("snagImageOutput" -as [type])) {
        Add-Type -TypeDefinition @"
public enum snagImageOutput {
    sioFile = 2
}
"@
    }

    if (-not ("snagImageFileType" -as [type])) {
        Add-Type -TypeDefinition @"
public enum snagImageFileType {
    siftJPEG = 3
}
"@
    }

    if (-not ("snagOuputFileNamingMethod" -as [type])) {
        Add-Type -TypeDefinition @"
public enum snagOuputFileNamingMethod {
    sofnmPrompt = 0,
    sofnmFixed = 1,
    sofnmAuto = 2
}
"@
    }
}

function Initialize-Snagit {
    [CmdletBinding()]
    param()
    
    try {
        Register-SnagitEnumTypes
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
        
        $script:IsInitialized = $true
        Write-Verbose "Snagit initialized (auto-save mode, no dialogs)"
        
        return $true
    }
    catch {
        $script:LastInitializeError = $_.Exception.Message
        Write-Error "Failed to initialize Snagit: $_"
        $script:IsInitialized = $false
        return $false
    }
}

function Test-SnagitInstalled {
    [CmdletBinding()]
    param()

    # Environment guarantee: Snagit is required and deployed everywhere this tool runs.
    return $true
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
            $initReason = if ([string]::IsNullOrWhiteSpace($script:LastInitializeError)) { "unknown reason" } else { $script:LastInitializeError }
            throw "Failed to initialize Snagit: $initReason"
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
        
        if ([string]::IsNullOrWhiteSpace($capturedFile) -or -not (Test-Path $capturedFile)) {
            throw "Capture cancelled or failed"
        }
        
        Write-Verbose "Auto-saved to: $capturedFile"
        
        # Move to desired location
        if (Test-Path $OutputPath) {
            Remove-Item $OutputPath -Force
        }
        Move-Item $capturedFile $OutputPath -Force
        
        Write-Verbose "Moved to: $OutputPath"
        
        return @{
            Success = $true
            FilePath = $OutputPath
            FileSize = (Get-Item $OutputPath).Length
            Timestamp = Get-Date
        }
    }
    catch {
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
        if ($null -ne $script:SnagitCOM) {
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($script:SnagitCOM) | Out-Null
            $script:SnagitCOM = $null
            $script:IsInitialized = $false
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
    'Close-Snagit'
)