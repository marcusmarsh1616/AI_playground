<!-- INTERNAL FR/OFFICIAL USE // FRSONLY -->

# PhoenixFrame Detection Script - Usage Guide

**Version:** 1.0.0  
**Last Updated:** 2026-06-23  
**Organization:** NIT EaaS Packaging Team  
**Template:** PhoenixFrame-DetectionScript-Template.ps1

---

## Quick Start

### 1. Copy Template
Copy `PhoenixFrame-DetectionScript-Template.ps1` to your project's `Docs/` folder.

### 2. Rename File
```
RITM{NUMBER}_{AppName}_Detect_R1.ps1
Example: RITM1078964_IntelliJIDEA_Detect_R1.ps1
```

### 3. Replace Placeholders

| Placeholder | Example |
|-------------|---------|
| {CREATION_DATE} | 2026-06-23 14:30:00 |
| {RITM} | RITM1078964 |
| {APP_NAME} | IntelliJIDEA |
| {APPLICATION_DISPLAY_NAME} | IntelliJ IDEA |
| {TARGET_VERSION} | 2026.1.3 |
| {VENDOR_NAME} | JetBrains |

### 4. Configure Detection

```powershell
# Set options
$useRegex = $false              # Use regex matching?
$installContext = 'System'      # System or User?

# Define detection
$infoHash = @{
    'Adobe Acrobat DC' = '24.1.0'
}
```

### 5. Test

```powershell
.\RITM1234567_AdobeAcrobat_Detect_R1.ps1 -Test
```

---

## Configuration Options

### $useRegex

| Value | Use Case |
|-------|----------|
| $false | Exact name matching |
| $true | Pattern matching with regex |

### $installContext

| Value | Registry | Use Case |
|-------|----------|----------|
| 'System' | HKLM | System-wide installs |
| 'User' | HKCU | Per-user installs |

---

## Common Scenarios

### Scenario 1: Standard System Install
```powershell
$useRegex = $false
$installContext = 'System'
$infoHash = @{ 'Adobe Acrobat DC' = '24.1.0' }
```

### Scenario 2: User Context Install
```powershell
$useRegex = $false
$installContext = 'User'
$infoHash = @{ 'IntelliJ IDEA' = '2026.1.3' }
```

### Scenario 3: Regex Pattern Matching
```powershell
$useRegex = $true
$installContext = 'System'
$infoHash = @{ '^Microsoft Visual Studio\b' = '17.8.0' }
```

### Scenario 4: File-Based Detection
```powershell
$useRegex = $false
$installContext = 'System'
$infoHash = @{ 'C:\ProgramData\MyApp\app.exe' = '1.0.0' }
```

### Scenario 5: Multiple Applications
```powershell
$useRegex = $false
$installContext = 'System'
$infoHash = @{
    'Python 3.11' = '3.11.0'
    'Git' = '2.43.0'
    'Visual Studio Code' = '1.85.0'
}
```

---

## Testing

### Test Mode
```powershell
.\RITM1234567_App_Detect_R1.ps1 -Test
```

### Expected Output
```
========================================
  DETECTION METHOD TEST RESULTS
========================================

Search Pattern: Adobe Acrobat DC
Target Version: 24.1.0 (minimum required)
Context: System
Regex Enabled: False

[FOUND] 1 application(s) found:

Application: Adobe Acrobat DC
  Installed Version: 24.2.0
  Target Version:    24.1.0
  Comparison:        PASS (>=)
  Status:            [PASS]

[DETECTION RESULT] Would return: DETECTED (exit 0)
========================================
```

---

## Troubleshooting

### Detection Always Fails

1. Run in Test Mode
2. Check registry manually:
```powershell
# System
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | 
    Where-Object DisplayName -like "*AppName*"

# User
Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | 
    Where-Object DisplayName -like "*AppName*"
```
3. Verify DisplayName matches exactly
4. Check install context (System vs User)

### Version Mismatch

- Check actual DisplayVersion in registry
- Use exact format from DisplayVersion
- Switch to file-based detection if needed

### Regex Not Matching

- Test regex at https://regex101.com
- Escape special characters
- Use `\b` for word boundaries

---

## Best Practices

1. **Always test before deployment**
2. **Use descriptive filenames** (RITM number + app name)
3. **Document custom logic** with comments
4. **Keep template structure** intact
5. **Use minimum version** (not exact version)
6. **Commit to Git** with descriptive message
7. **Update JSON metadata** with script name

---

## Quick Reference

### Registry Paths

**System Context:**
- HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall
- HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall

**User Context:**
- HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall
- HKCU:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall

### Test Commands

```powershell
# Test detection
.\Script_Detect_R1.ps1 -Test

# Check registry
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | 
    Where-Object DisplayName -eq "AppName" | 
    Select-Object DisplayName, DisplayVersion
```

---

For complete documentation, examples, and advanced scenarios, see the full PhoenixFrame documentation.

**Classification:** INTERNAL FR/OFFICIAL USE // FRSONLY
