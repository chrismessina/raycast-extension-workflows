---
name: ship
description: Get an existing Raycast extension into raycast/extensions and clean up — runs the pre-flight (dep hygiene + house-style AUDIT + weeding), fetches Store-compliance docs, submits the PR (via `ray publish`/`npm run publish` for monorepo extensions you contribute to, or the standalone-mirror fork-sync for your own extensions), preps the PR title/body, drives the review-feedback cycle, and sweeps merged branches. Fires on "submit / publish / ship to the Store", "npm run publish", or "address review feedback (metadata/screenshots)." Does NOT change code behavior — if feedback needs code, hands BACK to `develop`.
metadata:
  stage: "2a + 3 + 5 + 6 + 7 — pre-flight, compliance, PR, review, cleanup"
---

# ship

## The seam: `ship` never changes code behavior

`ship` runs *non-breaking* dep hygiene, the *read-only* house-style audit, weeds metadata, gates compliance, submits, and cleans up. The moment a code change is needed (a failing house-style audit, or Store review feedback that needs code), it **hands back to `develop`** with context, then receives the change forward again. The arrow is two-way.

## Pre-flight checklist (the "cake")

Run before PR. Each layer is gardening, not engineering:

0. **Typecheck gate — `npx tsc --noEmit`.** `ray build` (esbuild) and `ray lint`
   strip/skip types; they pass on code that does NOT typecheck, and an external
   reviewer running `tsc` will catch it. Run `tsc --noEmit` AND `npm run build` AND
   `npm run lint` — a non-zero `tsc` is a failure even when build/lint are green.
   A type error needing code → hand to `develop`. (See house-style.md `[both]` tsc rule.)
1. **Dep hygiene** — `npm outdated`, `npm audit fix`, non-breaking bumps only. Major migrations are NOT here — they're `develop` (gated by `reference/dep-gates.md`).
2. **House-style audit** (read-only — the `npm audit` twin) — assert against `reference/house-style.md` + `reference/keyboard-conventions.md`:
   - Every `Toast.Style.Failure` has a "Copy Error" action.
   - Web-request extensions use `@chrismessina/raycast-logger`.
   - Shortcuts use `Keyboard.Shortcut.Common`; **no conflicts within an ActionPanel.** Assert by *reading the resolved panel* — **never by trusting a green `ray lint`, which does not check this invariant at all.** Resolve each custom combo against the `Common` table first: a hand-written `{cmd+shift+c}` *is* `Common.Copy` and collides with one (see `reference/keyboard-conventions.md`).
   - No hand-defined `Preferences`/`Arguments` types; no `any` casts (`[lint]` — backstop only; durable home is ESLint).
   - **Any failure that needs code → hand to `develop`'s house-style audit fix.**
3. **Weeding** — screenshots current (did we add a command/view?), README current, CHANGELOG updated.
   - **CHANGELOG: add a NEW top entry with `{PR_MERGE_DATE}` for THIS update. Never
     touch entries that already carry a real date.** Raycast CI stamps the
     placeholder on merge; reverting an already-dated older entry (e.g. Initial
     Version) back to `{PR_MERGE_DATE}` makes it re-stamp with the new merge date,
     so it looks like the whole history launched today. (Bookface #28961 review
     flagged exactly this — it only came out right because CI/maintainer preserved
     the old date. Don't rely on that.) Diff the CHANGELOG against the published one
     and confirm only the new entry differs.

## HARD GATE — no PR without a green pre-flight

**The pre-flight above is a gate, not a suggestion. Do not open OR update a Store PR —
`ray publish`, `gh pr create`, or a push to an existing PR branch — until steps 0–3 have
actually been RUN and are green.**

This exists because it was violated. On 2026-07-13 the house-style audit was skipped
before publishing producthunt, and ⌘-only shortcuts (on a cross-platform extension) plus
Copy-Error-less failure toasts shipped into an open PR. The linter and the human reviewer
caught them *after* submission. The audit is worthless if it runs after the PR.

Before any submission command, state explicitly which of these you ran and what they
returned — paste the actual output, don't assert it:

- [ ] `npx tsc --noEmit` → exit 0
- [ ] `npm run build` → exit 0
- [ ] `npm run lint` → exit 0
- [ ] **house-style audit** (step 2) → zero violations, having **read `package.json`
      `platforms` first** (absent ⇒ macOS-only; see `reference/house-style.md`)
- [ ] weeding (step 3) → CHANGELOG top entry is new + `{PR_MERGE_DATE}`; screenshots/README current

**Any violation that needs code → STOP and hand to `develop`.** Do not fix it here and do
not ship around it. `ship` never changes code behavior.

## Store compliance gate

Fetch authoritative Store docs (absorbs the old `raycast-extension-review` skill).
**Fetch — do not audit from memory.** Prefer context7 (`/llmstxt/developers_raycast_llms-full_txt`),
falling back to WebFetch. Full procedure: `reference/store-guidelines.md`. Audit, don't guess.

## PR prep

Title convention: `Update <Title> extension` by default; `[Title] <fix>` when one change dominates. No Conventional Commits. See `reference/pr-and-cleanup.md`.

## Submission — pick the topology FIRST

There are two ways an extension reaches the Store, and they are NOT
interchangeable. Before doing anything, decide which one you're in — reading
`package.json`'s `author` field is the fastest tell:

- **Contributor to a monorepo extension** (`author` is someone else, or the repo
  is a fork of an existing `raycast/extensions` extension you help maintain — e.g.
  `video-downloader`, `author: vimtor`). → **Route A: `ray publish`.** This is the
  common case and the default.
- **Owner of your own extension** (`author: chrismessina`, first-party, has — or
  needs — a standalone `chrismessina/raycast-<name>` mirror). → **Route B:
  standalone mirror + manual fork-sync PR.**

If unsure, it's almost always Route A. Only reach for Route B when the extension is
genuinely yours and the standalone-mirror topology applies. **Do NOT ask the user a
repo/PR-destination decision tree for a Route-A extension** — `ray publish` decides
the destination (it always targets `raycast/extensions`). Asking is the failure this
section exists to prevent.

### Route A — `ray publish` (default; monorepo extensions you contribute to)

`ray publish` (`npm run publish`) IS the whole submission flow. It syncs your
`chrismessina/extensions` fork, clones/prepares the extension, pushes the branch, and
opens a **draft** PR to `raycast/extensions` — no standalone repo, no git remote on
the working repo, and no hand-rolled `gh pr create` needed. A missing/absent local
git remote is NOT a blocker here; `ray publish` does not use it.

1. Ensure the pre-flight above is green and the change is committed (signed).
2. Run `npm run publish`. It runs its own validate/lint/Prettier gates, then
   `getting fork → preparing clone → pushing extension → opening PR`.
3. On success it prints the draft PR URL (`raycast/extensions/pull/<N>`). Relay it.
   The PR opens as a **draft** — the user fills in the description and clicks
   "Ready for review"; those are the user's steps, not yours. Offer to draft the PR
   body (see PR prep).

**Known failure — stale fork (expected, not a bug).** `ray publish` may stop with:

> `error - getting fork` … *"could not get the latest changes. Head to
> https://github.com/chrismessina/extensions, select the Sync fork dropdown … click
> Update branch. Once you've done that, try running this command again"* (often an
> `HTTP error: 500`).

This means the `chrismessina/extensions` fork has drifted behind upstream. It's
routine and needs the user's browser session — you cannot fix it headlessly. Relay
the three steps verbatim (open the fork → **Sync fork** dropdown → **Update
branch**), then **re-run `npm run publish`** once they confirm. Nothing is wrong with
the code; don't start debugging the extension.

### Route B — standalone mirror (your own `author: chrismessina` extensions)

Only for first-party extensions with the standalone-mirror topology.

**FIRST: does the standalone repo exist?** `gh repo view chrismessina/raycast-<name>`.
If it 404s (the case that derailed the first Bookface ship — the repo was never
created), the entry point is to **create it and push** before anything else:
`gh repo create chrismessina/raycast-<name> --public --source=. --remote=origin --push`.
Then verify local `main` == the published v1.x (byte-diff the sparse-fetched dir)
before trusting it as the baseline.

**No live auto-sync exists today.** An earlier draft said "Actions own the standalone
repo, don't push" — but there is no working dispatcher (the repo didn't exist to host
one). The canonical flow is **manual**: push standalone `main` → sync the published
file set into the `chrismessina/extensions` fork → open the PR. If you later wire an
Actions pipeline, document it and prefer it; until then do not assume automation.

Full topology, the "what ships" allow-list, and the assets-bloat gotcha:
`reference/my-extensions-mirror.md`.

## Post-merge cleanup

Sweep merged branches by PR state (squash-merge re-SHAs, so use `gh pr list --head`, not git ancestry). See `reference/pr-and-cleanup.md`.

## Throughline A (hard rail)

**Never sync the full monorepo.** Sparse-checkout discipline — see `reference/sparse-checkout-discipline.md`.
