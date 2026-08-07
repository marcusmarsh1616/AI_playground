<#
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2022 v5.8.202
	 Created on:   	7/1/2022 1:16 PM
	 Created by:   	k1nxcm3
	 Organization: 	NIT
	 Filename:     	Template_Detect_R1.ps1
	===========================================================================
	.DESCRIPTION
		The purpose of this script is to detect any installed versions of the application onthe machine
		and to determine if that version is equal to or newer.
#>
#region [DO NOT TOUCH]
[CmdletBinding()]
param
(
    [switch] $Test
)

#$ErrorActionPreference = "SilentlyContinue"

function Get-InstalledVersion{
	<#
	.SYNOPSIS
		Get the version information on installed application by DisplayName or EXE version
	.DESCRIPTION
		Get DisplayVersion or file version and determine if it is greater than or equal to the version being compared against.
	.PARAMETER DetectType
		Choose whether you are going to look for the File version or the GUID DisplayVersion.
	.PARAMETER FilePath
		Full path to the file that we need to find the version to.
	.PARAMETER FileVersion
		Version of the file that we are comparing the installed files to.
	.PARAMETER DisplayName
		DisplayName listed in the GUID that matches the application we are looking for. Be as specific as you can on the DisplayName without limiting
		it with version specific information, just incase the application has been autoupdated.
	.PARAMETER DisplayVersion
		Version we are comparing the application already installed to the one we are trying to install.
	.PARAMETER Bitness
		Determines which registry hive it will look through for the Uninstall. Default both
	.EXAMPLE
		Get-InstalledVersion -DetectType 'File' -FilePath "$env:ProgramFiles\Docker\Docker\Docker.exe" -FileVersion '14.1.2'
		Get-InstalledVersion -DetectType 'ARP' -DisplayName "Docker Desktop" -Version '14.1.2' # Usign default value by omitting -Bitness
		Get-InstalledVersion -DetectType 'ARP' -DisplayName "Docker Desktop" -Version '14.1.2' -Bitness '64' # Specifying searching in the 64bit registry only
	.NOTES
	.LINK
	#>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $false)]
		[string]$DetectType = 'default',
		[Parameter(Mandatory = $false)]
		[hashtable]$SearchArray,
		[Parameter(Mandatory = $false)]
		[boolean]$Regex = $false,
		[Parameter(Mandatory = $false)]
		[string]$Context = 'System'
	)
	
	# We will compile our results if we find multiple versions installed
	
	$resultFinal = [System.Collections.ArrayList]::new()

	#region [Scriptblocks]
	[scriptblock]$DetectDefault = {
		param(
			$DisplayName,
			$DisplayVersion		
		)
		# We look through both registry sections
		$regPaths = @("Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall","Registry::HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
		if ($Context -eq 'User') { $regPaths = @("Registry::HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall","Registry::HKCU\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall") }
		# Checking each path for regkey that matches the DisplayName we are looking for and grabbing the DisplayVersion for each one
		foreach ($path in $regPaths)
		{
			# List of installed versions
			$installedVersions = Get-ChildItem -Path:$path | Get-ItemProperty | Where-Object{$PsItem.'DisplayName' -match $displayName} | Foreach-Object {[version]$PSItem.'DisplayVersion'}
			# Enumerate through each version and see if it is greater than or equal to our installing version
			foreach($installed in $installedVersions)
			{
				if($installed -ge $displayVersion)
				{
					# If a version is -ge than the installing version, then we add a $true to our result list
					$null = $result.Add($true)
				}
			}
		}
	}

	[scriptblock]$DetectTest = {
		param(
			$DisplayName,
			$DisplayVersion		
		)

$sql = @"
SELECT
'32' as bitness
,[DisplayName0] as 'DisplayName'
--,[ProductName0] as 'ProductName'
,[Version0] as 'DisplayVersion'
,[Publisher0]  as 'Publisher'
,COUNT([ResourceID]) as 'InstallCount'
FROM [ConfigMgr2].[dbo].[v_GS_ADD_REMOVE_PROGRAMS]
where timestamp > DATEADD(Month, -6, GETDATE())
GROUP BY
[DisplayName0]
,[Version0]
,[Publisher0]

UNION

SELECT
'64' as bitness
,[DisplayName0] as 'DisplayName'
--,[ProductName0] as 'ProductName'
,[Version0] as 'DisplayVersion'
,[Publisher0]  as 'Publisher'
,COUNT([ResourceID]) as 'InstallCount'
FROM [ConfigMgr2].[dbo].[v_GS_ADD_REMOVE_PROGRAMS_64]
where timestamp > DATEADD(Month, -6, GETDATE())
GROUP BY
[DisplayName0]
,[Version0]
,[Publisher0]
ORDER BY DisplayName ASC;
"@

$sccmstringData = @"
Data Source=P3PwVSQL382a.rb.win.frb.org;
Initial Catalog=ConfigMgr2;
Integrated Security=SSPI;
Provider=SQLOLEDB;
"@

			$connection = New-Object System.Data.OleDb.OleDbConnection $sccmstringData
			$command = New-Object System.Data.OleDb.OleDbCommand $sql,$connection
			$connection.Open()
			$adapter = New-Object System.Data.OleDb.OleDbDataAdapter $command
			$dataset = New-Object System.Data.DataSet
			[void] $adapter.Fill($dataSet)
			$connection.Close()

			#cache the data
			$test = New-Object system.Collections.ArrayList

			$dataset.Tables.Rows | Where-Object{$PsItem.DisplayName -match $displayName} | Foreach-Object {
			$upgrade = $true
			try {
				$ver = [version]$psitem.DisplayVersion
			}
			catch {
				$ver = [Version]0.0.0
			}
			if($ver -ge $DisplayVersion)
			{
				# if the version is greater than or equal we will not upgrade it.
				$upgrade = $false
			}

			$test.Add(
				[PSCustomObject]@{
					Name = $psitem.DisplayName
					Version = $ver
					InstallCount = $psitem.installCount
					bitness = [int16]$psitem.bitness
					Upgrade = $upgrade
				}) > $null
			}

			$test | Sort-Object Version, InstallCount -Descending | Format-Table -AutoSize
		
	}

	[scriptblock]$DetectFile = {
		param(
			$FilePath,
			$FileVersion		
		)
		# Check to see if the file exists
		if([System.IO.File]::Exists($filePath))
		{
			# Checking to see what version is the file currently on the machine
			[version]$installedFileVersion = (Get-Item $filePath).VersionInfo.ProductVersion.Replace(',','.').Split(' ')[0]
			if($installedFileVersion -ge $fileVersion )
			{
				# If the version of the file on the machine is -ge, then we add a $true
				$null = $result.Add($true)
			}
		}
	}
	#endregion

	$SearchArray.Keys | ForEach-Object {
		if ($DetectType -ne 'Test') {$DetectType = 'default'}
		$result = [System.Collections.ArrayList]::new()
		if (([System.IO.File]::Exists($PSItem)))
		{
			# Set File Stuff		
			[string]$DetectType = 'File'
			[string]$fPath = $PSItem
			[version]$fVersion = $SearchArray.$PSItem
		}
		else
		{
			# SearchName will contain escape switches where name contains regex values when its converted; ie: "Google\ Chrome"
			if ($Regex)
			{
				$dName = $PSItem
			} 
			else 
			{
				$dName = [regex]::Escape("$PSItem")
			}
			[version]$dVersion = $SearchArray.$PSItem
		}

		# Run detection based on $DetectType with 'ARP' being the default.
		switch($DetectType) {
			'File' {& $DetectFile -FilePath $fPath -FileVersion $fVersion}
			'Test' {& $DetectTest -DisplayName $dName -DisplayVersion $dVersion}
			default {& $DetectDefault -DisplayName $dName -DisplayVersion $dVersion}
		}

		if($result){
			$null = $resultFinal.Add($true)
		} else {
			$null = $resultFinal.Add($false)
		}

	}

	# If our $resultFinal does not contain a $false, then we will return a $true
	if($resultFinal -notcontains $false){
		return $true
	}
}

if ($PSBoundParameters['Test']) {
    # -Test parameter was used
    $detectType = 'Test'
}
#endregion [DO NOT TOUCH]

# Options - 
$useRegex = $false # For advanced searching, set this option to $true and use your own Regex values.
$installContext = 'System' # Determines which registry location to search. (i.e. "System = HKLM:" vs. "User = HKCU:")

# Enter the application(s) or file(s) you are looking for.
$infoHash = @{
	# 'Adobe Captivate' = '12.2.0' ### NOTE: EXCLUDE VERSION FROM APP NAME ###
	# 'C:\Temp\setup.exe' = '1.2.3' ### NOTE: USE PRODUCT VERSION ###
	'' = ''
}

#region [Detection Selection]
Get-InstalledVersion -DetectType $detectType -SearchArray $infoHash -Regex $useRegex -Context $installContext
#endregion [Detection Selection]
