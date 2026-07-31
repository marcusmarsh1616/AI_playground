#!/usr/bin/env python3
"""
Page Parser - HTML content extraction and parsing
"""

import json
import re
from pathlib import Path
from bs4 import BeautifulSoup


class PageParser:
    """Parse HTML pages to extract system requirements"""
    
    def __init__(self, patterns_path=None):
        if patterns_path is None:
            patterns_path = Path(__file__).parent.parent / 'Config' / 'scraping_patterns.json'
        
        with open(patterns_path, 'r', encoding='utf-8-sig') as f:
            self.patterns = json.load(f)
    
    def parse_requirements_page(self, html_content, custom_selectors=None):
        """Parse HTML content to extract requirements using a broader fallback strategy."""
        soup = BeautifulSoup(html_content, 'lxml')

        requirements = {
            "operating_system": [],
            "prerequisites": [],
            "memory": None,
            "disk_space": None,
            "processor": None,
            "conflicts": [],
            "upgrade_path": [],
            "raw_text": "",
            "extraction_confidence": "unknown"
        }

        req_section = self._find_requirements_section(soup, custom_selectors)
        text = ""
        if req_section:
            text = req_section.get_text(separator='\n', strip=True)
        else:
            text = soup.get_text(separator='\n', strip=True)

        cleaned_text = self._clean_text(text)
        requirements["raw_text"] = cleaned_text[:8000]

        if not cleaned_text:
            return requirements

        requirements["operating_system"] = self._extract_os(cleaned_text)
        requirements["prerequisites"] = self._extract_prerequisites(cleaned_text)
        requirements["memory"] = self._extract_memory(cleaned_text)
        requirements["disk_space"] = self._extract_disk_space(cleaned_text)
        requirements["processor"] = self._extract_processor(cleaned_text)
        requirements["conflicts"] = self._extract_conflicts(cleaned_text)
        requirements["upgrade_path"] = self._extract_upgrade_path(cleaned_text)

        for field in ["operating_system", "prerequisites", "conflicts", "upgrade_path"]:
            if requirements[field]:
                if requirements["extraction_confidence"] == "unknown":
                    requirements["extraction_confidence"] = "low"
                break

        if not requirements["operating_system"] and not requirements["prerequisites"] and not requirements["conflicts"] and not requirements["upgrade_path"]:
            requirements["extraction_confidence"] = "low"
        else:
            requirements["extraction_confidence"] = self._calculate_confidence(requirements)

        if not requirements["operating_system"]:
            requirements["operating_system"] = self._extract_os_from_context(cleaned_text)
        if not requirements["prerequisites"]:
            requirements["prerequisites"] = self._extract_prerequisite_phrases(cleaned_text)
        if not requirements["conflicts"]:
            requirements["conflicts"] = self._extract_conflict_phrases(cleaned_text)
        if not requirements["upgrade_path"]:
            requirements["upgrade_path"] = self._extract_upgrade_phrases(cleaned_text)

        return requirements
    
    def _find_requirements_section(self, soup, custom_selectors):
        """Find the main requirements section in the page"""
        
        # Try custom selectors first
        if custom_selectors:
            for selector in custom_selectors.get('requirements_section', []):
                section = soup.select_one(selector)
                if section:
                    return section
        
        # Try common patterns
        for selector in self.patterns['common_selectors']['requirements_sections']:
            section = soup.select_one(selector)
            if section:
                return section
        
        # Try finding by heading text
        for heading in soup.find_all(['h1', 'h2', 'h3', 'h4']):
            heading_text = heading.get_text().lower()
            if any(keyword in heading_text for keyword in ['requirement', 'system', 'specification']):
                # Return parent section or next sibling
                parent = heading.find_parent(['section', 'div', 'article'])
                if parent:
                    return parent
        
        return None
    
    def _extract_os(self, text):
        """Extract operating system requirements"""
        os_list = []
        patterns = self.patterns['extraction_rules']['operating_system']['patterns']

        for pattern in patterns:
            matches = re.finditer(pattern, text, re.IGNORECASE)
            for match in matches:
                os_list.append(match.group(0))

        if not os_list:
            for line in text.splitlines():
                if re.search(r"windows|mac os|linux|operating system|os", line, re.IGNORECASE):
                    os_list.append(self._clean_text(line))
        return list(dict.fromkeys([item for item in os_list if item]))
    
    def _extract_prerequisites(self, text):
        """Extract prerequisite software"""
        prereqs = []
        patterns = self.patterns['extraction_rules']['prerequisites']['patterns']

        for pattern in patterns:
            matches = re.finditer(pattern, text, re.IGNORECASE)
            for match in matches:
                prereqs.append(match.group(0))

        if not prereqs:
            prereqs = self._extract_prerequisite_phrases(text)

        return list(dict.fromkeys([item for item in prereqs if item]))
    
    def _extract_memory(self, text):
        """Extract memory requirements"""
        patterns = self.patterns['extraction_rules']['memory']['patterns']
        
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                return match.group(0)
        
        return None
    
    def _extract_disk_space(self, text):
        """Extract disk space requirements"""
        patterns = self.patterns['extraction_rules']['disk_space']['patterns']
        
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                return match.group(0)
        
        return None
    
    def _extract_processor(self, text):
        """Extract processor requirements"""
        patterns = self.patterns['extraction_rules']['processor']['patterns']
        
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                return match.group(0)
        
        return None
    
    def _extract_conflicts(self, text):
        """Extract known conflicts"""
        conflicts = []
        patterns = self.patterns['extraction_rules']['conflicts']['patterns']

        for pattern in patterns:
            matches = re.finditer(pattern, text, re.IGNORECASE)
            for match in matches:
                conflicts.append(match.group(0))

        if not conflicts:
            conflicts = self._extract_conflict_phrases(text)

        return list(dict.fromkeys([item for item in conflicts if item]))
    
    def _extract_upgrade_path(self, text):
        """Extract upgrade path information"""
        upgrade_info = []
        keywords = self.patterns['search_patterns']['upgrade_keywords']

        lines = text.split('\n')
        for line in lines:
            if any(keyword.lower() in line.lower() for keyword in keywords):
                upgrade_info.append(line.strip())

        if not upgrade_info:
            upgrade_info = self._extract_upgrade_phrases(text)

        return list(dict.fromkeys([item for item in upgrade_info if item]))
    
    def _clean_text(self, text):
        """Clean extracted text"""
        if text is None:
            return ""

        # Remove patterns specified in config
        for pattern in self.patterns['data_cleaning']['remove_patterns']:
            text = re.sub(pattern, '', text, flags=re.IGNORECASE)

        # Normalize whitespace
        if self.patterns['data_cleaning']['normalize_spaces']:
            text = re.sub(r'\s+', ' ', text)

        # Trim
        if self.patterns['data_cleaning']['trim_whitespace']:
            text = text.strip()

        return text

    def _extract_os_from_context(self, text):
        items = []
        for line in text.splitlines():
            lowered = line.lower()
            if any(token in lowered for token in ["windows", "mac", "linux", "operating system", "supported operating systems"]):
                cleaned = self._clean_text(line)
                if cleaned and len(cleaned) < 220:
                    items.append(cleaned)
        return list(dict.fromkeys(items))

    def _extract_prerequisite_phrases(self, text):
        items = []
        for line in text.splitlines():
            lowered = line.lower()
            if any(token in lowered for token in ["prerequisite", "requires", "requires an", "requires the", "install", "runtime", "framework", "service pack", "administrator"]):
                cleaned = self._clean_text(line)
                if cleaned and len(cleaned) < 220:
                    items.append(cleaned)
        return list(dict.fromkeys(items))

    def _extract_conflict_phrases(self, text):
        items = []
        for line in text.splitlines():
            lowered = line.lower()
            if any(token in lowered for token in ["conflict", "incompatible", "cannot install", "must uninstall", "older version", "previous version", "existing version"]):
                cleaned = self._clean_text(line)
                if cleaned and len(cleaned) < 220:
                    items.append(cleaned)
        return list(dict.fromkeys(items))

    def _extract_upgrade_phrases(self, text):
        items = []
        for line in text.splitlines():
            lowered = line.lower()
            if any(token in lowered for token in ["upgrade", "migrate", "previous version", "older version", "version", "replacement"]):
                cleaned = self._clean_text(line)
                if cleaned and len(cleaned) < 220:
                    items.append(cleaned)
        return list(dict.fromkeys(items))
    
    def _calculate_confidence(self, requirements):
        """Calculate extraction confidence based on what was found"""
        found_count = sum([
            len(requirements["operating_system"]) > 0,
            len(requirements["prerequisites"]) > 0,
            requirements["memory"] is not None,
            requirements["disk_space"] is not None,
            requirements["processor"] is not None
        ])
        
        if found_count >= 4:
            return "high"
        elif found_count >= 2:
            return "medium"
        else:
            return "low"
