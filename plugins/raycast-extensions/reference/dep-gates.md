# Dependency gates

Known-good dependency targets for Raycast extensions. Consulted by `develop`'s
**Intent 2 — Modernization** before any *major-version* migration, and by `ship`'s dep
hygiene to know where the non-breaking ceiling is.

- **Last verified:** 2026-07-13, by census of all 34 `chrismessina/raycast-*` working
  repos (`package.json` `dependencies` + `devDependencies`).
- **Drift guard:** gates never move silently. If `develop` finds a newer version is the
  real known-good target, it **proposes** the change and asks for confirmation before
  editing this file. Never trust a gate blind past its verified date.

## The two-tier model

A single "current version" number is a trap: it pushes every extension across a major
it never needed. So each dep carries **two** gates.

- **FLOOR** — the version that is *proven safe everywhere*. This is the dominant cluster
  across the fleet. An extension at or above the floor needs no migration. An extension
  *below* it is stranded and is a genuine migration candidate.
- **LEADING EDGE** — a newer major that is *proven, but not yet the default*. Named with
  the extensions that actually prove it. Migrating to the leading edge is a deliberate,
  gated choice — not routine hygiene.

**Non-breaking bumps within a tier are `ship`'s dep hygiene. Crossing a major — floor →
leading edge — is `develop`'s modernization intent, and it is gated on this file.**

> 🚨 **`@raycast/api` is the exception: its FLOOR is not a submission target.** Anything you
> submit must be the newest release **on the major line it is already on**, in both manifest
> and `package-lock.json` — the lockfile is what ships. The floor below exists so a
> *migration* knows what is safe fleet-wide; it is never permission to submit stale.
> `ship` enforces this as a blocking gate.
>
> **Scoped to the major on purpose — do not "simplify" it back to bare `latest`.** On
> 2026-08-20 `2.0.3` took the `latest` tag, and a gate keyed on `latest` instantly blocked
> every extension in the fleet and demanded a major migration inside a submission run.
> Crossing a major is `develop`'s job, gated here. Query the in-major target with
> `npm view "@raycast/api@^$MAJOR" version | tail -1`.
>
> The pinned versions in this table are a **snapshot, not an oracle** — they go stale by
> definition. Check the registry at submission time; if the table disagrees with `npm
> view`, the registry wins and this row needs updating.

## Gates

| Dependency | FLOOR (safe everywhere) | LEADING EDGE (proven, opt-in) | Proven on |
|---|---|---|---|
| `node` | 22 | — | local toolchain is v22.22.3 |
| `@raycast/api` | `^1.104` | `^1.104` (latest 1.x) | fleet-wide; **v2 exists but is NOT adopted — see below** |
| `@raycast/utils` | `^2.2` | — | `^1.17` still in use; see note below |
| `eslint` | `^9` | `^10` | `airbuddy` (10.5.0), `tesla-energy` (10.1.0) |
| `typescript` | `^5.9` | `^6` | `airbuddy` (6.0.3), `tesla-energy` (6.0.2) |
| `@raycast/eslint-config` | `^2.1` | `^2.2` | `airbuddy` (2.2.0) |
| `prettier` | `^3` | — | fleet-wide |
| `@types/react` | `^19` | — | fleet-wide |

### `@raycast/utils` — a split, not a gate

The fleet is genuinely split between `^1.17` and `^2.2`, and **v1 extensions are not
stranded** — they're just on the older major. Treat a `^1.17` → `^2.2` move as a real
migration (v2 changed hook signatures), not a hygiene bump. Don't bulk-migrate; do it
when the extension is being worked on anyway.

### `@raycast/api` v2 — available, deliberately not adopted (assessed 2026-08-20)

`2.0.3` holds the `latest` tag and is the only 2.x release. **Stay on 1.x for now.** This
is a hold, not a warning about danger — v2 tested clean; there is simply no reason to be
first.

What the assessment found, by diffing the shipped `.d.ts` files and building a real
extension against v2:

- **It is a soft major.** `engines` (node ≥22.22.2) and `peerDependencies`
  (`@types/node`, `@types/react` 19, `react-devtools`) are **byte-identical** to 1.104.23.
  No Node or React migration.
- **Nothing we rely on was removed.** `Keyboard.Shortcut.Common` survives with the same
  17 members; `showToast`, `secondaryAction`, `showInFinder`, `Action.ShowInFinder`,
  `LocalStorage`, `Cache`, `updateCommandMetadata`, `environment.launchType` /
  `LaunchType` are all intact and undeprecated.
- **The renames are the "command → entry point" shift**, reflecting that an extension now
  exposes tools as well as commands: `environment.commandName` → `entryPointName`,
  `environment.commandMode` → `entryPointMode`, plus new `entryPointType: "command" | "tool"`.
  Old names are **deprecated aliases that still work**. Same for `KeyboardShortcut` →
  `KeyboardShortcutV1` (canonical `Keyboard.Shortcut` is unchanged) and a batch of
  `AI.Model.*` constants → `AI.Model["..."]` bracket form.
- **Verified on a real extension:** `get-app-icon` upgraded to 2.0.3 gave `tsc --noEmit`
  exit 0, `ray build` exit 0, `ray lint` exit 0, with no source changes.

**Why hold anyway:** on 2026-08-20 every extension in `raycast/extensions` was still on
1.x, the 1.x line was still shipping (1.104.25), and `developers.raycast.com/migration/v2`
returned 404 — no published migration guide. Being the only v2 extension in the monorepo
means any Store-review or CI surprise is yours alone to debug.

**Fleet exposure if we do move:** effectively zero. The only `environment.commandName` use
is in `change-case`, which is a fork (author `erics118`), and it is a deprecation, not a
removal. `raycast-reader`'s `commandName` is its own local prop, unrelated to the API.

**Re-assess when** upstream extensions start landing on 2.x, a migration guide appears, or
1.x stops receiving releases.

## Stranded extensions (real migration candidates)

Found by the 2026-07-13 census — these sit *below* the floor and are the honest targets
of `develop`'s modernization intent:

| Extension | `@raycast/api` | `eslint` | `typescript` | Notes |
|---|---|---|---|---|
| `craftdocs` | `^1.47.3` | `^7.32.0` | `^4.4.3` | Badly stranded. ESLint 7 predates flat config entirely; a migration here is 3 majors of ESLint + 2 of TS. Expect real work, not a version bump. |
| `quick-call` | `^1.80.0` | `^8.22.0` | `^4.7.4` | Stranded. ESLint 8 → 9 is the flat-config cutover. |

Everything else in the fleet is at or above the floor.

## Migration rules

1. **One major at a time.** Never bump ESLint and TypeScript across majors in the same
   step — when it breaks you won't know which one did it.
2. **Build + lint + `tsc --noEmit` after each major.** All three. `ray build` (esbuild)
   does *not* typecheck — a green build is not evidence the code compiles. (See the
   `[both]` tsc rule in `house-style.md`.)
3. **ESLint 8 → 9 is the flat-config cutover**, not a version bump. `.eslintrc.*` →
   `eslint.config.js`. Budget for it. `@raycast/eslint-config` ≥ 2.x ships the flat
   config; pair the bump.
4. **The gate is not an instruction to migrate.** An extension sitting happily on the
   floor should stay there unless there's a reason to move. Modernization is gated
   *because* it's disruptive, not encouraged because it's available.
5. **If you discover a gate has moved** (e.g. ESLint 10 becomes the fleet default),
   propose an edit to this table and ask for confirmation. Then update "last verified."

## Re-running the census

To re-derive this table from ground truth rather than trusting the date:

```bash
cd ~/Developer/GitHub/chrismessina
for d in raycast-*/package.json; do node -e '
const p=require(process.cwd()+"/"+process.argv[1]);
const dd={...(p.dependencies||{}),...(p.devDependencies||{})};
const g=k=>String(dd[k]??"-"), pad=(s,n)=>String(s).padEnd(n);
console.log([pad(p.name??"?",16),pad(g("@raycast/api"),12),pad(g("eslint"),10),pad(g("typescript"),10)].join(" "));
' "$d" 2>/dev/null; done | sort
```
