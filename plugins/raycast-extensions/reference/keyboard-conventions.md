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

## `ray lint --fix` does not check the conflict invariant `[both]`

**A clean `ray lint` is NOT evidence that a panel is collision-free.** Nothing in `@raycast/eslint-plugin` checks whether two actions in one ActionPanel resolve to the same shortcut. You must assert it by reading the resolved panel.

What `prefer-common-shortcut --fix` actually does: it rewrites a shortcut whose **keys already equal** a `Common` member's into the named constant. That is a *spelling* change, not a behaviour change. So if `--fix` leaves you with two `Common.Copy` actions in one panel, **the collision was already there** — you had written `{cmd+shift+c}` by hand next to a `Common.Copy`, which is the same keys — and the fixer merely made it visible.

> **This is the trap, and it is a trap about you, not about the tool.** Writing an explicit `{ modifiers: ["cmd","shift"], key: "c" }` *feels* like you invented a distinct shortcut. It isn't: it's `Common.Copy` spelled out. The `Common` table below is the only way to know whether the combo you just typed is already taken. **Check every custom shortcut against the table before assigning it** — that's what prevents the collision, not avoiding `--fix`.
>
> Learned the hard way, 2026-07-13, on `reader-mode`: assigned Summarize `⌘S` (= `Common.Save`, already on "Save as Markdown") and Copy URL `⌘⇧C` (= `Common.Copy`, already on "Copy as Markdown"). Two collisions, both mine. `--fix` canonicalised them and I briefly blamed the linter.

**The one real `--fix` hazard** — narrow, and only on cross-platform extensions. `no-ambiguous-platform-shortcut` fires when `package.json` `platforms` has >1 entry AND a **single-form** shortcut carries **exactly one of `cmd` or `ctrl`** (`(hasCmd || hasCtrl) && !(hasCmd && hasCtrl)`) — so a bare `{cmd+s}` trips it just as `{ctrl+shift+c}` does. It's telling you *you* must declare both platforms.

But `prefer-common-shortcut` matches a single-form shortcut against *either* platform's binding (`macMatch || winMatch`), so `--fix` rewrites it to the `Common` constant — adopting that member's **other**-platform binding too, a choice you never made — and **the ambiguity warning silently disappears with it.** If you see that warning, **answer it yourself; don't let `--fix` answer it for you.**

**Practical rule for the audit-fix flow:** do the `Common` remap by semantics, by hand (per the contract below), checking each combo against the table. Run `ray lint` (no `--fix`) to check. If `--fix` did run, `git diff` the action files — not because it corrupts them, but because a green result tells you nothing about collisions.

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

---

## Action ORDER on an update `[verify]` — the append rule and when to refuse it

Greptile enforces a rule on every Store PR: *"New action panel actions should be appended."* It
has now fired twice on Chris's extensions **with opposite correct answers**, and the comment text
reads identically both times. Compliance-by-default is wrong half the time, so apply the test.

**The test: did the insertion change the Enter default?** That is the harm the rule protects
against — a silent change to the action a user gets by pressing Enter on a row they have pressed
Enter on a hundred times.

| Enter default changed? | Verdict |
| --- | --- |
| **Yes** — a new action became the first child | **FIX IT.** Append, and say so in the reply. |
| **No**, and the shifted actions carry explicit shortcuts | **Keep it**, and reply with the reasoning so the bot learns the exception. |

**Two receipts, same rule, same repo:**

- **Valid, fixed** (2026-08-27, PR #30529): setup actions were inserted at the top of
  `NotInstalledEmptyView`, making **View Setup Instructions** the Enter default. Genuine defect —
  order restored, and the reason is now a comment at
  `/Users/messina/Developer/GitHub/chrismessina/raycast-claude-artifacts/src/components/empty-views.tsx:24`.
- **Declined** (2026-08-28, PR #30626, P2 / non-blocking): `PinAction` was appended to the
  *primary* section at
  `/Users/messina/Developer/GitHub/chrismessina/raycast-claude-artifacts/src/search-artifacts.tsx:82`.
  `Action.OpenInBrowser` stayed the first child (`:68`), so Enter was unchanged; the two sections
  that shifted down a row are all shortcut-addressable (⌘⇧O, ⌘⇧G, ⌘⇧I).

**Why refusing matters — the remedy is not free.** "Appended" taken literally means *last in the
whole panel*. Any placement other than dead-last shifts something, so full compliance puts a
per-item action **below** whatever global or diagnostic actions the panel ends with. Trading a
permanent information-architecture regression for row-position stability on actions that have
keyboard shortcuts is the wrong trade.

**Appending to the primary SECTION is still appending.** The rule reads as though a panel were one
flat list. Where the panel is sectioned, an action that operates on the selected item belongs in
the section with the other per-item actions — nothing inside that section moved, and that is the
scope the rule should be measured against.

**Reply, don't just ignore.** Greptile's comment ends with *"reply to this and let me know. I'll
remember it for next time!"* — a reply tunes the rule across the whole fleet, so it stops firing on
appends-to-the-primary-section. **Posting it is Chris's call, not yours** (same standing rule as
never running `gh pr ready`): draft the reply, hand it to him.

**It works — this is not a theoretical courtesy.** On #30626 the reviewer replied to the posted
reasoning with *"I reconsidered it against the actual panel structure, and I'm withdrawing the
concern … No change is needed."* A declined finding left unanswered just re-fires on the next PR.
