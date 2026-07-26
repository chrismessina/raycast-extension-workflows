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

## The escalation ladder — learn to read your position on it

Rejections are almost never stated as rejections. The sequence is always the same, and each
rung is quieter than the last:

1. **A question in a comment.** "Could we consider…", "Could you clarify whether…"
2. **PR converted to draft.** This is the real verdict. Every duplicate-rejected PR in the
   sample was drafted at this step, and drafting stops maintainer review.
3. **Stale label** — 25 days of no activity (`stale.yml`).
4. **Auto-closed** — 7 days after that.

> **"Converted to draft" is the moment to act, and it does not look like a deadline.** In the
> sample, the median outcome after a draft conversion with no author reply is a closed PR
> ~5 weeks later. Nobody says no; the clock does it.

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
  Quit supports quitting selected apps."* Check the app before checking the Store.
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
