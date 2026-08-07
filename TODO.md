# raycast-extension-workflows — TODO

Backlog for the `raycast-extensions` plugin (`plugins/raycast-extensions/`). Compiled 2026-07-13
after diagnosing the "components keep going missing" drift while shipping the producthunt v3.1 PR.
Everything below was verified directly against this repo + the installed cache, not guessed.

## Context: the drift mechanism (root cause)

The plugin installs by **copying** source → `~/.claude/plugins/cache/raycast-extension-workflows/raycast-extensions/<version>/`.
The cache is a version-keyed **copy**, not a symlink (per repo commit `ab6183c`). So:

- Editing the **cache** is lost on the next reinstall.
- Editing the **source** doesn't reach a running Claude session until reinstall (or a manual cache copy).
- Source and cache had **diverged in both directions** at diagnosis time.

**Working rule going forward: edit the SOURCE (this repo). The cache is disposable.**
(This is now documented in `~/.claude/CLAUDE.md` → "Raycast extension workflows — skill routing".)

**Confirmed root cause of the shadowing (2026-07-13):** the version was pinned at `0.1.0` and
never bumped, so the `0.1.0` cache dir persisted across every source change and permanently
shadowed newer source. Bumping the version forces a fresh cache dir. Now at `0.2.0`.

---

## Done (2026-07-13, session 2)

### P0 — dangling reference files — **CLOSED**

`check-references.sh` now passes (exit 0, all 7 references resolve). Authored:

- [x] **`reference/dep-gates.md`** — two-tier model (**FLOOR** = safe everywhere; **LEADING EDGE**
  = proven but opt-in), built from a real census of all 34 `raycast-*` repos rather than invented
  numbers. Floor: eslint 9 / TS 5.9 / `@raycast/api` 1.103 / Node 22. Leading edge: eslint 10 /
  TS 6 — **proven on only `airbuddy` + `tesla-energy`**, so it is explicitly NOT the default.
  Names the two genuinely stranded extensions (`craftdocs`: eslint 7 / TS 4.4; `quick-call`:
  eslint 8 / TS 4.7) as the real migration candidates. Includes the census script to re-derive it.
- [x] **`reference/sparse-checkout-discipline.md`** — the Throughline A hard rail, extracted from
  prose into an actual procedure (`--filter=blob:none --no-checkout` → `sparse-checkout set` →
  `checkout`, in that order), plus the fork-remote naming that makes a stray `git push origin` fail
  loudly, the baseline-verification diff, and the cone-mode gotchas.
- [x] **`reference/store-guidelines.md`** — deliberately a **fetch procedure, not a rules copy.**
  The absorbed `raycast-extension-review` skill's core principle is *"do not rely on hardcoded
  rules — fetch the live docs"*; transcribing the rules statically would have inverted the one
  thing it insists on. Primary route is **context7** (`/llmstxt/developers_raycast_llms-full_txt`,
  High reputation — verified working), falling back to WebFetch. Caches only structural,
  slow-moving facts, each stamped + drift-guarded.

### Bonus — a real hole in the keyboard rule, found by the census

- [x] **`platforms` absent was undefined behavior.** The two-axis keyboard rule branches on
  `package.json` `platforms`, but said nothing about the field being **missing** — and it's missing
  on **7 of 34** extensions (`at-profile`, `google-books`, `ios-apps`, `raycast-fly`,
  `wayback-machine`, `craftdocs`, `quick-call`). An auditor defaulting absent → cross-platform
  would have raised a bogus ⌘-only defect on every one of them. **Absent now explicitly means
  macOS-only** (Raycast's historical default; the field postdates Windows support), fixed in
  lockstep across `house-style.md` + `keyboard-conventions.md` (both tables + the audit-fix
  contract's step 0).

### P1 — wire the guard + fix the drift permanently — **CLOSED**

- [x] **`check-references.sh` in CI.** *The TODO's premise here was wrong:* `dispatch-sync.yml` and
  `sync-from-upstream.yml` sit **loose in the repo root and are not wired into Actions at all** —
  they're templates for the *extension* repos (they reference `extensions/*/package.json`, the
  monorepo layout). There was **no `.github/` directory**. Created a real one:
  `.github/workflows/check-references.yml` (push to main + PR + manual dispatch).
- [x] **Version-bump.** `0.1.0` → `0.2.0`. This is the actual fix for cache shadowing.
- [x] **`sync-cache.sh`.** `bash sync-cache.sh` copies source → active cache;
  `bash sync-cache.sh --check` reports drift without mutating (exit 1 if drifted). Uses
  `rsync --delete`, so files *removed* from source also leave the cache — a plain copy would strand
  orphans and reintroduce drift in the other direction.

**Guard verified working, not just written:** witnessed RED (exit 1, correctly naming the
offending skill) on a deliberately-injected dangling reference, then GREEN (exit 0) once removed.

### P2 — finish `ship` — mostly closed

- [x] Dropped the `status: stub` marker + the "STUB" banner (its stated precondition — the P0
  reference files existing — is now met).
- [x] **Made the house-style audit a HARD GATE, not prose.** This is the fix for the actual
  producthunt failure: a "no PR without a green pre-flight" section that must be run *before* any
  `ray publish` / `gh pr create` / branch push, with an explicit run-and-paste-the-output checklist
  (tsc / build / lint / house-style / weeding). The audit is worthless if it runs after the PR.

---

## Still open

### P1 — five defects in the three-way-merge sync rewrite (added 2026-08-07)

**Found by an adversarial Codex review** of `raycast-karakeep`'s
`.github/workflows/sync-from-upstream.yml` at commits `82b5517` + `2ce6304` (the rewrite
that replaced the manifest approach with a committed `.github/upstream-sync-state.json`
baseline). Each was then verified by reading the file directly, not taken on the
reviewer's word. **These live in the deployed workflow, not the canonical template** —
fixing one mirror alone would fork it, so fix the template and redeploy.

**Context that shapes the priorities.** The version this replaced deleted an entire
mirror — 4,060 lines including `package.json`, `tsconfig.json`, `README.md`, `AGENTS.md`
and the workflow itself — **while reporting success**. The rewrite over-corrected into
"never delete", which is why #1 exists. That trade is defensible; it just needs to be a
decision rather than an accident.

**The safety net holds.** Verified: the workflow only ever pushes to a
`sync/upstream-<commit>` branch and opens a PR — nothing writes to `main`. The
truncated-tree guard and the download hash checks are intact. So the worst case for #3
is a bad diff a human rejects, not silent data loss.

#### Ranked

- [ ] **#5 — a closed-unmerged sync PR wedges all future runs.** (`:310-318`) The
      dedupe check queries `gh pr list --state open` only, then runs an unconditional
      `git push -u origin "$BRANCH"`. Close a sync PR without merging and the remote
      branch survives; every later run for that same upstream commit fails on the push.
      Nothing recovers until upstream moves or someone deletes the branch by hand.
      **Bites soonest** — closing an unwanted sync PR is a normal thing to do.

- [ ] **#2 — an upstream `.gitignore` change can wedge the sync permanently.**
      (`:163`, `:253`, `:299`) Comparison runs `git check-ignore` against the **old**
      checkout's rules, so it queues both the new `.gitignore` and a path that file will
      newly ignore. At staging, `git add` refuses the ignored path, `xargs` exits
      non-zero, and no PR is created — so `main` keeps the old `.gitignore` and the next
      run repeats it identically. Self-perpetuating.

- [ ] **#1 — upstream deletions never propagate.** (`:149`) The classification loop
      iterates `upstream.tsv`, so a path that exists in the baseline and the mirror but
      is *absent* upstream is never considered. `updated` stays zero, no PR is opened,
      and the mirror keeps the file forever. **Decide deliberately:** is "never delete"
      the intended contract after the earlier catastrophe, or should deletions surface
      in the PR for a human to approve? If the former, say so in the workflow's comments
      so the next reader doesn't read it as an oversight.

- [ ] **#4 — a formerly-ignored path can never be imported.** (`:163-165`, `:277-284`)
      While a mirror ignores `private/a`, the state file still records upstream's blob.
      Remove the ignore rule later and the comparison sees upstream unchanged from
      baseline but the mirror missing the file, files it under `kept-local`, and never
      downloads it. A subsequent upstream edit then registers as a *conflict* instead of
      repairing the gap.

- [ ] **#3 — a valid-but-wrong state entry can overwrite local work.** (`:168-195`)
      If `upstream-sync-state.json` records blob `L` while the true baseline was `A` and
      the mirror holds local change `L`, then `mirror_moved=false` and the file is queued
      for update — overwriting `L`. Missing or malformed state fails closed, and a merely
      *stale* baseline is conservative; the hole is specifically a syntactically valid
      entry that is wrong. Lands in a PR, so a human is still the checkpoint. Lowest of
      the five for that reason.

#### Verification (the same shape as the last sweep)

Each fix wants a real run, not just edited YAML — the earlier version passed every
static read while deleting a repo. `raycast-karakeep` is the reference deployment.

- [ ] Fix in the canonical template first, then redeploy to the mirrors carrying the
      rewrite (check which — not all 22 have it)
- [ ] Confirm with a dispatched run per fix, reading the log rather than the exit status

### P1 — upstream sync — **LARGELY CLOSED 2026-07-31** (see below; original entry kept for context)

> **Update 2026-07-31 (karakeep 2.4.0 ship).** The missing `schedule:` was only *one* of four
> defects, and the least dangerous. The template itself was broken in three further ways, each
> verified against real CI runs on `raycast-karakeep`:
>
> 1. **`git add -A`** swept any local-only file into an unreviewed automated commit.
> 2. **A per-file contents-API walk** (~85 requests) tripped secondary rate limits against
>    `raycast/extensions` — a repo the default `GITHUB_TOKEN` doesn't own. Run `30660911758`
>    failed partway through it.
> 3. **The deletion pass could delete the entire repository.** A later revision (karakeep-only)
>    wrote manifest paths as `"${local_path#./}/$name"`; for a root-level file `local_path` is
>    bare `.` and the stripped prefix is `./`, yielding `./package.json` while the guard grepped
>    for `package.json`. Every root file therefore read as "no longer served upstream". Run
>    `30651601868` deleted `package.json`, `package-lock.json`, `tsconfig.json`, `README.md`,
>    `AGENTS.md`, `.gitignore` and the workflow itself — **4,060 lines, while reporting success.**
>
> The template is now the version proven green in run `30676094499` (77/77 files, zero deletions):
> one scoped tree call (4 API requests), fail-closed `truncated=false` and downloaded-count
> assertions, staging limited to the manifest, and deletion candidates limited to *directories*
> the sync populates, skipped entirely below 10 manifest entries.
>
> **A whole-repo `git/trees?recursive=1` DOES truncate on this monorepo** — dropped entries would
> read as upstream deletions, which is why the call is scoped to the extension's own subtree.
>
> **Deployed:** all 12 mirrors that had the workflow, plus 10 of the 11 published mirrors that
> lacked it. `raycast-luma` (no remote), `raycast-change-case` / `raycast-craftdocs` (no remote —
> committed locally), `raycast-quick-call` (detached HEAD — skipped).
>
> **Published set re-derived** (the 2026-07-29 blocker). Note the contents API **caps at 1000
> entries** and silently truncates: it stopped at `g` and reported `karakeep` as unpublished. Use
> the tree API and assert `truncated == false` — 3,139 extensions, sentinels verified.
> **11 of 23 Group B repos are published**; the other 12 have no upstream and are correctly skipped.

### P1 — upstream sync does not auto-fire on 35 of 36 mirrors (added 2026-07-29)

**The mechanism.** `sync-from-upstream.yml` reconciles a standalone mirror against the merged
monorepo state — it is what delivers the two things Raycast CI produces *only on merge*:
**recompressed screenshots** and the **stamped `{PR_MERGE_DATE}`**. Where it doesn't fire, the
mirror drifts silently, and the cost lands on the *next* ship session as staleness-gate
reconciliation done by hand, long after anyone remembers why.

**Receipt:** `get-app-icon` was `repository_dispatch` + `workflow_dispatch` with no `schedule`.
`gh run list` showed **one run in five months** (manual, 2026-02-27). It never fired for the
2026-07-27 merge, and the 2026-07-29 ship session paid for it — adopting 3 CI-compressed PNGs by
hand (1.9 MB) and resolving a CHANGELOG conflict that would otherwise have re-dated shipped
history. Fixed there in `5a82561` (daily cron at `17 9 * * *`).

**The fix, per repo, is a 4-line insertion** into the existing `on:` block — keep
`repository_dispatch` as the fast path:

```yaml
on:
  schedule:
    - cron: "17 9 * * *"   # off the hour; daily is plenty — Store review takes days
  repository_dispatch:
    types: [upstream-sync]
  workflow_dispatch:
```

> **Stagger the minute per repo** rather than pasting `17 9` 35 times. GitHub queues
> same-minute cron across all of Actions, and scheduled runs are already best-effort/delayed
> under load; 35 mirrors firing simultaneously is self-inflicted contention. Spread them across
> the hour (e.g. `$((RANDOM % 60)) 9 * * *`, recorded per repo).

#### Group A — had the workflow — **DONE 2026-07-31** (12; all needed the WHOLE file replaced, not just `schedule:`)

11 of these are **byte-identical** (`sha256 b32b8b12…`), so one edit is mechanically repeatable.
`raycast-reader` differs *only* by `UPSTREAM_EXT_DIR: "reader-mode"` (slug override) — same
structure, same edit.

- [x] `/Users/messina/Developer/GitHub/chrismessina/raycast-at-profile` (`at-profile`)
- [x] `/Users/messina/Developer/GitHub/chrismessina/raycast-bookface` (`bookface`)
- [x] `/Users/messina/Developer/GitHub/chrismessina/raycast-digger` (`digger`)
- [x] `/Users/messina/Developer/GitHub/chrismessina/raycast-fathom` (`fathom`)
- [x] `/Users/messina/Developer/GitHub/chrismessina/raycast-karakeep` (`karakeep`)
- [x] `/Users/messina/Developer/GitHub/chrismessina/raycast-luma` (`luma`)
- [x] `/Users/messina/Developer/GitHub/chrismessina/raycast-reader` (`reader-mode` — slug override)
- [x] `/Users/messina/Developer/GitHub/chrismessina/raycast-secret-browser-commands` (`secret-browser-commands`)
- [x] `/Users/messina/Developer/GitHub/chrismessina/raycast-store-updates` (`raycast-store-updates`)
- [x] `/Users/messina/Developer/GitHub/chrismessina/raycast-tesla-energy` (`tesla-energy`)
- [x] `/Users/messina/Developer/GitHub/chrismessina/raycast-trimmy` (`trimmy`)
- [x] `/Users/messina/Developer/GitHub/chrismessina/raycast-wrap-unwrap` (`wrap-unwrap`)

#### Group B — no workflow at all; needs the file, but ONLY if published upstream (23)

Copy the template from `raycast-get-app-icon/.github/workflows/sync-from-upstream.yml` (it now
carries the cron), setting `UPSTREAM_EXT_DIR` when the monorepo dir ≠ `package.json` `name`.

**Gate each one on "is this slug actually in `raycast/extensions`?" first.** An unpublished
extension has no upstream to sync from, so the workflow would fail on every run — noise, not
coverage. That check could not be completed on 2026-07-29: `gh api` began returning
`authorization timeout` mid-survey (the 1Password/keychain prompt), and an earlier version of the
survey script **silently reported all 36 as unpublished** because it collapsed that error into
"no". Re-derive the published set before touching Group B, and fail loud on a non-200/404:

```bash
# One call for the whole monorepo beats 36 per-slug calls. Verify it parsed as an ARRAY
# before trusting it — an auth error that reads as "not published" is the trap here.
JSON=$(gh api "repos/raycast/extensions/contents/extensions" 2>&1)
printf '%s' "$JSON" | jq -e 'type=="array"' >/dev/null \
  || { echo "ABORT: $(printf '%s' "$JSON" | head -c 120)"; exit 1; }
printf '%s' "$JSON" | jq -r '.[] | select(.type=="dir") | .name' | sort > /tmp/upstream_slugs.txt
grep -qx get-app-icon /tmp/upstream_slugs.txt || { echo "ABORT: list looks wrong"; exit 1; }
```

`airbuddy`, `brew`, `central-icon-system`, `change-case`, `claude-artifacts`, `craft`,
`craftdocs`, `domainr`, `fetch`, `raycast-fly`, `google-books`, `google-maps`, `happenstance`,
`ios-apps`, `memory-store`, `openskills`, `parallel-web-tools`, `quick-call`, `screenocr`,
`sora`, `threads-client`, `wayback-machine`, `word-count`

- [x] Re-derive the published set (2026-07-31 — see the update block at the top of this section)
- [x] Add the workflow to each **published** repo (10 of 11 done; `quick-call` skipped, detached HEAD)
- [x] Record which of the 23 are unpublished, so the next sweep doesn't re-check them:

  **Published (workflow added):** `brew`, `change-case`ᴸ, `claude-artifacts`, `craftdocs`ᴸ,
  `domainr`, `raycast-fly`, `google-books`, `screenocr`, `wayback-machine`, `word-count`,
  and `quick-call` (**still needs it** — detached HEAD at the time).
  ᴸ = committed locally only; the repo has no `origin` remote.

  **Not published as of 2026-07-31 — no upstream to sync, skip:** `airbuddy`,
  `central-icon-system`, `craft`, `fetch`, `google-maps`, `happenstance`, `ios-apps`,
  `memory-store`, `openskills`, `parallel-web-tools`, `sora`, `threads-client`.

  Not extensions at all (no `commands` key), excluded from the sweep: `raycast-kit`,
  `raycast-logger`, `raycast-extension-workflows`, `raycast-memory-store-workspace`.

- [ ] `raycast-quick-call` is on a detached HEAD — check out `main` before adding the workflow
- [ ] `raycast-luma`, `raycast-change-case`, `raycast-craftdocs` have no `origin` remote; the
      commits exist locally but no cron can fire until each has a GitHub remote

#### Verification (per repo — a workflow that never runs looks identical to one that works)

```bash
sed -n '/^on:/,/^jobs:/p' .github/workflows/sync-from-upstream.yml   # schedule present?
gh run list --workflow sync-from-upstream.yml --limit 5              # did it ACTUALLY run?
```

**A cron on a branch other than the default branch never fires** — commit to `main`. And GitHub
disables scheduled workflows in repos with no activity for 60 days, which several of these will
hit; the run-history check is the only way to notice.

- [ ] Sweep once after the first cron day to confirm real runs (not just committed YAML)

**Reassurance for the media/metadata worry:** the sync downloads the extension dir recursively, so
it *does* overwrite `media/` and `metadata/`. That is safe for freshly-updated screenshots
**provided they are in the merged PR** — post-merge upstream then holds the user's own images,
CI-recompressed, so a 1.6 MB local copy is replaced by a pixel-identical smaller one. A local
screenshot *not* in a merged PR **would** be reverted: publish first, then sync.

### P2 — `ship`, remaining

- [ ] **Exercise `ship` end-to-end on a real submission.** Everything above is authored and
  statically verified; none of it has been driven through an actual Store PR yet. The next
  extension you ship is the real test — specifically whether the hard gate actually fires.

### P3 — repo rename (pending your call)

- [ ] Rename repo `raycast-extension-workflows` → `raycast-extension-skills`. **Do this
  atomically** — it ripples through: the marketplace manifest (`.claude-plugin/marketplace.json`),
  the README, the plugin install URL/command, **the cache path** (`~/.claude/plugins/cache/
  raycast-extension-workflows/…` — hardcoded in `sync-cache.sh`, which will need updating in the
  same commit), and any local `.claude` plugin config. Trace every reference and update in lockstep;
  don't do it piecemeal (that's how drift starts). The plugin's internal name is already
  `raycast-extensions` (distinct from the repo name) — decide whether that stays or aligns too.

### Follow-ups worth considering

- [ ] **Add `sync-cache.sh --check` to CI?** It can't run in CI (there's no `~/.claude` cache on a
  runner), so it's a local-only tool. Possibly worth a git pre-commit hook instead — but per your
  standing preference against "semi-invisible systems I'll forget exist," it's opt-in, not proposed.
- [ ] **`craftdocs` + `quick-call` are stranded** (see `dep-gates.md`). Not urgent, but they're the
  two extensions where a `develop` modernization pass would actually do real work. `craftdocs` is 3
  ESLint majors and 2 TS majors behind — that's a project, not a bump.

## Done (2026-07-13, commit `cce9c49`)

- [x] Keyboard-shortcut house-style rule: split the conflated rule into two independent axes —
  (1) does a `Common` member match the semantics, (2) what does `package.json` `platforms` say.
  Platform-explicit `{ macOS, Windows }` is REQUIRED for cross-platform extensions (not "always
  remove"); plain objects for macOS-only. Fixed the audit-fix contract (was: unconditionally "remove
  platform objects"). Corrected casing to `Windows` (capital W; TS rejects lowercase). In both
  `reference/house-style.md` and `reference/keyboard-conventions.md`.
- [x] Added `check-references.sh` anti-drift guard.
- [x] Synced the 2 source-only reference files (`pr-and-cleanup.md`, `my-extensions-mirror.md`) into
  the active install cache so `ship` resolves them today.
