---
module: raycast-extensions
date: 2026-07-26
problem_type: workflow_issue
component: tooling
severity: medium
symptoms:
  - "Store PR feedback arrives from a bot after submission, when it could have been run before"
  - "A PR with a clean 5/5 automated review is closed anyway"
  - "A submission dies without a rejection — the stale bot closes it"
root_cause: missing_validation
resolution_type: process_change
tags:
  - raycast
  - code-review
  - greptile
  - store-submission
  - pre-flight
related_components:
  - documentation
---

# Reverse-engineering the Raycast Store review gauntlet

## Problem

Every PR to `raycast/extensions` gets reviewed by `greptile-apps[bot]` — a required check
that posts a summary, a **Confidence Score: N/5**, and P1/P2-badged inline comments. Its
ruleset is configured in Greptile's dashboard, not committed to the repo, so there is nothing
to read before submitting. Feedback that could have been a pre-flight assertion arrives as a
review round instead, and each round costs a day or more of the 25-day stale clock.

The goal was to recover enough of that ruleset to run it against ourselves first.

## Symptoms

Findings that a script could have caught, showing up as bot comments after submission:

- `## [Feature] - 2026-07-26` instead of `{PR_MERGE_DATE}` — **P1**, the single most-fired rule.
- A hand-written `interface Preferences` shadowing the generated `raycast-env.d.ts` type.
- `.prettierrc` with `printWidth: 100`, or with the right width but no explicit `singleQuote`.
- A view command with screenshots in `media/` instead of `metadata/`.

## What Didn't Work

**Looking for a config file.** There is no `.greptile.json`, no `.greptile/` directory, and
nothing in `.github/`. The rules genuinely aren't in the repo.

**The GitHub API.** This session's proxy scopes API access to the session's own repos, so
`api.github.com/repos/raycast/extensions/...` returns 403 and `search/issues` is refused
outright. Rendered `github.com` PR pages fetch fine, which is what the survey ran on — but
the `/files` tab renders inline comment bodies unreliably (`Uh oh! There was an error while
loading`) while the conversation page renders them. Sampling the wrong tab silently returns
comment *locations* with no comment *text*.

**Trusting the score as a quality signal.** Every duplicate-rejected PR in the sample scored
**4/5 or 5/5**. The bot reviews the diff; it has no opinion on whether the extension should
exist.

## Solution

**Mine the bot's own citations.** Greptile footers its comments with `Rule Used:` and
`Knowledge Base Used:` when a *custom* rule fires — so the rules quote themselves. Sampling
~45 PRs (#27467–#29739, merged / open / closed-unmerged) surfaced exactly four distinct rule
strings, all citing a knowledge base named **Extension Authoring Conventions**, plus a second
KB, **Extensions Build & Publish Flow**, on packaging findings.

Four rules is a suspiciously short list — until you find
**`raycast/extensions/.github/copilot-instructions.md`**, a maintained, public,
machine-readable review spec whose wording the four rule strings track almost verbatim
(`{PR_MERGE_DATE}` format, `{"printWidth": 120, "singleQuote": false}`, the metadata-folder
requirement). That file is the closest thing to a published spec, and unlike the dashboard it
can be re-read on demand.

The split that fell out of the survey, and that the deliverable is built around:

| Layer | Where it lives | How to check it |
|---|---|---|
| 4 custom rules + CI enforcers | Greptile dashboard / `.github/workflows/` | Mechanical — a script |
| ~14 authored conventions | `.github/copilot-instructions.md` | Mostly mechanical |
| Defect taxonomy | Emergent from the model | Human, at design time |
| Acceptance | A maintainer's judgment | Human, **before** writing code |

Shipped as [`reference/greptile-review-rules.md`](../../../plugins/raycast-extensions/reference/greptile-review-rules.md)
(the rules and their evidence) plus
[`reference/scripts/greptile-preflight.sh`](../../../plugins/raycast-extensions/reference/scripts/greptile-preflight.sh)
(the mechanical half), wired into `ship`'s pre-flight as a hard gate and into `review-pr`.

## Why This Works

**The bot cites its own rules, so the ruleset is self-documenting through its output.** No
access to the dashboard is needed — only enough PRs that every rule has fired at least once.
Four rules across 45 PRs, each seen 4–9 times, is dense enough to believe the list is close to
complete for the deterministic tier.

**The two-tier split is real, not a convenience.** Tier 1 fires on *files* and is perfectly
mechanizable. The rest fires on *logic* and is not — Greptile's inline comments are uniformly
shaped as "when ⟨specific action or race⟩, ⟨this call⟩ ⟨does the wrong thing⟩, causing
⟨user-visible consequence⟩." That is a search for a reachable path to a wrong state, and no
grep approximates it. Pretending otherwise would have produced a script full of false
positives, which gets disabled within a week.

**The script's exit code is scoped to what it can prove.** `FAIL` (exit 1) is only ever a
Tier 1 rule or a CI enforcer. Everything heuristic — unwrapped `launchCommand`, sync `exec`,
`rmSync` — is `WARN` and does not affect the exit code, because each has legitimate
exceptions. Verified against a compliant fixture: **0 FAIL, 0 WARN**, including the cases most
likely to false-positive (`getPreferenceValues<Preferences>()` *usage* vs. *declaration*, and
failure toasts routed through `@chrismessina/raycast-kit`, which attaches the Copy-Error
action inside the package and so shows zero literal matches).

## Prevention

**Rank the gates by what actually kills PRs, not by which is loudest.** Three gates run on
every submission — CI, Greptile, maintainer — and the ranking is inverted from the noise:

1. **Duplication** closed six of the sampled unmerged PRs. The maintainer test is *"the same
   broad job,"* not feature overlap: a Steam search extension arguing differentiation on
   pricing and wishlist data still lost, with the counter-offer to reposition as a dedicated
   price tracker. **Search the Store before writing code.**
2. **The stale bot** closed ten. `stale.yml` is 25 days idle → stale label, 7 more → closed,
   against a stated review SLA of "up to 15 business days." Several died after a maintainer
   asked one question nobody answered. A Store PR is a month-long commitment to watch a thread.
3. **Screenshots** — must be genuine *Capture Window* captures at 2000×1250, not generated
   images. Rejected on one PR, revision-requested on two more.
4. Everything the bot says.

**A P1 is not a merge blocker, and a 5/5 is not an approval.** PR #29605 merged with three
open P1 comments the same day it was approved. Meanwhile a follow-up 5/5 is explicitly scoped
— *"no blocking failure remains within the scope of the previous review threads"* — so it
means "what you were told to fix, you fixed," not "the PR was re-reviewed."

**Re-read `copilot-instructions.md` before a first submission.** It is the one layer that is
public and versioned. The Tier 1 list is a dated snapshot of dashboard config that can change
without a commit, and it says so at the top.
