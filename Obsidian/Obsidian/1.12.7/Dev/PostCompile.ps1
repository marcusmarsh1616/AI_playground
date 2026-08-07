<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2023 v5.8.219
	 Created by:   	Eric Blankenbaker
	 Organization: 	FRB
	 Filename:     	PostCompile.ps1
	===========================================================================
	.DESCRIPTION
		This is the Post-Compile executable for the EaaS Packaging PSADTWrapper. This application does the following:
			- Moves the Install.exe file from ".\bin\x64" to ".\" and deletes the ".\bin" directory. 
			- Signs the Install.exe (NOTE: Only if the EUS Certificate Signer application is installed)
			- Auto-generates the Detection Method PS1
#>

#region [INSTALL.EXE]
$sourcePath = "$PSScriptRoot\bin\x64\Install.exe"
$destPath = "$PSScriptRoot\Install.exe"

if (Test-Path $sourcePath)
{
	if (Test-Path $destPath)
	{
		Remove-Item -Path $destPath -Force
	}
	Move-Item -Path $sourcePath -Destination $destPath -Force
	Remove-Item -Path "$PSScriptRoot\bin" -Recurse -Force
}
#endregion [INSTALL.EXE]

#region [SIGN]
$signingTool = "$env:APPDATA\EUS\Certificate Signer\Certificate_Signing.ps1"

if (Test-Path $signingTool)
{
	Start-Process "C:\Program Files\PowerShell\7\pwsh.exe" -ArgumentList "`"$signingTool`" -pathtoworkwith `"$destPath`""
}
#endregion [SIGN]

#region [AUTOGEN DM]
# Grab variables from Startup.pss
$content = get-content "$PSScriptRoot\Startup.pss"
$appName = (($content -match '.+\[string\]\$appName = ')[0].split('=')[1] -replace "('|`")", '').Trim()
$appNameMask = (($content -match '.+\[string\]\$appNameMask = ')[0].split('=')[1] -replace "('|`"|\#.+)", '').Trim()
$detectVersion = (($content -match '.+\[string\]\$appVersion = ')[0].split('=')[1] -replace "('|`")", '').Trim()
switch ($appNameMask)
{
	'' {
		$detectName = $appName
	}
	default {
		$detectName = $appNameMask
	}
}

# Set initial variables for file and path names
$newDMName = "$($detectName.Replace(' ','-'))`_$detectVersion`_Detect_R1.ps1"
$DMPath = "$PSScriptRoot\$newDMName"

# Make a copy of the template file and rename
Copy-Item -Path "$PSScriptRoot\Template_Detect_R1.ps1" -Destination $DMPath

# Grab content, replace App Name and Version, save content
$content = Get-Content -Path $DMPath
$content.Replace('APPLICATION_NAME',$detectName).Replace('APPLICATION_VERSION',$detectVersion) | Set-Content -Path $DMPath -Force
#endregion [AUTOGEN DM]