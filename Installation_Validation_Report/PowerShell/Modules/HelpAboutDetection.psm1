#Requires -Version 5.1
<#!
.SYNOPSIS
    Detect currently open Help/About style windows and capture verification info.

.DESCRIPTION
    Scans running processes for window titles that look like Help/About/Version dialogs
    and returns basic evidence such as the window title, process name, executable path,
    and version information from the executable.
#>

function Get-HelpAboutVerification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$ApplicationName
    )

    $patterns = @('about', 'help', 'version', 'info', 'license', 'properties', 'product', 'details')
    $results = New-Object System.Collections.Generic.List[object]

    $source = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class WindowDetector {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern int GetWindowTextLength(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMax);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    public static List<WindowInfo> GetVisibleWindows() {
        var windows = new List<WindowInfo>();
        EnumWindows((hWnd, lParam) => {
            if (!IsWindowVisible(hWnd)) {
                return true;
            }

            int length = GetWindowTextLength(hWnd);
            if (length <= 0) {
                return true;
            }

            var builder = new StringBuilder(length + 1);
            GetWindowText(hWnd, builder, builder.Capacity);
            string title = builder.ToString().Trim();
            if (string.IsNullOrWhiteSpace(title)) {
                return true;
            }

            uint processId = 0;
            GetWindowThreadProcessId(hWnd, out processId);
            windows.Add(new WindowInfo(hWnd, title, processId));
            return true;
        }, IntPtr.Zero);

        return windows;
    }

    public sealed class WindowInfo {
        public IntPtr Handle { get; private set; }
        public string Title { get; private set; }
        public uint ProcessId { get; private set; }

        public WindowInfo(IntPtr handle, string title, uint processId) {
            Handle = handle;
            Title = title;
            ProcessId = processId;
        }
    }
}
'@

try {
    Add-Type -TypeDefinition $source -Language CSharp -ErrorAction Stop
} catch {
    return @()
}

$windows = @([WindowDetector]::GetVisibleWindows())
foreach ($window in $windows) {
    $title = [string]$window.Title
    if ([string]::IsNullOrWhiteSpace($title)) {
        continue
    }

    $titleLower = $title.ToLowerInvariant()
    $matchedPattern = $null
    foreach ($pattern in $patterns) {
        if ($titleLower -like "*$pattern*") {
            $matchedPattern = $pattern
            break
        }
    }

    if (-not $matchedPattern) {
        continue
    }

    if ($ApplicationName) {
        $appNameLower = $ApplicationName.ToLowerInvariant()
        $process = Get-Process -Id $window.ProcessId -ErrorAction SilentlyContinue
        $processNameLower = if ($process) { $process.ProcessName.ToLowerInvariant() } else { $null }
        $nameMatches = $titleLower -like "*$appNameLower*" -or $processNameLower -like "*$appNameLower*"
        if ($appNameLower -ne 'all' -and -not $nameMatches) {
            continue
        }
    }

    $exePath = $null
    try {
        $processInfo = Get-CimInstance Win32_Process -Filter "ProcessId = $($window.ProcessId)" -ErrorAction SilentlyContinue
        if ($processInfo -and $processInfo.ExecutablePath) {
            $exePath = $processInfo.ExecutablePath
        }
    } catch {
        $exePath = $null
    }

    $productName = $null
    $companyName = $null
    $fileVersion = $null
    $productVersion = $null

    if ($exePath -and (Test-Path $exePath)) {
        try {
            $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($exePath)
            $productName = $versionInfo.ProductName
            $companyName = $versionInfo.CompanyName
            $fileVersion = $versionInfo.FileVersion
            $productVersion = $versionInfo.ProductVersion
        } catch {
            $productName = $null
        }
    }

    $results.Add([PSCustomObject]@{
        ProcessName = if ($process) { $process.ProcessName } else { $null }
        WindowTitle = $title
        MatchedPattern = $matchedPattern
        ExecutablePath = $exePath
        ProductName = $productName
        CompanyName = $companyName
        FileVersion = $fileVersion
        ProductVersion = $productVersion
    })
}

return $results.ToArray()
}

Export-ModuleMember -Function Get-HelpAboutVerification
