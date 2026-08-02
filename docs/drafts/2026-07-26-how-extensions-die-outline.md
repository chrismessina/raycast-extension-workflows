# OUTLINE — "How Raycast extensions die"

**Status:** outline only, no prose. For ChrisMessina.me.
**Target audience:** vibe-coding / indie-hacker / dev-rel / AI-tooling crowd.
**Length target:** 1,800–2,500 words + 3 charts.
**Data:** full census of `raycast/extensions` PRs, 2023–2026, pulled 2026-07-26. Method and
caveats in the appendix section below. Backing detail lives in
`plugins/raycast-extensions/reference/store-reviewer-feedback.md`.

---

## Title options

1. **"How Raycast extensions die"** — plain, high-curiosity, ages well.
2. **"0 to 0.5 is now free. 0.5 to 1 is where 67% of extensions die."**
3. **"The last mile ate your side project: 4,000 pull requests on what happens after the demo works."**
4. **"Nobody rejected your extension. The clock did."**
5. **"Two-thirds of new Raycast extensions never ship. I read ~150 pull requests to find out why."**

*Recommendation: #1 as title, #4 as subtitle/dek. #2 is the social-post hook.*

---

## The thesis (one line, to be stated early and returned to)

- AI made the **first 50%** of building software nearly free. It did **not** touch the second
  50% — and the second 50% is almost entirely *non-coding* work: prior art, conventions,
  metadata, and **responding to a human for five weeks**.
- The gap is now measurable. This is what it looks like in one well-run public repo.

---

## Section 1 — Cold open

- Beat: describe the shape of a dead PR without naming it as death. Submission → bot
  congratulates → a maintainer asks one friendly question → silence → stale label → closed.
- The line to land: **no one ever says "rejected."**
- Pivot: I expected to find bad code. That is not what kills these.

## Section 2 — The numbers

*Exhibit A — chart: unmerged share of resolved PRs, Jan–Jul, 2023→2026.*

| Year | Merged | Closed unmerged | Failure rate |
|---|---:|---:|---:|
| 2023 | 1,288 | 492 | 27.6% |
| 2024 | 1,638 | 514 | 23.9% |
| 2025 | 1,755 | 1,032 | **37.0%** |
| 2026 | 2,413 | 1,470 | **37.9%** |

- Beat: the inflection is **2024 → 2025**, not this year. Rate jumped ~13 points and then
  *plateaued*.
- **Discipline note — do not overclaim.** This correlates with mainstream AI coding assistants
  but does not prove causation. Say so in the piece; it buys credibility and costs nothing.
- The more defensible framing: **volume nearly doubled while the failure rate held**. More
  people are getting to "it works on my machine" than ever. The same share are getting stuck
  right after.
- **Quarter-over-quarter within 2026 is flat**, and saying so out loud pre-empts the "AI slop
  is flooding the repo *right now*" misreading:

| | Q1 2026 | Q2 2026 |
|---|---:|---:|
| Submissions | 989 | 781 |
| Merged | 321 | 239 |
| Failed | 667 | 480 |
| Failure rate | **67.5%** | **66.8%** |

  - Two independent quarters, 1,770 PRs, same answer. **Report as "flat," never as
    "improving."** The step change was 2024→2025 and it has held.
  - *Credibility move: state that Q2 was pulled as a genuine out-of-sample replication after
    the Q1 conclusions were already written. That's rare in a blog post and readers notice.*

*Exhibit B — chart: new-extension PRs, Q1 by year (stacked merged/failed).*

| Q1 | Merged | Failed | Failure rate | Submissions |
|---|---:|---:|---:|---:|
| 2024 | 154 | 143 | 48.1% | 297 |
| 2025 | 179 | 330 | 64.8% | 509 |
| 2026 | 321 | 667 | **67.5%** | **988** |

- **The headline stat: 2 out of 3 new extensions never ship.**
- Submissions **3.3×** in two years; merges only **2×**.
- The control that makes it land: in the same quarter, PRs that were *not* new extensions
  failed at **18.9%**. Same repo, same reviewers, same bots. **The difference isn't the code
  — it's the lifecycle.**
- Why Q1 and not "this year": Q1 is fully resolved (2 of 1,999 still open). Recent windows are
  right-censored — PRs that haven't failed *yet*. Mention this; it is the single easiest way
  for a critic to dismiss the piece.

## Section 3 — The mechanism (the actual scoop)

*Now backed by per-PR data: n=989 Q1-2026 new-extension PRs from the GitHub search API.*

**Lead with the single most surprising number:**

- **Zero.** Not one of the 989 PRs — merged or failed — had zero comments. The median *failed*
  PR got **four**. **Nobody is being ignored.** Failure is a conversation that stopped.

*Exhibit D — the money chart: merge rate by comment count. Combined Q1+Q2, n=1,770.*

| Comments | Merged | Failed | Merge rate |
|---:|---:|---:|---:|
| 0–2 | 2 | 326 | **0.6%** |
| 3–4 | 137 | 434 | 24.0% |
| 5–6 | 197 | 240 | 45.1% |
| 7–9 | 167 | 100 | **62.5%** |
| 10+ | 57 | 47 | 54.8% |

- Q2 alone: **0 merged out of 148** PRs with 0–2 comments. The cliff is not a Q1 artifact.
- **Zero PRs out of 1,770 had zero comments** — in *both* quarters, for *both* outcomes.

- **Be honest about causality in-post** — it's the strongest move available and critics will
  raise it anyway. Merged PRs accrue comments partly *because* they progress. The claim that
  survives: the 0–2 row. **2 merges vs 178 failures.** Nothing ships without a conversation,
  and a quarter of failures never got past two replies.
- Do **not** write "comment more to get merged." Write: *the shape of a surviving PR is a
  thread with a half-dozen turns in it.*

**Then the draft mechanism:**

- **77.2%** of failed Q1 new-extension PRs were in **draft** at close. Of merged PRs: **zero**.
- Sample of 10 draft-dead PRs: **7 converted to draft by a maintainer**, 1 by the author, 2
  pure silence.

**Then when they die** — the stale-bot fingerprint is visible in the histogram:

| Window | Share | What it is |
|---|---:|---|
| < 1 day | 26.5% | Withdrawn/superseded, median **1** comment — a *different* story; separate it out |
| 1–14 days | 10.2% | Early exits |
| 14–25 days | 23.7% | Pre-stale abandonment |
| **25–60 days** | **35.5%** | **The stale-bot zone** (25-day label + 7-day close) |
| 60+ days | 4.0% | Long tail |

**And the finding that kills the easy explanation:**

- 714 distinct authors in Q1; **77.7% submitted exactly one** (Q2: 81.4%).
- Merge rate by author experience:

| | one-PR authors | repeat authors |
|---|---:|---:|
| Q1 | 31.7% | 33.5% |
| Q2 | **36.8%** | **27.8%** |

- **The direction flips between adjacent quarters.** A predictor that reverses sign is noise.
  State it plainly: *prior experience does not predict whether your extension ships.*
- Beat: *if this were just newcomers not knowing the ropes, repeat contributors would do much
  better. They don't — in either direction.* What separates outcomes isn't familiarity, it's
  finishing **this** thread.
- Of 520 Q1 authors with a failed extension, only **12.5%** landed one that quarter (Q2: 10.6%).

## Section 3.5 — The window is closing (new, and the most actionable finding)

*Exhibit E — median days-to-merge, Q1 vs Q2, with the 25-day stale line drawn across.*

| | Q1 | Q2 |
|---|---:|---:|
| Median days to merge | 12.9 | **25.0** |
| p25 | 7.4 | 20.7 |

- Robustness (include it — this is the finding most likely to be challenged): restricted to
  PRs created in the **first month** of each quarter, so both cohorts have 90+ days of
  observation, **11.3 days → 24.9 days**. Censoring biases Q2 *downward*, so the real shift is
  at least this big.
- **The kicker: the median successful PR now takes as long as the stale-label threshold.**
  Success and abandonment have converged on the same timescale.
- Beat: the folk heuristic — *"three weeks of silence means it's dead"* — used to be roughly
  right and is now precisely wrong. It tells you to walk away at the exact moment the median
  winner is still in flight.
- This is the strongest practical takeaway in the piece. Consider promoting it into the dek or
  the social hook.
- The mechanic in the maintainer's own words (@pernielsentikaer, #24100):
  > "I converted this PR into a draft until it's ready for the review, please press the button
  > **Ready for review** when it's ready and we'll have a look 😊"
- Beat: **draft = the ball is in your court, and nothing happens until you click a button.**
  The 25-day stale clock keeps running while you don't.
- The trap most people never learn: **`ray publish` opens your PR as a draft by default.** You
  can be in the abandonment state before a human has ever looked at it.
- Narrative exhibit — #24105: ready → drafted → ready → drafted → abandoned → auto-closed.
  Ten weeks, two round trips, then nothing. *This is the loop.*

*Exhibit C — the funnel: 988 submissions → engaged → drafted → 321 merged.*

## Section 4 — Why they die: a taxonomy

*Ordered by frequency, and note that the order is inverted from where effort usually goes.*

1. **You built something that already exists.** (~12 of the closed-unmerged PRs I read)
   - The test is *"the same broad job,"* not feature overlap. Steam PR argued differentiation
     on pricing data and still lost.
   - **The app's own built-in features count as prior art.** One PR was rejected against
     Raycast's System Commands, not against any extension.
   - A *cluster* of small extensions counts as one incumbent (four at once, #28362).
   - The incumbent's author shows up and sides with consolidation: *"I'd genuinely rather grow
     it there."*
   - **"But the existing one is broken for me" does not work** — someone tried; it still died.
   - The kicker: **every duplicate-rejected PR I read had a 4/5 or 5/5 automated code review.**
     Perfect code, wrong premise.
2. **You ran out of stamina.** Stale bot: 25 days idle → label, 7 more → closed. Against a
   posted SLA of "up to 15 business days." A submission is a **five-week commitment**.
3. **Metadata, not code.** Screenshots wrong size/padding, generated rather than captured,
   containing real data (a VPN tool was asked for mock data). Missing `metadata/` folder.
   CHANGELOG date hardcoded instead of the merge-date placeholder.
4. **You didn't know the conventions existed.** The repo has a *public, machine-readable*
   review spec (`.github/copilot-instructions.md`) that ~nobody reads. Nine bot-enforced rules
   on top of it.
5. **You changed someone else's extension without asking.** Different failure entirely — the
   reviewer is the *author*, and the objection is design authority: *"Feature or UI changes are
   better proposed and discussed first, rather than implemented upfront."*

## Section 5 — Why AI makes this worse *and* better

- **Worse:** generation cost → ~0, so the marginal submission is less considered. The prior-art
  search is the one step an LLM won't do for you unprompted — and it's the step that decides
  the outcome. Also: 0→0.5 feels like 0→0.9, which is precisely why the last mile is a shock.
- **Also worse:** a clean bot review reads as *approval* to a newcomer. It isn't. It says
  nothing about whether the thing should exist.
- **Better:** every rule that kills these PRs is *mechanical and knowable in advance*. This is
  the ideal shape for an agent — a pre-flight gate you run before you ever open the PR.
- Personal proof point: I reverse-engineered the bot's ruleset from its own review comments
  and turned it into a script + checklist. Link the repo. Keep this short — the piece is not
  a tool ad.
- The honest limit: **the script can't answer the two questions that decide it.** Does this
  already exist, and will you still be here in five weeks?

## Section 6 — What to do (the takeaway box)

*Make this the most screenshot-able part of the piece.*

- **Before you write code:** search the store *and the app's built-in features*. If anything is
  close, decide up front — new thing, or a PR to theirs?
- **Frame the difference as a job, not a feature list.** "A price tracker," not "search, but
  with prices."
- **Read the repo's contribution spec.** Most repos have one; almost nobody opens it.
- **Automate what's mechanical.** Placeholder dates, screenshot dimensions, config drift,
  unused deps — none of this deserves a human review round.
- **Budget the last mile like real work.** Five weeks of thread-watching, not an afternoon.
- **Learn your ecosystem's "ball's in your court" signal.** Here it's draft state. Every
  ecosystem has one, and it's usually silent.
- **When you get the duplication question, answer it the same day.** The PRs that survived it
  answered fast and repositioned.

## Section 6.5 — "I'm not immune" (the personal spine)

*Place this before the close. It converts the piece from analysis into testimony and
disarms the "easy for you to say" reaction.*

- My lifetime record on this repo: **76 merged, 18 closed-unmerged, 4 open.**
- The trend is the point:

| Period | Merged | Failed | Merge rate |
|---|---:|---:|---:|
| Before 2026 | 36 | 17 | 67.9% |
| 2026 YTD | **40** | **1** | **97.6%** |

- Beat: **17 of my 18 failures are from before this year.** Same author, same repo, same
  reviewers. I did not get smarter — I got a process.
- Name what actually changed, concretely: a pre-flight checklist, answering the duplication
  question the same day, and treating "converted to draft" as a this-week deadline.
- Optional: name one of my own dead PRs and what I'd do differently. Specific > humble.
- This is also the natural, non-salesy place to link the tooling.

## Section 7 — Close

- Callback to the cold open.
- The reframe: this isn't gatekeeping — the maintainers are friendly, fast, and specific.
  It's that **shipping is a different skill from building**, and AI only automated one of them.
- Land the line: *0 to 0.5 has never been cheaper. 0.5 to 1 costs exactly what it always did.*
- Optional soft CTA: the repo, plus an offer to run the same analysis on another ecosystem.

## Appendix — method (short, in-post; builds trust with this audience)

- Source: public GitHub PR data for `raycast/extensions`. Aggregate counts from filtered
  searches (complete populations, not samples); per-PR distributions from the GitHub search API
  for new-extension PRs in **Q1 2026 (n=989)** and **Q2 2026 (n=781)** — 1,770 total.
- **Q2 was pulled as an out-of-sample replication after the Q1 conclusions were written.**
  Every headline finding reproduced; the one that didn't (author experience) reversed sign,
  which is reported as evidence it was never a real effect.
- Qualitative: ~150 PRs read across Jan–Jul 2026, merged / open / closed-unmerged.
- **Stated caveats** — cheap to include, expensive to omit:
  - Right-censoring: recent windows understate failure. Q1 used for all rate comparisons.
  - Comment-count↔outcome is **correlational**; merged PRs accrue comments by progressing.
  - `comments` counts the conversation thread, not inline review comments — the real
    engagement is *higher* than reported, which only strengthens the "nobody is ignored" point.
  - **⚠️ The two "comment" counts are not the same number.** GitHub's *search qualifier*
    `comments:` includes inline review comments; the *issues API* field does not. Same Q1
    query: 95 merged PRs with 3–4 comments by the API, 11 by search; 9 above 15 by the API,
    123 by search. All comment figures in the piece are **API-derived**. Worth a one-line
    footnote — this audience re-runs queries, and someone will hit this and think the numbers
    are wrong. Merged/failed/draft counts cross-check exactly between the two sources.
  - Bot comments (raycastbot, greptile) are included in comment counts; the 0–2 bucket is
    therefore *"almost no human conversation."*
  - Label-scoped counts depend on maintainers applying `new extension` consistently.
  - AI-assistance correlation ≠ causation; the data cannot identify AI-authored PRs.
  - One repo, one ecosystem. Generalize with care.
- **Reproducibility:** publish the query. `gh api -X GET search/issues --paginate -f
  q='repo:raycast/extensions is:pr label:"new extension" created:2026-01-01..2026-03-31'`.
  This audience will re-run it, and that's good.

---

## Charts to produce

1. Line/bar: failure rate by year, all PRs (2023–2026). *Point: the 2024→2025 step.*
2. Stacked bar: new-extension Q1 submissions, merged vs failed (2024–2026). *Point: the gap widens.*
3. Funnel or Sankey: 989 Q1-2026 submissions → 667 dead (split draft/non-draft) → 321 merged.
4. **Merge rate by comment count** (Exhibit D) — the strongest single visual. Bar chart,
   1.1% → 57.8%.
5. Histogram: days-to-close for failures, with the 25/32-day stale markers drawn in. The
   double hump (<1 day withdrawals, 25–60 day stale zone) tells the story without words.
6. *(optional)* Timeline strip of #24105's ready↔draft ping-pong.

## Distribution notes

- **Hook for social:** "1,770 Raycast extension submissions over two quarters. Two-thirds never
  shipped. Not one of them was ignored — the median failure got 3–4 comments. They just stopped
  replying."
- **Alt hook:** "PRs with 0–2 comments: 0.6% merge rate. PRs with 7–9 comments: 62.5%. The gap
  between shipping and dying is a handful of replies."
- **Strongest hook (use this one):** "The median Raycast extension now takes 25 days to merge.
  The bot marks your PR stale at 25 days. Success and abandonment now run on the same clock."
- Angle for dev-rel readers: this is a **contributor-funnel** post. Any ecosystem with a
  review queue can run the same query and will find its own version.
- Angle for AI/agent readers: a worked example of automating away a review loop by mining the
  reviewer's own output.
- Likely pushback to pre-empt in-post: *"this is just a stale-bot artifact"* → the 18.9%
  control group kills that. *"AI slop"* → the rate plateaued while volume rose; be careful.
- Offer Raycast a heads-up before publishing — the piece is complimentary about the
  maintainers and more useful to them if they aren't surprised by it.
