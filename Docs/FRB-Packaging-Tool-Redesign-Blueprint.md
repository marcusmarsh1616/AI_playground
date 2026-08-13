# FRB Packaging Tool — Redesign & Restructuring Blueprint

**Audience:** the developer/agent working on the complete development copy (`E:\AI_playground\FRB-Packaging-Tool`).
**Purpose:** a hand-off design document to drive a full modularization and restructuring of the tool, plus the nine specific fixes currently outstanding.
**Constraint that shapes everything:** **No third-party DLLs.** No purchased/licensed components, no native binaries, nothing that requires security review or introduces supply-chain risk. Everything must be achievable with in-box PowerShell, `System.Windows.Forms`, `System.Drawing`, and `System.Management.Automation` (all already present on every Windows machine).

> This document is a plan, not a change log. It describes the *target* structure and the *rationale*, so the redesign can be executed on the dev machine and then reconciled back.

---

## 1. Why restructure now

Current state (observed in the working copy `C:\Temp\AI_playground\SimpleGit`):

- **`FRB-Packaging-Tool.ps1` is ~6,660 lines.** It is simultaneously the bootstrapper, the GUI layout, the event wiring, the orchestration state machine, *and* a grab-bag of helper functions (log path discovery, report guidance, code-editor behavior, busy dialogs). This single file is the primary source of "unmanageable."
- **Engine sprawl with heavy cruft.** Under `src\` there are **89 files, of which 41 are stale** `*BACKUP*`, `*.BROKEN`, `*_NEW`, `*_TEMP`, `-WithEmojis` copies that are **not loaded** by the tool. Only 16 engines are actually imported (see the `$enginesToLoad` array). The dead files make the tree look far bigger and more confusing than the live code actually is, and they are a trap — it is easy to edit the wrong copy.
- **A few oversized engines.** `SwitchEngine.psm1` (~1,650 lines), `DocumentationUIEngine.psm1` (~1,180), `InstallTestEngine.psm1` (~1,100), `VendorDocumentationEngine.psm1` (~1,010) each do too much and mix concerns (scraping + parsing + UI + orchestration).
- **No manifest/module boundaries.** Engines are `.psm1` files imported by path with `-Force`. There are no `.psd1` manifests, no explicit exported-function lists, and no versioning. Everything is effectively global.
- **Orchestration is embedded in the GUI thread.** The install/uninstall test flow runs as labeled `while` loops (`:InstallLoop`, `:UninstallLoop`) directly inside button handlers, calling `$form.Refresh()` and `DoEvents()`. This is the root cause of several of the nine issues (blocking UI, no clean place to hook progress, no clean place to trigger the Troubleshooting tab).

**Goal of the redesign:** turn this into a layered, manifest-based module architecture with a thin bootstrapper, a dedicated UI layer, a dedicated orchestration/state layer, and small single-responsibility engines — while keeping it 100% dependency-free.

---

## 2. Target architecture

### 2.1 Layers (dependencies point downward only)

```
┌─────────────────────────────────────────────────────────────┐
│  Bootstrap            FRB-Packaging-Tool.ps1  (thin: <300 ln) │
│                       - parse args, load config, load manifest│
│                       - show splash, hand off to App          │
├─────────────────────────────────────────────────────────────┤
│  UI layer             src\UI\*                                │
│                       - Form/tab construction (one file/tab)  │
│                       - control factory + theme               │
│                       - NO business logic, NO Start-Process   │
│                       - raises events / calls Orchestration   │
├─────────────────────────────────────────────────────────────┤
│  Orchestration        src\Core\Workflow*                      │
│                       - the install/uninstall/build/deploy    │
│                         state machine (no WinForms drawing)   │
│                       - runs long work off the UI thread      │
│                       - emits progress + log events           │
├─────────────────────────────────────────────────────────────┤
│  Engines (features)   src\Engines\*  (small, single purpose)  │
│                       - Detection, Metadata, Switch, Scraper, │
│                         Build, Install/Uninstall test, Report,│
│                         Validation, Deployment, CustomCommands│
├─────────────────────────────────────────────────────────────┤
│  Platform/Utils       src\Utils\*, src\Core\*                 │
│                       - Logger, ErrorHandler, Config, State,  │
│                         ProcessRunner (the ONE Start-Process  │
│                         wrapper), PathResolver, LogWatcher     │
└─────────────────────────────────────────────────────────────┘
```

**Rule:** UI never calls `Start-Process`, never reads registry, never parses logs. It calls Orchestration or an Engine and subscribes to events. Engines never draw WinForms. This separation is what makes the tool testable and maintainable.

### 2.2 Proposed folder tree

```
FRB-Packaging-Tool/
  FRB-Packaging-Tool.ps1          # thin bootstrapper only
  FRB.PackagingTool.psd1          # top-level manifest (RootModule loads the rest)
  config/
    app.config.json
    pf_logo.ico
  src/
    Core/
      ConfigurationManager.psm1  (+ .psd1)
      StateManager.psm1
      PackageManager.psm1
      WorkflowEngine.psm1         # orchestration state machine
      ProcessRunner.psm1          # THE single Start-Process wrapper (see §4)
      LogWatcher.psm1             # FileSystemWatcher over InstallLogs (see §4)
    UI/
      AppShell.psm1               # builds form + tabControl, wires events
      Theme.psm1                  # colors, fonts, control factory
      Tab.Main.psm1
      Tab.Install.psm1
      Tab.Uninstall.psm1
      Tab.Troubleshooting.psm1
      Tab.Process.psm1            # Live Process Log
      Tab.GlobalsAssistant.psm1
      CodeEditor/                 # the ISE-like editor (see §5) — pure native
        CodeEditorControl.psm1    # RichTextBox + gutter + events
        PowerShellColorizer.psm1  # AST tokenizer → colors
        CompletionProvider.psm1   # CompleteInput() wrapper
        CompletionPopup.psm1      # the autocomplete listbox
    Engines/
      MetadataEngine/ DetectionEngine/ SwitchEngine/ PythonScraperEngine/
      BuildEngine/ InstallTestEngine/ UninstallEngine/ ReportEngine/
      ValidationEngine/ ValidationReportEngine/ DeploymentEngine/
      CustomCommandsEngine/ PathEngine/ FolderEngine/ ScanEngine/
    Utils/
      Logger.psm1  ErrorHandler.psm1
  Docs/
  tests/                          # Pester tests (see §7)
  archive/                        # ALL *BACKUP*/*BROKEN*/*_TEMP* moved here, out of src
```

### 2.3 Module manifests (`.psd1`)

Every engine gets a manifest that declares `RootModule`, `ModuleVersion`, `FunctionsToExport` (explicit — no `*`), and `RequiredModules`. Benefits:

- The dependency graph becomes **explicit and enforceable** (a UI module can't accidentally depend on a scraper internal).
- `FunctionsToExport` stops the current "everything is global" problem and makes each engine's public surface obvious.
- The bootstrapper loads **one** top-level manifest instead of importing 16 paths by hand.

---

## 3. First, the cleanup (do this before anything else)

This is the single highest-value, lowest-risk step and it will immediately make the tree feel manageable.

1. **Create `archive/`** at the repo root (git-tracked or git-ignored, your call).
2. **Move — do not delete — all 41 stale files** (`*BACKUP*`, `*.BROKEN`, `*_NEW`, `*_TEMP`, `*-TEMP*`, `-WithEmojis`) out of `src\` into `archive\`. Deletion is reversible via git, but moving keeps them one click away while you validate.
3. **Confirm the live set** against the `$enginesToLoad` array in the bootstrapper. Today that array is the *only* authoritative list of what actually runs:
   - MetadataEngine, DetectionEngine, PythonScraperEngine, SwitchEngine, UninstallEngine, ValidationEngine, FolderEngine, ProcessEngine, BuildEngine, ScanEngine, ReportEngine, InstallTestEngine, ValidationReportEngine, PathEngine, DeploymentEngine, CustomCommandsEngine.
   - Note: `ValidationReportEngine` pulls in its own `src\*` sub-engines; `InstallEngine`, `UninstallScanEngine`, `TestOrchestrationEngine` appear present but are **not** in the load list — decide per engine whether to wire in or archive.
4. **After archiving, run the tool once** to confirm nothing was actually depending on a stale copy. Then commit: *"chore: quarantine dead module copies to archive/"*.

Only after the tree is clean should the layering work begin.

---

## 4. Process execution & uninstall — the correct design (fixes #4, #5, #6)

These three items are all symptoms of the same missing abstraction: **there is no single, hardened process runner.** Today the uninstall path calls a bare `Start-Process` (in `InstallTestEngine.psm1`, ~line 543) with no `-ErrorAction Stop`, no try/catch, and no logging, while a heavyweight `Execute-Process` wrapper exists only in the Master Template's `Globals.ps1` and is reported to error out on certain filenames.

**Target: `src\Core\ProcessRunner.psm1`** — one function, used everywhere:

```
Invoke-ManagedProcess
  -FilePath <string>
  -ArgumentList <string[]>
  -WorkingDirectory <string>
  [-TimeoutSeconds <int>]
  [-Fallback]                # use the plain Start-Process fallback path
returns @{ ExitCode; StdOut; StdErr; TimedOut; Succeeded; Error }
```

Design requirements:

- **Primary path:** `System.Diagnostics.Process` with redirected stdout/stderr so output can be streamed to the Live Process Log in real time (this also feeds #9).
- **Fallback path (fixes #6):** the exact pattern the user wants wired in — wrap `Start-Process` in try/catch with `-ErrorAction Stop`:
  ```powershell
  try {
      Write-Log -Message "Uninstalling $appName $appVersion..."
      Start-Process -FilePath $uninstallerPath `
                    -ArgumentList '/uninstall','/quiet','/NoRestart' `
                    -Wait -ErrorAction Stop
      Write-Log -Message "Uninstall completed."
  } catch {
      Write-Log -Message "Failed to uninstall $appName $appVersion. Error: $($_.Exception.Message)"
  }
  ```
  This becomes a real, callable code path (`-Fallback`), not just text the tool detects. The engine should auto-fall-back to it when the primary `Execute-Process`/diagnostics path reports the known filename error, and log which path it took.
- **Every current call site** (`Start-Process`, `Execute-Process`, `Execute-MSI`) routes through `Invoke-ManagedProcess`. Grep the codebase and convert them one by one.

**Kill-before-uninstall (fixes #5):** `Stop-RunningAppExecutables` already exists and is already called before the uninstall (`InstallTestEngine.psm1` ~line 537, uninstall at ~543). The redesign should:
- Move it into a dedicated `ProcessRunner`/`UninstallEngine` responsibility.
- **Harden and verify it:** confirm the process actually exited (`WaitForExit` / poll `Get-Process`), log every PID it terminated and every failure, and add a short settle delay + re-check before the uninstaller launches. Add a Pester test with a dummy long-running process to prove the kill happens first.

---

## 5. The ISE-like Custom Command editor (fixes #7) — native, no DLLs

This is achievable to **ISE-grade functionality with zero third-party dependencies**, because the same completion engine ISE uses is built into PowerShell. It must be hand-built on top of `RichTextBox`, which is the trade-off for staying DLL-free.

**Target: `src\UI\CodeEditor\` — four small modules.**

| Module | Responsibility | Built on (in-box only) |
|---|---|---|
| `PowerShellColorizer.psm1` | Syntax highlighting: keywords, strings, comments, variables, operators, numbers | `[System.Management.Automation.Language.Parser]::Tokenize()` → set `RichTextBox.SelectionColor` per token span. Debounced on idle to avoid flicker. |
| `CompletionProvider.psm1` | The actual IntelliSense/type-ahead | `[System.Management.Automation.CommandCompletion]::CompleteInput($text,$cursor,$null,$runspace)` — returns cmdlets, parameters, variables, object members, enum values, paths. |
| `CompletionPopup.psm1` | The autocomplete UI | A borderless `ListBox` positioned at the caret; Enter/Tab accepts, Esc dismisses, Up/Down navigates. |
| `CodeEditorControl.psm1` | Wires it together on a RichTextBox: line-number gutter, current-line highlight, brace matching, auto-indent, real-time parse-error squiggles | `Parser::ParseInput()` gives `ParseError[]` for squiggles; a `Panel` beside the RichTextBox draws line numbers. |

**Making completion aware of `Globals.ps1` and loaded modules (the key ask):**

- Stand up a **dedicated background runspace** used only for completion.
- Into that runspace, **dot-source `Globals.ps1`** and import any package modules (PSADT etc.). Once its functions/parameters are defined there, `CompleteInput` offers **your Globals functions and their parameters** exactly like ISE completing an imported module.
- Belt-and-suspenders: also **AST-parse `Globals.ps1`** (`Parser::ParseFile`) to enumerate every `function`/`param` so completion works even before the runspace has executed anything.
- Treating Globals.ps1 "as a module": optionally wrap it in a generated `.psd1`/`.psm1` shim so it imports cleanly and versions like the other engines. **Yes, this is doable** and is the cleaner long-term form.

**Apply to all 6 boxes:** the current custom-command controls (`$txtPreInstall`, `$txtCustomInstall`, `$txtPostInstall`, `$txtPreUninstall`, `$txtCustomUninstall`, `$txtPostUninstall`) are already `RichTextBox` with Consolas — replace each with the new `CodeEditorControl` instance.

**Honest limits (state these so expectations are set):**
- You **cannot host the literal ISE editor pane** — it isn't a redistributable control. This *replicates* it.
- Deep best-practice linting (PSScriptAnalyzer-style) needs that module present offline; **parse-error** detection is free, rule-based lint is not.
- RichTextBox needs debouncing/virtualization for very large scripts; keep recolor work on idle and off the hot path.

---

## 6. Workflow, UI feedback, and log visibility (fixes #1, #2, #3, #8, #9)

These become straightforward once orchestration is separated from the UI (§2.1).

### #1 — Webscrape progress
A marquee busy dialog already exists (`Show-PackageHelperBusyDialog`) and the scrape already runs in a background job with a 350 ms poll timer. If it "isn't functioning," the fix is behavioral, not new UI:
- Ensure the dialog is created/shown **on the UI thread** and that the poll timer actually calls `Update-PackageHelperBusyDialog` (elapsed counter) each tick.
- Stream real scraper stdout/stderr lines (via `ProcessRunner` redirection) into the dialog text and the Live Process Log so it's a *real* progress indicator, not just a spinner.
- Guarantee `Close-PackageHelperBusyDialog` runs in a `finally` so it can never orphan.

### #2 — Troubleshooting tab auto-trigger
The tab (`$tabPackageHelper`) exists but is never auto-selected on failure. In the orchestration layer, at the two "did it work? → No" branches (`InstallTestEngine` returns `Success=$false/UserConfirmed=$false`; handled in the main `:InstallLoop` ~line 2840 and `:UninstallLoop` ~line 2979):
- When the technician answers **No**, set `$tabControl.SelectedTab = $tabPackageHelper`, auto-run the log+code scan, and focus the results — *before* returning them to the GUI.

### #3 — Troubleshooting reads more logs
`Get-TroubleshootingLogPaths` (~line 887) currently returns only tool logs + `logs\` folders. Add the two install-log roots (which the engine already knows about elsewhere):
- `${env:CommonProgramFiles(x86)}\InstallLogs`  → `C:\Program Files (x86)\Common Files\InstallLogs`
- `$env:TEMP\InstallLogs` → `C:\Users\<user>\AppData\Local\Temp\InstallLogs`
- Enumerate `*.log,*.txt` in both, filter to files touched during/after the operation start, so it surfaces 3–4 relevant logs instead of 2.

### #8 — Uninstall report should be GREEN when clean
`New-HTMLUninstallReport` (`ReportEngine.psm1` ~line 341) has two concrete bugs:
1. **Undefined variables** `$desktopShortcuts`, `$startMenuItems`, `$userScopedItems` (referenced ~lines 411/420/429) are never populated in this function — they exist only in the newer `New-HTMLLeftoverReport`. Populate them from `$LeftoverData.Details` (by `Type`/`Scope`) or remove the blocks.
2. **Status logic doesn't separate machine vs. user leftovers.** `New-HTMLLeftoverReport` already does this correctly (compute `MachineLeftoverCount`, green when `-eq 0`). Port that logic here so **preserved user-level items don't flip the report to yellow/red**. When nothing machine-level is found → `#28a745` green / `[PASS]` / "Clean Uninstall". Consolidating both functions into one is the cleaner fix.

### #9 — Live Process Log watches the InstallLogs folders
Today `$txtProcessLog` (`Write-ProcessOutputLine`, ~line 557) only shows tool-internal messages. Add **`src\Core\LogWatcher.psm1`**:
- Wraps `System.IO.FileSystemWatcher` (in-box) over both InstallLogs folders (§3 paths).
- On new/changed files, tails appended lines and routes them through `Write-ProcessOutputLine` with a `[InstallLog]` prefix.
- **Lifecycle:** start watching when an install/uninstall **test session begins**, stop when it ends — this keeps the log focused and avoids stale noise. (This was the intended default; confirm on the dev machine.)
- Marshal callbacks back to the UI thread (`$control.BeginInvoke`) since `FileSystemWatcher` events fire on a threadpool thread.

---

## 7. Cross-cutting standards for the redesign

- **Logging:** one `Logger` used by every layer; structured levels (INFO/WARN/ERROR); every process launch and every uninstall step logged with which code path executed.
- **Error handling:** engines return result objects (`@{ Success; Error; ... }`) rather than throwing across layers; the orchestration layer decides UI reaction.
- **Threading rule:** any work >~200 ms runs off the UI thread (runspace/job); UI updates marshalled via `BeginInvoke`. No more `DoEvents()` loops as the concurrency model.
- **Naming:** approved PowerShell verbs (`Get-`,`Invoke-`,`Start-`,`New-`); one public responsibility per exported function.
- **Tests (`tests\`, Pester — in-box):** minimum coverage for the risky bits — `Invoke-ManagedProcess` (exit codes, timeout, fallback), kill-before-uninstall ordering, uninstall-report green/yellow logic, `CompletionProvider` returning Globals functions, `LogWatcher` picking up a new file.
- **No new runtime dependencies.** If a feature seems to need a DLL, redesign the feature — that is the hard boundary.

---

## 8. Suggested execution order

1. **Cleanup/quarantine** the 41 dead files (§3). Commit. Lowest risk, biggest immediate relief.
2. **Extract `ProcessRunner`** and route all process calls through it (fixes #4/#5/#6). Commit + test.
3. **Fix the report green logic** (#8) and **troubleshooting log paths** (#3) — small, self-contained. Commit + test.
4. **Add `LogWatcher`** and wire the Live Process Log (#9); verify webscrape progress (#1). Commit.
5. **Separate orchestration from UI**, then add the Troubleshooting auto-trigger (#2). This is the larger structural step.
6. **Split the oversized engines** (`SwitchEngine`, `DocumentationUIEngine`, `InstallTestEngine`, `VendorDocumentationEngine`) along the seams exposed once orchestration is out.
7. **Build the native CodeEditor** (#7) and swap the 6 custom-command boxes over.
8. **Introduce `.psd1` manifests** per module and the top-level manifest; make the bootstrapper thin.

Steps 1–4 deliver working fixes fast; 5–8 are the deeper restructuring.

---

## 9. Quick reference — the nine items → where they live

| # | Item | Primary location today | Redesign home |
|---|------|------------------------|---------------|
| 1 | Webscrape progress | `Show-PackageHelperBusyDialog` (~4068), poll timer (~4218) | UI + ProcessRunner streaming |
| 2 | Troubleshooting trigger on "No" | `:InstallLoop` ~2840 / `:UninstallLoop` ~2979; tab `$tabPackageHelper` ~5939 | Orchestration layer |
| 3 | Read 3–4 logs incl. InstallLogs | `Get-TroubleshootingLogPaths` ~887 | same fn + LogWatcher paths |
| 4 | Start-Process wrapper broken | bare `Start-Process` InstallTestEngine ~543; `Execute-Process` in Globals.ps1 | `ProcessRunner.Invoke-ManagedProcess` |
| 5 | Kill app before uninstall | `Stop-RunningAppExecutables` ~537 (already runs) | ProcessRunner/UninstallEngine, hardened |
| 6 | Wire in Start-Process fallback | detected only as text, main ~1501 | `ProcessRunner -Fallback` real path |
| 7 | ISE-like custom command boxes | 6 RichTextBoxes ~5635–5860 | `src\UI\CodeEditor\*` (native) |
| 8 | Uninstall report not green | `New-HTMLUninstallReport` ~341 (undefined vars, machine/user logic) | ReportEngine, consolidated |
| 9 | Live Process Log watches folders | `$txtProcessLog`/`Write-ProcessOutputLine` ~557 | `src\Core\LogWatcher.psm1` |

*Line numbers are from the working copy `C:\Temp\AI_playground\SimpleGit\FRB-Packaging-Tool.ps1` (~6,660 lines) and its engines; they will differ on the dev copy but the anchors (function names) are stable.*
