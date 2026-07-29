# Store reviewer feedback — the human gate

What the `raycast/extensions` maintainers actually say, harvested verbatim from ~95 sampled
PRs (2026-03 → 2026-07). The bot's rules are in
[`greptile-review-rules.md`](greptile-review-rules.md); **this file is the one that decides
whether an extension ships.**

The reviewers, in rough order of how often they appear: **@0xdhrv** (the overwhelming
majority of new-extension reviews), **@pernielsentikaer**, **@samuelkraft**,
**@thomaspaulmann**, plus the **owner of the extension you're patching** on any `Update <ext>`
PR, and **@raycastbot** for automation.

---

## The numbers (full census, not a sample)

GitHub's filtered PR counts are a complete population, so these are censuses rather than
estimates. Repo: `raycast/extensions`. Pulled 2026-07-26.

**All PRs, same Jan 1 – Jul 26 window each year:**

| Year | Merged | Closed unmerged | Unmerged share of resolved |
|---|---:|---:|---:|
| 2023 | 1,288 | 492 | 27.6% |
| 2024 | 1,638 | 514 | 23.9% |
| 2025 | 1,755 | 1,032 | **37.0%** |
| 2026 | 2,413 | 1,470 | **37.9%** |

**New-extension PRs only** (`label:"new extension"`), Q1 of each year — Q1 is used because it
is *fully resolved*: only 2 of 1,999 Q1-2026 PRs are still open.

| Q1 | Merged | Closed unmerged | Failure rate | Submissions |
|---|---:|---:|---:|---:|
| 2024 | 154 | 143 | 48.1% | 297 |
| 2025 | 179 | 330 | 64.8% | 509 |
| 2026 | 321 | 667 | **67.5%** | **988** |

Q1 2026 submissions are **3.3× 2024's**; merges only doubled. In the same quarter, PRs that
were *not* new extensions failed at **18.9%** — new extensions fail at ~3.6× the rate of
everything else.

**How the 1,470 dead PRs of 2026 died:**

- **1,042 (70.9%) were in draft state** when they were closed.
- **3 (0.2%) had zero comments.** Effectively every one got engagement; almost none got
  finished.
- 773 PRs carried the `status: stalled` label in the window.

### Q1 2026 new-extension PRs, per-PR (n=989, GitHub search API)

The distributions, not just the totals:

| | Merged (321) | Failed (667) |
|---|---:|---:|
| Zero-comment PRs | **0** | **0** |
| Median comments | 6 | 4 |
| Median days to resolution | 12.9 | 21.1 |
| In draft at close | 0 | **515 (77.2%)** |

**Nobody is ignored.** Not one of the 989 PRs — merged or failed — had zero comments. The
median failed PR received **four**. Failure here is not neglect; it is a conversation that
stopped.

**Merge rate rises with conversation depth:**

| Comments | Merged | Failed | Merge rate |
|---:|---:|---:|---:|
| 0–2 | 2 | 178 | **1.1%** |
| 3–4 | 95 | 244 | 28.0% |
| 5–6 | 97 | 146 | 39.9% |
| 7–9 | 89 | 65 | **57.8%** |
| 10+ | 38 | 34 | 52.8% |

> **Read this correlationally, not causally.** Merged PRs accumulate comments partly *because*
> they progress — approvals and re-reviews are themselves comments. The defensible claim is
> the 0–2 row: **2 merges against 178 failures.** Essentially nothing ships without a
> conversation, and a quarter of all failures never got past two comments.

**When failures die** (days from open to close):

| Window | Share | What it is |
|---|---:|---|
| < 1 day | 26.5% | Withdrawn/superseded — median **1** comment. A distinct cohort, not abandonment. |
| 1–14 days | 10.2% | Early exits |
| 14–25 days | 23.7% | Pre-stale abandonment |
| 25–60 days | **35.5%** | **The stale-bot zone** (25-day label + 7-day close) |
| 60+ days | 4.0% | Long tail |

**Authors:** 714 distinct, **77.7% submitted exactly one** new-extension PR that quarter. Of
the 520 authors with at least one failure, only **65 (12.5%)** landed any new extension in the
same quarter.

### Q2 2026 — the rate is flat, not worsening

| | Q1 2026 | Q2 2026 |
|---|---:|---:|
| Submissions | 989 | 770 |
| Merged | 321 | 238 |
| Closed unmerged | 667 | 459 |
| Still open | 1 | **73** |
| Failure rate (of resolved) | **67.5%** | 65.9% *(provisional)* |
| Failed & in draft | 515 (77.2%) | 324 (**70.6%**) |

**Do not read Q2 as an improvement.** Q2 still has 73 open PRs against Q1's 1, so its rate is
right-censored. The true value is bounded: if every open PR eventually fails, 69.1%; if every
one merges, 59.6%. Q1's 67.5% sits inside that interval. **The honest conclusion is that the
failure rate held flat quarter over quarter** — which matters, because "AI slop is making this
worse *right now*" is the claim the data does not support. The step change was 2024→2025.

> ### ⚠️ Measurement trap: two different "comment" counts
>
> GitHub's **search qualifier `comments:` includes inline review comments**. The **issues API
> `comments` field does not** — it counts conversation comments only. Same quarter, same
> query, different answers:
>
> | Merged Q1 PRs | API field | Search qualifier |
> |---|---:|---:|
> | 3–4 comments | 95 | 11 |
> | ≥15 comments | 9 | **123** |
>
> The API max on any merged Q1 PR was 28; search reports 123 PRs above 15. Everything else —
> merged, closed-unmerged, and draft counts — cross-checks **exactly** between the two sources,
> so only this one field is affected.
>
> **Consequence:** the comment tables above are API-derived and internally consistent. Do not
> extend them with search-derived numbers, and do not compare comment counts across quarters
> unless both came from the same source. Getting the Q2 comment/time/author distributions
> requires the API export, not a search count.

> **Experience barely moves the needle — which rules out the obvious explanation.** One-PR
> authors merged at **31.7%**; multi-PR authors at **33.5%**. If this were simply newcomers
> not knowing the ropes, repeat contributors would do far better. They don't. What separates
> outcomes is *finishing the specific thread*, not general familiarity.

### Draft is not "unfinished" — it is the maintainers' hand-back mechanism

A sample of 10 draft-dead Q1 PRs: **7 were converted to draft by a maintainer**, 1 by the
author, 2 had no draft event and no human comment at all (pure silence → stale). The
mechanic is stated outright by @pernielsentikaer on #24100:

> "I converted this PR into a draft until it's ready for the review, **please press the button
> Ready for review when it's ready** and we'll have a look 😊"

So: **draft means the ball is in your court, and nothing will happen until you click a
button.** The stale timer keeps running the whole time. #24105 shows the full shape — ready →
drafted → ready → drafted → abandoned → auto-closed, over ten weeks.

> **Watch for the other draft trap:** `ray publish` opens your PR **as a draft** by default.
> If you never click *Ready for review*, you are already in the abandonment state before a
> maintainer has looked at it once.

---

## The escalation ladder — learn to read your position on it

Rejections are almost never stated as rejections. The sequence is always the same, and each
rung is quieter than the last:

1. **A question in a comment.** "Could we consider…", "Could you clarify whether…"
2. **PR converted to draft.** This is the real verdict. Every duplicate-rejected PR in the
   sample was drafted at this step, and drafting stops maintainer review.
3. **Stale label** — 25 days of no activity (`stale.yml`).
4. **Auto-closed** — 7 days after that.

> **"Converted to draft" is the moment to act, and it does not look like a deadline.**
> **70.9% of every PR that died in 2026 was sitting in draft when it closed.** Nobody says no;
> the clock does it.

**A PR you don't answer is a PR you lose.** `@raycastbot`'s standing notice —
*"initial review may take up to 15 business days"* — trains authors to stop watching, and the
25-day stale timer runs the whole time.

---

## 1. Duplication — the dominant rejection reason

Roughly **a dozen** of the sampled closed-unmerged PRs died here, and *every one of them had a
4/5 or 5/5 Greptile score*. Code quality has no bearing on this outcome.

The language is near-templated. @0xdhrv, across five different PRs:

> "We already have an extension in the Store that deals with this. Could we consider enhancing
> the existing extension below instead of creating another one? From the Store perspective,
> the core user intent overlaps significantly with the existing `quick-open-project`
> extension… having two extensions in the same space can reduce discoverability and split
> related functionality across multiple places." — #28265

> "Thanks for your contribution 🔥 We already have extensions in the Store that provide very
> similar GitHub pull-request workflows. Would you be open to exploring whether these
> improvements could be contributed to the existing GitHub extension instead of creating a
> separate extension?… Consolidating this functionality would help avoid duplication, reduce
> confusion for users, and keep closely related GitHub pull-request workflows maintained in
> one place." — #28729

> "Both extensions answer the same broad job: search Steam from Raycast… The extra pricing and
> discovery metadata is useful, but I'd consider it an enhancement to the existing Steam
> extension, not enough to justify a second Steam search extension." — #28111

### The four things that make this rule sharper than it looks

- **The test is "the same broad job," not feature overlap.** #28111 argued differentiation on
  pricing and wishlist tracking and still lost. The counter-offer was to *reposition* — "a
  dedicated Steam deals/wishlist price tracker rather than another general Steam search
  extension." Differentiate the **job**, not the feature list.
- **Raycast's own built-ins count as prior art.** #28385 wasn't compared to an extension at
  all: *"This overlaps with Raycast's built-in app management features: System Commands
  already include Quit All Apps / Quit All Apps Except Frontmost with exclusions, and Auto
  Quit supports quitting selected apps."* The bluntest version, @pernielsentikaer on #24097 in
  January: *"What's the purpose of this extension, there is nothing that's not possible out of
  the box in Raycast already."* Check the app before checking the Store.

> **This pattern is stable across the whole year, not a recent tightening.** The same
> objection, in the same words, appears in January (#24100 shell-alias, #24106 AdGuard,
> #24110 sleep-timer, #24118 bed-time-calculator) and in July (#28456, #28111, #28265,
> #28362, #28366, #28300, #28326). Duplication has been the top rejection cause all year.
- **A cluster of small extensions counts as one incumbent.** #28362 (a devtoolkit) was
  measured against four separate existing extensions at once — Ray Boop, Base64, Format JSON,
  UUID Generator.
- **The incumbent's author gets pulled in, and sides with consolidation.** On #28319,
  @gfazioli (author of App Updates) wrote: *"Extending that same model to the remaining
  sources is the direction App Updates is already heading and is next on its roadmap, not
  something that needs a separate extension. I'd genuinely rather grow it there."* Once that
  lands, the PR is over.

**"But the existing extension is broken for me" does not work.** On #28265 the author replied
*"I tried using that extension, but for some reason it opens the 'About This Mac' window"* —
and the PR still stalled and closed. A bug in the incumbent is an issue to file against it,
not a licence for a second extension.

### What to do instead

Decide *before writing code*, and if you submit anyway, lead the PR description with the
differentiation in job terms. The successful pattern in the sample is the author who accepts
the redirect fast: #29304 closed within a day of @pernielsentikaer asking *"I think it makes
sense to add this to the current one…we have in the store?"* and reopened as a PR against the
existing extension, which merged.

---

## 2. Screenshots — the most-repeated concrete request

Three distinct complaints, all from @0xdhrv:

- **"check the metadata screenshot size and padding"** (#28288, left three times on three
  separate images, then drafted). Requirements: **2000×1250 PNG**, ≤ 6, correct padding.
- **Must be genuine Raycast captures.** #28448 was asked to confirm the images were "actual
  image capture[s] from Raycast" rather than generated; #28907 was asked to recapture "using
  the Capture Window command" to preserve window sizing.
- **Must not contain real data.** #26501 (an enterprise VPN tool): *"use mock data for
  screenshot purposes since this extension might have sensitive information."*

---

## 3. Feedback on `Update <ext>` PRs — a different reviewer, different rules

When you patch an extension you don't own, the reviewer is usually **its author**, and their
objections are about design authority, not compliance. This is Chris's common case.

**Design philosophy pushback** — @the3ash on #29336 (window-sizer), rejecting a contributor's
UI changes:

> "I don't think this should be removed…users still need feedback if they try to star it again
> from a different group."
> "While this feature has some value, I think it detracts from the overall simplicity of the UI."
> **"Feature or UI changes are better proposed and discussed first, rather than implemented upfront."**

The author withdrew, citing "many conflicts with your design philosophy." The maintainer
closed with *"Some of the changes are indeed valuable, and I'll incorporate them into the next
version"* — i.e. the work was absorbed without the contributor. **Open an issue before
building UI changes into someone else's extension.**

**"Fix it upstream, not here"** — @bendrucker on #28449, on Windows-support code:

> "The Windows changes here mostly re-implement, on a second code path, behavior that a
> dependency already in the tree provides."
> "Seems like this could be worth fixing upstream versus working around in the extension."

@pernielsentikaer then drafted it pending a `raycast/utils` fix. A workaround that duplicates
a dependency's capability will be sent upstream.

**Housekeeping asks that quietly kill PRs.** @0xdhrv on #28139: *"Could you resolve the merge
conflict?"* — never answered, stale-closed. A one-line request is still a 25-day clock.

---

## 4. Approval looks like this

- **@0xdhrv:** "Looks good to me, approved ✅"
- **@pernielsentikaer:** "Looks good to me, approved 🔥"

Both arrive *after* the Greptile threads are resolved, and maintainers sometimes push fixes
themselves before merging (#28982, #28987). Merge is then performed by `raycastbot`.

**Bumping works, occasionally.** #28833's author posted *"Friendly bump — This PR is still
relevant and ready for review. All CI checks pass and the automated review feedback has been
addressed"* and it merged. #28828's author had to tell the bot *"the issue is not stalled."*
Note what makes a bump credible: **CI green and bot feedback already addressed.**

---

## Chris's own record (for calibration)

Lifetime against `raycast/extensions`: **76 merged, 18 closed-unmerged, 4 open** — an 80.9%
merge rate against an ecosystem baseline of 32.5% for new extensions.

The trend matters more than the total:

| Period | Merged | Failed | Merge rate |
|---|---:|---:|---:|
| Before 2026 | 36 | 17 | 67.9% |
| 2026 YTD | **40** | **1** | **97.6%** |

Same author, same repo, same reviewers. The variable that changed is process, not talent —
which is the whole premise of this plugin. Keep the 2026 number honest by keeping the habits:
answer the duplication question the same day, click *Ready for review*, and never let a thread
sit past a week.

## Pre-submission checklist (the half no script can run)

- [ ] **Searched the Store** for anything doing the same *broad job* — and **checked Raycast's
      built-in commands too**.
- [ ] If anything is close: decided to contribute *there* instead, or the PR body leads with
      the differentiation argument in job terms.
- [ ] For UI/behavior changes to someone else's extension: **proposed in an issue first.**
- [ ] Screenshots: real Capture Window output, 2000×1250, ≤ 6, padded, **no real data**.
- [ ] `author` in `package.json` matches the account opening the PR.
- [ ] No private/internal URLs, no internal planning docs, no raw source images in the diff.
- [ ] Calendar reminder to check the thread inside 25 days — **and treat a draft conversion as
      a same-week deadline.**
- [ ] After `ray publish`: **the PR is a draft. Click "Ready for review."** Nothing is queued
      until you do.

## Gotchas

- **A 5/5 Greptile score is not a signal about acceptance.** Every duplicate-rejected PR in the
  sample had one.
- **Silence is not neutral.** No maintainer ever posts "rejected." The stale bot does it.
- **Being drafted stops review.** Push the fix *and say you did* — a draft PR doesn't re-enter
  the queue on its own.
- **The incumbent extension's author is a stakeholder**, not a bystander. If your extension
  overlaps theirs, expect them in the thread.
- **Don't argue the incumbent is buggy.** File an issue against it; that's a different
  conversation and it doesn't unblock your PR.
