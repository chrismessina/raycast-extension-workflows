# raycast-extension-workflows — TODO

Backlog for the `raycast-extensions` plugin (`plugins/raycast-extensions/`). Compiled 2026-07-13
after diagnosing the "components keep going missing" drift while shipping the producthunt v3.1 PR.
Everything below was verified directly against this repo + the installed cache, not guessed.

## Context: the drift mechanism (root cause)

The plugin installs by **copying** source → `~/.claude/plugins/cache/raycast-extension-workflows/raycast-extensions/<version>/`.
The cache is a version-keyed **copy**, not a symlink (per repo commit `ab6183c`). So:

- Editing the **cache** is lost on the next reinstall.
- Editing the **source** doesn't reach a running Claude session until reinstall (or a manual cache copy).
- Source and cache had **diverged in both directions** at diagnosis time (cache missing 2 reference
  files that exist here; source having a newer `tsc` house-style rule the cache lacked).

**Working rule going forward: edit the SOURCE (this repo). The cache is disposable.**
(This is now documented in `~/.claude/CLAUDE.md` → "Raycast extension workflows — skill routing".)

---

## P0 — dangling reference files (the "missing components")

`check-references.sh` (added 2026-07-13, commit `cce9c49`) asserts every `reference/X.md` a skill
points to actually exists. It currently **FAILS** on 3 files that skills reference but were never authored:

- [ ] **`reference/dep-gates.md`** — referenced by `develop` + `ship`. Should hold known-good dependency
  version floors/ceilings for major migrations (eslint, typescript, node, @raycast/api). `develop`'s
  modernization intent is gated on it.
- [ ] **`reference/sparse-checkout-discipline.md`** — referenced by `develop` + `ship` (Throughline A,
  the "never sync the full monorepo" hard rail). The actual sparse-checkout procedure lives only in
  prose right now; extract it into this file.
- [ ] **`reference/store-guidelines.md`** — referenced by `ship`'s compliance gate. Should absorb the
  old `review` skill's authoritative Raycast Store rules (or point at the live docs to fetch).

Run `bash check-references.sh` — it prints each missing file + which skill references it. Green when all authored.

## P1 — wire the guard + fix the drift permanently

- [ ] **Add `check-references.sh` to CI** (there are already `dispatch-sync.yml` / `sync-from-upstream.yml`
  workflows — add a job that runs it and fails the build on a dangling reference).
- [ ] **Version-bump on every source change** so a stale cache (`0.1.0`) can't shadow newer source.
  Confirm the install path is version-keyed end-to-end (it should be, per `ab6183c`).
- [ ] **Add a `sync-cache` convenience** (make target / script) that copies `plugins/.../reference/*`
  and `skills/*` into the active `~/.claude/plugins/cache/.../<version>/` dir, for iterating without a
  full reinstall. (Band-aid used manually on 2026-07-13.)

## P2 — finish `ship`

`ship/SKILL.md` is marked `status: stub` but is actually substantial (full Route A `ray publish` /
Route B mirror topology, pre-flight, stale-fork handling). What's left:

- [ ] Drop the `status: stub` marker + the "STUB — authored to first-draft depth" banner once the
  reference files it points to (P0) exist and it's been exercised end-to-end.
- [ ] Confirm the pre-flight house-style audit actually runs before PR in practice — the producthunt
  2026-07-13 miss (⌘-only shortcuts + Copy-Error-less toasts shipped into an open PR) happened because
  the audit was NOT run before publish. Make "run the `develop` house-style audit before any PR" a hard
  gate in `ship`, not just prose.

## P3 — repo rename (Chris's request, pending)

- [ ] Rename repo `raycast-extension-workflows` → `raycast-extension-skills`. **Do this atomically** —
  it ripples through: the marketplace manifest (commit `de31c0d` added one), the README, the plugin
  install URL/command, and any local `.claude` plugin config pointing at the old name. Trace every
  reference and update in lockstep; don't do it piecemeal (that's how drift starts). The plugin's
  internal name is already `raycast-extensions` (distinct from the repo name) — decide whether that
  stays or aligns too.

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
