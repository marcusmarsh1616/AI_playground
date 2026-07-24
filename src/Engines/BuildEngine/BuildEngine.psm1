<#
.SYNOPSIS
    Build Engine for PowerShell Studio Project Compilation
.DESCRIPTION
        Handles compilation of PowerShell Studio .psproj files into executable packages
    using SAPIEN's SAPIENCommandLine.exe tool.
.NOTES
    Author: FRB Automation Team
    Created: December 2024
    Version: 1.0.0
    
    Requires: PowerShell Studio 2026 with SAPIENCommandLine.exe
#>

#region Functions

<#
.SYNOPSIS
    Compiles a PowerShell Studio project into an executable package
.DESCRIPTION
    Uses SAPIENCommandLine.exe to compile a .psproj file and generates Install.exe
.PARAMETER ProjectPath
    Full path to the .psproj file
.PARAMETER PSBuildPath
    Path to PSBuild.exe (default: standard PowerShell Studio 2026 location)
.PARAMETER BuildType
    Type of build to perform: PACKAGE, MSI, DEPLOY, or BUILD (default: PACKAGE)
.EXAMPLE
    $result = Invoke-ProjectBuild -ProjectPath "C:\path\to\project.psproj"
.OUTPUTS
    Hashtable with Success (bool), Message (string), OutputPath (string), BuildLog (string)
#>
function Invoke-ProjectBuild {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath,
        
                [Parameter(Mandatory = $false)]
        [string]$SAPIENPath = "C:\Program Files\SAPIEN Technologies, Inc\PowerShell Studio 2026\SAPIENCommandLine.exe"
    )
    
    $result = @{
        Success = $false
        Message = ""
        OutputPath = ""
        BuildLog = ""
    }
    
    try {
                # Validate SAPIENCommandLine.exe exists
        if (-not (Test-Path $SAPIENPath)) {
            $result.Message = "SAPIENCommandLine.exe not found at: $SAPIENPath"
            return $result
        }
        
        # Validate project file exists
        if (-not (Test-Path $ProjectPath)) {
            $result.Message = "Project file not found: $ProjectPath"
            return $result
        }
        
        # Get project directory and expected output path
        $projectDir = Split-Path $ProjectPath -Parent
        
        # Determine output path - Install.exe is always in the project directory
        $expectedOutputPath = Join-Path $projectDir "Install.exe"
        
        # Delete old Install.exe if it exists
        if (Test-Path $expectedOutputPath) {
            Remove-Item $expectedOutputPath -Force -ErrorAction SilentlyContinue
        }
        
                # Prepare SAPIEN build command
        $result.BuildLog = "Starting build with SAPIENCommandLine.exe
"
        $result.BuildLog += "Project: $ProjectPath
"
        $result.BuildLog += "Output: $expectedOutputPath

"
        
                                                                # Use Start-Process with -WindowStyle Hidden to hide SAPIENCommandLine window
        # PostCompile.exe will spawn its own PowerShell 7 window for certificate signing
        $result.BuildLog += "Executing build with hidden SAPIEN window...`n"
        
        $process = Start-Process -FilePath $SAPIENPath `
                                                 -ArgumentList "/buildexe `"$ProjectPath`"" `
                                                 -WorkingDirectory $projectDir `
                                                 -Wait `
                                                 -WindowStyle Hidden `
                                                 -PassThru
        
        $exitCode = $process.ExitCode
        $result.BuildLog += "Build completed with exit code: $exitCode`n"
        
                # Check if build was successful
                # Exit code 0 = success, Exit code -1 = success but signing failed (non-fatal)
                $buildSucceeded = ($exitCode -eq 0) -or ($exitCode -eq -1)
        
                if ($buildSucceeded) {
            # Poll for Install.exe (PostCompile.exe moves it from bin\x64 to ROOT)
            # This can take 0.5-6 seconds depending on whether code signing is enabled
                        $maxWaitTime = 90  # Wait up to 90 seconds for certificate signing
            $waitInterval = 1
            $waited = 0
            
            $result.BuildLog += "Waiting for PostCompile to move Install.exe to ROOT...`n"
            
            while ($waited -lt $maxWaitTime) {
                if (Test-Path $expectedOutputPath) {
                    $result.BuildLog += "Install.exe found after $waited seconds`n"
                    break
                }
                Start-Sleep -Seconds $waitInterval
                $waited += $waitInterval
            }
            
            # Verify output file exists
            if (Test-Path $expectedOutputPath) {
                $fileInfo = Get-Item $expectedOutputPath
                $result.Success = $true
                $result.OutputPath = $expectedOutputPath
                $result.Message = "Build completed successfully!

Output: $(Split-Path $expectedOutputPath -Leaf)
Size: $([math]::Round($fileInfo.Length / 1MB, 2)) MB
Location: $projectDir
Wait Time: $waited seconds"
            } else {
                $result.Message = "Build completed but Install.exe not found after $maxWaitTime seconds

Expected: $expectedOutputPath

PostCompile may have failed. Check for:
- PostCompile.exe in package folder
- Permissions to move files
- Antivirus blocking file operations"
                $result.BuildLog += "
WARNING: Install.exe not found after waiting $maxWaitTime seconds
"
                $result.BuildLog += "PostCompile.exe should move Install.exe from bin\x64 to ROOT
"
            }
        } else {
                        $result.Message = "Build failed with exit code: $exitCode"
        }
        
    }
    catch {
        $result.Message = "Build error: $($_.Exception.Message)"
        $result.BuildLog += "
    EXCEPTION: $($_.Exception.Message)
"
        $result.BuildLog += $_.ScriptStackTrace
    }
    
    return $result
}

<#
.SYNOPSIS
    Tests if SAPIENCommandLine.exe is available and accessible
.DESCRIPTION
    Validates that PowerShell Studio's SAPIENCommandLine.exe exists and is executable
.PARAMETER SAPIENPath
    Path to SAPIENCommandLine.exe (default: standard PowerShell Studio 2026 location)
.EXAMPLE
    $isAvailable = Test-SAPIENBuildAvailable
.OUTPUTS
    Hashtable with Available (bool), Version (string), Path (string)
#>
function Test-SAPIENBuildAvailable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SAPIENPath = "C:\Program Files\SAPIEN Technologies, Inc\PowerShell Studio 2026\SAPIENCommandLine.exe"
    )
    
    $result = @{
        Available = $false
        Version = ""
        Path = $SAPIENPath
    }
    
    try {
        if (Test-Path $SAPIENPath) {
            $result.Available = $true
            
            # Try to get version info
            $fileInfo = Get-Item $SAPIENPath
            $result.Version = $fileInfo.VersionInfo.FileVersion
        }
    }
    catch {
        Write-Verbose "Error checking SAPIEN availability: $($_.Exception.Message)"
    }
    
    return $result
}

<#
.SYNOPSIS
    Locates the .psproj file in a package folder
.DESCRIPTION
    Searches for FRB Installer.psproj in the PowerShell Studio folder structure
.PARAMETER PackagePath
    Root path of the package (e.g., C:\temp\packaging folder\Vendor\Product\Version)
.EXAMPLE
    $projPath = Find-ProjectFile -PackagePath "C:\temp\packaging folder\Adobe\Reader\24.0"
.OUTPUTS
    String path to .psproj file, or empty string if not found
#>
function Find-ProjectFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackagePath
    )
    
    try {
        # FRB Installer.psproj is directly in PackagePath
        $projPath = Join-Path $PackagePath "FRB Installer.psproj"
        
        if (Test-Path $projPath) {
            return $projPath
        }
        
        # Fallback: search recursively
        $projFiles = Get-ChildItem -Path $PackagePath -Filter "FRB Installer.psproj" -Recurse -ErrorAction SilentlyContinue
        if ($projFiles) {
            return $projFiles[0].FullName
        }
        
        return ""
        return ""
    }
    catch {
        Write-Verbose "Error finding project file: $($_.Exception.Message)"
        return ""
    }
}

#endregion Functions

# Export functions
Export-ModuleMember -Function Invoke-ProjectBuild, Test-SAPIENBuildAvailable, Find-ProjectFile

