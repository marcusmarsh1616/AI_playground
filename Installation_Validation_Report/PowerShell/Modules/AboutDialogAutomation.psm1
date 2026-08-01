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
        # Strip & (Win32) and _ (WPF) accelerator markers before matching
        $helpItem = $topItems | Where-Object { ($_.Current.Name -replace '[&_]','') -match '^help$|^\?$' } | Select-Object -First 1

        if ($helpItem) {
            $miCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::MenuItem)

            $expand = $null
            if ($helpItem.TryGetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern, [ref]$expand)) {
                $expand.Expand()
            } else {
                $inv = $null
                if ($helpItem.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$inv)) { $inv.Invoke() }
            }
            Start-Sleep -Milliseconds 700
            # Expand can toggle an already-open menu closed - re-expand if needed
            if ($expand -and $expand.Current.ExpandCollapseState -eq [System.Windows.Automation.ExpandCollapseState]::Collapsed) {
                $expand.Expand()
                Start-Sleep -Milliseconds 700
            }

            # Tier 1: submenu items as descendants of the Help item (WPF, WinForms)
            $subItems = @($helpItem.FindAll([System.Windows.Automation.TreeScope]::Descendants, $miCond)) | Where-Object { $_.Current.Name }
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

            $aboutItem = $subItems | Where-Object { ($_.Current.Name -replace '[&_]','') -match 'about' } | Select-Object -First 1
            if ($aboutItem) {
                $inv = $null
                if ($aboutItem.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$inv)) {
                    $inv.Invoke()
                    $result.AboutItemName = $aboutItem.Current.Name
                    $result.Method = 'UIAMenu'
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
            $helpSub = [IntPtr]::Zero
            for ($i = 0; $i -lt $topCount; $i++) {
                $sb = New-Object System.Text.StringBuilder 256
                [void][Win32.NativeMenu]::GetMenuString($hMenu, $i, $sb, 256, [Win32.NativeMenu]::MF_BYPOSITION)
                $name = $sb.ToString()
                $topNames += $name
                if (($name -replace '[&_]','') -match '^help$|^\?$') { $helpSub = [Win32.NativeMenu]::GetSubMenu($hMenu, $i) }
            }
            $result.MenuBarItems = $topNames

            if ($helpSub -ne [IntPtr]::Zero) {
                $subCount = [Win32.NativeMenu]::GetMenuItemCount($helpSub)
                $subNames = @()
                $aboutId = -1
                for ($i = 0; $i -lt $subCount; $i++) {
                    $sb = New-Object System.Text.StringBuilder 256
                    [void][Win32.NativeMenu]::GetMenuString($helpSub, $i, $sb, 256, [Win32.NativeMenu]::MF_BYPOSITION)
                    $name = $sb.ToString()
                    $subNames += $name
                    if ($aboutId -lt 0 -and ($name -replace '[&_]','') -match 'about') {
                        $aboutId = [Win32.NativeMenu]::GetMenuItemID($helpSub, $i)
                        $result.AboutItemName = $name
                    }
                }
                $result.HelpMenuItems = $subNames

                if ($aboutId -ge 0) {
                    [void][Win32.NativeMenu]::PostMessage($process.MainWindowHandle, [Win32.NativeMenu]::WM_COMMAND, [IntPtr]$aboutId, [IntPtr]::Zero)
                    $result.Method = 'Win32Menu'
                    $invoked = $true
                }
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

    Start-Sleep -Milliseconds 1200

    # --- Detect the About dialog: new top-level window of same PID, or in-app dialog window (Electron) ---
    $winCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Window)
    $aboutWin = @($root.FindAll([System.Windows.Automation.TreeScope]::Children, (New-Object System.Windows.Automation.AndCondition($pidCond, $winCond)))) |
        Where-Object { $_.Current.NativeWindowHandle -ne $process.MainWindowHandle.ToInt32() } | Select-Object -First 1
    if (-not $aboutWin) { $aboutWin = $window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $winCond) }

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
