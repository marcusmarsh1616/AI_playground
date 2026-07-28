#Requires -Version 5.1

<#
.SYNOPSIS
    ConfigurationManager Module - Centralized configuration management
.DESCRIPTION
    Loads and merges configuration from multiple JSON files, provides
    easy access to settings, and validates configuration.
.NOTES
    Author: FRB Automation Team
    Created: June 5, 2026
    Version: 1.0.0
#>

function Get-AppConfiguration {
    <#
    .SYNOPSIS
        Load and merge all configuration files
    .PARAMETER ConfigPath
        Path to config folder (default: config)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath
    )
    
    if (-not $ConfigPath) {
        $ConfigPath = Join-Path $PSScriptRoot "..\..\config"
    }
    
    $config = @{
        App = $null
        Logging = $null
        Paths = $null
        Engines = $null
    }
    
    try {
        # Load app.config.json
        $appConfigFile = Join-Path $ConfigPath "app.config.json"
        if (Test-Path $appConfigFile) {
            $config.App = Get-Content $appConfigFile -Raw | ConvertFrom-Json
        }
        
        # Load logging.config.json
        $loggingConfigFile = Join-Path $ConfigPath "logging.config.json"
        if (Test-Path $loggingConfigFile) {
            $config.Logging = Get-Content $loggingConfigFile -Raw | ConvertFrom-Json
        }
        
        # Load paths.config.json
        $pathsConfigFile = Join-Path $ConfigPath "paths.config.json"
        if (Test-Path $pathsConfigFile) {
            $config.Paths = Get-Content $pathsConfigFile -Raw | ConvertFrom-Json
        } else {
            # Fall back to app.config.json paths section
            if ($config.App -and $config.App.paths) {
                $config.Paths = $config.App.paths
            }
        }
        
        # Load engines.config.json
        $enginesConfigFile = Join-Path $ConfigPath "engines.config.json"
        if (Test-Path $enginesConfigFile) {
            $config.Engines = Get-Content $enginesConfigFile -Raw | ConvertFrom-Json
        }
        
        return $config
    }
    catch {
        Write-Warning "Failed to load configuration: $($_.Exception.Message)"
        return $null
    }
}

function Get-ConfigValue {
    <#
    .SYNOPSIS
        Get a specific configuration value
    .PARAMETER Config
        Configuration object
    .PARAMETER Path
        Dot-notation path to value (e.g., "Paths.masterTemplatePath")
    .PARAMETER Default
        Default value if not found
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        $Default = $null
    )
    
    $parts = $Path -split '\.'
    $current = $Config
    
    foreach ($part in $parts) {
        if ($current -is [hashtable] -and $current.ContainsKey($part)) {
            $current = $current[$part]
        }
        elseif ($current -is [PSCustomObject] -and ($current.PSObject.Properties.Name -contains $part)) {
            $current = $current.$part
        }
        else {
            return $Default
        }
    }
    
    return $current
}

function Test-AppConfiguration {
    <#
    .SYNOPSIS
        Validate configuration is complete and correct
    .PARAMETER Config
        Configuration object to validate
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [hashtable]$Config
    )
    
    if (-not $Config) {
        $Config = Get-AppConfiguration
    }
    
    $errors = @()
    $warnings = @()
    
    # Check paths configuration
    if ($Config.Paths) {
        # Check master template path
        $masterTemplate = Get-ConfigValue -Config $Config -Path "Paths.templates.masterTemplatePath"
        if ($masterTemplate -and -not (Test-Path $masterTemplate)) {
            $warnings += "Master template path does not exist: $masterTemplate"
        }
        
        # Check base packaging path
        $basePackaging = Get-ConfigValue -Config $Config -Path "Paths.packaging.basePackagingPath"
        if ($basePackaging -and -not (Test-Path $basePackaging)) {
            $warnings += "Base packaging path does not exist: $basePackaging"
        }
        
        # Check PowerShell Studio
        $psStudio = Get-ConfigValue -Config $Config -Path "Paths.tools.powerShellStudioExe"
        if ($psStudio -and -not (Test-Path $psStudio)) {
            $warnings += "PowerShell Studio not found: $psStudio (Build functionality will be limited)"
        }
    } else {
        $errors += "Paths configuration is missing"
    }
    
    # Check logging configuration
    if (-not $Config.Logging) {
        $warnings += "Logging configuration is missing, using defaults"
    }
    
    return @{
        IsValid = ($errors.Count -eq 0)
        Errors = $errors
        Warnings = $warnings
    }
}

function Set-ConfigValue {
    <#
    .SYNOPSIS
        Update a configuration value and save to file
    .PARAMETER ConfigFile
        Path to config file
    .PARAMETER Path
        Dot-notation path to value
    .PARAMETER Value
        New value
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigFile,
        
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        $Value
    )
    
    try {
        if (-not (Test-Path $ConfigFile)) {
            throw "Config file not found: $ConfigFile"
        }
        
        $config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        
        $parts = $Path -split '\.'
        $current = $config
        
        for ($i = 0; $i -lt $parts.Count - 1; $i++) {
            $part = $parts[$i]
            if (-not ($current.PSObject.Properties.Name -contains $part)) {
                $current | Add-Member -NotePropertyName $part -NotePropertyValue ([PSCustomObject]@{})
            }
            $current = $current.$part
        }
        
        $lastPart = $parts[-1]
        if ($current.PSObject.Properties.Name -contains $lastPart) {
            $current.$lastPart = $Value
        } else {
            $current | Add-Member -NotePropertyName $lastPart -NotePropertyValue $Value
        }
        
        $config | ConvertTo-Json -Depth 10 | Set-Content $ConfigFile -Encoding UTF8
        
        return $true
    }
    catch {
        Write-Warning "Failed to update config: $($_.Exception.Message)"
        return $false
    }
}

# Export functions
Export-ModuleMember -Function Get-AppConfiguration, Get-ConfigValue, Test-AppConfiguration, Set-ConfigValue
