#!/usr/bin/python3
import argparse
import json
import pathlib
import re
from typing import List
from html import unescape


def strip_html(text: str) -> str:
    text = re.sub(r"(?is)<script.*?</script>", " ", text)
    text = re.sub(r"(?is)<style.*?</style>", " ", text)
    text = re.sub(r"(?s)<[^>]+>", " ", text)
    text = unescape(text)
    return re.sub(r"\s+", " ", text).strip()


def read_html(path: pathlib.Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def extract_article_html(full_html: str) -> str:
    match = re.search(r"(?is)<article\b[^>]*>(.*)</article>", full_html)
    return match.group(1) if match else full_html


def extract_abstract(abs_html: str) -> str:
    match = re.search(
        r'(?s)<blockquote class="abstract mathjax">.*?<span class="descriptor">Abstract:</span>(.*?)</blockquote>',
        abs_html,
    )
    return strip_html(match.group(1)) if match else ""


def extract_section(article_html: str, section_keywords: List[str], max_chars: int = 900) -> str:
    heading_pattern = r'<h[2-4][^>]*class="[^"]*ltx_title_[^"]*section[^"]*"[^>]*>(.*?)</h[2-4]>'
    matches = list(re.finditer(heading_pattern, article_html, re.IGNORECASE | re.DOTALL))
    if not matches:
        return ""

    for index, match in enumerate(matches):
        heading_text = strip_html(match.group(1)).lower()
        if not any(keyword in heading_text for keyword in section_keywords):
            continue
        section_start = match.end()
        section_end = matches[index + 1].start() if index + 1 < len(matches) else len(article_html)
        section_html = article_html[section_start:section_end]
        paragraphs = re.findall(r"(?is)<p\b[^>]*>(.*?)</p>", section_html)
        clean_paragraphs = []
        for paragraph in paragraphs:
            text = strip_html(paragraph)
            if len(text) < 80:
                continue
            if "Cited by:" in text or "References" in text:
                continue
            clean_paragraphs.append(text)
            if len(" ".join(clean_paragraphs)) >= max_chars:
                break
        joined = " ".join(clean_paragraphs).strip()
        if joined:
            return joined[:max_chars].strip()
    return ""


def summarize_full_html(article_html: str, max_chars: int = 700) -> str:
    body = strip_html(article_html)
    return body[:max_chars].strip()


def compact_authors(authors: str, max_authors: int = 6) -> str:
    parts = [part.strip() for part in authors.split(",") if part.strip()]
    if len(parts) <= max_authors:
        return ", ".join(parts)
    return ", ".join(parts[:max_authors]) + ", et al."


def compact_score_notes(notes: str, max_chars: int = 240) -> str:
    return notes[:max_chars].strip()


def clip(text: str, max_chars: int) -> str:
    text = re.sub(r"\s+", " ", text or "").strip()
    return text[:max_chars].strip()


def build_notes_entry(paper: dict) -> dict:
    abs_path = pathlib.Path(paper["local_files"]["abs_html"])
    full_path = pathlib.Path(paper["local_files"]["full_html"])
    abs_html = read_html(abs_path)
    full_html = read_html(full_path)
    article_html = extract_article_html(full_html)

    abstract = paper.get("abstract") or extract_abstract(abs_html)
    introduction = extract_section(article_html, ["introduction", "background"], max_chars=700)
    methods = extract_section(
        article_html,
        ["method", "methods", "methodology", "observation", "observations", "analysis", "data reduction"],
        max_chars=800,
    )
    results = extract_section(article_html, ["result", "results", "finding", "findings"], max_chars=800)
    discussion = extract_section(article_html, ["discussion"], max_chars=700)
    conclusion = extract_section(article_html, ["conclusion"], max_chars=700)
    fallback_excerpt = summarize_full_html(article_html, max_chars=600)

    return {
        "arxiv_id": paper["arxiv_id"],
        "title": paper["title"],
        "authors": compact_authors(paper["authors"]),
        "subjects": paper["subjects"],
        "score": {
            "novelty": paper["score"]["novelty"],
            "results_conviction": paper["score"]["results_conviction"],
            "importance": paper["score"]["importance"],
            "total_score": paper["score"]["total_score"],
            "notes": compact_score_notes(paper["score"]["notes"]),
        },
        "abstract": clip(abstract, 520),
        "background_excerpt": clip(introduction, 260),
        "method_excerpt": clip(methods, 260),
        "results_excerpt": clip(results, 260),
        "discussion_excerpt": clip(discussion, 220),
        "conclusion_excerpt": clip(conclusion, 260),
        "fallback_excerpt": clip(fallback_excerpt, 180),
    }


def render_text_notes(notes: dict) -> str:
    lines = [
        "astro-arxiv-daily compact notes",
        "selected_count: {}".format(notes["selected_count"]),
        "template_path: {}".format(notes["template_path"]),
        "final_output_path: {}".format(notes["final_output_path"]),
        "",
    ]

    for index, paper in enumerate(notes["papers"], start=1):
        lines.extend(
            [
                "Paper {}".format(index),
                "arXiv ID: {}".format(paper["arxiv_id"]),
                "Title: {}".format(paper["title"]),
                "Authors: {}".format(paper["authors"]),
                "Subjects: {}".format(paper["subjects"]),
                "Score: novelty={n}, results_conviction={r}, importance={i}, total={t}".format(
                    n=paper["score"]["novelty"],
                    r=paper["score"]["results_conviction"],
                    i=paper["score"]["importance"],
                    t=paper["score"]["total_score"],
                ),
                "Score Notes: {}".format(paper["score"]["notes"]),
                "Abstract: {}".format(paper["abstract"]),
                "Background: {}".format(paper["background_excerpt"] or "N/A"),
                "Method: {}".format(paper["method_excerpt"] or "N/A"),
                "Results: {}".format(paper["results_excerpt"] or "N/A"),
                "Discussion: {}".format(paper["discussion_excerpt"] or "N/A"),
                "Conclusion: {}".format(paper["conclusion_excerpt"] or "N/A"),
                "",
                "====",
                "",
            ]
        )
    return "\n".join(lines).rstrip() + "\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--top3-context", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    payload = json.loads(pathlib.Path(args.top3_context).read_text(encoding="utf-8"))
    notes = {
        "selected_count": payload["selected_count"],
        "template_path": payload["template_path"],
        "final_output_path": payload["final_output_path"],
        "papers": [build_notes_entry(paper) for paper in payload["selected_papers"]],
    }

    output_path = pathlib.Path(args.output)
    if output_path.suffix.lower() == ".txt":
        output_text = render_text_notes(notes)
    else:
        output_text = json.dumps(notes, ensure_ascii=False, indent=2) + "\n"
    output_path.write_text(output_text, encoding="utf-8")
    print(f"output={output_path}")


if __name__ == "__main__":
    main()
