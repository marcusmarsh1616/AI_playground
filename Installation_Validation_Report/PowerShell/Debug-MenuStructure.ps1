param([int]$TargetPid)
Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes

$proc = Get-Process -Id $TargetPid -ErrorAction Stop
Write-Host "Process: $($proc.ProcessName) PID=$($proc.Id) HWND=$($proc.MainWindowHandle) Title='$($proc.MainWindowTitle)'"
if ($proc.MainWindowHandle -eq 0) { Write-Host "No main window handle"; exit 1 }

$window = [System.Windows.Automation.AutomationElement]::FromHandle($proc.MainWindowHandle)

Write-Host "`n--- MenuBar search (Descendants) ---"
$mbCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::MenuBar)
$mb = $window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $mbCond)
Write-Host "MenuBar found: $(if ($mb) { "'$($mb.Current.Name)' class=$($mb.Current.ClassName)" } else { 'NO' })"

Write-Host "`n--- Menu search (Descendants) ---"
$mCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Menu)
$menus = @($window.FindAll([System.Windows.Automation.TreeScope]::Descendants, $mCond))
Write-Host "Menus found: $($menus.Count)"
foreach ($m in $menus) {
    Write-Host "  Menu '$($m.Current.Name)' class=$($m.Current.ClassName) autoId=$($m.Current.AutomationId)"
    @($m.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)) |
        ForEach-Object { Write-Host "    child: [$($_.Current.ControlType.ProgrammaticName)] '$($_.Current.Name)'" }
}

Write-Host "`n--- MenuItem search (Descendants) ---"
$miCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::MenuItem)
$items = @($window.FindAll([System.Windows.Automation.TreeScope]::Descendants, $miCond))
Write-Host "MenuItems found: $($items.Count)"
$items | Select-Object -First 15 | ForEach-Object { Write-Host "  '$($_.Current.Name)' class=$($_.Current.ClassName)" }

Write-Host "`n--- Win32 GetMenu ---"
Add-Type -Namespace Win32 -Name M -MemberDefinition '[DllImport("user32.dll")] public static extern IntPtr GetMenu(IntPtr hWnd);'
$h = [Win32.M]::GetMenu($proc.MainWindowHandle)
Write-Host "GetMenu: $h"

Write-Host "`n--- Top-level window children ---"
@($window.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)) |
    ForEach-Object { Write-Host "  [$($_.Current.ControlType.ProgrammaticName)] '$($_.Current.Name)' class=$($_.Current.ClassName)" }
