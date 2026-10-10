#!/usr/bin/env bash
# Headless acceptance for the eight verified shikigami (verified_rules.json scope).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-godot}"

if ! command -v "$GODOT" >/dev/null 2>&1 && [[ ! -x "$GODOT" ]]; then
  echo "Set GODOT_BIN to a Godot 4.4+ headless binary (project targets 4.8 features)." >&2
  exit 1
fi

if command -v node >/dev/null 2>&1; then
  echo "== export content =="
  node "$ROOT/scripts/export-godot-content.mjs"
fi

echo "== godot import (registers global classes) =="
"$GODOT" --headless --path "$ROOT/godot" --import >/dev/null

RULE_SCRIPTS=(
  verify_steel_wind verify_steel_wind_ui
  verify_yaoginshi verify_yaoginshi_ui
  verify_datiangou verify_datiangou_ui
  verify_yimulian verify_yimulian_ui
  verify_zhen verify_zhen_ui
  verify_phoenix verify_phoenix_ui
  verify_peach verify_peach_ui
  verify_firefly verify_firefly_ui
  verify_parallel_rules
)

for script in "${RULE_SCRIPTS[@]}"; do
  echo "== $script =="
  log="$(mktemp)"
  if ! "$GODOT" --headless --path "$ROOT/godot" --script "res://scripts/$script.gd" >"$log" 2>&1; then
    cat "$log"
    rm -f "$log"
    exit 1
  fi
  cat "$log"
  if ! grep -qE '_OK$' "$log"; then
    echo "missing _OK marker in $script output" >&2
    rm -f "$log"
    exit 1
  fi
  rm -f "$log"
done

echo "GODOT_VERIFIED_EIGHT_OK"
