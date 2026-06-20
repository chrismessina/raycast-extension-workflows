---
name: develop
description: Change the CODE of an EXISTING Raycast extension — feature work, refactors, deliberate major dependency migrations (Node bump, ESLint major, flat-config, @raycast/api breaking changes), and bringing a forked or legacy extension up to Chris's House Style (the "house-style audit fix"). Fires on "build/add/change/refactor [feature]", "migrate to ESLint 10 / Node 22 / flat config", or "bring this fork up to my house style / fix the toasts & shortcuts to match my conventions." Does NOT scaffold net-new (that's `scaffold`) and does NOT submit to the Store (that's `ship`). Absorbs the former `raycast-extension-modernizer`.
metadata:
  stage: "2b + 4 — modernization + feature/refactor + house-style audit fix"
---

# develop

Owns every **code-changing** operation on an extension that already exists. Three intents live here, and the trigger phrase tells them apart:

| Intent | Trigger shape | What it does |
|---|---|---|
| **Feature / refactor** | "add / change / refactor X" | Normal command/view/logic work. |
| **Modernization** | "migrate to ESLint 10 / the new Node / flat config" | Deliberate **major-version** migration, gated. |
| **House-style audit fix** | "bring this up to my house style", "fix the toasts/shortcuts" | Sweep existing code and retrofit it to House Style. |

All three change code, so they all live here and all hand forward to `ship` when done. That's the seam.

## Seam rules (do not cross)

- **vs `scaffold`** — binary on existence. The extension already exists; you're changing it. If it doesn't exist yet, stop — that's `scaffold`.
- **vs `ship`** — `ship` never changes code behavior. If the work is non-breaking dep hygiene, metadata weeding, compliance, or submission, it belongs to `ship`, not here.
- **Two-way handoff from `ship`** — when `ship`'s house-style audit fails, or Store review feedback needs **code** (not just metadata/screenshots), `ship` hands *back* here with the feedback context. Make the change, then hand forward to `ship` again. Don't try to submit from `develop`.

## Throughline A — hard rail

**Never sync or clone the full monorepo.** Sparse-checkout discipline applies to every operation here. Before any monorepo read/write, consult [`../../reference/sparse-checkout-discipline.md`](../../reference/sparse-checkout-discipline.md).

---

## Intent 1 — Feature / refactor

Ordinary code work. The only non-default obligation: **write to House Style as you go.** Don't add a failure toast without a Copy-Error action; don't add an `Action` with an ad-hoc shortcut where a `Keyboard.Shortcut.Common` fits. See House Style below — applying it inline is cheaper than letting `ship`'s audit bounce it back.

## Intent 2 — Modernization (gated)

Deliberate **major-version** migrations only: Node bump, ESLint 9→10, flat-config migration, `@raycast/api` breaking changes. (Routine non-breaking bumps are NOT this — they're `ship`'s dep hygiene. If the user means "keep my packages current/secure," that's `ship`, not a migration.)

1. **Consult the gates** — [`../../reference/dep-gates.md`](../../reference/dep-gates.md) for current known-good targets before bumping across a major.
2. **Migrate** deliberately, one major at a time; run the build/lint after each.
3. **If you discover a moved gate** (e.g. ESLint 10 is now stable as the known-good target), **propose** updating `dep-gates.md` and ask for confirmation. Gates never move silently.

This is the absorbed `raycast-extension-modernizer` content — but reframed as the *rare, gated* case, not routine freshness.

## Intent 3 — House-style audit fix (the `npm audit fix` for code)

The retrofit pass: take an extension that works (a fork you're contributing to, or your own legacy one) and bring it up to House Style. This is the muscle the old modernizer had — iterative, mechanical, "sweep the whole extension and bring it up to standard" — except the target is **code patterns**, not dependency versions.

**Sources of truth:** [`../../reference/house-style.md`](../../reference/house-style.md) + [`../../reference/keyboard-conventions.md`](../../reference/keyboard-conventions.md).

**The loop:**

1. **Load** `house-style.md`. Take its `[build]` / `[both]` / `[lint]` entries (the mutating ones). Skip `[verify]`-only entries — those are `ship`'s read-only assertions.
2. **Scan** the codebase for each rule's governed pattern:
   - Failure toasts → grep `Toast.Style.Failure`; flag any without a Copy-Error action.
   - Shortcuts → find every `<Action>` with an inline `shortcut={{...}}`; map by semantics (see `keyboard-conventions.md`).
   - Web requests → grep `fetch`/`axios`/`node-fetch`/`useFetch`; if present, check for `@chrismessina/raycast-logger`.
   - `[lint]` rules (hand-defined `Preferences`/`Arguments`, `any` casts) — fix if found, but the durable home is ESLint; you're the backstop.
3. **Present a worklist** of violations before mutating en masse. Fix iteratively; show diffs.
4. **Apply the keyboard transformation contract** exactly (semantics over combo; drop platform-specific inline objects; fix imports; re-check the conflict invariant after rewriting — a remap can create a new collision).
5. **Build + lint** to confirm nothing broke.
6. **Hand forward to `ship`** when clean — `ship` re-runs the read-only audit as the gate.

> **Forked-extension caveat:** when retrofitting a fork you're contributing *upstream*, House Style is *your* convention — be judicious about imposing personal patterns (e.g. `@chrismessina/raycast-logger`) on someone else's extension you don't own. Apply universally-good fixes (Copy-Error, `Common` shortcuts, no `any`) freely; flag personal-dependency additions for the user's call before adding them to a non-`chrismessina`-authored extension.

---

## House Style (applies to all three intents)

Every code change here must conform to House Style. The canonical, tagged checklist is [`../../reference/house-style.md`](../../reference/house-style.md). Highlights you'll hit constantly:

- **Every `Toast.Style.Failure` gets a "Copy Error" action** (copies the message to clipboard).
- **Web-request extensions use `@chrismessina/raycast-logger`** for structured logging.
- **Shortcuts use `Keyboard.Shortcut.Common`** by semantics — see [`../../reference/keyboard-conventions.md`](../../reference/keyboard-conventions.md).
- **Never hand-define `Preferences`/`Arguments`** — use the auto-generated ambient types. **No `any` casts.**

## Hands off

→ `ship` when the change is done and builds clean. `ship` runs the read-only house-style audit, dep hygiene, weeding, compliance, PR, and cleanup. If it bounces back with code-level feedback, you're up again.

## Gotchas

- **Don't conflate hygiene with migration.** "Update my deps" is ambiguous — non-breaking refresh is `ship`; a major migration is here. If unsure which the user means, ask before bumping.
- **A semantic shortcut remap can introduce a conflict.** Always re-verify the ActionPanel conflict invariant *after* rewriting, not just before.
- **`[lint]` rules are not your job to fully own.** Fix what you find, but push the durable enforcement to ESLint — don't turn `develop` into a hand-rolled linter.
- **Forks aren't yours.** Be careful adding personal dependencies to extensions authored by someone else (see the forked-extension caveat).
- **New files won't show in `git diff`.** Cross-reference `git status` when reviewing what you changed.
