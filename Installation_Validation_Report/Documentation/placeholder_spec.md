# Validation Report Placeholder Specification

## Purpose

This document defines every placeholder used by the Installation Validation Report workflow so that downstream automation, including screenshot capture tools, can interpret the report without ambiguity.

## Placeholder Categories

### 1. Metadata Placeholders
These placeholders feed the report header and summary fields.

- Application Name
  - Placeholder: [Application Name]
  - Represents: The full display name of the application under validation.
  - Source: Primary application name from installer metadata or user input.

- Version
  - Placeholder: [Version]
  - Represents: Application version being validated.
  - Source: Installer version or user-supplied version.

- Ticket Number
  - Placeholder: [TT#####]
  - Represents: The ticket or work item number for the validation.
  - Source: External tracking system or manual entry.

- Validated By
  - Placeholder: [Tech Name]
  - Represents: The analyst or engineer who completed the validation.
  - Source: User input or automation profile.

- Validation Date
  - Placeholder: [Date]
  - Represents: Date of validation execution.
  - Source: Current date at report generation time.

- Operating System
  - Placeholder: [OS Version]
  - Represents: The OS environment used for validation.
  - Source: System environment or user input.

- Status
  - Placeholder: PASSED
  - Represents: Final validation outcome.
  - Source: Report workflow or manual completion.

### 2. Screenshot Placeholders
These placeholders indicate where image evidence should be inserted into the report.

- Installation Progress Dialog
  - Placeholder: [Figure 1: Installation Progress Dialog]
  - Represents: Screenshot of the installation progress window while installation is active.
  - Automation instruction: Capture during installation, not after completion.
  - Expected output: A screenshot file named using the app slug and a descriptive suffix.

- Programs and Features Entry
  - Placeholder: [Figure 2: Programs and Features Entry]
  - Represents: Screenshot showing the installed application in Programs and Features.
  - Automation instruction: Capture only after installation completes successfully.

- Start Menu Shortcuts
  - Placeholder: [Figure 3: Start Menu Shortcuts]
  - Represents: Screenshot of any Start Menu or Desktop shortcuts created by the installation.
  - Automation instruction: Capture after installation completion.

### 3. Structured Data Placeholders
These are not visual placeholders but values inserted into tables or lists.

- Prerequisite Name
  - Placeholder: [Prerequisite Name]
  - Represents: A prerequisite component detected by analysis or research.

- Version
  - Placeholder: [Version]
  - Represents: Version value for a listed prerequisite or install detail.

- Uninstall Registry Keys
  - Placeholder: [Uninstall Registry Keys]
  - Represents: The uninstall registry path associated with the application.

- Application
  - Placeholder: [Application]
  - Represents: Application name used in installation details.

## Automation Contract for Screenshot Capture Tool

The screenshot capture workflow should follow this contract:

1. Read the report template placeholders and their definitions.
2. Identify each screenshot placeholder by section and label.
3. Capture the screenshot at the correct stage:
   - during_installation for installation progress
   - post_install for Programs and Features and Start Menu shortcuts
4. Save screenshots using the expected filename convention.
5. Insert the image into the corresponding report section.

## Recommended Filename Convention

Use the application slug plus a descriptive suffix:

- {application_slug}_installation_progress.png
- {application_slug}_programs_and_features.png
- {application_slug}_start_menu_shortcuts.png

## Implementation Guidance

When integrating with another tool, use the JSON file in the Config folder as the canonical machine-readable source for placeholders and capture instructions.
