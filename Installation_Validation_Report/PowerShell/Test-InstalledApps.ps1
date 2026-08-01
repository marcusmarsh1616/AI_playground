$targets = @(
  @{Name='Microsoft Edge'; Path='C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'; Args='--new-window https://example.com'},
  @{Name='Google Chrome'; Path='C:\Program Files\Google\Chrome\Application\chrome.exe'; Args='--new-window https://example.com'},
  @{Name='Notepad'; Path='notepad.exe'; Args=''},
  @{Name='Paint'; Path='mspaint.exe'; Args=''}
)

foreach ($t in $targets) {
  Write-Host "=== $($t.Name) ==="
  if (-not (Test-Path $t.Path)) {
    Write-Host 'Binary not found'
    Write-Host ''
    continue
  }

  $p = Start-Process -FilePath $t.Path -ArgumentList $t.Args -PassThru
  if (-not $p) {
    Write-Host 'Failed to start process'
    Write-Host ''
    continue
  }

  Start-Sleep -Seconds 6
  & powershell -NoProfile -ExecutionPolicy Bypass -Command "& 'E:\AI_playground\FRB-Packaging-Tool\Installation_Validation_Report\PowerShell\Invoke-AboutDialogAutomation.ps1' -ApplicationName '$($t.Name)' -ProcessId $($p.Id) | Out-Null"
  Start-Sleep -Seconds 2
  Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
  Write-Host ''
}
