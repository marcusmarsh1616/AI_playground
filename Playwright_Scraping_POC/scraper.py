# INTERNAL FR/OFFICIAL USE // FRSONLY
# SCRAPER.PY - Enhanced with Input Field & Code Block Extraction

import sys
import json
import asyncio
import re
from playwright.async_api import async_playwright
from datetime import datetime

async def extract_commands_from_page(page, search_terms):
    """Extract commands from input fields, code blocks, and text"""
    all_commands = []
    
    # PRIORITY 1: Extract from input fields (actual commands!)
    print("[INFO]   -> Extracting from input/textarea fields...", file=sys.stderr)
    input_commands = await page.evaluate("""
        () => {
            const commands = [];
            const inputs = document.querySelectorAll('input[type="text"], input[readonly], textarea');
            inputs.forEach(inp => {
                const value = inp.value || inp.getAttribute('value');
                if (value && value.trim().length > 5) {
                    commands.push({
                        text: value.trim(),
                        source: 'input_field',
                        is_command: true
                    });
                }
            });
            return commands;
        }
    """)
    
    for cmd in input_commands:
        all_commands.append({
            "text": cmd['text'][:300],
            "context": "Extracted from HTML input field (command ready to use)",
            "is_command": True,
            "line_number": 0,
            "source_type": "input_field"
        })
    
    print(f"[INFO]   -> Found {len(input_commands)} commands in input fields", file=sys.stderr)
    
    # PRIORITY 2: Extract from code blocks
    print("[INFO]   -> Extracting from code/pre blocks...", file=sys.stderr)
    code_blocks = await page.evaluate("""
        () => {
            const codes = [];
            document.querySelectorAll('code, pre, .command, .code-block').forEach(el => {
                const text = (el.innerText || el.textContent || '').trim();
                if (text.length > 10 && text.length < 500) {
                    codes.push(text);
                }
            });
            return codes;
        }
    """)
    
    command_patterns = [
        r'[a-zA-Z0-9_-]+\.exe\s+[/\-]',
        r'msiexec(\.exe)?\s+/[ixar]',
        r'choco\s+(install|upgrade|uninstall)',
        r'Start-Process\s+',
        r'Remove-Item\s+',
    ]
    
    for code in code_blocks[:20]:
        # Check if looks like a command
        is_command = any(re.search(pattern, code, re.IGNORECASE) for pattern in command_patterns)
        has_keyword = any(term.lower() in code.lower() for term in search_terms)
        
        if is_command or has_keyword:
            all_commands.append({
                "text": code[:300],
                "context": "Extracted from code block",
                "is_command": is_command,
                "line_number": 0,
                "source_type": "code_block"
            })
    
    print(f"[INFO]   -> Found {len([c for c in code_blocks if any(re.search(p, c, re.IGNORECASE) for p in command_patterns)])} commands in code blocks", file=sys.stderr)
    
    # PRIORITY 3: Extract from regular text
    print("[INFO]   -> Extracting from page text...", file=sys.stderr)
    text_content = await page.evaluate("() => document.body.innerText")
    text_commands = extract_commands_from_text(text_content, search_terms)
    
    # Add text commands but mark as lower priority
    for cmd in text_commands[:10]:
        cmd["source_type"] = "page_text"
        all_commands.append(cmd)
    
    print(f"[INFO]   -> Found {len(text_commands)} potential commands in text", file=sys.stderr)
    
    return all_commands[:20]  # Limit to top 20

def extract_commands_from_text(text_content, search_terms):
    """Extract from regular text (fallback)"""
    commands = []
    lines = text_content.split("\n")
    
    command_patterns = [
        r'[a-zA-Z0-9_-]+\.exe\s+[/\-]',
        r'msiexec(\.exe)?\s+/[ixar]',
        r'setup(\.exe)?\s+[/\-]',
        r'Start-Process\s+',
        r'Remove-Item\s+',
        r'/[sqvnQN]+\b',
        r'ALLUSERS=\d',
    ]
    
    for i, line in enumerate(lines):
        line_strip = line.strip()
        
        if len(line_strip) < 10:
            continue
        
        # Skip UI elements
        skip_terms = ['copyright', 'cookie', 'privacy', 'sign in', 'log in', 'terms of service']
        if any(skip in line_strip.lower() for skip in skip_terms):
            continue
        
        # Check for keywords
        has_keyword = any(term.lower() in line_strip.lower() for term in search_terms)
        if not has_keyword:
            continue
        
        # Check for command patterns
        is_command = any(re.search(pattern, line_strip, re.IGNORECASE) for pattern in command_patterns)
        
        if is_command or len(line_strip) > 30:
            start = max(0, i - 2)
            end = min(len(lines), i + 3)
            context_lines = [l.strip() for l in lines[start:end] if l.strip() and len(l.strip()) > 5]
            context = " | ".join(context_lines[:4])
            
            if len(context) < 20:
                continue
            
            commands.append({
                "text": line_strip[:300],
                "context": context[:400],
                "is_command": is_command,
                "line_number": i
            })
            
            if len(commands) >= 10:
                break
    
    return commands

async def scrape_website(url, search_terms, config):
    """Scrape with enhanced extraction"""
    results = {
        "url": url,
        "timestamp": datetime.now().isoformat(),
        "success": False,
        "data": [],
        "error": None
    }
    
    try:
        async with async_playwright() as p:
            browser = await p.chromium.launch(
                headless=config["headless"],
                channel="msedge"
            )
            
            context = await browser.new_context(
                user_agent=config["user_agent"],
                viewport={'width': 1920, 'height': 1080}
            )
            
            page = await context.new_page()
            
            print("[INFO]   -> Loading page...", file=sys.stderr)
            await page.goto(url, timeout=config["timeout_seconds"] * 1000, wait_until="networkidle")
            await page.wait_for_timeout(3000)
            
            # Extract commands using all methods
            commands = await extract_commands_from_page(page, search_terms)
            
            results["data"].extend(commands)
            print(f"[INFO]   -> Total extracted: {len(commands)} items", file=sys.stderr)
            
            await browser.close()
            results["success"] = True
    
    except Exception as e:
        error_msg = str(e)
        results["error"] = error_msg[:200]
        results["success"] = False
        print(f"[ERROR] {error_msg[:100]}", file=sys.stderr)
    
    return results

async def main():
    """Main entry point"""
    config_json = sys.stdin.read()
    config = json.loads(config_json)
    
    all_results = []
    
    for site in config["target_websites"]:
        if site["search_enabled"]:
            site_name = site["name"]
            print(f"[INFO] Scraping {site_name}...", file=sys.stderr)
            
            result = await scrape_website(
                site["url"],
                config["search_terms"],
                config["scraping_config"]
            )
            
            result["site_name"] = site["name"]
            result["priority"] = site["priority"]
            all_results.append(result)
    
    print(json.dumps(all_results, indent=2))

if __name__ == "__main__":
    asyncio.run(main())
