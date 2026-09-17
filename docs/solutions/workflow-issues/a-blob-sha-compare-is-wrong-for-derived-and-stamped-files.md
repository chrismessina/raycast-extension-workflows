---
title: A blob-SHA compare is the wrong instrument for derived and stamped files
date: 2026-09-17
category: workflow-issues
module: publishing
problem_type: workflow_issue
component: development_workflow
severity: high
applies_when:
  - "A standalone mirror runs the three-way sync-from-upstream workflow and halts on the same file every day"
  - "The conflicting file is package-lock.json, or a CHANGELOG whose only difference is the merge-date stamp"
  - "A conflict was hand-reconciled and came straight back on the next scheduled run"
  - "Deciding whether a file belongs in a content-addressed comparison at all"
tags: ["raycast", "mirror-sync", "github-actions", "package-lock", "pr-merge-date", "three-way-compare"]
---

# A blob-SHA compare is the wrong instrument for derived and stamped files

`/Users/messina/Developer/GitHub/chrismessina/raycast-extension-workflows/sync-from-upstream.yml`
reconciles a standalone mirror against `raycast/extensions` by comparing three git blob SHAs per
path: upstream's current tree, the baseline recorded at the last sync, and the mirror's working
copy. A blob SHA is content-addressed, so "changed" is exact — which is precisely why the compare
is correct for authored files and structurally wrong for two others.

On 2026-09-17, five of thirteen mirrors had been failing their daily sync since 2026-09-15:
`bookface`, `tesla-energy`, `trimmy`, `wrap-unwrap` on `package-lock.json`, and
`secret-browser-commands` on `CHANGELOG.md`. Every run filed a comment on the same
manual-reconcile issue and exited 1.

## Neither conflict was reconcilable by hand

**`package-lock.json` is derived, and the two sides are permanently divergent by design.** The
mirrors carry `@ianvs/prettier-plugin-sort-imports` as a local devDependency; the monorepo copy
does not. So the mirror's lock can never equal upstream's. Meanwhile upstream's lock keeps moving
under Raycast's dependency bots — the 2026-09-17 diff was `brace-expansion` 1.1.14→1.1.18 and
`@raycast/api` 1.104.20→1.104.25, changes no human made. Both sides therefore differ from the
baseline on every run, which row 4 of the workflow's table classifies as a conflict.

Reconciling it by hand clears the halt exactly until the next bot bump. And taking upstream's copy
— the obvious script fix — is worse than halting: it drops the mirror's own devDependencies and
breaks `npm ci` there.

**A `CHANGELOG.md` differing only by `{PR_MERGE_DATE}` is the event the workflow exists to
deliver.** The mirror writes the literal placeholder; Raycast CI substitutes the merge date when
the Store PR lands. Upstream's copy is then *our* text with the date filled in. The header of the
workflow says delivering that stamp is half its purpose, and it was halting on it.

## The fix: classify by what the file *is*

Two new buckets in the classify loop, not two special cases in the conflict handler.

`package-lock.json` is skipped before the three-way compare runs at all, and skipped again in the
upstream-deletion loop. The second skip is not optional: the baseline is rebuilt verbatim from
`upstream.tsv` and so still carries the lock's upstream SHA, which means an upstream lockfile
removal would have `git rm`'d the mirror's own lock — a path the compare step is explicitly not
allowed to touch. It is instead regenerated with `npm install --package-lock-only --ignore-scripts`
whenever `package.json` is taken, which keeps the mirror's devDependencies *and* picks up whatever
upstream bumped.

The stamp is auto-resolved by an **exact line-wise test**, and the first draft of that test is the
interesting part of this learning.

## The first draft of the stamp test was too loose, and it looked right

The obvious implementation masks placeholders and ISO dates on both sides and compares:

```bash
# WRONG — swallows a real divergence
[ "$(sed -e 's/{PR_MERGE_DATE}/DATE/g' -e 's/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}/DATE/g' "$path")" = \
  "$(sed -e 's/{PR_MERGE_DATE}/DATE/g' -e 's/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}/DATE/g' "$upstream")" ]
```

It passed the real case and it passed a hand-built false-positive probe, so it read as verified.
It is not. Masking *every* date on *both* sides also compares equal when the two sides edited the
same **old** release date differently — mirror says `2026-08-02`, upstream says `2026-08-03` — and
upstream silently wins. The only precondition is a placeholder existing *somewhere* in the file,
not that the stamp is the sole difference.

The shipped version compares line by line and lets a line differ only in the one permitted way:

```awk
NR==FNR { mine[FNR]=$0; n=FNR; next }
FNR > n { exit 1 }
{
  if ($0 == mine[FNR]) next
  if (mine[FNR] !~ /\{PR_MERGE_DATE\}/) exit 1
  stamped = $0
  gsub(/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/, "{PR_MERGE_DATE}", stamped)
  if (stamped != mine[FNR]) exit 1
}
END { if (FNR != n) exit 1 }
```

Every other line must match byte for byte and the line counts must agree. Verified against the
real `raycast-secret-browser-commands` blobs plus four adversarial inputs — old-date divergence,
upstream prose insertion, truncation, local prose edit: one take-upstream, four conflicts.

## What generalises

**Ask what a file *is* before deciding how to compare it.** A content-addressed compare answers
"are these bytes identical", and for a *generated* file that question has no useful answer — the
bytes are a function of inputs that legitimately differ per repo. For a *stamped* file the answer
is misleading in the other direction: the difference is real and is exactly the thing you wanted.
Both belong in their own bucket in the classifier, not in the conflict handler as exceptions.

**A daily-failing automation is a design report, not a queue of incidents.** Five repos halting on
two file names, repeatedly, on changes nobody made, is the compare telling you its model is wrong.
The tell is that hand-reconciling does not hold.

**A normalisation test that passes one hand-built probe is not verified.** Both drafts above pass
the real case; only one of them is correct. What separated them was enumerating what *should*
conflict and confirming each one does — the false-negative direction, which a probe built from the
bug you already know about will never reach. Codex named this one; the mask had already shipped
past a green check.

## Receipts

- Failing runs: `chrismessina/raycast-bookface` 35232355486, `raycast-secret-browser-commands`
  35233730862 (2026-09-17), daily since 2026-09-15.
- Fix: `/Users/messina/Developer/GitHub/chrismessina/raycast-extension-workflows/sync-from-upstream.yml`,
  commits `30eef02` and `bf1398d`; rolled out to twelve mirrors 2026-09-17.
- Re-run green on all five. `secret-browser-commands` opened PR #3 whose only content change is
  `## [1.2.1] - {PR_MERGE_DATE}` → `## [1.2.1] - 2026-09-15`.
- Two adversarial review rounds; six findings, all closed. Two round-two findings declined under
  the stopping rule: a trailing-newline-only divergence and an ISO-shaped-but-invalid date such as
  `2026-99-99` both resolve toward upstream's canonical published copy, so neither can lose local
  work.
