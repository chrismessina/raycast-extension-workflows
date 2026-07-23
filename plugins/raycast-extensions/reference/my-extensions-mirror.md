# Mirror & submission topology (`author: chrismessina`)

How a `chrismessina`-authored extension gets from a local working repo to the
Raycast Store. Grounded in the Bookface v1.1 ship (2026-06-23) — the first time
this was done end-to-end and documented.

## The three repos

1. **Local working repo** — e.g. `~/Developer/GitHub/chrismessina/raycast-bookface`.
   Where you develop. Commits are SSH-signed via 1Password (see global CLAUDE.md).
2. **Standalone GitHub repo** — `github.com/chrismessina/raycast-<name>`. The public
   home of the extension's source. **This is the piece that is often MISSING** (see
   below) and whose absence breaks any sync automation.
3. **Monorepo fork** — `github.com/chrismessina/extensions` (a fork of
   `raycast/extensions`). PRs to the Store are opened from a branch here.

The published extension lives at `raycast/extensions/extensions/<name>/`.

## Sync direction — don't confuse the two

There are **two opposite flows**, and this doc's "submission flow" below is only one:

- **Outbound (submission):** your local work → `chrismessina/extensions` fork →
  PR → `raycast/extensions`. Manual; documented below.
- **Inbound (mirror sync):** `raycast/extensions/extensions/<dir>` → your standalone
  `chrismessina/raycast-<name>` repo, so the mirror reflects edits made upstream
  (including during PR review). **Automated** via the sync workflows — see the repo
  root `README.md` → "Sync workflows". As of 2026-07-15 the inbound dispatcher was
  rewritten and 5 more mirrors wired up; the one remaining gap is a scheduled
  fork-sync on `chrismessina/extensions` (see that README).

## Submission flow (outbound — what actually works, verified)

The reliable, manual flow for getting local work into the Store:

1. **Confirm the standalone repo exists.** `gh repo view chrismessina/raycast-<name>`.
   If it 404s, CREATE IT (see "Missing-mirror entry point").
2. **Verify local `main` == published v1.x** before trusting it as the baseline.
   Sparse-fetch the published dir and diff (see sparse-checkout-discipline.md). For
   Bookface they were byte-identical — local main genuinely was the published source.
3. **Push the local work** to the standalone repo's `main`.
4. **Sync the extension dir into the fork**: in a sparse checkout of the monorepo,
   copy ONLY the published file set (see "What ships" below) into
   `extensions/<name>/`, commit on a branch (`update/<name>-<topic>`), push to the
   `chrismessina/extensions` fork.
5. **Open the PR** `chrismessina:update/<name>-<topic>` → `raycast/extensions:main`.
6. **Cleanup** per pr-and-cleanup.md (track by PR head — squash-merge re-SHAs).

> **Direction note (updated 2026-07-15):** the "dispatcher / sync lag" the stub
> skill mentions is the **inbound** mirror-sync (upstream → standalone), NOT this
> outbound submission flow. Inbound automation IS live now (dispatcher rewritten,
> Bookface + 4 others wired up 2026-07-15) — see the repo root README. The
> **outbound** submission flow above has no automation and remains manual and
> canonical: do not assume a pipeline pushes your local work to the Store for you.

## Missing-mirror entry point (the case that threw the first ship)

If `gh repo view chrismessina/raycast-<name>` 404s, the standalone repo was never
created. Before anything else:

```bash
# from inside the local working repo, on the branch you intend to publish
gh repo create chrismessina/raycast-<name> --public --source=. --remote=origin \
  --description="<one-liner>" --push
```

This both creates the repo and wires `origin`, fixing the "no remote" state that
silently disables any future sync. THEN proceed with verify-baseline → fork-sync → PR.

## What ships (the published file set)

Copy ONLY these into `extensions/<name>/` — match the published v1.0's set exactly:

```
assets/  metadata/  src/
.gitignore  CHANGELOG.md  eslint.config.js  package-lock.json  package.json
README.md  tsconfig.json
```

**Do NOT ship** local-only artifacts even if tracked in the working repo:
`.github/docs/**` (review/findings docs, fixtures), `.github/assets/**` (icon
sources), `CLAUDE.md`. Use the published dir's file list as the allow-list, not a
blanket copy of the working repo.

## Assets gotcha (real, cost us a near-miss)

The monorepo's committed icons/screenshots are **Raycast-optimized (smaller)** than
the originals in the working repo. A naive copy re-introduces the larger originals,
bloating the PR with spurious binary diffs. Unless you are *intentionally* updating
imagery, **revert assets/ and metadata/ to the published versions** after syncing:

```bash
git checkout HEAD -- extensions/<name>/assets/ extensions/<name>/metadata/
```

Then the PR contains only real code/metadata changes.
