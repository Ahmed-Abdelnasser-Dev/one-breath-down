# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

This repo is a bare Godot project skeleton, not yet a working game — there are no scripts, no gameplay
code, and no git commits yet. The only real content is the design doc at `docs/gdd.md` and an empty
scene (`scenes/game-scene.tscn`, a single `Node2D`). When asked to build features, there is no existing
in-repo pattern to follow yet; consult the GDD for intended design and use standard Godot 4 conventions.

**Read `docs/gdd.md` first for any gameplay/design work.** It is the authoritative design doc: core loop,
breath/countdown mechanic, pearl value curve, hazard list, depth zones, and the upgrade shop. Section 6
("Open Questions") and Section 7 ("Scope Discipline Notes") are load-bearing — they list undecided
architecture (autoloads, scene structure, obstacle/pearl base classes) and an explicit cut order if time
runs short (shop/upgrades first, then content variety, never the core loop). Treat those as still-open
decisions, not settled facts.

## Engine / language note

`project.godot` targets Godot **4.7** (Forward+ rendering, Jolt Physics for 3D) but `config/features` does
not include C#/Mono, and there is no `.csproj`/`.sln` anywhere in the repo. This contradicts the GDD header
("Engine: Godot (C#)"). The `.vscode/launch.json` debug config is also the plain `godot` (GDScript) debugger,
not a C# one. Before adding scripts, confirm with the user whether this is going to be GDScript or C# —
if C#, the project needs `dotnet`/Mono support enabled first (`config/features` updated, `.csproj` created).

## Running the project

Godot is installed at `/usr/bin/godot`. Open the editor with:

```bash
godot --path .
```

There is no CLI build/test/lint tooling configured yet (no GUT test framework, no export presets, no
CI). If the user asks to run or test the game, do so through the Godot editor/`--path` invocation above
and describe what you did — there's nothing to script around yet.

## Layout

- `docs/gdd.md` — game design document, source of truth for mechanics.
- `project.godot` — engine config (Godot 4.7, Forward+, Jolt Physics).
- `scenes/` — currently just `game-scene.tscn`, an empty root node.
- `scripts/`, `audio/`, `visuals/` — created but empty; populate as work begins.