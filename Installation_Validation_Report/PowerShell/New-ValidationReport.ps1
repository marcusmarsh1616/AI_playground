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

function Get-ChecklistHtml {
    param(
        [Parameter(Mandatory=$false)]
        [object]$Items,

        [Parameter(Mandatory=$false)]
        [string]$FallbackText = 'No findings were identified.',

        [Parameter(Mandatory=$false)]
        [switch]$UseCheckmark
    )

    if (-not $Items) {
        return "<li>$FallbackText</li>"
    }

    $listItems = New-Object System.Collections.Generic.List[string]

    foreach ($item in @($Items)) {
        if ($null -eq $item) {
            continue
        }

        $text = [string]$item
        if ([string]::IsNullOrWhiteSpace($text)) {
            continue
        }

        if ($UseCheckmark) {
            $listItems.Add("<li><span class='checkmark'>☒</span> $text</li>")
        } else {
            $listItems.Add("<li>$text</li>")
        }
    }

    if ($listItems.Count -eq 0) {
        return "<li>$FallbackText</li>"
    }

    return ($listItems -join "`n")
}

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
    $appName = if ($Data.Application) { $Data.Application } else { "[Application Name]" }
    $version = if ($Data.Version) { $Data.Version } else { "[Version]" }
    $generatedBy = if ($Data.GeneratedBy) { $Data.GeneratedBy } else { "[Tech Name]" }
    $generatedDate = if ($Data.GeneratedDate) { $Data.GeneratedDate } else { "[Date]" }
    $ticketNumber = if ($Data.TicketNumber) { $Data.TicketNumber } else { "TTxxxxx" }
    $osValue = if ($Data.OperatingSystem) { $Data.OperatingSystem } else { "[OS Version]" }

    $report = $report -replace '\[Application Name\]', $appName
    $report = $report -replace '\[Version\]', $version
    $report = $report -replace '\[TT#####\]', $ticketNumber
    $report = $report -replace '\[Tech Name\]', $generatedBy
    $report = $report -replace '\[Date\]', $generatedDate
    $report = $report -replace '\[OS Version\]', $osValue
    $report = $report -replace '\[Operating System compatibility details\]', $osValue
    $report = $report -replace '\[Application\]', $appName
    
    # Add web research data if available
    if ($Data.WebResearch -and $Data.WebResearch.success) {
        $requirements = $Data.WebResearch.requirements

        $osHtml = Get-ChecklistHtml -Items $requirements.operating_system -FallbackText 'No specific operating-system requirement was identified in the research data.' -UseCheckmark
        $report = $report -replace '\[OS_COMPATIBILITY_CONTENT\]', $osHtml

        $conflictHtml = Get-ChecklistHtml -Items $requirements.conflicts -FallbackText 'No application conflicts were identified in the available research data.'
        $report = $report -replace '\[CONFLICT_CONTENT\]', $conflictHtml

        $prereqHtml = Get-ChecklistHtml -Items $requirements.prerequisites -FallbackText 'No additional prerequisites were identified in the available research data.'
        $report = $report -replace '\[PREREQUISITE_CONTENT\]', $prereqHtml

        $upgradeHtml = Get-ChecklistHtml -Items $requirements.upgrade_path -FallbackText 'No upgrade-path information was identified in the available research data.'
        $report = $report -replace '\[UPGRADE_PATH_CONTENT\]', $upgradeHtml
    } else {
        $report = $report -replace '\[OS_COMPATIBILITY_CONTENT\]', "<li>No research data was available for operating-system compatibility.</li>"
        $report = $report -replace '\[CONFLICT_CONTENT\]', "<li>No research data was available for conflicts.</li>"
        $report = $report -replace '\[PREREQUISITE_CONTENT\]', "<li>No research data was available for prerequisites.</li>"
        $report = $report -replace '\[UPGRADE_PATH_CONTENT\]', "<li>No research data was available for upgrade paths.</li>"
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
