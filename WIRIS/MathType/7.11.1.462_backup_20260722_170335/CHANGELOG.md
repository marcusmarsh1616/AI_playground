<!-- INTERNAL FR/OFFICIAL USE // FRSONLY -->

# Changelog - PhoenixFrame Packaging Template

All notable changes to this packaging template will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.1.1] - 2026-07-21

**![Offline](https://img.shields.io/badge/Internal_FR/Official_Use-00475b)**

### Fixed
- **Critical Bug Fix** – Corrected variable reference in Startup.pss from `$appContext.ToLower` to `$installContext` on line 268
  - This bug would have caused runtime errors when checking user vs system installation context
  - Prevents null reference exceptions during context detection
- **Code Organization** – Moved `$version` variable declaration from function start to proper VARIABLE DECLARATION section
  - Improves code readability and maintainability
  - Aligns with PowerShell best practices

### Changed
- **Project State File** – Minor reordering of open files in FRB Installer.psprojs (cosmetic)

### Technical Details
- **Merge Request:** #30
- **Merge Commit:** `7130df824d83bb3e23408d6ff640cd91f0ff0803`
- **Feature Branch:** `fix/installContext-variable`
- **Files Changed:** 2 files (3 insertions, 4 deletions)
- **Impact:** Bug fix - prevents runtime errors in installation context checking
- **Testing:** Verified variable reference is correct for both user and system context installations

### Migration Notes
- No action required for existing deployments
- Detection scripts remain unchanged
- No configuration changes needed

---

## [2.1.0] - 2026-07-08

**![Offline](https://img.shields.io/badge/Internal_FR/Official_Use-00475b)**

### Added
- **IntuneWin Exclusion** � Added `*.intunewin` to `.gitignore` to prevent generated packages from being committed
- **Zero-Config Templates** � Added multiple zero-config JSON templates for browser and multi-install scenarios
  - `Dev/zeroConfig_Browsers_EXAMPLE.json`
  - `Dev/zeroconfig-template-mulitpleInstalls.json`
  - `Dev/zeroconfig-template-singleInstalls.json`
- **PhoenixFrame Detection Guide** � Comprehensive documentation in `PhoenixFrame-DetectionScript-Guide.md`
- **Enhanced Detection Template** � New `PhoenixFrame-DetectionScript-Template.ps1` with improved version checking
- **README Template** � Added `README_Template.md` for standardized documentation
- **CHANGELOG Template** � Added `CHANGELOG_Template.md` for consistent change tracking
- **Template Update Summary** � Created `TEMPLATE_UPDATE_SUMMARY.md` documenting v2.0.0 changes

### Changed
- **Continue CLI** � Updated line 60 with improved CLI handling
- **Function Organization** � Moved `Start-TryParse` function to Globals.ps1 for better code organization
- **Startup Script** � Enhanced `Startup.pss` with additional error handling and validation
- **Globals.ps1** � Significantly expanded with new utility functions and improved error handling
- **README Structure** � Reorganized and expanded documentation with user-agnostic paths

### Improved
- **Code Maintainability** � Better function organization and separation of concerns
- **Documentation Quality** � More comprehensive guides and templates for packagers
- **Template Flexibility** � Enhanced zero-config support for various installation scenarios
- **Detection Script Standards** � Aligned with PhoenixFrame best practices

### Removed
- **Legacy Detection Script** � Removed `Template_Detect_R1.ps1` (replaced with PhoenixFrame template)

### Technical Details
- **Merge Commit:** `1ada6c6`
- **Branch:** json_merge ? master
- **Files Changed:** 16 files (+1741 lines, -335 lines)
- **Reference SID:** f60bcd2e-33fe-4eba-b61a-d37b02c8854b

---
## [2.0.0] - 2026-06-18

**![Offline](https://img.shields.io/badge/Internal_FR/Official_Use-00475b)**

# [{Application Name} - {version}]
![Offline](https://img.shields.io/badge/TEAAS-1234-blue)

### Added
- **PhoenixFrame Integration** � Full compatibility with PhoenixFrame v0.3.0+
- **JSON Metadata Template** � Standardized Intune metadata schema in Docs/metadata_template.json
- **Detection Script Standardization** � Updated templates with PhoenixFrame-compatible structure
- **Comprehensive README** � Complete template documentation with usage instructions
- **Automated Discovery Support** � Project structure optimized for PhoenixFrame auto-detection

### Changed
- **Detection Script Template** � Now uses PhoenixFrame-standard format with -Test mode
- **Documentation Structure** � Reorganized Docs/ folder for better clarity
- **Project Organization** � Aligned with PhoenixFrame discovery expectations

### Improved
- **Template Comments** � Added inline guidance for common customizations
- **Error Handling** � Enhanced Globals.ps1 with better exit code interpretation
- **Build Process** � PostCompile.ps1 updated for PhoenixFrame workflow

---

## [1.5.0] - 2025-09-15

### Added
- **ServiceUI Integration** � Added ServiceUI.exe for user-context elevation
- **EUS Branding Update** � Refreshed national_it_transparent.ico
- **Progress Dialogs** � New EUSInstallProgress.psf with branded styling

### Changed
- **UI Components** � Updated all .psf forms to match EUS design standards
- **Installation Messaging** � Improved user-facing text for clarity

---

## [1.0.0] - 2024-06-01

### Initial Release
- **PowerShell Studio Project Template** � Base .psproj structure
- **Globals.ps1 Framework** � Enterprise installation functions
- **Standard UI Forms** � CloseOpenApps, InstallCompleted, etc.
- **Documentation Templates** � Validation guide, UAT guide
- **Detection Script Base** � Initial detection method template

---

## Template Usage Notes

### For Packagers

When creating a new package from this template:

1. **Copy CHANGELOG Structure** � Use this format for your app-specific changelog
2. **Document All Changes** � Add entries for each packaging iteration
3. **Version Appropriately** � Follow semver (Major.Minor.Patch)
4. **Include Dates** � Always use YYYY-MM-DD format

### Version Guidelines

- **Major (X.0.0)** � Breaking changes, new installation method, framework migration
- **Minor (0.X.0)** � New features, dependency updates, non-breaking changes
- **Patch (0.0.X)** � Bug fixes, detection script fixes, documentation updates

### Example App-Specific Entry

```markdown
## [1.2.1] - 2026-06-20

### Fixed
- Detection script now correctly identifies build number variants
- Resolved silent install parameter issue with /norestart flag

### Changed
- Updated MSI from version 1.2.0 to 1.2.1 (security patch)
- Modified Startup.pss to check disk space before installation

### Added
- Pre-install validation for required .NET Framework version
```

---

## Template Version History

**Maintained by:** EUS Packaging Team  
**Repository:** https://gitlab.prod.nit-cicd.awscfs.frb.pvt  
**Support:** Open ServiceNow incident for packaging support

---

**End of CHANGELOG**
