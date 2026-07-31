# INTERNAL FR/OFFICIAL USE // FRSONLY
# SCRAPER.PY - Two-pass extraction with confidence scoring

import asyncio
import json
import re
import sys
from datetime import datetime
from urllib.parse import urljoin, urlparse

from playwright.async_api import async_playwright

COMMAND_PATTERNS = [
    r"\bmsiexec(\.exe)?\b.*\/(i|x)\b",
    r"\b[a-z0-9_.-]+\.exe\b\s+[/\-]",
    r"\bsetup(\.exe)?\b\s+[/\-]",
    r"\binstall(\.exe)?\b\s+[/\-]",
    r"\buninst(\.exe)?\b",
    r"\bchoco\s+(install|upgrade|uninstall)\b",
    r"\bStart-Process\b",
    r"\bRemove-Item\b",
    r"\bGet-ItemProperty\b",
    r"\bALLUSERS=\d\b",
    r"\/(qn|qb|quiet|passive|norestart|s|silent)\b",
]

LINK_KEYWORDS = [
    "silent",
    "install",
    "uninstall",
    "deployment",
    "switch",
    "parameter",
    "command",
    "msi",
    "powershell",
]

SKIP_TEXT_TOKENS = [
    "privacy",
    "cookie",
    "sign in",
    "log in",
    "copyright",
    "terms of service",
]


def normalize_text(value):
    return re.sub(r"\s+", " ", (value or "").strip())


def looks_like_link_only(value):
    text = normalize_text(value)
    if not text:
        return True
    if text.startswith("http://") or text.startswith("https://"):
        return True
    if len(text.split()) <= 3 and ("www." in text or ".com/" in text or ".org/" in text):
        return True
    return False


def is_likely_command(value):
    text = normalize_text(value)
    if not text or len(text) < 8:
        return False
    return any(re.search(pattern, text, re.IGNORECASE) for pattern in COMMAND_PATTERNS)


def infer_section_hints(candidate_text, candidate_context):
    full_text = f"{candidate_text} {candidate_context}".lower()
    hints = []

    if re.search(r"allusers|per-user|per-machine|hkcu|hklm|context", full_text):
        hints.append("context_selection")
    if re.search(r"choco uninstall|msiexec.*\/x|uninst\.exe|uninstall", full_text):
        hints.append("uninstall_command_line")
    if re.search(r"choco install|choco upgrade|msiexec.*\/i|\/quiet|\/qn|\/s|silent|setup\.exe", full_text):
        hints.append("install_command_line")
    if re.search(r"hklm.*uninstall|program files.*uninstall|uninstallstring|uninst\.exe.*path", full_text):
        hints.append("uninstall_executable")
    if re.search(r"prerequisite|before install|pre-install|check version|remove old", full_text):
        hints.append("pre_install_commands")
    if re.search(r"powershell|script|transform|mst|custom", full_text):
        hints.append("custom_install_commands")
    if re.search(r"after install|post-install|cleanup|shortcut|configure", full_text):
        hints.append("post_install_commands")
    if re.search(r"before uninstall|pre-uninstall|backup settings", full_text):
        hints.append("pre_uninstall_commands")
    if re.search(r"force remove|manual uninstall|cleanup files|remove registry", full_text):
        hints.append("custom_uninstall_commands")
    if re.search(r"after uninstall|post-uninstall|verify removed|final cleanup", full_text):
        hints.append("post_uninstall_commands")

    return hints


def compute_confidence(item, site_priority):
    source_type = item.get("source_type", "page_text")
    text = item.get("text", "")
    context = item.get("context", "")
    is_command = item.get("is_command", False)

    score = 0.15
    source_boost = {
        "input_field": 0.35,
        "code_block": 0.32,
        "table_command": 0.30,
        "page_text": 0.12,
    }
    score += source_boost.get(source_type, 0.1)

    if is_command:
        score += 0.28
    if re.search(r"\b(msiexec|choco|Start-Process|\.exe)\b", text, re.IGNORECASE):
        score += 0.15
    if re.search(r"\/(qn|quiet|s|silent|norestart)\b", text, re.IGNORECASE):
        score += 0.08
    if "example" in context.lower():
        score -= 0.06
    if looks_like_link_only(text):
        score -= 0.5

    score += max(0.0, (7 - min(site_priority, 7)) * 0.01)

    score = max(0.0, min(score, 0.99))
    return round(score, 3)


def unique_key(item):
    text = normalize_text(item.get("text", "")).lower()
    return re.sub(r"\s+", " ", text)


async def expand_collapsible_sections(page):
    selectors = [
        "button[aria-expanded='false']",
        "summary",
        "button:has-text('Show')",
        "button:has-text('Expand')",
        "button:has-text('More')",
        "a:has-text('Show')",
    ]

    for selector in selectors:
        try:
            locator = page.locator(selector)
            count = await locator.count()
            for idx in range(min(count, 8)):
                item = locator.nth(idx)
                try:
                    await item.click(timeout=1000)
                except Exception:
                    continue
        except Exception:
            continue


async def extract_inputs(page):
    return await page.evaluate(
        """
        () => {
            const items = [];
            const fields = document.querySelectorAll('input[type="text"], input[readonly], textarea');
            fields.forEach((f) => {
                const text = (f.value || f.getAttribute('value') || '').trim();
                if (text.length > 8) {
                    items.push({
                        text,
                        context: 'Extracted from HTML input field',
                        source_type: 'input_field'
                    });
                }
            });
            return items;
        }
        """
    )


async def extract_code_blocks(page):
    return await page.evaluate(
        """
        () => {
            const items = [];
            const blocks = document.querySelectorAll('code, pre, .command, .code-block, kbd, samp');
            blocks.forEach((b) => {
                const text = (b.innerText || b.textContent || '').trim();
                if (text.length > 8 && text.length < 4000) {
                    items.push({
                        text,
                        context: 'Extracted from code/pre block',
                        source_type: 'code_block'
                    });
                }
            });
            return items;
        }
        """
    )


async def extract_table_commands(page):
    return await page.evaluate(
        """
        () => {
            const items = [];
            const rows = document.querySelectorAll('table tr');
            rows.forEach((row) => {
                const cells = Array.from(row.querySelectorAll('th, td')).map(c => (c.innerText || '').trim()).filter(Boolean);
                if (cells.length < 2) return;

                const header = cells[0].toLowerCase();
                const looksLikeCommandCol = /command|example|switch|parameter|syntax/.test(header);
                if (!looksLikeCommandCol) return;

                const text = cells.slice(1).join(' | ').trim();
                if (text.length > 8) {
                    items.push({
                        text,
                        context: `Extracted from table row: ${cells[0]}`,
                        source_type: 'table_command'
                    });
                }
            });
            return items;
        }
        """
    )


def extract_text_fallback(text_content, search_terms):
    lines = [normalize_text(line) for line in (text_content or "").split("\n")]
    candidates = []
    search_lc = [term.lower() for term in search_terms]

    for idx, line in enumerate(lines):
        if len(line) < 12:
            continue
        line_lc = line.lower()
        if any(token in line_lc for token in SKIP_TEXT_TOKENS):
            continue
        has_keyword = any(term in line_lc for term in search_lc)
        is_command = is_likely_command(line)
        if not has_keyword and not is_command:
            continue

        start = max(0, idx - 2)
        end = min(len(lines), idx + 3)
        context = " | ".join([l for l in lines[start:end] if l])[:500]

        candidates.append(
            {
                "text": line[:700],
                "context": context,
                "is_command": is_command,
                "line_number": idx,
                "source_type": "page_text",
            }
        )

        if len(candidates) >= 25:
            break

    return candidates


async def discover_secondary_links(page, base_url, search_terms, max_links):
    discovered = await page.evaluate(
        """
        () => {
            const links = [];
            document.querySelectorAll('a[href]').forEach((a) => {
                const href = a.getAttribute('href') || '';
                const text = (a.innerText || a.textContent || '').trim();
                if (!href) return;
                links.push({ href, text });
            });
            return links;
        }
        """
    )

    base = urlparse(base_url)
    domain = base.netloc.lower()
    search_lc = [t.lower() for t in search_terms] + LINK_KEYWORDS
    accepted = []
    seen = set()

    for link in discovered:
        href = (link.get("href") or "").strip()
        anchor_text = normalize_text(link.get("text") or "")
        if not href:
            continue

        absolute = urljoin(base_url, href)
        parsed = urlparse(absolute)
        if parsed.scheme not in ("http", "https"):
            continue
        if parsed.netloc.lower() != domain:
            continue

        candidate = f"{absolute} {anchor_text}".lower()
        if not any(term in candidate for term in search_lc):
            continue

        normalized_url = f"{parsed.scheme}://{parsed.netloc}{parsed.path}"
        if parsed.query:
            normalized_url += f"?{parsed.query}"

        if normalized_url in seen:
            continue

        seen.add(normalized_url)
        accepted.append(normalized_url)
        if len(accepted) >= max_links:
            break

    return accepted


async def extract_page_candidates(page, page_url, search_terms, site_priority, scraping_config):
    await expand_collapsible_sections(page)

    candidates = []
    inputs = await extract_inputs(page)
    blocks = await extract_code_blocks(page)
    tables = await extract_table_commands(page)
    text_content = await page.evaluate("() => document.body ? document.body.innerText : ''")
    text_fallback = []
    if scraping_config.get("include_page_text_fallback", True):
        text_fallback = extract_text_fallback(text_content, search_terms)

    for item in inputs + blocks + tables + text_fallback:
        text = normalize_text(item.get("text", ""))
        context = normalize_text(item.get("context", ""))
        if not text or looks_like_link_only(text):
            continue

        is_command = bool(item.get("is_command")) or is_likely_command(text)
        if not is_command:
            has_keyword = any(term.lower() in f"{text} {context}".lower() for term in search_terms)
            if not has_keyword:
                continue

        section_hints = infer_section_hints(text, context)
        candidate = {
            "text": text[:1000],
            "context": context[:700],
            "is_command": is_command,
            "line_number": item.get("line_number", 0),
            "source_type": item.get("source_type", "page_text"),
            "source_url": page_url,
            "section_hints": section_hints,
        }
        candidate["confidence"] = compute_confidence(candidate, site_priority)
        candidate["why_selected"] = (
            f"source={candidate['source_type']}; "
            f"is_command={candidate['is_command']}; "
            f"hints={','.join(section_hints) if section_hints else 'none'}"
        )
        candidates.append(candidate)

    max_candidates = int(scraping_config.get("max_candidates_per_page", 30))
    candidates = sorted(candidates, key=lambda x: x.get("confidence", 0), reverse=True)[:max_candidates]
    return candidates


def dedupe_candidates(candidates, min_confidence):
    deduped = []
    seen = set()
    for item in sorted(candidates, key=lambda x: x.get("confidence", 0), reverse=True):
        key = unique_key(item)
        if not key or key in seen:
            continue
        if item.get("confidence", 0) < min_confidence:
            continue
        seen.add(key)
        deduped.append(item)
    return deduped


async def safe_goto(page, target_url, timeout_ms):
    await page.goto(target_url, timeout=timeout_ms, wait_until="domcontentloaded")
    try:
        await page.wait_for_load_state("networkidle", timeout=min(timeout_ms, 5000))
    except Exception:
        pass
    await page.wait_for_timeout(1200)


async def scrape_website(site, search_terms, scraping_config):
    url = site["url"]
    priority = int(site.get("priority", 5))

    results = {
        "url": url,
        "timestamp": datetime.now().isoformat(),
        "success": False,
        "data": [],
        "error": None,
    }

    timeout_ms = int(scraping_config.get("timeout_seconds", 30) * 1000)
    follow_links = bool(scraping_config.get("follow_secondary_links", True))
    max_secondary_pages = int(scraping_config.get("max_secondary_pages", 3))
    min_confidence = float(scraping_config.get("min_confidence", 0.2))

    try:
        async with async_playwright() as p:
            browser = await p.chromium.launch(
                headless=bool(scraping_config.get("headless", True)),
                channel="msedge",
            )

            context = await browser.new_context(
                user_agent=scraping_config.get(
                    "user_agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
                ),
                viewport={"width": 1920, "height": 1080},
            )

            collected = []

            page = await context.new_page()
            print("[INFO]   -> Loading landing page...", file=sys.stderr)
            await safe_goto(page, url, timeout_ms)
            landing_candidates = await extract_page_candidates(page, url, search_terms, priority, scraping_config)
            collected.extend(landing_candidates)
            print(f"[INFO]   -> Landing page candidates: {len(landing_candidates)}", file=sys.stderr)

            if follow_links and max_secondary_pages > 0:
                links = await discover_secondary_links(page, url, search_terms, max_secondary_pages)
                print(f"[INFO]   -> Following {len(links)} secondary links", file=sys.stderr)

                for idx, link in enumerate(links, start=1):
                    subpage = await context.new_page()
                    try:
                        print(f"[INFO]   -> [{idx}/{len(links)}] {link}", file=sys.stderr)
                        await safe_goto(subpage, link, timeout_ms)
                        link_candidates = await extract_page_candidates(
                            subpage, link, search_terms, priority, scraping_config
                        )
                        collected.extend(link_candidates)
                        print(f"[INFO]   -> Link candidates: {len(link_candidates)}", file=sys.stderr)
                    except Exception as link_error:
                        print(f"[WARN]   -> Skipped link ({str(link_error)[:90]})", file=sys.stderr)
                    finally:
                        await subpage.close()

            filtered = dedupe_candidates(collected, min_confidence=min_confidence)
            max_results = int(scraping_config.get("max_results_per_site", 10))
            results["data"] = filtered[: max(max_results, 1) * 3]
            results["success"] = True
            print(f"[INFO]   -> Total kept: {len(results['data'])}", file=sys.stderr)

            await context.close()
            await browser.close()

    except Exception as error:
        error_msg = str(error)
        results["error"] = error_msg[:300]
        print(f"[ERROR] {error_msg[:140]}", file=sys.stderr)

    return results


async def main():
    config_json = sys.stdin.read()
    config = json.loads(config_json)
    all_results = []

    for site in config.get("target_websites", []):
        if not site.get("search_enabled"):
            continue
        site_name = site.get("name", "Unknown Site")
        print(f"[INFO] Scraping {site_name}...", file=sys.stderr)

        result = await scrape_website(site, config.get("search_terms", []), config.get("scraping_config", {}))
        result["site_name"] = site_name
        result["priority"] = site.get("priority", 5)
        all_results.append(result)

    print(json.dumps(all_results, indent=2))


if __name__ == "__main__":
    asyncio.run(main())
