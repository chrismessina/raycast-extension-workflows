# README template

The standard shape for a **self-authored** extension README. Adapted from
[`nerd-font-picker`](https://github.com/raycast/extensions/tree/main/extensions/nerd-font-picker),
whose top-matter Chris adopted on 2026-08-26, merged with the follow/stars/Store badge row
already shipping across the fleet.

**One file, two audiences.** The same `README.md` is rendered on the extension's Raycast
Store page *and* in `raycast/extensions`. There is no separate Store copy. Badges and
centered HTML survive Store review — verified 2026-08-26: the published
`extensions/get-app-icon/README.md` carries all three badges upstream.

**Scope:** self-authored extensions only. Do not impose this on a fork you contribute to —
the personal follow/stars badges transfer *your* identity onto someone else's extension.

---

## The template

Replace every `<placeholder>`. `<slug>` is `package.json` `name`; `<repo>` is the standalone
mirror, normally `raycast-<slug>`.

````markdown
<div align="center">

# <Extension Title>

[![Raycast Store](https://img.shields.io/badge/Raycast-Store-FF6363?style=flat-square&logo=raycast&logoColor=white)](https://www.raycast.com/chrismessina/<slug>)
[![Licence MIT](https://img.shields.io/badge/Licence-MIT-22C55E?style=flat-square)](LICENSE)
[![Follow @chrismessina](https://img.shields.io/github/followers/chrismessina?label=Follow%20chrismessina&style=social)](https://github.com/chrismessina)
[![Stars](https://img.shields.io/github/stars/chrismessina/<repo>?style=social)](https://github.com/chrismessina/<repo>/stargazers)

**<One sentence. What it does and for whom — not a feature list.>**

[Features](#features) • [Requirements](#requirements) • [Quick Start](#quick-start) • [Usage](#usage) • [Development](#development)

</div>

---

## Features

- **<Capability>** — <what it does, and the detail that makes it non-obvious>
- **<Capability>** — <…>

---

## Requirements

- [Raycast](https://www.raycast.com/) installed
- <Anything else: an installed app, an API key, a minimum OS. Omit the section entirely if there is nothing beyond Raycast.>

---

## Quick Start

1. Open Raycast and search for **"<Command Title>"**
2. <First-run behavior — a scan, an auth prompt, a cache build. Say if it takes time.>
3. <The core interaction>

---

## Usage

### Commands

| Command | Mode | Description |
| --- | --- | --- |
| <Command Title> | `view` | <what it does> |

### Actions

| Action | Shortcut | Description |
| --- | --- | --- |
| <Action Title> | `⌘ ⏎` | <what it does> |

### Preferences

| Preference | Values | Default |
| --- | --- | --- |
| <Title> | <type or options> | <default, or blank> |

---

## Development

### Project Structure

```
<repo>/
├── src/
│   └── <command>.tsx    # <role>
├── assets/              # Extension icon
├── package.json
└── tsconfig.json
```

### Scripts

| Script | Description |
| --- | --- |
| `npm run dev` | Start in development mode with hot reload |
| `npm run build` | Build for production |
| `npm run lint` | Run Raycast ESLint config |
| `npm run fix-lint` | Auto-fix lint issues |
| `npm run publish` | Publish to the Raycast Store |

### Clone & Run

```sh
git clone https://github.com/chrismessina/<repo>.git
cd <repo>
npm install
npm run dev
```

---

## Tech Stack

| Package | Role |
| --- | --- |
| `@raycast/api` | Raycast extension primitives |
| `@raycast/utils` | Higher-level Raycast utilities |
| `<dep>` | <role> |

---

MIT © [Chris Messina](https://github.com/chrismessina)
````

---

## Rules that are not obvious from the shape

### Nav anchors are plain — do NOT copy the source's `#-feature` form

`nerd-font-picker` links `[Features](#-features)` against a plain `## Features` heading.
**All five of its nav links are dead** — verified 2026-08-26 by slugifying its headings
(`#features #requirements #quick-start #usage #development`) against its link targets
(`#-features #-requirements …`). The leading dash is what GitHub generates for an
*emoji-prefixed* heading, and those headings carry no emoji.

So: either plain headings + plain anchors (this template), or emoji headings + the
dash form. **Never mix.** Check with:

```bash
diff <(grep -oE '\(#[a-z-]+\)' README.md | tr -d '()' | sort -u) \
     <(grep -E '^## ' README.md | sed 's/^## //' | tr 'A-Z' 'a-z' | tr ' ' '-' | sed 's/^/#/' | sort -u)
```

Lines only on the left are broken links.

### Badge order is deliberate

Store link first — it is the only badge a *user* (rather than a developer) can act on.
Licence second because Store reviewers look for it. The two social badges last: they are
the personal half, and they are the half that must never appear on a fork.

The `TypeScript` badge from the source template is deliberately dropped. It tells a reader
nothing they cannot infer, and every extension in the fleet would carry an identical one.

### The tagline is not the `package.json` description

`description` is indexed by Store search and should be keyword-bearing. The README tagline
is read by a human deciding whether to install. They are allowed to differ, and usually
should.

### Omit sections that would be empty

A `## Preferences` table with no preferences, or `## Requirements` listing only "Raycast
installed", is worse than no section. Delete it. The nav row must then drop the same entry
— a nav link to a deleted section is the failure this file's own anchor rule is about.

### `.github/FUNDING.yml` is mirror-only

It lives in the standalone mirror and **never ships to the monorepo**: a published
extension directory contains no `.github/` at all (verified 2026-08-26 against
`extensions/nerd-font-picker`, and `ray publish` drops `.github/` regardless). Funding for
`raycast/extensions` is the Raycast org's own, not a contributor's.

Canonical content, already in most of the fleet:

```yaml
github: [chrismessina]
custom: [https://venmo.com/Chris-Messina]
ko_fi: [chris]
```

Every self-authored **mirror** should carry it. Its absence is not a Store blocker and must
never block a submission.
