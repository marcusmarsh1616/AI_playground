# FRB Packaging Tool - Architecture and Flow Analysis

Date: 2026-07-24  
Analyst: GitHub Copilot (GPT-5.3-Codex)

## Scope and Constraints

- This document analyzes runtime behavior of the tool in:
  - FRB-Packaging-Tool.ps1
  - src/Engines/*
  - config/app.config.json
- Master Template is treated as read-only and out of modification scope.
- GitLab/Okta download behavior is treated as deprecated per direction.

## Executive Summary

The FRB Packaging Tool is a Windows Forms orchestration application for creating, validating, and optionally deploying Intune-ready application packages. It is not a simple script. It is a multi-engine workflow coordinator that:

1. Collects package metadata and installer media.
2. Creates package folder structure from a read-only Master Template.
3. Updates Startup.pss fields and inserts optional custom commands.
4. Builds Install.exe through SAPIEN PowerShell Studio command-line build tooling.
5. Executes guided install and uninstall validation loops.
6. Produces HTML validation reports.
7. Optionally copies completed packages to a network share.

## Runtime Architecture

### Main Launcher

- Primary entrypoint: FRB-Packaging-Tool.ps1
- Responsibilities:
  - Load config and state flags
  - Import engine modules
  - Run first-time setup path
  - Render and handle GUI actions
  - Execute package creation/build/test/deploy workflow

### Core Configuration

- File: config/app.config.json
- Controls:
  - basePackagingPath
  - masterTemplatePath
  - projectFileName (Startup.pss)
  - build/test/deployment options
  - first-run state

### Active Engines in Current Workflow

- MetadataEngine
- DetectionEngine
- ValidationEngine
- FolderEngine
- BuildEngine
- ScanEngine
- ReportEngine
- InstallTestEngine
- PathEngine
- DeploymentEngine
- CustomCommandsEngine

### Present but Deprioritized/Legacy Paths

- TemplateDownloadEngine (GitLab/Okta)
- AuthenticationModule (Python/Playwright bootstrap for GitLab path)
- GitLabAuthEngine (token storage model)
- SwitchEngine (utility exists; manual workflow dominates)
- UninstallEngine (utility exists; not primary UI flow)
- ProcessEngine (helper exists; auto-process behavior appears minimized)

## End-to-End Operational Flow

1. Tool launch and engine import.
2. First-run setup check:
   - optional local copy initialization
   - packaging folder initialization
3. GUI renders for package metadata and command sections.
4. Technician browses installer media.
5. Metadata and installer type are detected.
6. Existing package custom commands may be loaded for reuse.
7. Start Packaging triggers validation checks.
8. Package create/update flow:
   - folder path resolution
   - template copy
   - media copy
   - Startup.pss variable updates
   - custom command insertion
9. Build flow:
   - locate FRB Installer.psproj
   - run SAPIEN command-line build
   - verify Install.exe output
10. Install test loop:
   - launch Install.exe
   - technician confirms behavior
11. Validation report generation:
   - scan registry/software state
   - output HTML report in Docs
12. Uninstall test loop:
   - run Install.exe /uninstall
   - leftover scan/report
   - technician confirms behavior
13. Optional network deployment to configured share.

## Major Dependencies

- Windows PowerShell 5.1 runtime.
- WinForms assemblies.
- SAPIEN PowerShell Studio command-line build tool.
- Valid local template path and package base path.
- Permissions for destination paths and network share (if deployment enabled).

## Critical Observations

1. The launcher is orchestration-heavy and stateful.
2. The workflow depends on strict folder and file naming assumptions.
3. Build, validation, and deployment are tightly coupled in one guided pipeline.
4. Backup/alternate module files indicate frequent in-place iteration and refactors.

## Known Risk Areas and What-If Scenarios

### 1) Startup Flow Coupling

- What if first-run flags are inconsistent across copies?
- Result: users may see repeated setup prompts, stale path state, or wrong runtime root.

### 2) Template and Path Assumptions

- What if basePackagingPath is unset/invalid?
- Result: folder creation and copy steps fail downstream.

### 3) Build Tool Availability

- What if SAPIEN CLI path is invalid or inaccessible?
- Result: package creation succeeds up to startup updates, then build stops.

### 4) Interactive Test Loop Behavior

- What if install/uninstall behavior is not technician-confirmed?
- Result: workflow intentionally loops back for manual adjustments.

### 5) Deployment Permissions

- What if network share is accessible but not writable?
- Result: packaging may succeed locally while deployment fails at final step.

### 6) Deprecated GitLab/Okta Paths

- What if old auth/template update logic remains active on startup?
- Result: startup delay, warning noise, and non-essential failures in an otherwise local workflow.

## Master Template Boundary

Master Template is correctly treated as an immutable source template.

- Allowed interaction:
  - read and copy content into generated package paths
- Not allowed in this plan:
  - edits or structural changes inside Master Template

## Safe Change Zones (Outside Master Template)

1. FRB-Packaging-Tool.ps1 orchestration and event handlers.
2. src/Engines module behaviors and interfaces.
3. config/app.config.json defaults and flags.

## Recommended Change Strategy for Timeline Delivery

### Phase 1 - Stabilize Runtime (Highest Priority)

- Remove/disable deprecated GitLab/Okta startup dependencies.
- Keep launch path deterministic and local-first.
- Preserve existing package build/test/deploy behavior.

### Phase 2 - Harden Reliability

- Normalize path-state handling and first-run logic.
- Strengthen guardrails around missing tools and bad paths.
- Improve explicit status/error messages at each pipeline stage.

### Phase 3 - Reduce Technical Debt

- Separate active modules from legacy backups/alternates.
- Define a clear engine contract map (inputs/outputs/errors).
- Add lightweight regression validation for core flows.

## Practical Printing Notes

- This Markdown file can be printed directly from VS Code preview.
- For formal distribution, export to PDF from the preview print dialog.

## Conclusion

The current codebase is capable of a complete packaging lifecycle and appears architected for technician-guided validation. The fastest path to timeline success is to keep Master Template unchanged, strip deprecated GitLab startup dependencies, and stabilize the launcher and engine orchestration around local template-based packaging.
