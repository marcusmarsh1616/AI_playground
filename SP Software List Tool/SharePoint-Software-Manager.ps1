<#
.SYNOPSIS
    Ultimate SharePoint Software Manager - The Lazy Person's Dream App.

.DESCRIPTION
    Full-featured GUI for managing software in SharePoint:
    - Add new software with form templates
    - Update existing software
    - Search and filter items
    - View recent additions
    - Copy previous entries
    - Save/load form presets
    
    Includes automatic prerequisite checking and installation.

.NOTES
    Requires: PowerShell 7+
    Auto-installs: PnP.PowerShell 2.x if not present
    Author: Your Friendly Neighborhood AI
    Version: 2.0 - Ultimate Edition
    
.EXAMPLE
    .\SharePoint-Software-Manager.ps1
#>

#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$SiteUrl = "https://frbprod1.sharepoint.com/sites/EUSEndpointasaService",

    [Parameter(Mandatory=$false)]
    [string]$ListTitle = "Endpoint Software List",
    
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = "$env:USERPROFILE\SPSoftwareManager_Config.json",
    
    [Parameter(Mandatory=$false)]
    [switch]$PreConnect
)

# ══════════════════════════════════════════════════════════════════════════════
# PREREQUISITES CHECK & INSTALLATION
# ══════════════════════════════════════════════════════════════════════════════

function Test-PnPModuleInstalled {
    [CmdletBinding()]
    param()
    
    Begin {}
    Process {
        $module = Get-Module -Name PnP.PowerShell -ListAvailable | 
                  Where-Object { $_.Version -like "2.*" } | 
                  Select-Object -First 1
        
        if ($null -ne $module) {
            Write-Host "✅ PnP.PowerShell $($module.Version) is installed" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "❌ PnP.PowerShell 2.x not found" -ForegroundColor Yellow
            return $false
        }
    }
    End {}
}

function Install-PnPModuleIfNeeded {
    [CmdletBinding()]
    param()
    
    Begin {}
    Process {
        try {
            Write-Host "📦 Installing PnP.PowerShell 2.x..." -ForegroundColor Cyan
            Write-Host "   This may take a minute..." -ForegroundColor Gray
            
            $version3 = Get-Module PnP.PowerShell -ListAvailable | Where-Object { $_.Version -like "3.*" }
            if ($version3) {
                Write-Host "   Removing PnP.PowerShell 3.x (incompatible)..." -ForegroundColor Yellow
                Uninstall-Module PnP.PowerShell -AllVersions -Force -ErrorAction SilentlyContinue
            }
            
            Install-Module PnP.PowerShell -MaximumVersion 2.99.0 -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
            
            Write-Host "✅ PnP.PowerShell 2.x installed successfully!" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "❌ Failed to install PnP.PowerShell: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
    End {}
}

function Initialize-PnPModule {
    [CmdletBinding()]
    param()
    
    Begin {
        Write-Host "" 
        Write-Host "══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Checking Prerequisites" -ForegroundColor Cyan
        Write-Host "══════════════════════════════════════════════════" -ForegroundColor Cyan
    }
    
    Process {
        Write-Host "Checking PowerShell version..." -ForegroundColor White
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            Write-Host "❌ PowerShell 7+ is required!" -ForegroundColor Red
            Write-Host "   Current version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
            Write-Host "   Download from: https://aka.ms/powershell" -ForegroundColor Cyan
            return $false
        }
        Write-Host "✅ PowerShell $($PSVersionTable.PSVersion) detected" -ForegroundColor Green
        
        Write-Host "Checking PnP.PowerShell module..." -ForegroundColor White
        $isInstalled = Test-PnPModuleInstalled
        
        if (-not $isInstalled) {
            Write-Host "PnP.PowerShell 2.x is required but not installed." -ForegroundColor Yellow
            $response = Read-Host "Install PnP.PowerShell 2.x now? (Y/N)"
            
            if ($response -eq "Y" -or $response -eq "y") {
                $installed = Install-PnPModuleIfNeeded
                if (-not $installed) {
                    Write-Host "❌ Cannot proceed without PnP.PowerShell" -ForegroundColor Red
                    return $false
                }
            }
            else {
                Write-Host "❌ Cannot proceed without PnP.PowerShell" -ForegroundColor Red
                return $false
            }
        }
        
        Write-Host "Loading PnP.PowerShell module..." -ForegroundColor White
        try {
            Import-Module PnP.PowerShell -Force -ErrorAction Stop
            $loadedVersion = (Get-Module PnP.PowerShell).Version
            Write-Host "✅ PnP.PowerShell $loadedVersion loaded successfully" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Failed to load PnP.PowerShell: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
        
        Write-Host "" 
        Write-Host "✅ All prerequisites satisfied!" -ForegroundColor Green
        Write-Host "══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "" 
        
        return $true
    }
    End {}
}

# ══════════════════════════════════════════════════════════════════════════════
# CONFIG MANAGEMENT
# ══════════════════════════════════════════════════════════════════════════════

function Save-FormConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$FormData,
        
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    Begin {}
    Process {
        try {
            $FormData | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Force
            return $true
        }
        catch {
            Write-Host "Failed to save config: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
    End {}
}

function Load-FormConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    Begin {}
    Process {
        try {
            if (Test-Path $Path) {
                $config = Get-Content -Path $Path -Raw | ConvertFrom-Json
                return $config
            }
            return $null
        }
        catch {
            Write-Host "Failed to load config: $($_.Exception.Message)" -ForegroundColor Red
            return $null
        }
    }
    End {}
}

# ══════════════════════════════════════════════════════════════════════════════
# SHAREPOINT FUNCTIONS
# ══════════════════════════════════════════════════════════════════════════════

function Connect-SharePointSite {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url
    )
    
    Begin {}
    Process {
        try {
            Connect-PnPOnline -Url $Url -UseWebLogin -ErrorAction Stop
            return $true
        }
        catch {
            Write-Host "Connection failed: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
    End {}
}

function Get-NextRefNumber {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ListName
    )
    
    Begin {}
    Process {
        try {
            $existingItems = Get-PnPListItem -List $ListName -Fields "Ref" -PageSize 1000
            $maxRef = ($existingItems | ForEach-Object { $_.FieldValues.Ref } | Measure-Object -Maximum).Maximum
            $nextRef = if ($maxRef) { $maxRef + 1 } else { 1 }
            return $nextRef
        }
        catch {
            Write-Host "Error getting Ref number: $($_.Exception.Message)" -ForegroundColor Red
            return 1
        }
    }
    End {}
}

function Add-SoftwareItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ListName,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$Values
    )
    
    Begin {}
    Process {
        try {
            $item = Add-PnPListItem -List $ListName -Values $Values -ErrorAction Stop
            return $item
        }
        catch {
            Write-Host "Error creating item: $($_.Exception.Message)" -ForegroundColor Red
            return $null
        }
    }
    End {}
}

function Update-SoftwareItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ListName,
        
        [Parameter(Mandatory=$true)]
        [int]$ItemId,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$Values
    )
    
    Begin {}
    Process {
        try {
            Set-PnPListItem -List $ListName -Identity $ItemId -Values $Values -ErrorAction Stop
            return $true
        }
        catch {
            Write-Host "Error updating item: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
    End {}
}

function Get-SoftwareItems {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ListName,
        
        [Parameter(Mandatory=$false)]
        [int]$Limit = 100
    )
    
    Begin {}
    Process {
        try {
            $items = Get-PnPListItem -List $ListName -PageSize $Limit
            return $items
        }
        catch {
            Write-Host "Error retrieving items: $($_.Exception.Message)" -ForegroundColor Red
            return @()
        }
    }
    End {}
}

function Search-SoftwareItems {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ListName,
        
        [Parameter(Mandatory=$true)]
        [string]$SearchTerm
    )
    
    Begin {}
    Process {
        try {
            $items = Get-PnPListItem -List $ListName -PageSize 500
            $filtered = $items | Where-Object { 
                $_.FieldValues.Title -like "*$SearchTerm*" -or 
                $_.FieldValues.Vendor -like "*$SearchTerm*"
            }
            return $filtered
        }
        catch {
            Write-Host "Error searching items: $($_.Exception.Message)" -ForegroundColor Red
            return @()
        }
    }
    End {}
}

# ══════════════════════════════════════════════════════════════════════════════
# STARTUP
# ══════════════════════════════════════════════════════════════════════════════

Write-Host "" 
Write-Host "🚀 SharePoint Software Manager - Ultimate Edition" -ForegroundColor Cyan
Write-Host "" 

$prereqsOk = Initialize-PnPModule

if (-not $prereqsOk) {
    Write-Host "" 
    Write-Host "❌ Cannot start application due to missing prerequisites." -ForegroundColor Red
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Pre-Connect Mode (connect before GUI launches)
$script:isConnected = $false

if ($PreConnect) {
    Write-Host "" 
    Write-Host "══════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Pre-Connect Mode" -ForegroundColor Cyan
    Write-Host "══════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Connecting to SharePoint..." -ForegroundColor White
    Write-Host "Browser window will open for authentication." -ForegroundColor Yellow
    Write-Host "" 
    
    $connected = Connect-SharePointSite -Url $SiteUrl
    
    if ($connected) {
        Write-Host "✅ Connected successfully!" -ForegroundColor Green
        Write-Host "" 
        $script:isConnected = $true
    }
    else {
        Write-Host "❌ Connection failed!" -ForegroundColor Red
        Write-Host "" 
        Write-Host "The GUI will still open, but you'll need to connect manually." -ForegroundColor Yellow
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    
    Write-Host "══════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "" 
}

# ══════════════════════════════════════════════════════════════════════════════
# GUI CONSTRUCTION
# ══════════════════════════════════════════════════════════════════════════════

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Main Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "SharePoint Software Manager - Ultimate Edition"
$form.Size = New-Object System.Drawing.Size(900, 850)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# Create TabControl
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(10, 50)
$tabControl.Size = New-Object System.Drawing.Size(860, 680)
$form.Controls.Add($tabControl)

# ═══════════════════════════════════════════════════════════════
# TAB 1: ADD SOFTWARE
# ═══════════════════════════════════════════════════════════════

$tabAdd = New-Object System.Windows.Forms.TabPage
$tabAdd.Text = "➕ Add New"
$tabControl.Controls.Add($tabAdd)

# Scroll panel for add form
$scrollAdd = New-Object System.Windows.Forms.Panel
$scrollAdd.Location = New-Object System.Drawing.Point(5, 5)
$scrollAdd.Size = New-Object System.Drawing.Size(840, 640)
$scrollAdd.AutoScroll = $true
$scrollAdd.BorderStyle = "FixedSingle"
$tabAdd.Controls.Add($scrollAdd)

$yPos = 10

# Quick Load Section
$grpQuickLoad = New-Object System.Windows.Forms.GroupBox
$grpQuickLoad.Location = New-Object System.Drawing.Point(10, $yPos)
$grpQuickLoad.Size = New-Object System.Drawing.Size(800, 60)
$grpQuickLoad.Text = "Quick Actions"
$scrollAdd.Controls.Add($grpQuickLoad)

$btnLoadLast = New-Object System.Windows.Forms.Button
$btnLoadLast.Location = New-Object System.Drawing.Point(10, 20)
$btnLoadLast.Size = New-Object System.Drawing.Size(120, 30)
$btnLoadLast.Text = "Load Last Entry"
$btnLoadLast.BackColor = [System.Drawing.Color]::LightBlue
$grpQuickLoad.Controls.Add($btnLoadLast)

$btnLoadTemplate = New-Object System.Windows.Forms.Button
$btnLoadTemplate.Location = New-Object System.Drawing.Point(140, 20)
$btnLoadTemplate.Size = New-Object System.Drawing.Size(120, 30)
$btnLoadTemplate.Text = "Load Template"
$btnLoadTemplate.BackColor = [System.Drawing.Color]::LightBlue
$grpQuickLoad.Controls.Add($btnLoadTemplate)

$btnSaveTemplate = New-Object System.Windows.Forms.Button
$btnSaveTemplate.Location = New-Object System.Drawing.Point(270, 20)
$btnSaveTemplate.Size = New-Object System.Drawing.Size(120, 30)
$btnSaveTemplate.Text = "Save as Template"
$btnSaveTemplate.BackColor = [System.Drawing.Color]::LightGreen
$grpQuickLoad.Controls.Add($btnSaveTemplate)

$btnClearForm = New-Object System.Windows.Forms.Button
$btnClearForm.Location = New-Object System.Drawing.Point(400, 20)
$btnClearForm.Size = New-Object System.Drawing.Size(120, 30)
$btnClearForm.Text = "Clear Form"
$grpQuickLoad.Controls.Add($btnClearForm)

$yPos += 70

# Title
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Location = New-Object System.Drawing.Point(10, $yPos)
$lblTitle.Size = New-Object System.Drawing.Size(200, 20)
$lblTitle.Text = "Title (Software Name) *"
$scrollAdd.Controls.Add($lblTitle)

$txtTitle = New-Object System.Windows.Forms.TextBox
$txtTitle.Location = New-Object System.Drawing.Point(220, $yPos)
$txtTitle.Size = New-Object System.Drawing.Size(580, 20)
$scrollAdd.Controls.Add($txtTitle)
$yPos += 30

# Vendor
$lblVendor = New-Object System.Windows.Forms.Label
$lblVendor.Location = New-Object System.Drawing.Point(10, $yPos)
$lblVendor.Size = New-Object System.Drawing.Size(200, 20)
$lblVendor.Text = "Vendor *"
$scrollAdd.Controls.Add($lblVendor)

$txtVendor = New-Object System.Windows.Forms.TextBox
$txtVendor.Location = New-Object System.Drawing.Point(220, $yPos)
$txtVendor.Size = New-Object System.Drawing.Size(580, 20)
$scrollAdd.Controls.Add($txtVendor)
$yPos += 30

# Version
$lblVersion = New-Object System.Windows.Forms.Label
$lblVersion.Location = New-Object System.Drawing.Point(10, $yPos)
$lblVersion.Size = New-Object System.Drawing.Size(200, 20)
$lblVersion.Text = "Version # (alt.)"
$scrollAdd.Controls.Add($lblVersion)

$txtVersion = New-Object System.Windows.Forms.TextBox
$txtVersion.Location = New-Object System.Drawing.Point(220, $yPos)
$txtVersion.Size = New-Object System.Drawing.Size(580, 20)
$scrollAdd.Controls.Add($txtVersion)
$yPos += 30

# User AD Group
$lblUserAD = New-Object System.Windows.Forms.Label
$lblUserAD.Location = New-Object System.Drawing.Point(10, $yPos)
$lblUserAD.Size = New-Object System.Drawing.Size(200, 20)
$lblUserAD.Text = "User AD Group"
$scrollAdd.Controls.Add($lblUserAD)

$txtUserAD = New-Object System.Windows.Forms.TextBox
$txtUserAD.Location = New-Object System.Drawing.Point(220, $yPos)
$txtUserAD.Size = New-Object System.Drawing.Size(580, 20)
$scrollAdd.Controls.Add($txtUserAD)
$yPos += 30

# Uninstall AD Group
$lblUninstallAD = New-Object System.Windows.Forms.Label
$lblUninstallAD.Location = New-Object System.Drawing.Point(10, $yPos)
$lblUninstallAD.Size = New-Object System.Drawing.Size(200, 20)
$lblUninstallAD.Text = "Uninstall AD Group"
$scrollAdd.Controls.Add($lblUninstallAD)

$txtUninstallAD = New-Object System.Windows.Forms.TextBox
$txtUninstallAD.Location = New-Object System.Drawing.Point(220, $yPos)
$txtUninstallAD.Size = New-Object System.Drawing.Size(580, 20)
$scrollAdd.Controls.Add($txtUninstallAD)
$yPos += 30

# SME AD Group
$lblSMEAD = New-Object System.Windows.Forms.Label
$lblSMEAD.Location = New-Object System.Drawing.Point(10, $yPos)
$lblSMEAD.Size = New-Object System.Drawing.Size(200, 20)
$lblSMEAD.Text = "SME AD Group"
$scrollAdd.Controls.Add($lblSMEAD)

$txtSMEAD = New-Object System.Windows.Forms.TextBox
$txtSMEAD.Location = New-Object System.Drawing.Point(220, $yPos)
$txtSMEAD.Size = New-Object System.Drawing.Size(580, 20)
$scrollAdd.Controls.Add($txtSMEAD)
$yPos += 30

# SAFR Boundary
$lblSAFR = New-Object System.Windows.Forms.Label
$lblSAFR.Location = New-Object System.Drawing.Point(10, $yPos)
$lblSAFR.Size = New-Object System.Drawing.Size(200, 20)
$lblSAFR.Text = "SAFR Boundary"
$scrollAdd.Controls.Add($lblSAFR)

$cmbSAFR = New-Object System.Windows.Forms.ComboBox
$cmbSAFR.Location = New-Object System.Drawing.Point(220, $yPos)
$cmbSAFR.Size = New-Object System.Drawing.Size(580, 20)
$cmbSAFR.DropDownStyle = "DropDownList"
$cmbSAFR.Items.AddRange(@("", "EaaS", "Product team", "District", "NA"))
$scrollAdd.Controls.Add($cmbSAFR)
$yPos += 30

# Update Frequency
$lblUpdateFreq = New-Object System.Windows.Forms.Label
$lblUpdateFreq.Location = New-Object System.Drawing.Point(10, $yPos)
$lblUpdateFreq.Size = New-Object System.Drawing.Size(200, 20)
$lblUpdateFreq.Text = "Update Frequency"
$scrollAdd.Controls.Add($lblUpdateFreq)

$cmbUpdateFreq = New-Object System.Windows.Forms.ComboBox
$cmbUpdateFreq.Location = New-Object System.Drawing.Point(220, $yPos)
$cmbUpdateFreq.Size = New-Object System.Drawing.Size(580, 20)
$cmbUpdateFreq.DropDownStyle = "DropDownList"
$cmbUpdateFreq.Items.AddRange(@("", "Quarterly", "Semi-Annually", "Annually", "No further updates", "Monthly", "Used strictly for licensing"))
$scrollAdd.Controls.Add($cmbUpdateFreq)
$yPos += 30

# BigFix
$lblBigFix = New-Object System.Windows.Forms.Label
$lblBigFix.Location = New-Object System.Drawing.Point(10, $yPos)
$lblBigFix.Size = New-Object System.Drawing.Size(200, 20)
$lblBigFix.Text = "BigFix?"
$scrollAdd.Controls.Add($lblBigFix)

$cmbBigFix = New-Object System.Windows.Forms.ComboBox
$cmbBigFix.Location = New-Object System.Drawing.Point(220, $yPos)
$cmbBigFix.Size = New-Object System.Drawing.Size(580, 20)
$cmbBigFix.DropDownStyle = "DropDownList"
$cmbBigFix.Items.AddRange(@("", "Yes", "No", "_"))
$scrollAdd.Controls.Add($cmbBigFix)
$yPos += 30

# Next Update Quarter
$lblNextQuarter = New-Object System.Windows.Forms.Label
$lblNextQuarter.Location = New-Object System.Drawing.Point(10, $yPos)
$lblNextQuarter.Size = New-Object System.Drawing.Size(200, 20)
$lblNextQuarter.Text = "Next Update Quarter"
$scrollAdd.Controls.Add($lblNextQuarter)

$txtNextQuarter = New-Object System.Windows.Forms.TextBox
$txtNextQuarter.Location = New-Object System.Drawing.Point(220, $yPos)
$txtNextQuarter.Size = New-Object System.Drawing.Size(580, 20)
$txtNextQuarter.PlaceholderText = "e.g., Q3 - 2026"
$scrollAdd.Controls.Add($txtNextQuarter)
$yPos += 30

# Next Renewal Date
$lblRenewalDate = New-Object System.Windows.Forms.Label
$lblRenewalDate.Location = New-Object System.Drawing.Point(10, $yPos)
$lblRenewalDate.Size = New-Object System.Drawing.Size(200, 20)
$lblRenewalDate.Text = "Next Renewal Date"
$scrollAdd.Controls.Add($lblRenewalDate)

$dtpRenewalDate = New-Object System.Windows.Forms.DateTimePicker
$dtpRenewalDate.Location = New-Object System.Drawing.Point(220, $yPos)
$dtpRenewalDate.Size = New-Object System.Drawing.Size(200, 20)
$dtpRenewalDate.Format = "Short"
$scrollAdd.Controls.Add($dtpRenewalDate)

$chkNoRenewalDate = New-Object System.Windows.Forms.CheckBox
$chkNoRenewalDate.Location = New-Object System.Drawing.Point(430, $yPos)
$chkNoRenewalDate.Size = New-Object System.Drawing.Size(150, 20)
$chkNoRenewalDate.Text = "No renewal date"
$chkNoRenewalDate.Checked = $true
$scrollAdd.Controls.Add($chkNoRenewalDate)
$yPos += 30

# Auto-Updates
$chkAutoUpdates = New-Object System.Windows.Forms.CheckBox
$chkAutoUpdates.Location = New-Object System.Drawing.Point(220, $yPos)
$chkAutoUpdates.Size = New-Object System.Drawing.Size(580, 20)
$chkAutoUpdates.Text = "Auto-Updates Enabled"
$scrollAdd.Controls.Add($chkAutoUpdates)
$yPos += 30

# License Type
$lblLicenseType = New-Object System.Windows.Forms.Label
$lblLicenseType.Location = New-Object System.Drawing.Point(10, $yPos)
$lblLicenseType.Size = New-Object System.Drawing.Size(200, 20)
$lblLicenseType.Text = "License Type (multi-select)"
$scrollAdd.Controls.Add($lblLicenseType)

$grpLicenseType = New-Object System.Windows.Forms.GroupBox
$grpLicenseType.Location = New-Object System.Drawing.Point(220, $yPos)
$grpLicenseType.Size = New-Object System.Drawing.Size(580, 60)
$scrollAdd.Controls.Add($grpLicenseType)

$chkLicenseNPO = New-Object System.Windows.Forms.CheckBox
$chkLicenseNPO.Location = New-Object System.Drawing.Point(10, 15)
$chkLicenseNPO.Size = New-Object System.Drawing.Size(130, 20)
$chkLicenseNPO.Text = "NPO"
$grpLicenseType.Controls.Add($chkLicenseNPO)

$chkLicenseDistrict = New-Object System.Windows.Forms.CheckBox
$chkLicenseDistrict.Location = New-Object System.Drawing.Point(150, 15)
$chkLicenseDistrict.Size = New-Object System.Drawing.Size(130, 20)
$chkLicenseDistrict.Text = "District"
$grpLicenseType.Controls.Add($chkLicenseDistrict)

$chkLicenseCAM = New-Object System.Windows.Forms.CheckBox
$chkLicenseCAM.Location = New-Object System.Drawing.Point(290, 15)
$chkLicenseCAM.Size = New-Object System.Drawing.Size(130, 20)
$chkLicenseCAM.Text = "CAM"
$grpLicenseType.Controls.Add($chkLicenseCAM)

$chkLicenseNA = New-Object System.Windows.Forms.CheckBox
$chkLicenseNA.Location = New-Object System.Drawing.Point(430, 15)
$chkLicenseNA.Size = New-Object System.Drawing.Size(130, 20)
$chkLicenseNA.Text = "N/A"
$grpLicenseType.Controls.Add($chkLicenseNA)

$yPos += 70

# Product Status
$lblProductStatus = New-Object System.Windows.Forms.Label
$lblProductStatus.Location = New-Object System.Drawing.Point(10, $yPos)
$lblProductStatus.Size = New-Object System.Drawing.Size(200, 20)
$lblProductStatus.Text = "Product Status (multi-select) *"
$scrollAdd.Controls.Add($lblProductStatus)

$grpProductStatus = New-Object System.Windows.Forms.GroupBox
$grpProductStatus.Location = New-Object System.Drawing.Point(220, $yPos)
$grpProductStatus.Size = New-Object System.Drawing.Size(580, 90)
$scrollAdd.Controls.Add($grpProductStatus)

$chkProdProduction = New-Object System.Windows.Forms.CheckBox
$chkProdProduction.Location = New-Object System.Drawing.Point(10, 15)
$chkProdProduction.Size = New-Object System.Drawing.Size(130, 20)
$chkProdProduction.Text = "Production"
$grpProductStatus.Controls.Add($chkProdProduction)

$chkProdCOE = New-Object System.Windows.Forms.CheckBox
$chkProdCOE.Location = New-Object System.Drawing.Point(150, 15)
$chkProdCOE.Size = New-Object System.Drawing.Size(130, 20)
$chkProdCOE.Text = "COE"
$grpProductStatus.Controls.Add($chkProdCOE)

$chkProdCatalog = New-Object System.Windows.Forms.CheckBox
$chkProdCatalog.Location = New-Object System.Drawing.Point(290, 15)
$chkProdCatalog.Size = New-Object System.Drawing.Size(130, 20)
$chkProdCatalog.Text = "Catalog Item"
$grpProductStatus.Controls.Add($chkProdCatalog)

$chkProdRemoved = New-Object System.Windows.Forms.CheckBox
$chkProdRemoved.Location = New-Object System.Drawing.Point(430, 15)
$chkProdRemoved.Size = New-Object System.Drawing.Size(130, 20)
$chkProdRemoved.Text = "Removed"
$grpProductStatus.Controls.Add($chkProdRemoved)

$chkProdLSS = New-Object System.Windows.Forms.CheckBox
$chkProdLSS.Location = New-Object System.Drawing.Point(10, 40)
$chkProdLSS.Size = New-Object System.Drawing.Size(130, 20)
$chkProdLSS.Text = "LSS"
$grpProductStatus.Controls.Add($chkProdLSS)

$chkProdNY = New-Object System.Windows.Forms.CheckBox
$chkProdNY.Location = New-Object System.Drawing.Point(150, 40)
$chkProdNY.Size = New-Object System.Drawing.Size(130, 20)
$chkProdNY.Text = "NY"
$grpProductStatus.Controls.Add($chkProdNY)

$chkProdStandard = New-Object System.Windows.Forms.CheckBox
$chkProdStandard.Location = New-Object System.Drawing.Point(290, 40)
$chkProdStandard.Size = New-Object System.Drawing.Size(130, 20)
$chkProdStandard.Text = "Standard"
$grpProductStatus.Controls.Add($chkProdStandard)

# ═══════════════════════════════════════════════════════════════
# TAB 2: UPDATE/SEARCH SOFTWARE
# ═══════════════════════════════════════════════════════════════

$tabUpdate = New-Object System.Windows.Forms.TabPage
$tabUpdate.Text = "🔄 Update/Search"
$tabControl.Controls.Add($tabUpdate)

# Search section
$grpSearch = New-Object System.Windows.Forms.GroupBox
$grpSearch.Location = New-Object System.Drawing.Point(10, 10)
$grpSearch.Size = New-Object System.Drawing.Size(840, 80)
$grpSearch.Text = "Search Software"
$tabUpdate.Controls.Add($grpSearch)

$lblSearch = New-Object System.Windows.Forms.Label
$lblSearch.Location = New-Object System.Drawing.Point(10, 25)
$lblSearch.Size = New-Object System.Drawing.Size(100, 20)
$lblSearch.Text = "Search:"
$grpSearch.Controls.Add($lblSearch)

$txtSearch = New-Object System.Windows.Forms.TextBox
$txtSearch.Location = New-Object System.Drawing.Point(120, 22)
$txtSearch.Size = New-Object System.Drawing.Size(400, 20)
$txtSearch.PlaceholderText = "Enter software name or vendor..."
$grpSearch.Controls.Add($txtSearch)

$btnSearch = New-Object System.Windows.Forms.Button
$btnSearch.Location = New-Object System.Drawing.Point(530, 20)
$btnSearch.Size = New-Object System.Drawing.Size(100, 25)
$btnSearch.Text = "Search"
$btnSearch.BackColor = [System.Drawing.Color]::LightBlue
$grpSearch.Controls.Add($btnSearch)

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Location = New-Object System.Drawing.Point(640, 20)
$btnRefresh.Size = New-Object System.Drawing.Size(100, 25)
$btnRefresh.Text = "Refresh All"
$btnRefresh.BackColor = [System.Drawing.Color]::LightGreen
$grpSearch.Controls.Add($btnRefresh)

# Results ListView
$listViewResults = New-Object System.Windows.Forms.ListView
$listViewResults.Location = New-Object System.Drawing.Point(10, 100)
$listViewResults.Size = New-Object System.Drawing.Size(840, 400)
$listViewResults.View = "Details"
$listViewResults.FullRowSelect = $true
$listViewResults.GridLines = $true
$listViewResults.MultiSelect = $false

# Add columns
$listViewResults.Columns.Add("ID", 50) | Out-Null
$listViewResults.Columns.Add("Ref", 50) | Out-Null
$listViewResults.Columns.Add("Title", 250) | Out-Null
$listViewResults.Columns.Add("Vendor", 150) | Out-Null
$listViewResults.Columns.Add("Version", 100) | Out-Null
$listViewResults.Columns.Add("Status", 150) | Out-Null

$tabUpdate.Controls.Add($listViewResults)

# Action buttons
$btnLoadToUpdate = New-Object System.Windows.Forms.Button
$btnLoadToUpdate.Location = New-Object System.Drawing.Point(10, 510)
$btnLoadToUpdate.Size = New-Object System.Drawing.Size(150, 30)
$btnLoadToUpdate.Text = "Load to Update Form"
$btnLoadToUpdate.BackColor = [System.Drawing.Color]::LightBlue
$btnLoadToUpdate.Enabled = $false
$tabUpdate.Controls.Add($btnLoadToUpdate)

$btnQuickEdit = New-Object System.Windows.Forms.Button
$btnQuickEdit.Location = New-Object System.Drawing.Point(170, 510)
$btnQuickEdit.Size = New-Object System.Drawing.Size(150, 30)
$btnQuickEdit.Text = "⚡ Quick Edit"
$btnQuickEdit.BackColor = [System.Drawing.Color]::LightGreen
$btnQuickEdit.Enabled = $false
$tabUpdate.Controls.Add($btnQuickEdit)

$btnOpenInBrowser = New-Object System.Windows.Forms.Button
$btnOpenInBrowser.Location = New-Object System.Drawing.Point(330, 510)
$btnOpenInBrowser.Size = New-Object System.Drawing.Size(150, 30)
$btnOpenInBrowser.Text = "Open in Browser"
$btnOpenInBrowser.Enabled = $false
$tabUpdate.Controls.Add($btnOpenInBrowser)

# Update form section
$grpUpdateForm = New-Object System.Windows.Forms.GroupBox
$grpUpdateForm.Location = New-Object System.Drawing.Point(10, 550)
$grpUpdateForm.Size = New-Object System.Drawing.Size(840, 90)
$grpUpdateForm.Text = "Quick Update (loaded item)"
$tabUpdate.Controls.Add($grpUpdateForm)

$lblUpdateInfo = New-Object System.Windows.Forms.Label
$lblUpdateInfo.Location = New-Object System.Drawing.Point(10, 20)
$lblUpdateInfo.Size = New-Object System.Drawing.Size(810, 20)
$lblUpdateInfo.Text = "No item loaded. Select an item above and click 'Load to Update Form'"
$lblUpdateInfo.ForeColor = [System.Drawing.Color]::Gray
$grpUpdateForm.Controls.Add($lblUpdateInfo)

$btnUpdateItem = New-Object System.Windows.Forms.Button
$btnUpdateItem.Location = New-Object System.Drawing.Point(10, 50)
$btnUpdateItem.Size = New-Object System.Drawing.Size(150, 30)
$btnUpdateItem.Text = "Update in SharePoint"
$btnUpdateItem.BackColor = [System.Drawing.Color]::LightGreen
$btnUpdateItem.Enabled = $false
$grpUpdateForm.Controls.Add($btnUpdateItem)

$lblUpdateHint = New-Object System.Windows.Forms.Label
$lblUpdateHint.Location = New-Object System.Drawing.Point(170, 50)
$lblUpdateHint.Size = New-Object System.Drawing.Size(650, 30)
$lblUpdateHint.Text = "Tip: Load an item here, switch to 'Add New' tab to modify fields, then come back and click Update"
$lblUpdateHint.ForeColor = [System.Drawing.Color]::DarkBlue
$grpUpdateForm.Controls.Add($lblUpdateHint)

# ═══════════════════════════════════════════════════════════════
# TAB 3: RECENT ADDITIONS
# ═══════════════════════════════════════════════════════════════

$tabRecent = New-Object System.Windows.Forms.TabPage
$tabRecent.Text = "📊 Recent Items"
$tabControl.Controls.Add($tabRecent)

$lblRecentInfo = New-Object System.Windows.Forms.Label
$lblRecentInfo.Location = New-Object System.Drawing.Point(10, 10)
$lblRecentInfo.Size = New-Object System.Drawing.Size(840, 20)
$lblRecentInfo.Text = "Most recent 50 items (sorted by ID descending)"
$tabRecent.Controls.Add($lblRecentInfo)

$listViewRecent = New-Object System.Windows.Forms.ListView
$listViewRecent.Location = New-Object System.Drawing.Point(10, 40)
$listViewRecent.Size = New-Object System.Drawing.Size(840, 550)
$listViewRecent.View = "Details"
$listViewRecent.FullRowSelect = $true
$listViewRecent.GridLines = $true
$listViewRecent.MultiSelect = $false

$listViewRecent.Columns.Add("ID", 50) | Out-Null
$listViewRecent.Columns.Add("Ref", 50) | Out-Null
$listViewRecent.Columns.Add("Title", 250) | Out-Null
$listViewRecent.Columns.Add("Vendor", 150) | Out-Null
$listViewRecent.Columns.Add("Version", 100) | Out-Null
$listViewRecent.Columns.Add("Created", 150) | Out-Null

$tabRecent.Controls.Add($listViewRecent)

$btnRefreshRecent = New-Object System.Windows.Forms.Button
$btnRefreshRecent.Location = New-Object System.Drawing.Point(10, 600)
$btnRefreshRecent.Size = New-Object System.Drawing.Size(150, 30)
$btnRefreshRecent.Text = "Refresh Recent"
$btnRefreshRecent.BackColor = [System.Drawing.Color]::LightGreen
$tabRecent.Controls.Add($btnRefreshRecent)

$btnLoadRecentToForm = New-Object System.Windows.Forms.Button
$btnLoadRecentToForm.Location = New-Object System.Drawing.Point(170, 600)
$btnLoadRecentToForm.Size = New-Object System.Drawing.Size(150, 30)
$btnLoadRecentToForm.Text = "Load to Form"
$btnLoadRecentToForm.BackColor = [System.Drawing.Color]::LightBlue
$btnLoadRecentToForm.Enabled = $false
$tabRecent.Controls.Add($btnLoadRecentToForm)

# ══════════════════════════════════════════════════════════════════════════════
# TOP SECTION - Connection Controls
# ══════════════════════════════════════════════════════════════════════════════

# Check if already connected via PreConnect
if ($script:isConnected) {
    $connStatusText = "Status: Connected to $SiteUrl (Pre-Connected)"
    $connStatusColor = [System.Drawing.Color]::Green
    $statusText = "✅ Already connected! Ready to use."
    $statusColor = [System.Drawing.Color]::LightGreen
    $connectEnabled = $false
    $disconnectEnabled = $true
    $addEnabled = $true
}
else {
    $connStatusText = "Status: Not connected to SharePoint"
    $connStatusColor = [System.Drawing.Color]::Red
    $statusText = "Click 'Connect' or restart with -PreConnect parameter"
    $statusColor = [System.Drawing.Color]::LightYellow
    $connectEnabled = $true
    $disconnectEnabled = $false
    $addEnabled = $false
}

$lblConnStatus = New-Object System.Windows.Forms.Label
$lblConnStatus.Location = New-Object System.Drawing.Point(20, 15)
$lblConnStatus.Size = New-Object System.Drawing.Size(600, 20)
$lblConnStatus.Text = $connStatusText
$lblConnStatus.ForeColor = $connStatusColor
$form.Controls.Add($lblConnStatus)

$btnConnect = New-Object System.Windows.Forms.Button
$btnConnect.Location = New-Object System.Drawing.Point(650, 10)
$btnConnect.Size = New-Object System.Drawing.Size(100, 30)
$btnConnect.Text = "Connect"
$btnConnect.BackColor = [System.Drawing.Color]::LightBlue
$btnConnect.Enabled = $connectEnabled
$form.Controls.Add($btnConnect)

$btnDisconnect = New-Object System.Windows.Forms.Button
$btnDisconnect.Location = New-Object System.Drawing.Point(760, 10)
$btnDisconnect.Size = New-Object System.Drawing.Size(100, 30)
$btnDisconnect.Text = "Disconnect"
$btnDisconnect.Enabled = $disconnectEnabled
$form.Controls.Add($btnDisconnect)

# ══════════════════════════════════════════════════════════════════════════════
# BOTTOM SECTION - Action Buttons & Status
# ══════════════════════════════════════════════════════════════════════════════

$btnAddSoftware = New-Object System.Windows.Forms.Button
$btnAddSoftware.Location = New-Object System.Drawing.Point(20, 740)
$btnAddSoftware.Size = New-Object System.Drawing.Size(120, 35)
$btnAddSoftware.Text = "➕ Add Software"
$btnAddSoftware.BackColor = [System.Drawing.Color]::LightGreen
$btnAddSoftware.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnAddSoftware.Enabled = $addEnabled
$form.Controls.Add($btnAddSoftware)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Location = New-Object System.Drawing.Point(760, 740)
$btnClose.Size = New-Object System.Drawing.Size(100, 35)
$btnClose.Text = "Close"
$form.Controls.Add($btnClose)

# Status Label
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(150, 745)
$lblStatus.Size = New-Object System.Drawing.Size(600, 30)
$lblStatus.Text = $statusText
$lblStatus.BorderStyle = "FixedSingle"
$lblStatus.BackColor = $statusColor
$lblStatus.TextAlign = "MiddleLeft"
$form.Controls.Add($lblStatus)

# Progress Bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20, 780)
$progressBar.Size = New-Object System.Drawing.Size(840, 20)
$progressBar.Style = "Marquee"
$progressBar.Visible = $false
$form.Controls.Add($progressBar)

# ══════════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS FOR GUI
# ══════════════════════════════════════════════════════════════════════════════

$script:currentItemId = $null

function Show-QuickEditDialog {
    param(
        [Parameter(Mandatory=$true)]
        $Item
    )
    
    $f = $Item.FieldValues
    
    # Create Quick Edit Dialog
    $editForm = New-Object System.Windows.Forms.Form
    $editForm.Text = "Quick Edit - $($f.Title)"
    $editForm.Size = New-Object System.Drawing.Size(600, 700)
    $editForm.StartPosition = "CenterParent"
    $editForm.FormBorderStyle = "FixedDialog"
    $editForm.MaximizeBox = $false
    $editForm.MinimizeBox = $false
    $editForm.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    
    $yPos = 20
    
    # Title
    $lblEditTitle = New-Object System.Windows.Forms.Label
    $lblEditTitle.Location = New-Object System.Drawing.Point(20, $yPos)
    $lblEditTitle.Size = New-Object System.Drawing.Size(100, 20)
    $lblEditTitle.Text = "Title:"
    $editForm.Controls.Add($lblEditTitle)
    
    $txtEditTitle = New-Object System.Windows.Forms.TextBox
    $txtEditTitle.Location = New-Object System.Drawing.Point(130, $yPos)
    $txtEditTitle.Size = New-Object System.Drawing.Size(430, 20)
    $txtEditTitle.Text = $f.Title
    $editForm.Controls.Add($txtEditTitle)
    $yPos += 30
    
    # Vendor
    $lblEditVendor = New-Object System.Windows.Forms.Label
    $lblEditVendor.Location = New-Object System.Drawing.Point(20, $yPos)
    $lblEditVendor.Size = New-Object System.Drawing.Size(100, 20)
    $lblEditVendor.Text = "Vendor:"
    $editForm.Controls.Add($lblEditVendor)
    
    $txtEditVendor = New-Object System.Windows.Forms.TextBox
    $txtEditVendor.Location = New-Object System.Drawing.Point(130, $yPos)
    $txtEditVendor.Size = New-Object System.Drawing.Size(430, 20)
    $txtEditVendor.Text = $f.Vendor
    $editForm.Controls.Add($txtEditVendor)
    $yPos += 30
    
    # Version
    $lblEditVersion = New-Object System.Windows.Forms.Label
    $lblEditVersion.Location = New-Object System.Drawing.Point(20, $yPos)
    $lblEditVersion.Size = New-Object System.Drawing.Size(100, 20)
    $lblEditVersion.Text = "Version:"
    $editForm.Controls.Add($lblEditVersion)
    
    $txtEditVersion = New-Object System.Windows.Forms.TextBox
    $txtEditVersion.Location = New-Object System.Drawing.Point(130, $yPos)
    $txtEditVersion.Size = New-Object System.Drawing.Size(430, 20)
    $txtEditVersion.Text = $f.Version_x0023__x0028_alt_x002e__
    $editForm.Controls.Add($txtEditVersion)
    $yPos += 30
    
    # User AD Group
    $lblEditUserAD = New-Object System.Windows.Forms.Label
    $lblEditUserAD.Location = New-Object System.Drawing.Point(20, $yPos)
    $lblEditUserAD.Size = New-Object System.Drawing.Size(100, 20)
    $lblEditUserAD.Text = "User AD Group:"
    $editForm.Controls.Add($lblEditUserAD)
    
    $txtEditUserAD = New-Object System.Windows.Forms.TextBox
    $txtEditUserAD.Location = New-Object System.Drawing.Point(130, $yPos)
    $txtEditUserAD.Size = New-Object System.Drawing.Size(430, 20)
    $txtEditUserAD.Text = $f.AD_Group_Name
    $editForm.Controls.Add($txtEditUserAD)
    $yPos += 30
    
    # SAFR Boundary
    $lblEditSAFR = New-Object System.Windows.Forms.Label
    $lblEditSAFR.Location = New-Object System.Drawing.Point(20, $yPos)
    $lblEditSAFR.Size = New-Object System.Drawing.Size(100, 20)
    $lblEditSAFR.Text = "SAFR Boundary:"
    $editForm.Controls.Add($lblEditSAFR)
    
    $cmbEditSAFR = New-Object System.Windows.Forms.ComboBox
    $cmbEditSAFR.Location = New-Object System.Drawing.Point(130, $yPos)
    $cmbEditSAFR.Size = New-Object System.Drawing.Size(430, 20)
    $cmbEditSAFR.DropDownStyle = "DropDownList"
    $cmbEditSAFR.Items.AddRange(@("", "EaaS", "Product team", "District", "NA"))
    $cmbEditSAFR.Text = $f.SAFRBoundary
    $editForm.Controls.Add($cmbEditSAFR)
    $yPos += 30
    
    # Update Frequency
    $lblEditUpdateFreq = New-Object System.Windows.Forms.Label
    $lblEditUpdateFreq.Location = New-Object System.Drawing.Point(20, $yPos)
    $lblEditUpdateFreq.Size = New-Object System.Drawing.Size(100, 20)
    $lblEditUpdateFreq.Text = "Update Freq:"
    $editForm.Controls.Add($lblEditUpdateFreq)
    
    $cmbEditUpdateFreq = New-Object System.Windows.Forms.ComboBox
    $cmbEditUpdateFreq.Location = New-Object System.Drawing.Point(130, $yPos)
    $cmbEditUpdateFreq.Size = New-Object System.Drawing.Size(430, 20)
    $cmbEditUpdateFreq.DropDownStyle = "DropDownList"
    $cmbEditUpdateFreq.Items.AddRange(@("", "Quarterly", "Semi-Annually", "Annually", "No further updates", "Monthly", "Used strictly for licensing"))
    $cmbEditUpdateFreq.Text = $f.UpdateFrequency
    $editForm.Controls.Add($cmbEditUpdateFreq)
    $yPos += 30
    
    # BigFix
    $lblEditBigFix = New-Object System.Windows.Forms.Label
    $lblEditBigFix.Location = New-Object System.Drawing.Point(20, $yPos)
    $lblEditBigFix.Size = New-Object System.Drawing.Size(100, 20)
    $lblEditBigFix.Text = "BigFix:"
    $editForm.Controls.Add($lblEditBigFix)
    
    $cmbEditBigFix = New-Object System.Windows.Forms.ComboBox
    $cmbEditBigFix.Location = New-Object System.Drawing.Point(130, $yPos)
    $cmbEditBigFix.Size = New-Object System.Drawing.Size(430, 20)
    $cmbEditBigFix.DropDownStyle = "DropDownList"
    $cmbEditBigFix.Items.AddRange(@("", "Yes", "No", "_"))
    $cmbEditBigFix.Text = $f.BigFix_x003f_
    $editForm.Controls.Add($cmbEditBigFix)
    $yPos += 30
    
    # Next Update Quarter
    $lblEditQuarter = New-Object System.Windows.Forms.Label
    $lblEditQuarter.Location = New-Object System.Drawing.Point(20, $yPos)
    $lblEditQuarter.Size = New-Object System.Drawing.Size(100, 20)
    $lblEditQuarter.Text = "Next Quarter:"
    $editForm.Controls.Add($lblEditQuarter)
    
    $txtEditQuarter = New-Object System.Windows.Forms.TextBox
    $txtEditQuarter.Location = New-Object System.Drawing.Point(130, $yPos)
    $txtEditQuarter.Size = New-Object System.Drawing.Size(430, 20)
    $txtEditQuarter.Text = $f.NextUpdateQuarter
    $editForm.Controls.Add($txtEditQuarter)
    $yPos += 30
    
    # Auto-Updates
    $chkEditAutoUpdates = New-Object System.Windows.Forms.CheckBox
    $chkEditAutoUpdates.Location = New-Object System.Drawing.Point(130, $yPos)
    $chkEditAutoUpdates.Size = New-Object System.Drawing.Size(430, 20)
    $chkEditAutoUpdates.Text = "Auto-Updates Enabled"
    $chkEditAutoUpdates.Checked = $f.Auto_x002d_Updates_x003f_
    $editForm.Controls.Add($chkEditAutoUpdates)
    $yPos += 30
    
    # Product Status
    $lblEditProdStatus = New-Object System.Windows.Forms.Label
    $lblEditProdStatus.Location = New-Object System.Drawing.Point(20, $yPos)
    $lblEditProdStatus.Size = New-Object System.Drawing.Size(100, 20)
    $lblEditProdStatus.Text = "Product Status:"
    $editForm.Controls.Add($lblEditProdStatus)
    
    $grpEditProdStatus = New-Object System.Windows.Forms.GroupBox
    $grpEditProdStatus.Location = New-Object System.Drawing.Point(130, $yPos)
    $grpEditProdStatus.Size = New-Object System.Drawing.Size(430, 90)
    $editForm.Controls.Add($grpEditProdStatus)
    
    $chkEditProdProduction = New-Object System.Windows.Forms.CheckBox
    $chkEditProdProduction.Location = New-Object System.Drawing.Point(10, 15)
    $chkEditProdProduction.Size = New-Object System.Drawing.Size(130, 20)
    $chkEditProdProduction.Text = "Production"
    $chkEditProdProduction.Checked = $f.CatalogStatus -contains "Production"
    $grpEditProdStatus.Controls.Add($chkEditProdProduction)
    
    $chkEditProdCOE = New-Object System.Windows.Forms.CheckBox
    $chkEditProdCOE.Location = New-Object System.Drawing.Point(150, 15)
    $chkEditProdCOE.Size = New-Object System.Drawing.Size(130, 20)
    $chkEditProdCOE.Text = "COE"
    $chkEditProdCOE.Checked = $f.CatalogStatus -contains "COE"
    $grpEditProdStatus.Controls.Add($chkEditProdCOE)
    
    $chkEditProdCatalog = New-Object System.Windows.Forms.CheckBox
    $chkEditProdCatalog.Location = New-Object System.Drawing.Point(290, 15)
    $chkEditProdCatalog.Size = New-Object System.Drawing.Size(130, 20)
    $chkEditProdCatalog.Text = "Catalog Item"
    $chkEditProdCatalog.Checked = $f.CatalogStatus -contains "Catalog Item"
    $grpEditProdStatus.Controls.Add($chkEditProdCatalog)
    
    $chkEditProdLSS = New-Object System.Windows.Forms.CheckBox
    $chkEditProdLSS.Location = New-Object System.Drawing.Point(10, 40)
    $chkEditProdLSS.Size = New-Object System.Drawing.Size(130, 20)
    $chkEditProdLSS.Text = "LSS"
    $chkEditProdLSS.Checked = $f.CatalogStatus -contains "LSS"
    $grpEditProdStatus.Controls.Add($chkEditProdLSS)
    
    $chkEditProdNY = New-Object System.Windows.Forms.CheckBox
    $chkEditProdNY.Location = New-Object System.Drawing.Point(150, 40)
    $chkEditProdNY.Size = New-Object System.Drawing.Size(130, 20)
    $chkEditProdNY.Text = "NY"
    $chkEditProdNY.Checked = $f.CatalogStatus -contains "NY"
    $grpEditProdStatus.Controls.Add($chkEditProdNY)
    
    $chkEditProdStandard = New-Object System.Windows.Forms.CheckBox
    $chkEditProdStandard.Location = New-Object System.Drawing.Point(290, 40)
    $chkEditProdStandard.Size = New-Object System.Drawing.Size(130, 20)
    $chkEditProdStandard.Text = "Standard"
    $chkEditProdStandard.Checked = $f.CatalogStatus -contains "Standard"
    $grpEditProdStatus.Controls.Add($chkEditProdStandard)
    
    $chkEditProdRemoved = New-Object System.Windows.Forms.CheckBox
    $chkEditProdRemoved.Location = New-Object System.Drawing.Point(10, 65)
    $chkEditProdRemoved.Size = New-Object System.Drawing.Size(130, 20)
    $chkEditProdRemoved.Text = "Removed"
    $chkEditProdRemoved.Checked = $f.CatalogStatus -contains "Removed"
    $grpEditProdStatus.Controls.Add($chkEditProdRemoved)
    
    $yPos += 100
    
    # Buttons
    $btnSaveEdit = New-Object System.Windows.Forms.Button
    $btnSaveEdit.Location = New-Object System.Drawing.Point(350, $yPos)
    $btnSaveEdit.Size = New-Object System.Drawing.Size(100, 35)
    $btnSaveEdit.Text = "💾 Save"
    $btnSaveEdit.BackColor = [System.Drawing.Color]::LightGreen
    $btnSaveEdit.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btnSaveEdit.DialogResult = "OK"
    $editForm.Controls.Add($btnSaveEdit)
    
    $btnCancelEdit = New-Object System.Windows.Forms.Button
    $btnCancelEdit.Location = New-Object System.Drawing.Point(460, $yPos)
    $btnCancelEdit.Size = New-Object System.Drawing.Size(100, 35)
    $btnCancelEdit.Text = "Cancel"
    $btnCancelEdit.DialogResult = "Cancel"
    $editForm.Controls.Add($btnCancelEdit)
    
    $editForm.AcceptButton = $btnSaveEdit
    $editForm.CancelButton = $btnCancelEdit
    
    # Show dialog
    $result = $editForm.ShowDialog()
    
    if ($result -eq "OK") {
        # Build update values
        $values = @{
            "Title" = $txtEditTitle.Text
            "Vendor" = $txtEditVendor.Text
        }
        
        if (-not [string]::IsNullOrWhiteSpace($txtEditVersion.Text)) {
            $values["Version_x0023__x0028_alt_x002e__"] = $txtEditVersion.Text
        }
        if (-not [string]::IsNullOrWhiteSpace($txtEditUserAD.Text)) {
            $values["AD_Group_Name"] = $txtEditUserAD.Text
        }
        if (-not [string]::IsNullOrWhiteSpace($cmbEditSAFR.Text)) {
            $values["SAFRBoundary"] = $cmbEditSAFR.Text
        }
        if (-not [string]::IsNullOrWhiteSpace($cmbEditUpdateFreq.Text)) {
            $values["UpdateFrequency"] = $cmbEditUpdateFreq.Text
        }
        if (-not [string]::IsNullOrWhiteSpace($cmbEditBigFix.Text)) {
            $values["BigFix_x003f_"] = $cmbEditBigFix.Text
        }
        if (-not [string]::IsNullOrWhiteSpace($txtEditQuarter.Text)) {
            $values["NextUpdateQuarter"] = $txtEditQuarter.Text
        }
        
        $values["Auto_x002d_Updates_x003f_"] = $chkEditAutoUpdates.Checked
        
        # Product Status
        $productStatus = @()
        if ($chkEditProdProduction.Checked) { $productStatus += "Production" }
        if ($chkEditProdCOE.Checked) { $productStatus += "COE" }
        if ($chkEditProdCatalog.Checked) { $productStatus += "Catalog Item" }
        if ($chkEditProdLSS.Checked) { $productStatus += "LSS" }
        if ($chkEditProdNY.Checked) { $productStatus += "NY" }
        if ($chkEditProdStandard.Checked) { $productStatus += "Standard" }
        if ($chkEditProdRemoved.Checked) { $productStatus += "Removed" }
        
        if ($productStatus.Count -gt 0) {
            $values["CatalogStatus"] = $productStatus
        }
        
        return $values
    }
    
    $editForm.Dispose()
    return $null
}

function Clear-AddForm {
    $txtTitle.Clear()
    $txtVendor.Clear()
    $txtVersion.Clear()
    $txtUserAD.Clear()
    $txtUninstallAD.Clear()
    $txtSMEAD.Clear()
    $cmbSAFR.SelectedIndex = -1
    $cmbUpdateFreq.SelectedIndex = -1
    $cmbBigFix.SelectedIndex = -1
    $txtNextQuarter.Clear()
    $chkNoRenewalDate.Checked = $true
    $chkAutoUpdates.Checked = $false
    $chkLicenseNPO.Checked = $false
    $chkLicenseDistrict.Checked = $false
    $chkLicenseCAM.Checked = $false
    $chkLicenseNA.Checked = $false
    $chkProdProduction.Checked = $false
    $chkProdCOE.Checked = $false
    $chkProdCatalog.Checked = $false
    $chkProdRemoved.Checked = $false
    $chkProdLSS.Checked = $false
    $chkProdNY.Checked = $false
    $chkProdStandard.Checked = $false
}

function Get-FormData {
    return @{
        Title = $txtTitle.Text
        Vendor = $txtVendor.Text
        Version = $txtVersion.Text
        UserAD = $txtUserAD.Text
        UninstallAD = $txtUninstallAD.Text
        SMEAD = $txtSMEAD.Text
        SAFR = $cmbSAFR.Text
        UpdateFreq = $cmbUpdateFreq.Text
        BigFix = $cmbBigFix.Text
        NextQuarter = $txtNextQuarter.Text
        NoRenewalDate = $chkNoRenewalDate.Checked
        RenewalDate = $dtpRenewalDate.Value
        AutoUpdates = $chkAutoUpdates.Checked
        LicenseNPO = $chkLicenseNPO.Checked
        LicenseDistrict = $chkLicenseDistrict.Checked
        LicenseCAM = $chkLicenseCAM.Checked
        LicenseNA = $chkLicenseNA.Checked
        ProdProduction = $chkProdProduction.Checked
        ProdCOE = $chkProdCOE.Checked
        ProdCatalog = $chkProdCatalog.Checked
        ProdRemoved = $chkProdRemoved.Checked
        ProdLSS = $chkProdLSS.Checked
        ProdNY = $chkProdNY.Checked
        ProdStandard = $chkProdStandard.Checked
    }
}

function Set-FormData {
    param([hashtable]$Data)
    
    $txtTitle.Text = $Data.Title
    $txtVendor.Text = $Data.Vendor
    $txtVersion.Text = $Data.Version
    $txtUserAD.Text = $Data.UserAD
    $txtUninstallAD.Text = $Data.UninstallAD
    $txtSMEAD.Text = $Data.SMEAD
    $cmbSAFR.Text = $Data.SAFR
    $cmbUpdateFreq.Text = $Data.UpdateFreq
    $cmbBigFix.Text = $Data.BigFix
    $txtNextQuarter.Text = $Data.NextQuarter
    $chkNoRenewalDate.Checked = $Data.NoRenewalDate
    if ($Data.RenewalDate) { $dtpRenewalDate.Value = $Data.RenewalDate }
    $chkAutoUpdates.Checked = $Data.AutoUpdates
    $chkLicenseNPO.Checked = $Data.LicenseNPO
    $chkLicenseDistrict.Checked = $Data.LicenseDistrict
    $chkLicenseCAM.Checked = $Data.LicenseCAM
    $chkLicenseNA.Checked = $Data.LicenseNA
    $chkProdProduction.Checked = $Data.ProdProduction
    $chkProdCOE.Checked = $Data.ProdCOE
    $chkProdCatalog.Checked = $Data.ProdCatalog
    $chkProdRemoved.Checked = $Data.ProdRemoved
    $chkProdLSS.Checked = $Data.ProdLSS
    $chkProdNY.Checked = $Data.ProdNY
    $chkProdStandard.Checked = $Data.ProdStandard
}

function Load-ItemToForm {
    param($Item)
    
    $f = $Item.FieldValues
    
    $txtTitle.Text = $f.Title
    $txtVendor.Text = $f.Vendor
    $txtVersion.Text = $f.Version_x0023__x0028_alt_x002e__
    $txtUserAD.Text = $f.AD_Group_Name
    $txtUninstallAD.Text = $f.UninstallADgroup
    $txtSMEAD.Text = $f.SMEADgroup
    $cmbSAFR.Text = $f.SAFRBoundary
    $cmbUpdateFreq.Text = $f.UpdateFrequency
    $cmbBigFix.Text = $f.BigFix_x003f_
    $txtNextQuarter.Text = $f.NextUpdateQuarter
    
    if ($f.NextRenewalDate) {
        $dtpRenewalDate.Value = [datetime]$f.NextRenewalDate
        $chkNoRenewalDate.Checked = $false
    } else {
        $chkNoRenewalDate.Checked = $true
    }
    
    $chkAutoUpdates.Checked = $f.Auto_x002d_Updates_x003f_
    
    # License Type
    $licenseType = $f.LicenseType
    $chkLicenseNPO.Checked = $licenseType -contains "NPO"
    $chkLicenseDistrict.Checked = $licenseType -contains "District"
    $chkLicenseCAM.Checked = $licenseType -contains "CAM"
    $chkLicenseNA.Checked = $licenseType -contains "N/A"
    
    # Product Status
    $prodStatus = $f.CatalogStatus
    $chkProdProduction.Checked = $prodStatus -contains "Production"
    $chkProdCOE.Checked = $prodStatus -contains "COE"
    $chkProdCatalog.Checked = $prodStatus -contains "Catalog Item"
    $chkProdRemoved.Checked = $prodStatus -contains "Removed"
    $chkProdLSS.Checked = $prodStatus -contains "LSS"
    $chkProdNY.Checked = $prodStatus -contains "NY"
    $chkProdStandard.Checked = $prodStatus -contains "Standard"
}

function Build-ValuesHash {
    $values = @{
        "Title" = $txtTitle.Text
        "Vendor" = $txtVendor.Text
    }
    
    if (-not [string]::IsNullOrWhiteSpace($txtVersion.Text)) {
        $values["Version_x0023__x0028_alt_x002e__"] = $txtVersion.Text
    }
    if (-not [string]::IsNullOrWhiteSpace($txtUserAD.Text)) {
        $values["AD_Group_Name"] = $txtUserAD.Text
    }
    if (-not [string]::IsNullOrWhiteSpace($txtUninstallAD.Text)) {
        $values["UninstallADgroup"] = $txtUninstallAD.Text
    }
    if (-not [string]::IsNullOrWhiteSpace($txtSMEAD.Text)) {
        $values["SMEADgroup"] = $txtSMEAD.Text
    }
    if (-not [string]::IsNullOrWhiteSpace($cmbSAFR.Text)) {
        $values["SAFRBoundary"] = $cmbSAFR.Text
    }
    if (-not [string]::IsNullOrWhiteSpace($cmbUpdateFreq.Text)) {
        $values["UpdateFrequency"] = $cmbUpdateFreq.Text
    }
    if (-not [string]::IsNullOrWhiteSpace($cmbBigFix.Text)) {
        $values["BigFix_x003f_"] = $cmbBigFix.Text
    }
    if (-not [string]::IsNullOrWhiteSpace($txtNextQuarter.Text)) {
        $values["NextUpdateQuarter"] = $txtNextQuarter.Text
    }
    
    # License Type
    $licenseType = @()
    if ($chkLicenseNPO.Checked) { $licenseType += "NPO" }
    if ($chkLicenseDistrict.Checked) { $licenseType += "District" }
    if ($chkLicenseCAM.Checked) { $licenseType += "CAM" }
    if ($chkLicenseNA.Checked) { $licenseType += "N/A" }
    if ($licenseType.Count -gt 0) {
        $values["LicenseType"] = $licenseType
    }
    
    # Product Status
    $productStatus = @()
    if ($chkProdProduction.Checked) { $productStatus += "Production" }
    if ($chkProdCOE.Checked) { $productStatus += "COE" }
    if ($chkProdCatalog.Checked) { $productStatus += "Catalog Item" }
    if ($chkProdRemoved.Checked) { $productStatus += "Removed" }
    if ($chkProdLSS.Checked) { $productStatus += "LSS" }
    if ($chkProdNY.Checked) { $productStatus += "NY" }
    if ($chkProdStandard.Checked) { $productStatus += "Standard" }
    if ($productStatus.Count -gt 0) {
        $values["CatalogStatus"] = $productStatus
    }
    
    $values["Auto_x002d_Updates_x003f_"] = $chkAutoUpdates.Checked
    
    if (-not $chkNoRenewalDate.Checked) {
        $values["NextRenewalDate"] = $dtpRenewalDate.Value
    }
    
    return $values
}

# ══════════════════════════════════════════════════════════════════════════════
# EVENT HANDLERS
# ══════════════════════════════════════════════════════════════════════════════

# Connect Button
$btnConnect.add_Click({
    $lblStatus.Text = "Connecting to SharePoint... (browser window will open)"
    $lblStatus.BackColor = [System.Drawing.Color]::LightYellow
    $lblConnStatus.Text = "Status: Connecting..."
    $lblConnStatus.ForeColor = [System.Drawing.Color]::Orange
    $progressBar.Visible = $true
    
    # Disable button to prevent double-click
    $btnConnect.Enabled = $false
    
    # Force UI updates during connection
    $form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
    
    # Give UI a moment to update
    Start-Sleep -Milliseconds 100
    [System.Windows.Forms.Application]::DoEvents()
    
    # Connect (this will open browser and wait)
    Write-Host "Opening browser for authentication..." -ForegroundColor Cyan
    $connected = $false
    
    try {
        # Keep UI responsive during connection
        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 100
        $timer.add_Tick({
            [System.Windows.Forms.Application]::DoEvents()
        })
        $timer.Start()
        
        $connected = Connect-SharePointSite -Url $SiteUrl
        
        $timer.Stop()
        $timer.Dispose()
    }
    catch {
        Write-Host "Connection error: $($_.Exception.Message)" -ForegroundColor Red
        $connected = $false
    }
    
    $progressBar.Visible = $false
    
    if ($connected) {
        $lblStatus.Text = "✅ Connected to SharePoint successfully!"
        $lblStatus.BackColor = [System.Drawing.Color]::LightGreen
        $lblConnStatus.Text = "Status: Connected to $SiteUrl"
        $lblConnStatus.ForeColor = [System.Drawing.Color]::Green
        $btnAddSoftware.Enabled = $true
        $btnDisconnect.Enabled = $true
        $script:isConnected = $true
    }
    else {
        $lblStatus.Text = "❌ Connection failed. Check console for details."
        $lblStatus.BackColor = [System.Drawing.Color]::LightCoral
        $lblConnStatus.Text = "Status: Connection failed"
        $lblConnStatus.ForeColor = [System.Drawing.Color]::Red
        $btnConnect.Enabled = $true
    }
})

# Disconnect Button
$btnDisconnect.add_Click({
    Disconnect-PnPOnline -ErrorAction SilentlyContinue
    $lblStatus.Text = "Disconnected from SharePoint"
    $lblStatus.BackColor = [System.Drawing.Color]::LightGray
    $lblConnStatus.Text = "Status: Not connected"
    $lblConnStatus.ForeColor = [System.Drawing.Color]::Red
    $btnAddSoftware.Enabled = $false
    $btnConnect.Enabled = $true
    $btnDisconnect.Enabled = $false
    $script:isConnected = $false
    $script:currentItemId = $null
    $btnUpdateItem.Enabled = $false
    $lblUpdateInfo.Text = "Disconnected. Reconnect to continue."
})

# Clear Form Button
$btnClearForm.add_Click({
    Clear-AddForm
    $lblStatus.Text = "Form cleared"
    $lblStatus.BackColor = [System.Drawing.Color]::LightYellow
})

# Save Template Button
$btnSaveTemplate.add_Click({
    $formData = Get-FormData
    $saved = Save-FormConfig -FormData $formData -Path $ConfigPath
    
    if ($saved) {
        $lblStatus.Text = "✅ Template saved to: $ConfigPath"
        $lblStatus.BackColor = [System.Drawing.Color]::LightGreen
        [System.Windows.Forms.MessageBox]::Show("Template saved successfully!", "Success", "OK", "Information")
    }
    else {
        $lblStatus.Text = "❌ Failed to save template"
        $lblStatus.BackColor = [System.Drawing.Color]::LightCoral
    }
})

# Load Template Button
$btnLoadTemplate.add_Click({
    $config = Load-FormConfig -Path $ConfigPath
    
    if ($null -ne $config) {
        Set-FormData -Data $config
        $lblStatus.Text = "✅ Template loaded from: $ConfigPath"
        $lblStatus.BackColor = [System.Drawing.Color]::LightGreen
    }
    else {
        $lblStatus.Text = "❌ No template found or failed to load"
        $lblStatus.BackColor = [System.Drawing.Color]::LightCoral
        [System.Windows.Forms.MessageBox]::Show("No template file found at:`n$ConfigPath`n`nCreate one by filling the form and clicking 'Save as Template'", "No Template", "OK", "Information")
    }
})

# Load Last Entry Button
$btnLoadLast.add_Click({
    if (-not $script:isConnected) {
        [System.Windows.Forms.MessageBox]::Show("Please connect to SharePoint first!", "Not Connected", "OK", "Warning")
        return
    }
    
    $lblStatus.Text = "Loading last entry..."
    $lblStatus.BackColor = [System.Drawing.Color]::LightYellow
    $progressBar.Visible = $true
    $form.Refresh()
    
    try {
        $items = Get-PnPListItem -List $ListTitle -PageSize 1
        $lastItem = $items | Sort-Object -Property { $_.FieldValues.ID } -Descending | Select-Object -First 1
        
        if ($lastItem) {
            Load-ItemToForm -Item $lastItem
            $lblStatus.Text = "✅ Loaded last entry: $($lastItem.FieldValues.Title)"
            $lblStatus.BackColor = [System.Drawing.Color]::LightGreen
        }
        else {
            $lblStatus.Text = "No items found in list"
            $lblStatus.BackColor = [System.Drawing.Color]::LightYellow
        }
    }
    catch {
        $lblStatus.Text = "❌ Failed to load last entry"
        $lblStatus.BackColor = [System.Drawing.Color]::LightCoral
    }
    
    $progressBar.Visible = $false
})

# Add Software Button
$btnAddSoftware.add_Click({
    # Validate
    if ([string]::IsNullOrWhiteSpace($txtTitle.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Title is required!", "Validation Error", "OK", "Warning")
        return
    }
    
    if ([string]::IsNullOrWhiteSpace($txtVendor.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Vendor is required!", "Validation Error", "OK", "Warning")
        return
    }
    
    $productStatus = @()
    if ($chkProdProduction.Checked) { $productStatus += "Production" }
    if ($chkProdCOE.Checked) { $productStatus += "COE" }
    if ($chkProdCatalog.Checked) { $productStatus += "Catalog Item" }
    if ($chkProdRemoved.Checked) { $productStatus += "Removed" }
    if ($chkProdLSS.Checked) { $productStatus += "LSS" }
    if ($chkProdNY.Checked) { $productStatus += "NY" }
    if ($chkProdStandard.Checked) { $productStatus += "Standard" }
    
    if ($productStatus.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("At least one Product Status is required!", "Validation Error", "OK", "Warning")
        return
    }
    
    $lblStatus.Text = "Creating item in SharePoint..."
    $lblStatus.BackColor = [System.Drawing.Color]::LightYellow
    $progressBar.Visible = $true
    $form.Refresh()
    
    $nextRef = Get-NextRefNumber -ListName $ListTitle
    $values = Build-ValuesHash
    $values["Ref"] = $nextRef
    
    $item = Add-SoftwareItem -ListName $ListTitle -Values $values
    
    $progressBar.Visible = $false
    
    if ($null -ne $item) {
        $lblStatus.Text = "✅ Software added successfully! ID: $($item.Id) | Ref: $nextRef"
        $lblStatus.BackColor = [System.Drawing.Color]::LightGreen
        
        $result = [System.Windows.Forms.MessageBox]::Show(
            "Software added successfully!`n`nID: $($item.Id)`nRef: $nextRef`n`nClear form to add another?",
            "Success",
            "YesNo",
            "Information"
        )
        
        if ($result -eq "Yes") {
            Clear-AddForm
        }
    }
    else {
        $lblStatus.Text = "❌ Failed to add software. Check console for details."
        $lblStatus.BackColor = [System.Drawing.Color]::LightCoral
    }
})

# Search Button
$btnSearch.add_Click({
    if (-not $script:isConnected) {
        [System.Windows.Forms.MessageBox]::Show("Please connect to SharePoint first!", "Not Connected", "OK", "Warning")
        return
    }
    
    if ([string]::IsNullOrWhiteSpace($txtSearch.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Enter a search term!", "Search", "OK", "Information")
        return
    }
    
    $lblStatus.Text = "Searching..."
    $lblStatus.BackColor = [System.Drawing.Color]::LightYellow
    $progressBar.Visible = $true
    $form.Refresh()
    
    $results = Search-SoftwareItems -ListName $ListTitle -SearchTerm $txtSearch.Text
    
    $listViewResults.Items.Clear()
    
    foreach ($item in $results) {
        $f = $item.FieldValues
        $listItem = New-Object System.Windows.Forms.ListViewItem($f.ID.ToString())
        $listItem.SubItems.Add($(if ($f.Ref) { $f.Ref.ToString() } else { "" })) | Out-Null
        $listItem.SubItems.Add($(if ($f.Title) { $f.Title } else { "" })) | Out-Null
        $listItem.SubItems.Add($(if ($f.Vendor) { $f.Vendor } else { "" })) | Out-Null
        $listItem.SubItems.Add($(if ($f.Version_x0023__x0028_alt_x002e__) { $f.Version_x0023__x0028_alt_x002e__ } else { "" })) | Out-Null
        $listItem.SubItems.Add($(if ($f.CatalogStatus) { ($f.CatalogStatus -join ", ") } else { "" })) | Out-Null
        $listItem.Tag = $item
        $listViewResults.Items.Add($listItem) | Out-Null
    }
    
    $progressBar.Visible = $false
    $lblStatus.Text = "✅ Found $($results.Count) item(s)"
    $lblStatus.BackColor = [System.Drawing.Color]::LightGreen
})

# Refresh All Button
$btnRefresh.add_Click({
    if (-not $script:isConnected) {
        [System.Windows.Forms.MessageBox]::Show("Please connect to SharePoint first!", "Not Connected", "OK", "Warning")
        return
    }
    
    $lblStatus.Text = "Loading all items..."
    $lblStatus.BackColor = [System.Drawing.Color]::LightYellow
    $progressBar.Visible = $true
    $form.Refresh()
    
    $items = Get-SoftwareItems -ListName $ListTitle -Limit 100
    
    $listViewResults.Items.Clear()
    
    foreach ($item in $items) {
        $f = $item.FieldValues
        $listItem = New-Object System.Windows.Forms.ListViewItem($f.ID.ToString())
        $listItem.SubItems.Add($(if ($f.Ref) { $f.Ref.ToString() } else { "" })) | Out-Null
        $listItem.SubItems.Add($(if ($f.Title) { $f.Title } else { "" })) | Out-Null
        $listItem.SubItems.Add($(if ($f.Vendor) { $f.Vendor } else { "" })) | Out-Null
        $listItem.SubItems.Add($(if ($f.Version_x0023__x0028_alt_x002e__) { $f.Version_x0023__x0028_alt_x002e__ } else { "" })) | Out-Null
        $listItem.SubItems.Add($(if ($f.CatalogStatus) { ($f.CatalogStatus -join ", ") } else { "" })) | Out-Null
        $listItem.Tag = $item
        $listViewResults.Items.Add($listItem) | Out-Null
    }
    
    $progressBar.Visible = $false
    $lblStatus.Text = "✅ Loaded $($items.Count) item(s)"
    $lblStatus.BackColor = [System.Drawing.Color]::LightGreen
})

# ListView Selection Changed
$listViewResults.add_SelectedIndexChanged({
    if ($listViewResults.SelectedItems.Count -gt 0) {
        $btnLoadToUpdate.Enabled = $true
        $btnQuickEdit.Enabled = $true
        $btnOpenInBrowser.Enabled = $true
    }
    else {
        $btnLoadToUpdate.Enabled = $false
        $btnQuickEdit.Enabled = $false
        $btnOpenInBrowser.Enabled = $false
    }
})

# ListView Double-Click = Quick Edit
$listViewResults.add_DoubleClick({
    if ($listViewResults.SelectedItems.Count -gt 0) {
        $btnQuickEdit.PerformClick()
    }
})

# Load to Update Button
$btnLoadToUpdate.add_Click({
    if ($listViewResults.SelectedItems.Count -eq 0) { return }
    
    $selectedItem = $listViewResults.SelectedItems[0].Tag
    $script:currentItemId = $selectedItem.Id
    
    Load-ItemToForm -Item $selectedItem
    
    $lblUpdateInfo.Text = "Loaded: $($selectedItem.FieldValues.Title) (ID: $($selectedItem.Id))"
    $lblUpdateInfo.ForeColor = [System.Drawing.Color]::Blue
    $btnUpdateItem.Enabled = $true
    
    $lblStatus.Text = "✅ Item loaded for update. Switch to 'Add New' tab to modify fields."
    $lblStatus.BackColor = [System.Drawing.Color]::LightGreen
    
    $tabControl.SelectedTab = $tabAdd
})

# Quick Edit Button
$btnQuickEdit.add_Click({
    if ($listViewResults.SelectedItems.Count -eq 0) { return }
    
    $selectedItem = $listViewResults.SelectedItems[0].Tag
    
    # Show quick edit dialog
    $values = Show-QuickEditDialog -Item $selectedItem
    
    if ($null -ne $values) {
        # User clicked Save, update the item
        $lblStatus.Text = "Updating item in SharePoint..."
        $lblStatus.BackColor = [System.Drawing.Color]::LightYellow
        $progressBar.Visible = $true
        $form.Refresh()
        
        $success = Update-SoftwareItem -ListName $ListTitle -ItemId $selectedItem.Id -Values $values
        
        $progressBar.Visible = $false
        
        if ($success) {
            $lblStatus.Text = "✅ Item updated successfully!"
            $lblStatus.BackColor = [System.Drawing.Color]::LightGreen
            [System.Windows.Forms.MessageBox]::Show("Item updated successfully!", "Success", "OK", "Information")
            
            # Refresh the list to show updated data
            $btnRefresh.PerformClick()
        }
        else {
            $lblStatus.Text = "❌ Failed to update item"
            $lblStatus.BackColor = [System.Drawing.Color]::LightCoral
        }
    }
})

# Open in Browser Button
$btnOpenInBrowser.add_Click({
    if ($listViewResults.SelectedItems.Count -eq 0) { return }
    
    $selectedItem = $listViewResults.SelectedItems[0].Tag
    $web = Get-PnPWeb
    $list = Get-PnPList -Identity $ListTitle
    $itemUrl = "$($web.Url)/lists/$($list.RootFolder.Name)/AllItems.aspx?ID=$($selectedItem.Id)"
    
    Start-Process $itemUrl
    $lblStatus.Text = "Opened in browser"
    $lblStatus.BackColor = [System.Drawing.Color]::LightBlue
})

# Update Item Button
$btnUpdateItem.add_Click({
    if ($null -eq $script:currentItemId) {
        [System.Windows.Forms.MessageBox]::Show("No item loaded for update!", "Error", "OK", "Warning")
        return
    }
    
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Update item ID $($script:currentItemId) with current form values?",
        "Confirm Update",
        "YesNo",
        "Question"
    )
    
    if ($result -eq "No") { return }
    
    $lblStatus.Text = "Updating item in SharePoint..."
    $lblStatus.BackColor = [System.Drawing.Color]::LightYellow
    $progressBar.Visible = $true
    $form.Refresh()
    
    $values = Build-ValuesHash
    $success = Update-SoftwareItem -ListName $ListTitle -ItemId $script:currentItemId -Values $values
    
    $progressBar.Visible = $false
    
    if ($success) {
        $lblStatus.Text = "✅ Item ID $($script:currentItemId) updated successfully!"
        $lblStatus.BackColor = [System.Drawing.Color]::LightGreen
        [System.Windows.Forms.MessageBox]::Show("Item updated successfully!", "Success", "OK", "Information")
        
        $script:currentItemId = $null
        $btnUpdateItem.Enabled = $false
        $lblUpdateInfo.Text = "Update complete. Load another item to update."
        $lblUpdateInfo.ForeColor = [System.Drawing.Color]::Gray
    }
    else {
        $lblStatus.Text = "❌ Failed to update item"
        $lblStatus.BackColor = [System.Drawing.Color]::LightCoral
    }
})

# Refresh Recent Button
$btnRefreshRecent.add_Click({
    if (-not $script:isConnected) {
        [System.Windows.Forms.MessageBox]::Show("Please connect to SharePoint first!", "Not Connected", "OK", "Warning")
        return
    }
    
    $lblStatus.Text = "Loading recent items..."
    $lblStatus.BackColor = [System.Drawing.Color]::LightYellow
    $progressBar.Visible = $true
    $form.Refresh()
    
    $items = Get-SoftwareItems -ListName $ListTitle -Limit 50
    $sorted = $items | Sort-Object -Property { $_.FieldValues.ID } -Descending | Select-Object -First 50
    
    $listViewRecent.Items.Clear()
    
    foreach ($item in $sorted) {
        $f = $item.FieldValues
        $listItem = New-Object System.Windows.Forms.ListViewItem($f.ID.ToString())
        $listItem.SubItems.Add($(if ($f.Ref) { $f.Ref.ToString() } else { "" })) | Out-Null
        $listItem.SubItems.Add($(if ($f.Title) { $f.Title } else { "" })) | Out-Null
        $listItem.SubItems.Add($(if ($f.Vendor) { $f.Vendor } else { "" })) | Out-Null
        $listItem.SubItems.Add($(if ($f.Version_x0023__x0028_alt_x002e__) { $f.Version_x0023__x0028_alt_x002e__ } else { "" })) | Out-Null
        $listItem.SubItems.Add($(if ($f.Created) { $f.Created.ToString("yyyy-MM-dd HH:mm") } else { "" })) | Out-Null
        $listItem.Tag = $item
        $listViewRecent.Items.Add($listItem) | Out-Null
    }
    
    $progressBar.Visible = $false
    $lblStatus.Text = "✅ Loaded $($sorted.Count) recent item(s)"
    $lblStatus.BackColor = [System.Drawing.Color]::LightGreen
})

# Recent ListView Selection Changed
$listViewRecent.add_SelectedIndexChanged({
    if ($listViewRecent.SelectedItems.Count -gt 0) {
        $btnLoadRecentToForm.Enabled = $true
    }
    else {
        $btnLoadRecentToForm.Enabled = $false
    }
})

# Load Recent to Form Button
$btnLoadRecentToForm.add_Click({
    if ($listViewRecent.SelectedItems.Count -eq 0) { return }
    
    $selectedItem = $listViewRecent.SelectedItems[0].Tag
    Load-ItemToForm -Item $selectedItem
    
    $lblStatus.Text = "✅ Loaded: $($selectedItem.FieldValues.Title)"
    $lblStatus.BackColor = [System.Drawing.Color]::LightGreen
    
    $tabControl.SelectedTab = $tabAdd
})

# Close Button
$btnClose.add_Click({
    $form.Close()
})

# ══════════════════════════════════════════════════════════════════════════════
# SHOW THE GUI
# ══════════════════════════════════════════════════════════════════════════════

Write-Host "🎨 Launching Ultimate GUI..." -ForegroundColor Cyan
Write-Host "Site: $SiteUrl" -ForegroundColor Gray
Write-Host "List: $ListTitle" -ForegroundColor Gray
Write-Host "Config: $ConfigPath" -ForegroundColor Gray
Write-Host ""

[void]$form.ShowDialog()

Write-Host "Application closed." -ForegroundColor Gray
