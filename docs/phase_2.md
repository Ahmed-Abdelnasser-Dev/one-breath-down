# Phase 2 — Content Spine

**Goal:** turn one loop into a *game with a shape*. Depth becomes a real unit, pearls become a value curve, water becomes zones, and carry weight starts to hurt. Still greybox — coloured rectangles, no art, no hazards, no shop.

**Engine reality check:** this project is Godot 4.7.1 + **GDScript**, Compatibility renderer. `gdd.md` and `hud_ui.md` still say C# from the original concept pass — the C# snippets in `hud_ui.md` are pseudocode for you, translate as you go. Everything below is GDScript.

---

## 1. Exit criteria

Phase 2 is done when:

1. The HUD shows **depth in metres**, not pixels, and the number is the same unit the design docs talk in.
2. Four pearl types exist as `.tres` files with different values, weights, and depth bands — and adding a fifth is a file, not a code change.
3. Each run **generates its own pearl field** procedurally, so two dives aren't the same dive.
4. The water visibly changes through **Sunlit → Twilight → Midnight**, and the zone name announces itself on crossing.
5. Deeper water actively costs more breath (zone multiplier), so depth is expensive even when you're gliding.
6. Carrying too much **measurably slows you down and burns more air**, and the HUD makes that legible.
7. The loot table shows **what you're carrying, by type, with a running run-value** — the greed meter.
8. `BEST DEPTH` persists across sessions in `user://save.cfg`.
9. **The playtest question:** do you ever *voluntarily turn back* with pearls still in the water below you? If you always dive to the seabed and always make it, the numbers aren't biting yet and §7 is where you spend your time.

Criteria 1–7 are the phase. 8 is cheap insurance. 9 is the only one that actually matters.

---

## 2. What this phase adds to the spine

Nothing architectural gets rebuilt. Phase 1 gave you `Events`, `GameState`, `RunManager`, `Diver`, `BreathComponent`, `Pearl`, `HUD`. Phase 2 adds three new systems that plug into the same bus:

```
DepthTracker  (inside RunManager)  -> converts Y to metres, emits depth/zone events
DiveSpawner   (World child)        -> builds the pearl column on reset_run()
ZoneManager   (World child)        -> owns ZoneData, tints water, feeds drain multiplier
```

### Scene tree (target)

```
Game (Node2D)                  -> RunManager.gd   (+ depth tracking)
├── World (Node2D)
│   ├── WaterBackground (ColorRect, huge, z_index -10)   <- lerps zone colour
│   ├── SurfaceLine (Marker2D)
│   ├── Seabed (StaticBody2D)        <- hard floor at MAX_DEPTH_M
│   ├── WallLeft / WallRight (StaticBody2D)
│   ├── ZoneManager (Node)     -> ZoneManager.gd
│   ├── DiveSpawner (Node2D)   -> DiveSpawner.gd
│   └── Pearls (Node2D)              <- spawner parents pearls here
├── Diver (CharacterBody2D)
│   ├── CollisionShape2D
│   ├── Camera2D                     <- add limit_bottom / limit_left / limit_right
│   └── BreathComponent (Node)
├── DarkOverlay (CanvasLayer, layer 5)
│   └── ColorRect                    <- zone darkness, cheap, pre-vignette
└── HUD (CanvasLayer, layer 10)
```

### New signals on `Events`

```gdscript
signal depth_changed(metres: int)          # only on whole-metre change, not per frame
signal zone_changed(zone: ZoneData)
signal new_best_depth(metres: int)
signal carry_weight_changed(current: float, capacity: float)
```

`depth_changed` firing only when the integer metre value changes is deliberate. `hud_ui.md` argues for polling continuous values instead of signalling at 60 Hz — that's correct in spirit, but the HUD only ever *displays* whole metres, so quantising at the source gives you the bus architecture with maybe 5–10 emits per second. Don't emit a float.

---

## 3. Files to create

| Path | Type | Responsibility |
|---|---|---|
| `scripts/resources/ZoneData.gd` | `Resource` class | Zone definition (name, start depth, colour, darkness, drain multiplier) |
| `data/zones/sunlit.tres` / `twilight.tres` / `midnight.tres` | ZoneData | The three zones |
| `data/pearls/seed_pearl.tres` *(extend)* | PearlData | Now carries band, weight, spawn weight, colour |
| `data/pearls/rose_pearl.tres` | PearlData | — |
| `data/pearls/black_pearl.tres` | PearlData | — |
| `data/pearls/golden_pearl.tres` | PearlData | — |
| `scripts/world/DiveSpawner.gd` | Node2D | Builds the pearl column each run from a seeded RNG |
| `scripts/world/ZoneManager.gd` | Node | Resolves depth → zone, tints water, publishes drain multiplier |
| `scenes/ui/LootTable.tscn` + `scripts/ui/LootTable.gd` | Control | Per-type rows + run value footer |
| `scenes/ui/DepthPanel.tscn` + `scripts/ui/DepthPanel.gd` | Control | DEPTH / BEST readout |
| `scenes/ui/ZoneBanner.tscn` + `scripts/ui/ZoneBanner.gd` | Control | Fades the zone name in on crossing |
| `scripts/ui/DebugOverlay.gd` | Control | Tuning numbers, toggled with a key (see §8) |

**Modified:** `PearlData.gd`, `GameState.gd`, `BreathComponent.gd`, `Diver.gd`, `RunManager.gd`, `HUD.gd`, `Events.gd`.

---

## 4. Build order

Same rule as Phase 1 — each step ends runnable, don't move on until the verify line is true.

---

**Step 1 — Depth becomes metres.**

Pick `PIXELS_PER_METRE` so your existing `max_speed` lands somewhere in the **4–7 m/s** range (see §7 for why). Add depth tracking to `RunManager`: compute metres from the surface line every physics frame, emit `Events.depth_changed` only when the rounded integer changes. Add the `DepthPanel` to the HUD showing `DEPTH   ## m`.

*Verify:* swimming down increments a clean whole-metre readout starting at 0 at the surface. No pixel values appear anywhere in the UI.

---

**Step 2 — Pearl types as data.**

Extend `PearlData` with the fields in §5, then author four `.tres` files with the draft numbers from §7. Make `Pearl.tscn` read its own `PearlData` in `_ready()` and set its placeholder colour and radius from the resource, so all four types share one scene.

*Verify:* drop one of each type into the world by hand, dive, and the loot value that banks matches the sum of the four resource values.

---

**Step 3 — Procedural pearl column.**

Build `DiveSpawner`. On `reset_run()`, clear `Pearls` and regenerate: walk down the column in 10 m bands, roll a pearl count from the density curve, and for each pearl weighted-pick among the types whose depth band covers that depth. Random X within the play width, with a minimum separation so they don't stack. Use an explicit `RandomNumberGenerator` with a stored seed.

*Verify:* every run has a different field; deep water is visibly sparser than shallow; setting the seed to a fixed number reproduces an identical field exactly.

---

**Step 4 — Zones.**

Write `ZoneData` and author the three zones. `ZoneManager` holds them sorted by `start_depth_m`, resolves the current zone from `depth_changed`, emits `Events.zone_changed` on transition, and every frame lerps `WaterBackground.color` and `DarkOverlay` alpha toward the zone's values. Publish `current_drain_multiplier` for the breath component to read.

Add `ZoneBanner`: on `zone_changed`, fade the zone name in large and semi-transparent for ~1.5 s, then out.

*Verify:* descending fades the water continuously darker rather than snapping at boundaries, the banner fires once per crossing (both directions), and breath drains noticeably faster in Midnight than Sunlit while gliding at the same speed.

---

**Step 5 — Carry weight bites.**

`GameState.weight_capacity` (default in §7, becomes an upgrade in Phase 4). Diver applies a speed multiplier from overweight; `BreathComponent` folds an overweight term into its drain multiplier. Emit `carry_weight_changed` on every collect and on `clear_carry`.

*Verify:* eight seed pearls make the ascent feel meaningfully heavier than two, and you can state the difference in seconds, not vibes.

---

**Step 6 — Loot table.**

Build `LootTable` per `hud_ui.md` §3.4: lazily-created rows (one per type, only after the first of that type is collected), sorted by value ascending, footer with the running run value. Subscribe to `pearl_collected`, clear on `run_started`. Add the strain indicator — a small bar or an amber border once `carried_weight > capacity`. Skip the fly-to-counter animation and roll-ups for now; that's Phase 5.

*Verify:* a mixed run shows correct counts and total, the panel clears on the next dive, and the strain state appears at exactly the weight where speed starts dropping.

---

**Step 7 — Best depth + save file.**

Add `best_depth_m` to `GameState`, updated from `depth_changed`, emitting `new_best_depth` when it's beaten. **Record deepest *reached*, not deepest *survived*** — this answers the first open question in `hud_ui.md` §10. A fatal dive that set a record still gave you something, which is the right feeling for an arcade loop and takes zero extra code.

Serialise `money` and `best_depth_m` with `ConfigFile` to `user://save.cfg`. Save on surface, on death, and on quit. Load in `GameState._ready()`.

*Verify:* set a record, close the game, reopen — `BEST` is still there. On Fedora that file lives at `~/.local/share/godot/app_userdata/One Breath Down/save.cfg`; `cat` it to confirm rather than trusting the UI.

---

**Step 8 — Tuning pass.**

Build the debug overlay (§8), then spend real time playing. This is not a small step — it is the point of the phase. See §7 for what you're tuning toward.

*Verify:* exit criterion 9 is true.

---

**Step 9 (stretch) — Depth ruler.**

The left-edge ruler from `hud_ui.md` §3.6. Draw it procedurally in `_draw()` from the current depth — minor tick every 5 m, major + label every 25 m, heavy line and label at zone boundaries, dim gold line at best depth. **Do not instantiate a node per tick.**

Genuinely optional. It's the single biggest "this feels like a real game" upgrade in the HUD, but it's also pure presentation and Phase 3 hazards are worth more. Only take it if Steps 1–8 land early.

---

## 5. Resource shapes

**`PearlData.gd` (extend the Phase 0 version):**

```gdscript
class_name PearlData
extends Resource

@export var id: StringName            # "black"
@export var display_name: String      # "Black pearl"
@export var value: int
@export var carry_weight: float

@export_group("Spawning")
@export var min_depth_m: int
@export var max_depth_m: int
@export var spawn_weight: float       # relative pick chance inside its band

@export_group("Placeholder visuals")   # replaced by a texture in Phase 5
@export var color: Color
@export var radius: float = 8.0
```

**`ZoneData.gd`:**

```gdscript
class_name ZoneData
extends Resource

@export var id: StringName
@export var display_name: String       # "TWILIGHT"
@export var start_depth_m: int
@export var water_color: Color
@export var darkness: float            # 0..1 alpha on DarkOverlay
@export var drain_multiplier: float = 1.0
# Phase 3 lands here: @export var hazard_table: Array[HazardSpawnEntry]
```

Note that last comment. `ZoneData` is the seam Phase 3 plugs into — hazards get authored per zone as data, exactly like pearls, so "add a shark to Midnight" stays a `.tres` edit.

---

## 6. Key logic sketches

Structure, not implementations.

**Depth conversion (RunManager):**

```gdscript
const PIXELS_PER_METRE := 32.0

var depth_m: int = 0

func _update_depth() -> void:
    var raw := (diver.global_position.y - surface_line.global_position.y) / PIXELS_PER_METRE
    var m := maxi(0, int(raw))
    if m != depth_m:
        depth_m = m
        Events.depth_changed.emit(m)
        GameState.report_depth(m)
```

Convert **once**, here, at the boundary. Nothing downstream ever sees a pixel coordinate.

**Weighted spawn (DiveSpawner):**

```gdscript
func _spawn_column() -> void:
    for band_top in range(0, MAX_DEPTH_M, BAND_M):
        var count := _density_at(band_top)          # see §7 curve
        for i in count:
            var depth := band_top + rng.randi_range(0, BAND_M - 1)
            var data := _pick_type_for_depth(depth)
            if data == null:
                continue
            _place(data, depth)

func _pick_type_for_depth(depth: int) -> PearlData:
    var pool: Array[PearlData] = []
    var total := 0.0
    for p in pearl_types:
        if depth >= p.min_depth_m and depth <= p.max_depth_m:
            pool.append(p)
            total += p.spawn_weight
    # standard weighted roll over `pool` using `total`
```

Overlapping bands are intentional — the 30–40 m stretch rolling either seed or rose keeps the transition from feeling like a hard tier gate.

**Composed drain multiplier (BreathComponent):**

```gdscript
const MAX_DRAIN_MULT := 2.5

func _current_multiplier() -> float:
    var speed_ratio := diver.velocity.length() / diver.max_speed
    var exertion := 1.0 + speed_ratio * EXERTION_BONUS
    var over := maxf(0.0, diver.carried_weight - GameState.weight_capacity)
    var strain := 1.0 + over * DRAIN_PENALTY_PER_UNIT
    return minf(exertion * strain * zone_multiplier, MAX_DRAIN_MULT)
```

The clamp matters. Three multiplicative terms can quietly stack into a death spiral the player can't read, and "why did I lose 20 seconds in three seconds" is the kind of thing that reads as a bug rather than a consequence.

**Overweight speed penalty (Diver):**

```gdscript
func _speed_multiplier() -> float:
    var over := maxf(0.0, carried_weight - GameState.weight_capacity)
    return 1.0 / (1.0 + over * SPEED_PENALTY_PER_UNIT)
```

Reciprocal rather than subtractive so it asymptotes instead of hitting zero — a hoarder gets slow, never frozen. Being unable to move at all reads as a softlock even when it's technically survivable.

**Zone resolution (ZoneManager):**

```gdscript
func _on_depth_changed(m: int) -> void:
    var z := zones[0]
    for zone in zones:                 # sorted by start_depth_m ascending
        if m >= zone.start_depth_m:
            z = zone
    if z != current_zone:
        current_zone = z
        Events.zone_changed.emit(z)
```

---

## 7. First-pass numbers

These are a starting point sized to be *wrong in a useful direction*, not final. Every one is a tunable export.

**Space and speed**

| Constant | Draft | Reasoning |
|---|---|---|
| `PIXELS_PER_METRE` | 32 | Makes a 200 m column 6400 px — trivial for Godot |
| Diver `max_speed` | ~160 px/s | = 5 m/s. Wildly unrealistic for a freediver, correct for an arcade game |
| `MAX_DEPTH_M` (seabed) | 200 | Bounded, not endless — you cannot tune an infinite column in 96 hours |
| Play width | ~1600 px | Wide enough to dodge, narrow enough that pearls are findable |

**Reachability check.** Base breath 60 s, base drain 1.0/s, exertion up to 1.5× at full speed. Sprinting flat out the whole dive burns 60 s of breath in 40 s of travel = 200 m of travel = **~100 m depth round trip, with zero margin and zero cargo**. Add zone multipliers and carry weight and realistic play sits around **70–85 m** on base kit.

That is a deliberate design outcome, not an accident: Midnight starts at 150 m, so **the deep zone and the golden pearl are unreachable without Phase 4 upgrades.** The shop then has an obvious, visible thing to sell — the player has *seen* the Twilight floor and knows there's more below it. Preserve this property when you tune.

**Pearl curve**

| Type | Band (m) | Value | Weight | Spawn weight |
|---|---|---|---|---|
| Seed | 0–40 | 10 | 0.2 | 100 |
| Rose | 30–90 | 35 | 0.5 | 55 |
| Black | 80–160 | 110 | 0.9 | 25 |
| Golden | 150–200 | 350 | 1.4 | 6 |

Value climbs faster than depth does. Seed → golden is 35× the value for 5× the depth, and that superlinearity is what makes greed the *rational* choice rather than a trap — the game should reward going deeper, then charge you for it in breath and weight. A linear curve makes shallow farming optimal and kills the whole tension.

**Density curve** — pearls per 10 m band, roughly linear from `2.5` at the surface to `0.8` at 200 m. Deep water should feel empty and committing; you swim past nothing for a while, then find one very good thing.

**Weight**

| Constant | Draft | Meaning |
|---|---|---|
| `weight_capacity` | 3.0 | ≈ 15 seed, 6 rose, or 3 black before penalties |
| `SPEED_PENALTY_PER_UNIT` | 0.18 | 2.0 over capacity → ~73% speed |
| `DRAIN_PENALTY_PER_UNIT` | 0.15 | 2.0 over capacity → 1.3× drain |

**Zone drain multipliers**

| Zone | Depth | Water | Darkness | Drain × |
|---|---|---|---|---|
| Sunlit | 0–50 | Bright blue-green | 0.0 | 1.0 |
| Twilight | 50–150 | Desaturated teal | 0.35 | 1.15 |
| Midnight | 150+ | Near-black indigo | 0.75 | 1.35 |

**What you're tuning toward:** a dive where you decide to turn back roughly **60–70% of the time**, and drown on the greedy ones often enough that surfacing feels earned. If you never drown, deepen the penalties. If you drown constantly, the drain multipliers are stacking too hard — check the clamp before touching the base rate.

---

## 8. Debug overlay

Build this before the tuning pass, not after. Toggle with a key bound to a `debug_toggle` action; strip nothing at export, just leave it off.

Display: current depth, live drain multiplier and its three component terms separately, carried weight vs capacity, current speed multiplier, RNG seed, and — the important one — the **point of no return**:

```gdscript
# metres you could still ascend on remaining breath, at current weight
var ascent_mps := diver.max_speed * diver._speed_multiplier() / PIXELS_PER_METRE
var burn := breath.base_drain * breath._current_multiplier()
var reachable_m := (breath.current_breath / burn) * ascent_mps
```

`hud_ui.md` §3.6 flags this as a mechanic that could drain the tension if shipped by default, and that judgement stands — **keep it debug-only in Phase 2.** But you cannot balance the value curve by feel alone in four days. Seeing "you had 40 m of ascent left and turned back at 55 m depth" tells you instantly whether your penalties are too soft. Ship it later as a purchasable upgrade if Phase 4 has room; that's the version where it's a reward rather than a solved puzzle.

---

## 9. Editor checklist

- **Seabed + walls:** `StaticBody2D` on the `wall` layer, matching the diver's existing mask. Without a floor, the diver swims into empty space below the deepest pearl and the camera follows into void.
- **Camera2D limits:** set `limit_bottom` to the seabed Y and `limit_left`/`limit_right` to the play width, or the world edges show as grey.
- **WaterBackground:** a `ColorRect` large enough to cover the whole column with margin, `z_index = -10`, on the World node — not on a CanvasLayer, so it scrolls with the camera and the zone lerp reads as *the water* changing rather than a filter.
- **DarkOverlay:** `CanvasLayer` at layer **5**, below the HUD's 10, per `hud_ui.md` §3.7. Overlays must never wash out the numbers.
- **Spawner reference:** `@export var pearl_types: Array[PearlData]` filled in the inspector. Do **not** `load()` paths in code — the inspector array is the whole point of the data-driven setup and lets you disable a type by unchecking it.
- **Zone array:** same pattern, `@export var zones: Array[ZoneData]`, sorted ascending by start depth. Assert the sort in `_ready()`; a mis-ordered array produces a zone system that silently never leaves Sunlit.
- **Pearl scene:** one `Pearl.tscn` for all types, coloured from its resource. Four scenes is four places to fix a bug.
- **Audio buses:** if you haven't yet, create `Master` / `Music` / `SFX` now (`hud_ui.md` §7.2). It costs two minutes here and hours on Day 4.

---

## 10. Scope notes

**Deferred out of Phase 2 (don't build these):**

- Hazards of any kind → Phase 3. The `hazard_table` slot on `ZoneData` is where they land.
- Shop, upgrades, inventory → Phase 4. `weight_capacity` and `max_breath` living on `GameState` is the entire hook needed; upgrades just write those numbers.
- Vignette shaders, bubble particles, heartbeat SFX, roll-up tweens, sprites → Phase 5. The flat `DarkOverlay` is the placeholder for the vignette and is enough to prove the zone read.
- Run summary screen, pause menu, options → Phase 4/5 per `hud_ui.md` §11.

**Cut order if you fall behind:**

1. Depth ruler (Step 9, already optional)
2. Zone banner flourish → the water colour change alone communicates the zone
3. Golden pearl → three types is a curve; the fourth is flavour
4. Per-type loot rows → a single `RUN VALUE` number still shows what's at stake
5. Procedural spawner → hand-place ~20 pearls down the column once and reuse them every run

**Never cut:** depth in metres, the value/weight curve, the zone drain multiplier. Those three *are* the risk maths. Without them Phase 1's loop is a toy where diving deeper costs nothing and every run plays identically.

**Open questions this phase closes:** `gdd.md` §6 items 1 and 2 (depletion curve, value curve) get their first real answers here. `hud_ui.md` §10 item 1 (`BEST` = deepest reached) is answered in Step 7. The point-of-no-return question is answered as *debug-only for now, upgrade later if there's room*.