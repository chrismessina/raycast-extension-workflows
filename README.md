# raycast-extension-workflows

GitHub Actions workflows for keeping standalone Raycast extension repos in sync with the upstream [`raycast/extensions`](https://github.com/raycast/extensions) monorepo.

---

## Overview

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

Triggered on every push to `main` that touches `extensions/*/package.json`.

**What it does:**
1. Sparse-checks out only `extensions/*/package.json` files (fast — no full clone)
2. Diffs to find which extension package files changed
3. Reads the `name` field from each changed `package.json`
4. Derives the target standalone repo name (see naming convention below)
5. Checks the repo exists, then fires a `repository_dispatch` event to it

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

The dispatcher workflow fires on pushes to `chrismessina/extensions`, which is a fork of `raycast/extensions`. The fork needs to stay in sync with upstream for the chain to work.

Sync manually anytime with:

```sh
gh repo sync chrismessina/extensions
```

Or automate it by adding a scheduled workflow to `chrismessina/extensions`:

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

| Standalone repo | Monorepo directory | Notes |
|---|---|---|
| `chrismessina/raycast-store-updates` | `extensions/raycast-store-updates` | |
| `chrismessina/raycast-fathom` | `extensions/fathom` | |
| `chrismessina/raycast-at-profile` | `extensions/at-profile` | |
| `chrismessina/raycast-digger` | `extensions/digger` | |
| `chrismessina/raycast-get-app-icon` | `extensions/get-app-icon` | |
| `chrismessina/raycast-secret-browser-commands` | `extensions/secret-browser-commands` | |
| `chrismessina/raycast-reader` | `extensions/reader-mode` | `UPSTREAM_EXT_DIR` override set |

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
