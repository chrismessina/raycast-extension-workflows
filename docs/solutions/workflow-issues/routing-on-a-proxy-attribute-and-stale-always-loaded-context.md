---
module: skills
date: 2026-07-26
problem_type: workflow_issue
component: development_workflow
severity: high
applies_when:
  - "A skill branches between two procedures and keys the decision on a metadata field"
  - "An agent pushes back that a documented route cannot work for its case"
  - "A CLAUDE.md / AGENTS.md claim about a skill's state may have gone stale"
tags:
  - skills
  - routing
  - claude-md
  - stale-documentation
  - agent-feedback
  - raycast
related_components:
  - documentation
  - tooling
---

# Routing on a proxy attribute, and stale always-loaded context

## Context

An agent trying to publish a brand-new Raycast extension stopped and asked which
of two submission routes to use. Its pushback contained three claims. One was a
real bug in the skill; two were false, and the false ones came from somewhere else
entirely. Both halves are worth recording, because the debugging instinct — "the
agent is confused, clarify the skill" — would have fixed only half and left the
other half generating the same confusion forever.

## Guidance

### Part 1 — route on the state that makes a procedure possible, not on a correlated attribute

The `ship` skill chose between two submission routes by reading `package.json`'s
`author` field:

- `author` is someone else → **Route A** (`ray publish`)
- `author: chrismessina` → **Route B** (standalone mirror + fork-sync PR)

`author` correlates with the right answer *for extensions that have already
shipped*, which is why it looked fine. But Route B's first step is "verify local
`main` equals the published v1.x by byte-diffing the sparse-fetched directory" —
and a brand-new first-party extension has no published version to diff against.
The routing key sent a whole class of cases into a procedure whose opening
instruction is impossible for them.

**The fix is to key on the precondition the procedure actually requires**, and to
make it a command the agent runs rather than an attribute it interprets:

```bash
EXT="$(jq -r .name package.json)"   # the Store slug is package.json `name`
gh api "repos/raycast/extensions/contents/extensions/$EXT" --jq '.[0].name' >/dev/null 2>&1 \
  && echo "PUBLISHED → consult the table" \
  || echo "NOT PUBLISHED → Route A"
```

| Published upstream? | `author` | Route |
| --- | --- | --- |
| **No** (first submission) | anyone, including you | **Route A** — always |
| Yes | someone else | **Route A** |
| Yes | you, **and** a mirror repo exists | **Route B** |
| Yes | you, no mirror | **Route A**, create the mirror afterward |

Two supporting moves made the fix durable:

1. **Name what the other route *is*.** Route B was implicitly a submission flow; it
   is actually *post-publication mirror maintenance*. Writing that down is what
   makes "not applicable to a first submission" obvious rather than a special case
   to remember. Implicitness is what let a correlated attribute become the key.
2. **Give the procedure an escape hatch.** "If you reach *verify against the
   published v1.x* and there is no published v1.x, you are in the wrong route — go
   to Route A." An agent that lands in the wrong branch can now self-correct instead
   of asking.

### Part 2 — when an agent reports a skill is broken, audit the always-loaded context too

The same agent also reported that `ship` was `status: stub` and that two of its
reference files did not exist. Both false:

```
$ rg -n 'status:' skills/*/SKILL.md
skills/scaffold/SKILL.md:6:  status: stub        # scaffold is the stub, not ship

$ ls reference/{pr-and-cleanup,sparse-checkout-discipline,my-extensions-mirror}.md
# all three exist: 64 / 127 / 96 lines
```

The claims came from a stale line in the user's global `CLAUDE.md` — an
always-loaded instruction file, written months earlier when both statements were
true. Nothing had updated it when they stopped being true.

This is a nastier failure than a stale doc, because:

- **It is injected into every session**, so the wrong facts arrive before the agent
  reads anything else, and they read as authoritative.
- **The blame lands on the wrong artifact.** The agent attributed the confusion to
  the skill. A maintainer who trusts that report edits the skill and leaves the
  actual source untouched.
- **Nothing points at it.** No test, no link checker, and no review step covers an
  instruction file's factual claims about *other* files.

**The durable fix is a precedence rule written into the stale file itself**, so the
next agent to hit a discrepancy resolves it correctly instead of reporting it:

> **Trust the skill over this file. If they disagree, the skill wins and this line
> needs fixing.**

The same audit found two more stale pointers in that file: one to a skill that had
been retired and absorbed elsewhere, and a missing pointer to a package added the
same week.

## Why This Matters

**Part 1** is the classic proxy-key bug, and its tell is that the key works for
every case you tested because your test cases all shared an unstated property
(here: already published). A correlated attribute is cheap to read, which is
exactly why it gets chosen over the real precondition — and it fails silently on
the first case where the correlation breaks.

**Part 2** matters more, because always-loaded context is *invisible
infrastructure*. Skills get reviewed when they are edited. Docs get link-checked.
A `CLAUDE.md` assertion about another file's state is checked by nobody, decays
silently, and is then read aloud with full confidence at the start of every
session. A stale claim there does not degrade gracefully — it manufactures
confident, specific, wrong statements that look like findings.

## When to Apply

- Any skill or workflow that branches between procedures on a metadata field —
  check whether the field is the precondition or merely correlates with it.
- **Whenever an agent pushes back on a skill.** Verify each claim separately against
  the tree; some will be about the skill and some about the context it was handed.
  Fix each at its own source.
- When adding, retiring, or renaming a skill — grep the always-loaded instruction
  files for references to it in the same change.
- **Not** applicable where the metadata field genuinely *is* the precondition (e.g.
  the fork prohibition on adding a personal dependency really does turn on
  authorship).

## Examples

**The misroute, verified against three live cases** after the fix:

```
claude-artifacts   slug=claude-artifacts  author=chrismessina   NOT PUBLISHED → Route A
get-app-icon       slug=get-app-icon      author=chrismessina   PUBLISHED
claude             slug=claude            author=florisdobber   PUBLISHED
```

Row 1 is the case that broke: same `author` as row 2, opposite correct route.

**Triaging the agent's three claims** — the pattern worth copying:

| Claim | Verdict | Source | Fix |
| --- | --- | --- | --- |
| "Route B is pointed to but Route A would be simpler" | **true** | the skill | re-key the routing decision |
| "`ship` is `status: stub`" | false | stale global `CLAUDE.md` | correct the line, add a precedence rule |
| "its reference files don't exist" | false | same stale line | same |

Two of three claims were false and the agent was still right to escalate — the
*conclusion* ("Route A would work and is simpler") was correct even though two
premises were wrong. Worth remembering when weighing agent feedback: bad premises
do not make the pushback bad, and a report that mixes true and false claims needs
each one checked rather than the whole thing accepted or dismissed.
