#Requires -Version 5.1
param(
    [string]$OutputFolder = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'

function New-DocHtml {
    param(
        [string]$Title,
        [string]$Subtitle,
        [string[]]$BodySections
    )

    $css = @'
    <style>
        body {
            font-family: "Segoe UI", Arial, sans-serif;
            color: #1f2937;
            margin: 0;
            padding: 0;
            background: #f6f8fb;
        }
        .page {
            width: 900px;
            margin: 32px auto;
            padding: 42px 50px;
            background: #ffffff;
            box-shadow: 0 8px 32px rgba(15, 23, 42, 0.08);
            border: 1px solid #e5e7eb;
        }
        .cover {
            text-align: center;
            padding: 40px 20px 20px 20px;
            border-bottom: 4px solid #2e75b6;
            margin-bottom: 28px;
        }
        .eyebrow {
            text-transform: uppercase;
            letter-spacing: 0.14em;
            color: #6b7280;
            font-size: 12px;
            margin-bottom: 14px;
        }
        h1 {
            color: #1d4f91;
            font-size: 30px;
            margin: 0 0 8px 0;
        }
        .subtitle {
            color: #475569;
            font-size: 16px;
            margin-bottom: 18px;
        }
        .meta {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 12px;
            margin: 18px 0 0 0;
            padding: 0;
        }
        .meta div {
            background: #f8fafc;
            border: 1px solid #dbe3ee;
            padding: 10px 12px;
            border-radius: 8px;
            text-align: left;
        }
        h2 {
            color: #1d4f91;
            font-size: 20px;
            margin-top: 28px;
            margin-bottom: 10px;
            border-bottom: 1px solid #d7e2ef;
            padding-bottom: 6px;
        }
        h3 {
            color: #0f172a;
            font-size: 16px;
            margin-top: 18px;
            margin-bottom: 8px;
        }
        p { line-height: 1.6; font-size: 11.5pt; margin: 10px 0; }
        ul, ol { margin-top: 8px; margin-bottom: 16px; }
        li { margin-bottom: 6px; }
        .callout {
            border-left: 5px solid #2e75b6;
            background: #eff6ff;
            padding: 12px 14px;
            margin: 14px 0;
        }
        .muted { color: #6b7280; }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 14px 0 18px 0;
            font-size: 10.5pt;
        }
        th, td {
            border: 1px solid #cfd8e3;
            padding: 9px 10px;
            vertical-align: top;
        }
        th {
            background: #1d4f91;
            color: white;
            text-align: left;
        }
        tr:nth-child(even) td { background: #fbfdff; }
        .pill {
            display: inline-block;
            padding: 3px 10px;
            border-radius: 999px;
            background: #dbeafe;
            color: #1e3a8a;
            font-size: 11px;
            margin-right: 8px;
        }
        .page-break { page-break-after: always; }
        .small { font-size: 10pt; }
    </style>
'@

    $content = New-Object System.Collections.Generic.List[string]
    [void]$content.Add('<!DOCTYPE html><html><head><meta charset="utf-8"><title>' + $Title + '</title>' + $css + '</head><body>')
    [void]$content.Add('<div class="page">')
    [void]$content.Add('<div class="cover">')
    [void]$content.Add('<div class="eyebrow">FRB Packaging Tool Documentation</div>')
    [void]$content.Add('<h1>' + $Title + '</h1>')
    [void]$content.Add('<div class="subtitle">' + $Subtitle + '</div>')
    [void]$content.Add('<div class="meta">')
    [void]$content.Add('<div><strong>Document Type:</strong><br>Internal Packaging Reference</div>')
    [void]$content.Add('<div><strong>Audience:</strong><br>Packagers, Technicians, and Support Engineers</div>')
    [void]$content.Add('<div><strong>Version:</strong><br>v6.0 package lineage</div>')
    [void]$content.Add('<div><strong>Prepared For:</strong><br>Repo-ready distribution</div>')
    [void]$content.Add('</div>')
    [void]$content.Add('</div>')

    foreach ($section in $BodySections) {
        [void]$content.Add($section)
    }

    [void]$content.Add('</div></body></html>')
    return ($content -join [Environment]::NewLine)
}

function Export-HtmlToDocx {
    param(
        [Parameter(Mandatory)]
        [string]$Html,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    $tempHtml = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetTempFileName(), '.html')
    [System.IO.File]::WriteAllText($tempHtml, $Html, [System.Text.Encoding]::UTF8)

    $word = $null
    $doc = $null
    try {
        $word = New-Object -ComObject Word.Application
        $word.Visible = $false
        $word.DisplayAlerts = 0
        $doc = $word.Documents.Open($tempHtml, $false, $true)
        $doc.SaveAs2($OutputPath, 16)
        $doc.Close($false)
    }
    finally {
        if ($doc) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($doc) }
        if ($word) { $word.Quit() | Out-Null; [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) }
        Remove-Item $tempHtml -Force -ErrorAction SilentlyContinue
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }
}

function New-ComparisonDocSections {
    $sections = @()

    $sections += @'
<h2>Purpose</h2>
<p>This document presents a polished comparison between the FRB-Packaging-Tool feature set associated with the v5.0.0 baseline and the current v6.0 implementation. It is written for packaging engineers and technicians who need a concise summary of what changed, why it matters, and what capabilities are now available.</p>

<div class="callout">
<strong>Interpretation note:</strong> The v5.0.0 baseline below reflects the preserved pre-v6 workflow profile in this repository lineage. v6.0 represents the current modular, technician-guided release with validation and reporting enhancements.
</div>

<h2>Feature Comparison</h2>
<table>
    <tr>
        <th style="width: 18%;">Area</th>
        <th style="width: 35%;">v5.0.0 Baseline</th>
        <th style="width: 35%;">v6.0 Current</th>
        <th style="width: 12%;">Change</th>
    </tr>
    <tr>
        <td>Packaging Flow</td>
        <td>Technician-guided packaging with template copy, metadata entry, Startup.pss updates, build, test, and copy behavior.</td>
        <td>Same end-to-end flow, but with stronger orchestration, clearer state resets, and cleaner tab/task separation.</td>
        <td>Refined</td>
    </tr>
    <tr>
        <td>Architecture</td>
        <td>Packaging functionality centered around the main launcher and core workflow handling.</td>
        <td>Modular engine-based architecture with separate engines for detection, validation, reporting, capture, deployment, and custom commands.</td>
        <td>Expanded</td>
    </tr>
    <tr>
        <td>Metadata & Detection</td>
        <td>Metadata capture and package folder population with installer selection and technician review.</td>
        <td>Improved installer detection with MSI/EXE parity, install-context prompting, and richer auto-population behavior.</td>
        <td>Improved</td>
    </tr>
    <tr>
        <td>Custom Commands</td>
        <td>Custom command sections were available for package-specific startup logic and updates.</td>
        <td>Custom command loading, expansion, rehydrate, and section-state handling are more deterministic and technician-friendly.</td>
        <td>Hardened</td>
    </tr>
    <tr>
        <td>Validation</td>
        <td>Validation existed as part of the packaging workflow, focused on the core install/uninstall check process.</td>
        <td>Validation now includes a dedicated report pipeline, application-open evidence, vendor-doc lookups, and final docs copy/open behavior.</td>
        <td>Major expansion</td>
    </tr>
    <tr>
        <td>Reporting</td>
        <td>Baseline report output with essential validation capture.</td>
        <td>Professional report generation with figure sequencing, vendor-only data insertion, and publish-to-docs behavior.</td>
        <td>Major expansion</td>
    </tr>
    <tr>
        <td>Operator Experience</td>
        <td>Standard packaging UI with technician interaction.</td>
        <td>Live process tab, reset-to-main-settings behavior, clearer status messages, and improved post-run cleanup.</td>
        <td>Improved</td>
    </tr>
    <tr>
        <td>Deployment</td>
        <td>Network copy support for completed package artifacts.</td>
        <td>Same deployment direction with more explicit verification and packaging state continuity.</td>
        <td>Refined</td>
    </tr>
</table>

<h2>What v6.0 Adds</h2>
<ul>
    <li>Dedicated validation report engine.</li>
    <li>Application opened screenshot capture (Figure 4).</li>
    <li>Vendor-documentation-only enrichment with deterministic fallback text.</li>
    <li>Process tab for live logging and troubleshooting.</li>
    <li>Cleaner return to the Main Settings tab after completion.</li>
    <li>Improved package rehydrate behavior for existing packages.</li>
    <li>Better MSI handling and technician context selection.</li>
</ul>

<h2>What Stayed Core</h2>
<ul>
    <li>Template-based package creation.</li>
    <li>Startup.pss editing and custom command insertion.</li>
    <li>Build, install test, and uninstall test workflow.</li>
    <li>Network share deployment for completed packages.</li>
    <li>Technician-guided packaging decisions.</li>
</ul>
'@

    return $sections
}

function New-WalkthroughDocSections {
    $sections = @()

    $sections += @'
<h2>Purpose</h2>
<p>This guide walks a technician through the standard FRB-Packaging-Tool v6.0 workflow from first launch through validation and completion. It is written as a practical operating guide, not a development note.</p>

<div class="callout">
<strong>Policy note:</strong> Desktop shortcuts are not included in the current workflow. The tool is expected to run from the packaging environment and package folder structure only.
</div>

<h2>Quick Workflow</h2>
<ol>
    <li>Launch the tool and confirm the base packaging paths are ready.</li>
    <li>Select the installer media.</li>
    <li>Review auto-filled metadata and choose install context if prompted.</li>
    <li>Review package helper suggestions and custom command sections.</li>
    <li>Create or update the package.</li>
    <li>Build the package and run install validation.</li>
    <li>Capture validation screenshots and complete the report.</li>
    <li>Review the copied validation report in the package docs folder.</li>
    <li>Complete uninstall validation if required.</li>
    <li>Reset to Main Settings and start the next package.</li>
</ol>

<h2>Step-by-Step Guide</h2>
<h3>1. Open FRB-Packaging-Tool v6.0</h3>
<p>Start the tool from the approved packaging location. Confirm the Main Settings tab is active and the live process area is available for status updates.</p>

<h3>2. Enter Package Metadata</h3>
<p>Provide the vendor, product name, edition if needed, and version. These values control the package path, output naming, and report naming.</p>

<h3>3. Select Installation Media</h3>
<p>Browse to the installer file. The tool will extract metadata, identify the installer type, and populate the basic fields when possible.</p>

<h3>4. Confirm Install Context</h3>
<p>If the installer suggests a user or system context, review the prompt and choose the context that matches the deployment intent.</p>

<h3>5. Review Package Helper Output</h3>
<p>Open the Package Helper tab and review generated suggestions for install switches, uninstall details, and reusable custom snippets. Apply the items you need into the tool fields.</p>

<h3>6. Review Custom Commands</h3>
<p>Use the custom command sections to inspect or edit the package-specific Startup.pss logic. Existing packages can rehydrate these sections automatically when the folder already exists.</p>

<h3>7. Create or Update the Package</h3>
<p>Start the packaging workflow. The tool copies the template, updates the startup script, inserts custom commands, and prepares the package folder structure.</p>

<h3>8. Build and Validate</h3>
<p>Build the package and proceed through the install validation workflow. The validation process now captures the installation progress, programs and features entry, start menu evidence, and the application-open screen.</p>

<h3>9. Review the Validation Report</h3>
<p>When validation completes, the final report is copied into the package docs folder using the established naming convention and opened for review.</p>

<h3>10. Complete Uninstall Validation</h3>
<p>If uninstall validation is part of the run, follow the same guided flow and confirm the results before completion.</p>

<h3>11. Finish and Reset</h3>
<p>After completion, the tool clears the live process log area and returns you to the Main Settings tab so you can start the next package immediately.</p>

<h2>Operator Tips</h2>
<ul>
    <li>Keep package naming consistent so validation reports land in the correct docs path.</li>
    <li>Review the live process tab if a step pauses or needs attention.</li>
    <li>Use the application-open screenshot as the key proof that the package launches successfully.</li>
    <li>Keep vendor documentation available for prerequisites, conflicts, and upgrade notes.</li>
</ul>
'@

    return $sections
}

if (-not (Test-Path $OutputFolder)) {
    New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
}

$comparisonPath = Join-Path $OutputFolder 'FRB-Packaging-Tool-v5.0.0-v6.0-Feature-Comparison.docx'
$walkthroughPath = Join-Path $OutputFolder 'FRB-Packaging-Tool-v6.0-Step-by-Step-Walkthrough.docx'

$comparisonHtml = New-DocHtml -Title 'FRB-Packaging-Tool Feature Comparison' -Subtitle 'v5.0.0 baseline to v6.0 current feature evolution' -BodySections (New-ComparisonDocSections)
$walkthroughHtml = New-DocHtml -Title 'FRB-Packaging-Tool v6.0 Walkthrough' -Subtitle 'Step-by-step operator guide for packaging, validation, and completion' -BodySections (New-WalkthroughDocSections)

Export-HtmlToDocx -Html $comparisonHtml -OutputPath $comparisonPath
Export-HtmlToDocx -Html $walkthroughHtml -OutputPath $walkthroughPath

Write-Host "Created: $comparisonPath"
Write-Host "Created: $walkthroughPath"