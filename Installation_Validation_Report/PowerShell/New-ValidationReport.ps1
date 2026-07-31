#Requires -Version 5.1
<#
.SYNOPSIS
    Generate validation report from collected data

.DESCRIPTION
    Creates comprehensive HTML validation report using template

.PARAMETER Data
    Hashtable containing all validation data

.PARAMETER OutputPath
    Directory for generated reports

.OUTPUTS
    Path to generated report file
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [hashtable]$Data,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\Reports"
)

function New-ValidationReport {
    param(
        [hashtable]$Data,
        [string]$OutputPath
    )
    
    $scriptPath = $MyInvocation.MyCommand.Path
    if (-not $scriptPath) {
        $scriptPath = $PSCommandPath
    }

    if (-not $scriptPath) {
        $scriptPath = Join-Path $PSScriptRoot "New-ValidationReport.ps1"
    }

    $scriptRoot = Split-Path -Parent $scriptPath
    $projectRoot = Split-Path -Parent $scriptRoot
    $templatePath = Join-Path $projectRoot "Templates\Professional-Validation-Template.html"
    
    # Verify template exists
    if (-not (Test-Path $templatePath)) {
        Write-Host "[ERROR] Template not found: $templatePath" -ForegroundColor Red
        throw "Template file missing"
    }
    
    # Create output directory
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }
    
    # Load template
    $template = Get-Content $templatePath -Raw -Encoding UTF8
    
    # Replace placeholders
    $report = $template
    
    # Basic info
    $appName = $Data.Application
    $version = if ($Data.Version) { $Data.Version } else { "Unknown" }
    
    $report = $report -replace '\[Application Name\]', $appName
    $report = $report -replace '\[Version\]', $version
    $report = $report -replace '\[Tech Name\]', $Data.GeneratedBy
    $report = $report -replace '\[Date\]', $Data.GeneratedDate
    
    # Add web research data if available
    if ($Data.WebResearch -and $Data.WebResearch.success) {
        $requirements = $Data.WebResearch.requirements
        
        # Operating System
        if ($requirements.operating_system -and $requirements.operating_system.Count -gt 0) {
            $osHtml = ($requirements.operating_system | ForEach-Object { 
                "<p><span class='checkmark'>OK</span> $_</p>" 
            }) -join "`n"
            
            $report = $report -replace '<p><span class="checkmark">.*?</span> Windows 10 x64 or Newer</p>', $osHtml
        }
        
        # Prerequisites
        if ($requirements.prerequisites -and $requirements.prerequisites.Count -gt 0) {
            $prereqHtml = "<table class='details-table'><tr><td>Component</td><td>Version</td><td>Status</td></tr>`n"
            
            foreach ($prereq in $requirements.prerequisites) {
                $prereqHtml += "<tr><td>$prereq</td><td>As Required</td><td><span class='checkmark'>OK</span> Required</td></tr>`n"
            }
            
            $prereqHtml += "</table>"
            
            # Find and replace prerequisites table
            $report = $report -replace '<table class="details-table">.*?</table>', $prereqHtml
        }
    }
    
    # Add installer data if available
    if ($Data.InstallerAnalysis) {
        $installer = $Data.InstallerAnalysis
        
        if ($installer.ProductName) {
            $report = $report -replace '\[Application\]', $installer.ProductName
        }
        
        if ($installer.ProductCode) {
            $report = $report -replace '\[Uninstall Registry Keys\]', "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$($installer.ProductCode)"
        }
    }
    
    # Generate filename
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $sanitizedName = $appName -replace '[\\/:*?"<>|]', '_'
    $fileName = "Validation_${sanitizedName}_${version}_${timestamp}.html"
    $reportPath = Join-Path $OutputPath $fileName
    
    # Save report
    $report | Set-Content $reportPath -Encoding UTF8
    
    Write-Host "[SUCCESS] Report generated: $reportPath" -ForegroundColor Green
    
    return $reportPath
}

# If run directly
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $Data) {
        throw "Data parameter is required when executing this script directly."
    }

    New-ValidationReport -Data $Data -OutputPath $OutputPath
}
