# Store compliance gate

`ship`'s compliance gate. Absorbs the standalone `raycast-extension-review` skill —
**including its core principle, which is the whole point of this file:**

> **Do not rely on hardcoded rules. Fetch the live docs and audit against what they
> actually say.** If the docs conflict with prior knowledge — or with this file —
> **the docs win.**

That principle is why this file is a **procedure**, not a transcription of the Store
rules. A static copy of Raycast's requirements would go stale silently and start
producing confidently-wrong audits, which is worse than no audit at all. The small
cached section at the bottom is deliberately limited to facts that are structural and
slow-moving, and every one of them is stamped and re-checkable.

## Authoritative sources

- **Prepare an Extension for Store** —
  https://developers.raycast.com/basics/prepare-an-extension-for-store
- **Manifest reference** — https://developers.raycast.com/information/manifest

## Procedure

1. **Fetch.** Prefer **context7** — it indexes the Raycast developer docs and is faster
   than a raw page fetch:

   - `resolve-library-id("Raycast API")` → use `/llmstxt/developers_raycast_llms-full_txt`
     (High reputation, full-text index; verified 2026-07-13).
   - Then `query-docs` with a **scoped** question — one concept per call. Good:
     *"required package.json manifest fields for a Raycast extension"*. Bad: *"store rules"*.

   Fall back to `WebFetch` on the two URLs above if context7 is unavailable or returns
   nothing useful. Either way: **fetch before auditing.** Do not audit from memory.

2. **Audit against the fetched text**, not against recall and not against this file.

3. **Report** findings in three buckets, each citing the source URL:
   - **Compliant** — what already passes (say so; a silent pass reads as an audit that
     didn't run).
   - **Must fix** — blocks submission.
   - **Optional** — improves the listing but won't block.

4. **Route the fixes.** Compliance findings are metadata/asset work — README, CHANGELOG,
   icon, screenshots, categories, manifest fields — and stay in `ship`. **Anything that
   needs a code change hands back to `develop`.** `ship` never changes code behavior.

## Cached stable facts

*Last verified 2026-07-13 via context7. Re-fetch if older than ~90 days, and re-fetch
regardless before any first-time submission.* These are cached only because they are
structural; **the fetched docs remain authoritative over anything below.**

- **Icon:** 512×512px PNG. Light/dark variants via `icon.png` + `icon@dark.png`.
- **`CHANGELOG.md` is required** to document changes between releases. See the
  `{PR_MERGE_DATE}` rule in `ship`'s pre-flight — new top entry only; never re-stamp an
  entry that already carries a real date.
- **Raycast-specific manifest fields:** `name`, `title`, `description`, `icon`, `author`,
  `platforms`, `categories`, `commands`, `tools`, `ai`, `owner`, `access`. The manifest
  is a *superset* of npm's `package.json` — one file, both roles.
- **Naming convention — be specific, not generic.** If the extension only searches Notion
  pages, name it **"Notion Search"**, not "Notion". A generic name is only appropriate
  when the extension genuinely covers broad functionality. This sets correct user
  expectations and is called out explicitly in the Store prep docs.
- **Preferences** support `"required": true`, which makes Raycast prompt the user before
  the extension can run.

## Gotchas

- **A clean audit with zero findings is suspect.** If nothing came back, confirm the
  fetch actually returned content before reporting "compliant" — an empty fetch and a
  passing audit look identical in the output.
- **Screenshots are the most common staleness miss.** If a command or view was added,
  the screenshots are wrong. That's a `ship` weeding item, and it's easy to skip because
  the code is fine.
- **Don't let the cache above become the audit.** It exists to save a round-trip on
  structural questions, not to replace step 1.
