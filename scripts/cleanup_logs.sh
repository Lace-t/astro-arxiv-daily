#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$ROOT/logs"

if [[ ! -d "$LOG_DIR" ]]; then
  exit 0
fi

find "$LOG_DIR" -mindepth 1 ! -name '.gitkeep' -exec rm -rf {} +
