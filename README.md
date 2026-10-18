# One Breath Down

**Dive deep, grab the pearls, and make it back before you run out of breath.**

A 2D side-view pearl diving game made solo for **GMTK Game Jam 2026** (theme: *Countdown*), built in **Godot 4.7**.

Inspired by the Egyptian film *The Diver* and the Gulf's pearl-diving history, the economy the region lived on before oil. The countdown is not a timer bolted onto the screen. It is the breath your diver is holding.

## How it plays

1. **Dive.** Your breath starts running out the moment you go under.
2. **Collect.** Pearls get rarer and more valuable the deeper you go.
3. **Decide.** Turn back whenever you want. The greedier you are, the longer and more dangerous the swim home.
4. **Ascend.** Swim back up through the same hazards, now with less air and heavier pockets.
5. **Surface.** Make it before your breath hits zero and every pearl you carry is banked. Fail, and the run's pearls are lost.
6. **Upgrade.** Spend banked pearls in the ship shop on gear that takes you deeper next time.

## Features

- **Breath system** that drains faster when you swim hard and the more pearls you carry
- **Three depth zones:** Sunlit, Twilight, and Midnight, each darker and more dangerous
- **Four pearl types:** Seed, Rose, Golden, and Black, worth more the deeper they are
- **Nine sea creatures** including sharks, hammerheads, tiger sharks, jellyfish, octopuses, sea snakes, and swordfish, with patrol, chase, charge, and drifting-aura behaviors
- **Procedural cave walls** and depth-based spawning
- **Ship hub** with an upgrade shop and inventory
- HUD with a depth ruler, zone banners, and breath and stamina meters
- Full menu set: main menu, options, controls, pause, game over, and credits

## Controls

| Action | Input |
|---|---|
| Swim | WASD or arrow keys |
| Attack | Space or J |
| Inventory | I |
| Shop | F (at the ship) |
| Pause | Esc |

## Running it

Requires [Godot 4.7](https://godotengine.org/download) (Forward+ renderer).

```bash
godot --path .
```

A Windows Desktop export preset is included.

## Project layout

```
scenes/     Game, player, enemies, pearls, world, HUD, menus
scripts/    Components (breath, health, stamina), enemies, world gen, UI, autoloads
data/       Zone, pearl, and enemy definitions as Godot resources (.tres)
docs/       Game design doc, phase plans, HUD spec, visual bible
audio/, visuals/, fonts/, theme/
```

The full design is in [docs/gdd.md](docs/gdd.md).

## Credits

Design, code, and build by **Ahmed Abdelnasser**.

Art and audio come from several itch.io creators. Full attribution is in [CREDITS.md](CREDITS.md), which the in-game Credits screen also reads.
