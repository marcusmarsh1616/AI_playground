# Application Detection Handoff

## Purpose
This workflow is designed to help a technician or another machine discover, test, classify, and improve About/help detection logic for installed Windows applications.

## What the workflow does
1. Enumerates installed GUI applications from the Windows uninstall registry.
2. Filters the list to likely desktop applications.
3. Attempts to launch each application.
4. Runs the existing About/help detection logic against the launched process.
5. Captures whether the app:
   - exposes a Help/About entry,
   - uses a classic Win32 menu,
   - uses a UI Automation menu,
   - uses an Electron/Chromium-style menu,
   - or uses a custom modal About dialog.
6. Records a difference class and the next action to make the detector more robust.
7. Writes JSON and CSV outputs for review.

## Files
- [Installation_Validation_Report/PowerShell/Analyze-AppDetectionMatrix.ps1](Installation_Validation_Report/PowerShell/Analyze-AppDetectionMatrix.ps1) — analysis runner
- [Installation_Validation_Report/PowerShell/Modules/AboutDialogAutomation.psm1](Installation_Validation_Report/PowerShell/Modules/AboutDialogAutomation.psm1) — detection logic
- [Installation_Validation_Report/PowerShell/Invoke-AboutDialogAutomation.ps1](Installation_Validation_Report/PowerShell/Invoke-AboutDialogAutomation.ps1) — wrapper entry point

## How to run it
From the repository root, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Installation_Validation_Report\PowerShell\Analyze-AppDetectionMatrix.ps1
```

Optional parameters:
- `-MaxApps 200` to limit the number of apps tested.
- `-SkipLaunch` to skip launching apps and only enumerate them.
- `-IncludeSystemApps` to broaden the app list (not recommended for normal runs).

## Expected outputs
The script writes:
- JSON summary: `Installation_Validation_Report/Output/AppDetectionAnalysis/app-detection-analysis.json`
- CSV results: `Installation_Validation_Report/Output/AppDetectionAnalysis/app-detection-analysis.csv`
- Skipped entries: `Installation_Validation_Report/Output/AppDetectionAnalysis/app-detection-skipped.csv`

## What to look for in the results
The analysis produces a `DifferenceClass` and `NextAction` for each app.

### Common patterns already understood
- Classic Win32 apps: use Win32 menus and `WM_COMMAND`
- WPF apps: may expose menus as UIA `Menu` rather than `MenuBar`
- Electron apps: may expose an application menu and a custom in-app About dialog
- Some apps have a Help menu but no About entry at all

## How to improve the detector
When a result comes back with a difference class, use the `NextAction` guidance to add a new branch to the detection logic.

### Recommended rule additions
1. Keep the existing menu-walk strategy as the default path.
2. For apps with no menu bar, inspect UIA Menu/MenuItem descendants.
3. For apps with a Help menu but no About entry, inspect submenu labels for alternate terms such as:
   - About App
   - Version
   - Info
   - License
4. For apps that invoke a menu command but show no dialog, inspect the window tree for a modal dialog or in-app popup.
5. For Electron apps, inspect the main window descendants for an About dialog and close it using the dialog's button if `WindowPattern.Close()` fails.

## Long-term goal
The goal is to reach a very high coverage rate of installed Windows software so that technicians need to intervene only for edge cases rather than common apps.
