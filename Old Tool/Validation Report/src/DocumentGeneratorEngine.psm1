#Requires -Version 5.1
<#
.SYNOPSIS
    Document Generator Engine
    
.DESCRIPTION
    Document Generator Engine
    
.DESCRIPTION
    Generates professional installation validation documents from HTML template.
    Replaces placeholders with actual data and inserts screenshots.
    
.NOTES 
    Author: P1MAM08
    Date: 2026-07-09
    Version: 1.0.0
    Type: Engine (Self-contained, integrable)
    Original: ValidationDocGenerator.psm1
    Author: P1MAM08
    Date: 2026-07-09
    Version: 1.0.0
#>

# Module variables
$script:TemplatePath = ".\templates\Professional-Validation-Template.html"
$script:FigurePlaceholders = @{
    1 = "Installation Progress Dialog"
    2 = "Programs and Features Entry"
    3 = "Start Menu Shortcuts"
    4 = "Uninstall Progress Dialog"
}

#region Helper Functions

function Get-Base64Image {
    <#
    .SYNOPSIS
    Document Generator Engine
    
.DESCRIPTION
        Converts image file to Base64 for embedding in HTML
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ImagePath
    )
    
    if (-not (Test-Path $ImagePath)) {
        throw "Image not found: $ImagePath"
    }
    
    $imageBytes = [System.IO.File]::ReadAllBytes($ImagePath)
    $base64 = [Convert]::ToBase64String($imageBytes)
    
    # Determine MIME type
    $extension = [System.IO.Path]::GetExtension($ImagePath).ToLower()
    $mimeType = switch ($extension) {
        '.jpg'  { 'image/jpeg' }
        '.jpeg' { 'image/jpeg' }
        '.png'  { 'image/png' }
        '.gif'  { 'image/gif' }
        default { 'image/jpeg' }
    }
    
    return "data:$mimeType;base64,$base64"
}

function Get-ImageDimensions {
    <#
    .SYNOPSIS
    Document Generator Engine
    
.DESCRIPTION
        Gets the width and height of an image file
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ImagePath
    )
    
    if (-not (Test-Path $ImagePath)) {
        throw "Image not found: $ImagePath"
    }
    
    Add-Type -AssemblyName System.Drawing
    $image = [System.Drawing.Image]::FromFile($ImagePath)
    $dimensions = @{
        Width = $image.Width
        Height = $image.Height
    }
    $image.Dispose()
    
    return $dimensions
}

#endregion

#region Main Functions

function New-ValidationDocument {
    <#
    .SYNOPSIS
    Document Generator Engine
    
.DESCRIPTION
        Creates a new validation document from template
        
    .DESCRIPTION
        Reads the HTML template and creates a new document with placeholder data.
        Returns the HTML content as a string for further modification.
        
    .PARAMETER AppName
        Application name (e.g., "Adobe Reader")
        
    .PARAMETER AppVersion
        Application version (e.g., "2024.001.20643")
        
    .PARAMETER TicketNumber
        Ticket number (e.g., "TT12345")
        
    .PARAMETER TechName
        Technician name performing validation
        
    .PARAMETER OSVersion
        Operating system version (e.g., "Windows 10 x64")
        
    .PARAMETER ValidationDate
        Date of validation (defaults to current date)
        
    .EXAMPLE
        $doc = New-ValidationDocument -AppName "Adobe Reader" -AppVersion "2024.1" -TicketNumber "TT12345" -TechName "John Doe"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppName,
        
        [Parameter(Mandatory)]
        [string]$AppVersion,
        
        [Parameter(Mandatory)]
        [string]$TicketNumber,
        
        [Parameter(Mandatory)]
        [string]$TechName,
        
        [Parameter()]
        [string]$OSVersion = "Windows 11 64x",
        
        [Parameter()]
        [datetime]$ValidationDate = (Get-Date)
    )
    
    Write-Verbose "Creating validation document for $AppName $AppVersion"
    
    # Read template
    if (-not (Test-Path $script:TemplatePath)) {
        throw "Template not found: $script:TemplatePath"
    }
    
    $html = Get-Content -Path $script:TemplatePath -Raw -Encoding UTF8
    
    # Replace placeholders using simple string replace
    $html = $html.Replace('[Application Name]', $AppName)
    $html = $html.Replace('[Version]', $AppVersion)
    $html = $html.Replace('[TT#####]', $TicketNumber)
    $html = $html.Replace('[Tech Name]', $TechName)
    $html = $html.Replace('[OS Version]', $OSVersion)
    $html = $html.Replace('[Date]', $ValidationDate.ToString('yyyy-MM-dd'))
    
        # Automatically embed FRS wrapper screenshot for Figure 1
    $frsWrapperPath = "$PSScriptRoot\..\design\FRS wrapper pic.jpg"
    if (Test-Path $frsWrapperPath) {
        Write-Verbose "Auto-embedding FRS wrapper for Figure 1"
        
        # Get image dimensions
        Add-Type -AssemblyName System.Drawing
        $image = [System.Drawing.Image]::FromFile($frsWrapperPath)
        $imgWidth = $image.Width
        $imgHeight = $image.Height
        $image.Dispose()
        
        # Convert to Base64
        $imageBytes = [System.IO.File]::ReadAllBytes($frsWrapperPath)
        $base64 = [Convert]::ToBase64String($imageBytes)
        $base64Image = "data:image/jpeg;base64,$base64"
        
        # Build figure HTML
        $figureHtml = (
            '<div class="figure-container">',
            "    <img src=`"$base64Image`" alt=`"Installation Progress Dialog`">",
            '    <div class="figure-caption">Figure 1: Installation Progress Dialog</div>',
            '</div>'
        ) -join [Environment]::NewLine
        
        # Replace the placeholder using simple string methods
        $figureMarker = "Figure 1:"
        $markerIndex = $html.IndexOf($figureMarker)
        
        if ($markerIndex -ge 0) {
            $searchStart = $markerIndex - 100
            if ($searchStart -lt 0) { $searchStart = 0 }
            
            $beforeMarker = $html.Substring($searchStart, $markerIndex - $searchStart)
            $divStart = $beforeMarker.LastIndexOf('<div class="figure-')
            
            if ($divStart -ge 0) {
                $divStart = $searchStart + $divStart
                $afterMarker = $html.Substring($markerIndex)
                $closingDiv = $afterMarker.IndexOf('</div>')
                
                if ($closingDiv -ge 0) {
                    $endPos = $markerIndex + $closingDiv + 6
                    $before = $html.Substring(0, $divStart)
                    $after = $html.Substring($endPos)
                    $html = $before + $figureHtml + $after
                    Write-Verbose "FRS wrapper embedded for Figure 1"
                }
            }
        }
    } else {
        Write-Warning "FRS wrapper image not found at: $frsWrapperPath"
    }
    
    Write-Verbose "Document created successfully"
    
    return $html
}

function Add-ValidationScreenshot {
    <#
    .SYNOPSIS
    Document Generator Engine
    
.DESCRIPTION
        Adds a screenshot to the validation document
        
    .DESCRIPTION
        Embeds a screenshot image into the document at the specified figure number.
        Converts image to Base64 for embedding.
        
    .PARAMETER HtmlContent
        The HTML content of the document
        
    .PARAMETER FigureNumber
        Figure number (1-4)
        
    .PARAMETER ImagePath
        Path to the screenshot image file
        
    .EXAMPLE
        $doc = Add-ValidationScreenshot -HtmlContent $doc -FigureNumber 1 -ImagePath "C:\temp\screenshot.jpg"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$HtmlContent,
        
        [Parameter(Mandatory)]
        [ValidateRange(1,4)]
        [int]$FigureNumber,
        
        [Parameter(Mandatory)]
        [string]$ImagePath
    )
    
    Write-Verbose "Adding screenshot for Figure $FigureNumber"
    
    if (-not (Test-Path $ImagePath)) {
        throw "Screenshot not found: $ImagePath"
    }
    
    # Get image dimensions
    $dimensions = Get-ImageDimensions -ImagePath $ImagePath
    Write-Verbose "Image dimensions: $($dimensions.Width) x $($dimensions.Height)"
    
    # Convert image to Base64
    $base64Image = Get-Base64Image -ImagePath $ImagePath
    Write-Verbose "Image converted to Base64 (length: $($base64Image.Length))"
    
    # Build the figure HTML
    $figureCaption = $script:FigurePlaceholders[$FigureNumber]
    $figureHtml = (
        '<div class="figure-container">',
        "    <img src=`"$base64Image`" alt=`"$figureCaption`">",
        "    <div class=`"figure-caption`">Figure $FigureNumber`: $figureCaption</div>",
        '</div>'
    ) -join [Environment]::NewLine
    
    # Find and replace using simple string methods (no regex)
    # Look for the figure marker
    $figureMarker = "Figure $FigureNumber`:"
    $markerIndex = $HtmlContent.IndexOf($figureMarker)
    
    if ($markerIndex -ge 0) {
        # Find the opening div before the marker
        $searchStart = $markerIndex - 200  # Search backwards max 200 chars
        if ($searchStart -lt 0) { $searchStart = 0 }
        
        $beforeMarker = $HtmlContent.Substring($searchStart, $markerIndex - $searchStart)
        $divStart = $beforeMarker.LastIndexOf('<div class="figure-')
        
        if ($divStart -ge 0) {
            $divStart = $searchStart + $divStart
            
            # Find the closing </div> after the marker
            # Find the closing </div> after the marker (template uses single-div structure)
            $afterMarker = $HtmlContent.Substring($markerIndex)
            $closingDiv = $afterMarker.IndexOf('</div>')
            
            if ($closingDiv -ge 0) {
                $endPos = $markerIndex + $closingDiv + 6
                
                # Replace the entire div section
                $before = $HtmlContent.Substring(0, $divStart)
                $after = $HtmlContent.Substring($endPos)
                $HtmlContent = $before + $figureHtml + $after
                
                Write-Verbose "Screenshot added for Figure $FigureNumber"
            } else {
                Write-Warning "Could not find closing div tag for Figure $FigureNumber"
            }
        }
    } else {
        Write-Warning "Could not find Figure $FigureNumber in document"
    }
    
    return $HtmlContent
}

function Set-ValidationDetails {
    <#
    .SYNOPSIS
    Document Generator Engine
    
.DESCRIPTION
        Sets installation details in the validation document
        
    .DESCRIPTION
        Updates the Installation Details table with actual values
        
    .PARAMETER HtmlContent
        The HTML content of the document
        
    .PARAMETER InstallDirectory
        Installation directory path
        
        
    .PARAMETER ServicesCreated
        Services created info
        
    .PARAMETER ConfigFiles
        Configuration files info
        
    .PARAMETER RegistryKeys
        Registry keys info
        
    .PARAMETER RebootRequired
        Whether reboot is required (Yes/No)
        
    .EXAMPLE
        $doc = Set-ValidationDetails -HtmlContent $doc -InstallDirectory "C:\Program Files\MyApp" -RebootRequired "No"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$HtmlContent,
        
        [Parameter()]
        [string]$InstallDirectory = "C:\Program Files\[Application]",
        
        [Parameter()]
        [string]$ServicesCreated = "None",
        
        [Parameter()]
        [string]$ConfigFiles = "None",
        
        [Parameter()]
        [string]$RegistryKeys = "HKLM\SOFTWARE\[Application]",
        
        [Parameter()]
        [string]$UninstallKeys = "[Uninstall Registry Keys]",
        
        [Parameter()]
        [ValidateSet("Yes", "No")]
        [string]$RebootRequired = "No"
    )
    
    Write-Verbose "Setting installation details"
    
    # Replace installation details using simple string replace
    $HtmlContent = $HtmlContent.Replace('C:\Program Files\[Application]', $InstallDirectory)
    $HtmlContent = $HtmlContent.Replace('<td>Services Created:</td><td>None</td>', "<td>Services Created:</td><td>$ServicesCreated</td>")
    $HtmlContent = $HtmlContent.Replace('<td>Configuration Files:</td><td>None</td>', "<td>Configuration Files:</td><td>$ConfigFiles</td>")
    $HtmlContent = $HtmlContent.Replace('HKLM\SOFTWARE\[Application]', $RegistryKeys)
    $HtmlContent = $HtmlContent.Replace('[Uninstall Registry Keys]', $UninstallKeys)
    $HtmlContent = $HtmlContent.Replace('<td>Reboot Required:</td><td>No</td>', "<td>Reboot Required:</td><td>$RebootRequired</td>")
    
    Write-Verbose "Installation details updated"
    
    return $HtmlContent
}

function Export-ValidationDocument {
    <#
    .SYNOPSIS
    Document Generator Engine
    
.DESCRIPTION
        Exports the validation document to a file
        
    .DESCRIPTION
        Saves the HTML document to the specified path
        
    .PARAMETER HtmlContent
        The HTML content of the document
        
    .PARAMETER OutputPath
        Path where the document should be saved
        
    .PARAMETER OpenAfterExport
        Whether to open the document after export
        
    .EXAMPLE
        Export-ValidationDocument -HtmlContent $doc -OutputPath "C:\Docs\MyApp_Validation.html" -OpenAfterExport
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$HtmlContent,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [Parameter()]
        [switch]$OpenAfterExport
    )
    
    Write-Verbose "Exporting document to: $OutputPath"
    
    # Ensure directory exists
    $directory = Split-Path -Path $OutputPath -Parent
    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        Write-Verbose "Created directory: $directory"
    }
    
    # Save the file
    $HtmlContent | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
    
    if (Test-Path $OutputPath) {
        $file = Get-Item $OutputPath
        Write-Verbose "Document exported successfully (Size: $($file.Length) bytes)"
        
        if ($OpenAfterExport) {
            Write-Verbose "Opening document"
            Start-Process $OutputPath
        }
        
        return $file
    } else {
        throw "Failed to export document"
    }
}

#endregion
# Export module members
Export-ModuleMember -Function @(
    'New-ValidationDocument',
    'Add-ValidationScreenshot',
    'Set-ValidationDetails',
    'Export-ValidationDocument'
)

