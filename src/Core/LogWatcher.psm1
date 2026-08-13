function Start-InstallLogWatcher {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallContext,

        [Parameter(Mandatory = $true)]
        [scriptblock]$OnLine
    )

    Stop-InstallLogWatcher

    $watchRoot = if ($InstallContext -eq 'User') {
        Join-Path $env:TEMP 'InstallLogs'
    }
    else {
        "${env:CommonProgramFiles(x86)}\InstallLogs"
    }

    if (-not (Test-Path $watchRoot)) {
        return $null
    }

    $state = @{
        Root      = $watchRoot
        Offsets   = @{}
        OnLine    = $OnLine
        Watcher   = $null
        Handlers  = New-Object System.Collections.Generic.List[object]
    }

    foreach ($file in @(Get-ChildItem -Path $watchRoot -File -Include *.log, *.txt -ErrorAction SilentlyContinue)) {
        $state.Offsets[$file.FullName] = $file.Length
    }

    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $watchRoot
    $watcher.Filter = "*.*"
    $watcher.IncludeSubdirectories = $false
    $watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor [System.IO.NotifyFilters]::FileName
    $watcher.EnableRaisingEvents = $true

    $script:LogWatcherState = $state

    $tailAction = {
        param($fullPath)

        $st = $script:LogWatcherState
        if (-not $st -or $st.Root -ne (Split-Path $fullPath -Parent)) { return }
        if ($fullPath -notmatch '\.(log|txt)$') { return }

        try {
            $item = Get-Item -Path $fullPath -ErrorAction Stop
        }
        catch {
            return
        }

        $previousOffset = if ($st.Offsets.ContainsKey($fullPath)) { [long]$st.Offsets[$fullPath] } else { 0 }

        if ($item.Length -lt $previousOffset) {
            $previousOffset = 0
        }
        if ($item.Length -eq $previousOffset) {
            return
        }

        try {
            $stream = [System.IO.File]::Open($fullPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            $stream.Seek($previousOffset, [System.IO.SeekOrigin]::Begin) | Out-Null
            $reader = New-Object System.IO.StreamReader($stream)
            $newText = $reader.ReadToEnd()
            $reader.Close()
            $stream.Close()
        }
        catch {
            return
        }

        $st.Offsets[$fullPath] = $item.Length

        foreach ($line in ($newText -split "`r?`n")) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            & $st.OnLine $line (Split-Path $fullPath -Leaf)
        }
    }

    $onChanged = Register-ObjectEvent -InputObject $watcher -EventName Changed -Action {
        & $Event.MessageData $Event.SourceEventArgs.FullPath
    } -MessageData $tailAction

    $onCreated = Register-ObjectEvent -InputObject $watcher -EventName Created -Action {
        & $Event.MessageData $Event.SourceEventArgs.FullPath
    } -MessageData $tailAction

    $state.Watcher = $watcher
    [void]$state.Handlers.Add($onChanged)
    [void]$state.Handlers.Add($onCreated)

    return $state
}

function Stop-InstallLogWatcher {
    [CmdletBinding()]
    param()

    if (-not $script:LogWatcherState) { return }

    $state = $script:LogWatcherState

    foreach ($handler in @($state.Handlers)) {
        try { Unregister-Event -SourceIdentifier $handler.Name -ErrorAction SilentlyContinue } catch {}
    }

    if ($state.Watcher) {
        try {
            $state.Watcher.EnableRaisingEvents = $false
            $state.Watcher.Dispose()
        }
        catch {}
    }

    $script:LogWatcherState = $null
}

Export-ModuleMember -Function Start-InstallLogWatcher, Stop-InstallLogWatcher
