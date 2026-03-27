#!/usr/bin/python3
import argparse
import json
import pathlib
import sys


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

    output_path.write_text(last_text.rstrip() + "\n", encoding="utf-8")
    print(f"output={output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
