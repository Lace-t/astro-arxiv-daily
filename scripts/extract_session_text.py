#!/usr/bin/python3
import argparse
import json
import pathlib
import re
import sys


PAPER_BLOCK_START_RE = re.compile(r"(?m)^English Title:")


def trim_to_first_paper_block(text: str) -> str:
    match = PAPER_BLOCK_START_RE.search(text)
    if not match:
        return text.strip()
    return text[match.start():].strip()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--session", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    session_path = pathlib.Path(args.session)
    output_path = pathlib.Path(args.output)

    last_text = None
    with session_path.open(encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            event = json.loads(line)
            if event.get("type") != "message":
                continue
            message = event.get("message", {})
            if message.get("role") != "assistant":
                continue
            if message.get("stopReason") == "error":
                continue
            text_parts = []
            for item in message.get("content", []):
                if item.get("type") == "text":
                    text_parts.append(item.get("text", ""))
            combined = "\n".join(part for part in text_parts if part.strip()).strip()
            if combined:
                last_text = combined

    if not last_text:
        print("error=no_assistant_text_found", file=sys.stderr)
        return 1

    trimmed_text = trim_to_first_paper_block(last_text)
    output_path.write_text(trimmed_text + "\n", encoding="utf-8")
    print(f"output={output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
