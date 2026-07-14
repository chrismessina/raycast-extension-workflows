# Keyboard conventions

Map ad-hoc `Action` shortcuts to `Keyboard.Shortcut.Common` **by semantics**, and guarantee no two actions collide within an ActionPanel. Cited by `develop` (build-time + house-style audit-fix ruleset) and `ship` (the conflict invariant is a mechanical audit gate).

- **Authoritative source:** `COMMON_SHORTCUTS` in `node_modules/@raycast/eslint-plugin/dist/rules/prefer-common-shortcut.js` — this is the array the linter actually compares against, so it is ground truth in a way the prose docs are not. Regenerate the table with:
  ```bash
  node --input-type=commonjs -e '
    const src = require("fs").readFileSync("node_modules/@raycast/eslint-plugin/dist/rules/prefer-common-shortcut.js","utf8");
    const list = eval(src.match(/const COMMON_SHORTCUTS = (\[[\s\S]*?\n\]);/)[1]);
    for (const c of list) console.log(c.name, "|", c.macOS.modifiers.join("+")+"+"+c.macOS.key, "|", c.Windows.modifiers.join("+")+"+"+c.Windows.key);
  '
  ```
- **Last verified:** 2026-07-13 against `@raycast/eslint-plugin` (shipped with `@raycast/eslint-config` 2.2.0). The 2026-06-19 snapshot had **five wrong macOS bindings** (`CopyName`, `CopyPath`, `Duplicate`, `Pin`, `Remove`) — a wrong table causes the exact mis-mapping this file exists to prevent, so regenerate rather than trusting prose docs.
- **Drift guard:** re-run the command above whenever `@raycast/eslint-config` is bumped; if the set changed, update the table and bump "last verified".

---

## Two independent axes `[build]` (read this first)

Shortcut form is decided by TWO independent questions — do NOT conflate them:

1. **Does a `Common` member match the action's semantics?** Yes → use the `Common` constant (it's already platform-aware; never wrap it in a platform object). No → a custom shortcut is correct.
2. **For custom shortcuts only — what does `package.json` `platforms` say?** **Absent** → treat as macOS-only (Raycast's historical default; the field postdates Windows support). `["macOS"]` → plain `{ modifiers, key }` object. `["macOS","Windows"]` → platform-explicit `{ macOS: {...}, Windows: {...} }` (capital `Windows`; TS rejects lowercase). A bare `cmd`-only object on a cross-platform extension is silently broken on Windows.

| `platforms` | `Common` match | Write |
|---|---|---|
| absent (⇒ macOS) | Yes | `Keyboard.Shortcut.Common.X` |
| absent (⇒ macOS) | No | `{ modifiers: [...], key: "..." }` |
| macOS only | Yes | `Keyboard.Shortcut.Common.X` |
| macOS only | No | `{ modifiers: [...], key: "..." }` |
| macOS + Windows | Yes | `Keyboard.Shortcut.Common.X` |
| macOS + Windows | No | `{ macOS: {...}, Windows: {...} }` |

> **Absent ≠ cross-platform.** 7 of Chris's 34 extensions have no `platforms` field (`at-profile`, `google-books`, `ios-apps`, `raycast-fly`, `wayback-machine`, `craftdocs`, `quick-call`). An auditor that defaults absent → cross-platform flags a bogus defect on every one of them.

## The semantic map `[build]`

`Keyboard.Shortcut.Common` is platform-aware — use the constant, not an inline `{ modifiers, key }` object.

| Common constant | macOS | Windows |
|---|---|---|
| `Common.Copy` | ⌘ ⇧ C | ctrl shift C |
| `Common.CopyDeeplink` | ⌘ ⇧ C | ctrl shift C |
| `Common.CopyName` | ⌘ ⌥ C | ctrl alt C |
| `Common.CopyPath` | ⌘ ⌃ C | alt shift C |
| `Common.Save` | ⌘ S | ctrl S |
| `Common.Duplicate` | ⌘ ⇧ S | ctrl shift S |
| `Common.Edit` | ⌘ E | ctrl E |
| `Common.MoveDown` | ⌘ ⇧ ↓ | ctrl shift ↓ |
| `Common.MoveUp` | ⌘ ⇧ ↑ | ctrl shift ↑ |
| `Common.New` | ⌘ N | ctrl N |
| `Common.Open` | ⌘ O | ctrl O |
| `Common.OpenWith` | ⌘ ⇧ O | ctrl shift O |
| `Common.Pin` | ⌘ . | ctrl . |
| `Common.Refresh` | ⌘ R | ctrl R |
| `Common.Remove` | ⌃ D | ctrl D |
| `Common.RemoveAll` | ⌃ ⇧ D | ctrl shift D |
| `Common.ToggleQuickLook` | ⌘ Y | ctrl Y |

> **`Copy` and `CopyDeeplink` are the same keys** (⌘⇧C / ctrl⇧C). Choosing `CopyDeeplink` for a URL is a naming nicety, **not** a way to avoid colliding with a `Copy` in the same panel — it *is* a collision. Two copy actions in one panel means one of them needs a genuinely different binding.

### Disambiguation (pick the most precise)

- **Copy family:** generic value → `Copy`; deeplink / URL / Raycast command link → `CopyDeeplink` (same keys as `Copy` — see above); display label/title/name → `CopyName`; filesystem path → `CopyPath`.
- **Destructive:** single item → `Remove`; clear/remove all → `RemoveAll`.
- **List nav:** move selection down → `MoveDown`; up → `MoveUp`.
- **Create/open:** new entity → `New`; open in default view → `Open`; open with specific app/handler → `OpenWith`; toggle pin/favorite → `Pin`.
- **State:** persist changes → `Save`; clone → `Duplicate`; enter edit mode/form → `Edit`; refetch/reload → `Refresh`; toggle preview/detail popover → `ToggleQuickLook`.

**Prefer semantics over the current key combo.** If an action is logically a "Save" but has a non-standard shortcut, change it to `Common.Save`.

---

## The conflict invariant `[verify]` (ship's mechanical gate)

> Within a single **resolved** ActionPanel, no two actions resolve to the same shortcut.

"Resolved" means: include actions in nested `ActionPanel.Submenu`s and actions composed in from other components that render into the same panel. The naive failure: mapping two generic copies both to `Common.Copy` in one panel — semantically tidy, silently colliding.

Also note: the **first and second** actions in a panel auto-get the default primary/secondary shortcuts (List/Grid/Detail: `↵` and `⌘↵`; Form: `⌘↵` and `⌘⇧↵`). Don't assign a `Common` shortcut that duplicates those defaults on the same panel.

---

## 🚨 `ray lint --fix` BREAKS the conflict invariant `[both]`

**Never run `ray lint --fix` (or `eslint --fix`) on a file with shortcuts and assume the result is correct. Always `git diff` the action files afterward.**

The `@raycast/eslint-plugin` rule `prefer-common-shortcut` is `fixable: "code"`, and its autofixer rewrites **each `shortcut` attribute in isolation** — it has no idea what the sibling actions in the same `ActionPanel` are bound to. It will happily collapse two *distinct* shortcuts onto the *same* `Common.*` constant, producing a collision it then reports no error for. Two failure modes, both reproduced against `@raycast/eslint-config` 2.2.0 on 2026-07-13:

**1. It creates collisions.** Distinct shortcuts in one panel → same `Common`:

```tsx
// BEFORE — two actions, two distinct shortcuts
<Action.CopyToClipboard title="Copy as Markdown" shortcut={Keyboard.Shortcut.Common.Copy} />
<Action.CopyToClipboard title="Copy URL" shortcut={{
  macOS: { modifiers: ["cmd", "shift"], key: "c" },
  Windows: { modifiers: ["ctrl", "shift"], key: "c" },
}} />

// AFTER `eslint --fix` — both are Common.Copy. One action is now unreachable.
<Action.CopyToClipboard title="Copy as Markdown" shortcut={Keyboard.Shortcut.Common.Copy} />
<Action.CopyToClipboard title="Copy URL" shortcut={Keyboard.Shortcut.Common.Copy} />
```

**2. It silently changes which keys you press on macOS.** `findMatchingCommon` matches a single-form shortcut against *either* platform's binding (`macMatch || winMatch`), so a macOS `ctrl+shift+C` (literal **Control**) is "matched" to `Common.Copy` — whose macOS binding is `cmd+shift+C` (**Command**). Different physical keys, rewritten without comment:

```tsx
// BEFORE:  shortcut={{ modifiers: ["ctrl", "shift"], key: "c" }}   // ⌃⇧C on macOS
// AFTER:   shortcut={Keyboard.Shortcut.Common.Copy}                 // ⌘⇧C on macOS
```

**Consequence for the audit-fix flow:** do the `Common` remap **by semantics, by hand** (per the contract below), then run `ray lint` (no `--fix`) to *check*. If `--fix` has already run, re-derive every shortcut it touched — a clean lint run is not evidence the panel is collision-free, because the rule that rewrote them does not check for collisions at all.

---

## Audit-fix transformation contract `[both]`

When `develop` rewrites shortcuts to `Common`:

0. **Read `package.json` `platforms` FIRST.** Everything below depends on whether the extension is macOS-only or cross-platform. **An absent `platforms` field means macOS-only** — do not read it as cross-platform. An auditor that skips this step, or that defaults absent → cross-platform, mis-fires on Mac-only extensions and on the 7 extensions with no `platforms` field.
1. **Infer semantics** from each `<Action>`'s `title`, `icon`, `onAction`, and surrounding JSX/comments.
2. **If a `Common` member matches → replace with the `Common` constant** (and if it was a platform-explicit object wrapping that semantic, collapse it to the constant — `Common` is already platform-aware). **If NO `Common` matches → keep it custom, in the form `platforms` dictates:** plain `{ modifiers, key }` for macOS-only; `{ macOS: {...}, Windows: {...} }` (capital `Windows`) for cross-platform. Do NOT strip a platform-explicit object on a cross-platform extension — it's required there; a bare `cmd`-only shortcut breaks on Windows.
3. **Leave truly-custom shortcuts as-is** (only normalizing the object *shape* per axis 2 above) — do not force a `Common` where no semantic match exists. Do not invent `Common` names beyond the 17 above.
4. **Imports:** ensure `Keyboard` is imported from `@raycast/api`; extend the existing import line; introduce no unused imports.
5. **Verify the conflict invariant** after rewriting — a semantic remap can create a new collision.
6. Change only shortcuts — never action titles, behavior, or logic.

### Example

```tsx
// before
<Action title="Open" shortcut={{ modifiers: ["cmd"], key: "o" }} onAction={handleOpen} />
// after
<Action title="Open" shortcut={Keyboard.Shortcut.Common.Open} onAction={handleOpen} />
```
