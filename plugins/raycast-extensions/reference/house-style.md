# House Style

Chris's personal conventions for every Raycast extension — the "third category": not a lifecycle *stage*, not a *throughline* constraint, but a standards checklist. Applied at **build time** by `develop` and audited at **pre-flight** by `ship`. Single source of truth, two consumers.

> **IN PROGRESS — Chris is still enumerating.** Append rules as they arrive; keep each tagged.

## Tags

- **`[build]`** — apply while writing (UI/UX patterns, judgment calls). `develop` build-mode only.
- **`[verify]`** — mechanically checkable presence/absence; a `ship` pre-flight audit assertion.
- **`[both]`** — applied at build *and* audited at ship.
- **`[lint]`** — *should be an ESLint rule* (enforced on every save via the shared config). The house-style audit is only the **backstop** for forks that don't yet carry the rule — it does not re-implement the linter.

`develop`'s **house-style audit fix** (the `npm audit fix` twin) reads `[build]`/`[both]`/`[lint]` entries and rewrites existing code to conform. `ship`'s **house-style audit** (the `npm audit` twin) reads `[verify]`/`[both]` entries and reports/asserts — read-only. Anything it finds that needs code → hand to `develop`.

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

### `[both]` (conditional) Structured logging via `@chrismessina/raycast-logger`

**Condition:** the extension makes web requests (grep `fetch` / `axios` / `node-fetch` / `useFetch`).

**If yes:** `@chrismessina/raycast-logger` must be a dependency and imported (the `logger` used in the Copy-Error pattern above). Does **not** apply to extensions with no network calls — the audit must check the condition first, or it mis-fires on offline extensions.

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

## Still to enumerate

Chris has more. Append here as they arrive, tagging each:

- _(pending)_
