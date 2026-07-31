#!/usr/bin/env python3
"""
Installation Validation Report - Requirements Research Module
Uses Playwright for automated web research of application requirements
"""

import sys
import json
import argparse
from pathlib import Path
from datetime import datetime
from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeout

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from page_parser import PageParser
from cache_manager import CacheManager


class RequirementsResearcher:
    """Automated research of application system requirements"""
    
    def __init__(self, config_path, cache_path):
        self.config_path = Path(config_path)
        self.cache_path = Path(cache_path)
        self.cache = CacheManager(cache_path)
        self.parser = PageParser()
        
        # Load configuration
        with open(config_path, 'r', encoding='utf-8-sig') as f:
            self.config = json.load(f)
    
    def research_application(self, app_name, version=None):
        """
        Research system requirements for an application
        
        Args:
            app_name: Name of the application
            version: Optional version number
            
        Returns:
            dict: Structured requirements data
        """
        # Check cache first
        cache_key = f"{app_name}_{version}" if version else app_name
        cached = self.cache.get(cache_key)
        if cached:
            print(f"[CACHE HIT] Found cached data for {cache_key}")
            return cached
        
        print(f"[RESEARCH] Starting research for {app_name}")
        
        # Try configured source first
        if app_name in self.config.get('applications', {}):
            result = self._research_configured_app(app_name, version)
        else:
            # Fallback to generic search
            result = self._research_generic_app(app_name, version)
        
        # Cache successful results
        if result and result.get('success'):
            self.cache.set(cache_key, result)
            print(f"[CACHE SAVE] Saved results for {cache_key}")
        
        return result
    
    def _research_configured_app(self, app_name, version):
        """Research using pre-configured vendor information"""
        app_config = self.config['applications'][app_name]
        strategy = app_config.get('search_strategy', 'google_search')
        
        print(f"[STRATEGY] Using {strategy} for {app_name}")
        
        if strategy == 'direct_url':
            return self._fetch_direct_url(app_config, app_name, version)
        elif strategy == 'fallback_apis':
            return self._try_api_sources(app_config, app_name, version)
        else:  # google_search
            return self._google_search(app_config, app_name, version)
    
    def _research_generic_app(self, app_name, version):
        """Research unknown application using fallback strategies"""
        print(f"[FALLBACK] No configuration found, trying fallback strategies")
        
        # Try APIs first (fast, structured data)
        result = self._try_chocolatey_api(app_name)
        if result and result.get('success'):
            return result
        
        result = self._try_winget_api(app_name)
        if result and result.get('success'):
            return result
        
        # Fall back to Google search
        return self._google_search_generic(app_name, version)
    
    def _fetch_direct_url(self, app_config, app_name, version):
        """Fetch requirements from known vendor URL"""
        url = app_config.get('requirements_url')
        if not url:
            return self._create_error_result("No requirements URL configured")
        
        print(f"[DIRECT URL] Fetching {url}")
        
        try:
            with sync_playwright() as p:
                browser = p.chromium.launch(channel='msedge', headless=True)
                page = browser.new_page()
                
                page.goto(url, wait_until='networkidle', timeout=30000)
                content = page.content()
                
                browser.close()
                
                # Parse the content
                requirements = self.parser.parse_requirements_page(
                    content,
                    app_config.get('selectors', {})
                )
                
                return self._create_success_result(
                    app_name, version, requirements, url, 'direct_url'
                )
                
        except PlaywrightTimeout:
            print(f"[ERROR] Timeout accessing {url}")
            return self._create_error_result(f"Timeout accessing {url}")
        except Exception as e:
            print(f"[ERROR] {str(e)}")
            return self._create_error_result(str(e))
    
    def _google_search(self, app_config, app_name, version):
        """Search Google for vendor requirements page"""
        search_terms = app_config.get('search_terms', [])
        if not search_terms:
            search_terms = [f"{app_name} system requirements"]
        
        version_str = f" {version}" if version else ""
        query = f"{search_terms[0]}{version_str}"
        
        print(f"[GOOGLE SEARCH] Searching for: {query}")
        
        try:
            with sync_playwright() as p:
                browser = p.chromium.launch(channel='msedge', headless=True)
                page = browser.new_page()
                
                # Perform Google search
                search_url = f"https://www.google.com/search?q={query.replace(' ', '+')}"
                page.goto(search_url, wait_until='networkidle')
                
                # Find vendor domain if specified
                vendor_domain = app_config.get('vendor_domain', '')
                
                # Click first relevant result
                if vendor_domain:
                    # Try to find link containing vendor domain
                    link = page.locator(f"a[href*='{vendor_domain}']").first
                else:
                    # Click first non-ad result
                    link = page.locator("div#search a h3").first
                
                result_url = link.evaluate("el => el.parentElement.href")
                print(f"[NAVIGATE] Opening {result_url}")
                
                page.goto(result_url, wait_until='networkidle', timeout=30000)
                content = page.content()
                
                browser.close()
                
                # Parse the content
                requirements = self.parser.parse_requirements_page(
                    content,
                    app_config.get('selectors', {})
                )
                
                return self._create_success_result(
                    app_name, version, requirements, result_url, 'google_search'
                )
                
        except Exception as e:
            print(f"[ERROR] Google search failed: {str(e)}")
            return self._create_error_result(str(e))
    
    def _google_search_generic(self, app_name, version):
        """Generic Google search for unknown applications"""
        version_str = f" {version}" if version else ""
        query = f"{app_name}{version_str} system requirements"
        
        print(f"[GENERIC SEARCH] {query}")
        
        try:
            with sync_playwright() as p:
                browser = p.chromium.launch(channel='msedge', headless=True)
                page = browser.new_page()
                
                search_url = f"https://www.google.com/search?q={query.replace(' ', '+')}"
                page.goto(search_url, wait_until='networkidle')
                
                # Click first result
                link = page.locator("div#search a h3").first
                result_url = link.evaluate("el => el.parentElement.href")
                
                print(f"[NAVIGATE] {result_url}")
                page.goto(result_url, wait_until='networkidle', timeout=30000)
                content = page.content()
                
                browser.close()
                
                requirements = self.parser.parse_requirements_page(content)
                
                return self._create_success_result(
                    app_name, version, requirements, result_url, 'generic_search'
                )
                
        except Exception as e:
            print(f"[ERROR] {str(e)}")
            return self._create_error_result(str(e))
    
    def _try_chocolatey_api(self, app_name):
        """Query Chocolatey package database"""
        print(f"[CHOCOLATEY API] Searching for {app_name}")
        
        try:
            import requests
            
            # Clean app name for package ID
            package_id = app_name.lower().replace(' ', '-')
            url = f"https://community.chocolatey.org/api/v2/Packages()?$filter=tolower(Id) eq '{package_id}'"
            
            response = requests.get(url, timeout=10)
            if response.status_code == 200:
                # Parse XML response
                # This is simplified - real implementation would parse the XML
                print(f"[CHOCOLATEY] Found package data")
                return self._create_success_result(
                    app_name, None, {"source": "chocolatey", "raw_data": response.text}, 
                    url, 'chocolatey_api'
                )
        except Exception as e:
            print(f"[CHOCOLATEY] Failed: {str(e)}")
        
        return None
    
    def _try_winget_api(self, app_name):
        """Query WinGet package information"""
        print(f"[WINGET API] Searching for {app_name}")
        
        try:
            import requests
            
            package_id = app_name.lower().replace(' ', '-')
            url = f"https://winget.run/pkg/{package_id}"
            
            response = requests.get(url, timeout=10)
            if response.status_code == 200:
                print(f"[WINGET] Found package data")
                # Parse HTML response
                requirements = self.parser.parse_requirements_page(response.text)
                return self._create_success_result(
                    app_name, None, requirements, url, 'winget_api'
                )
        except Exception as e:
            print(f"[WINGET] Failed: {str(e)}")
        
        return None
    
    def _try_api_sources(self, app_config, app_name, version):
        """Try multiple API sources in order"""
        api_sources = app_config.get('api_sources', [])
        
        for source in api_sources:
            if source == 'chocolatey':
                result = self._try_chocolatey_api(app_name)
                if result and result.get('success'):
                    return result
            elif source == 'winget':
                result = self._try_winget_api(app_name)
                if result and result.get('success'):
                    return result
        
        # Fallback to direct URL if configured
        if app_config.get('requirements_url'):
            return self._fetch_direct_url(app_config, app_name, version)
        
        return self._create_error_result("All API sources failed")
    
    def _create_success_result(self, app_name, version, requirements, source_url, method):
        """Create standardized success result"""
        return {
            "success": True,
            "application": app_name,
            "version": version,
            "timestamp": datetime.now().isoformat(),
            "source_url": source_url,
            "research_method": method,
            "requirements": requirements,
            "cached": False
        }
    
    def _create_error_result(self, error_message):
        """Create standardized error result"""
        return {
            "success": False,
            "error": error_message,
            "timestamp": datetime.now().isoformat()
        }


def main():
    """Command-line interface"""
    parser = argparse.ArgumentParser(
        description='Research application system requirements'
    )
    parser.add_argument('application', help='Application name')
    parser.add_argument('--version', help='Application version')
    parser.add_argument(
        '--config',
        default='../Config/application_sources.json',
        help='Path to configuration file'
    )
    parser.add_argument(
        '--cache',
        default='../Cache/research_cache.json',
        help='Path to cache file'
    )
    parser.add_argument(
        '--output',
        help='Output file path (default: stdout)'
    )
    
    args = parser.parse_args()
    
    # Resolve paths relative to script location
    script_dir = Path(__file__).parent
    config_path = (script_dir / args.config).resolve()
    cache_path = (script_dir / args.cache).resolve()
    
    # Research requirements
    researcher = RequirementsResearcher(config_path, cache_path)
    result = researcher.research_application(args.application, args.version)
    
    # Output results
    output_json = json.dumps(result, indent=2)
    
    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(output_json)
        print(f"[OUTPUT] Results written to {args.output}")
    else:
        print(output_json)
    
    # Exit with appropriate code
    sys.exit(0 if result.get('success') else 1)


if __name__ == '__main__':
    main()
