"""Crawl Taiwan Judicial Yuan judgments using Playwright.

Usage:
    python crawl_judgments.py --keyword "加重詐欺" --max-pages 3
    python crawl_judgments.py --keywords-file keywords.txt --max-pages 3

The script is intentionally conservative: it paces requests, does not bypass
rate limits, and stores raw HTML/text so downstream parsing can happen offline.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import random
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from urllib.parse import urljoin

from bs4 import BeautifulSoup
from playwright.async_api import async_playwright


SEARCH_URL = "https://judgment.judicial.gov.tw/FJUD/default.aspx"
CRAWLER_USER_AGENT = (
    "TaiwanLegalSupport-Research/1.0 "
    "(+contact: 20xianiax02@gmail.com; respects robots.txt)"
)
REQUEST_INTERVAL_SECONDS = (3.0, 5.0)


@dataclass
class RawJudgment:
    case_id: str
    source_url: str
    court_level: str
    raw_text: str


async def _extract_results(page) -> list[str]:
    html = await page.content()
    soup = BeautifulSoup(html, "lxml")
    links: list[str] = []
    for a in soup.select("a[href*='FJUD/data.aspx']"):
        href = a.get("href")
        if href:
            links.append(urljoin(SEARCH_URL, href))
    return links


async def _fetch_judgment(page, url: str) -> RawJudgment | None:
    await page.goto(url, wait_until="domcontentloaded", timeout=30_000)
    html = await page.content()
    soup = BeautifulSoup(html, "lxml")

    case_id_el = soup.select_one("#jud_case")
    title_el = soup.select_one("#jud_title, .jud-title")
    body_el = soup.select_one("#jud")
    if body_el is None:
        return None

    case_id = (case_id_el.get_text(strip=True) if case_id_el else "").strip()
    title = (title_el.get_text(strip=True) if title_el else "").strip()
    if not case_id:
        case_id = title or url.rsplit("id=", 1)[-1]
    court_level = _infer_court_level(title or case_id)
    raw_text = body_el.get_text("\n", strip=True)
    return RawJudgment(
        case_id=case_id,
        source_url=url,
        court_level=court_level,
        raw_text=raw_text,
    )


def _infer_court_level(text: str) -> str:
    if "最高" in text:
        return "最高法院"
    if "高等" in text:
        return "高等法院"
    if "地方" in text or "地院" in text:
        return "地方法院"
    return "未知"


async def crawl(
    keyword: str,
    max_pages: int,
    output_path: Path,
    headless: bool = True,
) -> int:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    written = 0
    async with async_playwright() as pw:
        browser = await pw.chromium.launch(headless=headless)
        context = await browser.new_context(user_agent=CRAWLER_USER_AGENT)
        page = await context.new_page()
        await page.goto(SEARCH_URL, wait_until="domcontentloaded")
        await page.fill("input[name='txtKW']", keyword)
        await page.click("input[name='btnSimpleQry']")
        await page.wait_for_load_state("networkidle")

        with output_path.open("a", encoding="utf-8") as sink:
            for page_idx in range(max_pages):
                links = await _extract_results(page)
                for link in links:
                    judgment_page = await context.new_page()
                    try:
                        judgment = await _fetch_judgment(judgment_page, link)
                    except Exception as exc:
                        print(f"[warn] skip {link}: {exc}", file=sys.stderr)
                        judgment = None
                    finally:
                        await judgment_page.close()
                    if judgment is None:
                        continue
                    sink.write(
                        json.dumps(asdict(judgment), ensure_ascii=False) + "\n"
                    )
                    written += 1
                    await asyncio.sleep(random.uniform(*REQUEST_INTERVAL_SECONDS))
                next_link = await page.query_selector(
                    "a:has-text('下一頁'), a:has-text('下頁')"
                )
                if not next_link:
                    break
                await next_link.click()
                await page.wait_for_load_state("networkidle")
                await asyncio.sleep(random.uniform(*REQUEST_INTERVAL_SECONDS))

        await browser.close()
    return written


def _load_keywords(path: Path) -> list[str]:
    raw = path.read_text(encoding="utf-8")
    keywords: list[str] = []
    for line in raw.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        keywords.append(line)
    return keywords


def main() -> None:
    parser = argparse.ArgumentParser(description="Crawl 司法院 judgments")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--keyword", help="單一搜尋關鍵字")
    group.add_argument(
        "--keywords-file",
        type=Path,
        help="Path to a text file; one keyword per line (blank lines and # comments ignored)",
    )
    parser.add_argument("--max-pages", type=int, default=3)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("output/crawled.jsonl"),
    )
    parser.add_argument("--no-headless", action="store_true")
    args = parser.parse_args()

    if args.keywords_file:
        keywords = _load_keywords(args.keywords_file)
        if not keywords:
            print(
                f"[ERROR] No keywords found in {args.keywords_file}.",
                file=sys.stderr,
            )
            sys.exit(1)
    else:
        keywords = [args.keyword]

    total = 0
    for idx, kw in enumerate(keywords, 1):
        print(f"[{idx}/{len(keywords)}] Crawling '{kw}' ...")
        written = asyncio.run(
            crawl(
                keyword=kw,
                max_pages=args.max_pages,
                output_path=args.output,
                headless=not args.no_headless,
            )
        )
        print(f"[{idx}/{len(keywords)}] {kw} done ({written} judgments)")
        total += written

    print(f"Total: {total} judgments into {args.output}")


if __name__ == "__main__":
    main()
