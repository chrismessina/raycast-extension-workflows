# Fleet punchlist — audited 2026-07-26

Findings from auditing all 40 local `raycast-*` repos against the House Style checklist
and the failure classes surfaced by the wrap-unwrap review campaign (PR
[raycast/extensions#29727](https://github.com/raycast/extensions/pull/29727), merged
2026-07-26).

**How to read this.** Every item was grepped against the live tree and spot-checked;
false positives were removed rather than listed with a hedge. Counts are file or
occurrence counts as noted. Nothing here has been fixed — this is backlog input.

The one caveat worth stating up front: **these are static findings, not reproductions.**
Unlike the wrap-unwrap defects, I did not run any of these extensions to confirm
user-visible breakage. P1 below is near-certain from the code alone (a `cmd` modifier
does not exist on Windows); the rest are convention gaps whose real-world impact varies.

---

## P1 — Broken on Windows: bare `cmd` shortcuts on cross-platform extensions

Each of these declares `"platforms": ["macOS", "Windows"]` in `package.json` but binds
shortcuts with a bare `{ modifiers: ["cmd"], … }`. **`cmd` does not exist on Windows**,
so these shortcuts are silently dead there — the action is unreachable by keyboard.

Fix: use `Keyboard.Shortcut.Common.X` where a member matches the action's semantics
(it is already platform-aware), or the explicit `{ macOS: {...}, Windows: {...} }` form
where none does. See
`/Users/messina/Developer/GitHub/chrismessina/raycast-extension-workflows/plugins/raycast-extensions/reference/keyboard-conventions.md`.

| Extension | Bare `cmd` shortcuts | Uses `Common`? |
| --- | ---: | --- |
| `raycast-karakeep` | 31 | none |
| `raycast-craft` | 17 | none |
| `raycast-fathom` | 11 | 14 — partial adoption, finish it |
| `raycast-sora` | 5 | none |
| `raycast-fetch` | 4 | — |
| `raycast-digger` | 3 | — |
| `raycast-luma` | 3 | — |
| `raycast-threads-client` | 2 | — |
| `raycast-trimmy` | 2 | — |
| `raycast-word-count` | 2 | — |
| `raycast-domainr` | 1 | — |
| `raycast-google-maps` | 1 | — |
| `raycast-memory-store` | 1 | — |
| `raycast-reader` | 1 | — |
| `raycast-store-updates` | 1 | — |
| `raycast-tesla-energy` | 1 | — |

**Start with `karakeep` and `craft`** — highest counts, zero `Common` adoption, so they
need a full pass rather than a touch-up. `fathom` is the cheapest win: it already uses
`Common` in 14 places, so 11 stragglers are inconsistency rather than unfamiliarity.

**Verify before fixing:** re-check each `package.json` — an extension with **no**
`platforms` key is macOS-only by Raycast's historical default, and a bare `cmd` there is
correct, not a defect. Every row above was confirmed to declare `Windows` explicitly.

---

## P2 — Failure toasts with no "Copy Error" action

House Style: every `Toast.Style.Failure` carries a `primaryAction` titled "Copy Error"
that copies the message to the clipboard. Without it a user who hits an error has no way
to report it except retyping from a toast that auto-dismisses.

**No copy affordance at all** (neither a Copy Error action nor `showFailureToast`):

| Extension | Files with a failure toast |
| --- | ---: |
| `raycast-fathom` | 4 |
| `raycast-google-maps` | 4 |
| `raycast-sora` | 4 |
| `raycast-threads-client` | 5 |
| `raycast-parallel-web-tools` | 3 |
| `raycast-craftdocs` | 2 |
| `raycast-google-books` | 2 |
| `raycast-memory-store` | 2 |
| `raycast-quick-call` | 2 |
| `raycast-store-updates` | 2 |
| `raycast-at-profile` | 1 |
| `raycast-change-case` | 1 |
| `raycast-luma` | 1 |
| `raycast-screenocr` | 1 |
| `raycast-secret-browser-commands` | 1 |
| `raycast-trimmy` | 1 |

**Partially mitigated** — these route some failures through `@raycast/utils`
`showFailureToast`, which is better than a bare toast but still not the House Style
Copy-Error shape:

- `raycast-craft` — 11 files with a raw failure toast, 15 using `showFailureToast`
- `raycast-ios-apps` — 15 files with a raw failure toast, 14 using `showFailureToast`

Cheapest path: lift the `failureToast(title, message)` helper from
`/Users/messina/Developer/GitHub/chrismessina/raycast-wrap-unwrap/src/lib/pipeline.ts:65-77`
into each extension. It is ~12 lines and makes the rule impossible to violate at the call
site.

---

## P2 — Hand-defined `Preferences` / `Arguments` interfaces

Raycast auto-generates these ambient types into `raycast-env.d.ts` from `package.json`.
A hand-written duplicate drifts the moment a preference is added or renamed, and the
drift is invisible until runtime.

`raycast-fetch` (3) · `raycast-sora` (2) · `raycast-digger` (1) · `raycast-ios-apps` (1) ·
`raycast-karakeep` (1) · `raycast-memory-store` (1) ·
`raycast-secret-browser-commands` (1) · `raycast-threads-client` (1)

---

## P3 — `any` casts

`raycast-parallel-web-tools` (6) · `raycast-craftdocs` (2) · `raycast-airbuddy` (1) ·
`raycast-bookface` (1) · `raycast-central-icon-system` (1) · `raycast-kit` (1)

Low count fleet-wide, so this is close to done. Worth clearing while touching each file
for the items above rather than as its own pass.

---

## P3 — No test suite at all

Only **6 of 40** extensions have any tests:

`raycast-happenstance` (12 files) · `raycast-central-icon-system` (6) ·
`raycast-wrap-unwrap` (6) · `raycast-memory-store` (1) · `raycast-reader` (1) ·
`raycast-word-count` (1)

Not a defect on its own — most of these extensions are thin API wrappers where a test
suite would test the API, not the code. **The ones worth tests are the ones with pure
transformation logic**, since that is where wrap-unwrap's bugs lived: `raycast-trimmy`,
`raycast-change-case`, `raycast-word-count`, and `raycast-screenocr` all transform text
with no network dependency, which is the exact shape that unit-tests cheaply.

---

## Accumulator / quadratic risk — audited, essentially clean

This is the class that produced the wrap-unwrap campaign, so I searched for all three
shapes specifically. **The fleet is in good shape here** and needs no backlog item:

- **Rescan of prior output inside a loop** (`[...arr].reverse().find(…)`) — three hits in
  `raycast-craft`, all on fixed-size UI arrays being rendered, none in a per-line loop.
  Not defects.
- **`.slice()` on a growing accumulator** — one real accumulator found outside
  wrap-unwrap: `raycast-fetch`'s `stderrBuffer`
  (`/Users/messina/Developer/GitHub/chrismessina/raycast-fetch/src/lib/downloader.ts:87-119`).
  **It is already correct** — it trims to a 1024-char tail once it passes 4096, with a
  comment naming the O(n²) hazard by name. Nothing to do.
- **Anchored regex against an accumulator** — all hits are validators against short
  fixed strings (filenames, slugs, numeric tokens). Not defects.

`raycast-brew`'s `message +=` in `utils/errors.ts` is three fixed appends with no loop —
a false positive from the initial grep.

**Only `raycast-wrap-unwrap` has elapsed-time perf guards.** That is correct for now:
nothing else in the fleet accumulates across an unbounded user-supplied input. Add one
the moment another extension starts doing so. Background:
`/Users/messina/Developer/GitHub/chrismessina/raycast-extension-workflows/docs/solutions/design-patterns/quadratic-accumulator-paths-in-text-reflow.md`

---

## Suggested order

1. **`raycast-karakeep`** — 31 broken Windows shortcuts + a hand-defined `Preferences`.
   Worst single-extension state in the fleet.
2. **`raycast-craft`** — 17 broken shortcuts + 11 files needing Copy-Error.
3. **`raycast-fathom`** — 11 stragglers on shortcuts it already half-converted, plus 4
   Copy-Error files. Cheapest ratio of fix-to-value.
4. **`raycast-sora`**, **`raycast-threads-client`** — each hits three categories.
5. Sweep the single-occurrence items opportunistically when a repo is open for another
   reason, rather than as a dedicated pass.

Each of these is a `raycast-extensions:develop` job (they change code), and each should
exit through `ship` — every one of these extensions is published.
