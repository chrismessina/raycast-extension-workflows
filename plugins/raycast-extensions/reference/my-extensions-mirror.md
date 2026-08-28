# Mirror & submission topology (`author: chrismessina`)

How a `chrismessina`-authored extension gets from a local working repo to the
Raycast Store. Grounded in the Bookface v1.1 ship (2026-06-23) — the first time
this was done end-to-end and documented.

## The three repos

1. **Local working repo** — e.g. `~/Developer/GitHub/chrismessina/raycast-bookface`.
   Where you develop. Commits are SSH-signed via 1Password (see global CLAUDE.md).
2. **Standalone GitHub repo** — `github.com/chrismessina/raycast-<name>`. The public
   home of the extension's source. **This is the piece that is often MISSING** (see
   below) and whose absence breaks any sync automation.
3. **Monorepo fork** — `github.com/chrismessina/extensions` (a fork of
   `raycast/extensions`). PRs to the Store are opened from a branch here.

The published extension lives at `raycast/extensions/extensions/<name>/`.

## Sync direction — don't confuse the two

There are **two opposite flows**, and this doc's "submission flow" below is only one:

- **Outbound (submission):** your local work → `chrismessina/extensions` fork →
  PR → `raycast/extensions`. Manual; documented below.
- **Inbound (mirror sync):** `raycast/extensions/extensions/<dir>` → your standalone
  `chrismessina/raycast-<name>` repo, so the mirror reflects edits made upstream
  (including during PR review). **Automated** via the sync workflows — see the repo
  root `README.md` → "Sync workflows". As of 2026-07-15 the inbound dispatcher was
  rewritten and 5 more mirrors wired up; the one remaining gap is a scheduled
  fork-sync on `chrismessina/extensions` (see that README).

### 🚨 The inbound sync MUST NOT overwrite blindly

**A mirror is downstream of the monorepo, but it is also where local work starts.**
Those two facts collide, and the naive implementation resolves the collision by
destroying local work:

```bash
curl ... -o "$path"     # overwrite, no comparison
git add -- "$path"      # commit it
```

**Verified damage, 2026-08-01 on `raycast-claude-artifacts`:** that loop reverted a
local README fix (a dead `docs/shelf.md` link, fixed locally, not yet shipped
upstream) by restoring the monorepo's older copy — and reported success. Re-running
the same comparison the next day showed it would have destroyed **three** files: the
README plus an entire unshipped feature (two `src/` modules).

**The cron schedule is not the bug — overwriting without comparing is.** A
merge-triggered sync running that same loop loses the same edit, just less often,
which is *worse*: rare corruption is the kind you stop watching for. Do not "fix"
this by changing the trigger.

**The contract every mirror's sync workflow must satisfy:**

1. **Never push to `main`.** Open a PR. Merging it is the only write to `main`, so
   there is no unattended path that can revert local work.
2. **Three-way compare per file**, against a committed state file
   (`.github/upstream-sync-state.json`) recording upstream blob SHAs at the last
   sync. Blob SHAs are content-addressed, so "changed" is exact:

   | upstream changed? | mirror changed? | action |
   | --- | --- | --- |
   | no | no | nothing |
   | **yes** | no | take upstream (CHANGELOG stamp, recompressed PNGs, contributor fixes) |
   | no | **yes** | **keep local** |
   | **yes** | **yes** | **halt** — open an issue, sync *nothing* |

3. **A conflicting run syncs nothing at all** — never a partial apply, which is the
   confusing state to debug.
4. **No baseline (first run) + differing local file → keep local.** Fail safe toward
   local work.
5. **Keep the cron** *and* add `repository_dispatch`. The dispatch gives an immediate
   sync after your own PR merges; the cron catches the case a trigger structurally
   cannot — **someone else's PR to your extension merging upstream**, where you are
   not the author and may never see it. That is the case that actually causes silent
   drift.

Reference implementation:
`/Users/messina/Developer/GitHub/chrismessina/raycast-claude-artifacts/.github/workflows/sync-from-upstream.yml`,
with the rationale in
`/Users/messina/Developer/GitHub/chrismessina/raycast-claude-artifacts/.github/mirror-sync.md`
(kept under `.github/` deliberately — `ray publish` excludes that directory, so the
doc lives in the mirror without shipping to the Store).

**Fleet status (2026-08-03):** `raycast-claude-artifacts` has the safe version on
`main`. The other five — `raycast-digger`, `raycast-get-app-icon`,
`raycast-store-updates`, `raycast-karakeep`, `raycast-reader` — have it **in an open
PR** (`ci/safe-upstream-sync`); they still run the blind-overwrite version until
those merge.

**Porting checklist** (what actually varies per repo — everything else is verbatim):

1. Copy the workflow, then restore that repo's **own cron minute** (staggered across
   the fleet: 17/23/31/41/45/59) and its **`UPSTREAM_EXT_DIR`** override if set
   (`raycast-reader` → `reader-mode`; the rest are empty).
2. **Seed `.github/upstream-sync-state.json`** from the current upstream tree, or the
   first run has no baseline. Assert a plausible file count (≥5) before writing it —
   a truncated or failed fetch would otherwise seed an empty baseline, and every
   local file then reads as "keep", masking real upstream changes indefinitely.
3. **Dry-run the compare before pushing.** On 2026-08-03 this surfaced that
   `raycast-digger` carries **27 local-only files** — a `@ianvs/prettier-plugin-sort-imports`
   pass (commit `5767aca`) that never shipped upstream. Verified formatting-only
   (identical once `import` lines are excluded). The old workflow would have reverted
   all 27 on digger's next cron; the new one keeps them.
4. Validate the YAML with `npx js-yaml <file>` — an unquoted `: ` inside a `run:`
   string parses locally as a mapping and fails on GitHub. Caught exactly this in the
   reference implementation before it shipped.

## Submission flow (outbound — what actually works, verified)

The reliable, manual flow for getting local work into the Store:

1. **Confirm the standalone repo exists.** `gh repo view chrismessina/raycast-<name>`.
   If it 404s, CREATE IT (see "Missing-mirror entry point").
2. **Verify local `main` == published v1.x** before trusting it as the baseline.
   Sparse-fetch the published dir and diff (see sparse-checkout-discipline.md). For
   Bookface they were byte-identical — local main genuinely was the published source.
3. **Land the local work in the standalone repo** — branch → PR → squash-merge to
   `main`, not a direct push. The inbound sync compares against `main`, so work that
   is merged there is *seen* and preserved; work sitting on an unmerged branch is
   invisible to it. (Direct pushes still work, but the PR path is what keeps the
   mirror's own history reviewable when contributors are involved.)
4. **Sync the extension dir into the fork**: in a sparse checkout of the monorepo,
   copy ONLY the published file set (see "What ships" below) into
   `extensions/<name>/`, commit on a branch (`update/<name>-<topic>`), push to the
   `chrismessina/extensions` fork.
5. **Open the PR** `chrismessina:update/<name>-<topic>` → `raycast/extensions:main`.
6. **Cleanup** per pr-and-cleanup.md (track by PR head — squash-merge re-SHAs).

> **Direction note (updated 2026-07-15):** the "dispatcher / sync lag" the stub
> skill mentions is the **inbound** mirror-sync (upstream → standalone), NOT this
> outbound submission flow. Inbound automation IS live now (dispatcher rewritten,
> Bookface + 4 others wired up 2026-07-15) — see the repo root README. The
> **outbound** submission flow above has no automation and remains manual and
> canonical: do not assume a pipeline pushes your local work to the Store for you.

## Missing-mirror entry point (the case that threw the first ship)

If `gh repo view chrismessina/raycast-<name>` 404s, the standalone repo was never
created. Before anything else:

```bash
# from inside the local working repo, on the branch you intend to publish
gh repo create chrismessina/raycast-<name> --public --source=. --remote=origin \
  --description="<one-liner>" --push
```

This both creates the repo and wires `origin`, fixing the "no remote" state that
silently disables any future sync. THEN proceed with verify-baseline → fork-sync → PR.

## What ships (the published file set)

Copy ONLY these into `extensions/<name>/` — match the published v1.0's set exactly:

```
assets/  metadata/  src/
.gitignore  CHANGELOG.md  eslint.config.js  package-lock.json  package.json
README.md  tsconfig.json
```

**Do NOT ship** local-only artifacts even if tracked in the working repo:
`.github/docs/**` (review/findings docs, fixtures), `.github/assets/**` (icon
sources), `CLAUDE.md`. Use the published dir's file list as the allow-list, not a
blanket copy of the working repo.

### Grep for inbound links before you drop a file

Excluding a file silently breaks every link pointing *at* it. Nothing in `ray lint`,
`ray build`, or CI checks relative Markdown links, so a dead pointer merges clean and
404s for every reader. This applies to **both routes** — `ray publish` drops files
just as a hand-copied allow-list does.

For each excluded path, grep the *shipping* docs for references to it:

```bash
# $EXCLUDED = the paths you are NOT shipping (shelf.md, HANDOFF.md, CLAUDE.md, …)
for f in $EXCLUDED; do
  grep -rn "$(basename "$f")" README.md docs/ CHANGELOG.md 2>/dev/null \
    && echo "^^ inbound link to excluded $f — fix before shipping"
done
```

Rewrite the prose to stand alone rather than deleting the sentence — the idea is
usually still worth stating, just without the pointer.

Then verify the links that *do* ship actually resolve, from each link's own
directory (a `../` link in `docs/` resolves differently than the same string in
`README.md`):

```bash
grep -rn -oE '\]\((\.{1,2}/[A-Za-z0-9_./-]+\.(md|sh|ts|tsx|json|svg|png))\)' \
  README.md docs/**/*.md CHANGELOG.md 2>/dev/null \
| sed -E 's/:[0-9]+:\]\(/\t/; s/\)$//' | sort -u \
| while IFS=$'\t' read -r src rel; do
    [ -e "$(dirname "$src")/$rel" ] || echo "BROKEN  $rel  <- $src"
  done
```

Silence means every link resolves. Run this **before** the PR, not after: a merged
README is a patch PR to fix. *(Cost us a dead `docs/shelf.md` pointer in
`claude-artifacts` v1.0 — caught only after merge, 2026-07-27.)*

## Assets gotcha (real, cost us a near-miss)

The monorepo's committed icons/screenshots are **Raycast-optimized (smaller)** than
the originals in the working repo. A naive copy re-introduces the larger originals,
bloating the PR with spurious binary diffs. Unless you are *intentionally* updating
imagery, **revert assets/ and metadata/ to the published versions** after syncing:

```bash
git checkout HEAD -- extensions/<name>/assets/ extensions/<name>/metadata/
```

Then the PR contains only real code/metadata changes.

### The optimization is LOSSY — which is why images must be pulled back DOWN after a merge

"Raycast-optimized" is not a re-encode of the same pixels. CI **palette-reduces** the image:
measured 2026-08-27 on `claude-artifacts`, a submitted 1,646,438-byte screenshot came back
at **1,050,178 bytes with different pixel data** — 36% smaller, visually indistinguishable,
same screen and same labels.

Three consequences, and they are the whole reason post-merge image sync exists:

1. **The bytes that ship are never the bytes you submitted.** A mirror that does not pull
   them back is permanently, invisibly divergent from the published extension — and the
   difference cannot be seen by looking, only by hashing.
2. **A hash cannot tell you whether that divergence is benign.** "CI optimized my
   screenshot" and "someone replaced the screenshot" both produce *different pixels*. The
   only discriminator is opening both images. Any triage script that decides this
   automatically is wrong in one direction or the other.
3. **A safe inbound sync will HALT on it after any release where you changed a screenshot** —
   you moved the file and CI moved it, so both sides differ from the recorded baseline. That
   is a genuine conflict and refusing to auto-resolve it is correct. Adopt the published
   copy by hand (after confirming by eye it is the same screen), or the file conflicts on
   every run forever.

Full triage procedure and verdict table: `ship`'s PNG triage under the staleness gate.
