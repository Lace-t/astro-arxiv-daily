#!/usr/bin/python3
import argparse
import json
import pathlib


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidates", required=True)
    parser.add_argument("--scoring", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--final-output", required=True)
    args = parser.parse_args()

    output_path = pathlib.Path(args.output).resolve()
    root_dir = output_path.parent.parent
    paper_dir = root_dir / "logs" / "papers"
    template_path = root_dir / "template.md"
    final_output_path = pathlib.Path(args.final_output).resolve()

    candidates = json.loads(pathlib.Path(args.candidates).read_text(encoding="utf-8"))
    scoring = json.loads(pathlib.Path(args.scoring).read_text(encoding="utf-8"))
    candidate_map = {paper["arxiv_id"]: paper for paper in candidates["candidates"]}
    scoring_map = {paper["arxiv_id"]: paper for paper in scoring["papers_scored"]}

    selected = []
    for arxiv_id in scoring["top3"]:
        candidate = candidate_map[arxiv_id]
        score = scoring_map[arxiv_id]
        selected.append(
            {
                "arxiv_id": arxiv_id,
                "title": candidate.get("title", ""),
                "authors": candidate.get("authors", ""),
                "subjects": candidate.get("subjects", ""),
                "abstract": candidate.get("abstract", ""),
                "abstract_url": candidate.get("abstract_url", ""),
                "pdf_url": candidate.get("pdf_url", ""),
                "html_url": candidate.get("html_url", ""),
                "score": {
                    "novelty": score["novelty"],
                    "results_conviction": score["results_conviction"],
                    "importance": score["importance"],
                    "total_score": score["total_score"],
                    "notes": score["notes"],
                },
                "local_files": {
                    "abs_html": str((paper_dir / f"{arxiv_id}.abs.html").resolve()),
                    "full_html": str((paper_dir / f"{arxiv_id}.full.html").resolve()),
                },
            }
        )

    output = {
        "selected_count": len(selected),
        "selected_papers": selected,
        "template_path": str(template_path),
        "final_output_path": str(final_output_path),
    }

    output_path.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"output={output_path}")


if __name__ == "__main__":
    main()
