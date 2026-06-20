# Design: `raycast-extensions` plugin

**Date:** 2026-06-19
**Status:** Design — review incorporated (2026-06-19); open Q#1 locked. One open item (marketplace mechanics, deferred to implementation). Ready to author pending House Style enumeration.
**Home repo:** `chrismessina/raycast-extension-workflows`

---

## Problem

Chris's Raycast-extension tooling is scattered and ambiguously bounded:

- **3 real skills** exist: `raycast-extension-modernizer` (deps/tooling), `raycast-extension-review` (fetch Store guidelines, lives in `~/.agents/skills/` via symlink), `raycast-script-creator` (script-commands — a *different artifact*, out of scope here).
- **2 phantom skills** are *referenced but never authored*: `raycast-extension-builder`, `raycast-extension-publisher`. The modernizer's description points users at both — dead cross-references.
- **No skill owns the git/fork/PR-lifecycle layer**, so facts land in the wrong place (the squash-merge branch-cleanup gotcha got wedged into `modernizer`, where it doesn't belong).

The recurring failure mode: **skills with ambiguous overlap.** Skills trigger on description match, so role-keyed names ("builder" vs "publisher" vs "review") collide because they all touch the same files. Two fire, or neither does.

## Insight that resolves it

**Key the skills to lifecycle *stages* (verbs), not ownership/roles (nouns).** A stage has a clean entry and exit, so triggers don't overlap. "Update deps" can't fire when you mean "address review feedback."

The lanes Chris originally named — (1) update my own extensions, (2) publish net-new, (3) fix/improve others' — turn out to share almost all mechanics. They differ on two **throughlines** that cut *across* every stage, not on the stages themselves.

## Stages (the "garden" lifecycle)

1. Ideate / scaffold net-new (Raycast-API-aware)
2. Dep work — **split by risk** (see "Dep work splits by risk" below):
   - 2a. Hygiene — `npm outdated` + `npm audit fix`, moderate non-breaking bumps (low-risk, routine)
   - 2b. Modernization — deliberate major migrations (Node bump, ESLint 10, flat-config) behind gate-checks
3. Weeding — metadata/screenshots/README/CHANGELOG hygiene
4. Develop / refactor feature code
5. PR prep & submission
6. Review & feedback cycle
7. Post-merge cleanup

## Throughlines (constraints, not stages)

- **A — NEVER sync the entire Raycast monorepo.** Sparse-checkout discipline; hard safety rail.
- **B — Mirror MY extensions to my own GitHub.** The `chrismessina/raycast-{name}` standalone-repo pattern. **Already largely automated** (see below). Applies only to extensions where `package.json` `author` is `chrismessina`.

---

## Architecture: one plugin, 3 skills + reference library

Container: **`raycast-extensions`** plugin, authored inside `raycast-extension-workflows`.

### Skills

| Skill | Stages owned | Fires when | Hands off | Sparse-checkout enforcement |
|---|---|---|---|---|
| **`scaffold`** | 1 — ideate + scaffold net-new | "create/start a **new** extension" | → `develop` once files exist | ✅ Never clones monorepo — scaffolds in a standalone dir |
| **`develop`** | 2b + 4 — **modernization** (deliberate major migrations) **+** feature dev + refactor (absorbs today's `modernizer`) **+ house-style audit fix** (retrofit existing code to House Style) | "change code, do a **major** dep migration, or **bring an existing/forked extension up to my House Style**" | ⇄ `ship` (forward when change done; receives back when review feedback needs code) | ✅ Consults `reference/sparse-checkout-discipline.md` before any monorepo op |
| **`ship`** | 2a + 3 + 5 + 6 + 7 — pre-flight (**dep hygiene** + **house-style audit** + weed) → Store-compliance fetch → PR prep + title → review-feedback cycle → post-merge cleanup | "get it into `raycast/extensions` and clean up" | ⇄ `develop` (back when feedback needs code) / → done | ✅ PR prep uses sparse checkout; mirror sync via GitHub API (no clone) |

**Seam rules (overlap prevention):**

- **`scaffold` vs `develop`** — binary on existence: `scaffold` = *no extension exists yet* (create folder/manifest/first command); `develop` = *it exists, I'm changing it*.
- **`develop` vs `ship`** — `develop` changes code (feature, refactor, major dep migration, **or house-style audit fix**); `ship` does NOT change code behavior (it runs *non-breaking* dep hygiene, the read-only *house-style audit*, weeds metadata, gates compliance, submits, cleans up).
- **`ship` → `develop` handoff (two-way)** — if Store review feedback (or a failing house-style audit at ship-time) requires **code** changes (not just metadata/screenshots), `ship` hands back to `develop` *with the feedback context*. `develop` makes the change, then hands forward to `ship` again for re-submission. The arrow is bidirectional.
- **Weeding + dep hygiene + house-style audit fold into `ship` as a pre-flight checklist** (not their own skills — Chris confirmed he'd never run `/weed` or a bare bump standalone): did we add a command/view → screenshots stale? README current? CHANGELOG date block present? `npm outdated` clean? `npm audit fix` applied? **house-style audit clean (every error toast has copy-logs action; shortcuts use `Keyboard.Shortcut.Common`; no shortcut conflicts within an ActionPanel)?**
- **House-style audit vs audit fix (the `npm audit` analogy)** — `ship` runs the **audit** (read-only: reports violations, asserts no shortcut conflicts — the twin of `npm audit`); `develop` runs the **audit fix** (mutating: sweeps existing code and retrofits it to House Style — the twin of `npm audit fix`). Same source of truth (`reference/house-style.md` + `reference/keyboard-conventions.md`), two consumers. This is the "modernizer feel" applied to *code patterns*, not deps.
- **`raycast-extension-review` dissolves** — its job ("fetch authoritative Store docs and audit") becomes `ship`'s pre-submission compliance gate + a `reference/` pointer. No longer a standalone trigger.

### Trigger phrases (quick reference)

| User says | Fires |
|---|---|
| "create / start / scaffold a **new** Raycast extension" | `scaffold` |
| "build / add / change / refactor [feature]" (existing ext) | `develop` |
| "migrate to ESLint 10 / Node 22 / flat config" | `develop` (modernization) |
| "bring this fork up to my House Style" / "fix the toasts & shortcuts to match my conventions" | `develop` (**house-style audit fix**) |
| "submit / publish / ship to the Store" | `ship` |
| "address review feedback" (metadata / screenshots) | `ship` |
| "address review feedback" (code changes) | `ship` ⇄ `develop` |
| "update my deps" (vague) | Ask: routine refresh (`ship` hygiene) or major migration (`develop`)? |

### Dep work splits by risk (the key seam)

"Update my deps" is two different jobs that today's `modernizer` conflates — and that conflation is what drags a quick refresh into a major-version debate. Split by **risk/intent**:

- **Hygiene (low-risk, routine)** → `ship` pre-flight. `npm outdated` + `npm audit fix`, moderate **non-breaking** bumps to keep packages current and secure. Run-it-and-move-on; no major-version back-and-forth. Same mood as metadata weeding — it's gardening, not engineering. Trigger: *"keep my packages current/secure."*
- **Modernization (deliberate, gated)** → `develop`. Major-version migrations: Node bump, ESLint 9→10, flat-config migration, `@raycast/api` breaking changes. Requires judgment and consults `reference/dep-gates.md` (below) for current known-good targets. Trigger: *"migrate to ESLint 10 / the new Node."*

This makes the trigger unambiguous: refresh-and-secure never accidentally invokes a migration, and a migration is always an explicit, gated choice.

### `scaffold` ideation

Reuse `superpowers:brainstorming` for idea-shaping, then apply a **Raycast-API constraints overlay** (command vs view vs menu-bar vs AI-tool; API limits/capabilities). Do **not** rebuild brainstorming.

### Reference library (`reference/`)

Shared docs — facts that belong to no single stage, cited by multiple skills:

- `sparse-checkout-discipline.md` — **throughline A**. The never-full-clone rule; how the sparse extensions-sparse checkout works. Cited by `develop` + `ship`.
- `my-extensions-mirror.md` — **throughline B**. Points at the **existing GitHub Actions automation in this repo** (see below) + the naming convention + `UPSTREAM_EXT_DIR` exceptions. Does NOT re-document; links to `../README.md`.
- `store-guidelines.md` — fetch-latest behavior absorbed from old `review` skill (the two developer-docs URLs).
- `pr-and-cleanup.md` — PR title convention (`Update <Title> extension` default; `[Title] <fix>` when one change dominates; no Conventional Commits) **+ the squash-merge / branch-sweep gotcha**, relocated out of `modernizer`.
- `dep-gates.md` — **current known-good dependency targets**, consulted (and updated) by `develop`'s modernization routine: Node version the Raycast SDK currently expects, ESLint major (flat-config CJS default today; watch for 10.0), `@raycast/api` / `@raycast/utils` baseline, `@types/node` / `@types/react` major-tracking notes. The home for "have the gates moved?" so it doesn't drift inside prose. Hygiene (in `ship`) never consults this — it only does non-breaking bumps; gates matter only when crossing a major. **Maintenance:** when a modernization run discovers a new known-good target (e.g. ESLint 10 ships stable), `develop` **proposes** the gate update and asks for confirmation before editing — gates never move silently.
- `house-style.md` — **Chris's house conventions for every extension** (the third category: not a stage, not a throughline — a personal standards checklist). See the seed appendix below for the rules captured so far. Each entry tagged:
  - **`[build]`** — apply while writing (UI/UX patterns; judgment calls). `develop` build-mode only.
  - **`[verify]`** — mechanically checkable presence/absence; a `ship` pre-flight audit assertion.
  - **`[both]`** — applied at build *and* audited at ship.
  - **`[lint]`** — *should be an ESLint rule* (enforced on every save in the shared config); the house-style audit is only the **backstop** for forks that don't yet carry the rule. Keeps the audit fast — it doesn't re-implement the linter.

  Consumed at **build time** by `develop` (apply inline) and at **pre-flight** by `ship` (audit: did we?). Single source of truth, two consumers — same pattern as `dep-gates.md`. Points at `keyboard-conventions.md` for the shortcut sub-rules.
- `keyboard-conventions.md` — the **`Keyboard.Shortcut.Common` semantic map** (17 members, verified against `docs/api-reference/keyboard.md` 2026-06-19) + disambiguation rules (Copy vs CopyName vs CopyPath vs CopyDeeplink; Remove vs RemoveAll; MoveUp/Down; etc.) `[build]` + the **conflict invariant** `[verify]` (*within a single resolved ActionPanel — including nested Submenus and actions composed from other components — no two actions resolve to the same shortcut*) + the **audit-fix transformation contract** (prefer semantics over current combo; drop platform-specific inline objects for the platform-aware constant; extend the existing `@raycast/api` import, no unused imports; leave truly-custom shortcuts untouched). Carries a **"last verified" date** + cites the authoritative doc so the snapshot can't silently drift (the `dep-gates.md` drift-guard pattern). The semantic map is `develop`'s build-time + audit-fix ruleset; the conflict invariant is `ship`'s mechanically-gateable check.

---

## Critical discovery: throughline B is already automated

`raycast-extension-workflows` already contains GitHub Actions that automate the **upstream → standalone mirror** direction:

- `dispatch-sync.yml` (in the fork `chrismessina/extensions`): on push to `main` touching `extensions/*/package.json`, derives the target `chrismessina/raycast-{name}` repo and fires `repository_dispatch`.
- `sync-from-upstream.yml` (in each standalone repo): receives the event, fetches the extension's files from the monorepo **via GitHub API** (no full clone — honors throughline A), commits to its `main`.
- Naming convention: target = `chrismessina/raycast-{name}` unless `name` already starts with `raycast-`. Mismatches handled by `UPSTREAM_EXT_DIR` env (e.g. `reader-mode` → `raycast-reader`).
- 7 repos already wired: `raycast-store-updates`, `raycast-fathom`, `raycast-at-profile`, `raycast-digger`, `raycast-get-app-icon`, `raycast-secret-browser-commands`, `raycast-reader`.

**Implication for `ship`:** the mirror updates *itself* after merge. `ship` must **not** manually push to the standalone repo. Its post-merge mirror step is reduced to: (a) confirm `author: chrismessina` provenance, (b) verify the dispatcher fired / note sync lag, (c) if the extension is yours but **not yet wired** for sync, point to the "Adding sync to a new extension repo" runbook in `README.md`. This is the "past-Chris built it, current-Chris forgot" gap the reference library closes.

**Mirror-sync verification (`author: chrismessina` only):**
- Confirm the dispatcher fired (Actions tab in `chrismessina/extensions`).
- Expected sync lag < 5 min; flag if > 10 min.
- If sync fails or lags past bound → point to the troubleshooting runbook in `reference/my-extensions-mirror.md`.
- If the extension is yours but not yet wired → point to "Adding sync to a new extension repo" in `README.md`.

---

## What we explicitly do NOT build (YAGNI)

- No re-implementation of mirror-sync — the Actions own it.
- No `weed` skill — folds into `ship`.
- No standalone `review` skill — dissolves into `ship` + reference.
- No Raycast-specific brainstorm engine — reuse `superpowers:brainstorming` + overlay.
- No standalone house-style skill — `audit` folds into `ship` pre-flight, `audit fix` into `develop`; the conventions live in `reference/`.
- `raycast-script-creator` is untouched (different artifact: script-commands, not extensions).

## Success criteria

- [ ] No more "which skill do I use?" confusion — stage triggers are unambiguous.
- [ ] Dep work no longer conflates hygiene and migration.
- [ ] House Style is applied at build time *and* enforced at pre-flight, from one source of truth (no drift between "write" and "check").
- [ ] A forked extension can be brought up to House Style in one `develop` audit-fix pass (toasts retrofitted, shortcuts normalized to `Common`, no ActionPanel conflicts).
- [ ] Mirror-sync facts live in one place, not scattered across skills.
- [ ] `raycast-extension-review` is fully absorbed (no orphaned skill).
- [ ] Sparse-checkout discipline is enforced (table column), not just documented.

## Open / deferred

- Plugin marketplace registration mechanics (local install vs published marketplace entry) — decide at implementation time.

---

## Decisions locked during brainstorming

- Mechanical stages, not ownership lanes, drive the seams.
- One plugin, kept tight, is the right container (vs scattered skills or 3 lane-skills).
- 3 skills: `scaffold`, `develop`, `ship`.
- **Dep work splits by risk:** hygiene (non-breaking bumps, `npm outdated` + `audit fix`) → `ship` pre-flight; modernization (major migrations) → `develop`, gated by `reference/dep-gates.md`. "Modernizing" is reframed as the *rare major-migration* case, not routine freshness.
- Weeding → pre-flight inside `ship`. `review` → merged into `ship`.
- Mirror-sync → conditional `ship` step keyed on `author: chrismessina`; leverages existing Actions, does not reimplement.
- `scaffold` reuses `superpowers:brainstorming` + Raycast overlay.
- Authored inside `raycast-extension-workflows`.
- **House Style is a third category** (not stage, not throughline) — a personal standards checklist living in `reference/house-style.md` (+ `keyboard-conventions.md`), entries tagged `[build]`/`[verify]`/`[both]`, consumed by both `develop` (build) and `ship` (pre-flight).
- **House-style audit / audit fix** = the `npm audit` / `npm audit fix` analogy for code patterns: read-only audit in `ship`, mutating fix in `develop`. Retrofitting a forked extension fires `develop`'s audit fix.
- **Keyboard conventions** = map ad-hoc shortcuts to `Keyboard.Shortcut.Common` by *semantics*; enforce no-conflict-within-an-ActionPanel as a mechanical `ship` gate. Snapshot verified current 2026-06-19; carries a "last verified" date.
- **`modernizer` is absorbed fully into `develop`** (open Q#1 locked) — leave a deprecation note in the old skill file pointing at the plugin; no parallel implementation.

---

## Appendix: House Style seed (working list)

> The content `reference/house-style.md` will be built from. **In progress — Chris is still enumerating.** Tags: `[build]` / `[verify]` / `[both]` / `[lint]` (see reference entry above).

### Prohibitions

- **`[lint]` Never hand-define `Preferences` or `Arguments` types.** Rely on Raycast's auto-generated ambient types from `package.json`. Use `const preferences = getPreferenceValues<Preferences>();` with the *generated* `Preferences` — never a locally-declared `interface Preferences` / `interface Arguments`, and never pass a hand-rolled type param to `getPreferenceValues()`. *Audit (backstop):* grep for a local `interface Preferences|Arguments` declaration. *Durable home:* ESLint rule.
- **`[lint]` No `any` type casting.** No `as any`, no `: any`. *Durable home:* `@typescript-eslint/no-explicit-any` in the shared config; audit is the backstop for un-linted forks.

### Required patterns

- **`[both]` Every failure toast carries a "Copy Error" action.** When showing `Toast.Style.Failure`, attach a `primaryAction` titled "Copy Error" that copies the error message to the clipboard. *Audit:* grep every `Toast.Style.Failure` → assert an accompanying copy-error action. Canonical form:

  ```ts
  catch (error) {
    logger.error("Token generation failed", error);
    const errorMessage = error instanceof Error ? error.message : "Unknown error";
    await showToast({
      style: Toast.Style.Failure,
      title: "Failed to generate token",
      message: errorMessage,
      primaryAction: {
        title: "Copy Error",
        onAction: async () => {
          await Clipboard.copy(errorMessage);
        },
      },
    });
  }
  ```
  *(The snippet Chris pasted had a paste-collision — duplicated `showToast`/`message` lines; this is the de-duplicated canonical form.)*

- **`[both]` (conditional) Structured logging via `@chrismessina/raycast-logger`** — for extensions that make web requests. *Condition:* extension fetches (grep `fetch` / `axios` / `node-fetch` / `useFetch`). *If yes:* `@chrismessina/raycast-logger` must be a dependency and imported (the `logger` used in the Copy-Error pattern above). Does NOT apply to extensions with no network calls — the audit must check the condition first or it mis-fires.

- **`[both]` Keyboard shortcuts → `Keyboard.Shortcut.Common`** by semantics; no conflicts within an ActionPanel. See `reference/keyboard-conventions.md`.

> **Still to enumerate** (Chris has more): _[append as they arrive]_
