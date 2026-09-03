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

**Fleet status (2026-09-02, verified against the DEFAULT BRANCH of every repo via the
API, not against local checkouts).** **No mirror runs the blind workflow any more.**
21 `raycast-*` repos carried a `sync-from-upstream.yml`: 17 now run the safe three-way
version, and 4 had it removed because they were never mirrors at all.

**The 17 safe mirrors** — `at-profile`, `bookface`, `claude-artifacts`, `digger`,
`domainr`, `ejection-seat`, `fathom`, `fly`, `get-app-icon`, `google-books`, `karakeep`,
`reader`, `secret-browser-commands`, `store-updates`, `tesla-energy`, `trimmy`,
`wrap-unwrap`. Every one records the baseline **unconditionally**, **propagates upstream
deletions** (the DELETED rows in the workflow's decision table), opens its PR
**idempotently**, and has Actions PR-creation enabled. Each carries its own cron minute
and nothing else that differs.

**The 4 archived** — `brew-2.0`, `screenocr`, `wayback-machine`, `word-count`. These are
extensions **other people author** (`nhojb`, `huzef44`, `pernielsentikaer`, `itsmingjie`)
where Chris is a listed contributor; the repos only ever held the working history behind a
contribution. There is nothing to mirror, so the workflow was deleted and the repos
archived — read-only, history intact, Actions dead. **Do not port a sync workflow to a
repo whose extension you do not author**; a mirror presupposes ownership of the upstream
copy.

`raycast-store-updates` and `raycast-fly` are the cautionary pair. store-updates had been
ported earlier but **incompletely** — missing both halves of the unconditional-baseline fix
*and* the `Commit the refreshed baseline` step. Treat "has the safe workflow" and "has a
*complete* safe workflow" as different claims: compare the step list, not the presence of
one step name.

### What the blind workflow actually cost — read this before relaxing any of the above

The blind version was not naive. It aborted on a truncated tree, asserted its download
count, staged only what it fetched, and refused to prune on a thin manifest. All of that
protects against a *failed download*. **None of it protects against local divergence**,
because without a baseline the workflow cannot tell "upstream changed this" from "I
changed this" — so a mirror behind upstream got a correct forward-sync and a mirror
*ahead* of upstream got flattened.

It ran fleet-wide for the first time on **2026-08-01** and did its damage in about
twenty-two minutes, reporting success everywhere:

- **`raycast-fly`** lost its entire v2 rewrite — 24 source files removed
  (`src/api/`, `src/pages/`, all 8 AI tools, both commands) and `package.json` reverted to
  upstream's v1, erasing ~30 commits from 2026-03-30/31 that had never been upstreamed.
  Restored 2026-09-02 as a forward commit (`bc0ca877`), not a force-push, so the
  destructive commit `e32351e3` stays in history as the record.
- **`raycast-secret-browser-commands`** lost `src/data/paths.md` (391 lines). It lived
  inside `src/`, which the pruner scans. **Local-only files placed under a synced
  directory are deleted within 24 hours** — put them at root `docs/` or upstream them.
- **`raycast-google-books`** lost `useCachedState` search persistence.
- **Six repos** lost the 2026-07-24 import-sort pass and their `.prettierrc`, because that
  hygiene was local-only and never upstreamed. Local-only *conventions* revert exactly
  like local-only code does.

**The population it hurt is the population the mirror pattern exists to serve** — mirrors
carrying work that had not yet reached the monorepo. Every one of the 17 mirrors was ahead
of upstream in file count when converted.

**A green run proves nothing about damage.** All 33 daily runs since were green, including
the ones that reverted work, and the audit that would have caught it was defeated by a
query that fails silently — see the trap below.

**The blocker that kept the safe version from ever working is a repo SETTING, not code.**
`gh pr create` from `GITHUB_TOKEN` is refused unless *Settings → Actions → General →
"Allow GitHub Actions to create and approve pull requests"* is on. It was off in six of
the seven — only `karakeep` had it — so those mirrors were silently incapable of the one
thing the design exists to do, and looked green purely because they had nothing to PR.
Turned on across all seven 2026-09-02; **check it on any repo you port to**, because the
symptom is a workflow that appears to work until the first time it matters:

```bash
gh api "repos/chrismessina/<repo>/actions/permissions/workflow" \
  --jq '.can_approve_pull_request_reviews'   # must be true
```

Re-derive the fleet split rather than trusting this paragraph — it has been wrong before,
and a bare grep for the *gate* reports the same `0` for "fixed" and for "no such step".
Read the **default branch**, not the worktree: several checkouts sit on feature branches,
where a workflow change is inert because Actions runs the scheduled workflow from the
default branch.

```bash
for r in $(gh repo list chrismessina --limit 200 --json name --jq '.[].name' | grep '^raycast-'); do
  c=$(gh api "repos/chrismessina/$r/contents/.github/workflows/sync-from-upstream.yml" \
        --jq '.content|@base64d' 2>/dev/null) || { echo "none   $r"; continue; }
  grep -q "Record the new baseline" <<<"$c" && echo "safe   $r" || echo "BLIND  $r"
done
```

### 🚨 The filters that answer "none" and "cannot tell" with the same value

Three separate audits of this fleet have been defeated by a query that returns a clean,
plausible, wrong answer instead of an error. Assume any filter is one of these until you
have proved otherwise, by running it against a case whose answer you already know.

| Query | Silent failure |
| --- | --- |
| `gh api "repos/O/R/commits?author=github-actions[bot]"` | The `[]` in the login breaks the filter. Returns `[]`. Reported **0** bot commits across 14 repos where **25** existed — an audit built on it concludes the fleet is dormant and nothing was ever overwritten. |
| `grep -c "updated != '0'"` to test the baseline gate | Returns `0` both when the gate is *fixed* and when the whole step is *missing*. Produced a sweep labelling 18 blind repos as fixed. Classify on the step's **presence** first, then its gate. |
| `gh api repos/raycast/extensions/contents/extensions` | Truncates at 1000 entries with no flag. Made every alphabetically-late slug look absent upstream — 11 false verdicts in a row. Use the tree API and assert `.truncated == false`. |

Filter on the commit **message**, which is under your control, rather than on the author:

```bash
gh api "repos/chrismessina/raycast-<name>/commits?per_page=100" \
  --jq '.[] | select(.commit.message | startswith("chore: sync from upstream"))
        | "\(.commit.author.date[0:10])  \(.sha[0:8])"'
```

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

**A missing mirror on a `chrismessina`-authored extension is not a state to leave
alone — create it as part of the same session, not "if you want one."** Every
self-created extension gets a standalone mirror plus its sync workflow; this is the
default, not an opt-in. See `ship`'s Post-merge cleanup step 0 for the full sequence
(create repo → adopt CI-touched assets → bring the README onto
[`readme-template.md`](./readme-template.md), icon copied into `media/` → wire
`sync-from-upstream.yml`, seeded and verified).

If `gh repo view chrismessina/raycast-<name>` 404s, the standalone repo was never
created. Before anything else:

```bash
# from inside the local working repo, on the branch you intend to publish
gh repo create chrismessina/raycast-<name> --public --source=. --remote=origin \
  --description="<one-liner>" --push
```

This both creates the repo and wires `origin`, fixing the "no remote" state that
silently disables any future sync. THEN proceed with verify-baseline → fork-sync → PR
for a Route B *update*; for a first-time Route A submission, proceed straight to
wiring the sync workflow per `ship`'s step 0 — there is no fork-sync/PR step needed
since the mirror has nothing to diverge from yet.

## What ships (the published file set)

Copy ONLY these into `extensions/<name>/`:

```
assets/  media/  metadata/  src/
.gitignore  .prettierrc  CHANGELOG.md  eslint.config.js  LICENSE
package-lock.json  package.json  README.md  tsconfig.json
```

`media/` was missing from this list until 2026-09-02 and its absence was actively
harmful: the README template's 128px header is an `<img src="media/…">`, so moving an
icon out of `assets/` to satisfy the README-asset rule and then *not* shipping `media/`
turns the Store page's header into a broken image. It does ship — `karakeep` and
`get-app-icon` both publish `media/` upstream today. `LICENSE` and `.prettierrc` were
missing for the same reason: the list was written from one extension's v1.0 and never
re-derived.

**Derive the list, don't recite it.** The authority is the published directory, which
is one fetch away — and it is per-extension (`eslint.config.js` vs `.mjs`, `TODO.md`
present or not). Any list in a document drifts:

```bash
gh api "repos/raycast/extensions/contents/extensions/$EXT" --jq '.[].name' | sort
```

### Agentic and supporting docs — the rule (decided 2026-09-02)

**The axis is AUTHORSHIP, not file type.** An earlier version of this block banned
`AGENTS.md` and `docs/**` outright. That was already false when written: `AGENTS.md` is
merged upstream in `karakeep`, `ejection-seat`, `trimmy` and `reader-mode`, and `docs/**`
in seven of Chris's extensions. Raycast accepts both. **Chris's call, as the extension
owner, is whether to include them** — and he decided to, because docs that help someone
else's agentic contribution are worth shipping.

**In an extension you author** — permitted, and encouraged where they earn their place:

| Path | Ships upstream? | Test |
| --- | --- | --- |
| `AGENTS.md` (root) | **yes** | The canonical name. Cross-tool, and already the fleet majority. |
| `docs/**` | **yes, selectively** | Would a *contributor to this extension* need it? Architecture, configuration, known issues, content-extraction notes: yes. **`docs/solutions/` `ce-compound` learnings: yes, in an extension you author** — Chris runs that skill *to support other contributors*, so on his own extensions the learnings are the product, not a by-product (his ruling, 2026-09-02, on `digger` #30742; an earlier version of this row excluded them and was wrong). What stays behind is material tied to one working session and useless to a stranger: handoffs, session plans, a migration post-mortem for a migration that is over. |
| `CLAUDE.md` / `WARP.md` | **no** | Not a privacy question, a naming one: consolidate on `AGENTS.md`. Every agent reads it. |

**In an extension you do NOT author** — add **nothing**. Not `AGENTS.md`, not `docs/`,
not a `.prettierrc` convention. The single exception: **the file already exists, merged,
in `extensions/<name>/` on `raycast/extensions` main.** Then follow its conventions and
you may edit it. An open PR does not count, and neither does the file existing in your
fork or your local checkout — check the merged monorepo:

```bash
gh api "repos/raycast/extensions/contents/extensions/$EXT/AGENTS.md" --jq '.path' 2>/dev/null \
  || echo "not upstream — do NOT add it to an extension you do not author"
```

🚨 **Never ships, in ANY extension, yours or not.** A dot-prefix is not privacy — GitHub
renders `.private/` in a public repo exactly like any other directory, and everything
under `extensions/<name>/` in `raycast/extensions` is world-readable:

| Path | Why |
| --- | --- |
| **any dot-directory** — `.private/`, `.claude/`, `.windsurf/`, `.cursor/` | Internal notes and tooling config. `.private/` is the worst offender because the name promises something the monorepo does not honour. |
| `TODO.md` | Your backlog, on a public page reviewers read. |
| `.github/**` | Dropped by `ray publish` anyway; `.github/docs/**` and `.github/assets/**` are review docs and icon sources. |

The required dotfiles — `.gitignore`, `.prettierrc`, the eslint config — are not
dot-*directories* and do ship. That is the whole exception.

**Dot-directories MAY be tracked in the standalone mirror** (Chris's call, 2026-09-02) —
that is what a mirror is for. But tracked-and-gitignored is a genuinely broken state: it
is what made `digger`'s sync fail every day until the workflow gained
`git check-ignore --no-index`. If you track it, do not also ignore it.

**Already published? Delete it in this PR.** The copy step only prevents *new* leaks; a
file that leaked in an earlier release stays until something removes it, and an
allow-list copy silently preserves it because the bytes match — published and local
agree, so every staleness check passes clean.

**A separate failure wears the same clothes: a stale fork baseline.** Branching from
`chrismessina/extensions` main rather than upstream main proposed *adding*
`extensions/threads/TODO.md` and `extensions/threads/docs/eslint-9-upgrade-guide.md` —
files the fork carries and upstream does not (2026-09-02). That is not a should-this-ship
question and no ship-time allow-list catches it; branch from upstream main.

**Known leaks live on `raycast/extensions` main as of 2026-09-02** — verified by fetching
the published directory, not inferred:

| Extension | Public right now |
| --- | --- |
| `digger` | `.private/docs/` (4 internal notes) **and** `TODO.md` (16.5 KB) |
| `karakeep` | `TODO.md` (7.5 KB) |
| `secret-browser-commands` | `TODO.md`, and `CLAUDE.md` (should be `AGENTS.md`) |
| `at-profile`, `fathom` | `TODO.md` |

`digger`'s `.private/docs/` removal is in **open PR #30742**, not merged — the files are
still public. Nothing else above has a fix in flight. Sweep them into the next PR that
touches each extension rather than opening five PRs that change nothing else.

```bash
# What is published that should not be? Run BEFORE building the branch.
LEAKS='^(\.private|\.claude|\.windsurf|\.cursor|TODO\.md|CLAUDE\.md|WARP\.md)$'
gh api "repos/raycast/extensions/contents/extensions/$EXT" --jq '.[].name' | grep -E "$LEAKS" \
  && echo "^^ delete these in this PR (git rm -r) — they are public right now"
```

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

### The re-encode changes the BYTES, not the pixels — which is why images must be pulled back DOWN after a merge

> **Corrected 2026-08-29.** This section previously said the optimization was lossy and
> palette-reducing. It is neither. The error came from testing with `sips -s format png` +
> `shasum`, which preserves channel count and therefore compares an RGBA re-encode against an
> RGB one — a difference that says nothing about pixels.

"Raycast-optimized" is a **lossless** re-encode: CI strips a fully-opaque alpha channel and
recompresses. Measured on `claude-artifacts` across both releases that changed a screenshot
(#30529 and #30626): `RGBA -> RGB`, the submitted alpha plane holds the single value `255`,
neither copy is palettized, and **all 7,500,000 RGB bytes are identical**. The 36–37% saving is
the dropped channel plus better zlib. Not one pixel changes.

Three consequences, and they are the whole reason post-merge image sync exists:

1. **The bytes that ship are never the bytes you submitted.** A mirror that does not pull them
   back is permanently divergent from the published extension. The divergence is invisible to
   the eye *and* to a pixel comparison — it lives in the encoding, so only a file hash sees it.
2. **A file hash cannot tell you whether that divergence is benign — a decoded comparison can.**
   "CI re-encoded my screenshot" and "someone replaced the screenshot" both change the bytes, so
   a hash reports the same verdict for each. Decode both and compare the RGB planes and the two
   separate cleanly: pixels equal means CI re-encoded yours, pixels differ means the image
   genuinely changed. A triage script *can* decide this correctly — it just must not do it by
   hashing files.
3. **A safe inbound sync halts on it only if you dispatch before adopting.** Adopt the published
   copy first and the sync short-circuits on byte-equality before it ever consults the recorded
   baseline, so there is nothing to conflict over. Dispatch first and both sides have moved from
   the baseline, which is a genuine conflict a safe sync must refuse.

Full triage procedure and verdict table: `ship`'s PNG triage under the staleness gate. The
baseline trap that a clean post-adoption run hides:
`/Users/messina/Developer/GitHub/chrismessina/raycast-extension-workflows/docs/solutions/workflow-issues/a-green-mirror-sync-does-not-mean-a-fresh-baseline.md`
