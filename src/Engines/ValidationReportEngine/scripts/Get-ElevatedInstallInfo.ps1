#Requires -Version 5.1
<#
.SYNOPSIS
    Collects installation details and outputs formatted text
    
.PARAMETER AppName
    Application name to search for
    
.PARAMETER OutputFile
    Path to output text file
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$AppName,

    [Parameter(Mandatory=$false)]
    [string]$AppVersion = "",

    [Parameter(Mandatory=$true)]
    [string]$OutputFile
)

$ErrorActionPreference = 'Continue'

# Escape once and reuse everywhere -match is used against a technician-entered
# name; unescaped, characters like '.', '(', '+' make the regex misbehave.
$NamePattern = [regex]::Escape($AppName)

# Build output text
$output = @()
$output += "=== INSTALLATION DETAILS FOR $AppName ==="
$output += ""

# --- 1. UNINSTALL REGISTRY KEYS ---
$RegPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$RegistryMatches = @(Get-ItemProperty -Path $RegPaths -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -match $NamePattern -or $_.PSChildName -match $NamePattern })

if ($RegistryMatches.Count -gt 0) {
    if (-not [string]::IsNullOrWhiteSpace($AppVersion)) {
        $versionMatches = @($RegistryMatches | Where-Object { $_.DisplayVersion -and $_.DisplayVersion.Trim() -eq $AppVersion.Trim() })
        if ($versionMatches.Count -gt 0) {
            $RegistryMatches = $versionMatches
        } else {
            $output += "[WARNING] No uninstall registry entry for '$AppName' has DisplayVersion matching claimed version '$AppVersion'. Found version(s): $((@($RegistryMatches | ForEach-Object { $_.DisplayVersion }) | Where-Object { $_ } | Select-Object -Unique) -join ', ')"
            $output += ""
        }
    }

    $output += "[UNINSTALL REGISTRY KEYS]"
    foreach ($Reg in $RegistryMatches) {
        $output += "  Display Name: $($Reg.DisplayName)"
        $output += "  Version: $($Reg.DisplayVersion)"
        $output += "  Publisher: $($Reg.Publisher)"
        $output += "  Install Location: $($Reg.InstallLocation)"
        $output += "  Registry Path: $($Reg.PSPath)"
        $output += ""
    }
} else {
    $output += "[ERROR] No uninstall registry keys found for '$AppName'"
    $output += ""
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllLines($OutputFile, $output, $utf8)
    exit 1
}

# --- 2. CONFIGURATION REGISTRY KEYS ---
$output += "[CONFIGURATION REGISTRY KEYS]"
$ConfigKeys = @()

$configRoots = @(
    "HKLM:\SOFTWARE",
    "HKLM:\SOFTWARE\Wow6432Node",
    "HKCU:\SOFTWARE"
)

foreach ($root in $configRoots) {
    if (Test-Path $root) {
        $topLevel = Get-ChildItem $root -ErrorAction SilentlyContinue | 
            Where-Object { $_.PSChildName -match $NamePattern }
        foreach ($key in $topLevel) {
            $ConfigKeys += $key.PSPath
        }
        
        $vendors = Get-ChildItem $root -ErrorAction SilentlyContinue
        foreach ($vendor in $vendors) {
            $appKeys = Get-ChildItem $vendor.PSPath -ErrorAction SilentlyContinue | 
                Where-Object { $_.PSChildName -match $NamePattern }
            foreach ($key in $appKeys) {
                $ConfigKeys += $key.PSPath
            }
        }
    }
}

$ConfigKeys = $ConfigKeys | Select-Object -Unique

if ($ConfigKeys.Count -gt 0) {
    foreach ($key in $ConfigKeys) {
        $output += "  $key"
    }
} else {
    $output += "  None detected"
}
$output += ""

# --- 3. START MENU ENTRIES ---
$output += "[START MENU ENTRIES]"
$StartMenuPaths = @(
    "C:\ProgramData\Microsoft\Windows\Start Menu\Programs",
    "$env:AppData\Microsoft\Windows\Start Menu\Programs"
)

$StartMenuEntries = @()
foreach ($path in $StartMenuPaths) {
    if (Test-Path $path) {
        $folders = Get-ChildItem $path -Directory -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -match $NamePattern }
        foreach ($folder in $folders) {
            $StartMenuEntries += $folder.FullName
        }
        
        $shortcuts = Get-ChildItem $path -Filter "*.lnk" -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -match $NamePattern }
        foreach ($shortcut in $shortcuts) {
            $StartMenuEntries += $shortcut.FullName
        }
    }
}

if ($StartMenuEntries.Count -gt 0) {
    foreach ($entry in $StartMenuEntries) {
        $output += "  $entry"
    }
} else {
    $output += "  None detected"
}
$output += ""

# --- 4. SERVICES ---
$output += "[SERVICES]"
$foundServices = Get-Service -ErrorAction SilentlyContinue | 
    Where-Object { $_.DisplayName -match $NamePattern -or $_.Name -match $NamePattern }

if ($foundServices) {
    foreach ($svc in $foundServices) {
        $output += "  Name: $($svc.Name)"
        $output += "  Display Name: $($svc.DisplayName)"
        $output += "  Status: $($svc.Status)"
        $output += "  Start Type: $($svc.StartType)"
        $output += ""
    }
} else {
    $output += "  None detected"
}
$output += ""

# --- 5. INSTALLATION DIRECTORIES ---
$output += "[INSTALLATION DIRECTORIES]"
$TargetDirs = @()

foreach ($Reg in $RegistryMatches) {
    if ($Reg.InstallLocation) { 
        $TargetDirs += $Reg.InstallLocation 
    }
    if ($Reg.DisplayIcon) { 
        $iconPath = $Reg.DisplayIcon -replace '"',''
        $parentPath = Split-Path -Path $iconPath -Parent -ErrorAction SilentlyContinue
        if ($parentPath) {
            $TargetDirs += $parentPath
        }
    }
}

$SearchRoots = @(
    $env:ProgramFiles, 
    ${env:ProgramFiles(x86)}, 
    $env:AppData, 
    $env:LocalAppData, 
    $env:ProgramData
)

foreach ($Root in $SearchRoots) {
    if (Test-Path $Root) {
        $FoundDirs = Get-ChildItem -Path $Root -Directory -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -match $NamePattern }
        foreach ($FD in $FoundDirs) { 
            $TargetDirs += $FD.FullName 
        }
    }
}

$TargetDirs = $TargetDirs | Select-Object -Unique | Where-Object { $_ -and (Test-Path $_) }

if ($TargetDirs.Count -gt 0) {
    foreach ($dir in $TargetDirs) {
        $output += "  $dir"
    }
} else {
    $output += "  None detected"
}
$output += ""

# --- WRITE OUTPUT ---
$output += "=== COLLECTION COMPLETE ==="

$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines($OutputFile, $output, $utf8)

exit 0