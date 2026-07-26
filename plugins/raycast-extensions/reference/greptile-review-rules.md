# Greptile review rules — reverse-engineered

What `greptile-apps[bot]` actually enforces on `raycast/extensions` PRs, derived from its
review output rather than from its (private) dashboard config. Consumed by
[`ship`](../skills/ship/SKILL.md)'s pre-flight, so its findings land *before* submission
instead of after.

> **Provenance.** Reconstructed 2026-07-26 from ~45 sampled `raycast/extensions` PRs
> (#27467–#29739), split across merged, open, and closed-unmerged. Greptile's rules are
> configured in its dashboard and are **not** in the repo — so Tier 1 below is what the bot
> *quoted back* in its own comment footers, not a copy of a config file. Tier 2 *is* a real
> file and is the closest thing to a public spec.

## The three gates, and which one actually kills PRs

A Store PR passes three independent gates. They fail for different reasons, and the loudest
one is the least fatal.

| Gate | Mechanism | Fails you for |
|---|---|---|
| **CI** | `changelog_enforcer`, `metadata_image_enforcer`, `npm_check`, Socket Security | Missing CHANGELOG entry, bad screenshot dimensions, dependency alerts |
| **Greptile Review** | A required check on every PR (`N files reviewed, M comments added`) | Code defects + the Tier 1 convention rules |
| **Maintainer** | `0xdhrv`, `pernielsentikaer`, `raycastbot` | **Duplication.** Then screenshot quality. Then everything else. |

**Greptile almost never kills a PR — it delays one.** PR #29605 merged with three open
**P1** comments; `0xdhrv` approved it the same day. What kills PRs is gate 3, and then the
stale bot. Budget your pre-PR effort accordingly: the duplication check below is worth more
than every code rule on this page combined.

---

## Tier 1 — confirmed custom rules (verbatim)

These are the only strings observed in Greptile's `Rule Used:` footers. Each is backed by a
`Knowledge Base Used:` line naming **Extension Authoring Conventions** (a second KB,
**Extensions Build & Publish Flow**, appears on packaging findings). Treat them as blocking —
they fire deterministically, every time, on every extension.

### R1. `Changelog entries must use {PR_MERGE_DATE}`

The single most-fired rule in the sample — it hit on #29738, #29605, #28997, #28932, #28875,
#28834, #29360, #29568, #29307. Greptile labels it **P1** and words the finding as
*"Merge Date Is Hard-Coded."*

```md
## [New Feature] - {PR_MERGE_DATE}     ✅
## [New Feature] - 2026-07-26          ❌  P1
```

Two sub-rules ride along, both observed as separate findings:

- New entries go at the **top** of the file.
- A first release is titled `[Initial Release]`, not `[Initial Version]` (#28997, #28834).

Already covered by house-style's *Never hand-invent a merge date* rule — the addition here
is that **Greptile flags it by name**, so it is not a stylistic preference you can argue.

### R2. `Don't manually define Preferences for getPreferenceValues()`

Fired on #28390, #28952, #29712, #29713, #28903. Greptile's stated reason is drift, not
style: the type is generated into `raycast-env.d.ts` at build time, so a hand-written copy
*keeps compiling* after the manifest changes.

It also flags the second-order defect this produces — a hand-written interface with a field
that **does not exist in `package.json`**, making the branch that reads it dead code
(#28952, `keepDisplayAwake`).

The same reasoning covers `Arguments`. Already a `[lint]` prohibition in
[`house-style.md`](house-style.md).

### R3. The standard Raycast Prettier config

Rule text begins `What: All extensions must use the standard Raycast…`. The config is
exactly:

```json
{ "printWidth": 120, "singleQuote": false }
```

Both failure modes fire:

- **`singleQuote` omitted** even when `printWidth` is right (#29725, #28942) — the rule wants
  the option *explicitly present*, not merely defaulting correctly.
- **Wrong `printWidth`** — `100` instead of `120` (#28448).

### R4. View commands must ship Store metadata screenshots

Worded as *"View Commands Lack Store Metadata."* Fires when `package.json` declares any
command with `"mode": "view"` and there is no `metadata/` directory with screenshots
(#29737, #29725, #29717, #28456). Screenshots living somewhere else — `media/`, `assets/`,
the README — do **not** satisfy it (#29737 shipped a `media/` screenshot and still failed).

Upstream's own wording, from `.github/copilot-instructions.md`:

> This extension needs a `metadata` folder with screenshots since it includes view commands.

Constraints that come from CI and the maintainer rather than Greptile, and that this rule is
usually found next to:

- **2000×1250 PNG**, enforced by `metadata_image_enforcer.yml` → `scripts/check_metadata_images.py`.
- **≤ 6 screenshots** (Store cap; not linted — a reviewer bounces it).
- **Real captures** from Raycast's *Capture Window* command. `0xdhrv` rejected #28448's
  screenshots as "not actual image capture[s] from Raycast," and asked #28907 to recapture.
- **README images live outside `metadata/`** — a PR-template checklist item.

---

## Tier 2 — the authored ruleset upstream publishes

`raycast/extensions/.github/copilot-instructions.md` is a maintained, machine-readable review
spec, and Tier 1's wording tracks it closely enough that it is almost certainly the source
text behind the *Extension Authoring Conventions* knowledge base. **It is public, so read it
rather than trusting this summary** — but these are the items with no Tier 1 evidence yet,
which means they are enforced by CI, Copilot, or a human instead:

| Rule | Detail |
|---|---|
| `launchCommand` in try/catch | Always. Unwrapped calls get a copy-pastable fix. |
| Lists/Grids use `isLoading` | `<List isLoading={isLoading}>`, never `{isLoading ? null : …}` — avoids empty-state flicker. |
| `getSelectedText()` guarded | try/catch **plus** a falsy check, each with its own failure toast. |
| Prefer `showFailureToast` | From `@raycast/utils`, over a hand-rolled `Toast.Style.Failure` in a catch. |
| Command `name` is immutable | It's the command's unique ID — ranking, aliases, and hotkeys are keyed to it. Change the `title` instead. |
| `author` changes get challenged | Any change to the field draws a "confirm this is intentional." |
| Multi-command extensions carry `subtitle` | Set it to the service name (usually `package.json` `title`). |
| `tools` require `ai.evals` | A `tools` array with no `ai.evals` block is incomplete. |
| US English only | No custom localization. Locale-dependent behavior goes through a preference dropdown. |
| `package-lock.json` only | `yarn.lock` / `bun.lock` / `pnpm-lock.yaml` are not allowed. |
| Official registry only | `https://registry.npmjs.org`. Check `.npmrc` for global *and* scoped overrides. |
| Title consistency | `CHANGELOG.md` and `README.md` headers match `package.json` `title`. |
| 100%-AI-generated PRs get flagged | Explicit instruction to call it out and ask for human review. |

---

## Tier 3 — the defect taxonomy that drives the score

Tier 1 fires on files; this is what fires on *logic*, and it is what separates a 5/5 from a
3/5. Greptile's inline comments are strikingly uniform in shape:

> **P1 · Title Case Noun Phrase**
> When ⟨specific user action or race⟩, ⟨this call⟩ ⟨does the wrong thing⟩, causing ⟨concrete
> user-visible consequence⟩.

It is looking for a **reachable path to a user-visible wrong state**, not for smells. It does
not flag naming, file layout, or test coverage. The classes it actually found, in the sample:

**Async lifecycle and cancellation** — the richest vein.
- A superseded/cached result settling state that belonged to an aborted request (#29708).
- Unmount during an in-flight request stranding a reservation nothing will release (#29708).
- Two concurrent readers both passing a read-only limiter before either arms it (#29703).
- Cleanup that must be in `finally`, not on the success path (#28932, #29728).
- Unhandled rejection in a *fallback* branch escaping command init (#29713).
- A loading gate that resolves on success but not on failure (#29662).

**State derived once and never refreshed** — a pushed view keeping its `entries` prop after a
mutation (#29725); a module-level cache the Refresh action doesn't clear (#28111); a parent
and a pushed child each opening their own WebSocket (#28834).

**Persistence and migration** — changing a dropdown's options without migrating values users
already have stored (#29738, the single richest finding in the sample: retired model IDs kept
being sent, *and* the hardcoded price table rendered `-1 cents`, *and* the retry actions still
referenced the retired IDs). Also: writing back a snapshot captured before a 15-second request
(#29605), and matching records on `id || address` so an edit can overwrite the wrong row
(#28834).

**Destructive or unconfirmed operations** — `rmSync` where `trash()` from `@raycast/api`
belongs, because there is no recovery path (#28390); replacing a user's whole config list on
a successful fetch with no confirmation, silently dropping hand-added entries (#29605);
deeplinks scoped so loosely they terminate a *newer* session than the one they own (#29717).

**Platform and shell reality** — GNU-only flags in a shell-out (`grep --include` on BSD/macOS)
failing silently into an empty result (#28448); `execFileSync`/`execSync` freezing the event
loop through a 2-second AppleScript dialog (#28456); invalid Windows shortcut key
capitalization (#29735).

**Auth and network** — a 401 that doesn't clear the stale OAuth token, producing a
revoked-token loop (#28932); picking the wrong credential from a multi-key map via a
first-non-empty fallback (#29605); N+1 requests inside a per-item loop (#28834).

**Defaults that lie** — an unknown value silently becoming a plausible constant (a missing
`context_length` saved as `128000`, so the failure surfaces far from its cause, #29605); a
sentinel like `-1` reaching the UI (#29738).

**Packaging** — generated data `.gitignore`d, so the Store bundle installs empty and the
in-app remediation tells users to clone the repo (#29734, the only *Extensions Build & Publish
Flow* KB citation in the sample); unused dependencies declared in `package.json` (#29735,
#29670); `eslint.config.js` not using `defineConfig` / the wrong ESM import form (#28987,
#28907, #28904); an executable statement between import blocks (#28952).

---

## Confidence score, decoded

Empirically the score is a **merge recommendation**, not a quality grade, and its justification
sentence names the specific blocker:

| Score | Observed meaning | Sample |
|---|---|---|
| **5/5** | "The PR appears safe to merge." Findings, if any, are nits. | Most merged PRs |
| **4/5** | Safe, *except* one named thing — or a sensitive area (crypto, custom parsers) flagged for a human second read. | #28429, #28111, #29703 |
| **3/5** | "The PR should not merge until X." At least one blocking defect, and the sentence names it. | #29725, #29717, #29713, #29737 |
| **2/5** | Multiple blocking defects across concerns. | #29738 |

Follow-up reviews are **scoped to prior threads** — the wording shifts to *"no blocking failure
remains within the scope of the previous review threads."* A 5/5 on round two does not mean the
whole PR was re-reviewed; it means what you were told to fix, you fixed.

**Comment severity** is a badge image, not text: `P1` (orange) = fix before merge, `P2`
(yellow) = should fix, `P3` = nit.

---

## What actually gets PRs rejected

Ranked by frequency in the closed-unmerged sample. **None of the top two is a code problem.**

### 1. Duplicating an extension that already exists — by far the top cause

Six of the sampled closed-unmerged PRs died here, every one of them with a 4/5 or 5/5 Greptile
score. The maintainer language is consistent:

> "We already have an extension in the Store that deals with this. Could we consider enhancing
> the existing extension below instead of creating another one?" — `0xdhrv` on #28456

> "Both extensions answer the same broad job… The extra pricing and discovery metadata is
> useful, but I'd consider it an enhancement to the existing Steam extension, not enough to
> justify a second Steam search extension." — `0xdhrv` on #28111

The test is **"the same broad job,"** not feature overlap. #28111 argued differentiation on
pricing and wishlist features and still lost; the counter-offer was to reposition as a
*dedicated price tracker* rather than a second general Steam search. Also seen on #28429
(2FA — "there are already several extensions in the store with that purpose"), #28903 (OCR),
#28952 (Coffee — "better to have a single extension for both macOS and Windows than two
separate ones"), and #29670 (JWT — closed in favor of adding commands to the existing JWT
Decoder).

**So: search the Store before writing a line of code, and if anything is close, decide up
front whether you are submitting a new extension or a PR to theirs.** If you submit anyway,
lead the PR description with the differentiation argument in *job* terms.

### 2. The stale bot

`stale.yml`: **25 days** of inactivity → stale label, **7 more** → auto-closed:

> "This pull request has been automatically closed due to inactivity."

Ten of the sampled closed PRs died this way, several after a maintainer left one question the
author never answered. Combined with `raycastbot`'s standing notice that initial review "may
take up to 15 business days," the window is tighter than it looks. **A Store PR is a
commitment to watch a thread for a month.**

### 3. Screenshot quality

Real Raycast captures, right dimensions, right padding. Rejected on #28448, revision requested
on #28907 and #28904.

---

## Pre-PR pipeline

Two halves, because the rules split cleanly into mechanical and judgment.

**Mechanical** — [`scripts/greptile-preflight.sh`](scripts/greptile-preflight.sh), run from
the extension root. Covers all of Tier 1 plus the checkable parts of Tier 2, and exits
non-zero on any `FAIL`:

```sh
bash "$CLAUDE_PLUGIN_ROOT/reference/scripts/greptile-preflight.sh"      # cwd = extension root
bash …/greptile-preflight.sh --path ~/Developer/GitHub/chrismessina/raycast-foo
```

`FAIL` = a Tier 1 rule or a CI gate, and it will be flagged. `WARN` = a heuristic that needs
your eyes — it does not exit non-zero, and some warnings are correct code.

**Judgment** — the script cannot see any of these, and they matter more:

- [ ] **Duplication.** Searched the Store; either nothing does this job, or the PR body argues
      the difference in job terms.
- [ ] **Availability.** You can respond to review for the next ~5 weeks.
- [ ] **Screenshots** are genuine *Capture Window* output, current with the commands that exist.
- [ ] **Every mutation refreshes what derives from it** — pushed views included.
- [ ] **Every in-flight request survives unmount and supersession** without stranding shared state.
- [ ] **Every changed preference/enum has a migration** for values users already stored.
- [ ] **Every destructive action is `trash()` or confirmed**, and scoped to what it owns.
- [ ] **Every unknown value fails loudly** rather than defaulting to a plausible constant.
- [ ] **Every shell-out is macOS-native** (BSD flags), and async.

## Gotchas

- **Greptile's rules are dashboard-side and can change without a commit.** Nothing in the repo
  pins them; this file is a snapshot of observed behavior with a date on it. Tier 2's file is
  the part that can be re-read — do that before trusting Tier 1 on a first submission.
- **A P1 is not a merge blocker.** #29605 merged with three open. Fix them anyway — but do not
  read a P1 as "this PR is dead," and do not let one stall a thread into the 25-day window.
- **A 5/5 on a follow-up review is scoped to the previous threads**, not to the whole PR. New
  code pushed alongside a fix may simply not have been looked at.
- **Greptile scored every duplicate-rejection PR in the sample at 4/5 or 5/5.** A clean bot
  review says nothing about whether the extension will be accepted.
- **`printWidth: 120` alone does not satisfy R3** — the config must also carry
  `"singleQuote": false` explicitly.
- **Don't "fix" a `.prettierrc` that's already standard.** Upstream's instructions say
  explicitly not to suggest changes to a conforming config.
