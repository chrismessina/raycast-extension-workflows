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

- **70.9%** of the 1,470 dead PRs in 2026 were sitting **in draft** when they closed.
- **3 of 1,470** had zero comments. **~99.8% got engagement.** Nobody is being ignored.
- Sample of 10 draft-dead PRs: **7 converted to draft by a maintainer**, 1 by the author, 2
  pure silence.
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

## Section 7 — Close

- Callback to the cold open.
- The reframe: this isn't gatekeeping — the maintainers are friendly, fast, and specific.
  It's that **shipping is a different skill from building**, and AI only automated one of them.
- Land the line: *0 to 0.5 has never been cheaper. 0.5 to 1 costs exactly what it always did.*
- Optional soft CTA: the repo, plus an offer to run the same analysis on another ecosystem.

## Appendix — method (short, in-post; builds trust with this audience)

- Source: public GitHub PR data for `raycast/extensions`, counts from filtered searches
  (complete populations, not samples), 2026-07-26.
- Qualitative: ~150 PRs read across Jan–Jul 2026, merged / open / closed-unmerged.
- **Stated caveats** — cheap to include, expensive to omit:
  - Right-censoring: recent windows understate failure. Q1 used for rate comparisons.
  - Label-scoped counts depend on maintainers applying `new extension` consistently.
  - AI-assistance correlation ≠ causation; no way to identify AI-authored PRs from the data.
  - One repo, one ecosystem. Generalize with care.

---

## Charts to produce

1. Line/bar: failure rate by year, all PRs (2023–2026). *Point: the 2024→2025 step.*
2. Stacked bar: new-extension Q1 submissions, merged vs failed (2024–2026). *Point: the gap widens.*
3. Funnel or Sankey: 988 Q1-2026 submissions → 667 dead (broken out by draft-at-death) → 321 merged.
4. *(optional)* Timeline strip of #24105's ready↔draft ping-pong.

## Distribution notes

- **Hook for social:** "2 out of 3 new Raycast extensions never ship. Only 3 out of 1,470 dead
  PRs were ignored. Everyone got feedback — almost nobody finished."
- Angle for dev-rel readers: this is a **contributor-funnel** post. Any ecosystem with a
  review queue can run the same query and will find its own version.
- Angle for AI/agent readers: a worked example of automating away a review loop by mining the
  reviewer's own output.
- Likely pushback to pre-empt in-post: *"this is just a stale-bot artifact"* → the 18.9%
  control group kills that. *"AI slop"* → the rate plateaued while volume rose; be careful.
- Offer Raycast a heads-up before publishing — the piece is complimentary about the
  maintainers and more useful to them if they aren't surprised by it.
