#Requires -Version 5.1

<#
.SYNOPSIS
    PathEngine - Manage portable packaging paths
.DESCRIPTION
    This engine manages the base packaging path configuration, allowing technicians
    to choose where packages are created. Supports both local and network paths.
.NOTES
    Author: FRB Automation Team
    Created: 2025-01-23
    Version: 1.0.0
    Part of: FRB Packaging Tool v3.1 - Enhancement 2
#>

function Test-PackagingPathConfigured {
    <#
    .SYNOPSIS
        Checks if the base packaging path is configured
    .DESCRIPTION
        Verifies that a valid base packaging path exists in the configuration
    .PARAMETER ConfigPath
        Path to app.config.json file
    .EXAMPLE
        $result = Test-PackagingPathConfigured -ConfigPath "C:\Temp\AI_Tools\FRB_Package_Creation_Tool\config\app.config.json"
    .OUTPUTS
        Hashtable with keys: IsConfigured (bool), Path (string), Message (string)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )
    
    Write-Verbose "PathEngine: Checking if packaging path is configured"
    
    try {
        if (-not (Test-Path $ConfigPath)) {
            return @{
                IsConfigured = $false
                Path = ""
                Message = "Configuration file not found"
            }
        }
        
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        
        $basePath = $config.paths.basePackagingPath
        $isConfigured = $config.paths.basePackagingPathConfigured
        
        if ([string]::IsNullOrWhiteSpace($basePath) -or $isConfigured -eq $false) {
            return @{
                IsConfigured = $false
                Path = ""
                Message = "Base packaging path not configured"
            }
        }
        
        # Verify the path exists or can be created
        if (-not (Test-Path $basePath)) {
            try {
                New-Item -Path $basePath -ItemType Directory -Force -ErrorAction Stop | Out-Null
                Write-Verbose "PathEngine: Created base packaging path: $basePath"
            }
            catch {
                return @{
                    IsConfigured = $false
                    Path = $basePath
                    Message = "Path configured but cannot be created: $($_.Exception.Message)"
                }
            }
        }
        
        return @{
            IsConfigured = $true
            Path = $basePath
            Message = "Base packaging path is configured and accessible"
        }
    }
    catch {
        Write-Error "PathEngine: Error checking configuration - $($_.Exception.Message)"
        return @{
            IsConfigured = $false
            Path = ""
            Message = $_.Exception.Message
        }
    }
}

function Set-PackagingPath {
    <#
    .SYNOPSIS
        Sets the base packaging path in configuration
    .DESCRIPTION
        Saves the user-selected packaging path to the configuration file
    .PARAMETER ConfigPath
        Path to app.config.json file
    .PARAMETER PackagingPath
        The new base packaging path
    .EXAMPLE
        $result = Set-PackagingPath -ConfigPath "C:\Temp\config.json" -PackagingPath "D:\MyPackages"
    .OUTPUTS
        Hashtable with keys: Success (bool), Path (string), Message (string)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,
        
        [Parameter(Mandatory = $true)]
        [string]$PackagingPath
    )
    
    Write-Verbose "PathEngine: Setting packaging path to: $PackagingPath"
    
    try {
        if (-not (Test-Path $ConfigPath)) {
            throw "Configuration file not found: $ConfigPath"
        }
        
        # Ensure the packaging path exists
        if (-not (Test-Path $PackagingPath)) {
            try {
                New-Item -Path $PackagingPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
                Write-Verbose "PathEngine: Created packaging directory: $PackagingPath"
            }
            catch {
                throw "Cannot create packaging directory: $($_.Exception.Message)"
            }
        }
        
        # Read current config
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        
        # Update packaging path
        $config.paths.basePackagingPath = $PackagingPath
        $config.paths.basePackagingPathConfigured = $true
        
        # Save config
        $config | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8 -Force
        
        Write-Verbose "PathEngine: Configuration updated successfully"
        
        return @{
            Success = $true
            Path = $PackagingPath
            Message = "Base packaging path configured successfully"
        }
    }
    catch {
        Write-Error "PathEngine: Error setting packaging path - $($_.Exception.Message)"
        return @{
            Success = $false
            Path = ""
            Message = $_.Exception.Message
        }
    }
}

function Get-PackagingPath {
    <#
    .SYNOPSIS
        Retrieves the configured packaging path
    .DESCRIPTION
        Gets the current base packaging path from configuration
    .PARAMETER ConfigPath
        Path to app.config.json file
    .EXAMPLE
        $result = Get-PackagingPath -ConfigPath "C:\Temp\config.json"
    .OUTPUTS
        Hashtable with keys: Success (bool), Path (string), Message (string)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )
    
    Write-Verbose "PathEngine: Retrieving packaging path"
    
    try {
        if (-not (Test-Path $ConfigPath)) {
            throw "Configuration file not found: $ConfigPath"
        }
        
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        $basePath = $config.paths.basePackagingPath
        
        if ([string]::IsNullOrWhiteSpace($basePath)) {
            return @{
                Success = $false
                Path = ""
                Message = "No packaging path configured"
            }
        }
        
        return @{
            Success = $true
            Path = $basePath
            Message = "Packaging path retrieved successfully"
        }
    }
    catch {
        Write-Error "PathEngine: Error retrieving packaging path - $($_.Exception.Message)"
        return @{
            Success = $false
            Path = ""
            Message = $_.Exception.Message
        }
    }
}

function Show-FolderBrowserDialog {
    <#
    .SYNOPSIS
        Shows a modern folder browser dialog
    .DESCRIPTION
        Displays a modern Windows folder browser dialog (Vista-style) for user to select a directory.
        Falls back to classic dialog if modern dialog fails.
    .PARAMETER Description
        Description text to show in dialog
    .PARAMETER SelectedPath
        Initial selected path (optional)
    .EXAMPLE
        $result = Show-FolderBrowserDialog -Description "Select packaging folder"
    .OUTPUTS
        Hashtable with keys: Success (bool), Path (string), Message (string)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Description = "Select the folder where you want to create packages",
        
        [Parameter(Mandatory = $false)]
        [string]$SelectedPath = ""
    )
    
    Write-Verbose "PathEngine: Showing modern folder browser dialog"
    
    try {
        # Try to use the modern folder picker via COM (Shell.Application)
        $shell = New-Object -ComObject Shell.Application
        
        # BrowseForFolder options:
        # 0x1 = BIF_RETURNONLYFSDIRS (only file system directories)
        # 0x10 = BIF_NEWDIALOGSTYLE (modern Vista-style dialog)
        # 0x40 = BIF_USENEWUI (use new UI with resizable dialog)
        # Combined: 0x51 = 81 decimal
        $options = 0x211
        
        # Get initial folder object if path provided
        $initialFolder = 0
        if (-not [string]::IsNullOrWhiteSpace($SelectedPath) -and (Test-Path $SelectedPath)) {
            try {
                $initialFolder = $shell.NameSpace($SelectedPath).Self.Path
            } catch {
                Write-Verbose "PathEngine: Could not set initial folder, using default"
                $initialFolder = 0
            }
        }
        
        # Show the modern folder browser
        $folder = $shell.BrowseForFolder(0, $Description, $options, $initialFolder)
        
        # Release COM object
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
        
        if ($null -ne $folder) {
            $selectedPath = $folder.Self.Path
            Write-Verbose "PathEngine: User selected: $selectedPath"
            
            return @{
                Success = $true
                Path = $selectedPath
                Message = "Folder selected successfully"
            }
        } else {
            return @{
                Success = $false
                Path = ""
                Message = "User cancelled folder selection"
            }
        }
    }
    catch {
        # Fallback to classic folder browser if COM fails
        Write-Warning "PathEngine: Modern folder browser failed, falling back to classic dialog - $($_.Exception.Message)"
        
        try {
            Add-Type -AssemblyName System.Windows.Forms
            
            $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
            $folderBrowser.Description = $Description
            $folderBrowser.ShowNewFolderButton = $true
            
            if (-not [string]::IsNullOrWhiteSpace($SelectedPath)) {
                $folderBrowser.SelectedPath = $SelectedPath
            }
            
            $result = $folderBrowser.ShowDialog()
            
            if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                $selectedPath = $folderBrowser.SelectedPath
                Write-Verbose "PathEngine: User selected (classic): $selectedPath"
                
                return @{
                    Success = $true
                    Path = $selectedPath
                    Message = "Folder selected successfully (classic dialog)"
                }
            } else {
                return @{
                    Success = $false
                    Path = ""
                    Message = "User cancelled folder selection"
                }
            }
        }
        catch {
            Write-Error "PathEngine: Error showing folder browser - $($_.Exception.Message)"
            return @{
                Success = $false
                Path = ""
                Message = $_.Exception.Message
            }
        }
    }
}

function Initialize-PackagingFolder {
    <#
    .SYNOPSIS
        Initializes the packaging folder structure
    .DESCRIPTION
        Creates necessary subdirectories and structure in the base packaging path
    .PARAMETER PackagingPath
        Base packaging path to initialize
    .EXAMPLE
        $result = Initialize-PackagingFolder -PackagingPath "D:\MyPackages"
    .OUTPUTS
        Hashtable with keys: Success (bool), Path (string), Message (string)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackagingPath
    )
    
    Write-Verbose "PathEngine: Initializing packaging folder structure"
    
    try {
        # Ensure base path exists
        if (-not (Test-Path $PackagingPath)) {
            New-Item -Path $PackagingPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-Verbose "PathEngine: Created base packaging path: $PackagingPath"
        }
        
        # Create README file for user guidance
        $readmePath = Join-Path $PackagingPath "README.txt"
        if (-not (Test-Path $readmePath)) {
            $readmeContent = @"
FRB Package Creation Tool - Packaging Folder
============================================

This folder contains packages created by the FRB Package Creation Tool.

Structure:
  Vendor\
    ProductName\
      Version\
        - Install.exe (compiled package)
        - Data\ (installer files)
        - Docs\ (validation reports)
        - Support Files\

Created: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Tool Version: v3.1.0
"@
            Set-Content -Path $readmePath -Value $readmeContent -Encoding UTF8
            Write-Verbose "PathEngine: Created README.txt"
        }
        
        return @{
            Success = $true
            Path = $PackagingPath
            Message = "Packaging folder initialized successfully"
        }
    }
    catch {
        Write-Error "PathEngine: Error initializing packaging folder - $($_.Exception.Message)"
        return @{
            Success = $false
            Path = ""
            Message = $_.Exception.Message
        }
    }
}

function Test-PathAccessible {
    <#
    .SYNOPSIS
        Tests if a path is accessible
    .DESCRIPTION
        Verifies that a path exists and has read/write permissions
    .PARAMETER Path
        Path to test
    .EXAMPLE
        $result = Test-PathAccessible -Path "\\server\share\packages"
    .OUTPUTS
        Hashtable with keys: Accessible (bool), CanRead (bool), CanWrite (bool), Message (string)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    Write-Verbose "PathEngine: Testing path accessibility: $Path"
    
    try {
        # Check if path exists
        if (-not (Test-Path $Path)) {
            return @{
                Accessible = $false
                CanRead = $false
                CanWrite = $false
                Message = "Path does not exist"
            }
        }
        
        # Test read access
        $canRead = $false
        try {
            $null = Get-ChildItem -Path $Path -ErrorAction Stop
            $canRead = $true
        }
        catch {
            Write-Verbose "PathEngine: Cannot read from path: $($_.Exception.Message)"
        }
        
        # Test write access
        $canWrite = $false
        $testFile = Join-Path $Path ".frb_write_test_$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
        try {
            Set-Content -Path $testFile -Value "test" -ErrorAction Stop
            Remove-Item -Path $testFile -Force -ErrorAction SilentlyContinue
            $canWrite = $true
        }
        catch {
            Write-Verbose "PathEngine: Cannot write to path: $($_.Exception.Message)"
        }
        
        $accessible = $canRead -and $canWrite
        $message = if ($accessible) {
            "Path is accessible with read and write permissions"
        } elseif ($canRead) {
            "Path is read-only"
        } elseif ($canWrite) {
            "Path is write-only (unusual)"
        } else {
            "Path exists but is not accessible"
        }
        
        return @{
            Accessible = $accessible
            CanRead = $canRead
            CanWrite = $canWrite
            Message = $message
        }
    }
    catch {
        Write-Error "PathEngine: Error testing path accessibility - $($_.Exception.Message)"
        return @{
            Accessible = $false
            CanRead = $false
            CanWrite = $false
            Message = $_.Exception.Message
        }
    }
}

function Test-FirstRunComplete {
    <#
    .SYNOPSIS
        Checks if first-time setup has been completed
    .DESCRIPTION
        Verifies if the tool has been set up on this PC by checking the firstRunCompleted flag
    .PARAMETER ConfigPath
        Path to app.config.json file
    .EXAMPLE
        $result = Test-FirstRunComplete -ConfigPath "C:\Temp\config.json"
    .OUTPUTS
        Hashtable with keys: Completed (bool), SetupDate (string), Message (string)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )
    
    Write-Verbose "PathEngine: Checking if first run is complete"
    
    try {
        if (-not (Test-Path $ConfigPath)) {
            return @{
                Completed = $false
                SetupDate = ""
                Message = "Configuration file not found - first run required"
            }
        }
        
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        
        # Check if firstRunCompleted flag exists and is true
        $firstRunCompleted = $false
        if ($config.settings.PSObject.Properties.Name -contains 'firstRunCompleted') {
            $firstRunCompleted = $config.settings.firstRunCompleted
        }
        
        $setupDate = ""
        if ($config.settings.PSObject.Properties.Name -contains 'setupCompletedDate') {
            $setupDate = $config.settings.setupCompletedDate
        }
        
        if ($firstRunCompleted) {
            return @{
                Completed = $true
                SetupDate = $setupDate
                Message = "First-time setup already completed"
            }
        } else {
            return @{
                Completed = $false
                SetupDate = ""
                Message = "First-time setup not completed"
            }
        }
    }
    catch {
        Write-Error "PathEngine: Error checking first run status - $($_.Exception.Message)"
        return @{
            Completed = $false
            SetupDate = ""
            Message = $_.Exception.Message
        }
    }
}

function Set-FirstRunComplete {
    <#
    .SYNOPSIS
        Marks first-time setup as completed
    .DESCRIPTION
        Sets the firstRunCompleted flag and records the setup date
    .PARAMETER ConfigPath
        Path to app.config.json file
    .EXAMPLE
        $result = Set-FirstRunComplete -ConfigPath "C:\Temp\config.json"
    .OUTPUTS
        Hashtable with keys: Success (bool), Message (string)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )
    
    Write-Verbose "PathEngine: Marking first run as complete"
    
    try {
        if (-not (Test-Path $ConfigPath)) {
            throw "Configuration file not found: $ConfigPath"
        }
        
        # Read current config
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        
        # Set first run completed flag
        $config.settings | Add-Member -MemberType NoteProperty -Name 'firstRunCompleted' -Value $true -Force
        $config.settings | Add-Member -MemberType NoteProperty -Name 'setupCompletedDate' -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Force
        
        # Save config
        $config | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8 -Force
        
        Write-Verbose "PathEngine: First run marked as complete"
        
        return @{
            Success = $true
            Message = "First-time setup marked as complete"
        }
    }
    catch {
        Write-Error "PathEngine: Error marking first run complete - $($_.Exception.Message)"
        return @{
            Success = $false
            Message = $_.Exception.Message
        }
    }
}

# Export public functions
Export-ModuleMember -Function Test-PackagingPathConfigured, Set-PackagingPath, Get-PackagingPath, Show-FolderBrowserDialog, Initialize-PackagingFolder, Test-PathAccessible, Test-FirstRunComplete, Set-FirstRunComplete

