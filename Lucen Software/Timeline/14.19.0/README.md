<!-- INTERNAL FR/OFFICIAL USE // FRSONLY -->

**![Offline](https://img.shields.io/badge/Internal_FR/Official_Use-00475b)**

# PhoenixFrame Packaging Template

![Template](https://img.shields.io/badge/Template-Project-blue)
![Version](https://img.shields.io/badge/Version-2.1.1-green)
![Framework](https://img.shields.io/badge/PhoenixFrame-Compatible-orange)

> **This is the master template project for all Federal Reserve Bank Intune application packaging projects.**

`Table of Contents`
[TOC]

---

## About This Template

This project serves as the **standardized template** for creating Microsoft Intune application deployment packages at the Federal Reserve Bank. All packaging projects should be cloned from this template to ensure consistency, compliance, and compatibility with the PhoenixFrame packaging automation framework.

### What's Included

- **PowerShell Studio Project Structure** — Pre-configured .psproj files and build settings
- **Standard Installation Framework** — Globals.ps1, ServiceUI.exe, and EUS-branded UI components
- **Detection Script Templates** — PhoenixFrame-compatible detection method templates
- **Documentation Templates** — README, CHANGELOG, validation guides, and UAT documentation
- **JSON Metadata Schema** — Standardized Intune metadata structure for PhoenixFrame automation
- **Source File Organization** — Pre-structured _SourceFiles directory with custom forms and progress dialogs

---

## How to Use This Template

### 1. Clone the Template

```powershell
# Navigate to your working directory
cd <YourWorkingDirectory>

# Clone this template project
Copy-Item -Path ".\PackagingTemplate" -Destination ".\YourAppName" -Recurse

# Rename the project directory to match your application
Rename-Item -Path ".\YourAppName" -NewName "ApplicationName-Version"
```

### 2. Customize Required Files

**Update these files immediately:**

1. **README.md** — Replace template content with your application details
2. **CHANGELOG.md** — Document your packaging changes
3. **Startup.pss** — Configure installation logic
4. **Detection Script** — Rename and customize __Detect_R1.ps1
5. **Docs/metadata_template.json** — Fill in application metadata

### 3. Package for Intune

Use PhoenixFrame and Continue CLI for automated packaging:

```powershell
cd <YourWorkingDirectory>\phoenixframe
.\phoenixframe.ps1
```

---

## PhoenixFrame Integration

This template is designed for seamless integration with PhoenixFrame automation.

### Automated Operations

- **create_metadata** — Auto-extracts MSI properties and generates JSON
- **create_intunewin** — Creates .intunewin package
- **transfer_package** — Copies to PkgXfer network share
- **publish_package** — Uploads to Azure Blob Storage

---

## Template Versioning

**Current Template Version:** 2.1.1  
**Last Updated:** 2026-07-21  
**Maintained By:** EUS Packaging Team  
**Framework Compatibility:** PhoenixFrame v0.3.0+

### Recent Updates

**v2.1.1 (2026-07-21)** — Critical bug fix
- Fixed variable reference error in Startup.pss (`$appContext` → `$installContext`)
- Improved code organization and maintainability
- See [CHANGELOG.md](CHANGELOG.md) for complete details

---

## Contact & Support

**Template Maintainers:** EUS Packaging Team  
**GitLab:** https://gitlab.prod.nit-cicd.awscfs.frb.pvt

---

**End of Template README**
