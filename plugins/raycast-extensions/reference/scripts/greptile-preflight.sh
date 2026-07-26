#!/usr/bin/env bash
# greptile-preflight.sh — run the checkable half of raycast/extensions' review gauntlet
# BEFORE opening the Store PR, instead of learning it from greptile-apps[bot] afterward.
#
# Covers Tier 1 (Greptile's confirmed custom rules) + the mechanically checkable parts of
# Tier 2 (upstream's .github/copilot-instructions.md) + the CI enforcers. The judgment-call
# half — duplication, screenshot authenticity, async lifecycle — is a human checklist in
# ../greptile-review-rules.md and is deliberately NOT faked here.
#
#   bash greptile-preflight.sh                 # cwd must be the extension root
#   bash greptile-preflight.sh --path DIR      # or point it at one
#   bash greptile-preflight.sh --quiet         # findings only, no per-check ok lines
#
# Exit 0 = no FAIL. Exit 1 = at least one FAIL. Exit 2 = not an extension root / bad usage.
#
# WARN never affects the exit code: every WARN here is a heuristic that has legitimate
# exceptions, and a gate that cries wolf gets disabled. Read them; don't automate on them.
#
# bash 3.2 compatible (macOS ships 3.2 — no mapfile, no associative arrays).

set -uo pipefail   # NOT -e: greps that find nothing return 1 and that is normal here.

EXT_ROOT="."
QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --path) EXT_ROOT="${2:?--path needs a directory}"; shift 2 ;;
    --quiet|-q) QUIET=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

cd "$EXT_ROOT" 2>/dev/null || { echo "ERROR: cannot cd to $EXT_ROOT" >&2; exit 2; }

FAILS=0
WARNS=0
fail() { printf '  FAIL  %s\n' "$1"; [ $# -gt 1 ] && printf '        %s\n' "$2"; FAILS=$((FAILS+1)); }
warn() { printf '  WARN  %s\n' "$1"; [ $# -gt 1 ] && printf '        %s\n' "$2"; WARNS=$((WARNS+1)); }
ok()   { [ "$QUIET" -eq 1 ] || printf '  ok    %s\n' "$1"; }
head2(){ [ "$QUIET" -eq 1 ] || printf '\n%s\n' "$1"; }

command -v jq >/dev/null || { echo "ERROR: jq is required" >&2; exit 2; }

# --- extension-root gate -----------------------------------------------------------------
# Testing `.commands` alone is too loose: {"commands":"anything-truthy"} passes `jq -e`.
# Require a non-empty ARRAY, the same assertion review-pr uses to prove a clone is at the
# extension root rather than a monorepo root.
if ! jq -e '(.commands|type=="array") and (.commands|length>0)' package.json >/dev/null 2>&1; then
  echo "ERROR: $(pwd) is not a Raycast extension root (no package.json with a non-empty commands array)." >&2
  echo "       Run from extensions/<name>/, or pass --path." >&2
  exit 2
fi

EXT_TITLE="$(jq -r '.title // ""' package.json)"
printf 'greptile-preflight — %s (%s)\n' "${EXT_TITLE:-untitled}" "$(pwd)"

# PNG dimensions from the IHDR header, without ImageMagick/sips (absent on Linux CI and
# increasingly on macOS). Echoes "WIDTHxHEIGHT", or nothing if it cannot read the file.
png_dims() {
  python3 - "$1" 2>/dev/null <<'PY'
import struct, sys
try:
    with open(sys.argv[1], 'rb') as f:
        head = f.read(24)
    if head[:8] != b'\x89PNG\r\n\x1a\n' or head[12:16] != b'IHDR':
        sys.exit(1)
    w, h = struct.unpack('>II', head[16:24])
    print(f"{w}x{h}")
except Exception:
    sys.exit(1)
PY
}

# ------------------------------------------------------------------------------------------
head2 "R1 — CHANGELOG / {PR_MERGE_DATE}"
# ------------------------------------------------------------------------------------------
if [ ! -f CHANGELOG.md ]; then
  fail "CHANGELOG.md is missing." "changelog_enforcer.yml fails the PR outright."
else
  TOP_ENTRY="$(grep -m1 '^## ' CHANGELOG.md)"
  if [ -z "$TOP_ENTRY" ]; then
    fail "CHANGELOG.md has no '## [Title] - date' entry." "Expected: ## [Description] - {PR_MERGE_DATE}"
  elif ! printf '%s' "$TOP_ENTRY" | grep -q '{PR_MERGE_DATE}'; then
    fail "Top CHANGELOG entry hard-codes a date: $TOP_ENTRY" \
         "Rule Used: Changelog entries must use {PR_MERGE_DATE}  (P1, fires every time)"
  else
    ok "top entry uses {PR_MERGE_DATE}"
  fi

  # More than one placeholder means an ALREADY-DATED older entry was reverted. CI re-stamps
  # every placeholder with the same merge date, so the whole history reads as shipped today.
  PLACEHOLDERS="$(grep -c '{PR_MERGE_DATE}' CHANGELOG.md)"
  if [ "$PLACEHOLDERS" -gt 1 ]; then
    fail "$PLACEHOLDERS entries carry {PR_MERGE_DATE} — only the new one may." \
         "CI stamps them all with this merge date. Restore the real dates on older entries."
  fi

  if printf '%s' "$TOP_ENTRY" | grep -q '\[Initial Version\]'; then
    warn "First entry titled [Initial Version]." "Greptile asks for [Initial Release] (#28997, #28834)."
  fi
fi

# ------------------------------------------------------------------------------------------
head2 "R2 — hand-defined Preferences / Arguments types"
# ------------------------------------------------------------------------------------------
# The generated types live in raycast-env.d.ts. A hand-written copy keeps compiling after the
# manifest changes, which is the drift Greptile names. Declarations only — a `Preferences.Foo`
# reference is correct usage and must not match.
HANDTYPES="$(grep -rnE '^[[:space:]]*(export[[:space:]]+)?(interface|type)[[:space:]]+(Preferences|Arguments)\b' \
             src 2>/dev/null)"
if [ -n "$HANDTYPES" ]; then
  fail "Hand-defined Preferences/Arguments type(s):" \
       "Rule Used: Don't manually define Preferences for getPreferenceValues()"
  printf '%s\n' "$HANDTYPES" | sed 's/^/          /'
else
  ok "no hand-defined Preferences/Arguments declarations"
fi

# ------------------------------------------------------------------------------------------
head2 "R3 — .prettierrc"
# ------------------------------------------------------------------------------------------
if [ ! -f .prettierrc ]; then
  warn "No extension-local .prettierrc." "Raycast's scaffold ships {\"printWidth\":120,\"singleQuote\":false}."
else
  PW="$(jq -r '.printWidth // "absent"' .prettierrc 2>/dev/null)"
  SQ="$(jq -r 'if has("singleQuote") then (.singleQuote|tostring) else "absent" end' .prettierrc 2>/dev/null)"
  BAD=0
  [ "$PW" = "120" ] || { fail ".prettierrc printWidth is $PW, must be 120."; BAD=1; }
  # The rule wants the option EXPLICITLY present — defaulting to false does not satisfy it.
  [ "$SQ" = "false" ] || { fail ".prettierrc singleQuote is $SQ, must be explicitly false."; BAD=1; }
  [ "$BAD" -eq 0 ] && ok "printWidth 120 + explicit singleQuote false"
fi

# ------------------------------------------------------------------------------------------
head2 "R4 — view commands ⇒ metadata screenshots"
# ------------------------------------------------------------------------------------------
VIEW_CMDS="$(jq '[.commands[]? | select(.mode == "view")] | length' package.json)"
SHOTS=0
for f in metadata/*.png; do [ -e "$f" ] && SHOTS=$((SHOTS+1)); done

if [ "$VIEW_CMDS" -gt 0 ] && [ "$SHOTS" -eq 0 ]; then
  fail "$VIEW_CMDS view command(s) but no metadata/*.png." \
       "Rule Used: extensions with view-type commands must include Store metadata screenshots."
  for d in media assets screenshots images; do
    [ -d "$d" ] && printf '        note: %s/ exists — screenshots there do NOT satisfy the rule (#29737).\n' "$d"
  done
elif [ "$VIEW_CMDS" -eq 0 ]; then
  ok "no view commands — metadata/ not required"
else
  ok "$VIEW_CMDS view command(s), $SHOTS screenshot(s)"
fi

if [ "$SHOTS" -gt 6 ]; then
  fail "$SHOTS screenshots in metadata/ — the Store caps at 6." "ray lint does not flag this; a reviewer will."
fi

# metadata_image_enforcer.yml runs scripts/check_metadata_images.py on every changed image.
for f in metadata/*.png; do
  [ -e "$f" ] || continue
  D="$(png_dims "$f")"
  if [ -z "$D" ]; then
    warn "could not read PNG header: $f"
  elif [ "$D" != "2000x1250" ]; then
    fail "$f is ${D}, must be 2000x1250." "Recapture with Raycast's Capture Window command."
  fi
done

if [ -f assets/icon.png ]; then
  D="$(png_dims assets/icon.png)"
  if [ -n "$D" ] && [ "$D" != "512x512" ]; then
    fail "assets/icon.png is ${D}, must be 512x512."
  elif [ -n "$D" ]; then
    ok "icon.png is 512x512"
  fi
fi

# PR-template checklist item: README assets live outside metadata/.
if [ -f README.md ] && grep -q '](.*metadata/' README.md; then
  fail "README.md embeds an image from metadata/." \
       "metadata/ is the Store-listing folder; move README assets outside it."
fi

# ------------------------------------------------------------------------------------------
head2 "R5 — manifest \$schema and categories"
# ------------------------------------------------------------------------------------------
# Rule: "Require Raycast extension projects to include $schema reference"
if ! jq -e 'has("$schema")' package.json >/dev/null 2>&1; then
  fail "package.json has no \$schema reference." \
       "Add \"\$schema\": \"https://www.raycast.com/schemas/extension.json\" as the first key."
else
  ok "\$schema present"
fi

# Rule: "Assign at least one predefined category to extensions"
if ! jq -e '(.categories|type=="array") and (.categories|length>0)' package.json >/dev/null 2>&1; then
  fail "package.json declares no categories." "At least one predefined category is required."
else
  ok "categories: $(jq -r '.categories|join(", ")' package.json)"
fi

# ------------------------------------------------------------------------------------------
head2 "R6 — eslint flat config"
# ------------------------------------------------------------------------------------------
# Rule: "In ESLint v9+, defineConfig is exported from eslint/config" — and the repo convention
# is the @raycast/eslint-config preset, not @raycast/eslint-plugin directly (#28288).
ESLINT_CFG=""
for c in eslint.config.js eslint.config.mjs eslint.config.cjs; do [ -f "$c" ] && ESLINT_CFG="$c" && break; done
if [ -n "$ESLINT_CFG" ]; then
  if grep -q '@raycast/eslint-plugin' "$ESLINT_CFG" && ! grep -q '@raycast/eslint-config' "$ESLINT_CFG"; then
    fail "$ESLINT_CFG uses @raycast/eslint-plugin directly." \
         "The canonical preset is @raycast/eslint-config."
  elif grep -q 'module\.exports' "$ESLINT_CFG"; then
    fail "$ESLINT_CFG uses the CommonJS module.exports pattern." \
         "ESLint v9 flat config: import { defineConfig } from \"eslint/config\"."
  elif ! grep -q 'defineConfig' "$ESLINT_CFG"; then
    warn "$ESLINT_CFG does not use defineConfig from eslint/config."
  else
    ok "$ESLINT_CFG uses defineConfig"
  fi
fi

# ------------------------------------------------------------------------------------------
head2 "Lockfiles, registry, manifest"
# ------------------------------------------------------------------------------------------
for lf in yarn.lock bun.lock bun.lockb pnpm-lock.yaml; do
  [ -f "$lf" ] && fail "$lf present — only package-lock.json is allowed."
done
[ -f package-lock.json ] || warn "No package-lock.json." "CI builds with npm and expects it in the PR."

# `"latest"` silently adopts breaking majors on a fresh CI install (#29447, #29564). A major
# range ahead of what CI can resolve blocks the build before `ray build` even runs (#29614).
LATEST="$(jq -r '[(.dependencies//{}), (.devDependencies//{})] | add | to_entries[]
                 | select(.value == "latest" or .value == "*") | "\(.key)@\(.value)"' package.json 2>/dev/null)"
if [ -n "$LATEST" ]; then
  fail "unpinned dependency version(s): $(printf '%s' "$LATEST" | tr '\n' ' ')" \
       "Use a caret range (^1.2.3). \"latest\" adopts breaking majors on a fresh install."
fi

# A lockfile whose root entry disagrees with package.json fails `npm ci` in CI (#28362, #28846).
if [ -f package-lock.json ]; then
  PJ_DEPS="$(jq -S -r '.dependencies // {} | keys | join(",")' package.json)"
  PL_DEPS="$(jq -S -r '.packages[""].dependencies // {} | keys | join(",")' package-lock.json 2>/dev/null)"
  if [ -n "$PL_DEPS" ] && [ "$PJ_DEPS" != "$PL_DEPS" ]; then
    fail "package-lock.json root entry disagrees with package.json dependencies." \
         "npm ci will fail. Run npm install and commit the regenerated lockfile."
  else
    ok "lockfile root entry matches package.json"
  fi
fi

if [ -f .npmrc ] && grep -qE '^[^#]*registry[[:space:]]*=' .npmrc; then
  fail ".npmrc sets a registry." "Only https://registry.npmjs.org is permitted (global or scoped)."
fi

# A tools array with no ai.evals block is incomplete.
if jq -e '(.tools|type=="array") and (.tools|length>0)' package.json >/dev/null 2>&1; then
  if ! jq -e '(.ai.evals|type=="array") and (.ai.evals|length>0)' package.json >/dev/null 2>&1; then
    fail "package.json declares tools but no ai.evals." \
         "See developers.raycast.com/ai/write-evals-for-your-ai-extension"
  else
    ok "tools carry ai.evals"
  fi
fi

# The command `name` is the unique ID that ranking, aliases, and hotkeys are saved against.
if [ -d .git ] && git rev-parse --verify HEAD >/dev/null 2>&1; then
  OLD_NAMES="$(git show HEAD:package.json 2>/dev/null | jq -r '.commands[]?.name' 2>/dev/null | sort)"
  NEW_NAMES="$(jq -r '.commands[]?.name' package.json | sort)"
  if [ -n "$OLD_NAMES" ] && [ "$OLD_NAMES" != "$NEW_NAMES" ]; then
    GONE="$(comm -23 <(printf '%s\n' "$OLD_NAMES") <(printf '%s\n' "$NEW_NAMES"))"
    [ -n "$GONE" ] && warn "command name(s) removed/renamed since HEAD: $(printf '%s' "$GONE" | tr '\n' ' ')" \
      "name is the command's unique ID — users' ranking, aliases and hotkeys are keyed to it. Change title instead."
  fi
fi

CMD_COUNT="$(jq '.commands | length' package.json)"
if [ "$CMD_COUNT" -gt 1 ]; then
  NOSUB="$(jq -r '[.commands[] | select(has("subtitle") | not) | .name] | join(", ")' package.json)"
  [ -n "$NOSUB" ] && warn "multi-command extension; commands without subtitle: $NOSUB" \
    "Upstream asks for \"subtitle\": \"$EXT_TITLE\" on each."
fi

# Titles must agree across package.json / README / CHANGELOG.
if [ -n "$EXT_TITLE" ] && [ -f README.md ]; then
  README_H1="$(grep -m1 '^# ' README.md | sed 's/^# *//')"
  if [ -n "$README_H1" ] && [ "$README_H1" != "$EXT_TITLE" ]; then
    warn "README H1 \"$README_H1\" != package.json title \"$EXT_TITLE\"."
  fi
fi

# Declared-but-never-imported dependencies (#29735, #29670). Heuristic: @types/* are
# type-only by definition, and a dep may legitimately be used from a build script.
DEPS="$(jq -r '.dependencies // {} | keys[]' package.json 2>/dev/null | grep -v '^@types/')"
UNUSED=""
for d in $DEPS; do
  grep -rqE "(from[[:space:]]+['\"]${d}(/|['\"])|require\(['\"]${d}(/|['\"]))" \
       src scripts 2>/dev/null || UNUSED="$UNUSED $d"
done
[ -n "$UNUSED" ] && warn "dependencies never imported:$UNUSED" "Greptile flags unused deps; drop them or explain."

# ------------------------------------------------------------------------------------------
head2 "Tier 2 code conventions (heuristic — read, don't automate)"
# ------------------------------------------------------------------------------------------
if [ -d src ]; then
  # launchCommand must be wrapped in try/catch. Approximated by requiring a `try` within the
  # 6 lines above the call — good enough to surface the bare ones.
  LC="$(grep -rn 'launchCommand(' src 2>/dev/null | cut -d: -f1,2)"
  for loc in $LC; do
    f="${loc%%:*}"; n="${loc##*:}"
    s=$(( n > 6 ? n - 6 : 1 ))
    sed -n "${s},${n}p" "$f" 2>/dev/null | grep -q '\btry\b' || \
      warn "launchCommand at $f:$n has no try/catch within 6 lines."
  done

  GST="$(grep -rn 'getSelectedText(' src 2>/dev/null | cut -d: -f1,2)"
  for loc in $GST; do
    f="${loc%%:*}"; n="${loc##*:}"
    s=$(( n > 6 ? n - 6 : 1 ))
    sed -n "${s},${n}p" "$f" 2>/dev/null | grep -q '\btry\b' || \
      warn "getSelectedText at $f:$n has no try/catch within 6 lines."
  done

  # Prefer showFailureToast from @raycast/utils over a hand-rolled Failure toast. Sites already
  # routed through the kit (showError/failToast) attach the action inside the package and must
  # not be counted — the literal grep gives a FALSE FAILURE on kit-using code (house-style).
  RAW_FAIL="$(grep -rn 'Toast\.Style\.Failure' src 2>/dev/null | grep -vE 'failToast|showError')"
  if [ -n "$RAW_FAIL" ]; then
    warn "raw Toast.Style.Failure site(s) — consider showFailureToast from @raycast/utils:"
    printf '%s\n' "$RAW_FAIL" | sed 's/^/          /'
  fi

  # Lists/Grids need isLoading or they flash an empty state before data lands.
  for f in $(grep -rlE '<(List|Grid)\b' src 2>/dev/null); do
    grep -q 'isLoading' "$f" || warn "$f renders a List/Grid with no isLoading prop."
  done

  # Sync exec freezes the event loop for the whole child process (#28456).
  SYNC="$(grep -rn 'execSync(\|execFileSync(\|spawnSync(' src 2>/dev/null)"
  [ -n "$SYNC" ] && { warn "synchronous child_process call(s) — these block the UI:"; printf '%s\n' "$SYNC" | sed 's/^/          /'; }

  # Permanent deletion with no recovery path where trash() belongs (#28390).
  DEL="$(grep -rn 'rmSync(\|unlinkSync(\|rmdirSync(\|fs\.rm(\|fs\.unlink(' src 2>/dev/null)"
  [ -n "$DEL" ] && { warn "permanent-delete call(s) — use trash() from @raycast/api for USER files:"; printf '%s\n' "$DEL" | sed 's/^/          /'; }

  # GNU-only flags in a shell-out fail silently into an empty result on macOS BSD tools (#28448).
  GNU="$(grep -rn -- '--include=\|grep -P\|sed -r\|readlink -f' src 2>/dev/null)"
  [ -n "$GNU" ] && { warn "GNU-only flag(s) in a shell-out — macOS ships BSD tools:"; printf '%s\n' "$GNU" | sed 's/^/          /'; }

  AS="$(grep -rn ' as any\|<any>\|: any\b' src 2>/dev/null)"
  [ -n "$AS" ] && warn "$(printf '%s' "$AS" | grep -c .) 'any' usage(s) — house-style [lint] prohibition."
fi

# ------------------------------------------------------------------------------------------
printf '\n────────────────────────────────────────\n'
printf '%d FAIL   %d WARN\n' "$FAILS" "$WARNS"
if [ "$FAILS" -gt 0 ]; then
  printf 'Fix every FAIL before opening the PR — each one is a rule greptile-apps[bot]\n'
  printf 'or a CI enforcer fires on deterministically.\n'
fi
printf '\nStill unchecked by machine — see ../greptile-review-rules.md:\n'
printf '  · Does an extension — OR a Raycast built-in — already do this job? (top cause of rejection)\n'
printf '  · Can you watch the PR thread for 5 weeks? (stale bot closes at 25+7 days)\n'
printf '  · Are the screenshots real Capture Window output, current, correctly padded,\n'
printf '    and free of real data? (maintainers ask for mock data on anything sensitive)\n'
printf '  · Does package.json `author` match the account opening the PR?\n'
printf '  · Do mutations refresh derived state, and do in-flight requests survive unmount?\n'
printf '  · Does every changed preference/enum migrate values users already stored?\n'
printf '  · Are all URLs/repos referenced from code public? (a private org link ships a 404)\n'

[ "$FAILS" -gt 0 ] && exit 1
exit 0
