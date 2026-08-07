$software = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*Articulate 360*" } | Select-Object DisplayName, DisplayVersion, Publisher, UninstallString, InstallLocation |
Format-List
Start-Process -FilePath "$env:windir\SysWOW64\msiexec.exe" -ArgumentList "/x", "$software", "/quiet", "/norestart" -Wait

