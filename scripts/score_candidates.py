#!/usr/bin/python3
import argparse
import json
import pathlib
import re


NOVELTY_KEYWORDS = {
    "first": 2,
    "new": 1,
    "novel": 2,
    "direct evidence": 2,
    "detected": 2,
    "detection": 2,
    "reveal": 1,
    "introduce": 1,
    "framework": 1,
    "method": 1,
    "measurement": 1,
}

CONVICTION_KEYWORDS = {
    "observ": 2,
    "measurement": 2,
    "constraints": 2,
    "data": 1,
    "survey": 1,
    "analysis": 1,
    "comparison": 1,
    "desi": 1,
    "planck": 1,
    "gaia": 1,
    "jwst": 1,
}

IMPORTANCE_KEYWORDS = {
    "dark matter": 2,
    "dark energy": 2,
    "black hole": 2,
    "cmb": 2,
    "jwst": 2,
    "desi": 2,
    "gaia": 2,
    "gravitational wave": 2,
    "supernova": 2,
    "galaxy": 1,
    "cosmology": 1,
    "exoplanet": 1,
}


def keyword_score(text: str, mapping: dict, base: int = 1) -> int:
    score = base
    lower = text.lower()
    for keyword, weight in mapping.items():
        if keyword in lower:
            score += weight
    return min(score, 5)


def empirical_bonus(text: str) -> int:
    lower = text.lower()
    bonus_terms = ["observ", "measurement", "survey", "map", "detected", "data"]
    return sum(1 for term in bonus_terms if term in lower)


def normalize_authors(authors: str) -> str:
    return re.sub(r"\s+,", ",", authors).strip()


def score_paper(candidate: dict) -> dict:
    combined = " ".join(
        [
            candidate.get("title", ""),
            candidate.get("subjects", ""),
            candidate.get("comments", ""),
            candidate.get("abstract", ""),
        ]
    )
    novelty = keyword_score(combined, NOVELTY_KEYWORDS)
    results_conviction = keyword_score(combined, CONVICTION_KEYWORDS)
    importance = keyword_score(combined, IMPORTANCE_KEYWORDS)
    total_score = novelty + results_conviction + importance
    snippet = candidate.get("abstract", "")[:280].strip()
    return {
        "arxiv_id": candidate["arxiv_id"],
        "title": candidate.get("title", ""),
        "category": candidate.get("category") or candidate.get("subjects", ""),
        "submission_date": candidate.get("source_date", ""),
        "authors": normalize_authors(candidate.get("authors", "")),
        "novelty": novelty,
        "results_conviction": results_conviction,
        "importance": importance,
        "total_score": total_score,
        "empirical_support": empirical_bonus(combined),
        "notes": snippet,
    }


def sort_key(paper: dict):
    return (
        paper["total_score"],
        paper["importance"],
        paper["novelty"],
        paper["empirical_support"],
        paper["arxiv_id"],
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidates", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--date", required=True)
    args = parser.parse_args()

    candidates_path = pathlib.Path(args.candidates)
    payload = json.loads(candidates_path.read_text(encoding="utf-8"))
    scored = [score_paper(candidate) for candidate in payload["candidates"]]
    scored.sort(key=sort_key, reverse=True)
    top3 = [paper["arxiv_id"] for paper in scored[:3]]

    output = {
        "date": args.date,
        "total_papers_found": len(payload["candidates"]),
        "scoring_criteria": {
            "novelty": "Keyword- and abstract-based heuristic emphasizing new methods, detections, or first-of-kind claims",
            "results_conviction": "Heuristic emphasizing observational or measurement-driven evidence and explicit datasets",
            "importance": "Heuristic emphasizing broad astrophysics impact topics such as dark matter, cosmology, black holes, JWST, DESI, and supernovae",
        },
        "papers_scored": scored,
        "top3": top3,
    }

    output_path = pathlib.Path(args.output)
    output_path.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"scored_count={len(scored)}")
    print(f"top3={','.join(top3)}")
    print(f"output={output_path}")


if __name__ == "__main__":
    main()
