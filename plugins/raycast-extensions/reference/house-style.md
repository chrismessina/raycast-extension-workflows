# House Style

Chris's personal conventions for every Raycast extension — the "third category": not a lifecycle *stage*, not a *throughline* constraint, but a standards checklist. Applied at **build time** by `develop` and audited at **pre-flight** by `ship`. Single source of truth, two consumers.

> **Living document.** Rules here are earned from Chris's actual fleet, not invented — each cites real fleet evidence: established adoption, a concrete defect it prevents, or a specific gap worth closing (a few are grounded in a gap rather than existing adoption, and say so). Append as new ones prove out; keep each tagged. Emerging-but-not-yet-established candidates are parked in [Still to enumerate](#still-to-enumerate) rather than promoted early.

## Tags

- **`[build]`** — apply while writing (UI/UX patterns, judgment calls). `develop` build-mode only.
- **`[verify]`** — mechanically checkable presence/absence; a `ship` pre-flight audit assertion.
- **`[both]`** — applied at build *and* audited at ship.
- **`[lint]`** — *should be an ESLint rule* (enforced on every save via the shared config). The house-style audit is only the **backstop** for forks that don't yet carry the rule — it does not re-implement the linter.

`develop`'s **house-style audit fix** (the `npm audit fix` twin) reads `[build]`/`[both]`/`[lint]` entries and brings existing code into conformance — mechanically where the rule is a clear rewrite (`[lint]`/most `[both]`), and as a **judgment call** where the `[build]` entry is a recommendation rather than a mandate (it says so in the rule). `ship`'s **house-style audit** (the `npm audit` twin) reads `[verify]`/`[both]` entries and reports/asserts — read-only. Anything it finds that needs code → hand to `develop`.

### Why these rules don't live in Prettier

A recurring question: can these be enforced via `.prettierrc` for determinism?
Mostly **no** — the layers don't overlap:

- **Prettier** only reshapes what it can derive from the AST with no notion of
  *meaning*: quotes, semicolons, width, indentation, trailing commas. **Zero**
  house-style rules are pure formatting.
- **ESLint** is where semantic rules belong — "no `any`", "no hand-defined
  `Preferences`", the `instanceof Error` ternary. That's what the `[lint]` tag means:
  the rule's durable home is a lint rule, and the audit is only the backstop for forks
  that don't carry it yet. The fleet's `@raycast/eslint-config` is the shared base.
- **The house-style audit** (`develop`/`ship`) covers the rest — relationships Prettier
  and off-the-shelf ESLint can't see (Copy-Error toast pairing, `canAccess(AI)` gating,
  `supportPath`-is-internal).

**`.prettierrc` convention.** Extensions use the Raycast-scaffold standard
`{"printWidth": 120, "singleQuote": false}` — keep it identical across the fleet
(this repo's own config deliberately differs: it's docs/YAML, not extension TS, and
excludes Markdown so hand-authored prose isn't reflowed).

**Import ordering** is the one formatting-shaped candidate. It's *not* a rule (adoption
was too split — see [Still to enumerate](#still-to-enumerate)), but it can be made
deterministic with `@ianvs/prettier-plugin-sort-imports`. Piloted on `reader`
(2026-07-24): sorts cleanly, `tsc` + `ray lint` both pass (Raycast's bundled Prettier
accepts the reordered output), ~27/42 files reflow one-time. Viable if promoted; left
opt-in for now.

---

## Prohibitions

### `[lint]` Never hand-define `Preferences` or `Arguments` types

Rely on Raycast's **auto-generated ambient types** from `package.json` (commands + preferences). Use:

```ts
const preferences = getPreferenceValues<Preferences>();
```

…where `Preferences` is the *generated* ambient type — never a locally-declared `interface Preferences` / `interface Arguments`, and never a hand-rolled type param passed to `getPreferenceValues()`.

- **Durable home:** ESLint rule (custom or config).
- **Audit backstop:** grep for a local `interface Preferences|Arguments` declaration, or a `getPreferenceValues<LocalType>()` where `LocalType` is defined in-file.

### `[lint]` No `any` type casting

No `as any`, no `: any`.

- **Durable home:** `@typescript-eslint/no-explicit-any` in the shared config.
- **Audit backstop:** grep `\bas any\b` / `:\s*any\b` for un-linted forks.

### `[lint]` Unwrap unknown catch values with the `instanceof Error` ternary

A `catch` value is `unknown`. Stringify it with the exact guard — never touch
`error.message` unguarded, and don't spin up a one-off `getErrorMessage` helper:

```ts
const errorMessage = error instanceof Error ? error.message : String(error);
```

This is Chris's standard across the fleet (17 of 21 self-authored extensions —
e.g. `raycast-digger/src/hooks/useFetchSite.ts:42`,
`raycast-ios-apps/src/ipatool.ts:328`). It pairs directly with the Copy-Error
toast below, whose `errorMessage` is produced this way.

- **Durable home:** ESLint (`@typescript-eslint/no-unsafe-member-access` catches the
  unguarded `.message`; a custom rule can enforce the exact ternary).
- **Audit backstop:** grep `catch (` blocks that reference `.message` without an
  accompanying `instanceof Error`.

### `[both]` Typecheck with `tsc --noEmit` — `ray build` does NOT typecheck

`ray build` (esbuild) and `ray lint` (ESLint) **strip/skip types without checking
them** — type errors compile and lint clean, then fail in editors and external
reviewers running `tsc`. So passing build + lint is **not** evidence the code
typechecks.

- **Always run `npx tsc --noEmit` as the real type gate** before claiming a change
  is done, alongside build + lint. Treat a non-zero `tsc` exit as a failure even if
  `ray build` succeeded.
- Common trap: a Raycast hook with multiple overloads (e.g. `usePromise` /
  `useCachedPromise`) silently resolving to the **paginated** overload, inferring
  `data` as `any[]`. Annotate the fetcher's return type
  (`(q: string): Promise<YcResult<T>> => …`) to pin the intended overload.
- TS does **not** carry an early-return narrowing into nested closures: after
  `if (!x) return`, a `const`-captured `string | null` is still `string | null`
  inside a later `async function`. Re-bind to a typed const (`const v: string = x`)
  rather than reaching for `as` / `!`.

---

## Required patterns

### `[both]` Every failure toast carries a "Copy Error" action

When showing `Toast.Style.Failure`, attach a `primaryAction` titled **"Copy Error"** that copies the error message to the clipboard.

- **Audit:** grep every `Toast.Style.Failure` → assert an accompanying copy-error action.
- **Canonical form:**

```ts
catch (error) {
  logger.error("Token generation failed", error);
  const errorMessage = error instanceof Error ? error.message : String(error);
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

### `[both]` Empty/error state copy: short title, one-line description, steps in the actions

`List.EmptyView` (and `Toast`) copy follows one shape: an icon, a short imperative
title, and a **single-sentence** description. Multi-step guidance goes in the
`actions`, not the description.

**Why it's a hard rule, not a preference:** `List.EmptyView`'s `description`
**collapses newlines** — a multi-line string renders as one run-on line. This is
documented in Chris's own code
(`raycast-airbuddy/src/components/error-views.tsx:43-44`: *"List.EmptyView's
`description` collapses newlines — … Keep every description to ONE short line and
put the steps in the actions."*). A long or multi-line description is therefore a
defect, not a style nit.

- **Error `Detail` screens** use the heading form `` `# Error\n\n${message}` ``
  (`raycast-fathom/src/search-meetings.tsx:335`,
  `raycast-reader/src/views/ArticleReaderView.tsx:120`,
  `raycast-tesla-energy/src/view-solar-production.tsx:244`), where `message` is the
  `instanceof Error` string from the prohibition above.
- **Audit:** two mechanical checks — (a) flag any `List.EmptyView` / `EmptyView`
  `description` whose string literal contains an explicit `\n` (the objective defect:
  collapsed newlines), and (b) flag any error `Detail` that doesn't use the `# Error`
  heading form. Overall description *length* is a `[build]` judgment, not a hard audit
  assertion.

### `[build]` Toggle copy states the resulting direction (on/off), never a bare "Toggled"

When a command **toggles** a setting, the success copy must say **which way it went** —
the resulting state — not merely that a toggle happened. "Toggled" (or a bare status
adjective like "Not Floating") makes the user open the app to find out what they just
did, which defeats the point of the command.

- **State the result as on/off (or the equivalent named state):** `"Microphone Input
  On"` / `"Microphone Input Off"`, `"Desktop Widgets Floating: On"` / `"…: Off"`,
  `"Audio Input Lock On"` / `"Audio Input Lock Off"`. A multi-value setting names the
  resulting value instead (`"Spatial Audio: Fixed"`). All five are real airbuddy toggle
  toasts (`raycast-airbuddy/src/toggle-*.ts`).
- **Read the real post-state when the API exposes it.** Prefer reading the setting's
  actual value after the toggle (poll the readable property) over assuming the direction
  from a locally-tracked "was it on before" guess — a guess silently desyncs if the
  setting is changed from the app's own UI between calls.
- **When the direction is genuinely unknowable** (no readable property anywhere in the
  API, and no reliable local state), do **not** fabricate a direction — say so, and
  point the user at where to confirm (`message: "Check <app> to confirm the current
  state."`). Honesty beats a lie that reads as certainty. *(This was airbuddy's stopgap
  for `toggle desktop widgets` / `toggle audio input lock` before AirBuddy 913 added
  readable `desktopWidgetsFloating` / `audioInputLockEnabled` properties — once the
  property existed, the toasts were upgraded to name the real state.)*
- **The defect this closes:** a "Desktop Widgets Not Floating" toast (airbuddy, pre-fix)
  reads as a passive status label, ambiguous about whether the command succeeded or what
  it changed. Naming the direction as a result (`Floating: Off`) resolves it.
- **Audit:** `[build]` judgment — grep success-toast titles on `toggle-*` commands for a
  bare `"Toggled"` / `"… Toggled"` with no on/off or named result, and flag it. Not a
  hard `[verify]` assertion (the "genuinely unknowable" carve-out is a judgment call).

### `[build]` Count-bearing copy uses correct singular/plural agreement — never `item(s)`

Any user-facing string that interpolates a count must agree grammatically with that
count across **all three** cases: zero, one, and many. `"1 items"` and `"No devices
found"` sitting next to `"3 device found"` are defects. The lazy escape hatches —
`"${n} item(s)"`, `"${n} device(s)"`, always-plural `"${n} items"` — are prohibited in
copy the **user reads** (they're fine in `logger.*` debug output, which no user sees).

- **The shape:** three-way, e.g. `n === 0 ? "No devices found." : n === 1 ? "1 device
  found." : \`${n} devices found.\``. Don't hand-inline that ternary five times — **this
  helper now exists** as `countOf(n, "device")` / `countOf(n, "match")` in
  `@chrismessina/raycast-kit` (see the conditional kit rule below). It handles the
  irregulars the hand-rolled version got wrong (`match`→`matches`, `city`→`cities`,
  `person`→`people`, `series`→`series`) and thousands separators.
- **Zero has its own copy.** `"No devices found."` reads better than `"0 devices
  found."`; use the worded-negative form for the empty case (it also matches the
  `List.EmptyView` empty-state titles this fleet already writes — `"No Known Devices"`,
  `"No Headsets Nearby"` in `raycast-airbuddy/src/list-devices.tsx`).
- **The defects this closes (real fleet):** `raycast-craft/src/tools/add-collection-items.ts:63`
  (+ `update-`/`delete-collection-items.ts`) render `${input.items.length} item(s)`;
  `raycast-fathom/src/view-action-items.tsx:71` and `raycast-at-profile/src/history.tsx:188`
  render an unconditional `${n} items` that says `"1 items"` at count 1. (Terse
  `List.Section` subtitles are the softest case — but the pattern is fleet-wide and the
  fix is cheap.)
- **Audit:** the greppable subset is a `[verify]`-grade check — grep user-facing copy
  for the literal `(s)` / `(es)` pluralization crutch and for `length}\s*<plural-noun>`
  templates with no adjacent `=== 1` guard. General agreement across a computed message
  stays a `[build]` judgment.

### `[both]` (conditional) Structured logging via `@chrismessina/raycast-logger`

**Condition:** the extension makes web requests (grep `fetch` / `axios` / `node-fetch` / `useFetch`).

**If yes:** `@chrismessina/raycast-logger` must be a dependency and imported (the `logger` used in the Copy-Error pattern above). Does **not** apply to extensions with no network calls — the audit must check the condition first, or it mis-fires on offline extensions.

**Corollary — the debug preference name is fixed.** The logger reads
`getPreferenceValues().verboseLogging` internally, so an extension that adopts it
**must** expose a preference named **exactly `verboseLogging`**, type `checkbox`.
This is not a free naming choice — a differently-named toggle silently does nothing.
(Present in all 7 logger-using extensions: `bookface`, `digger`, `fathom`,
`ios-apps`, `parallel-web-tools`, `reader`, `tesla-energy`.)

### `[both]` (conditional) Prefer `@chrismessina/raycast-kit` for failure toasts and count copy

**Condition — all three must hold:**

1. The extension is **self-authored** (`package.json` `author: chrismessina`), AND
2. it is **already being changed** for some other reason, AND
3. it has a `Toast.Style.Failure`, an `instanceof Error` unwrap ternary, or count-bearing copy.

**Never on a fork you don't own** — this is a personal dependency, the same call as the
logger. And **never as a standalone change**: sorting imports or swapping a helper is not
worth a Store reviewer's time on its own. Bundle it with substantive work or skip it.

**Why the rule exists.** Three rules above this one — the Copy-Error toast, the
`instanceof Error` ternary, and count agreement — are enforced today by an agent
remembering to grep. The 2026-07-25 fleet audit measured what that's worth:

| Rule | Hand-written | Repos | Compliance |
|---|---|---|---|
| `Toast.Style.Failure` | 124 | 20 | — |
| …carrying a Copy-Error action | **26** | **9** | **~20%** |
| `instanceof Error ? …` ternary | 98 | 16 | — |
| Count-bearing copy | 34 | 11 | — |

`raycast-ios-apps` is the proof: **51 failure toasts, zero Copy-Error actions**, because it
calls `showFailureToast` from `@raycast/utils` 42 times — which has no copy action at all.
The house-style rule and the ergonomic path point in opposite directions, and the ergonomic
path wins. A dependency inverts that: the compliant call becomes the shortest one.

**The mapping:**

```ts
import { showError, getErrorMessage, countOf } from "@chrismessina/raycast-kit";

// BEFORE — Copy-Error block hand-written (or, more often, omitted)
const errorMessage = error instanceof Error ? error.message : String(error);
await showToast({ style: Toast.Style.Failure, title: "Failed to Load", message: errorMessage,
  primaryAction: { title: "Copy Error", onAction: async () => { await Clipboard.copy(errorMessage); } } });
// AFTER
await showError(error, { title: "Failed to Load" });

// BEFORE — says "1 items" at count 1
`${n} items`  /  `${n} item(s)`
// AFTER
countOf(n, "item")                      // "0 items" · "1 item" · "7 items"
countOf(n, "item", { zero: "No items" }) // worded zero, per the count rule above
```

`showError` swallows `AbortError` by default — a user typing the next keystroke cancels the
in-flight request, and that was never a failure worth toasting. Pass `ignoreAbort: false`
where you do want it surfaced.

**`getErrorMessage` is strictly better than the ternary it replaces**, which is why the
`[lint]` ternary rule above stays satisfied by it. Validated against real fleet error shapes:
an `itunes-api`-style `{status, statusText}` object, a nested `{error:{message}}` JSON API
response, and a thrown plain object were all rendering **`"[object Object]"`** through the
bare ternary. 4 of 7 real shapes produce better copy.

**Pure-TS subpaths.** `@raycast/api` has no loadable runtime outside Raycast, so
`getErrorMessage` / `countOf` are importable standalone —
`@chrismessina/raycast-kit/errors`, `@chrismessina/raycast-kit/plural`. Use those in tests
and scripts; the root export pulls in the toast module.

**Audit posture — REPORT, never block.** `ship`'s pre-flight notes non-adoption as an
opportunity and moves on. The hard gate stays on the *underlying* rules (a failure toast
without a Copy-Error action fails the audit whether or not the kit is involved) — hand-rolling
the compliant block is still perfectly correct. What fails is a missing copy action, not a
missing dependency.

**Out of scope, deliberately.** The same audit considered and **rejected** date, text, and
number helpers: eight `formatDate` implementations across the fleet had eight different
signatures (`string`, `number`, `Date|string`, `string+Period`, `string|undefined`) — a shared
name, not a shared behavior. `truncate` looked fleet-wide at 79 uses until 40 proved to be in
`digger` alone. Generic helpers belong in `@raycast/utils`, already imported by 19 of 24
extensions. Don't grow the kit past rules that would otherwise depend on memory.

### `[both]` Keyboard shortcuts: `Common` first, platform-explicit only when cross-platform

Two independent decisions. Don't conflate them. (Full ruleset + conflict invariant + audit-fix contract: see [`keyboard-conventions.md`](./keyboard-conventions.md).)

**Decision 1 — Does a `Keyboard.Shortcut.Common` member match the action's semantics?**

- **Yes → use the `Common` constant.** Always. It is already platform-aware, so it is correct on every platform with no extra work. Never hand-roll a shortcut that `Common` already covers, and never wrap a `Common` constant in a platform-explicit object.
- **No → a custom shortcut is correct and expected.** The `Common` set is 17 members; it does not cover everything (no "switch mode", "toggle setting", "connect"). Do not force a bad semantic match — a wrong `Common` is worse than an honest custom shortcut.

**Decision 2 — For custom shortcuts only: what does `platforms` in `package.json` say?**

- **`platforms` ABSENT** → treat as **macOS-only**. That is Raycast's historical default (the field postdates Windows support), so an extension with no `platforms` key predates the split and has no Windows leg. Write the plain object; do **not** flag a bare `cmd`-only shortcut. *(Real: 7 of Chris's 34 extensions have no `platforms` field — `at-profile`, `google-books`, `ios-apps`, `raycast-fly`, `wayback-machine`, `craftdocs`, `quick-call`. An auditor that treats absent as cross-platform mis-fires on every one of them.)*
- **`["macOS"]` only** → plain object: `shortcut={{ modifiers: ["cmd"], key: "l" }}`. There is no Windows leg. A `{ macOS, Windows }` object on a Mac-only extension is dead weight implying portability it doesn't have.
- **macOS *and* Windows** → platform-explicit form:
  ```ts
  shortcut={{
    macOS: { modifiers: ["cmd"], key: "l" },
    Windows: { modifiers: ["ctrl"], key: "l" },
  }}
  ```
  A bare `{ modifiers: ["cmd"], … }` on a cross-platform extension is the defect: `cmd` doesn't exist on Windows, so the shortcut is silently broken there. (This is the miss that shipped ⌘-only shortcuts into an open Store PR on 2026-07-13.)

> **API casing:** the platform keys are **`macOS`** and **`Windows`** (capital W). TypeScript rejects lowercase `windows` — the type is `{ macOS: {...}, Windows: {...} }`.

| `platforms`         | `Common` match | Write                                                 |
| ------------------- | -------------- | ----------------------------------------------------- |
| absent (⇒ macOS)    | Yes            | `Keyboard.Shortcut.Common.X`                          |
| absent (⇒ macOS)    | No             | `{ modifiers: [...], key: "..." }`                    |
| macOS only          | Yes            | `Keyboard.Shortcut.Common.X`                          |
| macOS only          | No             | `{ modifiers: [...], key: "..." }`                    |
| macOS + Windows     | Yes            | `Keyboard.Shortcut.Common.X` (already platform-aware) |
| macOS + Windows     | No             | `{ macOS: {...}, Windows: {...} }`                    |

**Audit note:** a bare `cmd`-only shortcut is a defect *only if* `platforms` **explicitly includes Windows**. The auditor MUST read `package.json` `platforms` before flagging — and must treat an **absent** `platforms` as macOS-only, not as cross-platform. Skipping this mis-fires on every Mac-only extension *and* on every extension with no `platforms` field, which together are the majority of the fleet.

---

## Raycast `environment` API

Use the platform's `environment` object instead of re-deriving what it already
knows. The rules below are grounded in real fleet patterns and defects (each names
the repo that got it right, and where relevant the one that didn't). Reference:
<https://developers.raycast.com/api-reference/environment>.

### `[both]` Handle no-AI-access on every Raycast-AI call

Any code path that calls `AI.ask` / `useAI` must **degrade gracefully** for a user
without Raycast AI access (non-Pro, or AI disabled) — never let it surface as an
unhandled failure. Two acceptable ways:
- **Gate ahead of time** with `environment.canAccess(AI)` and branch to a non-AI
  fallback (preferred when there's a real fallback to show).
- **Catch the thrown no-access error** around the AI call and fall back there.

Either is fine; an *ungated, uncaught* AI call is the defect.

- **Right (copy this):** `raycast-reader/src/hooks/useArticleReader.ts:84` —
  `const canAccessAI = environment.canAccess(AI);` then
  `const shouldShowSummary = canAccessAI && preferences.enableAISummary;`, reused
  before `rewriteArticleTitle` (~:263).
- **The gap this rule closes:** `raycast-sora/src/utils/videoNaming.ts:44` calls
  `useAI(...)` unconditionally; a user without AI access gets a failure instead of
  the truncated-title fallback `getVideoDisplayTitle()` already provides.
- Same pattern applies to any capability behind `canAccess` (e.g.
  `BrowserExtension` — `raycast-memory-store/src/lib/background.ts:25`).
- **Audit:** grep `useAI(` / `AI.ask` and assert **either** a `canAccess(AI)` guard
  **or** an enclosing try/catch on that path.

### `[both]` Interval-driven commands must branch on `environment.launchType`

A command with an `interval` (a scheduled background refresh — this is what causes
background ticks; `"mode": "menu-bar"` alone does **not**) runs both on user open
**and** on the scheduled background wake. Guard user-facing side effects
(`showToast`, `showHUD`, error UI) behind `environment.launchType`, so a failed
background refresh (e.g. an expired OAuth token) logs quietly instead of firing the
same toast path as a manual open:

```ts
if (environment.launchType === LaunchType.Background) {
  // log only — no toasts, no HUD
}
```

- **The gap:** `raycast-tesla-energy/src/menu-bar-status.tsx` and
  `raycast-luma/src/luma-menubar.tsx` (both interval-driven) don't guard their
  fetch/error UI against background invocation. *(Note: `LaunchType` is imported in
  7 repos but only ever passed **outbound** to `launchCommand()` — no repo yet reads
  its own `environment.launchType`. This is the blank spot to close.)*

### `[build]` Prefer `updateCommandMetadata` to surface menu-bar status in the command list

When a `menu-bar` command has a meaningful compact status, push it into the
command's `subtitle` with `updateCommandMetadata({ subtitle })` so the user sees it
in the root search without opening the menu. This is a *recommendation, not a
mandate* — a menu-bar command with no meaningful one-line status shouldn't be forced
to invent one, so it's `[build]` (judgment at build time), not a `[verify]` audit
assertion that would false-positive on every subtitle-less menu-bar command.

- **The opportunity (0 repos use this yet):** `raycast-tesla-energy/src/menu-bar-status.tsx`
  already computes a compact status string (`batteryTitle()`/`gridTitle()`, ~:8-18)
  that is a ready-made `subtitle`; `raycast-luma/src/luma-menubar.tsx` likewise.

### `[both]` `environment.supportPath` is for INTERNAL state only — user files go to a preference dir

`supportPath` is the writable per-extension directory — the right home for caches,
indexes, and command state the user never opens by hand. (Not `assetsPath`, which is
the **read-only** path to the extension's *bundled* assets — don't write there.)
Anything the user is meant to **find in Finder** (exports, downloads, generated
deliverables) must go to a user-visible directory — an
`exportDirectory`/`downloadDirectory` preference defaulting to `~/Downloads`.

- **Right:** `raycast-fathom/src/utils/export.ts:36` reads
  `preferences.exportDirectory` for vCard/member exports.
- **The gap:** `raycast-fathom/src/actions/TeamMemberActions.tsx:22` writes a
  user-facing JSON export to `path.join(environment.supportPath, "downloads")` —
  buried in `~/Library/Application Support/…` where no one will find it. Route it
  through the same `exportDirectory` preference.
- **Audit:** flag `environment.supportPath` used to build a path that is then
  revealed/opened for the user, or handed to `Action.ShowInFinder`.

### `[verify]` Read the active selection via the platform API, never a shell-out

Use the platform functions to read a selection — never an `osascript`/`open`-based
shell-out:
- `getSelectedText()` — highlighted text in the frontmost app.
- `getSelectedFinderItems()` — selected files, **Finder-specific**: it rejects if
  Finder isn't the frontmost app, so always `await` it in a try/catch (or use it as a
  guarded fallback, as the fleet does).

Already **universal** in the fleet (no shell-outs found): `getSelectedText` in 5
repos (`digger`, `google-maps`, `reader`, `trimmy`, `wrap-unwrap`),
`getSelectedFinderItems` in 2 (`at-profile/src/yaml-settings.ts:282`,
`trimmy/src/trim-core.ts:91`, both macOS-guarded fallbacks). Codifying the winner so
a future extension doesn't regress to `osascript`.

- **Audit:** grep for `osascript`/`System Events` reading a selection; prefer the API.

> **Underused — reach for these on the next fitting extension.** These have little
> or no current adoption and **no** live defect, so they are not rules — but Chris's
> own read is that the `environment` toolkit is under-embraced, so treat them as
> first-choice options when the situation fits:
> - **`environment.appearance`** (`"dark"`/`"light"`) — used in exactly one place
>   (`tesla-energy`'s SVG chart, `view-solar-production.tsx:95`). The pattern to reuse
>   whenever an extension renders **custom graphics** (SVG/canvas) whose colors must
>   track the theme. (Component `tintColor`s should still use the theme-safe `Color.*`
>   enum, not this.)
> - **`environment.textSize`** (`"medium"`/`"large"`) — 0 repos. A natural first try
>   on a long-form `Detail`/Markdown extension like `reader`.
> - **`environment.isDevelopment`** — 0 repos. Gate dev-only debug UI behind it
>   (today debug output is gated on the `verboseLogging` preference instead — fine,
>   but `isDevelopment` is the idiomatic switch for *dev-only* affordances).

---

## Project structure

### `[build]` Organize `src/` into role folders once a command file grows past ~150 lines

Every self-authored extension beyond a handful of files splits `src/` into a subset
of these role folders — the convention is which name means what:

- **`hooks/`** — React state hooks, each file/​export prefixed `use*`.
- **`utils/`** — business logic / pure helpers. (Older/smaller repos used `lib/`;
  new work uses `utils/`.)
- **`types/`** — shared type declarations.
- **`components/`** — small reusable UI widgets.
- **`views/`** — full-screen sub-views (a whole `List`/`Detail` screen), distinct
  from `components/`.
- **`actions/`** — standalone `ActionPanel`/`Action` builders.

Evidence: `raycast-digger/src/{types,utils,components,hooks,actions}`,
`raycast-fathom/src/{tools,types,utils,components,hooks,actions,views}`,
`raycast-threads-client/src/{types,utils,hooks,actions,views}`. Not a single grep,
but the split (and the `views/` vs `components/` distinction) is the house shape —
don't pile everything into one command file, and don't invent parallel names
(`helpers/`, `lib/` in new work).

---

## README

### `[verify]` Original extensions open with the social-badge preamble

Every **self-authored** extension's `README.md` starts with the title, then the
centered badge block (Follow / Stars / Raycast Store), then the one-line tagline —
adapted per extension. (Applies to `chrismessina`-authored extensions; do **not**
impose it on forks you contribute upstream.)

```markdown
# <Extension Name>

<div align="center">
  <a href="https://github.com/chrismessina">
    <img src="https://img.shields.io/github/followers/chrismessina?label=Follow%20chrismessina&style=social" alt="Follow @chrismessina">
  </a>
  <a href="https://github.com/chrismessina/<repo>/stargazers">
    <img src="https://img.shields.io/github/stars/chrismessina/<repo>?style=social" alt="Stars">
  </a>
  <a href="https://www.raycast.com/chrismessina/<store-slug>">
    <img src="https://img.shields.io/badge/Raycast-Store-red.svg" alt="<Extension Name> on Raycast store.">
  </a>
</div>

<one-line tagline>
```

**Two substitutions, and the second is a trap:**
- `<repo>` (stars badge, ×2) = the **full** standalone repo name, e.g. `raycast-reader`
  (the `raycast-` prefix is part of `<repo>`, not the template — don't double it).
- `<store-slug>` (Store badge) = the extension's **`package.json` `name`**, which is
  the Store slug — **not** the repo name. Canonical mismatch: repo `raycast-reader`
  has `name: "reader-mode"`, so the badge URL is
  `raycast.com/chrismessina/reader-mode`. Using `raycast-reader` there 404s. (The
  slug is always `package.json` `name`; when that also differs from the *monorepo
  directory*, the sync layer's `UPSTREAM_EXT_DIR` handles that separate mapping — but
  the badge only ever cares about `name`.)

- **Reference:** `chrismessina/raycast-reader`'s README.
- **Audit:** self-authored repo whose `README.md` lacks the `<div align="center">`
  badge block, or whose Store badge URL doesn't resolve to a live Store page.

---

## Changelog

### `[verify]` Never hand-invent a merge date — keep the `{PR_MERGE_DATE}` placeholder

The newest, unreleased CHANGELOG entry keeps Raycast's literal `{PR_MERGE_DATE}`
token; Raycast substitutes the real date when the Store PR merges. Do **not** guess
a date before merge. Entries follow `## [<Title>] - {PR_MERGE_DATE}` under a
`# <Name> Changelog` header. Universal across all 21 self-authored CHANGELOGs
(merged entries correctly show a real date, e.g. `raycast-bookface: ## […] -
2026-06-23`; only the unreleased entry carries the token).

- **Audit:** `grep -c '{PR_MERGE_DATE}' CHANGELOG.md` — expect it only on the newest
  unreleased entry, never on an already-shipped one, and never a real date on an
  unmerged entry.

---

## Environment / tooling

### `[both]` Run every `ray`/`npm` command from the extension root, never a parent

`npm install`, `npm run dev`, `npm run publish`, and `npx ray develop|build|lint` resolve the
manifest by **walking up from your current directory to the nearest `package.json`** — not by
finding "the extension." Run one from the wrong place and you either get an npm-flavored error
that blames tooling instead of your path, or — worse — you silently operate on a *different*
package.

**Measured on this machine, 2026-07-24** (`raycast-wrap-unwrap`, git 2.50.1, npm/npx; `ray` is
*not* on `PATH` — extensions invoke it via `npx` or an npm script, so always write `npx ray …`):

| Where you run it | `npm run dev` | `npx ray lint` / `npx ray build` |
|---|---|---|
| Extension root | ✅ works (`ray develop` starts) | ✅ works, exit 0 |
| **Subdirectory** of the extension (e.g. `src/`) | ✅ works — npm walks *up* to the nearest `package.json` | ✅ works |
| Parent with **no** `package.json` above it | ❌ `npm error code ENOENT … path …/package.json` | ❌ `npm error could not determine executable to run` |
| Parent that **has** its own `package.json` | 🚨 **silently runs the PARENT's script, exit 0** | ❌ `could not determine executable to run` |

**The last row is the dangerous one, and it's why this rule exists.** npm does not resolve "the
extension" — it walks *upward* to the nearest ancestor `package.json` and uses whatever it finds.
Verified with a decoy `{"name":"PARENT-DECOY","scripts":{"dev":"echo RAN_PARENT_SCRIPT"}}` one
level up: `npm run dev` printed `RAN_PARENT_SCRIPT` and **exited 0 with no error at all.** So the
failure is not reliably a clean error — it can be the *wrong package* quietly running or
installing. This repo (`raycast-extension-workflows`) is exactly such an ancestor: a
`package.json` with `format` scripts and no extension in it.

When you *do* get an error, it **names npm and never Raycast** — nothing says "manifest" — so it
reads like a broken install and sends you debugging a dependency. (`npx ray …` is the more
confusing: "could not determine executable to run" sounds like `ray` isn't installed.)

**So never rely on an error to tell you you're in the wrong directory.** Resolve the root
explicitly (below) and `cd` there before running anything.

The extension root is the directory holding the `package.json` **that carries Raycast keys**
(`commands`, `title`, `icon`) — not merely any `package.json`. That distinction is the whole
rule, because the fleet has **two topologies** and only one of them puts the root at the repo root:

| Topology | Repo root | Extension root |
|---|---|---|
| Standalone mirror (`chrismessina/raycast-<name>`) | = extension root | the repo root itself |
| Monorepo (`raycast/extensions`, incl. sparse checkouts and PR-review forks) | monorepo root | `extensions/<name>/` |

**The trap is the second row.** After a sparse checkout or a PR-review fetch you are sitting
in the monorepo root with exactly one extension materialized under `extensions/<name>/` — it
*feels* like the project root, and the error blames tooling instead of the path. This repo's own
`raycast-extension-workflows` root is a third false root, and the worst kind: it has a
`package.json` (Prettier/format scripts only) with **no extension in it**, so npm's upward walk
finds it and runs *that* instead of erroring.

**Resolve the root explicitly before running anything** — don't infer it from where the shell
happens to be:

```bash
# From anywhere in the tree: find the package.json holding a real Raycast `commands` ARRAY.
# Testing `.commands` alone is too loose — `{"commands":"anything-truthy"}` passes `jq -e`
# and would misidentify the root (verified 2026-07-24).
find . -name package.json -not -path '*/node_modules/*' \
  -exec sh -c 'jq -e "(.commands|type==\"array\") and (.commands|length>0)" "$1" >/dev/null 2>&1 && dirname "$1"' _ {} \;
```

Ambiguous result (several matches) → ask which extension, don't guess. Then `cd` there and
stay there for the whole build/lint/dev cycle.

- **`develop`:** `cd` to the resolved root before the first command; keep the dev loop there.
- **`ship`:** every pre-flight gate (`tsc --noEmit`, `npm run build`, `npm run lint`) and
  `npm run publish` runs from that same root. A gate that "passed" from the wrong directory
  did not run.

### `[both]` Disable the Impeccable design hook — it is irrelevant to Raycast extensions

The Impeccable **design detector hook** (`/impeccable hooks`) scans edited files for
rendered-UI defects — broken `<img>`, contrast, gradient text, glow shadows, layout
rhythm. **A Raycast extension has no rendered HTML/CSS surface** — the UI is declared
entirely through `@raycast/api` components (`List`, `ActionPanel`, `Detail`), which the
detector cannot see. So every finding it produces on extension code is a false positive.

The concrete failure (observed 2026-07-23, `reddit-search`): the detector read a
**server-side Atom-feed parser** — `decodeEntities(rawContent).match(/<img[^>]+src="…"/)`,
a regex that *extracts* image URLs from feed HTML, plus a JSDoc mentioning `<img>` — as a
"broken image" and re-fired the `broken-image` finding on **every `Stop` event**, turning
a shipped, correct extension into a per-turn nag.

**Rule:** on first touch of any Raycast extension repo, disable the hook for that project:

```bash
node <impeccable-skill-dir>/scripts/hook-admin.mjs off   # writes hook.enabled:false to .impeccable/config.json
# (or) /impeccable hooks off
```

`.impeccable/config.json` is machine-local (gitignore it — it must not ship to the Store
PR). Do NOT reach for per-file/per-rule ignores here: the whole detector is out of scope
for this codebase, so `off` is the correct blunt instrument, not a scoped `ignore-value`.

- **`develop`:** run this once when you first edit an extension in a session and the hook
  is firing. It has no bearing on the code; silence it and move on.
- **`ship`:** ensure the hook is off (or its config gitignored) before the pre-flight, so
  a stray design finding can't masquerade as a house-style violation during the audit.

---

## Still to enumerate

Candidates that showed up in a fleet audit (2026-07-23) but are **not yet rules** —
either emerging (adopted only in recent work) or too split to codify. Parked here so
they aren't re-discovered from scratch; promote one when it earns it.

- **Conventional Commits** (`feat:`/`fix:`/`chore:`/…). Near-100% in recent repos
  (`airbuddy` 40/40, `wrap-unwrap` 39/39) but **zero** in older ones (`digger`,
  `bookface`, `google-maps`, `fetch`, `at-profile`). A habit adopted mid-2026, not a
  standing convention — and a commit convention, not strictly extension house-style.
  Promote when it's the norm across a fresh audit.
- **Real unit-test suites** (`*.test.ts`). Only 4/21 (`happenstance`, `memory-store`,
  `reader`, `wrap-unwrap`). Emerging practice; too sparse to mandate.
- **Explicit `throttle` on live-search `List`s.** Chris sets it deliberately where a
  command does per-keystroke remote fetching (`google-maps`, `memory-store`,
  `ios-apps` on; `parallel-web-tools` off-with-intent) but many search commands omit
  it. Closer to a per-command correctness call than a blanket rule.
- **Default icon filename `extension-icon.png`.** ~10/21 use it, ~11/21 use a
  brand-specific name — a coin flip, not a convention. Not codified.
- **`@raycast/api` import ordering.** 35–85% adherence and no `import/order` /
  `simple-import-sort` configured anywhere. Would need tooling first; not enforced.

**Rejected outright** (checked, no real pattern): `ActionPanel.Section` usage ratio;
`showFailureToast` vs manual Failure toast (manual dominates — already covered by the
Copy-Error rule); `useCachedPromise`/`usePromise` vs manual loading state (even split);
`export default function Command()` naming (mixed).
