#Requires -Version 5.1

<#
.SYNOPSIS
    ErrorHandler Module - Centralized error handling
.DESCRIPTION
    Provides standardized error handling, user-friendly error dialogs,
    and detailed error context for troubleshooting.
.NOTES
    Author: FRB Automation Team
    Created: June 5, 2026
    Version: 1.0.0
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Invoke-SafeOperation {
    <#
    .SYNOPSIS
        Execute an operation with error handling
    .PARAMETER Operation
        ScriptBlock to execute
    .PARAMETER ErrorMessage
        Custom error message
    .PARAMETER ShowDialog
        Show error dialog if operation fails
    .PARAMETER Component
        Component name for logging
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ScriptBlock]$Operation,
        
        [Parameter(Mandatory = $false)]
        [string]$ErrorMessage = "Operation failed",
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowDialog,
        
        [Parameter(Mandatory = $false)]
        [string]$Component = "Unknown"
    )
    
    try {
        $result = & $Operation
        return @{
            Success = $true
            Result = $result
            Error = $null
        }
    }
    catch {
        $errorDetails = Get-DetailedError -ErrorRecord $_
        
        # Log error if logger is available
        if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
            Write-AppLog "$ErrorMessage`: $($errorDetails.Message)" -Level Error -Component $Component -Exception $_.Exception
        }
        
        # Show dialog if requested
        if ($ShowDialog) {
            Show-ErrorDialog -Title $ErrorMessage `
                           -Message $errorDetails.Message `
                           -Details $errorDetails.FullDetails
        }
        
        return @{
            Success = $false
            Result = $null
            Error = $errorDetails
        }
    }
}

function Get-DetailedError {
    <#
    .SYNOPSIS
        Extract detailed error information from an error record
    .PARAMETER ErrorRecord
        The error record to analyze
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    
    $details = @{
        Message = $ErrorRecord.Exception.Message
        Type = $ErrorRecord.Exception.GetType().FullName
        StackTrace = $ErrorRecord.Exception.StackTrace
        ScriptStackTrace = $ErrorRecord.ScriptStackTrace
        PositionMessage = $ErrorRecord.InvocationInfo.PositionMessage
        CategoryInfo = $ErrorRecord.CategoryInfo.ToString()
        FullyQualifiedErrorId = $ErrorRecord.FullyQualifiedErrorId
        Timestamp = Get-Date
    }
    
    # Create formatted full details
    $fullDetails = @"
Error Message: $($details.Message)

Error Type: $($details.Type)

Category: $($details.CategoryInfo)

Location: $($details.PositionMessage)

Stack Trace:
$($details.StackTrace)

Script Stack Trace:
$($details.ScriptStackTrace)

Timestamp: $($details.Timestamp)
"@
    
    $details['FullDetails'] = $fullDetails
    
    return $details
}

function Show-ErrorDialog {
    <#
    .SYNOPSIS
        Display a user-friendly error dialog
    .PARAMETER Title
        Dialog title
    .PARAMETER Message
        Main error message
    .PARAMETER Details
        Detailed error information
    .PARAMETER ShowLog
        Show button to open logs
    .PARAMETER Suggestions
        Array of suggested fixes
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$Details,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowLog,
        
        [Parameter(Mandatory = $false)]
        [string[]]$Suggestions
    )
    
    # Create form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.Size = New-Object System.Drawing.Size(600, 500)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true
    
    # Icon label
    $lblIcon = New-Object System.Windows.Forms.Label
    $lblIcon.Text = "?"
    $lblIcon.Font = New-Object System.Drawing.Font("Segoe UI", 32)
    $lblIcon.Location = New-Object System.Drawing.Point(20, 20)
    $lblIcon.Size = New-Object System.Drawing.Size(60, 60)
    $lblIcon.ForeColor = [System.Drawing.Color]::Red
    $form.Controls.Add($lblIcon)
    
    # Message label
    $lblMessage = New-Object System.Windows.Forms.Label
    $lblMessage.Text = $Message
    $lblMessage.Location = New-Object System.Drawing.Point(90, 20)
    $lblMessage.Size = New-Object System.Drawing.Size(480, 60)
    $lblMessage.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $form.Controls.Add($lblMessage)
    
    # Suggestions section
    $yPos = 90
    if ($Suggestions -and $Suggestions.Count -gt 0) {
        $lblSuggestionsTitle = New-Object System.Windows.Forms.Label
        $lblSuggestionsTitle.Text = "How to fix:"
        $lblSuggestionsTitle.Location = New-Object System.Drawing.Point(20, $yPos)
        $lblSuggestionsTitle.Size = New-Object System.Drawing.Size(560, 20)
        $lblSuggestionsTitle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        $form.Controls.Add($lblSuggestionsTitle)
        $yPos += 25
        
        foreach ($suggestion in $Suggestions) {
            $lblSuggestion = New-Object System.Windows.Forms.Label
            $lblSuggestion.Text = "- $suggestion"
            $lblSuggestion.Location = New-Object System.Drawing.Point(30, $yPos)
            $lblSuggestion.Size = New-Object System.Drawing.Size(550, 40)
            $lblSuggestion.Font = New-Object System.Drawing.Font("Segoe UI", 9)
            $form.Controls.Add($lblSuggestion)
            $yPos += 30
        }
        $yPos += 10
    }
    
    # Details section
    if ($Details) {
        $lblDetailsTitle = New-Object System.Windows.Forms.Label
        $lblDetailsTitle.Text = "Technical Details:"
        $lblDetailsTitle.Location = New-Object System.Drawing.Point(20, $yPos)
        $lblDetailsTitle.Size = New-Object System.Drawing.Size(560, 20)
        $lblDetailsTitle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        $form.Controls.Add($lblDetailsTitle)
        $yPos += 25
        
        $txtDetails = New-Object System.Windows.Forms.TextBox
        $txtDetails.Multiline = $true
        $txtDetails.ScrollBars = "Both"
        $txtDetails.Location = New-Object System.Drawing.Point(20, $yPos)
        $txtDetails.Size = New-Object System.Drawing.Size(560, 220)
        $txtDetails.Font = New-Object System.Drawing.Font("Consolas", 8)
        $txtDetails.Text = $Details
        $txtDetails.ReadOnly = $true
        $form.Controls.Add($txtDetails)
        $yPos += 230
    }
    
    # Buttons
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "OK"
    $btnOK.Location = New-Object System.Drawing.Point(380, $yPos)
    $btnOK.Size = New-Object System.Drawing.Size(90, 30)
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($btnOK)
    
    $btnCopy = New-Object System.Windows.Forms.Button
    $btnCopy.Text = "Copy Error"
    $btnCopy.Location = New-Object System.Drawing.Point(280, $yPos)
    $btnCopy.Size = New-Object System.Drawing.Size(90, 30)
    $btnCopy.Add_Click({
        [System.Windows.Forms.Clipboard]::SetText($Details)
        [System.Windows.Forms.MessageBox]::Show("Error details copied to clipboard", "Copied", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    })
    $form.Controls.Add($btnCopy)
    
    if ($ShowLog) {
        $btnOpenLog = New-Object System.Windows.Forms.Button
        $btnOpenLog.Text = "Open Logs"
        $btnOpenLog.Location = New-Object System.Drawing.Point(180, $yPos)
        $btnOpenLog.Size = New-Object System.Drawing.Size(90, 30)
        $btnOpenLog.Add_Click({
            $logPath = Join-Path $PSScriptRoot "..\..\logs"
            if (Test-Path $logPath) {
                Start-Process explorer.exe -ArgumentList $logPath
            } else {
                [System.Windows.Forms.MessageBox]::Show("Log folder not found: $logPath", "Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            }
        })
        $form.Controls.Add($btnOpenLog)
    }
    
    $form.AcceptButton = $btnOK
    $form.ShowDialog() | Out-Null
}

function Show-SuccessDialog {
    <#
    .SYNOPSIS
        Display a success message dialog
    .PARAMETER Title
        Dialog title
    .PARAMETER Message
        Success message
    .PARAMETER Details
        Additional details
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$Details
    )
    
    $fullMessage = $Message
    if ($Details) {
        $fullMessage += "`n`n$Details"
    }
    
    [System.Windows.Forms.MessageBox]::Show(
        $fullMessage,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
}

function Show-WarningDialog {
    <#
    .SYNOPSIS
        Display a warning message dialog
    .PARAMETER Title
        Dialog title
    .PARAMETER Message
        Warning message
    .PARAMETER Details
        Additional details
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$Details
    )
    
    $fullMessage = $Message
    if ($Details) {
        $fullMessage += "`n`n$Details"
    }
    
    [System.Windows.Forms.MessageBox]::Show(
        $fullMessage,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
}

function Copy-ErrorToClipboard {
    <#
    .SYNOPSIS
        Copy error details to clipboard
    .PARAMETER ErrorDetails
        Error details object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ErrorDetails
    )
    
    [System.Windows.Forms.Clipboard]::SetText($ErrorDetails.FullDetails)
}

# Export functions
Export-ModuleMember -Function Invoke-SafeOperation, Get-DetailedError, Show-ErrorDialog, Show-SuccessDialog, Show-WarningDialog, Copy-ErrorToClipboard

