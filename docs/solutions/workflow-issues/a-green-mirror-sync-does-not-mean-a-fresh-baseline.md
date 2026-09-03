---
title: A green mirror sync does not mean a fresh baseline
date: 2026-08-29
category: workflow-issues
module: publishing
problem_type: workflow_issue
component: development_workflow
severity: high
applies_when:
  - Post-merge reconcile of a standalone mirror after a Raycast Store PR lands
  - A release changed a screenshot, so CI's re-encode moved the published bytes
  - A mirror runs the three-way sync-from-upstream workflow with a committed blob-SHA baseline
tags: [raycast, mirror-sync, screenshot, post-merge, baseline, github-actions]
---

# A green mirror sync does not mean a fresh baseline

## Context

Raycast's Store CI re-encodes screenshots on merge, so the published **bytes** differ from what
you submitted. Measured twice on `claude-artifacts`, figures read from the git objects:

| PR | Submitted | Published | Reduction |
| --- | --- | --- | --- |
| #30529 (merged 2026-08-27) | 1,646,438 B | 1,050,178 B | 36.2% |
| #30626 (merged 2026-08-29) | 1,625,990 B | 1,024,643 B | 37.0% |

**The re-encode is lossless, and knowing that is what makes the triage reliable.** CI drops a
fully-opaque alpha channel and recompresses — `RGBA -> RGB`, single distinct alpha value `255`,
and all 7,500,000 RGB bytes byte-for-byte identical in both pairs. Neither copy is palettized.
Not one pixel changes.

> ⚠️ **Do not test this with `sips -s format png` + `shasum`.** That re-encode *preserves channel
> count*, so it compares an RGBA re-encode against an RGB one and reports a difference no matter
> what the pixels hold. It is not a pixel comparison, and reading it as one is what produced the
> earlier, wrong "lossy / palette-reduced / different pixels" conclusion. Decode and compare the
> RGB planes instead:
>
> ```python
> from PIL import Image
> a, b = Image.open(local), Image.open(published)
> same_pixels = a.convert("RGB").tobytes() == b.convert("RGB").tobytes()
> ```
>
> `same_pixels` cleanly separates the two cases a byte hash cannot: **True** means CI re-encoded
> your own submission (adopt upstream), **False** means the image genuinely changed (keep local).

The mirror's `sync-from-upstream.yml` does a three-way compare against blob SHAs committed in
`.github/upstream-sync-state.json`, and halts rather than guessing when both sides moved. After a
release where you changed a screenshot, both sides *have* moved, so it halts — correctly.

Existing guidance treated that halt as the expected path and told you how to recover from it. It
is avoidable, and avoiding it turns out to expose a second, quieter problem.

## Guidance

**1. Adopt the published bytes and commit them BEFORE dispatching the sync.**

```bash
curl -sL -o metadata/screenshot-1.png \
  https://raw.githubusercontent.com/raycast/extensions/main/extensions/<ext>/metadata/screenshot-1.png
# compare decoded RGB (below) — or just eyeball it; then commit, push, and only then:
gh workflow run sync-from-upstream.yml
```

The halt never fires, because the workflow short-circuits on byte-equality *before* it consults
the baseline. At
`/Users/messina/Developer/GitHub/chrismessina/raycast-claude-artifacts/.github/workflows/sync-from-upstream.yml:174`:

```bash
if [ "$up_sha" = "$mine_sha" ]; then
  continue                                    # identical, nothing to do
fi
```

`base_sha` is read at `:168` but only *used* at `:180-181`, and the conflict branch is `:193` —
all three skipped. A stale baseline cannot produce a conflict on a file whose bytes already match.

**2. Know that the same short-circuit is why your baseline never refreshes.**

Recording the new baseline is gated on having copied something
(`sync-from-upstream.yml:267`):

```yaml
- name: Record the new baseline
  if: steps.compare.outputs.updated != '0'
```

Adopting first guarantees `take-upstream=0`, so the gate stays shut and
`.github/upstream-sync-state.json` is not rewritten. On `claude-artifacts` it has been written
exactly once, when it was seeded:

```
$ cd ~/Developer/GitHub/chrismessina/raycast-claude-artifacts
$ git log --format='%cs %h %s' -- .github/upstream-sync-state.json
2026-08-02 d717a45 fix: stop the upstream sync from reverting local work
```

(That SHA and the paths quoted below live in the **mirror** repo, not in this one.)

Every run since the adopt-first ordering reports `take-upstream=0  keep-local=0  conflicts=0
gitignored=0`. The green is real for *that* run and tells you nothing about the baseline behind
it.

**3. Port the unconditional-recording fix.** `raycast-karakeep` had this same freeze and fixed it
in commits `0369178` and `ac103cf` (2026-08-13 local, 2026-08-14 UTC — `git log --format=%cs`
shows 08-13) by dropping the `if:` so the baseline records on every successful run. A second-order bug came with it — `synced_at`
changing every run produced daily junk commits — solved by diffing only `upstream_commit` and the
`files` map, not the timestamp. Port both halves together or you trade one problem for another.

## Why This Matters

A frozen baseline is a *phantom-conflict generator*, and it is invisible until it fires.

For any file whose current bytes differ from the frozen baseline, the next genuine upstream-only
change — someone else's PR to your extension, the case you will not see coming — computes
`upstream_moved=true` **and** `mirror_moved=true`, and lands in the conflict branch at `:193`.
You never touched the file. The sync halts, files an issue, and syncs nothing.

On `claude-artifacts` today, 8 of the 22 tracked files are already in that state:

```
CHANGELOG.md                      package-lock.json   src/actions/reveal-in-finder.tsx
metadata/screenshot-1.png         package.json        src/components/empty-views.tsx
README.md                         src/search-artifacts.tsx
```

It is a fleet condition, not one repo's. Six mirrors run the safe three-way sync; four of them
carry a baseline last written 2026-08-02:

| Mirror | Record step | Baseline last written |
| --- | --- | --- |
| `raycast-karakeep` | unconditional | 2026-08-29 |
| `raycast-ejection-seat` | gated | 2026-08-29 |
| `raycast-claude-artifacts` | gated | **2026-08-02** |
| `raycast-digger` | gated | **2026-08-02** |
| `raycast-get-app-icon` | gated | **2026-08-02** |
| `raycast-reader` | gated | **2026-08-02** |

(The other 18 `raycast-*` repos **that carry this workflow** have no `Record the new baseline`
step at all; a further 20 have no sync workflow whatsoever. Do not read their absence as health; classify on the step, not on a grep
that a missing step also satisfies.)

## When to Apply

- Immediately after a Store PR merges, as part of post-merge cleanup — adopt, then dispatch.
- Before trusting any green sync run as evidence the mirror is reconciled. Check
  `git log -- .github/upstream-sync-state.json` and compare its date to your last release.
- When a sync halts on files you know you never edited — suspect the frozen baseline before
  suspecting a real contribution.

## Examples

**The halt, when you dispatch first** — `claude-artifacts`, runs `33111129187` (2026-08-27T19:59)
and `33133301791` (2026-08-28T01:35), both:

```
take-upstream=0  keep-local=0  conflicts=1  gitignored=0
CONFLICTS (both sides changed):
    metadata/screenshot-1.png
```

Run `33133407396` (2026-08-28T01:37) went green two minutes later, after the published copy was
adopted by hand.

**No halt, when you adopt first** — after #30626 merged, the adoption was committed and pushed
before dispatch. Run `33274604623` (2026-08-29T20:52):

```
take-upstream=0  keep-local=0  conflicts=0  gitignored=0
```

No conflict, no issue filed — and, per the trap above, no baseline refresh either.

**Distinguish the two halt causes.** An earlier halt on the same repo (run `32957468142`,
2026-08-26, issue #1) conflicted on `CHANGELOG.md`,
`src/components/empty-views.tsx`, and `src/search-artifacts.tsx` — source files mid-release, not
the screenshot. Same branch of the same code, different cause. Read the conflict list before
reaching for the PNG triage.

## Related

- `/Users/messina/Developer/GitHub/chrismessina/raycast-extension-workflows/docs/solutions/workflow-issues/mirror-silently-stale-against-published-monorepo.md`
  — the inbound half of the same loop: detecting staleness before you write code. Its line
  "**Screenshots always differ** … none of it is meaningful" needs tightening: the *bytes* always
  differ, but a replaced screenshot differs too and is very meaningful — decoded-RGB equality is
  what tells the two apart. Under adopt-first ordering the file stops differing at all.
- `/Users/messina/Developer/GitHub/chrismessina/raycast-extension-workflows/docs/solutions/workflow-issues/raycast-store-pr-base-diverged-fork-main.md`
  — a sibling failure earlier in the same publish pipeline.
- `ship`'s post-merge step 2 and PNG triage
  (`/Users/messina/Developer/GitHub/chrismessina/raycast-extension-workflows/plugins/raycast-extensions/skills/ship/SKILL.md`)
  — the triage stays correct, but it is the recovery path for a sync you already dispatched, not
  the default path.
