#Requires -Version 5.1
<#
.SYNOPSIS
    Installation Detector Engine
    
.DESCRIPTION
    Detects installed applications and gathers installation details.
    Pure detection logic with no external dependencies.
    
.NOTES
    Author: P1MAM08
    Date: 2026-07-09
    Version: 1.0.0
    Type: Engine (Self-contained, integrable)
#>

#region Public Functions

function Find-InstalledApplication {
    <#
    .SYNOPSIS
        Searches for an installed application in the registry
        
    .PARAMETER AppName
        Application name to search for (supports partial matching)
        
    .OUTPUTS
        Array of found applications with details
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppName
    )
    
    Write-Verbose "Searching for application: $AppName"
    
    $uninstallPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    
    $foundApps = @()
    
    foreach ($path in $uninstallPaths) {
        try {
            $apps = Get-ItemProperty $path -ErrorAction SilentlyContinue
            foreach ($app in $apps) {
                if ($app.DisplayName -and ($app.DisplayName.IndexOf($AppName, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)) {
                    $foundApps += [PSCustomObject]@{
                        DisplayName = $app.DisplayName
                        DisplayVersion = $app.DisplayVersion
                        Publisher = $app.Publisher
                        InstallLocation = $app.InstallLocation
                        InstallDate = $app.InstallDate
                        UninstallString = $app.UninstallString
                        RegistryPath = $app.PSPath
                    }
                }
            }
        } catch {
            Write-Verbose "Could not access registry path: $path"
        }
    }
    
    Write-Verbose "Found $($foundApps.Count) matching applications"
    
    return $foundApps
}

function Get-InstallationDetails {
    <#
    .SYNOPSIS
        Gets comprehensive installation details for an application
        
    .PARAMETER AppName
        Application name
        
    .OUTPUTS
        Installation details object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppName
    )
    
    Write-Verbose "Getting installation details for: $AppName"
    
    # Find the application
    $apps = Find-InstalledApplication -AppName $AppName
    
    if ($apps.Count -eq 0) {
        Write-Warning "Application not found: $AppName"
        return $null
    }
    
    # Use the first match
    $app = $apps[0]
    
    # Gather details
    $details = [PSCustomObject]@{
        AppName = $app.DisplayName
        Version = $app.DisplayVersion
        Publisher = $app.Publisher
        InstallDirectory = $app.InstallLocation
        InstallDate = $app.InstallDate
        UninstallCommand = $app.UninstallString
        RegistryKey = $app.RegistryPath.Replace('Microsoft.PowerShell.Core\Registry::', '')
        DesktopShortcuts = (Get-ApplicationShortcuts -AppName $AppName -Location 'Desktop')
        StartMenuShortcuts = (Get-ApplicationShortcuts -AppName $AppName -Location 'StartMenu')
        Services = (Get-ApplicationServices -AppName $AppName)
        RegistryKeys = (Get-RegistryKeys -AppName $AppName)
    }
    
    Write-Verbose "Installation details gathered successfully"
    
    return $details
}

function Get-ApplicationServices {
    <#
    .SYNOPSIS
        Finds services related to an application
        
    .PARAMETER AppName
        Application name to search for
        
    .OUTPUTS
        Array of service names
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppName
    )
    
    Write-Verbose "Searching for services related to: $AppName"
    
    $services = Get-Service -ErrorAction SilentlyContinue | Where-Object {
        ($_.DisplayName.IndexOf($AppName, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) -or
        ($_.ServiceName.IndexOf($AppName, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
    }
    
    if ($services) {
        $serviceNames = $services | ForEach-Object { $_.Name }
        Write-Verbose "Found $($serviceNames.Count) services"
        return ($serviceNames -join ', ')
    } else {
        Write-Verbose "No services found"
        return 'None'
    }
}

function Get-ApplicationShortcuts {
    <#
    .SYNOPSIS
        Finds shortcuts related to an application
        
    .PARAMETER AppName
        Application name to search for
        
    .PARAMETER Location
        Location to search (Desktop, StartMenu, or Both)
        
    .OUTPUTS
        String of shortcut names
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppName,
        
        [Parameter()]
        [ValidateSet('Desktop', 'StartMenu', 'Both')]
        [string]$Location = 'Both'
    )
    
    Write-Verbose "Searching for shortcuts in: $Location"
    
    $shortcuts = @()
    $searchPaths = @()
    
    if ($Location -eq 'Desktop' -or $Location -eq 'Both') {
        $searchPaths += [Environment]::GetFolderPath('Desktop')
        $searchPaths += [Environment]::GetFolderPath('CommonDesktopDirectory')
    }
    
    if ($Location -eq 'StartMenu' -or $Location -eq 'Both') {
        $searchPaths += [Environment]::GetFolderPath('StartMenu')
        $searchPaths += [Environment]::GetFolderPath('CommonStartMenu')
    }
    
    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            $found = Get-ChildItem -Path $path -Filter "*.lnk" -Recurse -ErrorAction SilentlyContinue | 
                Where-Object { $_.Name.IndexOf($AppName, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 }
            
            if ($found) {
                $shortcuts += $found
            }
        }
    }
    
    if ($shortcuts.Count -gt 0) {
        $shortcutNames = $shortcuts | ForEach-Object { $_.Name }
        Write-Verbose "Found $($shortcutNames.Count) shortcuts"
        return ($shortcutNames -join ', ')
    } else {
        Write-Verbose "No shortcuts found"
        return 'None'
    }
}

function Get-RegistryKeys {
    <#
    .SYNOPSIS
        Finds registry keys related to an application
        
    .PARAMETER AppName
        Application name to search for
        
    .OUTPUTS
        String of registry key paths
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppName
    )
    
    Write-Verbose "Searching for registry keys related to: $AppName"
    
    $searchRoots = @(
        'HKLM:\SOFTWARE',
        'HKLM:\SOFTWARE\WOW6432Node',
        'HKCU:\SOFTWARE'
    )
    
    $foundKeys = @()
    
    foreach ($root in $searchRoots) {
        try {
            if (Test-Path $root) {
                $keys = Get-ChildItem -Path $root -ErrorAction SilentlyContinue | 
                    Where-Object { $_.Name.IndexOf($AppName, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 }
                
                if ($keys) {
                    foreach ($key in $keys) {
                        $keyPath = $key.Name.Replace('HKEY_LOCAL_MACHINE', 'HKLM')
                        $keyPath = $keyPath.Replace('HKEY_CURRENT_USER', 'HKCU')
                        $foundKeys += $keyPath
                    }
                }
            }
        } catch {
            Write-Verbose "Could not search: $root"
        }
    }
    
    if ($foundKeys.Count -gt 0) {
        Write-Verbose "Found $($foundKeys.Count) registry keys"
        return ($foundKeys -join '; ')
    } else {
        # Return default pattern
        $cleanName = $AppName.Replace(' ', '')
        Write-Verbose "No specific keys found, returning pattern"
        return "HKLM\SOFTWARE\$cleanName"
    }
}

function Test-ApplicationInstalled {
    <#
    .SYNOPSIS
        Checks if an application is installed
        
    .PARAMETER AppName
        Application name to check
        
    .OUTPUTS
        Boolean - true if installed, false otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppName
    )
    
    $apps = Find-InstalledApplication -AppName $AppName
    return ($apps.Count -gt 0)
}

#endregion

# Export public functions
Export-ModuleMember -Function @(
    'Find-InstalledApplication',
    'Get-InstallationDetails',
    'Get-ApplicationServices',
    'Get-ApplicationShortcuts',
    'Get-RegistryKeys',
    'Test-ApplicationInstalled'
)
