---
name: scaffold
description: Ideate and scaffold a NET-NEW Raycast extension — when no extension exists yet and you need to shape the idea, pick the command type, and lay down the manifest + first command. Fires on "create / start / scaffold a new Raycast extension." Hands off to `develop` once files exist. Do NOT use to change an existing extension (that's `develop`).
metadata:
  stage: "1 — ideate + scaffold net-new"
  status: stub
---

# scaffold

> **STUB — authored to first-draft depth.** Deep authoring pending. The design contract is fixed; the prose below is the skeleton.

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

   *(Overlay content to be drawn from the Craft Raycast docs MCP — `https://mcp.craft.do/links/CSd4xy0mQPc/mcp` — at authoring time. See `docs/shelf.md` and the design spec.)*

## Output location

Scaffold into a standalone working dir / `chrismessina/raycast-{name}` repo. Mirror-sync wiring happens **after first merge** (manual PR the first time; automation takes over after). See `reference/my-extensions-mirror.md`.

## Hands off

→ `develop` once files exist and you're writing real command code.

## House Style from the start

New code must conform to House Style as it's written — see `reference/house-style.md` (`[build]` entries) and `reference/keyboard-conventions.md`. Don't scaffold code that the `ship` house-style audit would immediately flag.
