# HANDOFF — roll the safe upstream sync out to the remaining 18 mirrors

**Written 2026-08-29** by the session that shipped `claude-artifacts` v1.3 (Store PR
[#30626](https://github.com/raycast/extensions/pull/30626)) and, while doing the post-merge
reconcile, found the fleet split in two. Every number and every file path below was verified
against the live tree that day — re-verify before acting, and see **Traps** for exactly which
checks lie to you.

---

## STATUS as of 2026-09-02 — read this before acting on anything below

Three things changed. The Traps section is unaffected and still the most useful part.

1. **The BLOCKING question is resolved.** The deletion pass was ported into the safe
   workflow, so the rollout no longer trades one correctness property for another. A path
   in the baseline and absent from the current upstream tree is an unambiguous deletion;
   upstream-deleted-but-locally-modified keeps the local copy. The subdirectory scoping
   that the blind version needed is gone and its absence is **not** a regression — see
   the deletion block's own comment for why the baseline makes it structurally
   unnecessary. Live in all seven safe mirrors.

2. **18 is now 15, and `store-updates` was an INCOMPLETE port** — it had the safe
   workflow but was missing both halves of the unconditional-baseline fix and the
   `Commit the refreshed baseline` step. Rebuilt from karakeep 2026-09-02. The lesson
   generalizes: the Trap 1 sweep proves a step name exists, not that a port is complete.
   Diff the step list.

3. **A repo SETTING blocked the whole design and is not mentioned anywhere below.**
   `gh pr create` from `GITHUB_TOKEN` is refused unless *Settings → Actions → General →
   "Allow GitHub Actions to create and approve pull requests"* is on. It was off in six
   of seven mirrors, so they could never open their sync PR — `raycast-store-updates` sat
   wedged from 2026-08-27 to 2026-09-02 because of it, and the others merely had nothing
   to PR yet. **Turn it on as step one of any port**, and note that writing
   `.github/workflows/*` over the API needs a token with the `workflow` scope, which the
   ambient `GH_TOKEN` does not carry.

The two workflow defects fixed alongside this are described in the commit that touched all
seven mirrors; the re-runnable PR step matters because a mid-step failure used to wedge a
repo permanently.

---

## Why you

You own `raycast-extension-workflows` and hold the fleet context. This work touches 18
separate repos, several of which have other sessions' uncommitted work in them right now. It
is a rollout, not a fix — the fix already exists and is proven in six repos.

## The situation in one paragraph

Of 44 `raycast-*` repos, 24 carry `.github/workflows/sync-from-upstream.yml`. **Six** run the
safe three-way version. **Eighteen** run a blind-overwrite version that downloads every
upstream file with `curl -o`, no comparison, then commits and pushes **straight to `main`**
with no PR. That is the exact pattern
`/Users/messina/Developer/GitHub/chrismessina/raycast-extension-workflows/plugins/raycast-extensions/reference/my-extensions-mirror.md`
forbids under "🚨 The inbound sync MUST NOT overwrite blindly", and it is the loop that
silently reverted a README on `raycast-claude-artifacts` on 2026-08-01. Re-running that
comparison the next day showed it would have destroyed three files, including an entire
unshipped feature.

**It is live and unattended in 18 repos on a daily cron.**

---

## Task A — commit the docs left uncommitted (do this first, it is 5 minutes)

In `/Users/messina/Developer/GitHub/chrismessina/raycast-extension-workflows`, on `main`:

| Path | State |
| --- | --- |
| `docs/solutions/workflow-issues/a-green-mirror-sync-does-not-mean-a-fresh-baseline.md` | new, untracked |
| `CONCEPTS.md` | modified — one entry added, `### Sync baseline`, in the Fleet conventions cluster |
| `plugins/raycast-extensions/reference/my-extensions-mirror.md` | modified — corrected "The optimization is LOSSY" section + rewritten Fleet status block |

**`plugins/raycast-extensions/skills/ship/SKILL.md` is NOT in that list and needs nothing.**
Its four corrections were swept into commit `792f0f8` ("Make readme-template.md the single
source of truth for README shape") by a concurrent session and are already pushed. The
commit message does not mention them. Do not go looking for them as missing work, and do not
re-apply them — grep for `SAME-PIXELS` to confirm they are present.

Stage **by path**, never `git add -A` — see Traps.

---

## Task B — the rollout

### What is being replaced

The blind workflow, byte-identical across all 18 apart from its cron minute
(reproduce with exactly `sed 's/cron: .*/cron: X/' "$f" | shasum -a256 | cut -c1-12` →
`27cafc38dc3a` on every one; a hash taken without that normalization will differ per repo and
tells you nothing). Its core:

```bash
while read -r path; do
  mkdir -p "$(dirname "$path")"
  curl -fsSL --retry 3 --retry-delay 2 ".../${path}" -o "$path" || { echo ABORT; exit 1; }
done < "$RUNNER_TEMP/upstream-paths.txt"
...
git commit -m "$MSG"
git push                      # straight to main. no PR, no comparison.
```

It is not entirely naive — it pins to one commit, aborts on a short manifest, and stages only
what it downloaded. None of that helps: it still overwrites local work it never compared
against.

### 🚨 BLOCKING — the safe version LOSES upstream-deletion propagation

**Read this before writing any code. It is a capability regression the rollout would
otherwise ship silently to 18 repos, and it is a decision for Chris, not for you.**

The blind workflow propagates upstream deletions. It diffs `git ls-files` over the synced
subdirectories against the download manifest and removes what upstream no longer serves:

```bash
while read -r tracked; do
  if ! grep -Fxq "$tracked" "$MANIFEST"; then
    echo "  upstream no longer serves: $tracked"
    git rm -q --cached --ignore-unmatch -- "$tracked"
    rm -f -- "$tracked"
  fi
done < <(git ls-files -- $SYNCED_DIRS)
```

It is guarded — it refuses to prune on an implausibly small manifest, and it is scoped to
synced subdirectories after a 2026-07-31 incident (karakeep run `30651601868`) where every
root file became a deletion candidate.

**The safe workflow has no deletion mechanism whatsoever.** Grep it: no `git rm`, no `rm -f`,
no prune step. Its compare loop only iterates paths upstream currently serves, so a file
deleted upstream is simply never visited — it stays in the mirror forever and quietly drops
out of the next recorded baseline.

So the trade is real in both directions: the safe version protects local work and refuses
ambiguous merges, and the blind version handles deletions. **Porting as-is trades one
correctness property for another.** The six already-ported mirrors have carried this gap
since 2026-08-03; nobody noticed, which tells you the deletion path is rare, not that it is
harmless.

Options, in the order I would put them to Chris:

1. **Port the deletion pass into the safe workflow** before rolling out — a file present in
   the baseline and absent from the current upstream tree is an unambiguous upstream
   deletion, which the three-way compare can classify honestly (and it is strictly *better*
   informed than the blind version's manifest diff, because it has the baseline). Keep the
   plausibility guard and the subdirectory scoping. This also closes the gap in the six.
2. Roll out without it and file the gap, accepting that upstream deletions stop propagating
   across the whole fleet.
3. Roll out to a subset and leave repos with churn-prone file sets on the blind version.

**Do not silently pick one.** Surface it.

### The reference implementation

`/Users/messina/Developer/GitHub/chrismessina/raycast-karakeep/.github/workflows/sync-from-upstream.yml`
— the most advanced copy. It has the three-way compare **and** both halves of the
unconditional-baseline fix. `claude-artifacts`, `digger`, `get-app-icon`, `reader`, and
`ejection-seat` are now identical to it in the baseline steps (ported 2026-08-29).

Do not build from `my-extensions-mirror.md`'s "Reference implementation" pointer at
`raycast-claude-artifacts` without diffing it against karakeep first — they agree today, but
karakeep is where fixes land first.

**Copy karakeep's file wholesale and then change only the cron minute. Do not patch the
existing blind file in place.** The two workflows differ structurally, not incrementally —
different steps, different permissions block, different compare logic — and patching invites
18 subtly divergent results. After copying, the only intended diff between any two of the 18
is one integer.

**The `permissions:` block is part of what you are copying and is easy to lose.** The blind
workflow declares `contents: write` alone; the safe one needs three, because it opens PRs and
files conflict issues:

```yaml
permissions:
  contents: write
  pull-requests: write
  issues: write
```

Ported without those, the sync appears to run and then silently fails to open its PR or file
its conflict issue — the failure mode this whole design exists to avoid. Assert the block
exists in every ported file before committing.

### What varies per repo — and what does not

Verified for all 18 on 2026-08-29:

- **Cron minute** — every repo has its own, already staggered. **Preserve it.** GitHub queues
  same-minute schedules fleet-wide. Current values:
  `at-profile 3 · bookface 10 · brew 27 · change-case 34 · craftdocs 48 · domainr 55 ·
  fathom 24 · fly 2 · google-books 9 · luma 38 · screenocr 16 ·
  secret-browser-commands 52 · store-updates 59 · tesla-energy 6 · trimmy 13 ·
  wayback-machine 23 · word-count 30 · wrap-unwrap 20`
- **`UPSTREAM_EXT_DIR`** — **none of the 18 needs one.** Each repo's `package.json` `name`
  matches an existing directory under `extensions/` upstream, including the two that look
  wrong: `raycast-fly` and `raycast-store-updates` are genuinely named that upstream.
  (Checked against the full 3,233-entry tree, `truncated: false` — see Traps for why the
  obvious way to check this is wrong.) `raycast-reader → reader-mode` is the fleet's only
  override and it is already in the safe six.
- **All 18 are on `main`** and `main` is their default branch.

### Seed the baseline, and assert before writing it

A safe workflow with no `.github/upstream-sync-state.json` has no third point on its first
run. The porting checklist in `my-extensions-mirror.md` covers this; the load-bearing part:

> Assert a plausible file count (≥5) before writing it — a truncated or failed fetch would
> otherwise seed an empty baseline, and every local file then reads as "keep", masking real
> upstream changes.

(Now that recording is unconditional, a bad seed is corrected on the next successful run
rather than persisting indefinitely, so this is a one-run miss — still worth asserting, but
it is not the permanent trap the older wording implied.)

**A count is not a validity check.** The file must be this shape, and every SHA must come
from one resolved, non-truncated tree read:

```json
{
  "upstream_commit": "<40-hex commit the paths were read from>",
  "synced_at": "<ISO-8601 UTC>",
  "files": { "<repo-relative path>": "<git blob SHA>", "...": "..." }
}
```

The blob SHAs must be git blob SHAs (what `git hash-object` produces), because that is what
the compare step compares against. Assert `.truncated == false` on the tree read that
produces them — karakeep's own workflow does exactly this at its line 116 and fails closed,
for the same reason. A garbage-but-populated `files` map passes a count check and then
mis-classifies every file.

For calibration, the six live baselines hold 14–87 files (`ejection-seat` 14,
`get-app-icon` 15, `claude-artifacts` 22, `digger` 62, `reader` 77, `karakeep` 87).

### Ordering: workflow and baseline in the same commit

If the safe workflow lands without a baseline, the first run is **fail-safe, not
destructive** — verified by reading the compare step: with no `base_sha`, a file that exists
locally and differs is classified `keep-local`, and only files absent locally are downloaded.
So the worst case is a no-op run, not lost work.

Commit them together anyway. It costs nothing and removes the question.

### Dry-run the compare before pushing anything

`my-extensions-mirror.md` records why: on 2026-08-03 a dry run surfaced that `raycast-digger`
carries 27 local-only files (a prettier-import-sort pass that never shipped upstream). The
blind workflow would have reverted all 27; the safe one keeps them. **Expect every mirror to
carry something like this** and confirm the safe version keeps it before you cut over.

### Validate the YAML

`npx js-yaml <file>` on each. An unquoted `: ` inside a `run:` block parses locally and fails
on GitHub. This caught a real defect in the reference implementation before it shipped.

---

## Traps — every one of these burned a turn on 2026-08-29

**1. Grepping for the `if:` gate reports the same `0` for "fixed" and for "no such step".**
This produced a fleet sweep that labelled 18 blind repos as "fixed". Classify on the step's
*presence*, then on the gate:

```bash
for d in raycast-*/; do
  f="${d}.github/workflows/sync-from-upstream.yml"; [ -f "$f" ] || continue
  grep -q "name: Record the new baseline" "$f" \
    && echo "safe   ${d%/}" || echo "BLIND  ${d%/}"
done
```

Expected today: 6 safe, 18 BLIND, and 20 repos printing nothing (no workflow at all).

**2. `gh api repos/raycast/extensions/contents/extensions` silently truncates at 1000
entries.** It returned exactly 1000 and made every alphabetically-late slug look absent
upstream — 11 false "needs UPSTREAM_EXT_DIR" verdicts in a row, all starting with letters
after `f`. Use the tree API and check the flag:

```bash
ROOT=$(gh api repos/raycast/extensions/git/trees/main --jq '.tree[]|select(.path=="extensions")|.sha')
gh api "repos/raycast/extensions/git/trees/$ROOT" --jq '.truncated'   # must be false
```

**3. Check the branch before you commit.** Two of the five ports on 2026-08-29 landed on
feature branches (`digger` on `fix/report-auxiliary-fetch-failures`, `get-app-icon` on
`ci/safe-upstream-sync`) because the repos were not on `main`. A workflow fix on a
non-default branch is **inert** — Actions runs the scheduled workflow from the default
branch. One entangled the CI change with unrelated in-flight feature work. All 18 are on
`main` today; re-check anyway, it costs one command.

> Both of those have since reached `main` (digger by merge, get-app-icon via its PR #2), so
> the fix is live in all six. **Their local worktrees are still checked out on those feature
> branches**, which is a separate thing and not yours to change — do not switch anyone's
> branch. Read `main` through `git show origin/main:<path>` rather than trusting the
> worktree when you audit those two.

**4. Several of the 18 have substantial uncommitted work from other sessions.** Counts on
2026-08-29: `fathom` 27 files, `luma` 13, `store-updates` 12, `at-profile` 4, `bookface` 4,
`change-case` 3, `secret-browser-commands` 3, `craftdocs` 2, `trimmy` 2, and one file each in
`brew`, `domainr`, `screenocr`, `tesla-energy`, `wayback-machine`, `word-count`,
`wrap-unwrap`. `fly` and `google-books` were clean.

> Chris works in a permanently dirty tree across concurrent agent sessions and his
> uncommitted edits are sacred. **Stage only
> `.github/workflows/sync-from-upstream.yml` and `.github/upstream-sync-state.json` by
> explicit path**, assert what is staged before committing, and never run `git add -A`,
> `git stash`, `git checkout --`, `git restore`, or `git reset`. The 2026-08-29 rollout used
> this guard and it is worth keeping:
>
> ```bash
> git -C "$r" add -- .github/workflows/sync-from-upstream.yml .github/upstream-sync-state.json
> staged=$(git -C "$r" diff --cached --name-only | sort | tr '\n' ' ')
> expected=".github/upstream-sync-state.json .github/workflows/sync-from-upstream.yml "
> [ "$staged" = "$expected" ] || { echo "ABORT $r — staged: $staged"; continue; }
> ```
>
> **Both paths, one commit.** An earlier draft of this guard staged only the workflow, which
> would have left the baseline untracked and reintroduced the very ordering hazard below.

**5. A green sync run is not a refreshed baseline.** The whole reason the six needed a second
fix. Full analysis:
`/Users/messina/Developer/GitHub/chrismessina/raycast-extension-workflows/docs/solutions/workflow-issues/a-green-mirror-sync-does-not-mean-a-fresh-baseline.md`.
Short version: recording used to be gated on `updated != '0'`, and the runs that copy nothing
are the common case, so the baseline froze and ordinary upstream-only edits later read as
"both sides moved". Four of the six still carry a baseline dated 2026-08-02 that self-heals
on their next run now the gate is gone — **confirm that actually happens on at least one of
them before assuming it did.**

**6. Do not use `sips -s format png` + `shasum` to compare screenshots.** It preserves channel
count, so it compares an RGBA re-encode against an RGB one and always reports a difference.
Raycast CI's re-encode is **lossless** (strips a fully-opaque alpha, `RGBA → RGB`, all
7,500,000 RGB bytes identical). Decode and compare RGB planes instead. Not directly part of
this rollout, but it is in the triage these workflows feed, and it was wrong in the docs for
two days.

---

## Verification

Per repo, before commit:

```bash
npx js-yaml "$r/.github/workflows/sync-from-upstream.yml"          # parses
grep -c "name: Record the new baseline"       "$r/.github/..."     # 1
grep -A1 "name: Record the new baseline" "$r/.github/..." | grep -c "updated != '0'"   # 0
grep -c "Commit the refreshed baseline"       "$r/.github/..."     # 1
grep -c "name: Open a pull request"           "$r/.github/..."     # 1
jq '.files | length' "$r/.github/upstream-sync-state.json"         # >= 5, sanity-check the number
```

Fleet-wide, after: the sweep in Trap 1 should print 24 `safe` and no `BLIND`. **That sweep
only proves a step name exists** — it cannot tell a complete port from one missing the
permissions block or the PR step. For real equivalence, diff each ported file against
karakeep with the cron minute and comments normalized away:

```bash
K=/Users/messina/Developer/GitHub/chrismessina/raycast-karakeep/.github/workflows/sync-from-upstream.yml
norm() { sed 's/cron: .*/cron: X/' "$1" | sed 's/[[:space:]]*#.*$//' | grep -vE '^[[:space:]]*$'; }
for d in raycast-*/; do
  f="${d}.github/workflows/sync-from-upstream.yml"; [ -f "$f" ] || continue
  diff <(norm "$K") <(norm "$f") >/dev/null && echo "identical  ${d%/}" || echo "DIVERGES   ${d%/}"
done
```

**Strip the comments — a raw diff is too strict and cries wolf.** Without the comment filter
all five of the 2026-08-29 ports read `DIVERGES` at 22–24 lines, every one of them inside a
comment block deliberately reworded so it does not quote karakeep's own file counts in a repo
where they would be false. Nothing was wrong with those ports.

Baseline for the run above, measured 2026-08-29 — expect exactly this, plus `identical` for
each repo you newly port:

| Repo | Verdict | Why |
| --- | --- | --- |
| `karakeep`, `claude-artifacts`, `ejection-seat`, `get-app-icon` | `identical` | — |
| `reader` | `DIVERGES`, 2 lines | legitimate: `UPSTREAM_EXT_DIR: "reader-mode"` |
| `digger` | `DIVERGES`, 2 lines | **open question, resolve before copying karakeep 18 times** — digger has `git check-ignore -q --no-index` where karakeep has `git check-ignore -q`. `--no-index` also consults `.gitignore` for tracked paths. One of the two is stale and nobody has decided which; copy blindly and you propagate whichever is wrong. |

Any other `DIVERGES` is an incomplete port.

Then dispatch one repo's workflow (`gh workflow run sync-from-upstream.yml`) and read the
result line — `take-upstream=N keep-local=N conflicts=N gitignored=N` — rather than trusting
the green check. A first run against a freshly seeded baseline should be a quiet no-op.

## Scope — do not expand

- **Do not port to the 20 repos with no sync workflow.** They were never wired up; adding one
  is a separate decision with its own question (is the extension even published?).
- **Do not mark any Raycast Store PR ready for review.** Chris's call, always.
- **`ci/safe-upstream-sync` in `raycast-get-app-icon` is a merged leftover branch** and can be
  deleted, but that is branch surgery — ask.
- Rollout shape (direct commits to `main` vs a PR per repo) is worth asking Chris about
  before doing it 18 times. The 2026-08-29 ports went in as direct commits on `main` for five
  repos and as one PR where the repo was mid-branch.
