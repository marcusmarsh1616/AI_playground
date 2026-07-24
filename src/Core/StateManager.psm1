#Requires -Version 5.1

<#
.SYNOPSIS
    StateManager Module - Application state tracking
.DESCRIPTION
    Tracks the current state of package creation, allowing for
    resume capability and better error recovery.
.NOTES
    Author: FRB Automation Team
    Created: June 5, 2026
    Version: 1.0.0
#>

$script:AppState = $null

function Initialize-AppState {
    <#
    .SYNOPSIS
        Initialize a new application state
    #>
    [CmdletBinding()]
    param()
    
    $script:AppState = @{
        InstallerPath = ""
        InstallerType = ""
        Vendor = ""
        ProductName = ""
        Version = ""
        InstallSwitch = ""
        UninstallSwitch = ""
        UninstallExecutable = ""
        PackagePath = ""
        ProjectPath = ""
        BuildPath = ""
        PackageCreated = $false
        ProjectBuilt = $false
        TestResults = @()
        CreatedDate = Get-Date
        LastModified = Get-Date
    }
    
    if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
        Write-AppLog "Application state initialized" -Level Info -Component "StateManager"
    }
    
    return $script:AppState
}

function Get-PackageState {
    <#
    .SYNOPSIS
        Get the current package state
    #>
    [CmdletBinding()]
    param()
    
    if (-not $script:AppState) {
        Initialize-AppState
    }
    
    return $script:AppState
}

function Set-PackageState {
    <#
    .SYNOPSIS
        Update package state
    .PARAMETER Property
        Property name to update
    .PARAMETER Value
        New value
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Property,
        
        [Parameter(Mandatory = $true)]
        $Value
    )
    
    if (-not $script:AppState) {
        Initialize-AppState
    }
    
    if ($script:AppState.ContainsKey($Property)) {
        $script:AppState[$Property] = $Value
        $script:AppState.LastModified = Get-Date
        
        if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
            Write-AppLog "State updated: $Property = $Value" -Level Debug -Component "StateManager"
        }
    } else {
        Write-Warning "Unknown state property: $Property"
    }
}

function Reset-PackageState {
    <#
    .SYNOPSIS
        Reset state for new package
    .PARAMETER PreserveConfig
        Keep configuration-related state
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$PreserveConfig
    )
    
    Initialize-AppState
    
    if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
        Write-AppLog "Package state reset" -Level Info -Component "StateManager"
    }
}

function Export-AppState {
    <#
    .SYNOPSIS
        Save state to file
    .PARAMETER FilePath
        Path to save state file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    try {
        if (-not $script:AppState) {
            throw "No state to export"
        }
        
        $script:AppState | ConvertTo-Json -Depth 10 | Set-Content $FilePath -Encoding UTF8
        
        if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
            Write-AppLog "State exported to: $FilePath" -Level Info -Component "StateManager"
        }
        
        return $true
    }
    catch {
        if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
            Write-AppLog "Failed to export state: $($_.Exception.Message)" -Level Error -Component "StateManager"
        }
        return $false
    }
}

function Import-AppState {
    <#
    .SYNOPSIS
        Load state from file
    .PARAMETER FilePath
        Path to state file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    try {
        if (-not (Test-Path $FilePath)) {
            throw "State file not found: $FilePath"
        }
        
        $script:AppState = Get-Content $FilePath -Raw | ConvertFrom-Json -AsHashtable
        
        if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
            Write-AppLog "State imported from: $FilePath" -Level Info -Component "StateManager"
        }
        
        return $script:AppState
    }
    catch {
        if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
            Write-AppLog "Failed to import state: $($_.Exception.Message)" -Level Error -Component "StateManager"
        }
        return $null
    }
}

# Export functions
Export-ModuleMember -Function Initialize-AppState, Get-PackageState, Set-PackageState, Reset-PackageState, Export-AppState, Import-AppState
