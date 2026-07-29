---
name: scaffold
description: Ideate and scaffold a NET-NEW Raycast extension — when no extension exists yet and you need to shape the idea, pick the command type, and lay down the manifest + first command. Fires on "create / start / scaffold a new Raycast extension." Hands off to `develop` once files exist. Do NOT use to change an existing extension (that's `develop`).
metadata:
  stage: "1 — ideate + scaffold net-new"
  status: complete
---

# scaffold

## When this fires vs. not

- **Fires:** no extension exists yet. You're creating the folder, `package.json` manifest, and the first command/view.
- **Does NOT fire:** the extension already exists and you're changing it → that's `develop`.

The seam is **binary on existence**, so triggers never overlap with `develop`.

## Ideation: reuse, don't rebuild

1. Run `superpowers:brainstorming` for idea-shaping. Do **not** re-implement an interview here.
2. Apply the **Raycast-API constraints overlay** on top of the brainstorm output:
   - Command type: `view` vs `no-view` vs `menu-bar` vs `AI tool` (`@raycast/api` tools).
   - API capabilities and limits (what Raycast can/can't do for this idea).
   - Single-command vs multi-command shape.

   **Source the overlay from the live docs, not from memory** — same rule as every other
   skill here. Use `reference/store-guidelines.md`'s step 1 (context7 →
   `/llmstxt/developers_raycast_llms-full_txt`, `WebFetch` fallback). Scope one question
   per call, e.g. *"when to use a menu-bar command vs a view command"*.

   *(This previously pointed at `docs/shelf.md` and a Craft MCP endpoint. Neither is
   reachable: `docs/shelf.md` does not exist in this repo — verified 2026-07-28 — and the
   MCP is not wired into this workspace. A step that depends on unavailable material is a
   step that silently doesn't run.)*

## Compliance gate — BEFORE generating files

**A net-new extension is the only path into the fleet that no other skill audits.**
`develop` assumes the extension exists; `ship`'s pre-flight runs at submission, by which
point a wrong *product shape* (config-as-a-command, a Windows claim on a macOS-only
extension, a non-MIT license) is expensive to undo. Catch it here.

1. **Fetch the Store rules** — `reference/store-guidelines.md`, steps 1 and 2b. Run 2b's
   conditional router against the *intended* shape: planning a menu-bar command means
   fetching the menu-bar page **now**, not after it's written.
2. **Decide and write down**, before any file exists:
   - command mode(s) — `view` / `no-view` / `menu-bar` / AI `tools`
   - `platforms` — claim **only** what you'll actually support (an `osascript` call is
     macOS-only; don't list `Windows`)
   - `categories` — from the Store's fixed list
   - every piece of user config → a `preferences` entry. **Never a setup command.**

## Scaffold procedure (executable)

```bash
mkdir -p raycast-<name> && cd raycast-<name>
npm init -y
# Caret range, matching the ecosystem convention (verified 2026-07-29: every extension
# in the fleet and upstream uses `^`). `@latest` pins the CURRENT version into the
# lockfile, which is what the Store actually checks — do NOT use --save-exact.
npm install @raycast/api@latest
npm install --save-dev @raycast/eslint-config eslint prettier typescript @types/node @types/react
```

Then write the manifest. **These fields are required and are what a reviewer checks
first** — `name` must be the kebab-case Store slug and match the directory:

```jsonc
{
  "name": "<kebab-case-slug>",
  "title": "<Human Title>",
  "description": "<one sentence, specific — not 'a Notion extension'>",
  "icon": "icon.png",                    // 512×512 PNG in assets/
  "author": "chrismessina",
  "license": "MIT",                      // MIT is REQUIRED
  "platforms": ["macOS"],                // only what you support
  "categories": ["Productivity"],
  "commands": [{ "name": "index", "title": "…", "description": "…", "mode": "view" }],
  "scripts": {
    "build": "ray build -e dist",
    "dev": "ray develop",
    "lint": "ray lint",
    "fix-lint": "ray lint --fix",
    "publish": "npx @raycast/api@latest publish"
  }
}
```

**Then create the files the manifest promises — the build fails without them.** A
manifest referencing `"name": "index"` and `"icon": "icon.png"` needs all three:

```bash
mkdir -p src assets

# src/<command-name>.tsx — MUST match the command's `name` in the manifest.
cat > src/index.tsx <<'EOF'
import { List } from "@raycast/api";

export default function Command() {
  return (
    <List>
      <List.EmptyView title="Nothing here yet" description="Replace me." />
    </List>
  );
}
EOF

cat > tsconfig.json <<'EOF'
{
  "$schema": "https://json.schemastore.org/tsconfig",
  "include": ["src/**/*", "raycast-env.d.ts"],
  "compilerOptions": {
    "lib": ["ES2023"],
    "module": "commonjs",
    "target": "ES2022",
    "strict": true,
    "isolatedModules": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "jsx": "react-jsx",
    "resolveJsonModule": true
  }
}
EOF

printf 'node_modules\ndist\nraycast-env.d.ts\n.DS_Store\n' > .gitignore
```

**`assets/icon.png` (512×512) is a real PNG you must supply — the build fails without
it.** It cannot be generated here; ask the user for it, or use a placeholder and flag it
as a blocker in your report. Do not claim the scaffold is complete while the icon is
missing.

**Verify before handing off — all four must pass:**

```bash
ls package-lock.json                  # REQUIRED by the Store; npm only, never yarn/pnpm
npx tsc --noEmit                      # build/lint do NOT typecheck
npm run build
npm run lint
```

A scaffold that hasn't built and linted is not a scaffold — it's a guess. Do not hand to
`develop` until all four are green.

## Output location

Scaffold into a standalone working dir / `chrismessina/raycast-{name}` repo. Mirror-sync wiring happens **after first merge** (manual PR the first time; automation takes over after). See `reference/my-extensions-mirror.md`.

## Hands off

→ `develop` once files exist and you're writing real command code.

→ then `ship`, which submits a net-new extension via **Route A (`ray publish`)** — the
default for **every** first submission. Do **not** let `author: chrismessina` route a
never-published extension into Route B: that's mirror *maintenance* and its first step
diffs against a published version that doesn't exist yet. A standalone
`chrismessina/raycast-<name>` mirror, if you want one, is created **after** the first
merge — not as a prerequisite for submitting. (Misroute reported 2026-07-26 on
`claude-artifacts`; see `ship`'s "Submission — pick the topology FIRST".)

## House Style from the start

New code must conform to House Style as it's written — see `reference/house-style.md` (`[build]` entries) and `reference/keyboard-conventions.md`. Don't scaffold code that the `ship` house-style audit would immediately flag.
