#Requires -Version 5.1
<#
.SYNOPSIS
    Installer Analysis Module

.DESCRIPTION
    Analyzes MSI and EXE installers to extract technical requirements
#>

function Invoke-InstallerAnalysis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    Write-Host "[ANALYZE] $Path" -ForegroundColor Cyan
    
    $fileInfo = Get-Item $Path
    $extension = $fileInfo.Extension.ToLower()
    
    $analysis = @{
        FilePath = $Path
        FileName = $fileInfo.Name
        FileSize = $fileInfo.Length
        FileType = $extension
        ProductName = $null
        ProductVersion = $null
        Manufacturer = $null
        Prerequisites = @()
        LaunchConditions = @()
        UpgradeCode = $null
        ProductCode = $null
        RelatedProducts = @()
    }
    
    if ($extension -eq '.msi') {
        $analysis += Analyze-MsiFile -Path $Path
    } elseif ($extension -eq '.exe') {
        $analysis += Analyze-ExeFile -Path $Path
    } else {
        Write-Host "[WARNING] Unsupported file type: $extension" -ForegroundColor Yellow
    }
    
    return [PSCustomObject]$analysis
}

function Analyze-MsiFile {
    param([string]$Path)
    
    $data = @{}
    
    try {
        # Create Windows Installer object
        $installer = New-Object -ComObject WindowsInstaller.Installer
        $database = $installer.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $installer, @($Path, 0))
        
        # Get Property table
        $query = "SELECT * FROM Property"
        $view = $database.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $database, ($query))
        $view.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $view, $null)
        
        $record = $view.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $view, $null)
        
        while ($record) {
            $property = $record.GetType().InvokeMember('StringData', 'GetProperty', $null, $record, 1)
            $value = $record.GetType().InvokeMember('StringData', 'GetProperty', $null, $record, 2)
            
            switch ($property) {
                'ProductName' { $data.ProductName = $value }
                'ProductVersion' { $data.ProductVersion = $value }
                'Manufacturer' { $data.Manufacturer = $value }
                'ProductCode' { $data.ProductCode = $value }
                'UpgradeCode' { $data.UpgradeCode = $value }
            }
            
            $record = $view.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $view, $null)
        }
        
        # Get LaunchCondition table
        try {
            $query = "SELECT * FROM LaunchCondition"
            $view = $database.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $database, ($query))
            $view.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $view, $null)
            
            $conditions = @()
            $record = $view.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $view, $null)
            
            while ($record) {
                $condition = $record.GetType().InvokeMember('StringData', 'GetProperty', $null, $record, 1)
                $description = $record.GetType().InvokeMember('StringData', 'GetProperty', $null, $record, 2)
                
                $conditions += @{
                    Condition = $condition
                    Description = $description
                }
                
                $record = $view.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $view, $null)
            }
            
            $data.LaunchConditions = $conditions
        } catch {
            # LaunchCondition table may not exist
        }
        
        Write-Host "[INFO] MSI analysis complete" -ForegroundColor Green
        
    } catch {
        Write-Host "[WARNING] MSI analysis failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    return $data
}

function Analyze-ExeFile {
    param([string]$Path)
    
    $data = @{}
    
    try {
        # Get file version info
        $versionInfo = (Get-Item $Path).VersionInfo
        
        $data.ProductName = $versionInfo.ProductName
        $data.ProductVersion = $versionInfo.ProductVersion
        $data.Manufacturer = $versionInfo.CompanyName
        
        Write-Host "[INFO] EXE version info extracted" -ForegroundColor Green
        
    } catch {
        Write-Host "[WARNING] EXE analysis failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    return $data
}

Export-ModuleMember -Function Invoke-InstallerAnalysis
