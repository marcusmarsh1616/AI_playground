#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ApplicationName,

    [Parameter(Mandatory=$false)]
    [int]$ProcessId,

    [Parameter(Mandatory=$false)]
    [switch]$LeaveOpen
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $scriptRoot 'Modules\AboutDialogAutomation.psm1') -Force

$result = Invoke-AboutDialogAutomation -ApplicationName $ApplicationName -ProcessId $ProcessId -LeaveOpen:$LeaveOpen

if ($result.Success) {
    Write-Host "Method: $($result.Method)" -ForegroundColor Green
    Write-Host "Process: $($result.ProcessName) (PID $($result.ProcessId))" -ForegroundColor Cyan
    Write-Host "Menu bar: $($result.MenuBarItems -join ', ')" -ForegroundColor Cyan
    Write-Host "Help menu: $($result.HelpMenuItems -join ' | ')" -ForegroundColor Cyan
    Write-Host "About item: $($result.AboutItemName)" -ForegroundColor Cyan
    Write-Host "Dialog title: $($result.DialogTitle)" -ForegroundColor Green
    Write-Host "Dialog text:" -ForegroundColor Green
    $result.DialogText | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host $result.Message -ForegroundColor Yellow
}

$result
