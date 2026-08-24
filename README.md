# raycast-extension-workflows

Chris's Raycast-extension tooling. This repo holds two things:

1. **The `raycast-extensions` Claude Code plugin** — lifecycle-stage skills (`scaffold` / `develop` / `ship` / `review-pr`) for building, modernizing, shipping, and reviewing Raycast extensions. See [Plugin](#plugin) below.
2. **GitHub Actions sync workflows** — keep standalone extension repos in sync with the upstream [`raycast/extensions`](https://github.com/raycast/extensions) monorepo. See [Sync workflows](#sync-workflows) below.

---

## Plugin

A Claude Code plugin (`plugins/raycast-extensions/`) whose skills are keyed to lifecycle **stages** (verbs), not roles (nouns), so their triggers don't overlap.

| Skill | Fires when | Owns |
|---|---|---|
| **`scaffold`** | "create / start a **new** extension" | Ideate (reuses `superpowers:brainstorming` + a Raycast-API overlay) and scaffold net-new. |
| **`develop`** | "change code", "migrate to ESLint 10 / new Node", "**bring this up to my house style**" | Feature/refactor, gated major dep migrations, and the **house-style audit fix** (retrofit existing code to House Style). Absorbs the former `raycast-extension-modernizer`. |
| **`ship`** | "submit / publish to the Store", "address review feedback" | Pre-flight (dep hygiene + **house-style audit** + weeding), Store-compliance gate, PR prep, review-feedback cycle, mirror-sync verification, post-merge cleanup. |
| **`review-pr`** | "review this PR", "run this fork locally", a pasted `raycast/extensions/pull/<N>` URL | Reviewing **someone else's** submission: resolve the contributor's fork and head branch, sparse-fetch only the touched extension, run it locally in Raycast, report findings. |

The `develop`↔`ship` handoff is two-way: if `ship`'s read-only audit or Store review feedback needs **code**, it hands back to `develop`. `review-pr` hands to `develop` the same way when reviewing surfaces a defect in your own extension.

Shared facts live in `plugins/raycast-extensions/reference/`: `house-style.md`, `keyboard-conventions.md`, `dep-gates.md`, `sparse-checkout-discipline.md`, `pr-and-cleanup.md`, `store-guidelines.md`, and `my-extensions-mirror.md` (which points back at the sync workflows below), plus an `eslint-rules/` directory.

> **Status:** v0.5.0 — all four skills are authored and in use; none are stubs. `ship` is the largest (~58 KB), then `develop` (~33 KB), `review-pr` (~18 KB), `scaffold` (~7 KB). The version that matters is the matched pair `plugins/raycast-extensions/.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json`, both `0.5.0`; the root `package.json` version governs nothing. Original design spec (historical, predates `review-pr`): [`docs/specs/2026-06-19-raycast-extensions-plugin-design.md`](docs/specs/2026-06-19-raycast-extensions-plugin-design.md).
>
> When this block and the files disagree, **the files win** — a stale "ship is a stub" note here once misrouted an agent shipping `claude-artifacts`. See [`CLAUDE.md`](CLAUDE.md).

### Install (local, for development)

Add the repo as a local-path marketplace, then install the plugin from it:

```sh
claude plugin marketplace add ~/Developer/GitHub/chrismessina/raycast-extension-workflows
claude plugin install raycast-extensions@raycast-extension-workflows
```

(Or use the `/plugin` menu: Browse marketplaces → add local path → install.) Restart Claude Code afterward so the skills load.

The marketplace `source` points at this repo directory, so the repo is the source of truth — but **install copies the plugin into a version-keyed cache** (`~/.claude/plugins/cache/<marketplace>/raycast-extensions/<version>/`). It is **not** a live symlink: editing the repo does not update the running plugin until you refresh the cache.

### Iterating

The edit loop has a refresh step:

```sh
# 1. edit  plugins/raycast-extensions/skills/*/SKILL.md  (or reference/*.md)
# 2. refresh the cache from this repo's source
claude plugin marketplace update raycast-extension-workflows
# 3. apply (restart required)
claude plugin update raycast-extensions   # then restart Claude Code
```

For a body edit to an existing skill, step 2 + a restart is usually enough. **When you add a new skill folder or make a substantive change, bump `version` in `plugins/raycast-extensions/.claude-plugin/plugin.json`** (and the marketplace entry) so the version-keyed cache invalidates cleanly — same-version refreshes can be sticky. `claude plugin tag` creates a `raycast-extensions--v{version}` git tag and validates that `plugin.json` and the marketplace entry agree.

Commit + push is the save point, not the deploy step.

---

## Sync workflows

### Overview

The Raycast extensions monorepo is the source of truth for all published extensions. When you maintain an extension in a standalone repo (e.g. `chrismessina/raycast-fathom`), changes merged upstream — by you or a contributor — won't automatically appear in your repo. This setup solves that.

### How it works

```
raycast/extensions (upstream monorepo)
        │
        │  gh repo sync (automatic or manual)
        ▼
chrismessina/extensions (fork)
        │
        │  dispatch-sync.yml fires on push to main
        │  reads changed extensions/*/package.json
        │  derives target standalone repo name
        │  sends repository_dispatch → upstream-sync
        ▼
chrismessina/raycast-{name} (standalone repo)
        │
        │  sync-from-upstream.yml receives event
        │  fetches extension files via GitHub API
        │  commits changes to main
        ▼
your local clone (git pull to get changes)
```

There is no full clone of the monorepo at any point. Files are fetched directly via the GitHub API.

---

## Workflows

### `sync-from-upstream.yml` — goes in each standalone repo

Triggered by a `repository_dispatch` event from the fork, or manually via `workflow_dispatch`.

**What it does:**
1. Checks out the standalone repo
2. Reads the `name` field from `package.json` to determine which monorepo directory to fetch
3. Recursively downloads all files from `raycast/extensions/extensions/{name}/` via the GitHub API
4. Commits and pushes any changes to `main`, referencing the upstream PR number if available

**Required secrets:** none — uses the built-in `GITHUB_TOKEN`.

### `dispatch-sync.yml` — goes in `chrismessina/extensions` (the fork)

Triggered on every push to `main` that touches `extensions/*/package.json` (i.e.
whenever the fork syncs upstream). Also runnable manually via `workflow_dispatch`
(with an optional `force_all` input that re-dispatches to every mapped repo).

**What it does:**
1. Sparse-checks out only `extensions/*/package.json` files (fast — no full clone)
2. Diffs to find which **top-level** `extensions/<dir>/package.json` files changed
3. Keeps only the dirs present in `MIRROR_MAP` (the allow-list of extensions we mirror)
4. Looks up each dir's standalone repo via `MIRROR_MAP` (handles renames like
   `reader-mode` → `raycast-reader`)
5. Checks the repo exists, then fires a `repository_dispatch` event carrying the
   monorepo dir as `client_payload.ext_name`

**Why an explicit `MIRROR_MAP` instead of deriving the name (rewritten 2026-07-15):**
The original derived `chrismessina/raycast-<name>` by convention. Two bugs made it
dead since 2026-02-27:
- **Renamed extensions broke:** `reader-mode` derived `raycast-reader-mode` (404) and
  silently skipped — the real repo is `raycast-reader`. There was no dir→repo map.
- **The whole loop aborted:** it iterated *every* changed extension in the monorepo
  (~2000 on a fork-sync) and died (`exit 2`) on a nested/deleted
  `vendor/*/package.json` in someone else's extension, so nothing after it dispatched.

The allow-list fixes both: only your dirs are considered, nested/deleted files are
ignored, and renames are explicit. **Keep `MIRROR_MAP` in lockstep with the
"Currently synced repos" table above.**

**Required secret in `chrismessina/extensions`:** `DISPATCH_PAT` — a fine-grained PAT with **Actions: Read and write** access scoped to all `chrismessina/raycast-*` repos.

---

## Repo naming convention

| package.json `name` | Monorepo directory | Standalone repo |
|---|---|---|
| `fathom` | `extensions/fathom` | `chrismessina/raycast-fathom` |
| `at-profile` | `extensions/at-profile` | `chrismessina/raycast-at-profile` |
| `raycast-store-updates` | `extensions/raycast-store-updates` | `chrismessina/raycast-store-updates` |

**Rule:** target repo = `chrismessina/raycast-{name}`, unless `name` already starts with `raycast-`, in which case target = `chrismessina/{name}`.

### When the repo name doesn't match the monorepo directory

Some extensions have a `package.json` name that differs from their monorepo directory. For example, `chrismessina/raycast-reader` maps to `extensions/reader-mode` in the monorepo.

Handle this by setting the `UPSTREAM_EXT_DIR` env var at the top of `sync-from-upstream.yml`:

```yaml
env:
  UPSTREAM_EXT_DIR: "reader-mode"
```

The precedence for resolving the monorepo directory is:
1. `repository_dispatch` payload `ext_name` field (set automatically by the dispatcher)
2. `workflow_dispatch` input `ext_dir`
3. `UPSTREAM_EXT_DIR` env var in the workflow file
4. `name` field from `package.json`

---

## One-time setup

### 1. Create a DISPATCH_PAT

Go to [GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens](https://github.com/settings/tokens?type=beta) and create a token with:

- **Resource owner:** `chrismessina`
- **Repository access:** All repositories (or select your `raycast-*` repos explicitly)
- **Permissions:** Repository permissions → **Actions: Read and write**

Add it as a secret named `DISPATCH_PAT` in `chrismessina/extensions`:
Settings → Secrets and variables → Actions → New repository secret

### 2. Keep the fork in sync with upstream

The dispatcher fires on pushes to `chrismessina/extensions` (a fork of
`raycast/extensions`). **Nothing dispatches unless the fork receives upstream
commits**, so the fork must be kept synced for the whole chain to run hands-off.

> **Gap found 2026-07-15:** the fork has **no scheduled fork-sync workflow
> deployed.** Its upstream merges currently come from GitHub's native "Sync fork"
> (manual button or an ad-hoc `gh repo sync`). Until the scheduled workflow below is
> added, remote mirrors only refresh when you manually sync the fork. This is the
> last piece of full automation still missing.

Sync manually anytime with:

```sh
gh repo sync chrismessina/extensions
```

To close the gap, add this scheduled workflow to `chrismessina/extensions`
(`.github/workflows/sync-fork.yml`):

```yaml
name: Sync fork with upstream
on:
  schedule:
    - cron: "0 * * * *"  # every hour
  workflow_dispatch:

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - run: gh repo sync chrismessina/extensions --source raycast/extensions
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Each hourly sync that lands a change to a mirrored `extensions/<dir>/package.json`
triggers `dispatch-sync.yml`, which fans out to the standalone repos.

---

## Adding sync to a new extension repo

### Prerequisites
- Your extension is published to `raycast/extensions` and you are listed as `author` in its `package.json`
- You have a standalone repo at `chrismessina/raycast-{name}` (or `chrismessina/{name}` if name starts with `raycast-`)

### Steps

**1. Copy the workflow into the standalone repo:**

```sh
cp /path/to/sync-from-upstream.yml .github/workflows/sync-from-upstream.yml
```

Or copy it directly from this repo:

```sh
mkdir -p .github/workflows
curl -fsSL https://raw.githubusercontent.com/chrismessina/raycast-extension-workflows/main/sync-from-upstream.yml \
  -o .github/workflows/sync-from-upstream.yml
```

**2. If your repo name doesn't match the monorepo directory**, set `UPSTREAM_EXT_DIR` near the top of the workflow:

```yaml
env:
  UPSTREAM_EXT_DIR: "your-monorepo-dir-name"
```

**3. Commit and push:**

```sh
git add .github/workflows/sync-from-upstream.yml
git commit -m "Add upstream sync workflow"
git push
```

**4. Test it manually:**

```sh
gh workflow run sync-from-upstream.yml --repo chrismessina/your-repo-name
```

No changes to `chrismessina/extensions` are needed — the dispatcher automatically skips repos that don't exist, and will start dispatching to your new repo as soon as it detects it.

---

## Currently synced repos

This table is the source of truth and **must stay in sync with `MIRROR_MAP` in
`dispatch-sync.yml`** — the dispatcher only fires for extensions listed there.

| Standalone repo | Monorepo directory | Notes |
|---|---|---|
| `chrismessina/raycast-store-updates` | `extensions/raycast-store-updates` | dir already `raycast-`-prefixed |
| `chrismessina/raycast-fathom` | `extensions/fathom` | |
| `chrismessina/raycast-at-profile` | `extensions/at-profile` | |
| `chrismessina/raycast-digger` | `extensions/digger` | |
| `chrismessina/raycast-get-app-icon` | `extensions/get-app-icon` | |
| `chrismessina/raycast-secret-browser-commands` | `extensions/secret-browser-commands` | |
| `chrismessina/raycast-reader` | `extensions/reader-mode` | `UPSTREAM_EXT_DIR` override set; dir ≠ repo name |
| `chrismessina/raycast-bookface` | `extensions/bookface` | added 2026-07-15 |
| `chrismessina/raycast-luma` | `extensions/luma` | added 2026-07-15 |
| `chrismessina/raycast-tesla-energy` | `extensions/tesla-energy` | added 2026-07-15 |
| `chrismessina/raycast-trimmy` | `extensions/trimmy` | added 2026-07-15 |
| `chrismessina/raycast-wrap-unwrap` | `extensions/wrap-unwrap` | added 2026-07-15 |
| `chrismessina/raycast-karakeep` | `extensions/karakeep` | contributed-to (author `luolei`); Chris maintains the mirror |

**Not synced (self-authored but not in the public monorepo):** `airbuddy`, `fetch`,
`google-maps`, `happenstance`, `ios-apps`, `memory-store`, `openskills`,
`parallel-web-tools`, `sora`, `threads-client`. These 404 at
`raycast/extensions/extensions/<name>`, so `sync-from-upstream` would fail every run.
Add them to the table + `MIRROR_MAP` only once they're published upstream.

**Not an extension:** `raycast-logger` is a published npm package
(`@chrismessina/raycast-logger`), not a Store extension — no upstream dir to sync.

---

## Troubleshooting

**Dispatcher fires but sync doesn't run**
Check that the repo name matches the convention. The dispatcher logs which repo it's targeting — check the Actions log in `chrismessina/extensions`.

**Sync runs but downloads wrong files**
The `name` field in your standalone repo's `package.json` may not match the upstream monorepo directory. Set `UPSTREAM_EXT_DIR` in the workflow.

**`DISPATCH_PAT` errors**
The PAT may have expired or have insufficient scope. Regenerate it with Actions: Read and write access and update the secret in `chrismessina/extensions`.

**Fork is behind upstream**
Run `gh repo sync chrismessina/extensions` to bring it up to date, which will trigger the dispatcher for any newly changed extensions.
