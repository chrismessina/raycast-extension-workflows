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
`error.message` unguarded, and don't spin up a **one-off, in-repo** `getErrorMessage` helper:

```ts
const errorMessage = error instanceof Error ? error.message : String(error);
```

**Exemption — the shared kit.** `getErrorMessage` from `@chrismessina/raycast-kit`
satisfies this rule and is *preferred* wherever the kit is already a dependency: it is
strictly better than the ternary (see the kit section below for the fleet error shapes
the bare ternary renders as `"[object Object]"`). The prohibition is on hand-rolling a
*local* helper per repo, not on the one shared implementation. Use the literal ternary
only where the kit is not available.

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

### `[both]` In a `no-view` command, never `showHUD` before a toast that carries actions

The Copy-Error rule above is silently defeated in `no-view` commands by a single earlier `showHUD`. Three pieces of documented behavior compose into a trap:

1. `showHUD` **closes the main Raycast window** — its stated purpose, not a side effect.
2. `showToast` **degrades when the window is closed.** Raycast's docs describe that fallback inconsistently — `showHUD()` in one place, a system notification in another — but both are non-interactive, so the distinction doesn't change the outcome.
3. Neither fallback renders actions, so `primaryAction` / `secondaryAction` are **dropped**.

The code reads correct — the actions sit right there in the `showToast` call — and they never render. Nothing in the type system, the linter, or a diff review catches it. **Only a human running the command sees it.**

- **HUDs cannot carry actions at all.** `showHUD(title, options)` accepts only `clearRootSearch` and `popToRootType`. There is no action parameter, so "add an action to the HUD" is never the fix — the fix is to stop using a HUD.
- **If a `no-view` command offers any action on completion** — Show in Finder, Open, Copy Error, Retry — use a **Toast for the whole flow**: animated toast up front, mutate `message`/`title` for progress, terminal toast at the end. No `showHUD` anywhere in that command's path, *including inside shared `lib/` helpers it calls* — that is where it hides.
- **HUD stays correct** for instant, action-free confirmations: "Copied", "Pinned", "Moved to Trash".
- **Accept the trade-off:** a Toast keeps the Raycast window open where a HUD dismisses it. That is the price of interactivity; there is no third option that both closes the window and offers an action.

```ts
// no-view command, canonical shape
const toast = await showToast({ style: Toast.Style.Animated, title: "Downloading", message: filename });

toast.message = `${filename} — ${percent}%`; // progress: mutate in place

// Terminal state. Mutating `toast.style` in place is equally supported (see the
// kit section below); what matters here is that the user ends up looking at a
// Toast rather than a HUD, so the action survives.
await toast.hide();
await showToast({
  style: Toast.Style.Success,
  title: "Download Complete",
  message: filename,
  primaryAction: { title: "Show in Finder", onAction: () => showInFinder(path) },
});
```

- **Audit:** for each command with `"mode": "no-view"` in `package.json`, walk its entry file **and the `lib/` helpers it imports**. Flag any `showHUD` in a command that also builds a toast carrying `primaryAction`/`secondaryAction`.
- **Evidence:** 2026-08-07, `raycast-fetch`. The single-download completion toast carried both "Open File" and "Reveal in Finder"; neither ever appeared, because the progress helper opened with `showHUD`. It survived a full code review, a house-style audit, and an adversarial Codex pass — Chris found it on the first real run. Converting the path to a Toast throughout fixed it, confirmed on screen.

### `[both]` `Toast.Style.Animated` is a promise that work is in flight — never spin for a synchronous write

An animated toast tells the user "wait, something is happening." If the operation is an instant `LocalStorage` write, a `setState`, or a `Clipboard.copy`, there is nothing to wait for: show the terminal Success toast directly, with no `Animated` phase at all.

- **Reserve `Animated` for genuinely async work** — network requests, disk IO, spawned processes, anything with a plausible wait.
- **For genuinely async work, both terminal patterns are supported.** Mutate in place (`toast.style = Toast.Style.Success`, or `failToast` for the failure half — see the kit section below), or `await toast.hide()` then show a fresh toast. Pick either; they are equivalent.
- **Audit:** grep `Toast.Style.Animated`. For each, confirm genuinely async work is awaited between creation and the terminal state. Flag any whose only intervening work is `LocalStorage` / `setState` / `Clipboard`.

**Evidence, and a correction worth recording.** 2026-07-27, `raycast-claude`: Chris screenshotted "Preset saved!" beside a still-spinning icon. The first diagnosis was *"mutating `toast.style` on a presented toast never swaps the animated icon"* and it was written down as a general law. **That claim is false** — Raycast's SDK documents live mutation as the supported pattern, and it demonstrably worked at other sites in that same codebase. The actual defect was that **15 of the 17 sites were instant `LocalStorage` writes that should never have had a spinner**. The fix was deleting the `Animated` phase, not changing how the terminal state is set. If you see the old claim resurface anywhere, this entry supersedes it.

### `[both]` Show a file with `Action.ShowInFinder` / `showInFinder()`, never `open(path, "Finder")`

`open(path, "Finder")` means "open this file **with** the Finder application". It is not the show-in-Finder API and does not reliably select the file in its containing folder. The correct primitives are the built-in `Action.ShowInFinder` (inside an `ActionPanel`) and `showInFinder(path)` (in a toast action or plain handler). The **component** supplies the right default title and icon for free; the **utility** takes only a path and simply shows it — you own the surrounding title/icon there.

**Also watch the inverse:** a label promising Finder while the handler calls bare `open(filePath)`, which opens the file in its default app and never involves Finder. The label is the spec — make the call match it.

- **Audit:** grep `open(` with `"Finder"` as its second argument.
- **Evidence:** 2026-08-07, `raycast-fetch` — two action panels labelled "Reveal in Finder" were opening the file with Finder rather than revealing it.

#### Wording: "Show in Finder" — and on `Action.ShowInFinder`, pass no `title` at all

Raycast's term is **Show**, not Reveal or Open — in action titles, error copy, and any user-visible string. ("Reveal" is Finder's own menu wording, which is exactly why it keeps creeping in.) But the rule that matters is stronger than wording, because the title carries the platform:

```
title?: string;
@defaultValue `"Show in Finder"` on macOS and … on Windows   ← the Windows half MOVES
icon?:  @defaultValue Icon.Finder on macOS and Icon.HardDrive on Windows
```

So **any** `title` on `<Action.ShowInFinder>` — including the "correct" `"Show in Finder"` — hardcodes macOS wording onto Windows. Omit it and both platforms are right for free, *and stay right across upgrades*.

> ⚠️ **The Windows string is not stable, which is the whole argument for omitting `title`.**
> `ShowInFinderProps` documented `"Show in Explorer"` in v1.104.23 and **`"File Explorer"`**
> in v2.0.3. Any extension that hand-wrote the v1 wording silently disagrees with Raycast
> the moment it upgrades. The component tracks the change; a literal never will.

Hand-written titles (`toast.primaryAction`, a custom `<Action>`) get no such help, so they carry a standing maintenance cost. Prefer routing through `Action.ShowInFinder` where an `ActionPanel` allows it. Where you genuinely must hand-write (a toast action), **read the current default out of the installed types rather than copying a string from this file**:

```bash
grep -A3 'defaultValue.*Show in Finder' node_modules/@raycast/api/types/index.d.ts
```

```ts
// macOS is stable; the Windows half is version-dependent — verify against the line above.
title: isMacOS ? "Show in Finder" : "File Explorer"   // v2.0.3 wording
```

Never `"Show in Folder"` — that has never been Raycast's string on either platform.

- **Audit:** `rg -n 'title[=:] *["`].*\b[Rr]eveal'` → any user-facing "Reveal" (not just "in Finder" — it hides in "Reveal Index File" and "Could Not Reveal…"); `rg -A3 '<Action\.ShowInFinder' | rg 'title='` → must return nothing. Internal identifiers (`revealOnComplete`, a `RevealInFinderAction` component) are not user-facing and don't block.
- **Evidence:** 2026-08-10 fleet audit — 8 user-facing strings across 4 self-authored extensions said "Reveal" or "Open in Finder"; `raycast-reader` branched on platform but emitted "Show in Folder". Every `Action.ShowInFinder` already omitted `title`, so the component was the only thing getting Windows right. Two `raycast-fathom` toasts labelled "Open in Finder" called bare `open(filePath)` — the file opened in its default app and Finder never appeared. **2026-08-20:** v2.0.3 renamed the Windows default from "Show in Explorer" to "File Explorer", invalidating the hand-written wording this rule had recommended ten days earlier — evidence for the omit-`title` form over any literal.

### `[both]` Empty/error state copy: short title, one-line description, steps in the actions

`List.EmptyView` (and `Toast`) copy follows one shape: an icon, a short imperative
title, and a **single-sentence** description. Multi-step guidance goes in the
`actions`, not the description.

**Why it's a hard rule, not a preference:** `List.EmptyView`'s `description`
**collapses newlines** — a multi-line string renders as one run-on line, so the steps
you carefully put on separate lines arrive as one wall of text.

> **Sourcing:** this is *observed behavior*, not a documented API guarantee — the SDK
> types specify only `description: string`. The evidence is Chris's own note at
> `/Users/messina/Developer/GitHub/chrismessina/raycast-airbuddy/src/components/error-views.tsx:43`
> (*"List.EmptyView's `description` collapses newlines — … Keep every description to ONE
> short line and put the steps in the actions."*). **Repro if you need to confirm it:**
> render a `List.EmptyView` with `description={"line one\nline two"}` and look at the
> screen. The rule is good regardless of the mechanism — a one-line description with the
> steps in the actions is the better empty state either way.

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
- **The newline half of (a) now has an ESLint rule** —
  [`eslint-rules/no-multiline-emptyview-description.mjs`](./eslint-rules/no-multiline-emptyview-description.mjs).
  Catches `List.EmptyView` / `Grid.EmptyView` / bare `EmptyView` (plus any local wrapper
  passed via `additionalComponents`), across `"…"`, `{"…"}`, and template literals. Drop it
  into an extension's flat config:

  ```js
  import noMultilineEmptyViewDescription from "./eslint-rules/no-multiline-emptyview-description.mjs";

  export default defineConfig([
    ...raycastConfig,
    {
      plugins: { house: { rules: { "no-multiline-emptyview-description": noMultilineEmptyViewDescription } } },
      rules: { "house/no-multiline-emptyview-description": "error" },
    },
  ]);
  ```

  **Why lint and not a shared `<EmptyView>` component** (considered and rejected 2026-07-25):
  a wrapper can't stop anyone using `List.EmptyView` directly, `description: string` can't
  express "contains no newline" in TypeScript, and normalizing at runtime would *hide* the
  defect rather than prevent it. Lint catches it before merge; the `ship` grep stays as the
  backstop for extensions that haven't adopted the rule. A component layer would also drag
  React and JSX build surface into every consumer for 55 call sites that are mostly
  domain-specific (airbuddy's dispatches on four AirBuddy-only error classes).
  *Fleet check 2026-07-25: zero current violations — this rule is preventive, and the
  airbuddy comment that documented the trap did its job.*

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

### `[both]` Count-bearing copy uses correct singular/plural agreement — never `item(s)`

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
- **Audit:** the greppable subset is what `ship` asserts (this rule is `[both]` for that
  reason — as `[build]` the check below never actually ran). Grep user-facing copy
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

**Status:** published — [`@chrismessina/raycast-kit`](https://www.npmjs.com/package/@chrismessina/raycast-kit)
v0.1.3 (first published 2026-07-25), zero runtime deps, `@raycast/api` peer. First adoption: `get-app-icon`
(`c1de11b`), which converted 4 non-compliant failure toasts and deleted a duplicate
`pluralize`, net −22 lines.

**The mapping:**

```ts
import { showError, failToast, getErrorMessage, countOf } from "@chrismessina/raycast-kit";

// BEFORE — Copy-Error block hand-written (or, more often, omitted)
const errorMessage = error instanceof Error ? error.message : String(error);
await showToast({ style: Toast.Style.Failure, title: "Failed to Load", message: errorMessage,
  primaryAction: { title: "Copy Error", onAction: async () => { await Clipboard.copy(errorMessage); } } });
// AFTER
await showError(error, { title: "Failed to Load" });

// A progress toast flipped to failure IN PLACE — showError creates a NEW toast, so
// these sites need failToast. They're the majority of real failure paths, and were
// the ones missing a Copy-Error action (attaching it by hand costs six lines).
const toast = await showToast({ style: Toast.Style.Animated, title: "Exporting…" });
try { await work(); toast.style = Toast.Style.Success; }
catch (error) { failToast(toast, error, { title: "Export Failed" }); }

// BEFORE — says "1 items" at count 1
`${n} items`  /  `${n} item(s)`
// AFTER — user-facing copy always passes `zero`, per the count rule above
countOf(n, "item", { zero: "No items" }) // "No items" · "1 item" · "7 items"
countOf(n, "item")                       // "0 items" — numeric zero; internal/among-other-counts only
```

`showError` swallows `AbortError` by default — a user typing the next keystroke cancels the
in-flight request, and that was never a failure worth toasting. Pass `ignoreAbort: false`
where you do want it surfaced.

**`getErrorMessage` is strictly better than the ternary it replaces**, which is why the
`[lint]` ternary rule above stays satisfied by it. Validated against real fleet error shapes:
an `itunes-api`-style `{status, statusText}` object, a nested `{error:{message}}` JSON API
response, and a thrown plain object were all rendering **`"[object Object]"`** through the
bare ternary. 4 of 7 real shapes produce better copy.

**Pure-TS subpaths — decide the entry point per MODULE, not per file type.**
`@raycast/api` ships types only (no `main`; the host injects it at runtime), so the root
export — which pulls in `showError` → `toast.js` → `@raycast/api` — is **unloadable in plain
Node**. The pure helpers have standalone subpaths: `@chrismessina/raycast-kit/errors`
(`getErrorMessage`, `isAbortError`, `redactSecrets`), `@chrismessina/raycast-kit/plural`
(`countOf`, `plural`).

The rule is **not** "subpaths in tests, root everywhere else." It is:

| Module | Import from |
|---|---|
| UI layer — components, actions, anything already importing `@raycast/api` | root |
| Pure logic — parsers, formatters, index/cache readers, tests, scripts | the subpath |

**The trap is a production module that happens to be headlessly testable.** Importing the
root into one poisons it: the module still compiles and `ray build` still succeeds — esbuild
resolves `@raycast/api` fine — so **nothing fails until you run that module outside Raycast**,
and then it fails as `Cannot find module '@raycast/api'` with a stack naming `toast.js`. The
error never mentions the kit's export map, so it reads like a broken install rather than a
wrong entry point.

*(Receipt, `claude-artifacts` 2026-07-25 — an early kit adoption, hours after `get-app-icon`: a root import of
`getErrorMessage` into the index-parser module broke all 11 of its headless fixtures at once.
The first fix attempted was a hand-rolled local copy plus a comment claiming the kit "can't"
be used in pure modules — wrong, and the kit's README had documented the subpath all along.
Check the entry point before concluding the kit doesn't fit.)*

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

### `[build]` An ActionPanel spanning two scopes is split into `ActionPanel.Section`

A flat list of actions does not tell the user **what each one will act on**. In a list
row's panel, "Remove From Group" and "Add New Tester" sit adjacent and look like peers —
one destroys the selected tester, the other creates something in the group. Nothing in
a flat panel distinguishes them, and the destructive one is the one you can't undo.

**The section boundary is scope, not category.** Not "reads vs writes", not "safe vs
destructive" — *what does this act on?*

1. **First section: the selected item.** Everything that reads, edits, copies, or
   deletes *this row*. **Title it with the item's own name** (`betaGroup.attributes.name`,
   the tester's display name, `Build 4`). That title is the whole point: the panel now
   states its target instead of leaving the user to infer it.
2. **Following sections: the wider scope.** Actions on the collection or context —
   "Add New Tester", "Create Group", "Invite Team Member". Usually untitled; title it
   when there is a second, genuinely different scope (e.g. `Export Compliance` on a
   build, which is neither the build's identity nor the list's).

```tsx
<ActionPanel>
  <ActionPanel.Section title={betaTesterDisplayName(tester)}>
    {copyAction(tester)}
    {removeTesterAction(tester)}   {/* destructive lives WITH what it destroys */}
  </ActionPanel.Section>
  <ActionPanel.Section>
    {addNewTesterAction()}
    {manageBuildsAction()}
  </ActionPanel.Section>
</ActionPanel>
```

**Keep the destructive action inside its item's section.** Quarantining it into a
"Danger" section at the bottom is the common instinct and it is wrong here: it separates
the action from the thing it names, which is exactly the association the section titles
exist to make. Destructiveness is already carried by `Action.Style.Destructive` and the
confirm dialog.

**Three corollaries, all observed while applying this:**

- **A section title needs a display-name helper, not string concatenation.** Reaching for
  `firstName + " " + lastName` inline produces a trailing space for anyone with no
  surname, and you will now render that string in two places (row title *and* section
  title) where it must agree. Extract one helper; the duplication is what surfaces the
  bug. *(Public-link TestFlight testers have no surname — every such row had a trailing
  space.)*
- **Sectioning changes shortcut adjacency, so re-check the conflict invariant after.**
  Moving an action into a section is also the moment you notice it had no shortcut at
  all; adding `Common.New`/`Common.Remove` while sectioning is normal and is exactly when
  a collision gets introduced. `ray lint` does not check this — read the resolved panel.
- **Two actions in *different rows'* panels may share a shortcut.** A file with two
  `Common.Remove` is not a collision if each lives in a separate row's ActionPanel
  (e.g. "Revoke" on an invitation, "Remove" on a member). Count per resolved panel, not
  per file, or the audit produces false positives.

**When the rule fires — both conditions, not either.**

1. The panel resolves to **5 or more direct actions**, AND
2. those actions span **two or more scopes** by the test above.

**A single-scope panel is EXEMPT at any size.** Five actions that all act on the same
item stay flat — there is no second scope, and inventing one produces an empty or
artificial section. This is the common false positive; check condition 2 before flagging.

**"Resolved" means what the user actually sees**, for one concrete item, after
conditionals evaluate. Count accordingly:

- A `{cond && <Action/>}` counts only in the branch where it renders. A panel that is
  flat-with-4 for most rows and 6 for one state is judged per state.
- A fragment (`{copyAction(x)}` returning `<>…</>`) counts as the actions inside it, not
  as one.
- An `ActionPanel.Submenu` counts as **one** action; its children are its own scope and
  are not counted at this level.

**Deliberately `[build]`, not `[both]`.** Condition 2 is a judgment call — whether two
actions share a scope cannot be decided by grep, and an auditor that mechanically flags
every flat 5-action panel produces false positives on exactly the single-scope panels
exempted above. `ship` does not assert this; `develop` applies it while writing, and a
reviewer may raise it. Do not promote it to `[verify]` without a mechanical scope test.

Applies to `List.Item`/`Grid.Item`/`Detail` panels; a `Form`'s single submit action needs
nothing.

### `[both]` Audit the FIRST action of every ActionPanel state, not just the primary one

Raycast binds Return to whatever action is first in an `ActionPanel`, per rendered state,
regardless of any explicit `shortcut` on it. So the question is never "did I assign the
shortcuts correctly" — it is **"for each state this view can render, what does Return do?"**

**Audit:** enumerate every branch that renders a different `ActionPanel` — loaded, empty,
error, mid-scan, partial results — and for each one name the first action and what Return
therefore triggers.

- A **destructive or irreversible** action (eject, delete, revoke, overwrite) must never be
  first in any state. Put a read-only action ahead of it.
- Every state must render **at least one** action. A state with an empty `ActionPanel` is a
  dead end the user can only escape with Esc.
- Adding an action to one state does not audit the others: the branch you did not touch is
  where the defect lands.

*(Real: `raycast-ejection-seat` audited the shortcut slots in the blockers state and shipped
correct ones — then in the "No Visible Blockers" state `Eject Volume` was first, so opening a
clean volume and pressing Return ejected it. The shortcut audit passed; the per-state
first-action audit did not exist.)*

### `[both]` Keyboard shortcuts: `Common` first, platform-explicit only when cross-platform

Two independent decisions. Don't conflate them. (Full ruleset + conflict invariant + audit-fix contract: see [`keyboard-conventions.md`](./keyboard-conventions.md).)

**Decision 1 — Does a `Keyboard.Shortcut.Common` member match the action's semantics?**

- **Yes → use the `Common` constant.** Always. It is already platform-aware, so it is correct on every platform with no extra work. Never hand-roll a shortcut that `Common` already covers, and never wrap a `Common` constant in a platform-explicit object.
- **No → a custom shortcut is correct and expected.** The `Common` set is small and version-dependent (16 members in `@raycast/api` 1.104.1,
  17 in 2.0.5 — read the installed typing rather than trusting a number written here); it
  does not cover everything (no "switch mode", "toggle setting", "connect"). Do not force a bad semantic match — a wrong `Common` is worse than an honest custom shortcut.

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

> **API casing:** the platform keys are **`macOS`** and **`Windows`** (capital W). Lowercase `windows` still typechecks but is marked `@deprecated Use Windows instead` in the SDK — always write `Windows`.

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
- **Audit:** the failure mode here is a **green check on a real violation**, so the pattern
  has to be tight. A literal `useAI (` / `useAI(` grep misses `useAI  (`, a renamed import
  (`import { useAI as ask }`), and property access (`AI["ask"]`). Match
  `\b(useAI|AI\s*\.\s*ask|AI\s*\[\s*["']ask["']\s*\])\s*\(` **and** resolve aliases by
  first grepping the `@raycast/api` import specifiers in each file for `useAI`/`AI`.
  For each hit assert **either** a `canAccess(AI)` guard **or** an enclosing try/catch on
  that path. AST detection (`ts-morph`/`typescript` compiler API) is the airtight version if
  this ever produces a miss in practice.

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
indexes, and command state the user never opens by hand. (Not `assetsPath`, which points
at the extension's *bundled* assets — that directory is part of the installed bundle and
gets replaced on every update, so anything you write there is lost. The SDK does not
document it as filesystem-read-only; the reason to avoid it is durability, not permissions.)
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

- **Audit:** a bare `osascript`/`System Events` grep is **too broad** — it fires on
  AppleScript/JXA used for unrelated automation (`get-app-icon` opens Finder's Info
  window; `airbuddy` drives its own JXA), neither of which reads a selection. Narrow to
  scripts that actually read one: match `osascript`/JXA **co-occurring** with a selection
  term (`selection of`, `selected items`, `get selection`, `selectedText`, `sel of`), then
  eyeball the hits. Prefer the API in every case that survives.

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

## Icons

### `[both]` A monochrome bundled icon needs a theme-aware treatment — a bare filename is invisible in one theme

**Scope: monochrome glyphs shipped as a single asset.** Referencing one by bare filename
— `icon="artifact_file.svg"` — renders it with **its own baked-in fill**, which Raycast
does not adjust for the active theme. A glyph authored dark reads fine in light mode and
**disappears against the dark background** (and vice versa).

Two supported fixes; either satisfies this rule.

**1. Tint from the code side** (preferred for a single monochrome asset):

```tsx
const ARTIFACT_ICON: Image.ImageLike = {
  source: "artifact_file.svg",
  tintColor: Color.PrimaryText,   // theme-aware; tracks the row's title color
};
```

**2. Ship a themed source pair** — `Image.Source` accepts `{ light, dark }` directly, and
Raycast also picks up an implicit `foo@dark.png` sibling. Correct, and **not** a defect:

```tsx
const ICON: Image.ImageLike = { source: { light: "glyph-light.svg", dark: "glyph-dark.svg" } };
```

- **Which color, when tinting:** `Color.PrimaryText` for a glyph that should read like the
  row title; `Color.SecondaryText` for a de-emphasised accessory; a semantic `Color.*`
  (Red / Green / Orange) where the icon carries status. **Prefer the semantic `Color.*`
  enum over a raw hex** — not because hex is broken (`Color.Raw` is fully supported and
  documents HEX/RGB/HSL, and `Color.Dynamic` takes `{ light, dark, adjustContrast }`), but
  because the enum keeps one palette across the fleet and tracks Raycast's themes for free.
  Reach for hex only when the design genuinely needs a color the enum doesn't carry.
- **Don't count on `fill="currentColor"` in the SVG.** *Observed on `claude-artifacts`,
  2026-07-25:* the icon was switched to `currentColor` specifically to fix dark mode,
  shipped, and was **still invisible in dark mode** on the next screenshot — the fix was
  `tintColor`, not the asset. Stated as an observation, not an SDK law: Raycast's changelog
  records a `currentColor` SVG-handling fix, so behavior may differ by version, and this has
  not been re-tested since. Use one of the two supported mechanisms above and you don't have
  to care which way it currently falls.
- **Exempt:** full-color raster assets (logos, app icons, screenshots) that are
  *meant* to keep their own colors, and `Icon.*` built-ins (already theme-aware).
- **Not the same as `environment.appearance`** — that is for graphics you *render*
  yourself (SVG charts you generate). For a bundled asset handed to a component,
  `tintColor` is the mechanism.
- **Audit:** grep `icon=` / `source:` for a bare `.svg`/`.png` string that has **neither**
  an adjacent `tintColor` **nor** a `{ light, dark }` source **nor** an `@dark` sibling file
  in `assets/`, and flag it for a monochrome glyph. Do not flag a themed pair — it is
  already correct. A green `ray lint` proves nothing here: no rule checks it, and the defect
  is invisible until someone opens the other theme.

> **Check both themes before calling an icon done.** This class of defect is
> undetectable from a build, a lint, and a single screenshot — it needs the theme
> toggled. Same discipline as walking the empty/error states.

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

### `[verify]` Original extensions ship the social-badge preamble and `FUNDING.yml`

**Going-forward standard, not a description of the fleet as it stands.** The badge block
post-dates a good number of already-published extensions, so a census will show plenty of
misses — that is expected backlog, not drift. Apply it to anything new, and backfill on the
next substantive touch. (Applies to `chrismessina`-authored extensions; do **not** impose
it on forks you contribute upstream.)

Two artifacts:

1. **`README.md`** starts with the title, then the centered badge block
   (Follow / Stars / Raycast Store), then the one-line tagline — adapted per extension.
2. **`.github/FUNDING.yml`** — every self-authored mirror carries it. All existing copies
   are byte-identical, so this is a straight copy from any repo that has one; there is
   nothing per-extension to edit.

> **The badge implies publication.** The third badge deep-links to
> `raycast.com/chrismessina/<store-slug>`, which 404s until the extension is actually in
> the Store. Add the block **at publish time**, not at scaffold time — and when auditing,
> check the Store URL resolves rather than only that the block exists. `FUNDING.yml` has no
> such constraint; it is safe from day one.

- **Audit:** for self-authored extensions, assert the preamble **and** `.github/FUNDING.yml`.
  Report unpublished extensions separately rather than as violations. Watch for `.github`
  appearing in `.gitignore` — it silently prevents `FUNDING.yml` from ever being committed.
- **Census 2026-08-10:** 25 self-authored extensions, 12 published. Of those 12: 4 complete,
  3 have the badge but no `FUNDING.yml`, 5 have neither. `central-icon-system` carries the
  badge while its Store URL 404s — a live dead link, and the reason for the publish-time rule.

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

### `[both]` Changelog bullets are tweet-length and ordered by user benefit

The CHANGELOG is read by two audiences who both skim: a Store reviewer deciding what
changed, and a user deciding whether to care. Neither reads a paragraph.

**Length: ~280 characters per bullet — tweet length.** If a bullet needs more, the
rationale belongs in the commit message, not here. A bullet that runs long is usually
carrying three things at once; the fix is to cut the mechanism and keep the outcome.

**Order by user benefit, not by diff size or chronology.** The headline capability
first, behavior changes to things that already worked next (a returning user needs to
find those), dependency and security bumps last.

**One bullet per change a user would notice.** A minor improvement does not earn its own
line — fold it into the bullet for the feature it belongs to, as a trailing clause. A
CHANGELOG where every touched file gets a bullet reads as a diff, not as release notes.

**Do name behavior changes explicitly.** A default action that moved, an action that
disappeared from a view, a renamed command — these are the entries that stop a bug
report from being filed. They go above the dependency bumps, never omitted as noise.

- **Audit:** every `- ` line in the newest entry is ≤ ~280 chars:
  ```bash
  awk '/^## \[/{n++} n==1 && /^- /{ if (length($0)-2 > 280) print length($0)-2": "$0 }' CHANGELOG.md
  ```
  Expect no output. Treat 280 as a target, not a hard gate — 300 for a bullet that
  genuinely needs it is fine; 390 is a bullet doing three jobs.

> ⚠️ **Be careful running Prettier on `CHANGELOG.md`.** It reformats whitespace inside
> headings that have **already shipped** — collapsing a double space after the dash, for
> instance — which puts unrelated churn in a diff that a Store reviewer reads as an edit to
> published history. `ray lint` does **not** require the changelog to be Prettier-clean, so
> reformatting it buys nothing.
>
> **This is cosmetic, not dangerous.** Raycast CI substitutes the literal `{PR_MERGE_DATE}`
> token and nothing else, so whitespace in an already-dated heading cannot cause a
> re-stamp — only reverting a dated heading *back to the placeholder* can (see the rule
> above). An earlier version of this note claimed otherwise; that was asserted, not
> verified. If Chris says normalize it, normalize it.
>
> Observed twice in one session (2026-08-27, brew #30598): `npx prettier --write
> CHANGELOG.md` rewrote `## [Bug fix] -  2026-05-21` to a single space on two separate
> edits, and `ray lint` stayed green both times — so only the diff against the published
> file surfaced it at all. After any reformat, check what moved:
> ```bash
> diff <(grep -E '^## \[' "$PUB_DIR/CHANGELOG.md") \
>      <(grep -E '^## \[' CHANGELOG.md | grep -v '{PR_MERGE_DATE}')
> ```bash
> diff <(grep -E '^## \[' "$PUB_DIR/CHANGELOG.md") \
>      <(grep -E '^## \[' CHANGELOG.md | grep -v '{PR_MERGE_DATE}')
> ```

**Evidence:** written 2026-08-27 after the `brew` analytics PR, where the first draft ran
to nine bullets — one of them 391 characters, another 326 — and spent a full bullet on
"each package shows when it was installed, and pinned formulae carry a pin icon", a minor
change that Chris flagged as not warranting its own line. Condensing to seven bullets
ordered by benefit, with the minor items folded in as clauses, is the shape this rule
describes.

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
# Find the package.json holding a real Raycast `commands` ARRAY.
# Testing `.commands` alone is too loose — `{"commands":"anything-truthy"}` passes `jq -e`
# and would misidentify the root (verified 2026-07-24).
# Walk UP first, THEN search descendants: you are usually already *inside* the extension,
# and a bare `find .` only looks downward — from `myext/src/lib` it silently returns
# nothing (bug found and the fix verified against a disposable tree, 2026-08-10).
find_ext_root() {
  _is_ext() { jq -e '(.commands|type=="array") and (.commands|length>0)' "$1" >/dev/null 2>&1; }
  d=$PWD
  while [ "$d" != "/" ]; do
    if [ -f "$d/package.json" ] && _is_ext "$d/package.json"; then echo "$d"; return 0; fi
    d=$(dirname "$d")
  done
  find . -name package.json -not -path '*/node_modules/*' \
    -exec sh -c 'jq -e "(.commands|type==\"array\") and (.commands|length>0)" "$1" >/dev/null 2>&1 && dirname "$1"' _ {} \;
}
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
