# FRB Packaging Tool Analysis Report

## Purpose

This report is an updated handoff document for the current FRB Packaging Tool implementation in E:\AI_playground\FRB-Packaging-Tool. It is meant for another device or technician who needs to understand the current behavior of the tool, how the GUI is wired, and what changed since the previous report was written.

The tool is a modular PowerShell WinForms application centered on package creation, package update, validation, install and uninstall testing, network deployment, live process logging, troubleshooting, and validation report capture.

## Executive Summary

FRB Packaging Tool is a technician-facing packaging workstation. The main script builds the GUI, loads the engine modules, and orchestrates package creation and follow-on validation workflows. The design favors a guided packaging experience rather than a thin editor. It auto-detects metadata, recommends install context, populates switches and helper content, manages package folder structure, and can continue into build, test, validation, troubleshooting, and deployment steps.

The biggest changes since the last report are:

- Validation report Section 1 now uses deterministic scrape-only content with an exact no-data fallback.
- Validation report generation now writes live progress and completion messages into the process log.
- The validation report engine now resolves the Python runtime and the research script path before launching Playwright research.
- The Python Playwright research helper now falls back across msedge and chromium browser launch paths.
- The old Package Helper surface was replaced with a Troubleshooting tab.
- The Troubleshooting tab now scans both logs and current package code to suggest fixes.
- Native PowerShell guidance is now surfaced as troubleshooting advice, not only as general helper text.

At a high level, the application is split into:

- Main GUI and orchestration in FRB-Packaging-Tool.ps1
- Core support modules under src\Core
- Feature engines under src\Engines
- Validation report generation under ValidationReportEngine
- Package helper and switch generation under SwitchEngine and PythonScraperEngine
- Validation requirements research under Installation_Validation_Report\Python

## Current User Workflow

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
11. Review troubleshooting output and suggested fixes.
12. Deploy the package to the network share when enabled.

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
- Troubleshooting analysis
- Packaging workflow orchestration
- Build, test, validation, and deployment transitions

The script also maintains a large set of script-scoped state variables for GUI controls, selected paths, current context, helper job state, process logging, and current package workflow state.

### Logging and Process Visibility

The main script now includes a logged process wrapper, `Invoke-LoggedStartProcess`, so GUI-triggered child processes can be launched with consistent logging, stdout and stderr capture, and exit-code visibility. That wrapper is used in the current validation-report flow and is also available for other process launches.

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

The GUI uses a tabbed WinForms layout with a status bar at the bottom. The form is resizable and built around a direct WinForms model.

### Main Controls

The main form contains:

- TabControl for application sections
- Status panel with progress bar and action buttons
- Context-aware status label updates
- Process log output area
- Troubleshooting tab with live log and code review
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

### Tab 4: Troubleshooting

This tab replaced the older helper-focused surface. It now serves as a live log review and suggested-fix panel.

The troubleshooting workflow now does two things at once:

- Reads the active process, error, transcript, and logs folder output.
- Inspects the current package code for manual PowerShell patterns that deserve guard rails or wrapper-aligned recommendations.

The scan button now says Scan Logs + Code, which matches the current behavior.

The tab produces three outputs:

- Raw log summary text
- Findings extracted from recent log lines
- Suggested fixes that combine log evidence with code-aware guidance

### Tab 5: Globals Assistant

This tab analyzes and rewrites Global.ps1-related snippets. It helps technicians translate direct registry or command usage into safer or more standardized helper patterns.

### Live Process Tab

The process tab presents live process logs. It is intended to show the current stage of packaging, build, validation, troubleshooting, and deployment. It is also used to communicate warnings, status changes, and workflow results.

## Troubleshooting Design

The troubleshooting feature is now more than a log reader. It combines runtime evidence with code-shape guidance.

### Log Review

The analyzer scans:

- Current process log files
- Error log files
- Transcript output
- Any log-like files in the local logs folders

It extracts lines that contain common failure signals such as errors, exit code failures, exceptions, launch failures, and missing output conditions.

### Code-Aware Suggestions

The analyzer now inspects the current package code and surfaces advice based on the code patterns it finds. The guidance currently looks for:

- Start-Process usage
- Stop-Process usage
- Remove-Item usage
- Test-Path and Get-ChildItem checks
- Write-Log or Write-Verbose patterns
- Execute-Process and Execute-MSI wrapper usage

This means the troubleshooting tab can recommend concrete fixes such as adding -Wait and -PassThru, capturing stdout and stderr, checking path existence before deletion, and preferring wrapper cmdlets when they already provide standardized logging.

### Native PowerShell Guidance

The tool now explicitly surfaces manual PowerShell guard-rail guidance instead of only recommending wrapper substitutions. That was added so technician notes can suggest safe native usage patterns across the package startup scripts, not just around Start-Process.

## Validation Report Workflow

Validation report generation is one of the biggest changed areas in the current snapshot.

### What the Validation Report Now Does

The validation report flow now uses a stricter and more deterministic data path for Section 1 content. The vendor documentation engine no longer fills the report with generic prose or source chatter. It focuses on actual scraped content and falls back to the exact message Nothing to Report or Found. when a section has no valid data.

### Live Process Logging

The validation report UI now writes progress into the live process log so the technician can see when the report starts, completes, or fails.

This makes the report creation process visible in the same logging stream as the rest of the packaging workflow.

### Validation Report Runtime Selection

The vendor documentation engine now resolves the Python runtime before launching Playwright research. The runtime discovery process checks:

- Configured interpreter paths
- Local repo-specific virtual environments
- python
- py -3
- python3

If none of those can import Playwright, the report gives a clear availability failure message instead of failing silently or assuming python is present.

### Browser Launch Fallback

The Python research module now tries to launch Playwright with the msedge browser channel first and falls back to chromium if that fails. That makes validation report generation more robust across workstations where the browser channel may differ.

## Validation Report Engine

The ValidationReportEngine now coordinates the documentation UI, log reporting, and vendor documentation lookup more cleanly.

### DocumentationUIEngine.psm1

This module coordinates the validation report UI and workflow. Its current responsibilities include:

- Emitting live process log messages for report start, completion, and failure
- Launching the installation details helper through the logged process path
- Driving Section 1 vendor documentation collection

### VendorDocumentationEngine.psm1

This module performs the vendor documentation deep crawl for Section 1 validation report content.

The current behavior is:

- Normalize application and vendor tokens
- Score and filter relevant sources
- Crawl real documentation pages
- Convert HTML to text
- Reject noise snippets and footer chatter
- Return only actual scraped content
- Use the exact fallback message Nothing to Report or Found. when no usable content is discovered

The latest additions also include:

- Python runtime resolution for Playwright execution
- Better error reporting when the research script or configuration file is missing
- More specific runtime and process failure messages

### Installation_Validation_Report\Python\research_requirements.py

This Python module performs the Playwright-backed requirements research used by validation report content.

The current behavior is:

- Check cache before doing work
- Use configured source mappings when available
- Fall back to generic search strategies when not configured
- Launch Playwright with msedge if possible, then chromium if necessary
- Fall back to deterministic offline content when the research result is empty or incomplete
- Cache successful results for repeatability

## Validation Report Content Rules

The report content rules were tightened so the output stays useful:

- Section 1 is based on actual scrape output, not source labels or descriptive filler.
- Status prose and extra narration are filtered out when they are not part of the scraped documentation itself.
- If a section has no meaningful data, the report uses the exact fallback message instead of inventing text.
- The report is now more predictable for technicians who need to compare one run against another.

## Package Helper and Switch Generation

The helper pipeline still exists, but its role is narrower and more focused now.

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

Package helper generation remains asynchronous from the GUI perspective:

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

The Install Command-line Switch and Uninstall Command-Line Switch boxes are intended to hold switch values, not executable paths. The helper layer strips or avoids executable-style output so those boxes remain focused on actual switches.

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

After install validation, the tool optionally proceeds into uninstall testing.

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
- Keeps helper generation responsive with background job polling
- Uses a Troubleshooting tab to scan logs and current code for suggested fixes
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
- The helper flow is backgrounded at the job level, but it still relies on PowerShell job and timer coordination.
- The Troubleshooting tab depends on current log availability and the current package code surface, so it is only as useful as the data it can inspect.
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

The live process log and Troubleshooting tab are the main places to observe runtime behavior.

## Conclusion

FRB Packaging Tool is not a simple packaging form. It is a guided packaging workstation with modular engine boundaries, live workflow feedback, helper generation, validation documentation, troubleshooting support, and deployment support. The strongest architectural pattern in the current codebase is the split between the GUI shell and the individual feature engines. The most important operational behavior is that the GUI serves as the source of truth, with package data flowing back into the tool from existing Startup.pss content, helper generation outputs, and live log/code review output.

For a second machine, this report should provide enough detail to understand the system at the feature level, the GUI level, and the engine level without needing to reverse-engineer the code from scratch.