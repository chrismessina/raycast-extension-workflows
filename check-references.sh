#!/usr/bin/env bash
# check-references.sh — anti-drift guard for the raycast-extensions plugin.
#
# Asserts that every `reference/X.md` a skill points to actually exists in the
# plugin's reference/ dir. Dangling references are the failure mode that lets a
# skill ship pointing at a file that was never authored (or lost from the install
# cache) — e.g. `ship` referencing pr-and-cleanup.md / store-guidelines.md.
#
# Run from the repo root (or anywhere): `bash check-references.sh`
# Exit 0 = all references resolve; exit 1 = at least one dangling reference.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$REPO_ROOT/plugins/raycast-extensions"
SKILLS_DIR="$PLUGIN_DIR/skills"
REFERENCE_DIR="$PLUGIN_DIR/reference"

if [[ ! -d "$SKILLS_DIR" ]]; then
  echo "ERROR: skills dir not found at $SKILLS_DIR" >&2
  exit 2
fi

# Collect every referenced reference/<name>.md across all skill markdown files,
# unique-sorted, then assert each exists in reference/. (Plain loop, not mapfile —
# macOS ships bash 3.2, which has no mapfile.) Use a temp marker for the failure
# flag so a subshell'd pipe loop can't swallow it.
refs="$(grep -rohE 'reference/[A-Za-z0-9-]+\.md' "$SKILLS_DIR" 2>/dev/null | sort -u)"
fail_marker="$(mktemp)"
trap 'rm -f "$fail_marker"' EXIT

echo "Checking referenced reference file(s) against $REFERENCE_DIR"
echo

IFS='
'
for ref in $refs; do
  [ -z "$ref" ] && continue
  base="$(basename "$ref")"
  if [ -f "$REFERENCE_DIR/$base" ]; then
    echo "  ok       $base"
  else
    echo "  MISSING  $base   <-- referenced by a skill but not authored"
    grep -rl "reference/$base" "$SKILLS_DIR" 2>/dev/null | sed "s|$REPO_ROOT/|             by: |"
    echo "x" >> "$fail_marker"
  fi
done
unset IFS

echo
if [ -s "$fail_marker" ]; then
  echo "FAIL: one or more skill references point at a reference file that does not exist."
  echo "      Author the missing file(s) in $REFERENCE_DIR, or remove the dangling reference."
  exit 1
fi
echo "PASS: every skill reference resolves."
