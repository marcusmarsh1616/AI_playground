param(
    [string]$ProcessName = '7zFM',
    [switch]$LeaveOpen
)

Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes

$proc = Get-Process -Name $ProcessName -ErrorAction Stop | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $proc) { Write-Host "FAIL: no process '$ProcessName' with a main window"; exit 1 }
Write-Host "STEP 1 - Process: $($proc.ProcessName) PID=$($proc.Id) Title='$($proc.MainWindowTitle)'"

$window = [System.Windows.Automation.AutomationElement]::FromHandle($proc.MainWindowHandle)

# Restore if minimized, then bring to foreground
$winPattern = $null
if ($window.TryGetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern, [ref]$winPattern)) {
    if ($winPattern.Current.WindowVisualState -eq [System.Windows.Automation.WindowVisualState]::Minimized) {
        $winPattern.SetWindowVisualState([System.Windows.Automation.WindowVisualState]::Normal)
        Start-Sleep -Milliseconds 500
    }
}
try { $window.SetFocus() } catch { Write-Host "WARN: SetFocus failed, continuing" }
Start-Sleep -Milliseconds 300

# STEP 2: find the menu bar and list its top-level items
$menuBarCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::MenuBar)
$menuBar = $window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $menuBarCond)
if (-not $menuBar) {
    # Some apps expose the menu as ControlType.Menu instead of MenuBar
    $menuCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Menu)
    $menuBar = $window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $menuCond)
}
if (-not $menuBar) {
    Write-Host "STEP 2 - No UIA menu bar; falling back to Win32 classic menu (GetMenu/WM_COMMAND)"

    Add-Type -Namespace Win32 -Name Menu -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr GetMenu(IntPtr hWnd);
[DllImport("user32.dll")] public static extern IntPtr GetSubMenu(IntPtr hMenu, int nPos);
[DllImport("user32.dll")] public static extern int GetMenuItemCount(IntPtr hMenu);
[DllImport("user32.dll")] public static extern int GetMenuItemID(IntPtr hMenu, int nPos);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetMenuString(IntPtr hMenu, int uIDItem, System.Text.StringBuilder lpString, int nMaxCount, int uFlag);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
public const int MF_BYPOSITION = 0x400;
public const uint WM_COMMAND = 0x0111;
'@

    $hMenu = [Win32.Menu]::GetMenu($proc.MainWindowHandle)
    if ($hMenu -eq [IntPtr]::Zero) { Write-Host "FAIL: window has no Win32 menu either"; exit 1 }

    $topCount = [Win32.Menu]::GetMenuItemCount($hMenu)
    $topNames = @()
    $helpSub = [IntPtr]::Zero
    for ($i = 0; $i -lt $topCount; $i++) {
        $sb = New-Object System.Text.StringBuilder 256
        [void][Win32.Menu]::GetMenuString($hMenu, $i, $sb, 256, [Win32.Menu]::MF_BYPOSITION)
        $name = $sb.ToString()
        $topNames += $name
        if (($name -replace '&','') -match '^help$|^\?$') { $helpSub = [Win32.Menu]::GetSubMenu($hMenu, $i) }
    }
    Write-Host "STEP 2 - Win32 menu bar items: $($topNames -join ', ')"
    if ($helpSub -eq [IntPtr]::Zero) { Write-Host "FAIL: no Help menu in Win32 menu"; exit 1 }

    $subCount = [Win32.Menu]::GetMenuItemCount($helpSub)
    $subNames = @()
    $aboutId = -1
    $aboutName = ''
    for ($i = 0; $i -lt $subCount; $i++) {
        $sb = New-Object System.Text.StringBuilder 256
        [void][Win32.Menu]::GetMenuString($helpSub, $i, $sb, 256, [Win32.Menu]::MF_BYPOSITION)
        $name = $sb.ToString()
        $subNames += $name
        if (($name -replace '&','') -match 'about') {
            $aboutId = [Win32.Menu]::GetMenuItemID($helpSub, $i)
            $aboutName = $name
        }
    }
    Write-Host "STEP 3 - Help menu contains: $($subNames -join ' | ')"
    if ($aboutId -lt 0) { Write-Host "FAIL: no About item in Help menu"; exit 1 }
    Write-Host "STEP 4 - About item found: '$aboutName' (command id $aboutId)"

    [void][Win32.Menu]::PostMessage($proc.MainWindowHandle, [Win32.Menu]::WM_COMMAND, [IntPtr]$aboutId, [IntPtr]::Zero)
    Write-Host "STEP 5 - WM_COMMAND posted"
    Start-Sleep -Milliseconds 1200

    # Jump straight to dialog detection
    $pidCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $proc.Id)
    $winCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Window)
    $both = New-Object System.Windows.Automation.AndCondition($pidCond, $winCond)
    $root = [System.Windows.Automation.AutomationElement]::RootElement
    $aboutWin = @($root.FindAll([System.Windows.Automation.TreeScope]::Children, $both)) |
        Where-Object { $_.Current.NativeWindowHandle -ne $proc.MainWindowHandle.ToInt32() } | Select-Object -First 1
    if (-not $aboutWin) { $aboutWin = $window.FindFirst([System.Windows.Automation.TreeScope]::Children, $winCond) }
    if (-not $aboutWin) { Write-Host "FAIL: About dialog did not appear"; exit 1 }

    Write-Host "STEP 6 - Dialog opened: '$($aboutWin.Current.Name)'"
    $texts = @($aboutWin.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) |
        ForEach-Object { $_.Current.Name } | Where-Object { $_ } | Select-Object -Unique
    Write-Host "STEP 7 - Dialog contents:"
    $texts | ForEach-Object { Write-Host "  $_" }

    if ($LeaveOpen) {
        Write-Host "STEP 8 - Dialog left open as requested"
    } else {
        $closePattern = $null
        if ($aboutWin.TryGetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern, [ref]$closePattern)) {
            $closePattern.Close()
            Write-Host "STEP 8 - Dialog closed"
        }
    }
    Write-Host "SUCCESS: full Help -> About flow completed (Win32 menu path)"
    exit 0
}

$menuItems = $menuBar.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)
Write-Host "STEP 2 - Menu bar items: $(@($menuItems | ForEach-Object { $_.Current.Name }) -join ', ')"

$helpItem = $menuItems | Where-Object { $_.Current.Name -match '^help$|^\?$' } | Select-Object -First 1
if (-not $helpItem) { Write-Host "FAIL: no Help menu"; exit 1 }

# STEP 3: expand Help and list what's inside
$expand = $null
if ($helpItem.TryGetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern, [ref]$expand)) {
    $expand.Expand()
} else {
    $invoke = $null
    if ($helpItem.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$invoke)) { $invoke.Invoke() }
}
Start-Sleep -Milliseconds 500

# Submenu items appear as children of the Help item after expansion (or in a popup menu)
$subItems = @($helpItem.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition))
if ($subItems.Count -eq 0) {
    # fallback: popup menu is hosted at desktop level under this process
    $root = [System.Windows.Automation.AutomationElement]::RootElement
    $pidCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $proc.Id)
    $menuCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Menu)
    $both = New-Object System.Windows.Automation.AndCondition($pidCond, $menuCond)
    $popup = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $both)
    if ($popup) { $subItems = @($popup.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)) }
}
Write-Host "STEP 3 - Help menu contains: $(@($subItems | ForEach-Object { $_.Current.Name }) -join ' | ')"

$aboutItem = $subItems | Where-Object { $_.Current.Name -match 'about' } | Select-Object -First 1
if (-not $aboutItem) { Write-Host "FAIL: no About item inside Help menu"; exit 1 }
Write-Host "STEP 4 - About item found: '$($aboutItem.Current.Name)'"

# STEP 5: invoke it
$invoke = $null
if ($aboutItem.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$invoke)) {
    $invoke.Invoke()
} else { Write-Host "FAIL: About item does not support Invoke"; exit 1 }
Start-Sleep -Milliseconds 1000

# STEP 6: find the About dialog (new window in same process) and read its text
$pidCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $proc.Id)
$winCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Window)
$both = New-Object System.Windows.Automation.AndCondition($pidCond, $winCond)
$root = [System.Windows.Automation.AutomationElement]::RootElement
$windows = @($root.FindAll([System.Windows.Automation.TreeScope]::Children, $both))
$aboutWin = $windows | Where-Object { $_.Current.NativeWindowHandle -ne $proc.MainWindowHandle.ToInt32() } | Select-Object -First 1
if (-not $aboutWin) { $aboutWin = $window.FindFirst([System.Windows.Automation.TreeScope]::Children, $winCond) }
if (-not $aboutWin) { Write-Host "FAIL: About dialog did not appear"; exit 1 }

Write-Host "STEP 6 - Dialog opened: '$($aboutWin.Current.Name)'"
$texts = @($aboutWin.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) |
    ForEach-Object { $_.Current.Name } | Where-Object { $_ } | Select-Object -Unique
Write-Host "STEP 7 - Dialog contents:"
$texts | ForEach-Object { Write-Host "  $_" }

# STEP 8: close the dialog
if ($LeaveOpen) {
    Write-Host "STEP 8 - Dialog left open as requested"
} else {
    $closePattern = $null
    if ($aboutWin.TryGetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern, [ref]$closePattern)) {
        $closePattern.Close()
        Write-Host "STEP 8 - Dialog closed"
    }
}
Write-Host "SUCCESS: full Help -> About flow completed"
