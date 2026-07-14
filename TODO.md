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
