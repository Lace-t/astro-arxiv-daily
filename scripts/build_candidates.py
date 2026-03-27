#!/usr/bin/python3
import argparse
import datetime as dt
import html
import json
import pathlib
import re
import urllib.request
import xml.etree.ElementTree as ET
from typing import Dict, List, Tuple


def clean_text(text: str) -> str:
    text = re.sub(r"<[^>]+>", " ", text)
    text = html.unescape(text)
    return re.sub(r"\s+", " ", text).strip()


def parse_today_section(recent_html: str) -> Tuple[str, List[dict]]:
    heading_match = re.search(
        r"<h3>\s*([^<]+?)\s*\(showing.*?</h3>(.*?)(?=<h3>|</dl>)",
        recent_html,
        re.DOTALL,
    )
    if not heading_match:
        raise SystemExit("Could not locate today's section in latest-astro-ph-recent.html")

    section_label = clean_text(heading_match.group(1))
    section_html = heading_match.group(2)
    pairs = re.findall(r"<dt>(.*?)</dt>\s*<dd>(.*?)</dd>", section_html, re.DOTALL)
    candidates = []
    for dt_html, dd_html in pairs:
        id_match = re.search(r'id="(\d{4}\.\d{5})"', dt_html)
        if not id_match:
            continue
        arxiv_id = id_match.group(1)
        title_match = re.search(
            r"<div class='list-title mathjax'>.*?<span class='descriptor'>Title:</span>(.*?)</div>",
            dd_html,
            re.DOTALL,
        )
        authors_match = re.search(
            r"<div class='list-authors'>(.*?)</div>",
            dd_html,
            re.DOTALL,
        )
        subjects_match = re.search(
            r"<div class='list-subjects'>.*?<span class='descriptor'>Subjects:</span>(.*?)</div>",
            dd_html,
            re.DOTALL,
        )
        comments_match = re.search(
            r"<div class='list-comments mathjax'>.*?<span class='descriptor'>Comments:</span>(.*?)</div>",
            dd_html,
            re.DOTALL,
        )
        candidates.append(
            {
                "arxiv_id": arxiv_id,
                "title": clean_text(title_match.group(1) if title_match else ""),
                "authors": clean_text(authors_match.group(1) if authors_match else ""),
                "subjects": clean_text(subjects_match.group(1) if subjects_match else ""),
                "comments": clean_text(comments_match.group(1) if comments_match else ""),
                "abstract_url": f"https://arxiv.org/abs/{arxiv_id}",
                "pdf_url": f"https://arxiv.org/pdf/{arxiv_id}",
                "html_url": f"https://arxiv.org/html/{arxiv_id}v1",
                "source_date": section_label,
            }
        )
    return section_label, candidates


def parse_rss(rss_xml: str) -> Dict[str, dict]:
    root = ET.fromstring(rss_xml)
    items: Dict[str, dict] = {}
    for item in root.findall("./channel/item"):
        link = item.findtext("link", default="")
        id_match = re.search(r"/abs/(\d{4}\.\d{5})", link)
        if not id_match:
            continue
        arxiv_id = id_match.group(1)
        description = item.findtext("description", default="")
        abstract = description
        if "Abstract:" in description:
            abstract = description.split("Abstract:", 1)[1].strip()
        items[arxiv_id] = {
            "rss_title": clean_text(item.findtext("title", default="")),
            "abstract": clean_text(abstract),
            "category": clean_text(item.findtext("category", default="")),
            "pub_date": clean_text(item.findtext("pubDate", default="")),
            "creator": clean_text(item.findtext("{http://purl.org/dc/elements/1.1/}creator", default="")),
            "link": link,
        }
    return items


def merge_candidates(today_label: str, candidates: List[dict], rss_map: Dict[str, dict]) -> dict:
    merged = []
    for candidate in candidates:
        rss_entry = rss_map.get(candidate["arxiv_id"], {})
        merged.append(
            {
                **candidate,
                "abstract": rss_entry.get("abstract", ""),
                "category": rss_entry.get("category", ""),
                "pub_date": rss_entry.get("pub_date", ""),
                "rss_creator": rss_entry.get("creator", ""),
                "rss_title": rss_entry.get("rss_title", ""),
            }
        )

    return {
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "source": {
            "recent_html": "logs/latest-astro-ph-recent.html",
            "rss_xml": "logs/latest-astro-ph-rss.xml",
            "today_label": today_label,
        },
        "total_candidates": len(merged),
        "candidates": merged,
    }


def fetch_url(url: str) -> str:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": (
                "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
                "(KHTML, like Gecko) Chrome/123.0 Safari/537.36"
            )
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8", errors="replace")


def hydrate_abstracts(candidates: List[dict], cache_dir: pathlib.Path) -> None:
    cache_dir.mkdir(parents=True, exist_ok=True)
    for candidate in candidates:
        if candidate.get("abstract"):
            continue
        arxiv_id = candidate["arxiv_id"]
        cache_path = cache_dir / f"{arxiv_id}.abs.html"
        try:
            if cache_path.exists():
                page = cache_path.read_text(encoding="utf-8")
            else:
                page = fetch_url(candidate["abstract_url"])
                cache_path.write_text(page, encoding="utf-8")
            abstract_match = re.search(
                r"<blockquote class=\"abstract mathjax\">.*?<span class=\"descriptor\">Abstract:</span>(.*?)</blockquote>",
                page,
                re.DOTALL,
            )
            if abstract_match:
                candidate["abstract"] = clean_text(abstract_match.group(1))
        except Exception as exc:
            candidate["abstract_fetch_error"] = str(exc)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--recent-html", required=True)
    parser.add_argument("--rss-xml", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--hydrate-abstracts", action="store_true")
    parser.add_argument("--abstract-cache-dir")
    args = parser.parse_args()

    recent_html = pathlib.Path(args.recent_html).read_text(encoding="utf-8")
    rss_xml = pathlib.Path(args.rss_xml).read_text(encoding="utf-8")
    output_path = pathlib.Path(args.output)

    today_label, candidates = parse_today_section(recent_html)
    rss_map = parse_rss(rss_xml)
    if args.hydrate_abstracts:
        cache_dir = pathlib.Path(
            args.abstract_cache_dir or output_path.parent / "abstract-cache"
        )
        hydrate_abstracts(candidates, cache_dir)
    payload = merge_candidates(today_label, candidates, rss_map)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"today_label={today_label}")
    print(f"candidate_count={payload['total_candidates']}")
    print(f"output={output_path}")


if __name__ == "__main__":
    main()
