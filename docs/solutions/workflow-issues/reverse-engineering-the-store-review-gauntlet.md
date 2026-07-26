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
**~95 PRs** (#22064–#29739, merged / open / closed-unmerged) surfaced **nine** distinct rule
strings, all citing a knowledge base named **Extension Authoring Conventions**, plus
**Extensions Build & Publish Flow** on packaging findings and a `raycast/-/custom-context`
slug on one.

> **Sampling depth was load-bearing, and the first pass got it wrong.** At ~45 PRs the list
> looked like four rules; the true count is nine. The reason is a sampling bias that isn't
> visible from inside a small sample: **rules fire almost exclusively on new-extension PRs**,
> and the first pass was weighted toward recent merged `Update <ext>` PRs, which draw general
> defect findings instead. Rule strings also render **truncated** in GitHub's collapsed footer
> (`What: Extensions with view-type commands must incl…`), so a rule can be present and
> unreadable. Saturation only arrived when two consecutive batches of new-extension PRs
> returned no new strings.

Nine rules is still a short list — until you find
**`raycast/extensions/.github/copilot-instructions.md`**, a maintained, public,
machine-readable review spec whose wording the four rule strings track almost verbatim
(`{PR_MERGE_DATE}` format, `{"printWidth": 120, "singleQuote": false}`, the metadata-folder
requirement). That file is the closest thing to a published spec, and unlike the dashboard it
can be re-read on demand.

The split that fell out of the survey, and that the deliverable is built around:

| Layer | Where it lives | How to check it |
|---|---|---|
| 9 custom rules + CI enforcers | Greptile dashboard / `.github/workflows/` | Mechanical — a script |
| ~14 authored conventions | `.github/copilot-instructions.md` | Mostly mechanical |
| Defect taxonomy | Emergent from the model | Human, at design time |
| Acceptance | A maintainer's judgment | Human, **before** writing code |

Shipped as [`reference/greptile-review-rules.md`](../../../plugins/raycast-extensions/reference/greptile-review-rules.md)
(the rules and their evidence),
[`reference/store-reviewer-feedback.md`](../../../plugins/raycast-extensions/reference/store-reviewer-feedback.md)
(the human gate — verbatim maintainer language and the escalation ladder), and
[`reference/scripts/greptile-preflight.sh`](../../../plugins/raycast-extensions/reference/scripts/greptile-preflight.sh)
(the mechanical half), wired into `ship`'s pre-flight as a hard gate, plus `develop` and
`review-pr`.

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

1. **Duplication** closed ~12 of the sampled unmerged PRs. The maintainer test is *"the same
   broad job,"* not feature overlap: a Steam search extension arguing differentiation on
   pricing and wishlist data still lost, with the counter-offer to reposition as a dedicated
   price tracker. **Raycast's own built-in commands count as prior art too** — one PR was
   rejected against System Commands, not against any extension. And the incumbent extension's
   author joins the thread and sides with consolidation. **Search before writing code.**
2. **The stale bot** closed ten-plus. `stale.yml` is 25 days idle → stale label, 7 more →
   closed, against a stated review SLA of "up to 15 business days." Several died after a
   maintainer asked one question nobody answered.
3. **Screenshots** — genuine *Capture Window* captures at 2000×1250, padded, and **free of
   real data** (maintainers ask for mock data on anything sensitive).
4. Everything the bot says.

**Nobody ever says "rejected."** The ladder is: a question → **PR converted to draft** → stale
→ auto-closed. Drafting is the actual verdict and it stops review; a drafted PR does not
re-enter the queue on its own. Every duplicate-rejected PR in the sample was drafted at that
step and died ~5 weeks later without another human comment.

**A P1 is not a merge blocker, and a 5/5 is not an approval.** PR #29605 merged with three
open P1 comments the same day it was approved. A follow-up 5/5 is explicitly scoped —
*"no blocking failure remains within the scope of the previous review threads"* — so it means
"what you were told to fix, you fixed," not "the PR was re-reviewed."

**But the bot does cost you a cycle.** The wider sample corrected the first pass here: on
new-extension PRs, a Greptile review is frequently the last event before the **author closes
their own PR** (eleven instances), often reopening a corrected one. The bot doesn't reject
you; it hands you a P1 list that costs a resubmission. That is precisely the cost the
preflight script removes.

**Re-read `copilot-instructions.md` before a first submission.** It is the one layer that is
public and versioned. The Tier 1 list is a dated snapshot of dashboard config that can change
without a commit, and it says so at the top.
