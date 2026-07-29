---
module: publishing
date: 2026-07-29
problem_type: workflow_issue
component: development_workflow
severity: critical
applies_when:
  - "Working in a standalone mirror repo whose published copy lives in an upstream monorepo (`raycast/extensions`)"
  - "Other contributors can merge directly upstream without ever touching the mirror"
  - "A push-model sync job (`repository_dispatch`, webhook) is the only thing keeping the mirror current"
  - "Starting any session on an extension already published to the Store"
  - "Reconciling local work against an upstream version that advanced independently"
tags:
  - raycast
  - mirror-repo
  - upstream-sync
  - fail-closed
  - reconciliation
  - store-submission
  - github-actions
related_components:
  - tooling
  - documentation
---

# A mirror repo goes stale silently — verify against the published copy before writing code

## Context

Most of these extensions are developed in a standalone mirror
(`chrismessina/raycast-<name>`) and published into `raycast/extensions` at
`extensions/<slug>/`. That gives the published copy **two writers**: you, via
`ray publish`, and anyone whose PR the Raycast team merges directly into the
monorepo. The mirror is downstream of the monorepo, not the reverse.

A sync workflow is supposed to close the loop. It fires on a
`repository_dispatch` of type `upstream-sync`, or a manual `workflow_dispatch`,
and pulls the extension's files down through the GitHub contents API. It is a
**push-model** sync: something upstream has to tell it to run.

When that dispatch never arrives, the workflow does not run, does not fail, and
**emits no signal at all**. A mirror that is months stale is indistinguishable,
from inside the repo, from one that synced five minutes ago: `git status` is
clean, `git log` shows your own commits, the tree builds and lints and runs.

That is the whole trap. **Staleness in a mirror is silent by construction.**

The chain has two independent links, and neither self-heals:

```
raycast/extensions (upstream, where contributors' PRs merge)
      ↓  requires the fork to be synced — no scheduled job
chrismessina/extensions (fork, where the dispatcher lives)
      ↓  requires a push touching extensions/*/package.json
the mirror
```

The mirror's own workflow has **no `schedule:` trigger** — only
`repository_dispatch` and `workflow_dispatch` — so it cannot poll for work it was
never told about. And the link above it was already known to be broken:
`README.md` in this repo recorded on **2026-07-15** that "the fork has **no
scheduled fork-sync workflow deployed** … remote mirrors only refresh when you
manually sync the fork."

That note is about the fork→mirror trigger, not the mirror's own workflow — but
the two compound. A dispatch that is never fired and a mirror that cannot poll
produce the same observable state: silence.

The gap was dated 2026-07-15 and committed on 2026-07-22, so the warning had been
readable in the repo for six days when the incident hit on 2026-07-28. The point
is not that six days is a long time — it is that a documented, un-closed gap in an
automation chain produces no signal at all until something downstream depends on
it. Writing the gap down did not make it visible at the moment it mattered; only a
check at the start of the session would have.

## Guidance

**Verify the local tree against the published copy before writing any code —
not at ship time.**

Three properties are load-bearing. Drop any one and the check becomes decorative.

### 1. Compare content, not filenames

An upstream *edit* to a file you also have is invisible to a name-only check —
and an upstream edit to a file you also have is exactly what a re-publish
silently reverts. Two trees can hold an identical file list and be a release
apart.

### 2. Fail closed — `set -e` is not enough

A pipeline's exit status is its *last* command's, not the failing one's, so
`set -e` does not fire when a `git fetch` failure is swallowed mid-pipeline. The
consequence is the worst available outcome: an empty baseline directory, a
comparison that finds no differences, and a report of **"in sync" off a failed
fetch**. That launders "I could not look" into "I looked and it's fine."

An explicit assertion that the baseline exists *and is non-empty* is what makes
the check trustworthy.

### 3. Sparse, blobless checkout — never a full clone

`raycast/extensions` holds thousands of extensions. `--filter=blob:none
--depth 1` plus a cone sparse-checkout of the one extension directory keeps this
to seconds. A check that takes minutes is a check you skip, and a check you skip
is not a check.

```bash
#!/usr/bin/env bash
# check-upstream-drift.sh <upstream-ext-dir> [local-repo]
# 0 = in sync · 1 = drift · 2 = no baseline established (FAIL CLOSED)
set -euo pipefail

EXT_DIR="${1:?usage: check-upstream-drift.sh <upstream-ext-dir> [local-repo]}"
LOCAL="${2:-$PWD}"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

git clone --filter=blob:none --no-checkout --depth 1 \
  https://github.com/raycast/extensions.git "$WORK/up" >/dev/null 2>&1
git -C "$WORK/up" sparse-checkout init --cone >/dev/null
git -C "$WORK/up" sparse-checkout set "extensions/$EXT_DIR" >/dev/null
git -C "$WORK/up" checkout >/dev/null 2>&1
BASE="$WORK/up/extensions/$EXT_DIR"

# FAIL CLOSED. Without this a failed fetch leaves BASE empty, the loop below runs
# zero times, and the script reports "IN SYNC" — worse than having no check.
[ -d "$BASE" ] && [ -n "$(ls -A "$BASE" 2>/dev/null)" ] || {
  echo "FATAL: upstream baseline empty/missing for '$EXT_DIR'." >&2; exit 2; }

# Enumerate from the UPSTREAM side. A bare `diff -rq` also flags every
# mirror-only path (.github/, CLAUDE.md, docs/, raycast-env.d.ts) as drift —
# noise that trains you to ignore the one line that matters.
DRIFT=0
while IFS= read -r rel; do
  if [ ! -e "$LOCAL/$rel" ]; then
    echo "MISSING LOCALLY: $rel"; DRIFT=1
  elif ! cmp -s "$BASE/$rel" "$LOCAL/$rel"; then
    echo "CONTENT DIFFERS: $rel"; DRIFT=1
  fi
done < <(cd "$BASE" && find . -type f -not -path './node_modules/*' | sed 's|^\./||' | sort)

[ "$DRIFT" -eq 0 ] && echo "IN SYNC with upstream extensions/$EXT_DIR" && exit 0
echo; echo "STALE. Reconcile BEFORE editing — re-publishing now reverts upstream work." >&2
exit 1
```

**Screenshots always differ** — Raycast CI recompresses `metadata/*.png` on
merge, so every screenshot shows as drift and none of it is meaningful. Read
past those lines to the source files.

**Known blind spot: files upstream *deleted*.** Enumerating from the upstream side
is what keeps the output readable — mirror-only paths (`.github/`, `CLAUDE.md`,
`docs/`, `media/`) are expected by design, so flagging them would bury the signal.
The cost is that a file upstream removed, which the mirror still carries, is not
reported. It matters because `ray publish` adds and updates but never deletes, so
a stale re-publish resurrects it into the PR. If a reconciliation involved upstream
deletions, check that direction by hand — or accept that the ship pre-flight's
`diff -r -q`, which is noisier but symmetric, is the backstop for it.

## Why This Matters

The cost of skipping this is not a merge conflict. It is:

- **An entire session built on a stale tree.** The staleness surfaced only at the
  ship pre-flight's CHANGELOG diff, after all the code was written.
- **Five of roughly eight fixes duplicated** work a contributor had already
  merged. That labor was simply spent twice.
- **A publish that would have left the extension incoherent.** The missing
  upstream release added a second command (`store-updates-menu-bar.tsx`), a
  `githubToken` preference, and a new module (`store-cache.ts`).

  The damage is subtler than deletion, and worse for being subtler. **`ray publish`
  adds and updates but never deletes**, so the two upstream-only `.tsx` files would
  have *survived* in the PR. `package.json` exists on both sides, so it would have
  been **overwritten with the stale copy** — the one that declares a single command
  and no `githubToken`.

  The result: `store-updates-menu-bar.tsx` sitting in `src/` while the manifest no
  longer registers it. `ray build` derives its entry points from `package.json`, so
  the command silently disappears from the Store while its source lingers as dead
  weight, and every user's stored token is orphaned by a preference that no longer
  exists. A reviewer scanning the file list sees nothing missing.

The pre-flight caught it. But a pre-flight runs after the code is written, which
makes it a seatbelt, not a lane marking.

**This is not one repo's problem.** Thirteen mirror repos carry the same
`sync-from-upstream.yml`, and **four already have external contributors** —
`karakeep` (3), `raycast-store-updates` (2), `at-profile` (1), `reader` (1). The
other three are live instances of the same latent failure.

`reader` is the sharpest: its slug is `reader-mode` but its repo is
`raycast-reader`. A check that assumes repo name equals slug reads the wrong
upstream directory and reports a confident, false "in sync."

## When to Apply

- Before starting **any** session on a mirrored, published extension — step zero,
  before reading code or planning
- Any repo mirroring a subdirectory of an upstream monorepo you do not solely
  control
- Any project where a push-model sync is the only thing keeping a copy current;
  its failure mode is silence
- Whenever you reconcile a contributor's merged work into local changes
- Whenever you resolve directory drift by copying — check for untracked files at
  the destination first

## Examples

### Reconciling: the contributor may be right

Upstream's rate-limit handling was strictly better than the local version. It
threw rather than returning `[]`, preserving `keepPreviousData` so a rate-limited
refresh leaves the user's list on screen instead of blanking it, and it read
`X-RateLimit-Remaining` to decide what a 403 actually meant.

The correct move was to **drop the local implementation wholesale**.
Reconciliation is not "defend my diff."

### But adopting a superset is not adopting every line in it

Taking upstream wholesale silently re-introduced two defects the local branch had
already fixed:

1. **Bare-403-as-rate-limit.** A 403 with no rate-limit headers is a proxy or VPN
   rejection. Treating it as a rate limit starts an hour-long cooldown GitHub
   never asked for, locking the user out of quota they still have.
2. **A `⌘⇧C` ActionPanel collision.** `Keyboard.Shortcut.Common.Copy` *is* `⌘⇧C`,
   so a hand-written `{ modifiers: ["cmd","shift"], key: "c" }` in the same panel
   looks distinct and resolves identically. `ray lint` does not check this
   invariant, so it needs a human assertion.

**Re-run your house-style and defect assertions AFTER reconciling, not before.**
A merge that adopts someone else's superset is a fresh tree that has never been
audited, even though every individual change in it was reviewed once.

### The lesson recurring after it was written

The sharpest evidence that reconciliation needs a *post*-merge audit is that the
same failure happened again, later in the same session, after the rule above had
already been drafted.

A `isExtensionGone()` helper had been written to confirm extension removals via a
definitive `404`. The reconciliation reverted that call site to the published
version's check and dropped the helper entirely:

```ts
// after reconciling — the published version's logic, silently restored
const pkgInfo = await fetchExtensionPackageInfo(slug);
if (pkgInfo !== null) continue; // "still exists"
```

`fetchExtensionPackageInfo()` returns `null` on *any* failure — its `!response.ok`
branch covers 500, 502, 429 — and caches that miss for fifteen minutes. So a
single transient blip displayed a **live extension as "Removed"** and kept doing
so until the cache expired.

| status | old → removed? | fixed → removed? |
| --- | --- | --- |
| 404 (genuinely deleted) | yes | yes |
| 500 / 502 / 429 (transient) | **yes** | no |
| 200 (exists) | no | no |

Neither `tsc`, `ray build`, `ray lint`, nor a full manual pre-flight caught it —
the code is locally correct and only wrong in what it *means*. It took an
external reviewer (Greptile, on the open Store PR) to surface it.

That is the argument for the rule, made by the rule's own author violating it
within the hour: **the post-reconciliation audit is not optional, and you are not
exempt from it because you wrote the fix the first time.**

## Related

- **`develop` skill, step 0 — STALENESS GATE.** "Diff the local tree against the
  PUBLISHED extension. Do this FIRST, before reading code, planning, or editing."
  Step 0 is where the check *saves* the work.
- **`ship` skill, step −1 — STALENESS GATE.** The pre-flight backstop, carrying
  the same fail-closed assertion. It only *prevents the disaster*; in this
  incident only the backstop existed, which is why the near-miss was caught and
  the wasted session was not.
- [`raycast-store-pr-base-diverged-fork-main.md`](./raycast-store-pr-base-diverged-fork-main.md)
  — the sibling failure at the other end of the same publish pipeline: there the
  fork's `main` had diverged; here the mirror had.
- `README.md` in this repo documents the missing scheduled fork-sync as a known
  open gap (2026-07-15). Until that is closed, this gate is the detection layer
  for a hole that is still open.
- Store submission: raycast/extensions#29819 (submitted 2026-07-28).
