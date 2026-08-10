#Requires -Version 5.1

function Get-ProcessWindowInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [int]$ProcessId
    )

    $result = [pscustomobject]@{
        ProcessId = $ProcessId
        ProcessName = $null
        MainWindowTitle = $null
        ExecutablePath = $null
    }

    if (-not $ProcessId) {
        return $result
    }

    try {
        $process = Get-Process -Id $ProcessId -ErrorAction Stop
        $result.ProcessName = $process.ProcessName
        $result.MainWindowTitle = $process.MainWindowTitle
    } catch {
        $result.ProcessName = $null
    }

    try {
        $procInfo = Get-CimInstance Win32_Process -Filter "ProcessId = $ProcessId" -ErrorAction SilentlyContinue
        if ($procInfo -and $procInfo.ExecutablePath) {
            $result.ExecutablePath = $procInfo.ExecutablePath
        }
    } catch {
        $result.ExecutablePath = $null
    }

    return $result
}

function Get-UiAutomationElementText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$Element
    )

    try {
        return $Element.Current.Name
    } catch {
        return $null
    }
}

function Get-UiAutomationElementChildren {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$Element
    )

    try {
        return @($Element.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition))
    } catch {
        return @()
    }
}

function Get-TargetProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$ApplicationName,

        [Parameter(Mandatory=$false)]
        [int]$ProcessId
    )

    if ($ProcessId) {
        try {
            return Get-Process -Id $ProcessId -ErrorAction Stop
        } catch {
            return $null
        }
    }

    if (-not $ApplicationName) {
        return $null
    }

    $appLower = $ApplicationName.ToLowerInvariant()
    $matches = @(Get-Process | Where-Object {
        $procName = $_.ProcessName.ToLowerInvariant()
        $title = $_.MainWindowTitle.ToLowerInvariant()
        $procName -like "*$appLower*" -or $title -like "*$appLower*"
    })

    if ($matches.Count -gt 0) {
        return $matches[0]
    }

    return $null
}

function Get-WindowElementForProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$ApplicationName,

        [Parameter(Mandatory=$false)]
        [int]$ProcessId
    )

    $process = Get-TargetProcess -ApplicationName $ApplicationName -ProcessId $ProcessId
    if (-not $process) {
        return $null
    }

    try {
        Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes -ErrorAction Stop
    } catch {
        return $null
    }

    if ($process.MainWindowHandle -and $process.MainWindowHandle -ne 0) {
        try {
            return [System.Windows.Automation.AutomationElement]::FromHandle($process.MainWindowHandle)
        } catch {
            return $null
        }
    }

    return $null
}

function Add-Win32MenuType {
    # Classic Win32 apps (e.g. 7-Zip) expose menus as HMENU, invisible to UI Automation
    if (-not ('Win32.NativeMenu' -as [type])) {
        Add-Type -Namespace Win32 -Name NativeMenu -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr GetMenu(IntPtr hWnd);
[DllImport("user32.dll")] public static extern IntPtr GetSubMenu(IntPtr hMenu, int nPos);
[DllImport("user32.dll")] public static extern int GetMenuItemCount(IntPtr hMenu);
[DllImport("user32.dll")] public static extern int GetMenuItemID(IntPtr hMenu, int nPos);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetMenuString(IntPtr hMenu, int uIDItem, System.Text.StringBuilder lpString, int nMaxCount, int uFlag);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
public const int MF_BYPOSITION = 0x400;
public const uint WM_COMMAND = 0x0111;
'@
    }
}

function Get-NormalizedMenuName {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return [string]::Empty }
    return ($Text -replace '[&_\-]', '').Trim().ToLowerInvariant()
}

function Get-AboutLikeScore {
    param([string]$Text)

    $name = Get-NormalizedMenuName -Text $Text
    if ([string]::IsNullOrWhiteSpace($name)) { return 0 }

    if ($name -eq 'about') { return 100 }
    if ($name -match '^about\b') { return 95 }
    if ($name -match 'about') { return 90 }
    if ($name -match 'version') { return 60 }
    if ($name -match 'info') { return 55 }
    if ($name -match 'license') { return 50 }
    if ($name -match 'credits|copyright') { return 50 }
    if ($name -match 'details|properties|register') { return 40 }

    return 0
}

function Test-AboutLikeName {
    param([string]$Text)

    $name = Get-NormalizedMenuName -Text $Text
    if ([string]::IsNullOrWhiteSpace($name)) { return $false }

    if ($name -match '\b(about|version|build|license|licence|credits|copyright)\b') { return $true }
    if ($name -match 'product\s*info|app\s*info|information') { return $true }

    return $false
}

function Get-TopMenuScore {
    param(
        [string]$Text,
        [string]$ProcessName
    )

    $name = Get-NormalizedMenuName -Text $Text
    if ([string]::IsNullOrWhiteSpace($name)) { return 0 }

    if ($name -eq 'help' -or $name -eq '?') { return 100 }
    if (-not [string]::IsNullOrWhiteSpace($ProcessName)) {
        $procName = (Get-NormalizedMenuName -Text $ProcessName)
        if (-not [string]::IsNullOrWhiteSpace($procName) -and $name -eq $procName) { return 90 }
    }
    if ($name -match '^file$|^app$|^application$') { return 80 }
    if ($name -match '^settings$|^tools$|^window$') { return 60 }

    return 20
}

function Find-AboutWindowForProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$Root,

        [Parameter(Mandatory=$true)]
        [object]$Window,

        [Parameter(Mandatory=$true)]
        [object]$PidCondition,

        [Parameter(Mandatory=$true)]
        [int]$MainWindowHandle,

        [int]$TimeoutMilliseconds = 5000
    )

    $winCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Window)
    $paneCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Pane)
    $deadline = (Get-Date).AddMilliseconds($TimeoutMilliseconds)

    while ((Get-Date) -lt $deadline) {
        $aboutWin = @($Root.FindAll([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.AndCondition($PidCondition, $winCond)))) |
            Where-Object { $_.Current.NativeWindowHandle -ne $MainWindowHandle -and $_.Current.NativeWindowHandle -ne 0 } | Select-Object -First 1
        if ($aboutWin) { return $aboutWin }

        $embeddedWindow = $Window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $winCond)
        if ($embeddedWindow) { return $embeddedWindow }

        $embeddedPane = @($Window.FindAll([System.Windows.Automation.TreeScope]::Descendants, $paneCond)) |
            Where-Object { Test-AboutLikeName -Text $_.Current.Name } | Select-Object -First 1
        if ($embeddedPane) { return $embeddedPane }

        Start-Sleep -Milliseconds 250
    }

    return $null
}

function Find-AboutLikeAutomationElement {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$Window,

        [Parameter(Mandatory=$true)]
        [object]$Root,

        [Parameter(Mandatory=$true)]
        [int]$ProcessId
    )

    $candidates = New-Object System.Collections.Generic.List[object]
    $descendants = @($Window.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition))

    foreach ($element in $descendants) {
        $name = Get-UiAutomationElementText -Element $element
        if ([string]::IsNullOrWhiteSpace($name)) { continue }

        $score = Get-AboutLikeScore -Text $name
        if ($score -lt 50) { continue }

        $controlType = $element.Current.ControlType.ProgrammaticName
        $candidates.Add([pscustomobject]@{
            Element = $element
            Name = $name
            Score = $score
            ControlType = $controlType
        })
    }

    if ($candidates.Count -eq 0) { return $null }

    $best = $candidates | Sort-Object Score -Descending | Select-Object -First 1
    $inv = $null
    if ($best.Element.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$inv)) {
        return $best
    }

    return $null
}

function Invoke-AboutDialogAutomation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ApplicationName,

        [Parameter(Mandatory=$false)]
        [int]$ProcessId,

        [Parameter(Mandatory=$false)]
        [switch]$LeaveOpen
    )

    $result = [pscustomobject]@{
        Success = $false
        Method = $null
        Message = $null
        ProcessId = $null
        ProcessName = $null
        MenuBarItems = @()
        HelpMenuItems = @()
        AboutItemName = $null
        DialogTitle = $null
        DialogText = @()
    }

    try {
        Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes -ErrorAction Stop
    } catch {
        $result.Message = 'UI Automation assemblies are not available.'
        return $result
    }

    $process = Get-TargetProcess -ApplicationName $ApplicationName -ProcessId $ProcessId
    if (-not $process -or -not $process.MainWindowHandle -or $process.MainWindowHandle -eq 0) {
        $result.Message = 'No matching process with a main window was found.'
        return $result
    }
    $result.ProcessId = $process.Id
    $result.ProcessName = $process.ProcessName

    $window = [System.Windows.Automation.AutomationElement]::FromHandle($process.MainWindowHandle)

    # Restore if minimized; SetFocus may fail for background windows - not fatal
    $winPattern = $null
    if ($window.TryGetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern, [ref]$winPattern)) {
        if ($winPattern.Current.WindowVisualState -eq [System.Windows.Automation.WindowVisualState]::Minimized) {
            $winPattern.SetWindowVisualState([System.Windows.Automation.WindowVisualState]::Normal)
            Start-Sleep -Milliseconds 500
        }
    }
    try { $window.SetFocus() } catch { }

    $invoked = $false
    $pidCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $process.Id)
    $root = [System.Windows.Automation.AutomationElement]::RootElement

    # --- Path 1: UIA menu bar (modern apps) ---
    $menuBarCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::MenuBar)
    $menuBar = $window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $menuBarCond)
    if (-not $menuBar) {
        $menuCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Menu)
        $menuBar = $window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $menuCond)
    }

    if ($menuBar) {
        $topItems = @($menuBar.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition))
        $result.MenuBarItems = @($topItems | ForEach-Object { $_.Current.Name })
        $topCandidates = @($topItems | ForEach-Object {
            [pscustomobject]@{
                Element = $_
                Name = $_.Current.Name
                Score = Get-TopMenuScore -Text $_.Current.Name -ProcessName $process.ProcessName
            }
        } | Sort-Object Score -Descending)

        foreach ($topCandidate in $topCandidates) {
            if ($invoked) { break }

            $menuRootItem = $topCandidate.Element
            $miCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::MenuItem)

            $expand = $null
            if ($menuRootItem.TryGetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern, [ref]$expand)) {
                $expand.Expand()
            } else {
                $inv = $null
                if ($menuRootItem.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$inv)) { $inv.Invoke() }
            }
            Start-Sleep -Milliseconds 700
            # Expand can toggle an already-open menu closed - re-expand if needed
            if ($expand -and $expand.Current.ExpandCollapseState -eq [System.Windows.Automation.ExpandCollapseState]::Collapsed) {
                $expand.Expand()
                Start-Sleep -Milliseconds 700
            }

            # Tier 1: submenu items as descendants of the Help item (WPF, WinForms)
            $subItems = @($menuRootItem.FindAll([System.Windows.Automation.TreeScope]::Descendants, $miCond)) | Where-Object { $_.Current.Name }
            if ($subItems.Count -eq 0) {
                # Tier 2: popup menu hosted at desktop level under the same process
                $popupCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Menu)
                $popup = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, (New-Object System.Windows.Automation.AndCondition($pidCond, $popupCond)))
                if ($popup) { $subItems = @($popup.FindAll([System.Windows.Automation.TreeScope]::Descendants, $miCond)) | Where-Object { $_.Current.Name } }
            }
            if ($subItems.Count -eq 0) {
                # Tier 3: Electron - submenu MenuItems appear in the window tree, not under the Help item
                $subItems = @($window.FindAll([System.Windows.Automation.TreeScope]::Descendants, $miCond)) | Where-Object { $_.Current.Name -and $result.MenuBarItems -notcontains $_.Current.Name }
            }
            $result.HelpMenuItems = @($subItems | ForEach-Object { $_.Current.Name })

            $aboutItem = $subItems | Where-Object { Test-AboutLikeName -Text $_.Current.Name } | Select-Object -First 1
            if ($aboutItem) {
                $inv = $null
                if ($aboutItem.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$inv)) {
                    $inv.Invoke()
                    $result.AboutItemName = $aboutItem.Current.Name
                    $result.Method = "UIAMenu:$($topCandidate.Name)"
                    $invoked = $true
                }
            }
            if (-not $invoked -and $expand) {
                try { $expand.Collapse() } catch { }
            }
        }
    }

    # --- Path 2: classic Win32 menu fallback (GetMenu + WM_COMMAND, no focus needed) ---
    if (-not $invoked) {
        Add-Win32MenuType
        $hMenu = [Win32.NativeMenu]::GetMenu($process.MainWindowHandle)
        if ($hMenu -ne [IntPtr]::Zero) {
            $topCount = [Win32.NativeMenu]::GetMenuItemCount($hMenu)
            $topNames = @()
            $topSubMenus = New-Object System.Collections.Generic.List[object]
            for ($i = 0; $i -lt $topCount; $i++) {
                $sb = New-Object System.Text.StringBuilder 256
                [void][Win32.NativeMenu]::GetMenuString($hMenu, $i, $sb, 256, [Win32.NativeMenu]::MF_BYPOSITION)
                $name = $sb.ToString()
                $topNames += $name
                $sub = [Win32.NativeMenu]::GetSubMenu($hMenu, $i)
                if ($sub -ne [IntPtr]::Zero) {
                    $topSubMenus.Add([pscustomobject]@{
                        Name = $name
                        Score = Get-TopMenuScore -Text $name -ProcessName $process.ProcessName
                        SubMenu = $sub
                    })
                }
            }
            $result.MenuBarItems = $topNames

            foreach ($subMenuInfo in @($topSubMenus | Sort-Object Score -Descending)) {
                if ($invoked) { break }

                $subCount = [Win32.NativeMenu]::GetMenuItemCount($subMenuInfo.SubMenu)
                $subNames = @()
                $aboutId = -1
                for ($i = 0; $i -lt $subCount; $i++) {
                    $sb = New-Object System.Text.StringBuilder 256
                    [void][Win32.NativeMenu]::GetMenuString($subMenuInfo.SubMenu, $i, $sb, 256, [Win32.NativeMenu]::MF_BYPOSITION)
                    $name = $sb.ToString()
                    $subNames += $name
                    if ($aboutId -lt 0 -and (Test-AboutLikeName -Text $name)) {
                        $aboutId = [Win32.NativeMenu]::GetMenuItemID($subMenuInfo.SubMenu, $i)
                        $result.AboutItemName = $name
                    }
                }
                $result.HelpMenuItems = $subNames

                if ($aboutId -ge 0) {
                    [void][Win32.NativeMenu]::PostMessage($process.MainWindowHandle, [Win32.NativeMenu]::WM_COMMAND, [IntPtr]$aboutId, [IntPtr]::Zero)
                    $result.Method = "Win32Menu:$($subMenuInfo.Name)"
                    $invoked = $true
                }
            }
        }
    }

    if (-not $invoked) {
        $fallbackCandidate = Find-AboutLikeAutomationElement -Window $window -Root $root -ProcessId $process.Id
        if ($fallbackCandidate) {
            $result.AboutItemName = $fallbackCandidate.Name
            $result.Method = "UIAElement:$($fallbackCandidate.ControlType)"
            $inv = $null
            if ($fallbackCandidate.Element.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$inv)) {
                $inv.Invoke()
                $invoked = $true
            }
        }
    }

    if (-not $invoked) {
        if ($result.HelpMenuItems.Count -gt 0) {
            $result.Message = "Help menu found but it contains no About item. Help items: $($result.HelpMenuItems -join ' | ')"
        } elseif ($result.MenuBarItems.Count -gt 0) {
            $result.Message = "Menu bar found but no Help menu. Menu items: $($result.MenuBarItems -join ', ')"
        } else {
            $result.Message = 'No menu bar could be found via UIA or Win32 menus.'
        }
        return $result
    }

    # --- Detect the About dialog: new top-level window of same PID, embedded dialog, or in-app pane ---
    $aboutWin = Find-AboutWindowForProcess -Root $root -Window $window -PidCondition $pidCond -MainWindowHandle $process.MainWindowHandle.ToInt32() -TimeoutMilliseconds 5000

    if (-not $aboutWin) {
        $result.Message = 'About command was invoked but no dialog appeared.'
        return $result
    }

    $result.DialogTitle = $aboutWin.Current.Name
    $result.DialogText = @($aboutWin.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) |
        ForEach-Object { $_.Current.Name } | Where-Object { $_ } | Select-Object -Unique

    if (-not $LeaveOpen) {
        $closed = $false
        $closePattern = $null
        if ($aboutWin.TryGetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern, [ref]$closePattern)) {
            # Electron advertises WindowPattern but Close() can throw - fall through to the Close button
            try { $closePattern.Close(); $closed = $true } catch { }
        }
        if (-not $closed) {
            $btnCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
            $closeBtn = @($aboutWin.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) |
                Where-Object { $_.Current.Name -match '^close$|^ok$|^x$' } | Select-Object -First 1
            if ($closeBtn) {
                $inv = $null
                if ($closeBtn.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$inv)) { $inv.Invoke() }
            }
        }
    }

    $result.Success = $true
    $result.Message = "About dialog opened and captured via $($result.Method)."
    return $result
}

Export-ModuleMember -Function Get-ProcessWindowInfo, Get-TargetProcess, Invoke-AboutDialogAutomation
