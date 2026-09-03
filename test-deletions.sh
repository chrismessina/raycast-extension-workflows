#!/usr/bin/env bash
# Self-check for the upstream-deletion classifier ported into
# sync-from-upstream.yml. Extracts the loop from the real workflow (so it
# cannot drift from what ships) and runs it against a scratch git repo.
set -euo pipefail

WF="${1:?usage: test_deletions.sh <sync-from-upstream.yml>}"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# --- pull the deletion block out of the workflow's compare step -------------
python3 - "$WF" > "$WORK/deletions.sh" <<'PY'
import sys, yaml, re
d = yaml.safe_load(open(sys.argv[1]))
run = [s for s in d['jobs']['sync']['steps']
       if s['name'] == 'Fetch upstream file list and compare'][0]['run']
start = run.index(': > "$RUNNER_TEMP/to-delete.txt"')
end = run.index('UPD=$(wc -l')
block = run[start:end]
assert 'done < "$RUNNER_TEMP/baseline.tsv"' in block, "loop not captured"
assert 'refusing to propagate' in block, "guard not captured"
print(re.sub(r'\$\{\{[^}]*\}\}', 'X', block))
PY

# --- scratch mirror --------------------------------------------------------
export RUNNER_TEMP="$WORK/tmp"; mkdir -p "$RUNNER_TEMP"
REPO="$WORK/repo"; mkdir -p "$REPO"; cd "$REPO"
git init -q .; git config user.email t@t; git config user.name t

printf 'ignored\n' > .gitignore

mk() { mkdir -p "$(dirname "$1")"; printf '%s' "$2" > "$1"; }

mk keep.ts        'v1'   # still served upstream       -> untouched
mk gone-clean.ts  'v1'   # gone upstream, matches base -> DELETE
mk gone-dirty.ts  'MINE' # gone upstream, edited here  -> KEEP
mk ignored        'x'    # gone upstream, gitignored   -> skip
mk untracked.ts   'v1'   # gone upstream, never added  -> skip
# gone-missing.ts: in baseline, already absent on disk -> skip
git add .gitignore keep.ts gone-clean.ts gone-dirty.ts
git commit -qm init

V1=$(printf 'v1' | git hash-object --stdin)

# baseline = what upstream served last sync
{
  printf 'keep.ts\t%s\n'         "$V1"
  printf 'gone-clean.ts\t%s\n'   "$V1"
  printf 'gone-dirty.ts\t%s\n'   "$V1"
  printf 'ignored\t%s\n'         "$V1"
  printf 'untracked.ts\t%s\n'    "$V1"
  printf 'gone-missing.ts\t%s\n' "$V1"
} > "$RUNNER_TEMP/baseline.tsv"

# upstream now serves only keep.ts
printf 'keep.ts\t%s\n' "$V1" > "$RUNNER_TEMP/upstream.tsv"

set +e
bash "$WORK/deletions.sh"; RC=$?
set -e

fail() { echo "FAIL: $1"; exit 1; }
[ "$RC" -eq 0 ] || fail "guard tripped on 1-of-6 (rc=$RC)"

got_del=$(sort "$RUNNER_TEMP/to-delete.txt" | tr '\n' ' ')
got_kept=$(sort "$RUNNER_TEMP/deleted-upstream-kept.txt" | tr '\n' ' ')
[ "$got_del"  = "gone-clean.ts " ] || fail "to-delete = '$got_del'"
[ "$got_kept" = "gone-dirty.ts " ] || fail "kept = '$got_kept'"

# --- the mass-deletion guard --------------------------------------------
# Threshold is strictly MORE than half, so exactly half must still pass: a
# 2-file baseline losing 1 file is an ordinary deletion, not an incident.
printf 'keep.ts\t%s\n' "$V1" > "$RUNNER_TEMP/upstream.tsv"
for n in 1 2 3 4; do
  mk "bulk$n.ts" 'v1'; git add "bulk$n.ts"
  printf 'bulk%s.ts\t%s\n' "$n" "$V1" >> "$RUNNER_TEMP/baseline.tsv"
done
git commit -qm bulk
set +e
bash "$WORK/deletions.sh" >/dev/null 2>&1; RC=$?
set -e
[ "$RC" -eq 0 ] || fail "guard tripped at exactly half (5 of 10)"

# One more deletion crosses it: 6 of 11.
mk bulk5.ts 'v1'; git add bulk5.ts; git commit -qm bulk5
printf 'bulk5.ts\t%s\n' "$V1" >> "$RUNNER_TEMP/baseline.tsv"
set +e
OUT=$(bash "$WORK/deletions.sh" 2>&1); RC=$?
set -e
[ "$RC" -ne 0 ] || fail "guard did NOT trip on 6-of-11"
grep -q 'refusing to propagate a deletion that large' <<<"$OUT" \
  || fail "guard tripped with the wrong message: $OUT"

echo "PASS  delete=gone-clean.ts  keep=gone-dirty.ts  skipped=ignored/untracked/missing  guard=fails-closed"
