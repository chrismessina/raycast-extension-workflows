---
name: ship
description: Get an existing Raycast extension into raycast/extensions and clean up — runs the pre-flight (dep hygiene + house-style AUDIT + weeding), fetches Store-compliance docs, preps the PR + title, drives the review-feedback cycle, verifies mirror-sync, and sweeps merged branches. Fires on "submit / publish / ship to the Store" or "address review feedback (metadata/screenshots)." Does NOT change code behavior — if feedback needs code, hands BACK to `develop`.
metadata:
  stage: "2a + 3 + 5 + 6 + 7 — pre-flight, compliance, PR, review, cleanup"
  status: stub
---

# ship

> **STUB — authored to first-draft depth.** Deep authoring pending. The design contract is fixed; the prose below is the skeleton.

## The seam: `ship` never changes code behavior

`ship` runs *non-breaking* dep hygiene, the *read-only* house-style audit, weeds metadata, gates compliance, submits, and cleans up. The moment a code change is needed (a failing house-style audit, or Store review feedback that needs code), it **hands back to `develop`** with context, then receives the change forward again. The arrow is two-way.

## Pre-flight checklist (the "cake")

Run before PR. Each layer is gardening, not engineering:

1. **Dep hygiene** — `npm outdated`, `npm audit fix`, non-breaking bumps only. Major migrations are NOT here — they're `develop` (gated by `reference/dep-gates.md`).
2. **House-style audit** (read-only — the `npm audit` twin) — assert against `reference/house-style.md` + `reference/keyboard-conventions.md`:
   - Every `Toast.Style.Failure` has a "Copy Error" action.
   - Web-request extensions use `@chrismessina/raycast-logger`.
   - Shortcuts use `Keyboard.Shortcut.Common`; **no conflicts within an ActionPanel.**
   - No hand-defined `Preferences`/`Arguments` types; no `any` casts (`[lint]` — backstop only; durable home is ESLint).
   - **Any failure that needs code → hand to `develop`'s house-style audit fix.**
3. **Weeding** — screenshots current (did we add a command/view?), README current, CHANGELOG date block present.

## Store compliance gate

Fetch authoritative Store docs (absorbs the old `review` skill). See `reference/store-guidelines.md`. Audit, don't guess.

## PR prep

Title convention: `Update <Title> extension` by default; `[Title] <fix>` when one change dominates. No Conventional Commits. See `reference/pr-and-cleanup.md`.

## Mirror-sync verification (`author: chrismessina` only)

**Do NOT push to the standalone repo** — GitHub Actions own it. Only: confirm the dispatcher fired, check sync lag (< 5 min expected, flag > 10), and if the extension is yours but not yet wired, point to the runbook. See `reference/my-extensions-mirror.md`.

## Post-merge cleanup

Sweep merged branches by PR state (squash-merge re-SHAs, so use `gh pr list --head`, not git ancestry). See `reference/pr-and-cleanup.md`.

## Throughline A (hard rail)

**Never sync the full monorepo.** Sparse-checkout discipline — see `reference/sparse-checkout-discipline.md`.
