# CLAUDE.md

Guidance for Claude Code working in this repo. The README is the human-facing manual for the
sync workflows and the install loop — read it for those. This file covers what an agent gets
wrong here.

## What this is

Two things that share a repo: the **`raycast-extensions` Claude Code plugin**
(`plugins/raycast-extensions/`) and the **GitHub Actions sync workflows** that keep standalone
extension repos current against `raycast/extensions`. Neither is a Raycast extension — there is
no `ray build` here, and `package.json` is `private: true` with Prettier as its only dependency.

It is also, since 2026-08, the durable home for **learnings written out of extension repos**
(`docs/solutions/`), because those repos gitignore their own `docs/` to keep agent notes out of
Store PRs. A learning that lives only in an extension checkout has no git copy and has been
lost that way before.

## The README's status block is stale — trust the files

The README's plugin section still says **"Status: v0.1.0 … `scaffold` / `ship` are first-draft
stubs."** All three claims are false:

- `plugin.json` and `marketplace.json` are both at **0.5.0**.
- `ship/SKILL.md` is ~56 KB and complete, with the Route A/B topology, the staleness gate, and
  the compliance gate all authored.
- `scaffold` was completed 2026-07-28.

It also **omits `review-pr` entirely** — from the skills table and from the marketplace
`description` — though the skill has existed since 2026-07-24.

This is not a cosmetic docs bug. A stale "ship is a stub" note misrouted a real agent shipping
`claude-artifacts`. **When a prose description and a file disagree, the file wins**, and the
prose needs fixing in the same change.

`package.json` is a third version number (`0.2.0`) and drifts freely — it is unpublished and
governs nothing. The two that must agree are `plugins/raycast-extensions/.claude-plugin/plugin.json`
and `.claude-plugin/marketplace.json`; `claude plugin tag` validates exactly that pair.

## Editing the plugin

**Install copies into a version-keyed cache — it is not a symlink.** Editing a `SKILL.md` here
does nothing to the running plugin until the cache is refreshed, and same-version refreshes are
sticky. Bump the version in both files above for anything structural (new skill folder, new
reference file), then refresh and restart. The README's *Iterating* section has the commands.

The practical consequence: **a skill you just edited is not the skill that runs in this
session.** Do not verify an edit by invoking the skill.

**Run `bash check-references.sh` after touching any skill or reference file.** It asserts every
`reference/X.md` a skill points at actually exists — the failure it catches is a skill shipping
a pointer to a file that was never authored or was lost from the install cache. Exit 0 = clean.

## `docs/solutions/` — the learnings corpus

Learnings from previous runs of these skills, filed by category with YAML frontmatter
(`module`, `component`, `problem_type`, `tags`). Categories in use: `workflow-issues/`,
`design-patterns/`, `tooling-decisions/`, `security-issues/`. Relevant when publishing behaves
unexpectedly, when a review raises something these skills should already know, or when a claim
in a skill looks stale.

Corpus vocabulary is self-consistent and worth matching: `component: development_workflow` for
process learnings, `module: publishing` for Store/mirror topics, `module: skills` for
plugin-authoring ones. Array items in frontmatter are double-quoted.

`CONCEPTS.md` at the repo root is the shared vocabulary — entities and named processes with
project-specific meaning (Fleet, House Style, Standalone mirror, Lock lease, Command process
isolation). Read it when orienting; add to it when a term needed defining.

**Nothing routed to either file until 2026-08-18**, when `ship/SKILL.md` gained a pointer. The
other three skills still do not reference the corpus — a learning nothing points at does not
compound, so wire new ones in when you write them.

## Conventions

- **Cite files in Markdown docs by absolute path** (`/Users/messina/Developer/GitHub/chrismessina/…`),
  never repo-relative. Learnings get consolidated *out of* extension repos into this one, and a
  relative path stops resolving the moment the file moves. Verify absolute citations resolve
  yourself — some path-checkers skip them and report clean.
- Prettier covers `yml`/`yaml`/`json` only (`npm run format`). Markdown is unformatted here.
- `MIRROR_MAP` in `dispatch-sync.yml` and the "Currently synced repos" table in the README are
  a matched pair. Changing one without the other silently stops dispatching for that extension.
