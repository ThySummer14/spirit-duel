#!/usr/bin/env bash
# Headless verify for the Godot vertical slice.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-/Users/thysummer/apps/Godot.app/Contents/MacOS/Godot}"

if [[ ! -x "$GODOT" ]]; then
  echo "Godot binary not found: $GODOT" >&2
  exit 1
fi

if command -v node >/dev/null 2>&1; then
  echo "== export content =="
  node "$ROOT/scripts/export-godot-content.mjs"
fi

echo "== godot content + match verify =="
"$GODOT" --headless --path "$ROOT/godot" --script res://scripts/verify.gd
echo "== godot boot smoke =="
"$GODOT" --headless --path "$ROOT/godot" --quit-after 1
echo "GODOT_VERIFY_ALL_OK"
