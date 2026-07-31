# Installation Validation Report System

Automated system for researching application requirements and generating comprehensive validation reports.

## Overview

This system combines:
- **Installer Analysis** - Extracts technical data from MSI/EXE files
- **Web Research** - Automated Playwright-based requirement discovery
- **Knowledge Base** - Caches research results for reuse
- **Professional Reports** - HTML validation documents

## Features

- Automated web scraping of vendor documentation
- Multi-source aggregation (Chocolatey, WinGet, vendor sites)
- Intelligent caching system (30-day expiry)
- MSI/EXE installer analysis
- Comprehensive HTML report generation
- Configuration system for known applications

## Requirements

### System Requirements
- Windows 10 or newer
- PowerShell 5.1 (Windows PowerShell)
- Python 3.8 or newer
- Internet connectivity (for web research)

### Python Dependencies
```bash
pip install -r Python\requirements.txt
```

Required packages:
- playwright >= 1.40.0
- beautifulsoup4 >= 4.12.0
- lxml >= 5.0.0
- requests >= 2.31.0

### Playwright Installation
After installing Python packages, install browser binaries:
```bash
python -m playwright install chromium
```

## Quick Start

### Option 1: With Installer File
```powershell
.\PowerShell\Start-ValidationResearch.ps1 -InstallerPath "C:\Installers\Snagit.exe"
```

### Option 2: Application Name Only
```powershell
.\PowerShell\Start-ValidationResearch.ps1 -ApplicationName "Adobe Acrobat DC" -Version "2024"
```

### Option 3: Skip Web Research
```powershell
.\PowerShell\Start-ValidationResearch.ps1 -InstallerPath "C:\Installers\app.msi" -SkipWebResearch
```

## Project Structure

```
Installation_Validation_Report/
├── Config/
│   ├── application_sources.json      # Vendor URL mappings
│   └── scraping_patterns.json        # HTML parsing rules
├── Python/
│   ├── research_requirements.py      # Main Playwright script
│   ├── page_parser.py                # HTML parsing
│   ├── cache_manager.py              # Knowledge base
│   └── requirements.txt              # Python dependencies
├── PowerShell/
│   ├── Start-ValidationResearch.ps1  # Main entry point
│   ├── Invoke-WebResearch.ps1        # Python integration
│   ├── New-ValidationReport.ps1      # Report generation
│   └── Modules/
│       ├── InstallerAnalysis.psm1    # MSI/EXE analysis
│       └── CacheManagement.psm1      # Cache utilities
├── Templates/
│   └── Professional-Validation-Template.html
├── Cache/
│   └── research_cache.json           # Cached results
└── Reports/
    └── (Generated reports)
```

## Configuration

### Adding Known Applications

Edit `Config\application_sources.json`:

```json
{
  "applications": {
    "YourApp": {
      "vendor": "Vendor Name",
      "search_strategy": "direct_url",
      "requirements_url": "https://vendor.com/requirements",
      "selectors": {
        "requirements_section": "div.requirements",
        "prerequisites": "table tbody tr"
      }
    }
  }
}
```

### Search Strategies

1. **direct_url** - Go directly to known requirements page
2. **google_search** - Search and navigate to vendor site
3. **fallback_apis** - Try Chocolatey/WinGet first

## Cache Management

### View Cache Statistics
```powershell
Import-Module .\PowerShell\Modules\CacheManagement.psm1
Get-CacheStatistics
```

### Clear Specific Application
```powershell
Clear-ResearchCache -Application "Snagit"
```

### Clear Entire Cache
```powershell
Clear-ResearchCache
```

## Python Module Usage

Can be used standalone:

```bash
python Python\research_requirements.py "Adobe Acrobat DC" --version "2024"
```

Output:
```json
{
  "success": true,
  "application": "Adobe Acrobat DC",
  "version": "2024",
  "requirements": {
    "operating_system": ["Windows 10 x64", "Windows 11"],
    "prerequisites": [".NET Framework 4.8"],
    "memory": "4 GB RAM",
    "disk_space": "4.5 GB"
  }
}
```

## Troubleshooting

### Playwright Not Found
```powershell
pip install playwright
python -m playwright install chromium
```

### Python Not Found
- Install Python from python.org
- Add Python to PATH during installation
- Verify: `python --version`

### Web Research Fails
- Check internet connectivity
- Try with `-SkipWebResearch` to use installer analysis only
- Check if application is in Config\application_sources.json

### Cache Issues
```powershell
Import-Module .\PowerShell\Modules\CacheManagement.psm1
Clear-ResearchCache
```

## Development

### Adding New Parsing Patterns

Edit `Config\scraping_patterns.json`:

```json
{
  "extraction_rules": {
    "your_pattern": {
      "patterns": ["regex pattern here"],
      "keywords": ["keyword1", "keyword2"]
    }
  }
}
```

### Extending Installer Analysis

Modify `PowerShell\Modules\InstallerAnalysis.psm1` to extract additional MSI properties.

## Future Enhancements

- AI integration for intelligent content extraction
- Support for additional installer types (MSIX, AppX)
- Screenshot capture during validation
- Integration with ticketing systems
- Scheduled validation runs
- Version comparison reports

## Support

For issues or questions, contact the packaging team.

## Version

1.0.0 - Initial Release
