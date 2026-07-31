# Installation Validation Report Workflow

## Objective

Generate a professional validation report from installer analysis and research data, and provide a deterministic contract for screenshot capture and report completion.

## Workflow Stages

1. Input Collection
   - Accept application name, version, installer path, and optional metadata.
   - Collect installer analysis data.
   - Optionally collect web research findings.

2. Report Template Population
   - Load the HTML template.
   - Replace metadata placeholders.
   - Insert analysis and research-derived values into the appropriate sections.

3. Placeholder Resolution
   - Resolve placeholders for:
     - report header metadata
     - prerequisite tables
     - install details
     - screenshot evidence locations

4. Screenshot Capture
   - Capture screenshots at specific stages.
   - Store them in a report-specific output folder.
   - Reference them by file name from the placeholder contract.

5. Report Finalization
   - Combine content and images into the final HTML report.
   - Save the generated document in the Reports directory.

## Placeholder Handling Rules

- All header metadata should be replaced before report generation is finalized.
- Placeholder values should be explicit and never left ambiguous.
- Screenshot placeholders must be tied to a defined capture stage and output filename.
- Any placeholder not resolved should remain visible as a clearly marked bracketed token for manual review.

## Expected Output Structure

- Reports/
  - Validation_{Application}_{Version}_{Timestamp}.html
  - screenshots/
    - {application_slug}_installation_progress.png
    - {application_slug}_programs_and_features.png
    - {application_slug}_start_menu_shortcuts.png

## Integration Notes

The screenshot tool should consume the JSON placeholder definitions and the markdown spec as the canonical instructions for what to capture and when to capture it.
