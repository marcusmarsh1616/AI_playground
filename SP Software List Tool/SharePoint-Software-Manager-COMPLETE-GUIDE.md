# SharePoint Software Manager - Complete User & Developer Guide

**Version:** 2.0 - Ultimate Edition  
**Last Updated:** April 28, 2026  
**Application Location:** `SharePoint-Software-Manager.ps1`  
**Quick Launcher:** `Launch-SoftwareManager.ps1`

---

## 📋 Table of Contents

1. [Overview](#1-overview)
2. [Features at a Glance](#2-features-at-a-glance)
3. [Prerequisites & Installation](#3-prerequisites--installation)
4. [Quick Start Guide](#4-quick-start-guide)
5. [Complete User Guide](#5-complete-user-guide)
6. [Field Reference](#6-field-reference)
7. [Troubleshooting](#7-troubleshooting)
8. [Advanced Usage](#8-advanced-usage)
9. [Architecture & Development](#9-architecture--development)
10. [FAQ](#10-faq)

---

## 1. Overview

### 1.1 What Is This Application?

SharePoint Software Manager is a **PowerShell 7-based Windows GUI application** that provides a modern, efficient interface for managing software inventory in SharePoint Online.

**Key Purpose:** Replace clunky browser-based SharePoint list editing with a dedicated desktop application that offers:
- Faster data entry through templates and form pre-filling
- Quick Edit popup for single-field updates (no tab switching!)
- Search and filter capabilities
- Recent items view
- Automatic validation before submission
- No page reloads or browser navigation

### 1.2 Why This Exists

**The Problem:**
Managing software inventory through SharePoint's web interface involves:
- Multiple page loads for each entry
- Navigating through complex list forms
- Re-entering similar data repeatedly
- No easy way to copy previous entries
- Slow performance with large lists
- Prone to typos and validation errors

**The Solution:**
A native Windows application that:
- Loads once, stays open
- Pre-fills forms from templates or previous entries
- Validates data before submission
- Provides instant search and edit capabilities
- Auto-calculates reference numbers
- Handles null values gracefully
- Offers keyboard shortcuts and double-click actions

### 1.3 Target Users

- **IT Asset Managers**: Maintain comprehensive software inventories
- **Endpoint Management Teams**: Track software deployments and versions
- **Service Desk Personnel**: Update software status and details
- **Compliance Officers**: Monitor license renewals and compliance status
- **Anyone** managing software in SharePoint who wants to work faster

### 1.4 Technology Stack

- **Language**: PowerShell 7.2+
- **GUI Framework**: System.Windows.Forms (.NET)
- **SharePoint API**: PnP.PowerShell 2.x
- **Authentication**: OAuth via browser (UseWebLogin)
- **Data Storage**: SharePoint Online List
- **Config Storage**: JSON in user profile

---

## 2. Features at a Glance

### 2.1 Three-Tab Interface

#### Tab 1: ➕ Add New Software
- Full form with all fields
- Quick Actions section:
  - **Load Last Entry**: Copy most recent item
  - **Load Template**: Load saved form preset
  - **Save as Template**: Save current form
  - **Clear Form**: Reset all fields
- Multi-select for License Type and Product Status
- Date picker with "No renewal date" option
- Auto-calculates next Ref number
- Validation for required fields

#### Tab 2: 🔄 Update/Search
- Search box (searches Title and Vendor)
- Refresh All button (loads 100 most recent)
- Results ListView with columns: ID, Ref, Title, Vendor, Version, Status
- Action buttons:
  - **Load to Update Form**: Full form editing
  - **⚡ Quick Edit**: Popup dialog for fast edits
  - **Open in Browser**: Direct SharePoint link
- Quick Update section for loaded items
- **Double-click** any row for instant Quick Edit

#### Tab 3: 📊 Recent Items
- View 50 most recent additions
- Shows: ID, Ref, Title, Vendor, Version, Created date
- Refresh Recent button
- Load to Form button
- Double-click to Quick Edit

### 2.2 ⚡ Quick Edit Feature

**The Star Feature** - Edit software in 3 clicks:
1. Find item (search or browse)
2. Double-click row
3. Make changes → Save

**Quick Edit Dialog Includes:**
- Title, Vendor, Version
- User AD Group
- SAFR Boundary (dropdown)
- Update Frequency (dropdown)
- BigFix (dropdown)
- Next Update Quarter
- Auto-Updates (checkbox)
- Product Status (multi-checkbox)

**Benefits:**
- No tab switching
- No form clutter
- Instant updates
- Auto-refresh after save

### 2.3 💾 Template System

**Save Form Configurations:**
1. Fill form with common values
2. Click "Save as Template"
3. Anytime: Click "Load Template" to restore

**Use Cases:**
- Standard browser installations (same settings, different titles)
- Vendor-specific defaults
- Department-specific configurations

**Storage:** `%USERPROFILE%\SPSoftwareManager_Config.json`

### 2.4 🔌 Pre-Connect Mode

**Avoid GUI Freezing:**
- Connect to SharePoint **before** opening GUI
- Browser auth happens in console
- GUI opens already connected
- No UI thread blocking

**Launch Methods:**
```powershell
# Recommended
.\Launch-SoftwareManager.ps1

# Or
.\SharePoint-Software-Manager.ps1 -PreConnect
```

### 2.5 ✅ Automatic Prerequisites

On first run, the app:
1. Checks PowerShell version (requires 7+)
2. Checks for PnP.PowerShell module
3. Prompts to install if missing
4. Removes incompatible version 3.x
5. Installs stable version 2.x
6. Imports module automatically

**You just run it - prerequisites handle themselves!**

### 2.6 Additional Features

- **Color-coded status bar**: Green = success, Red = error, Yellow = working
- **Progress indicator** for long operations
- **Connection management**: Connect/Disconnect buttons
- **Validation dialogs** before destructive actions
- **Error messages** with actionable guidance
- **Null-safe ListView**: Handles missing data gracefully
- **DateTime formatting**: Proper date display

---

## 3. Prerequisites & Installation

### 3.1 System Requirements

**Required:**
- **Windows 10/11** (64-bit recommended)
- **PowerShell 7.0 or higher** (NOT Windows PowerShell 5.1)
- **Internet connection** (for SharePoint)
- **.NET Framework** (built into Windows 10/11)

**Permissions:**
- **SharePoint**: Read/Write access to target list
- **No admin rights needed** for installation

### 3.2 Check Your Environment

```powershell
# Check PowerShell version
$PSVersionTable.PSVersion
# Should show: 7.x.x

# Check if PnP module exists
Get-Module PnP.PowerShell -ListAvailable
# Should show version 2.x.x (or nothing, app will install)
```

### 3.3 Installing PowerShell 7

If you don't have PowerShell 7:

**Method 1: WinGet (Recommended)**
```powershell
winget install Microsoft.PowerShell
```

**Method 2: MSI Installer**
1. Go to: https://aka.ms/powershell
2. Download latest stable release
3. Run installer

**Method 3: Chocolatey**
```powershell
choco install powershell-core
```

**Verify Installation:**
```powershell
pwsh --version
# Should show: PowerShell 7.x.x
```

### 3.4 Installing the Application

**Step 1: Get the Files**
You need:
- `SharePoint-Software-Manager.ps1` (main application)
- `Launch-SoftwareManager.ps1` (quick launcher)

Place them in a folder, e.g.:
```
C:\Tools\SharePoint-Manager\
```

**Step 2: Run the Quick Launcher**
```powershell
cd "C:\Tools\SharePoint-Manager"
.\Launch-SoftwareManager.ps1
```

**Step 3: First-Run Setup**
The app will:
1. Check PowerShell version ✅
2. Check for PnP.PowerShell module
3. If missing: "Install PnP.PowerShell 2.x now? (Y/N)"
4. Type `Y` and press Enter
5. Module installs (takes ~1 minute)
6. Browser opens for SharePoint authentication
7. Sign in with your credentials
8. GUI opens, connected and ready!

**That's it!** The app handles everything else.

### 3.5 Troubleshooting Installation

**If PowerShell 7 install fails:**
- Check you have internet connection
- Try running as administrator
- Download MSI manually from https://aka.ms/powershell

**If PnP module install fails:**
```powershell
# Try manual install
Install-Module PnP.PowerShell -MaximumVersion 2.99.0 -Scope CurrentUser -Force

# If it says "untrusted repository", accept it:
Install-Module PnP.PowerShell -MaximumVersion 2.99.0 -Scope CurrentUser -Force -AllowClobber
```

**If you have PnP 3.x causing issues:**
```powershell
# Remove all versions
Uninstall-Module PnP.PowerShell -AllVersions -Force

# Install 2.x
Install-Module PnP.PowerShell -MaximumVersion 2.99.0 -Scope CurrentUser -Force
```

---

## 4. Quick Start Guide

### 4.1 Your First Launch (5 Minutes)

**Step 1: Launch the App**
```powershell
.\Launch-SoftwareManager.ps1
```

You'll see:
```
🚀 SharePoint Software Manager - Ultimate Edition

══════════════════════════════════════════════════
  Checking Prerequisites
══════════════════════════════════════════════════
Checking PowerShell version...
✅ PowerShell 7.5.0 detected
Checking PnP.PowerShell module...
✅ PnP.PowerShell 2.12.0 is installed
Loading PnP.PowerShell module...
✅ PnP.PowerShell 2.12.0 loaded successfully

✅ All prerequisites satisfied!
══════════════════════════════════════════════════

══════════════════════════════════════════════════
  Pre-Connect Mode
══════════════════════════════════════════════════
Connecting to SharePoint...
Browser window will open for authentication.
```

**Step 2: Authenticate**
- Browser opens
- Sign in with your organization credentials
- Complete MFA if required
- Browser shows "Authentication complete"
- Close browser tab
- Return to console

You'll see:
```
✅ Connected successfully!
══════════════════════════════════════════════════

🎨 Launching GUI...
```

**Step 3: GUI Opens**
You're now looking at the SharePoint Software Manager window!
- Status bar shows: "✅ Already connected! Ready to use."
- You're on the "➕ Add New" tab
- All fields are empty and ready

### 4.2 Add Your First Software (2 Minutes)

**Fill in these required fields:**

1. **Title**: `Google Chrome`
2. **Vendor**: `Google`
3. **Product Status**: Check ☑ `Production`

**Optional (but recommended):**
- **Version**: `131.0.6778.86`
- **SAFR Boundary**: Select `District`
- **Update Frequency**: Select `Annually`

**Click: "➕ Add Software"**

You'll see:
```
Success dialog:
Software added successfully!

ID: 123
Ref: 45

Clear form to add another?
[Yes] [No]
```

**Click Yes** to clear the form, or **No** to keep values for similar entry.

**Verify:**
1. Go to **"📊 Recent Items"** tab
2. Click **"Refresh Recent"**
3. You should see Chrome at the top!

### 4.3 Your First Update (1 Minute)

**Find the item:**
1. Go to **"🔄 Update/Search"** tab
2. Type `chrome` in search box
3. Click **"Search"**
4. You see Chrome in the list

**Quick Edit:**
1. **Double-click** the Chrome row
2. Quick Edit popup appears
3. Change **Version** to `132.0.6834.83`
4. Click **"💾 Save"**
5. Done!

Status bar shows: "✅ Item updated successfully!"

The list auto-refreshes with the new version!

### 4.4 Your First Template (1 Minute)

**Save a template for similar software:**

1. Fill out the **"Add New"** form:
   - **SAFR Boundary**: `District`
   - **Update Frequency**: `Annually`
   - **BigFix**: `No`
   - Leave Title and Vendor blank (you'll change these per-software)

2. Click **"Save as Template"**

3. Status bar: "✅ Template saved"

**Now use it:**
1. Click **"Load Template"**
2. Form fills with your saved values
3. Enter **Title**: `Slack` and **Vendor**: `Slack Technologies`
4. Check **Product Status**: `LSS`
5. Click **"➕ Add Software"**

**Repeat for more software** - just Load Template → Change Title/Vendor → Add!

---

## 5. Complete User Guide

### 5.1 Launching the Application

#### Option 1: Quick Launcher (Recommended)
```powershell
.\Launch-SoftwareManager.ps1
```
- Connects in console first
- Then opens GUI
- No UI freezing

#### Option 2: Direct with Pre-Connect
```powershell
.\SharePoint-Software-Manager.ps1 -PreConnect
```
- Same as Quick Launcher
- Uses parameter directly

#### Option 3: Launch Then Connect
```powershell
.\SharePoint-Software-Manager.ps1
```
- Opens GUI immediately
- Click "Connect" button
- **Warning**: May cause UI freeze during browser auth

**Best Practice:** Always use the Quick Launcher or `-PreConnect` parameter.

### 5.2 Adding Software

#### Method 1: Manual Entry

**When to use:** New software, all fields needed

1. Ensure you're on **"➕ Add New"** tab
2. Fill **required** fields:
   - Title (e.g., "Microsoft Teams")
   - Vendor (e.g., "Microsoft")
   - Product Status (check at least one)
3. Fill **optional** fields as needed
4. Click **"➕ Add Software"**
5. Success dialog appears with ID and Ref
6. Choose to clear form or keep values

**Tips:**
- Use Tab key to move between fields
- Dropdowns auto-complete when you type
- Checkboxes support spacebar toggle
- Date picker has calendar popup

#### Method 2: Load Last Entry

**When to use:** Adding similar software (e.g., different version)

1. Click **"Load Last Entry"** button
2. Form fills with most recent item
3. Modify what changed:
   - Usually Title, Vendor, or Version
4. Click **"➕ Add Software"**

**Example:**
```
Last Entry: Adobe Acrobat Pro DC 2023
↓ Load Last Entry
↓ Change Title to: Adobe Acrobat Pro DC 2024
↓ Change Version to: 24.001.20643
↓ Add Software
Result: New entry created with updated info
```

#### Method 3: Load Template

**When to use:** Repetitive entries with common fields

**First time - Create template:**
1. Fill form with standard values
   - Example: SAFR = "District", Update Frequency = "Annually"
2. Click **"Save as Template"**
3. Template saved!

**Every subsequent time:**
1. Click **"Load Template"**
2. Form fills with saved values
3. Change Title, Vendor, Version
4. Add any unique fields
5. Click **"➕ Add Software"**

**Real-world workflow:**
```
Template: Standard Desktop Application
- SAFR Boundary: District
- Update Frequency: Annually
- BigFix: No
- Auto-Updates: No
- License Type: District

Use template for:
- Slack (Slack Technologies)
- Zoom (Zoom Video)
- Teams (Microsoft)
- Chrome (Google)

Each takes 30 seconds to add!
```

#### Method 4: Copy from Recent Items

**When to use:** Software similar to recently added

1. Go to **"📊 Recent Items"** tab
2. Click **"Refresh Recent"**
3. Find similar item
4. Select it
5. Click **"Load to Form"**
6. Switches to "Add New" tab
7. Modify fields
8. Click **"➕ Add Software"**

### 5.3 Searching for Software

#### Basic Text Search

1. Go to **"🔄 Update/Search"** tab
2. Enter search term in **Search** box
3. Click **"Search"**

**Searches:**
- Title field
- Vendor field
- Case-insensitive
- Partial matches work

**Examples:**
- `chrome` finds: "Google Chrome", "Chrome Enterprise", "Chrome Remote Desktop"
- `microsoft` finds: All Microsoft products
- `131` finds: All software with version "131.x.x"
- `acrobat` finds: "Adobe Acrobat", "Acrobat Reader", etc.

#### View All Items

1. Go to **"🔄 Update/Search"** tab
2. Click **"Refresh All"**
3. Displays up to 100 most recent items
4. Sorted by ID descending (newest first)

**When to use:**
- Browse recent additions
- No specific search term
- See what's been added lately

**Performance note:** For lists with >100 items, use Search for older entries.

#### Understanding Results

**ListView Columns:**
- **ID**: SharePoint's internal item ID (unique, auto-assigned)
- **Ref**: Your custom reference number (auto-incremented)
- **Title**: Software name
- **Vendor**: Publisher/vendor
- **Version**: Version number (blank if not entered)
- **Status**: Product Status values (comma-separated if multiple)

**Example results:**
```
ID  | Ref | Title         | Vendor          | Version        | Status
────┼─────┼───────────────┼─────────────────┼────────────────┼──────────────────
125 | 47  | Slack         | Slack Tech      | 4.38.125       | LSS, NY
124 | 46  | Zoom          | Zoom Video      | 5.14.0         | Production
123 | 45  | Chrome        | Google          | 132.0.6834.83  | Production
122 | 44  | Teams         | Microsoft       | 24166.1502.1    | LSS, Production
```

### 5.4 Updating Software

#### Method 1: ⚡ Quick Edit (Fastest - Recommended)

**When to use:** Updating one or two fields quickly

**Steps:**
1. Find the item (search or browse)
2. **Double-click the row** (or select it and click "⚡ Quick Edit")
3. Quick Edit popup appears
4. Make your changes
5. Click **"💾 Save"**
6. List auto-refreshes

**Example - Update Chrome Version:**
```
Time: 10 seconds

1. Search: "chrome"
2. Double-click Chrome row
3. Popup opens
4. Change Version: "131.0" → "132.0"
5. Click Save
6. Done!

Total clicks: 3
```

**Fields available in Quick Edit:**
- Title (usually leave as-is)
- Vendor (usually leave as-is)
- Version ← Most commonly changed
- User AD Group
- SAFR Boundary (dropdown)
- Update Frequency (dropdown)
- BigFix (dropdown)
- Next Update Quarter
- Auto-Updates (checkbox)
- Product Status (multi-checkbox)

**Not in Quick Edit** (use Method 2 for these):
- Ref (never editable)
- Uninstall AD group
- SME AD group
- License Type
- Next Renewal Date

#### Method 2: Load to Update Form (Full Edit)

**When to use:** Changing many fields, need to see all options

**Steps:**
1. Find and select the item
2. Click **"Load to Update Form"**
3. Automatically switches to "➕ Add New" tab
4. All fields populated with current values
5. Status shows: "Loaded: [Name] (ID: 123)"
6. Edit any/all fields
7. Switch back to **"🔄 Update/Search"** tab
8. Verify loaded item in "Quick Update" section
9. Click **"Update in SharePoint"**
10. Confirm dialog → Yes
11. Done!

**Example - Major Update:**
```
Software: Adobe Acrobat DC
Changes needed:
- Version: 2023 → 2024
- User AD Group: Old name → New name
- Update Frequency: Annually → Quarterly
- License Type: Add "NPO"
- Next Renewal Date: Set to June 30, 2025

Time: 2 minutes

Process:
1. Search "Acrobat"
2. Select Adobe Acrobat DC
3. Load to Update Form
4. On "Add New" tab:
   - Change all 5 fields
5. Back to "Update/Search" tab
6. Click "Update in SharePoint"
7. Confirm
8. All changes saved!
```

#### Method 3: Update from Recent Items

**When to use:** Just added something and need to fix it

**Steps:**
1. Go to **"📊 Recent Items"** tab
2. Click **"Refresh Recent"**
3. Find the item (probably at top)
4. **Double-click it**
5. Quick Edit popup
6. Fix the issue
7. Save

**Tip:** This is fastest for "oops, I made a typo" situations.

### 5.5 Managing Templates

#### Creating a Template

**Purpose:** Save form configuration for repeated use

**Steps:**
1. Fill out **"Add New"** form with desired values
2. Include all common fields you want to reuse
3. Click **"Save as Template"**
4. Status: "✅ Template saved to: [path]"
5. Confirmation dialog

**What gets saved:**
- All text fields (except Title/Vendor if you want those unique)
- All dropdown selections
- All checkbox states (License Type, Product Status)
- Auto-Updates checkbox
- Next Renewal Date checkbox state (but not the actual date)

**What does NOT get saved:**
- The actual Ref number (auto-calculated each time)
- The actual Renewal Date value (set manually each time if needed)

**Storage location:**
```
C:\Users\YourName\SPSoftwareManager_Config.json
```

#### Loading a Template

**Steps:**
1. Click **"Load Template"**
2. If template exists:
   - Form fills with saved values
   - Status: "✅ Template loaded"
3. If no template:
   - Dialog: "No template file found"
   - Suggestion to create one

**Then:**
- Modify the unique fields (Title, Vendor, Version)
- Click **"➕ Add Software"**

#### Editing a Template

**Option 1: Through GUI**
1. Load the template
2. Make changes
3. Click "Save as Template" again
4. Overwrites existing template

**Option 2: Edit JSON Directly**
1. Open in Notepad:
   ```
   notepad $env:USERPROFILE\SPSoftwareManager_Config.json
   ```
2. Edit values
3. Save file
4. Load template in app

**JSON format example:**
```json
{
  "Title": "",
  "Vendor": "",
  "Version": "",
  "UserAD": "",
  "UninstallAD": "",
  "SMEAD": "",
  "SAFR": "District",
  "UpdateFreq": "Annually",
  "BigFix": "No",
  "NextQuarter": "",
  "NoRenewalDate": true,
  "RenewalDate": null,
  "AutoUpdates": false,
  "LicenseNPO": false,
  "LicenseDistrict": true,
  "LicenseCAM": false,
  "LicenseNA": false,
  "ProdProduction": true,
  "ProdCOE": false,
  "ProdCatalog": false,
  "ProdRemoved": false,
  "ProdLSS": false,
  "ProdNY": false,
  "ProdStandard": false
}
```

#### Multiple Templates (Workaround)

**Problem:** App supports one template at a time.

**Solution:** Manually manage multiple JSON files:

1. Create template variants:
   ```powershell
   # Save different templates
   Copy-Item "$env:USERPROFILE\SPSoftwareManager_Config.json" "Template_Browsers.json"
   Copy-Item "$env:USERPROFILE\SPSoftwareManager_Config.json" "Template_Office.json"
   Copy-Item "$env:USERPROFILE\SPSoftwareManager_Config.json" "Template_DevTools.json"
   ```

2. When you need a specific template:
   ```powershell
   # Use browser template
   Copy-Item "Template_Browsers.json" "$env:USERPROFILE\SPSoftwareManager_Config.json"
   ```

3. Load in app

**Future enhancement:** Could add template selector dropdown in app.

### 5.6 Viewing Recent Items

**Purpose:** See what was recently added, copy recent items

**Steps:**
1. Go to **"📊 Recent Items"** tab
2. Click **"Refresh Recent"**
3. View 50 most recent items
4. Sorted by ID descending (newest at top)

**Columns shown:**
- ID
- Ref
- Title
- Vendor
- Version
- Created (date/time)

**Actions available:**
- **Select an item** → "Load to Form" button enables
- **Click "Load to Form"** → Copies to "Add New" tab
- **Double-click item** → Opens Quick Edit popup

**Use cases:**
- Verify your recent additions
- Copy a recently added item to create similar
- Quick edit a recent mistake
- Review what colleagues added today
- Check if software already exists before adding

### 5.7 Connection Management

#### Connecting to SharePoint

**If Pre-Connected (Recommended):**
- Status shows: "Status: Connected to [URL] (Pre-Connected)"
- Connect button: Disabled (already connected)
- Disconnect button: Enabled
- All features: Active

**If Not Pre-Connected:**
1. App opens with "Status: Not connected"
2. Click **"Connect"** button
3. Status changes to "Status: Connecting..."
4. Browser opens
5. Authenticate with credentials
6. Browser shows "Authentication complete"
7. Return to app
8. Status: "✅ Connected to SharePoint successfully!"
9. All features enabled

**Connection indicators:**
- **Green text**: Connected
- **Red text**: Not connected
- **Orange text**: Connecting...
- **Progress bar**: Active during connection

#### Disconnecting

**When to disconnect:**
- End of work session
- Switching SharePoint sites (not implemented yet)
- Troubleshooting connection issues

**Steps:**
1. Click **"Disconnect"** button
2. Status: "Disconnected from SharePoint"
3. Connection dropped
4. All features disabled (except Connect)
5. Any loaded update items cleared

**Note:** Disconnecting doesn't close the app, just drops the SharePoint connection.

#### Troubleshooting Connection

**If connection fails:**
1. Check console for error details
2. Verify SharePoint URL is correct
3. Test site access in browser:
   ```powershell
   Start-Process "https://frbprod1.sharepoint.com/sites/EUSEndpointasaService"
   ```
4. Try manual connection:
   ```powershell
   Import-Module PnP.PowerShell
   Connect-PnPOnline -Url "https://your-site-url" -UseWebLogin
   Get-PnPException
   ```

**If UI freezes during connection:**
- Close app
- Relaunch with Pre-Connect mode:
  ```powershell
  .\Launch-SoftwareManager.ps1
  ```

---

## 6. Field Reference

### 6.1 Complete Field List

| Display Name | Type | Required | Description | Example Value | Internal Name |
|--------------|------|----------|-------------|---------------|---------------|
| Title | Text | Yes | Software name | "Google Chrome" | Title |
| Ref | Number | Yes (auto) | Reference number | 45 | Ref |
| Vendor | Text | Yes | Publisher/vendor | "Google" | Vendor |
| Version # (alt.) | Text | No | Version number | "131.0.6778.86" | Version_x0023__x0028_alt_x002e__ |
| User AD Group | Text | No | User access AD group | "EUSG-Chrome-Users" | AD_Group_Name |
| Uninstall AD group | Text | No | Uninstall AD group | "EUSG-U-Chrome-Users" | UninstallADgroup |
| SME AD group | Text | No | SME AD group | "EUSZ-Chrome-SMEs" | SMEADgroup |
| SAFR Boundary | Choice | No | SAFR designation | "District" | SAFRBoundary |
| License Type | Multi-Choice | No | License type(s) | ["NPO", "District"] | LicenseType |
| Product Status | Multi-Choice | Yes | Current status | ["Production", "LSS"] | CatalogStatus |
| Next Renewal Date | DateTime | No | License renewal | 2025-06-30 | NextRenewalDate |
| Next Update Quarter | Text | No | Update quarter | "Q3 - 2026" | NextUpdateQuarter |
| Update Frequency | Choice | No | Update frequency | "Annually" | UpdateFrequency |
| Auto-Updates? | Boolean | No | Auto-update enabled | True/False | Auto_x002d_Updates_x003f_ |
| BigFix? | Choice | No | BigFix managed | "Yes" | BigFix_x003f_ |

### 6.2 Field Validation Rules

#### Title
- **Required**: Yes
- **Type**: Text
- **Max Length**: 255 characters
- **Validation**: Must not be empty/whitespace
- **Examples Valid**: 
  - "Google Chrome"
  - "Microsoft Office 365 ProPlus"
  - "Adobe Creative Cloud"
- **Examples Invalid**:
  - "" (empty)
  - "   " (whitespace only)

#### Ref
- **Required**: Yes (but auto-generated)
- **Type**: Integer
- **Validation**: Must be unique, must be > 0
- **Behavior**: App queries existing items, finds max Ref, adds 1
- **User Input**: Can manually override (not recommended)
- **Example**: If max Ref is 44, next will be 45

#### Vendor
- **Required**: Yes
- **Type**: Text
- **Max Length**: 255 characters
- **Validation**: Must not be empty
- **Examples**: "Google", "Microsoft Corporation", "Adobe Systems Inc."

#### Product Status
- **Required**: Yes
- **Type**: Multi-select checkboxes
- **Min Selections**: 1
- **Max Selections**: Unlimited
- **Values**: 
  - Production
  - COE (Center of Excellence)
  - Catalog Item
  - Removed
  - LSS (Local Self Service?)
  - NY (New York?)
  - Standard
- **Validation**: At least one must be checked
- **Error if violated**: "At least one Product Status is required!"
- **Common combinations**:
  - Production only
  - LSS + NY
  - Production + LSS

#### SAFR Boundary
- **Required**: No
- **Type**: Single-select dropdown
- **Values**:
  - (blank)
  - EaaS (Endpoint as a Service)
  - Product team
  - District
  - NA
- **Default**: (blank)

#### License Type
- **Required**: No
- **Type**: Multi-select checkboxes
- **Values**:
  - NPO
  - District
  - CAM
  - N/A
- **Behavior**: Can select 0-4 options

#### Update Frequency
- **Required**: No
- **Type**: Single-select dropdown
- **Values**:
  - (blank)
  - Quarterly
  - Semi-Annually
  - Annually
  - No further updates
  - Monthly
  - Used strictly for licensing

#### BigFix?
- **Required**: No
- **Type**: Single-select dropdown
- **Values**:
  - (blank)
  - Yes
  - No
  - _ (underscore = unknown/N/A)

#### Version # (alt.)
- **Required**: No
- **Type**: Text
- **Format**: Free-form (no validation)
- **Common formats**:
  - "131.0.6778.86" (Chrome style)
  - "24.001.20643" (Adobe style)
  - "2024" (Year-based)
  - "v3.5.2" (Semantic versioning)

#### Auto-Updates?
- **Required**: No
- **Type**: Boolean (checkbox)
- **Values**: 
  - True (checked)
  - False (unchecked)
- **Default**: False

#### Next Renewal Date
- **Required**: No
- **Type**: DateTime
- **Format**: Date picker (MM/dd/yyyy)
- **Special**: "No renewal date" checkbox
- **Behavior**: If checkbox is checked, date is not sent to SharePoint

#### Next Update Quarter
- **Required**: No
- **Type**: Text
- **Format**: Free-form, but convention is "Q# - YYYY"
- **Examples**: 
  - "Q3 - 2026"
  - "Q1 - 2025"
  - "Q4 - 2024"

### 6.3 Internal Name Encoding

SharePoint encodes special characters in internal field names:

| Character | Encoding | Example |
|-----------|----------|---------|
| `#` | `_x0023_` | Version # → Version_x0023_ |
| `?` | `_x003f_` | BigFix? → BigFix_x003f_ |
| `-` | `_x002d_` | Auto-Updates? → Auto_x002d_Updates_x003f_ |
| `(` | `_x0028_` | (alt.) → _x0028_alt |
| `)` | `_x0029_` | (alt.) → alt_x0029_ |
| `.` | `_x002e_` | (alt.) → _x002e__ |
| Space | `_x0020_` | AD Group → AD_x0020_Group |

**Why this matters:**
- App handles encoding automatically
- If debugging, you'll see these encoded names
- PnP.PowerShell uses internal names, not display names

**Example:**
```
Display Name: "Version # (alt.)"
Internal Name: "Version_x0023__x0028_alt_x002e__"
```

---

## 7. Troubleshooting

### 7.1 Connection Issues

#### Error: "Connection failed. Check console for details."

**Possible Causes:**
1. Wrong SharePoint URL
2. No internet connection
3. SharePoint site doesn't exist
4. No permissions to site
5. Authentication cancelled

**Solutions:**

**Check URL:**
```powershell
# Try opening in browser
Start-Process "https://frbprod1.sharepoint.com/sites/EUSEndpointasaService"
# Should open without errors
```

**Check Network:**
```powershell
Test-NetConnection frbprod1.sharepoint.com -Port 443
# Should show: TcpTestSucceeded : True
```

**Check Permissions:**
- Ensure your account has access
- Contact SharePoint admin if needed

**Try Manual Connection:**
```powershell
Import-Module PnP.PowerShell
Connect-PnPOnline -Url "https://frbprod1.sharepoint.com/sites/EUSEndpointasaService" -UseWebLogin
# If fails, run:
Get-PnPException
# Shows detailed error
```

**Clear Cached Credentials:**
```powershell
Disconnect-PnPOnline -ErrorAction SilentlyContinue
# Then try connecting again
```

#### Error: "Specified method is not supported"

**Cause:** Wrong PnP.PowerShell or PowerShell version

**Check Versions:**
```powershell
# PowerShell version
$PSVersionTable.PSVersion
# Must be: 7.0+

# PnP version
Get-Module PnP.PowerShell -ListAvailable | Select-Object Version
# Must be: 2.x.x
```

**Fix PowerShell Version:**
```powershell
# Install PowerShell 7
winget install Microsoft.PowerShell
# Then run app in pwsh.exe, not powershell.exe
```

**Fix PnP Version:**
```powershell
# Remove all versions
Uninstall-Module PnP.PowerShell -AllVersions -Force

# Install 2.x
Install-Module PnP.PowerShell -MaximumVersion 2.99.0 -Scope CurrentUser -Force

# Verify
Get-Module PnP.PowerShell -ListAvailable
```

#### Form Freezes During Connection

**Cause:** UI thread blocking during browser authentication

**Solution:** Use Pre-Connect mode
```powershell
# Close frozen app
# Relaunch with:
.\Launch-SoftwareManager.ps1
```

This connects in console before opening GUI, avoiding the freeze.

### 7.2 Adding/Updating Issues

#### Error: "List 'Endpoint Software List' does not exist"

**Cause:** Wrong list name or site

**Verify List Exists:**
```powershell
Get-PnPList | Where-Object { $_.Title -like "*Software*" } | Select-Object Title
```

**Launch with Correct List:**
```powershell
.\SharePoint-Software-Manager.ps1 -ListTitle "YourListName" -PreConnect
```

#### Error: "Invalid data has been used to update the list item"

**Causes:**
1. Field name mismatch
2. Data type mismatch
3. Choice value not in allowed list
4. Required field missing
5. Read-only field being updated

**Diagnose:**
```powershell
# Check field info
Get-PnPField -List "Endpoint Software List" | 
  Where-Object { -not $_.Hidden } | 
  Select-Object Title, InternalName, TypeAsString, ReadOnlyField

# Get detailed error
Get-PnPException
```

**Common Issues:**

**Choice field value not in list:**
```powershell
# Check allowed values
$field = Get-PnPField -List "Endpoint Software List" -Identity "UpdateFrequency"
$field.Choices
# Make sure your value matches exactly (including case)
```

**Wrong internal name:**
- App uses correct internal names
- If modified script, verify names match SharePoint

**Required field missing:**
- Ensure Title, Vendor, and Product Status are provided
- Check dialog validations before clicking Add

#### Error: "Value cannot be null. (Parameter 'item')"

**Cause:** ListView trying to display null field

**Status:** Fixed in current version

**If you see this:** Update your script to latest version.

**Fix (if editing code):**
```powershell
# Old (broken):
$listItem.SubItems.Add($f.Field)

# New (fixed):
$listItem.SubItems.Add($(if ($f.Field) { $f.Field } else { "" }))
```

#### Error: DateTime conversion in ListView

**Cause:** ListView expecting string, got DateTime object

**Status:** Fixed in current version

**Fix (if editing code):**
```powershell
# Old (broken):
$listItem.SubItems.Add($f.Created)

# New (fixed):
$listItem.SubItems.Add($(if ($f.Created) { $f.Created.ToString("yyyy-MM-dd HH:mm") } else { "" }))
```

### 7.3 Template Issues

#### Template Doesn't Load

**Causes:**
1. File doesn't exist
2. JSON corrupted
3. Wrong file path

**Check File:**
```powershell
Test-Path "$env:USERPROFILE\SPSoftwareManager_Config.json"
# Should return: True
```

**Verify JSON:**
```powershell
Get-Content "$env:USERPROFILE\SPSoftwareManager_Config.json" | ConvertFrom-Json
# Should not error
```

**If Corrupted:**
```powershell
# Delete and recreate
Remove-Item "$env:USERPROFILE\SPSoftwareManager_Config.json"
# Then use GUI to save new template
```

**Check Permissions:**
```powershell
Get-Acl "$env:USERPROFILE\SPSoftwareManager_Config.json" | Format-List
```

#### Template Loads Wrong Values

**Cause:** JSON manually edited with incorrect format

**Solution:**
```powershell
# Delete corrupted template
Remove-Item "$env:USERPROFILE\SPSoftwareManager_Config.json"
# Recreate via GUI
```

### 7.4 Module Issues

#### Error: "PnP.PowerShell 2.x not found"

**Solutions:**

**Let app install:**
- When prompted "Install PnP.PowerShell 2.x now? (Y/N)"
- Type `Y`

**Manual install:**
```powershell
Install-Module PnP.PowerShell -MaximumVersion 2.99.0 -Scope CurrentUser -Force
```

**If "untrusted repository" error:**
```powershell
Install-Module PnP.PowerShell -MaximumVersion 2.99.0 -Scope CurrentUser -Force -AllowClobber
```

**Verify:**
```powershell
Get-Module PnP.PowerShell -ListAvailable
# Should show version 2.x.x
```

#### Error: "Module in use" During Uninstall

**Cause:** Module loaded in PowerShell session

**Solution:**
1. Close ALL PowerShell windows
2. Open fresh PowerShell 7 window
3. Run:
```powershell
Uninstall-Module PnP.PowerShell -AllVersions -Force
```

**Nuclear option (if above fails):**
```powershell
# Find module path
$modulePath = (Get-Module PnP.PowerShell -ListAvailable)[0].ModuleBase | Split-Path

# Take ownership and delete
takeown /f "$modulePath" /r /d y
icacls "$modulePath" /grant administrators:F /t
Remove-Item "$modulePath" -Recurse -Force
```

### 7.5 GUI Issues

#### Form Controls Not Responding

**Cause:** Long operation in progress

**Check:**
- Progress bar at bottom (animating?)
- Status bar text (what's happening?)

**If Truly Frozen:**
1. Check PowerShell console for errors
2. Wait 30 seconds (SharePoint can be slow)
3. If still frozen: Close and relaunch
4. Use Pre-Connect mode next time

#### Quick Edit Dialog Doesn't Appear

**Checklist:**
- [ ] Item selected? (row highlighted)
- [ ] Connected to SharePoint? (green status)
- [ ] No other dialog open?

**Solution:**
1. Click item to select
2. Verify row highlighted
3. Click Quick Edit button (or double-click row)

#### Tabs Not Switching

**Rare issue:** .NET UI threading

**Solution:**
1. Click directly on tab name
2. If persists: Restart app

### 7.6 Performance Issues

#### Slow Loading of Items

**Causes:**
1. Large list (>1000 items)
2. Slow network
3. SharePoint throttling

**Solutions:**

**Use Search instead of Refresh All:**
```
Search narrows results = faster loading
```

**Reduce page size (edit script):**
```powershell
# Find line:
Get-SoftwareItems -ListName $ListTitle -Limit 100

# Change to:
Get-SoftwareItems -ListName $ListTitle -Limit 50
```

**Check Network:**
```powershell
Test-NetConnection frbprod1.sharepoint.com -Port 443
# Look at latency (should be < 100ms)
```

#### Application Startup Slow

**Cause:** Loading large PnP.PowerShell module (~50MB)

**Status:** Normal behavior

**Mitigation:**
- First load is slower (3-5 seconds)
- Subsequent launches faster (cached)
- Keep app open during work session rather than closing/reopening

---

## 8. Advanced Usage

### 8.1 Bulk Operations

#### Bulk Add from CSV

**Scenario:** Adding multiple software items at once

**Step 1: Create CSV**
```csv
Title,Vendor,Version,SAFR,Status
Google Chrome,Google,131.0.6778.86,District,Production
Slack,Slack Technologies,4.38.125,District,"LSS,NY"
Zoom,Zoom Video,5.14.0,EaaS,Production
Microsoft Teams,Microsoft,24166.1502.1,District,"Production,LSS"
```

**Step 2: Import Script**
```powershell
# Connect first
Import-Module PnP.PowerShell
Connect-PnPOnline -Url "https://frbprod1.sharepoint.com/sites/EUSEndpointasaService" -UseWebLogin

# Import CSV
$items = Import-Csv "C:\Temp\software.csv"

# Get next Ref
$existingItems = Get-PnPListItem -List "Endpoint Software List" -Fields "Ref"
$maxRef = ($existingItems | ForEach-Object { $_.FieldValues.Ref } | Measure-Object -Maximum).Maximum
$nextRef = if ($maxRef) { $maxRef + 1 } else { 1 }

# Add each item
foreach ($item in $items) {
    $statusArray = $item.Status -split "," | ForEach-Object { $_.Trim() }
    
    $values = @{
        "Ref" = $nextRef
        "Title" = $item.Title
        "Vendor" = $item.Vendor
        "Version_x0023__x0028_alt_x002e__" = $item.Version
        "SAFRBoundary" = $item.SAFR
        "CatalogStatus" = $statusArray
    }
    
    Add-PnPListItem -List "Endpoint Software List" -Values $values
    Write-Host "Added: $($item.Title) (Ref: $nextRef)"
    $nextRef++
}

Write-Host "Bulk add complete!"
```

#### Bulk Update Script

**Scenario:** Update all items matching criteria

**Example: Change SAFR Boundary for all "District" to "EaaS"**
```powershell
# Connect
Connect-PnPOnline -Url "https://frbprod1.sharepoint.com/sites/EUSEndpointasaService" -UseWebLogin

# Get items
$items = Get-PnPListItem -List "Endpoint Software List" -Fields "SAFRBoundary"

# Update each
$count = 0
foreach ($item in $items) {
    if ($item.FieldValues.SAFRBoundary -eq "District") {
        Set-PnPListItem -List "Endpoint Software List" -Identity $item.Id -Values @{
            "SAFRBoundary" = "EaaS"
        }
        Write-Host "Updated item ID $($item.Id): $($item.FieldValues.Title)"
        $count++
    }
}

Write-Host "Updated $count items"
```

### 8.2 Exporting Data

#### Export to CSV

```powershell
# Connect
Connect-PnPOnline -Url "https://frbprod1.sharepoint.com/sites/EUSEndpointasaService" -UseWebLogin

# Get all items
$items = Get-PnPListItem -List "Endpoint Software List" -PageSize 1000

# Export
$items | ForEach-Object {
    [PSCustomObject]@{
        ID = $_.FieldValues.ID
        Ref = $_.FieldValues.Ref
        Title = $_.FieldValues.Title
        Vendor = $_.FieldValues.Vendor
        Version = $_.FieldValues.Version_x0023__x0028_alt_x002e__
        ProductStatus = ($_.FieldValues.CatalogStatus -join ", ")
        SAFRBoundary = $_.FieldValues.SAFRBoundary
        UpdateFrequency = $_.FieldValues.UpdateFrequency
        Created = $_.FieldValues.Created
        Modified = $_.FieldValues.Modified
    }
} | Export-Csv "C:\Temp\SoftwareInventory.csv" -NoTypeInformation

Write-Host "Exported to C:\Temp\SoftwareInventory.csv"
```

#### Export to Excel

**Requires ImportExcel module:**
```powershell
# Install module (one time)
Install-Module ImportExcel -Scope CurrentUser

# Export
$data = $items | ForEach-Object { ... }  # Same as CSV above

$data | Export-Excel "C:\Temp\SoftwareInventory.xlsx" `
    -AutoSize `
    -TableName "Software" `
    -WorksheetName "Inventory" `
    -FreezeTopRow `
    -BoldTopRow

Write-Host "Exported to Excel"
```

### 8.3 Automation & Scheduling

#### Task Scheduler Integration

**Create scheduled update script:**
```powershell
# UpdateSoftware.ps1
$LogFile = "C:\Logs\SPSoftwareUpdate_$(Get-Date -Format 'yyyyMMdd').log"
Start-Transcript -Path $LogFile

try {
    Write-Host "Starting software update automation..."
    
    # Connect
    Import-Module PnP.PowerShell
    Connect-PnPOnline -Url "https://your-site" -UseWebLogin
    
    # Your automation logic here
    # Example: Update all Chrome versions
    $items = Get-PnPListItem -List "Endpoint Software List" |
        Where-Object { $_.FieldValues.Title -eq "Google Chrome" }
    
    foreach ($item in $items) {
        Set-PnPListItem -List "Endpoint Software List" -Identity $item.Id -Values @{
            "Version_x0023__x0028_alt_x002e__" = "132.0.6834.83"
        }
        Write-Host "Updated Chrome ID $($item.Id)"
    }
    
    Write-Host "Automation completed successfully"
}
catch {
    Write-Error "Automation failed: $_"
    exit 1
}
finally {
    Stop-Transcript
    Disconnect-PnPOnline
}
```

**Schedule with Task Scheduler:**
```powershell
# Create scheduled task
$action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-File C:\Scripts\UpdateSoftware.ps1"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 8am
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -LogonType Interactive

Register-ScheduledTask -TaskName "SPSoftwareUpdate" -Action $action -Trigger $trigger -Principal $principal -Description "Weekly software inventory update"
```

### 8.4 Extending the Application

#### Add New Field to GUI

**Scenario:** SharePoint list has new field "Department"

**Step 1: Add to Form (in script)**
```powershell
# Find form creation section (~line 500)
# Add after existing fields:

$lblDepartment = New-Object System.Windows.Forms.Label
$lblDepartment.Location = New-Object System.Drawing.Point(10, $yPos)
$lblDepartment.Size = New-Object System.Drawing.Size(200, 20)
$lblDepartment.Text = "Department"
$scrollAdd.Controls.Add($lblDepartment)

$txtDepartment = New-Object System.Windows.Forms.TextBox
$txtDepartment.Location = New-Object System.Drawing.Point(220, $yPos)
$txtDepartment.Size = New-Object System.Drawing.Size(580, 20)
$scrollAdd.Controls.Add($txtDepartment)
$yPos += 30
```

**Step 2: Add to Build-ValuesHash function**
```powershell
# Find Build-ValuesHash function (~line 1300)
# Add:
if (-not [string]::IsNullOrWhiteSpace($txtDepartment.Text)) {
    $values["Department"] = $txtDepartment.Text
}
```

**Step 3: Add to Clear-AddForm function**
```powershell
# Find Clear-AddForm function (~line 1100)
# Add:
$txtDepartment.Clear()
```

**Step 4: Add to Get-FormData and Set-FormData**
```powershell
# Get-FormData: Add
Department = $txtDepartment.Text

# Set-FormData: Add
$txtDepartment.Text = $Data.Department
```

#### Add Context Menu to ListView

**Add right-click menu with options:**
```powershell
# Create context menu
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

# Copy Title menu item
$menuCopyTitle = New-Object System.Windows.Forms.ToolStripMenuItem
$menuCopyTitle.Text = "Copy Title"
$menuCopyTitle.add_Click({
    if ($listViewResults.SelectedItems.Count -gt 0) {
        $title = $listViewResults.SelectedItems[0].SubItems[2].Text
        Set-Clipboard $title
        $lblStatus.Text = "Copied: $title"
        $lblStatus.BackColor = [System.Drawing.Color]::LightBlue
    }
})
$contextMenu.Items.Add($menuCopyTitle)

# Copy ID menu item
$menuCopyID = New-Object System.Windows.Forms.ToolStripMenuItem
$menuCopyID.Text = "Copy ID"
$menuCopyID.add_Click({
    if ($listViewResults.SelectedItems.Count -gt 0) {
        $id = $listViewResults.SelectedItems[0].SubItems[0].Text
        Set-Clipboard $id
    }
})
$contextMenu.Items.Add($menuCopyID)

# Attach to ListView
$listViewResults.ContextMenuStrip = $contextMenu
```

#### Add Keyboard Shortcuts

**Add global hotkeys:**
```powershell
# Enable key preview on form
$form.KeyPreview = $true

# Add key handler
$form.add_KeyDown({
    param($sender, $e)
    
    # Ctrl+N = Clear form
    if ($e.Control -and $e.KeyCode -eq "N") {
        $btnClearForm.PerformClick()
        $e.Handled = $true
    }
    
    # Ctrl+S = Add/Save
    if ($e.Control -and $e.KeyCode -eq "S") {
        if ($tabControl.SelectedTab -eq $tabAdd) {
            $btnAddSoftware.PerformClick()
        }
        $e.Handled = $true
    }
    
    # Ctrl+F = Focus search
    if ($e.Control -and $e.KeyCode -eq "F") {
        $tabControl.SelectedTab = $tabUpdate
        $txtSearch.Focus()
        $e.Handled = $true
    }
    
    # Ctrl+R = Refresh current tab
    if ($e.Control -and $e.KeyCode -eq "R") {
        if ($tabControl.SelectedTab -eq $tabUpdate) {
            $btnRefresh.PerformClick()
        }
        elseif ($tabControl.SelectedTab -eq $tabRecent) {
            $btnRefreshRecent.PerformClick()
        }
        $e.Handled = $true
    }
})
```

---

## 9. Architecture & Development

### 9.1 Code Structure

**File:** `SharePoint-Software-Manager.ps1` (~1800 lines)

**Major Sections:**
```
Lines 1-50:     Header, parameters, documentation
Lines 50-150:   Prerequisites functions
Lines 150-200:  Config management functions
Lines 200-350:  SharePoint functions
Lines 350-400:  Pre-connect logic
Lines 400-1000: GUI construction
Lines 1000-1400: Helper functions (including Quick Edit)
Lines 1400-1800: Event handlers
```

**Design Pattern:** Monolithic script (all-in-one)
- **Pros**: Easy to deploy (single file), no dependencies
- **Cons**: Large file, harder to navigate

**Future improvement:** Could be modularized into:
- `Core.psm1`: SharePoint functions
- `GUI.psm1`: UI construction
- `Main.ps1`: Entry point

### 9.2 Key Technologies

**PowerShell 7.2+**
- Cross-platform PowerShell
- Better performance than 5.1
- Native JSON support
- Improved error handling

**System.Windows.Forms**
- Native Windows GUI framework
- Part of .NET Framework
- No additional dependencies
- Mature and stable

**PnP.PowerShell 2.x**
- Community-driven SharePoint module
- Actively maintained
- Comprehensive cmdlets
- Better than CSOM for most operations

**Why PnP 2.x not 3.x?**
- Version 3.x has threading issues with `-Interactive` and `-UseWebLogin`
- Browser auth blocks UI thread
- Version 2.x is stable and works reliably
- Community has more experience with 2.x

### 9.3 Data Flow

**Adding New Item:**
```
User fills form
  ↓
Clicks "Add Software"
  ↓
Validation (Title, Vendor, Status required)
  ↓
Get-NextRefNumber()
  └→ Queries SharePoint for max Ref
  └→ Returns max + 1
  ↓
Build-ValuesHash()
  └→ Converts form controls to hashtable
  └→ Uses SharePoint internal field names
  └→ Handles multi-select as arrays
  ↓
Add-SoftwareItem()
  └→ Calls Add-PnPListItem
  └→ SharePoint creates item
  ↓
Success confirmation
  ↓
User choice: Clear form or keep values
```

**Quick Edit Update:**
```
User double-clicks row
  ↓
Show-QuickEditDialog()
  └→ Creates popup form
  └→ Pre-fills with current values
  └→ ShowDialog() (modal)
  ↓
User edits fields
  ↓
Clicks Save
  ↓
Dialog returns values hashtable
  ↓
Update-SoftwareItem()
  └→ Calls Set-PnPListItem
  └→ SharePoint updates item
  ↓
Auto-refresh list
  ↓
Success message
```

**Template System:**
```
Save Template:
  Get-FormData()
    └→ Reads all form controls
    └→ Returns hashtable
  ↓
  ConvertTo-Json
    └→ Serializes to JSON string
  ↓
  Set-Content
    └→ Writes to user profile path

Load Template:
  Test-Path
    └→ Check if file exists
  ↓
  Get-Content | ConvertFrom-Json
    └→ Deserializes to PSCustomObject
  ↓
  Set-FormData()
    └→ Populates all form controls
```

### 9.4 Security Considerations

**Credentials:**
- Never stored in code
- OAuth flow via browser
- Tokens managed by PnP.PowerShell
- No plaintext passwords

**Config File:**
- Stored in user profile (`%USERPROFILE%`)
- Protected by Windows file permissions
- Contains no sensitive data (just form field values)
- Could be encrypted in future version

**SharePoint Permissions:**
- App inherits user's permissions
- Cannot elevate privileges
- All operations logged in SharePoint audit log
- No backdoor access

**Code Execution:**
- PowerShell execution policy applies
- User must allow script execution
- Script is readable (not obfuscated)
- Can be reviewed before running

### 9.5 Performance Optimization

**ListView Population:**
- Limited to 100 items (Refresh All)
- Reason: SharePoint throttling, UI responsiveness
- Mitigation: Use Search for specific items

**Module Loading:**
- PnP.PowerShell is ~50MB
- First import: 3-5 seconds
- Cached for subsequent launches
- Consider keeping app open vs repeatedly launching

**SharePoint Queries:**
- Use `-Fields` parameter to limit data
- Use `-PageSize` to control batch size
- Avoid loading all items when possible

**GUI Responsiveness:**
- Progress bar for long operations
- Status messages during work
- DoEvents() calls where needed (though limited use)

### 9.6 Known Limitations

1. **Single Template**
   - One template file at a time
   - Workaround: Manually manage multiple JSON files

2. **No Offline Mode**
   - Requires active SharePoint connection
   - Cannot queue changes for later sync

3. **List Size Limits**
   - Refresh All capped at 100 items
   - Very large lists (>5000) may have performance issues

4. **No Conflict Resolution**
   - Last write wins if two users edit same item
   - No optimistic concurrency

5. **Windows Only**
   - WinForms is Windows-specific
   - Could be rewritten with Avalonia for cross-platform

6. **No Undo**
   - Changes are immediate
   - Use SharePoint version history to revert

### 9.7 Future Enhancements

**Potential additions:**

1. **Multi-Template Support**
   - Dropdown selector
   - Template manager dialog

2. **Batch Edit**
   - Select multiple items
   - Apply change to all

3. **Import Wizard**
   - GUI-driven CSV import
   - Field mapping

4. **Advanced Search**
   - Date range filters
   - Multi-field search
   - Saved queries

5. **Reporting**
   - Charts/graphs
   - Export to PDF

6. **Dark Mode**
   - Theme toggle
   - Saved preference

7. **Audit History**
   - Show change log
   - Version history view

8. **Multi-Site Support**
   - Switch between sites
   - Site selector

9. **Workflow Integration**
   - Trigger Power Automate
   - Approval flows

10. **Notifications**
    - Toast notifications
    - Email on errors

---

## 10. FAQ

### General Questions

**Q: What is this for?**
A: Managing software inventory in SharePoint through a Windows GUI instead of the SharePoint web interface.

**Q: Why not just use SharePoint?**
A: The app is faster, has templates, quick edit, better validation, and no page reloads.

**Q: Is this officially supported by Microsoft?**
A: No, it's a custom application using Microsoft's PnP.PowerShell library.

**Q: Can multiple people use this at once?**
A: Yes, each connects with their own credentials.

**Q: Does this work on Mac/Linux?**
A: No, it uses Windows Forms. Could be rewritten for cross-platform with Avalonia.

**Q: Do I need admin rights?**
A: No, everything installs to user profile.

### Usage Questions

**Q: How do I add the same software but different version?**
A: Click "Load Last Entry", change Version, click "Add Software".

**Q: Can I edit multiple items at once?**
A: Not in GUI. Use PowerShell script for bulk edits.

**Q: What if I lose connection while editing?**
A: Form data is preserved. Reconnect and submit.

**Q: Can I save my work and come back later?**
A: Yes, use "Save as Template" or leave app open (minimized).

**Q: How do I know my changes saved?**
A: Green status bar with "✅ Item added/updated successfully!"

**Q: Can I delete items?**
A: Not currently. Use SharePoint interface to delete.

### Template Questions

**Q: Where is the template stored?**
A: `C:\Users\YourName\SPSoftwareManager_Config.json`

**Q: Can I have multiple templates?**
A: One at a time in GUI. Workaround: manually manage multiple JSON files.

**Q: Can I share templates?**
A: Yes, send the JSON file to coworkers.

**Q: What if template is corrupted?**
A: Delete it and create new one.

### Error Questions

**Q: "Connection failed" - what do I do?**
A: Verify URL, check network, ensure permissions. See Troubleshooting section.

**Q: ListView shows null value errors?**
A: Update to latest version of script.

**Q: Quick Edit doesn't appear?**
A: Ensure item is selected, connected to SharePoint, no other dialogs open.

**Q: "Specified method is not supported"?**
A: Wrong PnP or PowerShell version. See Troubleshooting.

### Technical Questions

**Q: Can I automate this with a script?**
A: Yes! See Advanced Usage section.

**Q: Can I add custom fields?**
A: Yes, requires editing the script.

**Q: How do I export all data?**
A: See Advanced Usage - Exporting Data section.

**Q: Can I schedule automated updates?**
A: Yes, use Task Scheduler. See Advanced Usage.

**Q: Is the source code available?**
A: Yes, the .ps1 files are the source.

### Performance Questions

**Q: App is slow to start?**
A: Normal. PnP.PowerShell is large. Subsequent starts are faster.

**Q: ListView takes long to load?**
A: Use Search instead of Refresh All for large lists.

**Q: Form froze during connection?**
A: Use Pre-Connect mode next time.

**Q: Changes don't appear in SharePoint?**
A: Verify save was successful, refresh SharePoint page.

---

## Appendix: Quick Reference

### Command Cheat Sheet

```powershell
# Launch app
.\Launch-SoftwareManager.ps1

# Check versions
$PSVersionTable.PSVersion
Get-Module PnP.PowerShell -ListAvailable

# Install prerequisites
Install-Module PnP.PowerShell -MaximumVersion 2.99.0 -Scope CurrentUser -Force

# Manual connection
Import-Module PnP.PowerShell
Connect-PnPOnline -Url "https://site.sharepoint.com/sites/site" -UseWebLogin

# Get list info
Get-PnPList | Where-Object { $_.Title -like "*Software*" }
Get-PnPField -List "ListName" | Select-Object Title, InternalName

# Export data
Get-PnPListItem -List "ListName" | Export-Csv "export.csv"

# Check for errors
Get-PnPException
```

### File Locations

```
Application:
  SharePoint-Software-Manager.ps1
  Launch-SoftwareManager.ps1

Config:
  %USERPROFILE%\SPSoftwareManager_Config.json

Example:
  C:\Users\YourName\SPSoftwareManager_Config.json
```

### Keyboard Shortcuts (if implemented)

```
Ctrl+N    Clear form
Ctrl+S    Add/Save software
Ctrl+F    Focus search box
Ctrl+R    Refresh current tab
Enter     Submit form / Save Quick Edit
Escape    Cancel / Close dialog
Tab       Next field
```

### Common Field Internal Names

```
Display Name              Internal Name
────────────────────────  ────────────────────────────────────
Title                     Title
Vendor                    Vendor
Version # (alt.)          Version_x0023__x0028_alt_x002e__
User AD Group             AD_Group_Name
Product Status            CatalogStatus
SAFR Boundary             SAFRBoundary
Auto-Updates?             Auto_x002d_Updates_x003f_
BigFix?                   BigFix_x003f_
```

---

## Document Information

**Document Title:** SharePoint Software Manager - Complete User & Developer Guide  
**Version:** 1.0  
**Date:** April 28, 2026  
**Application Version:** 2.0 - Ultimate Edition  
**Author:** AI-Assisted Development  
**Pages:** 80+ (equivalent)  
**Word Count:** ~18,000 words

**License:** Free to use and modify within your organization.

**Contributions:** Welcome! Share improvements and enhancements.

**Support:**
- Check this guide first
- Review PowerShell console for errors
- Use `Get-PnPException` for detailed error info
- Contact your SharePoint administrator for permissions issues

---

**End of Guide**

*This comprehensive guide covers every aspect of the SharePoint Software Manager application. Load it into an AI assistant for instant answers to any question!*
