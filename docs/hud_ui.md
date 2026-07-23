# One Breath Down — HUD & UI Design

### Companion document to `gdd.md`

**Engine:** Godot (C#) | **Base resolution:** 1920×1080 | **Stretch:** `canvas_items` / `expand`

---

## 1. Purpose & Design Principles

The HUD exists to serve **one decision, repeated continuously: keep going down, or turn back now.**

Every element on screen is justified by that decision. If a widget doesn't feed the turn-back math, it doesn't ship.

**Principles:**

1. **The countdown owns the screen.** Breath is the largest, brightest, loudest element. It is the game's theme made visible.
2. **Peripheral readability.** During a dive the player's eyes are on the diver sprite, not the corners. Bars, colour shifts, and flashes must be readable in peripheral vision without a saccade. Numbers are for the moments the player *chooses* to look.
3. **Redundant encoding on purpose.** Breath is shown twice (bar + timer) and depth is shown twice (readout + ruler). One form is glanceable, the other is precise. This is not duplication — it is two different reading speeds for two different moments.
4. **Corners for state, centre for the world.** The centre 60% of the screen stays clear of UI at all times. Nothing may occlude a hazard.
5. **The HUD reacts, it doesn't narrate.** No tutorial text mid-dive, no "warning!" popups. Colour, scale, and audio carry urgency.

---

## 2. Screen Layout Map

```
+------------------------------------------------------------------+
| +-----------------------------+                +---------------+ |
| | BREATH [########------] 0:42|                |  LOOT         | |
| | $ 1,240                     |                |  o White  x5  | |
| | [] o kg                     |                |  * Rose   x2  | |           
| +-----------------------------+                |  # Black  x1  | |
| |= 0m                                          |               | |
| |=                                             |  -----------  | |
| |= 25m                                         |  Run    340   | |
| |=                                             +---------------+ |
| |= 50m ===== TWILIGHT =====                                      |
| |=                                                               |
| |= 75m                        [ diver + world ]                  |
| |=                                                               |
| |= 100m                                                          |
| |=                                            +----------------+ |
| |= 125m                                       | DEPTH    112 m | |
| |=                                            | BEST     168 m | |
| |= 150m ===== MIDNIGHT ====                   +----------------+ |
+------------------------------------------------------------------+
```

| Zone | Anchor | Contents | Visible during |
|---|---|---|---|
| A | Top-left | Breath bar + breath timer, total money | Dive + surface |
| B | Top-right | Loot table (current run) | Dive only |
| C | Bottom-right | Current depth, best depth | Dive only |
| D | Left edge (full height) | Depth ruler / meter indicator | Dive only |
| E | Bottom-centre | Contextual prompts (`Press F`, `Press I`) | Surface only |
| F | Full screen overlay | Vignette, low-oxygen tint, damage flash | Dive only |
| G | Full screen modal | Shop, inventory, pause menu, options, about, credits, run summary | On demand |

**Safe margins:** 48px from every screen edge at 1920×1080. All panels anchored to their corner, never centred, so ultrawide and 16:10 don't shuffle the layout.

---

## 3. Element Specifications

### 3.1 Breath Bar (Zone A)

The primary countdown display.

| Property | Spec |
|---|---|
| Type | Horizontal `ProgressBar` (or `TextureProgressBar` for a rope/hose-styled fill) |
| Size | ~420×36 px |
| Fill direction | Right-to-left drain (empties toward the left, reads as "running out") |
| Data source | `BreathSystem.Current / BreathSystem.Max` |
| Update | Polled every frame in `_Process`, not signal-driven |

**States by remaining ratio:**

| Ratio | Fill colour | Behaviour |
|---|---|---|
| 100–60% | Pale cyan | Calm, static |
| 60–30% | Amber | Slow pulse (~1 Hz), matches heartbeat SFX |
| 30–10% | Orange-red | Faster pulse (~2 Hz), bar edge glows |
| <10% | Red | Hard flash on each pulse, screen vignette tightens sharply |

**Extra reads to build in:**

- **Drain-rate ghost.** A lighter trailing segment shows where the bar was ~0.7s ago. When the player sprints or carries heavy loot, the gap widens visibly — this teaches the exertion cost mechanic without a tutorial.
- **Regen fill.** On surfacing, the bar refills left-to-right with a distinct bright-white sweep and a gasp/inhale SFX.

### 3.2 Breath Timer (Zone A, right of the bar)

| Property | Spec |
|---|---|
| Format | `M:SS` above 10s, `S.s` (one decimal) below 10s |
| Font | Largest numeric on screen (~48px), monospace or tabular figures |
| Data source | Same `BreathSystem.Current`, expressed in seconds |

The switch to a decimal under 10 seconds is deliberate: it makes the last stretch feel like it's accelerating, and it's the exact window where the player is doing precise "can I make it" math.

> **Use tabular/monospace digits.** Proportional digits cause the number to jitter horizontally as it counts down, which is very visible at this size.

### 3.3 Total Money (Zone A, below the bar)

| Property | Spec |
|---|---|
| Scope | **Persistent across the whole game**, not per-run |
| Data source | `GameState.Money` (autoload, saved to `user://save.cfg`) |
| Format | Currency icon + thousands separator, e.g. `⌾ 1,240` |
| Behaviour | Static during a dive. On a successful surface, counts up incrementally as loot is auto-sold, with a coin tick per increment |

Kept small and dim relative to the breath elements — it's reference information, not decision-critical mid-dive.

### 3.4 Loot Table (Zone B, top-right)

The greed meter. Shows exactly what the player stands to lose.

```
+---------------------+
|  LOOT               |
|  o  White     x5    |
|  *  Rose      x2    |
|  #  Black     x1    |
|  -----------------  |
|  RUN VALUE   340    |
+---------------------+
```

| Property | Spec |
|---|---|
| Scope | **Current run only.** Cleared on dive start |
| Rows | One per pearl type, created lazily — a row only appears after the first pearl of that type is collected |
| Row content | Type icon, type name, count. Per-type value shown on the row's right edge if space allows |
| Footer | Running total value of everything currently carried |
| Sort | By value ascending, so the rarest/most valuable pearl sits at the bottom nearest the eye's resting position |

**Feedback:**

- **On pickup:** the affected row scale-punches (1.0 → 1.15 → 1.0 over 0.15s) and the `RUN VALUE` number rolls up rather than snapping.
- **New type discovered:** row slides in from the right with a distinct chime.
- **Weight threshold crossed:** when carried weight starts costing speed (per `gdd.md`), the panel gains a subtle weight/strain indicator — a small filled bar under the footer, or the panel border shifting to amber. This makes the invisible carry penalty legible.
- **On death / drowning:** the whole panel desaturates to grey, the `RUN VALUE` number spins down to `0`, then the panel fades out. The player must *see* what they lost.
- **On successful surface:** rows fly one by one toward the money counter as they auto-sell.

### 3.5 Depth Readout (Zone C, bottom-right)

```
+------------------+
| DEPTH     112 m  |
| BEST      168 m  |
+------------------+
```

| Field | Scope | Data source |
|---|---|---|
| `DEPTH` | Live, current run | `Diver.GlobalPosition.Y` converted to metres |
| `BEST` | **Persistent across the whole game** | `GameState.BestDepth` |

**Notes:**

- Depth is a positive number that grows as the player descends. The world axis points down; convert once at the boundary (`metres = (diver.Y - surfaceY) / PIXELS_PER_METRE`) and never expose raw pixel coordinates to the UI.
- Round to whole metres. A decimal here is noise.
- **`BEST` is a record of deepest reached, not deepest survived.** Decide explicitly (see §9) — recording it even on a failed run rewards ambition and gives a consolation prize to a fatal dive, which fits the arcade loop.
- When `DEPTH` exceeds `BEST`, the `BEST` row locks to `DEPTH`, tints gold, and a small `NEW BEST` label pulses once. It should feel like breaking a record while it's happening, not in a post-run screen.

### 3.6 Depth Ruler / Meter Indicator (Zone D, left edge)

A vertical measuring-tape running the full screen height, scrolling with the diver. This is the element that turns raw depth into *place*.

| Property | Spec |
|---|---|
| Orientation | Vertical, left edge, ~72px wide, full screen height |
| Motion | Ticks scroll upward as the diver descends. The diver's own depth maps to a fixed screen Y (the diver's resting position, ~45% down) |
| Minor tick | Every 5 m — short line, no label |
| Major tick | Every 25 m — long line + numeric label (`25m`, `50m`, …) |
| Zone boundary | Full-width heavy line + zone name label (`SUNLIT`, `TWILIGHT`, `MIDNIGHT`) at 0m, 50m, 150m per `gdd.md` |
| Rendering | Draw procedurally in `_Draw()` from the current depth, or use a shader on a `ColorRect` with a scrolling UV. **Do not instantiate a node per tick** |

**Persistent markers overlaid on the ruler:**

| Marker | Meaning |
|---|---|
| Surface line (0m) | Bright, always drawn — the goal |
| Best-depth ghost | A dim gold line at `GameState.BestDepth`; passing it is the record-break moment |
| Zone bands | The ruler's background tints to match the zone colour, so the ruler itself darkens as the water does |

**Zone transitions:** as the diver crosses a boundary, the zone name fades in large and semi-transparent near the ruler for ~1.5s, then shrinks back into the ruler as a permanent small label. Cheap, high-impact, and it makes depth progression feel like an achievement rather than a number changing.

**Optional — "point of no return" marker (evaluate carefully):**
A computed line showing the deepest depth from which the player could still surface with their current breath, speed, and carry weight. Mechanically it's a clean, honest reading of the core tension.

Counter-argument: it converts a gut-feel gamble into an arithmetic problem the UI solves for the player, which may drain the tension the entire game is built on. **Recommendation:** build it behind a debug flag for tuning, and consider shipping it as an *upgrade* the player buys — that way it's a reward, not a default, and the early game keeps its fear.

### 3.7 Screen Overlays (Zone F)

Not widgets, but part of the HUD budget:

- **Vignette** — radius shrinks as breath depletes and as depth increases (two inputs, multiplied). Doubles as the Midnight-zone light radius.
- **Low-oxygen tint** — desaturation + red edge bleed under 20% breath.
- **Hazard flash** — brief white/red full-screen flash on damage or entanglement.
- **Surface bloom** — bright warm flash on breaking the surface, paired with the gasp SFX.

All of these live on a `CanvasLayer` **below** the HUD layer so they never wash out the numbers the player needs to read.

---

## 4. Surface State

When the diver breaks the surface, the HUD switches modes rather than showing a separate menu screen. The boat deck stays visible and playable — no hard scene cut.

**Sequence on surfacing:**

1. **Gasp** — breath bar refills over ~1.2s with an inhale SFX and a bright sweep. Refill is automatic and continuous while the diver stays at the surface.
2. **Auto-sell** — loot table rows fly to the money counter one at a time (~0.12s apart), each with a coin tick, money counter rolling up. Total sequence capped at ~1.5s regardless of loot count; any input skips it and settles instantly.
3. **Loot table clears**, dive-only widgets (loot, depth readout, ruler) fade out over ~0.3s.
4. **Prompts appear** in Zone E:

```
        [ F ]  Shop          [ I ]  Inventory        [ Space ]  Dive
```

**Prompt rules:**

- Prompts fade in only once the sell sequence finishes, so they never compete with the payoff moment.
- Show the actual bound key, read from the `InputMap` action, not a hardcoded string.
- Prompts are proximity-gated if there's a physical shop location on the dhow (approach the merchant → `F` appears); otherwise they're always present at the surface.
- If money is `0` and the shop has nothing affordable, the shop prompt dims but stays visible — the player should still learn it exists.

---

## 5. Shop Screen (`F`)

Modal, opened from the surface only. Pauses gameplay (`get_tree().paused = true`, HUD `CanvasLayer` on `PROCESS_MODE_ALWAYS`).

```
+--------------------------------------------------------------+
|  THE MERCHANT                                    $ 1,240      |
+---------------------+----------------------------------------+
|  > Bigger lungs     |   BIGGER LUNGS            Lv 1 -> Lv 2  |
|    Fins             |                                         |
|    Knife            |   Breath duration                       |
|    Weighted belt    |   62s  ->  74s   (+12s)                 |
|    Lantern          |                                         |
|    Pearl basket     |   "Deeper lungs, longer silence."       |
|                     |                                         |
|                     |   COST  400            [ ENTER ] Buy    |
+---------------------+----------------------------------------+
|  [ Esc ] Close        [ Tab ] Inventory                        |
+--------------------------------------------------------------+
```

**Requirements:**

- **Always show the before → after delta numerically.** `62s -> 74s` teaches the player the game's own units and makes upgrades feel concrete. Never show a vague "improves breath capacity".
- Items the player can't afford are shown but dimmed, with the cost in red — visible goals drive the next dive.
- Owned/maxed items show `MAX` and stay in the list.
- Keyboard-first navigation (up/down/enter/esc), mouse supported. Jam players use whatever's under their hand.
- Purchase feedback: coin SFX, money counter rolls down, the item row punches, the stat delta animates to its new value.

---

## 6. Inventory (`I`)

Toggled with `I`. This is where purchased equipment is **equipped, configured, or removed** before a run.

```
+--------------------------------------------------------------+
|  KIT                                    Carry weight  3 / 5  |
+--------------------------------------------------------------+
|   [x] Fins              -- equipped                          |
|   [x] Lantern           -- equipped                          |
|   [ ] Weighted belt     -- sink faster, harder ascent        |
|   [x] Knife             -- equipped                          |
|                                                              |
|   Loadout effect:  Breath 74s   Swim 1.2x   Ascent 0.9x      |
+--------------------------------------------------------------+
|  [ I / Esc ] Close                                           |
+--------------------------------------------------------------+
```

**Requirements:**

- **Live loadout summary** at the bottom, recalculating as items are toggled. This is the single most valuable widget in the screen — it lets the player reason about a build instead of guessing.
- Risk-based items (weighted belt) show their downside in the same weight of text as their upside. No hiding tradeoffs.
- If a carry-slot or weight limit exists, show it in the header and block toggles that exceed it, with a shake + error tick rather than a silent no-op.

**Access rules — decide and stay consistent:**

| State | Behaviour |
|---|---|
| At surface | Full edit. Equip, unequip, configure |
| Mid-dive | **Read-only by default.** Opens, pauses, shows the loadout, but toggles are disabled and greyed |

Read-only mid-dive is the safe jam choice: it avoids the pause-menu exploit of re-speccing to escape a bad situation, while still letting a confused player check what they're wearing. If consumables are added later (an air pocket, a smoke pouch), they'd be the one category usable mid-dive — and they should then get their own always-visible HUD slot rather than living behind a menu, because nobody opens a menu at 4 seconds of breath.

---

## 7. Pause Menu & System Screens (`Esc`)

### 7.1 Behaviour

`Esc` opens the pause menu from anywhere — surface or mid-dive. It halts the world (`GetTree().Paused = true`), which means **it halts the breath countdown**.

```
+--------------------------------------------------------------+
|                                                              |
|                    ONE BREATH DOWN                           |
|                                                              |
|                    >  RESUME                                 |
|                       OPTIONS                                |
|                       ABOUT                                  |
|                       CREDITS                                |
|                       QUIT                                   |
|                                                              |
|                                            [ Esc ] Resume    |
+--------------------------------------------------------------+
```

> You listed *resume, about, credits, exit* and then described options separately — I've assumed **Options is its own top-level entry**, since display and sound settings need a home and burying them inside About would be strange.

**Backdrop:** the game world stays visible behind a dark scrim (~65% black) with an optional blur shader. Don't cut to a black screen — keeping the dive visible behind the menu preserves the sense that the run is still there, waiting.

**Menu stack, not a flat toggle.** `Esc` should close the topmost open screen, not jump straight to pause:

| Current screen | `Esc` does |
|---|---|
| Playing | Open pause menu |
| Pause menu | Resume |
| Options (from pause) | Back to pause menu |
| Credits / About | Back to pause menu |
| Shop / Inventory | Close that screen, return to gameplay |

Implement as an actual `Stack<Control>` in a `MenuManager`. A pile of booleans (`_shopOpen`, `_pauseOpen`, `_optionsOpen`) will produce input bugs by Day 3 — two screens open at once, or `Esc` closing both layers in one frame. Consume the event with `GetViewport().SetInputAsHandled()` after handling it so it doesn't fall through to the next listener.

**Quit** shows a confirmation only if a dive is in progress, and the confirmation must say what's lost: `Quit now and this run's 340 in pearls is gone.` At the surface, quit is immediate — nothing is at stake.

**One design note on pausing:** because pause stops the countdown, it's technically a free escape from the tension — hit `Esc` at 3 seconds of breath and think for as long as you like. For a solo jam game with a personal best-depth stat, this is fine and not worth defending against. Just be aware that if a leaderboard ever gets added, `BEST DEPTH` becomes trivially gameable this way.

### 7.2 Options

Two groups, one screen. Keep it on a single page — no tabs to build.

```
+--------------------------------------------------------------+
|  OPTIONS                                                     |
|                                                              |
|  DISPLAY                                                     |
|    Window mode        <  Fullscreen  >                       |
|    Resolution         <  1920 x 1080 >                       |
|    VSync              <  On          >                       |
|    Screen shake       [#########-----]  70%                  |
|    Flashing effects   [x] Enabled                            |
|                                                              |
|  SOUND                                                       |
|    Master             [############--]  85%                  |
|    Music              [########------]  60%                  |
|    SFX                [###########---]  80%                  |
|                                                              |
|                              [ Esc ] Back                    |
+--------------------------------------------------------------+
```

**Flashing effects toggle is not optional.** This game's low-oxygen feedback is a red screen flashing at ~2 Hz with a tightening vignette — that is squarely in photosensitivity territory, and jam pages get flagged for it. When disabled, the flash pulse becomes a steady colour shift and the vignette stops animating; the information is still conveyed, just without the strobe. Cheap to build, and it's the difference between some players being able to finish your game or not.

**Audio implementation — the standard trap:** audio bus volume in Godot is decibels, and a 0–1 slider is linear. Map it, and floor zero to silence rather than to a very quiet `-80 dB`:

```csharp
private void OnVolumeChanged(float value, string busName)
{
    int bus = AudioServer.GetBusIndex(busName);
    AudioServer.SetBusMute(bus, value < 0.001f);
    AudioServer.SetBusVolumeDb(bus, Mathf.LinearToDb(value));
}
```

Create three buses — `Master`, `Music`, `SFX` — in the audio panel on Day 1. Retrofitting bus routing onto forty already-placed `AudioStreamPlayer` nodes on Day 4 is miserable.

**Persistence:** settings write to `user://settings.cfg` on change (debounced for sliders) and are applied in an autoload's `_Ready()` before the first frame renders. A player who sets windowed mode and reopens the game to fullscreen will assume the option is broken.

### 7.3 About

Short. One screen, no scrolling.

- Title, the one-line pitch from `gdd.md`, GMTK Game Jam 2026, theme: Countdown.
- Two or three sentences on the pearl-diving inspiration and the Gulf heritage framing — this is the game's strongest differentiator and most players will never read a devlog.
- **Controls list.** This is the single most useful thing on the screen. Jam players forget the keybinds within thirty seconds and will hunt for them here before anywhere else. Read the labels from the `InputMap` rather than hardcoding them.

### 7.4 Credits

Two blocks: you, and everything you didn't make.

```
+--------------------------------------------------------------+
|  CREDITS                                                     |
|                                                              |
|  DESIGN, CODE & BUILD                                        |
|    Ahmed Abdelnasser                                         |
|    github.com/...   |   itch.io/...   |   @...               |
|                                                              |
|  ASSETS                                                      |
|    Asset            Author        Source        License      |
|    ------------------------------------------------------    |
|    Ambient loop     A. Composer   freesound     CC BY 4.0    |
|    Bubble SFX       B. Foley      freesound     CC0          |
|    UI font          Foundry       Google Fonts  OFL 1.1      |
|    Water shader     C. Dev        godotshaders  MIT          |
|                                                              |
|    Made with Godot 4 (MIT)                                   |
|                              [ Esc ] Back                    |
+--------------------------------------------------------------+
```

**Build this file from hour one, not on Day 4.** This is the part I'd push hardest on. Most CC BY and OFL licences make attribution a legal condition of use, and the practical failure mode is exactly the one a jam produces: at 2am on the last night you have eleven sound files in `assets/audio/` and no memory of which of five Freesound tabs each came from. Reconstructing that is slow, and getting it wrong can mean a takedown on itch or removal from the jam.

**Workflow that costs ~15 seconds per asset:**

1. Keep `CREDITS.md` in the repo root from the first commit.
2. The moment you download anything, append a row — asset name, author, direct URL, licence, date. Before you even unzip it.
3. Have the credits screen parse that same file at runtime (`FileAccess` on a `res://CREDITS.md`), or generate the screen's text from it with a small script. One source of truth means the in-game credits can't drift out of date.
4. Copy the same table onto the itch.io page. Judges and reviewers frequently never open the in-game credits screen — the page is where attribution actually gets seen.

Record the licence even for CC0 and public-domain assets. You don't legally need to, but it's the record that proves you checked, and it takes the same fifteen seconds.

**Credits must also be reachable from the main menu**, not only from pause. A player who bounces off the game after one dive still sees the attribution.

---

## 8. HUD State Machine

```
        +-----------+   dive input    +-----------+
        |  SURFACE  |---------------->|  DIVING   |
        +-----------+                 +-----------+
             ^                         |    |    |
             |  reached surface        |    |    | breath < 25%
             +-------------------------+    |    v
             |                              |  +-----------+
             |  loot lost                   |  | CRITICAL  |
             +------------------------------+  +-----------+
                        breath = 0 / killed        |
                                                   | breath = 0
                                                   v
                                             +-----------+
                                             | DROWNED   |
                                             +-----------+
```

| State | Visible | Hidden |
|---|---|---|
| `SURFACE` | Breath bar (refilling), money, prompts | Loot table, depth readout, ruler |
| `DIVING` | All dive widgets | Prompts |
| `CRITICAL` | All dive widgets + intensified overlays, pulsing | Prompts |
| `DROWNED` | Loot table (draining to zero), then fade to summary | Everything else |

A single `HudState` enum drives visibility. Widgets subscribe to the state change and run their own fade tweens — no central function that reaches into every node to set `Visible`.

**Pause is not a `HudState`.** It's orthogonal — the player can pause from `SURFACE`, `DIVING`, or `CRITICAL`, and resuming must restore whatever state was active. Keep it out of this enum entirely; the `MenuManager` owns pause, the HUD is unaware of it beyond dimming behind the scrim. Folding `PAUSED` into `HudState` means storing a "previous state" field and hand-restoring it, which is where resume-into-the-wrong-HUD bugs come from.

---

## 9. Godot Implementation Notes

### 9.1 Scene structure

```
Main
├── World (Node2D)
│   ├── Diver
│   ├── BreathSystem          (child of Diver or standalone)
│   └── Hazards / Pearls
├── OverlayLayer (CanvasLayer, layer = 5)
│   └── VignetteRect (ColorRect + shader)
├── HudLayer (CanvasLayer, layer = 10)
│   └── Hud (Control, anchors full rect)
│       ├── BreathPanel       (top-left anchor)
│       ├── LootTable         (top-right anchor)
│       ├── DepthPanel        (bottom-right anchor)
│       ├── DepthRuler        (left anchor, full height)
│       └── PromptBar         (bottom-centre anchor)
└── MenuLayer (CanvasLayer, layer = 20, process_mode = ALWAYS)
    ├── MenuManager        (owns the Stack<Control>, handles Esc)
    ├── Scrim              (ColorRect, dim + optional blur shader)
    ├── ShopScreen
    ├── InventoryScreen
    ├── PauseMenu
    ├── OptionsScreen
    ├── AboutScreen
    └── CreditsScreen
```

Separate `CanvasLayer`s matter: overlays must draw under the HUD, menus must draw over it and keep processing while the tree is paused.

### 9.2 Data flow

Two different mechanisms, chosen by data shape:

**Continuous values → poll in `_Process`.** Breath and depth change every frame. Emitting a signal 60×/sec allocates and marshals for nothing.

```csharp
public override void _Process(double delta)
{
    _breathBar.Value  = _breath.Ratio;
    _breathLabel.Text = FormatBreath(_breath.Seconds);
    _depthLabel.Text  = $"{_depth.Metres:0} m";
    _ruler.SetDepth(_depth.Metres);
}
```

**Discrete events → C# events.** Pickups, zone changes, state transitions, purchases.

```csharp
public static class GameEvents
{
    public static event Action<PearlType, int> PearlCollected;
    public static event Action<int>            RunBanked;
    public static event Action<ZoneId>         ZoneChanged;
    public static event Action<HudState>       HudStateChanged;
    public static event Action<float>          NewBestDepth;
}
```

> **Unsubscribe in `_ExitTree()`.** A static event holding a reference to a freed `Node` is the classic Godot/C# crash: `ObjectDisposedException` on the next invoke. This will bite during a jam when you're reloading the run scene dozens of times.

### 9.3 Persistent state

`GameState` autoload owns everything that survives a run: `Money`, `BestDepth`, `OwnedUpgrades`, `EquippedLoadout`. Serialise with `ConfigFile` to `user://save.cfg` — simpler than JSON for flat key/value data and it handles Godot types natively. Save on surface, on purchase, and on quit.

### 9.4 Practical details

- Build a single `Theme` resource early (fonts, colours, panel styleboxes). Retheming six screens by hand on Day 3 is a guaranteed time sink.
- Use `Tween` for every number roll-up, punch, and fade. Never hand-roll lerps in `_Process` for UI.
- All fonts need tabular figures for numeric fields, or use a monospace font for numbers specifically.
- Test at 1280×720 windowed. Jam judges rarely play fullscreen, and anchored corner panels can collide at small sizes.
- Keep every string in a single `UiStrings` static class. If an Arabic localisation pass becomes viable later, it's a one-file change plus RTL anchor mirroring.

---

## 10. Open Questions

- [ ] Does `BEST DEPTH` record deepest *reached* or deepest *survived*?
- [ ] Is the run summary a modal screen after death, or does the HUD just drain the loot table in place and let the player dive again immediately? (In-place is faster to build and keeps the loop tight.)
- [ ] Does the depth ruler show a "point of no return" marker — never, always, or as a purchasable upgrade?
- [ ] Is the shop a modal overlay on the boat deck, or a separate scene?
- [ ] Can the inventory be opened mid-dive at all, or is `I` simply ignored while submerged?
- [ ] Does the loot table show per-type value, or only the run total? (Per-type is more informative, but four rows of numbers in a corner may be noise during a panicked ascent.)
- [ ] Weight/carry-strain indicator: separate widget, or folded into the loot table panel?
- [ ] Is there a main menu on launch, or does the game boot straight onto the boat deck? (Booting straight in is faster to play and faster to build, but then pause is the *only* route to credits and options — which makes those screens easy for a judge to miss entirely.)
- [ ] Does `Quit` from a mid-dive pause count as a failed run (lose the pearls) or does it just close the game with the run discarded either way?
- [ ] Are the controls listed in About, or on their own panel reachable from pause?

---

## 11. Build Order & Cut List

**Day 1 — functional, ugly:** breath bar, breath timer, current depth. Plain `Label`s and a default `ProgressBar`. The core loop must be *readable* before anything is *pretty*.

**Day 1 — also:** create the three audio buses, and start `CREDITS.md` with the first commit. Both cost minutes now and hours later.

**Day 2:** loot table with counts, money counter, surface prompts, auto-sell sequence. Stub the pause menu — `MenuManager` with the stack, `Esc` binding, and a Resume/Quit menu with no styling. Getting the input plumbing right early prevents the Day 4 scramble where `Esc` closes two screens at once.

**Day 3:** depth ruler with ticks and zone labels, best-depth tracking, shop and inventory screens. Fill in the rest of the pause menu: options (audio sliders + window mode + flashing toggle), about, credits.

**Day 4:** juice — punches, roll-ups, vignette response, colour states, audio hookup, theme pass. Final pass on `CREDITS.md`, and mirror it onto the itch.io page.

**Cut in this order if time runs short:**

1. Point-of-no-return marker (already optional)
2. Blur shader behind the pause menu → flat dark scrim
3. Resolution and VSync options → fullscreen toggle only
4. About screen → fold the controls list into the pause menu itself
5. Best-depth ghost marker on the ruler
6. Per-type values in the loot table → run total only
7. Loot fly-to-counter animation → instant tally with one sound
8. Zone-name fade-in flourish → static ruler labels only
9. Inventory screen → upgrades apply automatically on purchase, no equip step
10. Depth ruler entirely → depth readout alone still communicates depth

**Never cut:** breath bar, breath timer, current depth, loot count. Those four are the game.