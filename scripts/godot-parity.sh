#!/usr/bin/env bash
# 双实现对拍入口：JS 跑样本 → Godot 跑同一样本 → 比对快照
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/Users/thysummer/apps/Godot.app/Contents/MacOS/Godot}"
SAMPLE="${1:-$ROOT/scripts/parity/sample-origin.json}"
OUT_DIR="${2:-$ROOT/scripts/parity/out}"
BASE="$(basename "$SAMPLE" .json)"
mkdir -p "$OUT_DIR"

echo "== export content =="
node "$ROOT/scripts/export-godot-content.mjs"

echo "== JS parity: $SAMPLE =="
node "$ROOT/scripts/parity/run-js.mjs" "$SAMPLE" "$OUT_DIR/$BASE-js.json"

echo "== Godot parity: $SAMPLE =="
SAMPLE_ABS="$(cd "$(dirname "$SAMPLE")" && pwd)/$(basename "$SAMPLE")"
OUT_ABS="$(cd "$OUT_DIR" && pwd)/$BASE-godot.json"
PARITY_SAMPLE_ABS="$SAMPLE_ABS" "$GODOT_BIN" --headless --path "$ROOT/godot" --script res://scripts/parity_run.gd -- \
  "$SAMPLE_ABS" "$OUT_ABS"

echo "== compare =="
node "$ROOT/scripts/parity/compare.mjs" \
  "$OUT_DIR/$BASE-js.json" \
  "$OUT_DIR/$BASE-godot.json" \
  "$OUT_DIR/$BASE-report.json"
