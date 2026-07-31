<!-- INTERNAL FR/OFFICIAL USE // FRSONLY -->
# Playwright Web Scraping POC - README

**Purpose:** Proof of concept for scraping real-world installer documentation to populate Package Helper suggestions

**Target Application:** TechSmith Camtasia

**Architecture:**
- PowerShell orchestration (Test-Scraper.ps1)
- Python + Playwright scraping (scraper.py)
- JSON configuration (config.json)
- Structured output matching Package Helper format

## Files

1. **Test-Scraper.ps1** - Main orchestration script
   - Validates prerequisites (Python, Playwright)
   - Reads config.json for targets
   - Calls scraper.py with target websites
   - Aggregates scraped data
   - Formats as Package Helper sections
   - Outputs to console and JSON file

2. **scraper.py** - Python + Playwright scraper
   - Accepts URL and search terms
   - Navigates to target website
   - Extracts relevant content
   - Returns JSON to stdout
   - Handles errors gracefully

3. **config.json** - Target websites configuration
   - TechSmith documentation
   - Community forums
   - GitHub repositories
   - Search terms for Camtasia

4. **output/** - Scraped results folder
   - Timestamped JSON files
   - Package Helper formatted data

5. **logs/** - Diagnostic logs
   - Scraping activity
   - Errors and warnings

## Usage

```powershell
# Run the scraper
.\Test-Scraper.ps1

# View results
Get-Content .\output\camtasia_*.json | ConvertFrom-Json
```

## Package Helper Format

Output matches 10-section structure:
1. Context Selection
2. Install Command Line
3. Uninstall Command Line
4. Uninstall Executable
5. Pre-Install Commands
6. Custom Install Commands
7. Post-Install Commands
8. Pre-Uninstall Commands
9. Custom Uninstall Commands
10. Post-Uninstall Commands

Each section contains:
- Title
- Summary
- Suggestions array (multiple examples)
- Source URL (where data was scraped from)

## Prerequisites

- PowerShell 5.1+
- Python 3.8+
- Playwright for Python: `pip install playwright`
- Playwright browsers: `playwright install`

## Next Steps

1. Run POC to validate concept
2. Review scraped data quality
3. Refine scraping logic
4. Add more target websites
5. Integrate into FRB-Packaging-Tool
