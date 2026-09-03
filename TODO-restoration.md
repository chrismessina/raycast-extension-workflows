# Restoration chores — undoing the 2026-08-01 blind sync

Six mirrors lost local-only formatting conventions when the blind `sync-from-upstream`
workflow first ran. All six now run the safe workflow, so restored work will stick.

## Status — 2026-09-02

| Repo | State | Commit |
| --- | --- | --- |
| `at-profile` | done — 16 `src/` files re-sorted | `1f770d98` |
| `bookface` | done — 12 `src/` files | `0d0f8e2c` |
| `tesla-energy` | done — 3 `src/` files | `6c40f5bb` |
| `trimmy` | done — 3 `src/` files | `a1815e02` |
| `wrap-unwrap` | done; README rebuild + LICENSE + `media/` in progress | `f62b277f` |
| `fathom` | **PARKED** — Chris is mid-feature, see below | — |

Verified against each remote (`HEAD`, signature, `package.json` devDependency, and the
`.prettierrc` plugin block), not on the agents' reports.

**`fathom` is parked deliberately.** `git pull --ff-only` refuses — 13 of its 27 dirty
files collide — and `package.json`/`package-lock.json` carry an unrelated in-flight
download feature (`@chrismessina/raycast-download`, `raycast-kit`, a `copy-runner` build
step, two new preferences, six untracked source files). Staging the lockfile would sweep
that whole feature into a formatting commit, and `git add -p` cannot split a lockfile.
Chris will land the download work first; then this is nearly a no-op, because fathom's
local checkout already holds the sorted state. **Do not touch fathom until he says so.**

### Two corrections this work produced

- **`bookface` failed differently.** Its remote did NOT revert `.prettierrc` — it stripped
  the plugin from `package.json`/`package-lock.json` and left `.prettierrc` still pointing
  at it. A config/dependency mismatch masked by a stale `node_modules` copy: clean locally,
  broken on any fresh checkout or CI run. Check that seam, not just the config file.
- **"`npm install` only if absent from `node_modules`" (below) is wrong** and three agents
  correctly worked around it. The blind sync stripped the *lockfile* entries while
  `node_modules` stayed populated, so that test says "don't reinstall" while the lock still
  needs reconciling. Use `npm install --package-lock-only`: it fixes the lock without
  touching the install tree.

Full incident audit: https://claude.ai/code/artifact/74d9d8ba-942a-49a9-9dd2-ae73787b557e
Fleet context: `/Users/messina/Developer/GitHub/chrismessina/raycast-extension-workflows/plugins/raycast-extensions/reference/my-extensions-mirror.md`

## The state — verified 2026-09-02, do not assume otherwise

**The revert only ever landed on the REMOTE.** Every local checkout is 3–4 commits
*behind* `origin/main` and still holds the pre-revert `.prettierrc` and the
`@ianvs/prettier-plugin-sort-imports` devDependency. So this is not "re-apply the config
from scratch" — it is "sync to the reverted remote, then put the convention back."

Naively `git pull` and the merge takes the remote's revert, because the local side has no
competing change to that file. The config must be re-applied *after* syncing.

| Repo | behind | uncommitted (NOT yours to touch) |
| --- | --- | --- |
| `raycast-at-profile` | 4 | `README.md`, `TODO.md`, `.github/FUNDING.yml`, `CLAUDE.md` |
| `raycast-bookface` | 3 | `README.md`, `.github/FUNDING.yml`, `.github/docs/*` |
| `raycast-fathom` | 4 | 27 files incl. `README.md`, `CHANGELOG.md`, `LICENSE`, `docs/*` |
| `raycast-tesla-energy` | 3 | `.github/FUNDING.yml` |
| `raycast-trimmy` | 3 | `README.md`, `.github/FUNDING.yml` |
| `raycast-wrap-unwrap` | 3 | `.github/FUNDING.yml` |

All six are on `main`.

## The target `.prettierrc` — authoritative, type it exactly

```json
{
  "printWidth": 120,
  "singleQuote": false,
  "plugins": ["@ianvs/prettier-plugin-sort-imports"],
  "importOrder": ["<BUILTIN_MODULES>", "<THIRD_PARTY_MODULES>", "^@raycast/(.*)$", "^[.]"]
}
```

`@ianvs/prettier-plugin-sort-imports` must be in `devDependencies` at `^4.7.0`. Config and
dependency are a matched pair — Prettier fails to load the plugin without it, and every
format run errors. Rule: `/Users/messina/Developer/GitHub/chrismessina/raycast-extension-workflows/plugins/raycast-extensions/reference/house-style.md`

## Per repo

1. `git fetch origin && git pull --ff-only`. If it refuses because a dirty file would be
   overwritten, **STOP and report** — do not force, stash, or check out.
2. Restore `.prettierrc` to the block above; ensure the devDependency; `npm install` only
   if the dependency is genuinely absent from `node_modules`.
3. `npx prettier --write "src/**/*.{ts,tsx}" .prettierrc package.json`
4. Verify, and paste raw output: `npx tsc --noEmit`, `npm run lint`, `npm run build`.
5. Stage **by explicit path** — only `.prettierrc`, `package.json`, `package-lock.json`,
   and the `src/` files Prettier reformatted. Assert the staged list before committing.
6. Commit (SSH-signed via 1Password) and push to `main`.

### `raycast-wrap-unwrap` — one extra

`c2272860` also stripped the README social-badge block added 2026-07-27. Restore it, but
conform to the current template, which is the single source of truth as of `792f0f8`:
`/Users/messina/Developer/GitHub/chrismessina/raycast-extension-workflows/plugins/raycast-extensions/reference/readme-template.md`

`README.md` is **not** dirty in wrap-unwrap, so it is safe to edit. Recover the old block
from `git show c2272860^:README.md` and reconcile it against the template rather than
pasting it back verbatim.

## Not in scope

- **Do not push anything to `raycast/extensions`.** These conventions are local-only by
  design; that is *why* the blind sync reverted them. No Store PR.
- `domainr` is NOT on this list. Its "revert" was the rename to *Fastly Domain Search*,
  which is the wanted state.
- `google-books` and `secret-browser-commands` lost real code, not formatting. Parked
  deliberately — do not attempt those here.
- Do not add `AGENTS.md`, `TODO.md`, or `docs/` to any extension as part of this work.

## Standing rules

- Chris runs several agents against one checkout and **his uncommitted edits are sacred.**
  No `git add -A`, `git stash`, `git checkout --`, `git restore`, `git reset`. If a
  command dirties the tree (a lockfile rewrite from `npm install`), say so and leave it.
- If 1Password is locked, `git commit` fails to sign. Leave the work **staged** and say
  so in one line. Never `--no-gpg-sign`.
- Bubble up anything needing a decision instead of guessing.
