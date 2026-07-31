# FRB Packaging Tool Analysis Report

## Purpose

This report documents the current FRB Packaging Tool architecture as implemented in the repository snapshot under E:\AI_playground\FRB-Packaging-Tool. It is written as a handoff document for another machine or technician who needs to understand what the tool does, how the GUI behaves, and how the engine layer is designed.

The tool is a modular PowerShell WinForms application centered on package creation, package update, validation, installation testing, uninstallation testing, network deployment, and validation report capture.

## Executive Summary

FRB Packaging Tool is a technician-facing packaging workstation. The main script builds the GUI, loads the engine modules, and orchestrates package creation and follow-on validation workflows. The design favors a guided packaging experience rather than a thin editor. It auto-detects metadata, recommends install context, populates switches and helper content, manages package folder structure, and can continue into build, test, validation, and deployment steps.

At a high level, the application is split into:

- Main GUI and orchestration in FRB-Packaging-Tool.ps1
- Core support modules under src\Core
- Feature engines under src\Engines
- Validation report generation under ValidationReportEngine
- Package helper and switch generation under SwitchEngine and PythonScraperEngine

## Core User Experience

The application is designed around a linear technician workflow:

1. Launch the tool.
2. Select installation media.
3. Confirm metadata and install context.
4. Review install and uninstall switches.
5. Review or edit custom commands.
6. Create or update the package.
7. Build the package.
8. Run installation testing.
9. Run uninstallation testing.
10. Generate or copy validation documentation.
11. Deploy the package to the network share when enabled.

The tool uses the GUI itself as the source of truth. Existing package data can be reloaded from Startup.pss, and helper sections can be regenerated from engine output.

## Main Script Architecture

The root script, FRB-Packaging-Tool.ps1, is both the application bootstrapper and the GUI controller. It handles:

- Assembly loading
- Configuration loading
- Splash screen startup
- Engine imports
- GUI creation
- Status and process logging
- Package folder detection
- Package helper generation and application
- Packaging workflow orchestration
- Build, test, validation, and deployment transitions

The script also maintains a large set of script-scoped state variables for GUI controls, selected paths, current context, helper job state, process logging, and current package workflow state.

## Configuration and Startup

The application loads configuration from config\app.config.json and falls back to default paths when values are missing. Important runtime settings include:

- Master template path
- Base packaging path
- PowerShell Studio executable path
- Open-in-PowerShell-Studio behavior
- First run completion state
- Deployment defaults

The startup sequence also checks prerequisites and can show a splash screen while engines are imported. Engine import order is explicit and stable.

## Engine Import Order

The main script loads engines in a fixed sequence:

- MetadataEngine
- DetectionEngine
- PythonScraperEngine
- SwitchEngine
- UninstallEngine
- ValidationEngine
- FolderEngine
- ProcessEngine
- BuildEngine
- ScanEngine
- ReportEngine
- InstallTestEngine
- ValidationReportEngine
- PathEngine
- DeploymentEngine
- CustomCommandsEngine

This order reflects the dependency chain used by the GUI and workflow logic.

## GUI Structure

The GUI uses a tabbed WinForms layout with a status bar at the bottom. The form is resizable and built around a modernized but still direct WinForms model.

### Main Controls

The main form contains:

- TabControl for application sections
- Status panel with progress bar and action buttons
- Context-aware status label updates
- Process log output area
- Package helper tab with generated recommendations
- Validation report tab for documentation capture and report generation

### Tab 1: Main Settings

This tab is the control center. It contains package metadata and primary switches.

Sections include:

- Install media selection
- Vendor
- App name
- Edition
- Version
- Install context checkbox
- Uninstall media field
- Install switch field
- Uninstall switch field
- Help package button
- Folder exists indicator
- Packaging folder display

Behavioral notes:

- The Browse button selects EXE or MSI media.
- MetadataEngine attempts to auto-populate vendor, product name, and version.
- DetectionEngine identifies installer type.
- Install context prompt is shown when context detection is available.
- When a matching package folder exists, the tool shows a folder-exists flag and reloads existing package data.

### Tab 2: Custom Installation

This tab contains editable code sections for install-time custom logic.

Sections include:

- Pre-Install Commands
- Custom Install Commands
- Post-Install Commands

Each section is implemented as a collapsible code editor region. The sections auto-expand when content exists.

### Tab 3: Custom Uninstallation

This tab mirrors the installation tab but for uninstall logic.

Sections include:

- Pre-Uninstall Commands
- Custom Uninstall Commands
- Post-Uninstall Commands

The uninstall command areas also support auto-expansion and rehydration from existing Startup.pss files.

### Tab 4: Package Helper

This tab provides guided recommendations. Each helper section supports copy, apply, and feedback actions.

Current helper order:

1. Uninstall Media
2. Install Command-line Switch
3. Uninstall Command-Line Switch
4. Pre-Install Commands
5. Custom Install Commands
6. Post-Install Commands
7. Pre-Uninstall Commands
8. Custom Uninstall Commands
9. Post-Uninstall Commands

The Package Helper tab uses generated section content from SwitchEngine and may also incorporate results from the PythonScraperEngine.

### Tab 5: Globals Assistant

This tab is used to analyze and rewrite Global.ps1-related snippets. It is designed to help technicians translate direct registry or command usage into safer or more standardized helper patterns.

### Tab 6: Process

This tab presents live process logs. It is intended to show the current stage of packaging, build, validation, and deployment. It is also used to communicate warnings, status changes, and workflow results.

## Package Helper Design

The Package Helper flow is one of the most important modern additions in the application.

### Responsibilities

The helper pipeline:

- Evaluates install context
- Builds switch suggestions
- Builds uninstall media suggestions
- Builds custom command suggestions
- Optionally performs web-backed scrape enrichment through PythonScraperEngine
- Sanitizes output so the helper surface stays usable
- Supports applying snippets directly back into the tool

### Background Execution

Package Helper generation is now asynchronous from the GUI perspective:

- A background job is created for helper generation.
- A modeless progress dialog is shown.
- A WinForms timer polls job completion.
- The UI remains responsive while helper generation runs.
- A queued refresh mechanism exists if the technician requests another generation while one is already active.

### Output Sanitization

The helper generation path filters out unwanted noise, including:

- Write-Host
- Write-Output
- Write-Verbose
- Write-Debug
- Write-Warning
- Write-Information
- Write-Progress
- Write-Log

It also removes or blocks undesirable command suggestions such as choco and winget in the helper output path.

### Switch-Only Behavior

The Install Command-line Switch and Uninstall Command-Line Switch boxes are intended to hold switch values, not executable paths. The helper layer now strips or avoids executable-style output so those boxes remain focused on actual switches.

## Start Packaging Workflow

The Start Packaging button triggers the main packaging process. This workflow still performs a long synchronous sequence that includes modal prompts and several update stages.

### What Happens on Start Packaging

The workflow performs the following major stages:

1. Validates required inputs.
2. Ensures packaging folder state is ready.
3. Creates or updates the package folder.
4. Copies the master template.
5. Copies installation media when present.
6. Updates Startup.pss.
7. Inserts custom commands.
8. Verifies the project file.
9. Starts the build/test/deploy workflow.

### Workflow Behavior

The package creation logic uses:

- FolderEngine for folder structure and template copy operations
- CustomCommandsEngine for Startup.pss insertion
- BuildEngine for project compilation
- InstallTestEngine for install and uninstall validation
- ValidationReportEngine for documentation capture
- DeploymentEngine for copying to the network share

The build/test/deploy chain is currently auto-started after package creation in the main workflow path.

## Build, Test, and Deploy Pipeline

The Build-Test-Deploy workflow is implemented in Start-BuildTestDeployWorkflow.

### Build Stage

The workflow locates the project file and ensures PSBuild.exe is available. It then builds Install.exe through PowerShell Studio tooling.

### Context Handling

The workflow adapts based on install context:

- User context updates Startup.pss and .psbuild for non-elevated behavior.
- System context updates Startup.pss and .psbuild for elevated behavior.

### Installation Testing

After a successful build, the tool searches for Install.exe and launches install testing.

The installation testing loop:

- Launches the package
- Records diagnostics
- Lets the technician confirm success or request changes
- Restores GUI state if the workflow needs to loop back

### Uninstallation Testing

After install validation, the workflow optionally proceeds into uninstall testing.

### Validation Documentation

If the installation is confirmed, the tool invokes the validation report capture workflow and stores the generated report in the package docs folder.

### Deployment

If network deployment is enabled, the workflow verifies required validation artifacts and copies the package to the configured share.

## Engine Design Summary

### MetadataEngine

Purpose:

- Extract installer metadata from media files

Public surface:

- Get-InstallerMetadata

### DetectionEngine

Purpose:

- Detect installer technology and recommend install context

Public surface:

- Get-InstallerType
- Get-InstallContextRecommendation

### FolderEngine

Purpose:

- Create package folder structure
- Copy template files
- Copy installer media into the package

Public surface:

- New-PackagingFolderStructure
- Copy-TemplateFiles
- Copy-InstallerToPackage

### SwitchEngine

Purpose:

- Generate install and uninstall switches
- Build package helper sections
- Supply helper suggestions and web-backed enrichment

Public surface:

- Get-InstallSwitches
- Get-UninstallSwitches
- Get-SwitchesForInstaller
- Get-PackageHelpSections
- Get-WrapperAwareSectionSuggestions
- Get-WebSilentSwitchSuggestions

SwitchEngine design notes:

- It includes local switch templates for common installer technologies.
- It uses web lookup helpers for enrichment when available.
- It generates structured helper sections, including install context, uninstall media, command-line switch suggestions, and custom command guidance.

### PythonScraperEngine

Purpose:

- Run co-located Python Playwright scraping code for helper enrichment.

Public surface:

- Test-PythonScraperPrerequisites
- Invoke-PythonScraperForPackageHelper

Design notes:

- The PowerShell module launches scraper.py directly.
- Communication uses JSON through standard input/output.
- The scraper uses Playwright and web search to gather helper candidates.

### UninstallEngine

Purpose:

- Suggest likely uninstall executable names and installer-specific uninstall patterns

Public surface:

- Get-UninstallExecutableOptions
- Get-UninstallOptionsForInstaller

### ValidationEngine

Purpose:

- Validate user input and system requirements

Public surface:

- Test-SoftwareInputs
- Test-InstallerFile
- Test-OutputPath
- Test-FolderNameValid

### BuildEngine

Purpose:

- Compile the PowerShell Studio project into the install executable

Public surface:

- Invoke-ProjectBuild
- Test-SAPIENBuildAvailable
- Find-ProjectFile

### ScanEngine

Purpose:

- Read installed software from registry-based sources

Public surface:

- Get-InstalledSoftwareData

### ReportEngine

Purpose:

- Generate HTML reports from scan or validation data

Public surface:

- New-HTMLValidationReport
- New-HTMLLeftoverReport
- New-HTMLUninstallReport

### InstallTestEngine

Purpose:

- Run installation and uninstallation test cycles

Public surface:

- Start-InstallationTest
- Start-UninstallationTest
- Get-UninstallLeftovers
- Remove-UninstallLeftovers
- Show-CompletionMessage

### ValidationReportEngine

Purpose:

- Capture documentation for installation validation and generate the final report

Public surface:

- Start-ValidationReportCapture

This engine contains its own submodules for capture, UI, session management, documentation generation, installation detection, and vendor documentation lookup.

### DeploymentEngine

Purpose:

- Copy completed packages to a network share

Public surface:

- Test-NetworkShareAccess
- Copy-PackageToNetworkShare
- Test-PackageCopyIntegrity
- Get-PackageFolderSize
- New-PackageBackup

### WorkflowEngine

Purpose:

- Orchestrate the package creation and testing workflow at a higher level

Public surface:

- Initialize-Workflow
- Start-TestingWorkflow
- Get-WorkflowState
- Reset-Workflow

### ProcessEngine

Purpose:

- Suggest processes that should be closed before installation

Public surface:

- Get-RequiredProcessesToClose

### AuthenticationModule and GitLabAuthEngine

Purpose:

- Handle prerequisite installation and GitLab authentication support

These modules support GitLab/Okta secured workflows and Playwright prerequisite handling.

### WebSearchEngine

Purpose:

- Query online sources for installer switch and uninstall data

Public surface:

- Get-InstallSwitchesFromWeb
- Get-UninstallExecutableFromWeb
- Test-WebConnectivity

## Core Modules

### ConfigurationManager

Purpose:

- Load and merge configuration files
- Read and validate values through dot-notation lookups
- Update configuration values

Public surface:

- Get-AppConfiguration
- Get-ConfigValue
- Test-AppConfiguration
- Set-ConfigValue

### PackageManager

Purpose:

- Orchestrate package creation at a high level

Public surface:

- New-FRBPackage

PackageManager accepts the package metadata, installer media, switches, uninstall executable, config, and an optional progress callback. It performs validation, folder creation or update, installer copy, Startup.pss updates, and project verification.

## Validation Report Engine Structure

ValidationReportEngine is itself a mini architecture. It contains:

- CaptureEngine
- DocumentationSessionEngine
- DocumentationUIEngine
- DocumentGeneratorEngine
- InstallationDetectorEngine
- SessionManager
- SnagitController
- ValidationDocGenerator
- VendorDocumentationEngine

This sub-architecture is used for producing the final installation validation report in a package docs folder.

## Data Flow Summary

The typical data flow looks like this:

1. Main Settings collects metadata and installer media.
2. Detection and metadata engines infer installer type and context.
3. SwitchEngine and PythonScraperEngine populate helper recommendations.
4. FolderEngine creates or updates the package folder.
5. CustomCommandsEngine injects technician-authored command blocks.
6. BuildEngine compiles the project.
7. InstallTestEngine launches install verification.
8. ValidationReportEngine captures or generates the validation report.
9. DeploymentEngine copies the package to the network share when enabled.

## Current Operational Characteristics

The tool currently has the following notable characteristics:

- Uses a modular engine architecture
- Keeps the GUI as the primary technician interface
- Auto-populates metadata and context where possible
- Rehydrates custom command content from existing package data
- Uses a live process tab for status and logging
- Keeps Package Helper generation responsive with background job polling
- Applies helper suggestions back into the GUI
- Supports validation documentation capture as part of the workflow
- Supports optional network deployment after package completion

## Design Strengths

- Clear separation between GUI orchestration and domain engines
- Strong reuse of package data through Startup.pss rehydration
- Guided technician workflow with visible status feedback
- Modular helper generation with pluggable scraping support
- Structured validation report generation with a dedicated engine tree

## Practical Risks and Notes

- The Start Packaging workflow remains a long synchronous chain and can block the UI during the full create/build/test/deploy run.
- The Package Helper flow is backgrounded at the job level, but it still relies on PowerShell job and timer coordination.
- The repository contains many backup and temporary engine files that should not be confused with active modules.
- Some module headers and comments still carry legacy wording from earlier versions.

## Recommended Handoff Notes

If another machine is going to continue work on this project, the most important files to review first are:

- FRB-Packaging-Tool.ps1
- src\Engines\SwitchEngine\SwitchEngine.psm1
- src\Engines\PythonScraperEngine\PythonScraperEngine.psm1
- src\Engines\CustomCommandsEngine\CustomCommandsEngine.psm1
- src\Engines\BuildEngine\BuildEngine.psm1
- src\Engines\InstallTestEngine\InstallTestEngine.psm1
- src\Engines\ValidationReportEngine\ValidationReportEngine.psm1

The live process log and Package Helper output path are the main places to observe runtime behavior.

## Conclusion

FRB Packaging Tool is not a simple packaging form. It is a guided packaging workstation with modular engine boundaries, live workflow feedback, helper generation, validation documentation, and deployment support. The strongest architectural pattern in the current codebase is the split between the GUI shell and the individual feature engines. The most important operational behavior is that the GUI serves as the source of truth, with package data flowing back into the tool from existing Startup.pss content and helper generation outputs.

For a second machine, this report should provide enough detail to understand the system at the feature level, the GUI level, and the engine level without needing to reverse-engineer the code from scratch.