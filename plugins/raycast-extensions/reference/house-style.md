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

### `[both]` Keyboard shortcuts use `Keyboard.Shortcut.Common`

Map ad-hoc shortcuts to `Common` by semantics; no conflicts within an ActionPanel. Full ruleset + conflict invariant + audit-fix contract: see [`keyboard-conventions.md`](./keyboard-conventions.md).

---

## Still to enumerate

Chris has more. Append here as they arrive, tagging each:

- _(pending)_
