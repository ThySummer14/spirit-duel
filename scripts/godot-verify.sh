#!/usr/bin/env bash
# Headless verify for the Godot vertical slice.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-/Users/thysummer/apps/Godot.app/Contents/MacOS/Godot}"

if [[ ! -x "$GODOT" ]]; then
  echo "Godot binary not found: $GODOT" >&2
  exit 1
fi

run_godot_check() {
  local check_log check_status check_line
  check_log="$(mktemp)"
  if "$GODOT" --headless --path "$ROOT/godot" "$@" >"$check_log" 2>&1; then
    check_status=0
  else
    check_status=$?
  fi
  cat "$check_log"
  while IFS= read -r check_line; do
    case "$check_line" in
      *"SCRIPT ERROR:"*|*"ERROR:"*) check_status=1 ;;
    esac
  done <"$check_log"
  rm -f "$check_log"
  return "$check_status"
}

if command -v node >/dev/null 2>&1; then
  echo "== export content =="
  node "$ROOT/scripts/export-godot-content.mjs"
fi

echo "== godot import assets =="
run_godot_check --editor --import

for check_script in verify verify_combat verify_growth verify_draw verify_ui verify_save verify_collection verify_interactions verify_reference_workflow verify_presentation verify_art verify_roster; do
  echo "== godot $check_script =="
  run_godot_check --script "res://scripts/$check_script.gd"
done
echo "== godot seeded matches =="
run_godot_check --script res://scripts/playtest_burst.gd -- 60
run_godot_check --script res://scripts/playtest_focus.gd -- 20
echo "== godot boot smoke =="
run_godot_check --quit-after 1
echo "GODOT_VERIFY_ALL_OK"
