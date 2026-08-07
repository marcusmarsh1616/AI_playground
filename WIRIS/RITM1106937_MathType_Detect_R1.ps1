# INTERNAL FR/OFFICIAL USE // FRSONLY

<#
	.NOTES
	===========================================================================
	 Created with: 	PhoenixFrame Detection Method Generator
	 Created on:   	2026-08-03 12:55:54
	 Organization: 	NIT
	 Filename:     	RITM1106937_MathType_Detect_R1.ps1
	===========================================================================
	.DESCRIPTION
		The purpose of this script is to detect any installed versions of the application on the machine
		and to determine if that version is GREATER THAN OR EQUAL TO the target version.
		
		Application: ^MathType(?:\s|$)
		Target Version: 7.11.1 (minimum required)
		Vendor: WIRIS
		RITM: RITM1106937
		
	.PARAMETER Test
		Run in test mode - outputs what was found for validation
		Usage: .\RITM1106937_MathType_Detect_R1.ps1 -Test
#>
#region [DO NOT TOUCH]
[CmdletBinding()]
param
(
    [switch] $Test
)

function Get-InstalledVersion{
	<#
	.SYNOPSIS
		Get the version information on installed application by DisplayName or EXE version
	.DESCRIPTION
		Get DisplayVersion or file version and determine if it is GREATER THAN OR EQUAL TO the target version.
		Returns detailed findings in Test mode.
	.PARAMETER DetectType
		Choose whether you are going to look for the File version or the GUID DisplayVersion.
	.PARAMETER SearchArray
		Hashtable of applications/files to search for with their versions.
	.PARAMETER Regex
		Use regex matching for application names.
	.PARAMETER Context
		System (HKLM) or User (HKCU) registry context.
	.EXAMPLE
		Get-InstalledVersion -DetectType 'File' -SearchArray @{'C:\Program Files\App\app.exe' = '1.0.0'}
		Get-InstalledVersion -DetectType 'default' -SearchArray @{'Adobe Acrobat' = '2024.1.0'} -Context 'System'
	.NOTES
		Version Comparison: Uses PowerShell [version] type for >= comparison
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
	
	$resultFinal = [System.Collections.ArrayList]::new()
	$testResults = @()  # For Test mode output

	#region [Scriptblocks]
	[scriptblock]$DetectDefault = {
		param(
			$DisplayName,
			$DisplayVersion		
		)
		$regPaths = @("Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall","Registry::HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
		if ($Context -eq 'User') { $regPaths = @("Registry::HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall","Registry::HKCU\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall") }
		
		foreach ($path in $regPaths)
		{
			try {
				$installedApps = Get-ChildItem -Path:$path -ErrorAction SilentlyContinue | Get-ItemProperty | Where-Object{$PsItem.'DisplayName' -match $displayName}
				
				foreach($app in $installedApps)
				{
					try {
						[version]$installedVersion = $app.'DisplayVersion'
						
						if ($DetectType -eq 'Test') {
							$script:testResults += [PSCustomObject]@{
								DisplayName = $app.DisplayName
								InstalledVersion = $installedVersion.ToString()
								TargetVersion = $displayVersion.ToString()
								MeetsRequirement = ($installedVersion -ge $displayVersion)
								Comparison = if ($installedVersion -ge $displayVersion) { "PASS (>="} else { "FAIL (<)" }
								RegistryPath = $app.PSPath
							}
						}
						
						# CRITICAL: Check if installed version is GREATER THAN OR EQUAL TO target
						if($installedVersion -ge $displayVersion)
						{
							$null = $result.Add($true)
						}
					}
					catch {
						# Version parsing failed - log in test mode
						if ($DetectType -eq 'Test') {
							$script:testResults += [PSCustomObject]@{
								DisplayName = $app.DisplayName
								InstalledVersion = "ERROR: $($app.DisplayVersion)"
								TargetVersion = $displayVersion.ToString()
								MeetsRequirement = $false
								Comparison = "ERROR (version parse failed)"
								RegistryPath = $app.PSPath
							}
						}
					}
				}
			}
			catch {
				# Registry read error - silent in normal mode, logged in test mode
				if ($DetectType -eq 'Test') {
					Write-Verbose "Registry read error: $path - $_"
				}
			}
		}
	}

	[scriptblock]$DetectFile = {
		param(
			$FilePath,
			$FileVersion		
		)
		if([System.IO.File]::Exists($filePath))
		{
			try {
				$versionInfo = (Get-Item $filePath).VersionInfo
				[version]$installedFileVersion = $versionInfo.ProductVersion.Replace(',','.').Split(' ')[0]
				
				if ($DetectType -eq 'Test') {
					$script:testResults += [PSCustomObject]@{
						DisplayName = $versionInfo.ProductName
						InstalledVersion = $installedFileVersion.ToString()
						TargetVersion = $fileVersion.ToString()
						MeetsRequirement = ($installedFileVersion -ge $fileVersion)
						Comparison = if ($installedFileVersion -ge $fileVersion) { "PASS (>=)" } else { "FAIL (<)" }
						FilePath = $filePath
					}
				}
				
				# CRITICAL: Check if installed version is GREATER THAN OR EQUAL TO target
				if($installedFileVersion -ge $fileVersion )
				{
					$null = $result.Add($true)
				}
			}
			catch {
				if ($DetectType -eq 'Test') {
					$script:testResults += [PSCustomObject]@{
						DisplayName = "Unknown"
						InstalledVersion = "ERROR"
						TargetVersion = $fileVersion.ToString()
						MeetsRequirement = $false
						Comparison = "ERROR (file read failed)"
						FilePath = $filePath
					}
				}
			}
		}
		else {
			if ($DetectType -eq 'Test') {
				$script:testResults += [PSCustomObject]@{
					DisplayName = "N/A"
					InstalledVersion = "NOT FOUND"
					TargetVersion = $fileVersion.ToString()
					MeetsRequirement = $false
					Comparison = "ERROR (file does not exist)"
					FilePath = $filePath
				}
			}
		}
	}
	#endregion

	$SearchArray.Keys | ForEach-Object {
		if ($DetectType -ne 'Test') {$DetectType = 'default'}
		$result = [System.Collections.ArrayList]::new()
		if (([System.IO.File]::Exists($PSItem)))
		{
			[string]$DetectType = 'File'
			[string]$fPath = $PSItem
			[version]$fVersion = $SearchArray.$PSItem
		}
		else
		{
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

		switch($DetectType) {
			'File' {& $DetectFile -FilePath $fPath -FileVersion $fVersion}
			default {& $DetectDefault -DisplayName $dName -DisplayVersion $dVersion}
		}

		if($result){
			$null = $resultFinal.Add($true)
		} else {
			$null = $resultFinal.Add($false)
		}
	}

	# Return test results if in Test mode
	if ($DetectType -eq 'Test') {
		return $testResults
	}

	if($resultFinal -notcontains $false){
		return $true
	}
}

if ($PSBoundParameters['Test']) {
    $detectType = 'Test'
}
#endregion [DO NOT TOUCH]

# Options
$useRegex = $true # For advanced searching, set this option to $true and use your own Regex values.
$installContext = 'System' # Determines which registry location to search. (i.e. "System = HKLM:" vs. "User = HKCU:")

# Application details
$appName = '^MathType(?:\s|$)'
$appVersion = '7.11.1'

# Enter the application(s) or file(s) you are looking for.
# NOTE: Version comparison is GREATER THAN OR EQUAL (>=)
# NOTE: $appName is pre-processed by generator (custom regex, smart pattern, or escaped literal)
$infoHash = @{
	$appName = $appVersion
}

#region [Detection Selection]
$detected = Get-InstalledVersion -DetectType $detectType -SearchArray $infoHash -Regex $useRegex -Context $installContext

# TEST MODE: Output detailed findings for validation
if ($Test) {
	Write-Host "" -ForegroundColor Cyan
	Write-Host "========================================" -ForegroundColor Cyan
	Write-Host "  DETECTION METHOD TEST RESULTS" -ForegroundColor Cyan
	Write-Host "========================================" -ForegroundColor Cyan
	Write-Host "" -ForegroundColor Cyan

	Write-Host "Search Pattern: $appName" -ForegroundColor White
	Write-Host "Target Version: $appVersion (minimum required)" -ForegroundColor White
	Write-Host "Context: $installContext" -ForegroundColor White
	Write-Host "Regex Enabled: $useRegex" -ForegroundColor White
	Write-Host "" -ForegroundColor Cyan
	
	if ($detected -and $detected.Count -gt 0) {
		Write-Host "[FOUND] $($detected.Count) application(s) found:" -ForegroundColor Green
		Write-Host "" -ForegroundColor Cyan
		
		$detected | ForEach-Object {
			$status = if ($_.MeetsRequirement) { "PASS" } else { "FAIL" }
			$color = if ($_.MeetsRequirement) { "Green" } else { "Red" }
			
			Write-Host "Application: $($_.DisplayName)" -ForegroundColor White
			Write-Host "  Installed Version: $($_.InstalledVersion)" -ForegroundColor White
			Write-Host "  Target Version:    $($_.TargetVersion)" -ForegroundColor White
			Write-Host "  Comparison:        $($_.Comparison)" -ForegroundColor $color
			Write-Host "  Status:            [$status]" -ForegroundColor $color
			if ($_.RegistryPath) {
				Write-Host "  Registry:          $($_.RegistryPath)" -ForegroundColor Gray
			}
			if ($_.FilePath) {
				Write-Host "  File Path:         $($_.FilePath)" -ForegroundColor Gray
			}
			Write-Host "" -ForegroundColor Cyan
		}
		
		$passCount = ($detected | Where-Object { $_.MeetsRequirement }).Count
		$failCount = ($detected | Where-Object { -not $_.MeetsRequirement }).Count
		
		Write-Host "Summary:" -ForegroundColor Cyan
		Write-Host "  Total Found:   $($detected.Count)" -ForegroundColor White
		Write-Host "  Pass (>=):     $passCount" -ForegroundColor Green
		Write-Host "  Fail (<):      $failCount" -ForegroundColor Red
		Write-Host "" -ForegroundColor Cyan
		
		if ($passCount -gt 0) {
			Write-Host "[DETECTION RESULT] Would return: DETECTED (exit 0)" -ForegroundColor Green
		} else {
			Write-Host "[DETECTION RESULT] Would return: NOT DETECTED (exit 1)" -ForegroundColor Red
			Write-Host "  Reason: No installed version meets minimum requirement" -ForegroundColor Yellow
		}
	} else {
		Write-Host "[NOT FOUND] No applications matching pattern '$appName'" -ForegroundColor Red
		Write-Host "" -ForegroundColor Cyan
		Write-Host "[DETECTION RESULT] Would return: NOT DETECTED (exit 1)" -ForegroundColor Red
		Write-Host "" -ForegroundColor Cyan
		Write-Host "Troubleshooting:" -ForegroundColor Yellow
		Write-Host "  1. Check if application is installed" -ForegroundColor White
		Write-Host "  2. Verify DisplayName in registry matches pattern" -ForegroundColor White
		Write-Host "  3. Check registry context (System vs User)" -ForegroundColor White
		Write-Host "  4. Try running without -Test to see Intune behavior" -ForegroundColor White
	}
	
	Write-Host "" -ForegroundColor Cyan
	Write-Host "========================================" -ForegroundColor Cyan
	exit 0  # Test mode always exits successfully
}

# NORMAL MODE: Intune detection
# Output text if detected (>= version found), output nothing if not detected
if ($detected) {
    Write-Host "Detected"
    exit 0
}
# No output = not detected (Intune interprets as not installed)
exit 1
#endregion [Detection Selection]
