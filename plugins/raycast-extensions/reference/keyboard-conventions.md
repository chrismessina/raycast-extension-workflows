# Keyboard conventions

Map ad-hoc `Action` shortcuts to `Keyboard.Shortcut.Common` **by semantics**, and guarantee no two actions collide within an ActionPanel. Cited by `develop` (build-time + house-style audit-fix ruleset) and `ship` (the conflict invariant is a mechanical audit gate).

- **Authoritative source:** `docs/api-reference/keyboard.md` in `raycast/extensions`.
- **Last verified:** 2026-06-19 (snapshot below confirmed identical to live docs that day).
- **Drift guard:** if `develop` ever finds the live `Common` set has changed (new member, changed binding), update the table below and bump "last verified" — propose, then confirm, like `dep-gates.md`. Never trust this snapshot blind past its date.

---

## The semantic map `[build]`

`Keyboard.Shortcut.Common` is platform-aware — use the constant, not an inline `{ modifiers, key }` object.

| Common constant | macOS | Windows |
|---|---|---|
| `Common.Copy` | ⌘ ⇧ C | ctrl shift C |
| `Common.CopyDeeplink` | ⌘ ⇧ C | ctrl shift C |
| `Common.CopyName` | ⌘ ⇧ . | ctrl alt C |
| `Common.CopyPath` | ⌘ ⇧ , | alt shift C |
| `Common.Save` | ⌘ S | ctrl S |
| `Common.Duplicate` | ⌘ D | ctrl shift S |
| `Common.Edit` | ⌘ E | ctrl E |
| `Common.MoveDown` | ⌘ ⇧ ↓ | ctrl shift ↓ |
| `Common.MoveUp` | ⌘ ⇧ ↑ | ctrl shift ↑ |
| `Common.New` | ⌘ N | ctrl N |
| `Common.Open` | ⌘ O | ctrl O |
| `Common.OpenWith` | ⌘ ⇧ O | ctrl shift O |
| `Common.Pin` | ⌘ ⇧ P | ctrl . |
| `Common.Refresh` | ⌘ R | ctrl R |
| `Common.Remove` | ⌃ X | ctrl D |
| `Common.RemoveAll` | ⌃ ⇧ X | ctrl shift D |
| `Common.ToggleQuickLook` | ⌘ Y | ctrl Y |

### Disambiguation (pick the most precise)

- **Copy family:** generic value → `Copy`; deeplink / URL / Raycast command link → `CopyDeeplink`; display label/title/name → `CopyName`; filesystem path → `CopyPath`.
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

## Audit-fix transformation contract `[both]`

When `develop` rewrites shortcuts to `Common`:

1. **Infer semantics** from each `<Action>`'s `title`, `icon`, `onAction`, and surrounding JSX/comments.
2. **Replace** matching inline shortcuts with the `Common` constant; **remove** any platform-specific inline objects (e.g. `{ macOS: {...}, Windows: {...} }`) — the constant is already platform-aware.
3. **Leave truly-custom shortcuts as-is** — do not force a `Common` where no semantic match exists. Do not invent `Common` names beyond the 17 above.
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
