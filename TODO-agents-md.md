# Adding `AGENTS.md` to authored extensions

Shared brief. Written 2026-09-04 during the Windsurf sweep.

## Why

Chris decided 2026-09-02 that agentic support docs are **permitted and encouraged** in
extensions he authors, because they help other people's agentic contributions. The rule
is in
`/Users/messina/Developer/GitHub/chrismessina/raycast-extension-workflows/plugins/raycast-extensions/reference/my-extensions-mirror.md`
— read the "Agentic and supporting docs" section before writing anything.

`AGENTS.md` is the canonical name. `CLAUDE.md` and `WARP.md` do not ship.

## What NOT to write

The Windsurf sweep that prompted this found nine `.windsurf/rules/*.md` files across the
fleet. They collapse to four rules, and **three are already fleet policy** in
`/Users/messina/Developer/GitHub/chrismessina/raycast-extension-workflows/plugins/raycast-extensions/reference/house-style.md`:

| Rule | Already covered at |
| --- | --- |
| Never hand-define `Preferences`/`Arguments`; use Raycast's generated types | `house-style.md:77` |
| No `any` | `house-style.md:88` |
| `Toast.Style.Failure` + a "Copy Error" action | `house-style.md:193` |

**Do not restate fleet-wide house style in a per-extension `AGENTS.md`.** A rule copied
into sixteen files is sixteen places to drift. Link to `house-style.md` and move on.
Write only what is true of *this* extension and could not be guessed from the fleet rules.

The fourth rule — reader's "don't cast DOM elements from linkedom" — is genuinely
extension-specific. That is the shape to aim for.

## What TO write

Two files are the exemplars, both strong and both worth reading before you start:

- `/Users/messina/Developer/GitHub/chrismessina/raycast-digger/AGENTS.md`
- `/Users/messina/Developer/GitHub/chrismessina/raycast-reader/AGENTS.md`

What makes them good: they lead with **the mistake this codebase actually makes**, name
real files and real symbols, and describe mechanisms a newcomer would otherwise get
wrong. digger's opens with "the mistake this codebase makes most: reporting a failed
check as an empty one" and cites the six times it happened.

Aim for that. A generic "run npm run dev, the code is in src/" file is worse than nothing
— it costs a reader time and teaches them what they already assumed.

Structure that works:

1. One paragraph: what the extension does, in the user's terms.
2. **Before making changes** — the docs and vocabulary a contributor must read first.
3. **The trap** — the mistake this codebase invites. Ground it in real history: read
   `git log`, look for reverts, fixes-to-fixes, and commits whose message admits a
   previous one was wrong. If there is genuinely no recurring trap, say so and cut the
   section rather than inventing one.
4. **Architecture** — only the parts that are non-obvious from the file names.
5. **Commands** — `npm run dev` / `build` / `lint`, and whether tests exist.
6. A pointer to `house-style.md` for fleet-wide conventions. Do not inline them.

## Ground truth, not guesses

**Read the actual code before describing it.** Do not describe behaviour from the README,
from `package.json` alone, or from what the extension's name implies. Open `src/`, follow
the entry points listed in `package.json` `commands`, and read the modules they call.
Every claim in the file must be traceable to a symbol you actually read.

If you cite a file and line, verify the line says what you claim — a citation that
resolves but points at unrelated code is worse than none.

## Also do, in the same pass

- If the repo has a root `CLAUDE.md`, its content is the starting point for `AGENTS.md`.
  Migrate what is still true, drop what is stale, then `git rm` the `CLAUDE.md`.
- If the repo has a `.windsurf/` directory, delete it. Windsurf is dead and its rules are
  either fleet policy already or its own agent's system prompt. Check for anything
  genuinely unique first and say what you found before deleting.
- Do **not** add `AGENTS.md` to `raycast/extensions` in this pass. Mirror only.

## Standing rules

- Chris runs several agents against one checkout and **his uncommitted edits are sacred.**
  No `git add -A`, `git stash`, `git checkout --`, `git restore`, `git reset`. Stage by
  explicit path and assert the staged list before committing.
- Verify with raw pasted output, never an assertion that you checked.
- Commits are SSH-signed via 1Password. If signing fails, leave the work staged, say so
  in one line, and stop. Never `--no-gpg-sign`.
- Bubble up decisions rather than guessing.
