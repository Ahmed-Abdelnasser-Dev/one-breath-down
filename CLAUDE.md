# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

A playable vertical-slice dive game in **GDScript** (Godot 4.7). The loop works end to end: dive from
the ship, collect pearls against a breath countdown, dodge/fight enemies, surface at the ship to bank,
spend pearls in the shop, repeat.

The GDD's "Engine: Godot (C#)" header is obsolete — there is no C#, no `.csproj`, and `config/features`
has no Mono. Everything is GDScript; keep it that way unless the user says otherwise.

## Docs — read before changing behaviour

- `docs/gdd.md` — design intent: core loop, breath mechanic, pearl curve, hazards, depth zones, shop.
  Its pearl and upgrade tables are synced to the shipped resources, but **the `.tres` files and
  `shop_screen.gd` CATALOG are the source of truth**, not the doc.
- `docs/visual-bible.md` — authoritative for anything visual: palette, the no-smooth-gradients rule,
  the vertical-repetition rule, and the pixel-perfect contract (480x270, integer scale, nearest filter,
  camera zoom 1.0, `PIXELS_PER_METRE = 32`, background sprites at scale 4).
- `docs/audit-and-fix-plan.md` — a full audit with a phased fix plan. Phases 0-5 are largely landed;
  check it before "discovering" a problem it already documents.

## Architecture

- **Autoloads** (`scripts/autoloads/`): `Settings`, `Events`, `GameState`, `Juice`, `Sfx`.
  `Events` is a pure signal bus — emitters never reference listeners. `Juice` (shake/hitstop) and
  `Sfx` both listen on that bus rather than being called from gameplay code; keep new feedback
  wired the same way instead of reaching into nodes.
- **Zones** are the organising principle. `data/zones/*.tres` define Sunlit / Twilight / Midnight at
  0 / 50 / 150m. The background, prop spawning and lighting all key off the same boundaries, and each
  zone has one visual identity: clear water, then the drowned fleet, then bare rock. Preserve that.
- **The world is generated per run**: `CaveWallGenerator` builds the shaft (hand-authored width
  profile + three noise scales), `DiveSpawner` places pearls, `PropSpawner` places scenery,
  `EnemySpawner` streams enemies around the camera. All regenerate on `Events.run_reset`.
- **Depth is vertical**: the camera travels ~6400px straight down. Background art in `visuals/` was
  drawn for horizontal scrollers, so any layer that tiles must never complete a tile period during a
  descent (see the parallax comments in `scripts/background/background.gd`).

## Running and verifying

Godot is at `/usr/bin/godot`. Open the editor with `godot --path .`.

There is no test framework, lint or CI. Verify changes by **running the game and looking at it** —
the Godot MCP tools (`run_project`, `game_screenshot`, `game_eval`) work well for this. Useful notes:
- `game_click` takes window coordinates (1920x1080), i.e. 4x the 480x270 viewport coordinates.
- Held input via `game_key_hold` persists across resets; always release explicitly.
- Real time passes between tool calls, so breath drains and enemies attack while you inspect. For
  scripted inspection, set `BreathComponent.base_drain = 0` and raise health via `game_eval`.
- Only one instance can hold the MCP interaction port; an editor playtest blocks `run_project`.

## Layout

- `scenes/` — `Game.tscn` is the run scene; also `menus/`, `ui/`, `world/`, `enemies/`, `player/`.
- `scripts/` — mirrors `scenes/`, plus `autoloads/`, `components/`, `resources/`.
- `data/` — `pearls/`, `zones/`, `enemies/` as `.tres`. Prefer adding data here over hardcoding.
- `visuals/`, `audio/sfx/` — art and generated sound effects.
- `mcp_interaction_server.gd` in the repo root is a dev tool; exclude it from any export preset.
