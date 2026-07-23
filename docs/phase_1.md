# Phase 1 — Core Loop (Greybox)

**Goal:** the full dive → collect → decide → ascend → bank/lose loop, playable end-to-end with rectangles. No content variety, no shop, no art. Everything from here is "add more of the same."

---

## 1. Exit criteria

Phase 1 is done when, using only placeholder shapes, you can:

1. Start at the surface and swim down.
2. Watch breath start draining the moment you cross below the surface line.
3. Touch a placeholder pearl and see your **carried** count go up.
4. Swim back above the surface line → pearls **bank** (GameState total rises) → run resets.
5. **OR** let breath hit zero while submerged → you drown, carried pearls are **lost**, run resets.
6. Immediately dive again.

If both the success path and the drown path close cleanly and loop, the core game exists. Everything after is content and polish.

---

## 2. Architecture overview

This phase exercises the entire Phase 0 spine — `Events` (signal bus) and `GameState` (persistent wallet). Nothing new gets bolted onto those; you just start emitting through them.

### Scene tree (target)

```
Game (Node2D)              -> RunManager.gd  (owns the state machine)
├── World (Node2D)
│   ├── Background (ColorRect, greybox)
│   ├── SurfaceLine (Marker2D)    <- the Y threshold for submerge/surface
│   └── Pearls (Node2D)           <- placeholder pearls parented here
├── Diver (CharacterBody2D)  -> Diver.gd
│   ├── CollisionShape2D
│   ├── Camera2D
│   └── BreathComponent (Node) -> BreathComponent.gd
└── HUD (CanvasLayer)         -> HUD.gd
```

`Game.tscn` becomes the main scene for now (the Phase 0 `Main.tscn` was just a smoke test — you can leave it or delete it).

### State machine (lives in RunManager)

```gdscript
enum RunState { AT_SURFACE, SUBMERGED, RUN_OVER }
```

| From | Trigger | To | Side effects |
|---|---|---|---|
| AT_SURFACE | Diver crosses **below** SurfaceLine | SUBMERGED | `BreathComponent.set_draining(true)`, `Events.run_started.emit()` |
| SUBMERGED | Diver crosses **above** SurfaceLine | RUN_OVER (success) | bank via `GameState.add_pearls(...)`, `Events.player_surfaced.emit(value)` |
| SUBMERGED | `Events.breath_depleted` | RUN_OVER (drowned) | clear carried (lost), `Events.player_died.emit("drowned")` |
| RUN_OVER | short timer | AT_SURFACE | `reset_run()` — reposition diver, refill breath, clear carry |

Crossing detection is just a Y comparison each frame: `diver.global_position.y > SurfaceLine.global_position.y` means submerged (Y grows downward). No Area2D needed for the surface — a threshold is simpler and can't be missed at high speed.

### Signal flow

```
Pearl (body_entered) ──► Diver.collect(data) ──► Events.pearl_collected(data)
BreathComponent ─────────────────────────────► Events.breath_changed(cur, max)
BreathComponent (hits 0) ────────────────────► Events.breath_depleted
RunManager (bank) ──► GameState.add_pearls() ─► Events.pearls_banked(amount)

HUD listens to: breath_changed, pearl_collected, pearls_banked, run_started, player_died, player_surfaced
RunManager listens to: breath_depleted
```

Because everything routes through `Events`, no system needs a direct reference to another. The HUD never touches the diver; the breath component never touches the HUD.

---

## 3. Files to create

| Path | Node type | Responsibility |
|---|---|---|
| `scenes/player/Diver.tscn` + `scripts/player/Diver.gd` | CharacterBody2D | Swim movement, carry tally (count/value/weight), `collect()` |
| `scripts/components/BreathComponent.gd` | Node | Owns breath, drains while diving, emits breath signals |
| `scenes/pearls/Pearl.tscn` + `scripts/pearls/Pearl.gd` | Area2D | Detects diver, emits pearl_collected, frees self. Exports a `PearlData` |
| `data/pearls/seed_pearl.tres` | PearlData resource | One placeholder pearl definition (exercises the data path) |
| `scenes/main/Game.tscn` + `scripts/main/RunManager.gd` | Node2D | State machine, surface detection, banking, reset |
| `scenes/ui/HUD.tscn` + `scripts/ui/HUD.gd` | CanvasLayer | Breath bar + carried/banked labels |

---

## 4. Build order

Each step leaves you with something runnable. Don't move on until the "verify" line is true.

**Step 1 — Diver moves.**
Build `Diver.tscn` with a CharacterBody2D, a CollisionShape2D (a rectangle is fine), and a child Camera2D. Implement swim movement (model in §6).
*Verify:* you can fly the rectangle around empty space and it feels aquatic (glides, doesn't stop dead). Camera follows.

**Step 2 — Breath drains.**
Add `BreathComponent` as a child Node of the diver. It holds `max_breath`, `current_breath`, drains in `_physics_process` when `draining == true`, reads the diver's velocity for exertion, and emits `Events.breath_changed`. For now toggle `draining` manually or with a temp key.
*Verify:* `print` or a temp label shows breath falling faster when you swim hard, slower when you glide.

**Step 3 — Surface line + state machine.**
Add `SurfaceLine` (Marker2D) and `RunManager.gd`. Wire the AT_SURFACE ↔ SUBMERGED crossing to `set_draining()` and `Events.run_started`. Wire `breath_depleted` → RUN_OVER(drowned) → `reset_run()`.
*Verify:* dive below the line → breath starts; let it hit zero → run resets, breath refills, you're back at the surface.

**Step 4 — Pearls + banking.**
Build `Pearl.tscn` (Area2D on the `pearl` layer, masking `player`). On `body_entered`, if the body is the diver, call `diver.collect(pearl_data)`, emit `Events.pearl_collected`, `queue_free()`. Diver accumulates `carried_value`. RunManager banks it on the surface crossing via `GameState.add_pearls`.
*Verify:* grab a pearl, swim up → banked total rises. Grab a pearl, drown → banked total unchanged (pearl lost).

**Step 5 — HUD.**
Build `HUD.tscn`: a ProgressBar (breath) + two Labels (carried / banked). Connect to `Events` in `_ready`. Update the bar from `breath_changed`, carried from `pearl_collected` (reset on `run_started`), banked from `pearls_banked`.
*Verify:* all three read correctly through a full success run and a full drown run.

**Step 6 — Greybox a real mini-run.**
Scatter 4–6 placeholder pearls down the vertical space at increasing depth. Make the playfield tall enough that reaching the deepest pearl and getting back is a genuine breath gamble.
*Verify:* there's an actual decision — "do I grab the deep one or turn back now?"

**Step 7 (optional) — Carry-weight hook.**
Give the diver a `carried_weight` that grows per pearl and feeds the exertion multiplier (and optionally a small max-speed penalty). Keep the numbers tiny and tunable — full per-type weights are Phase 2. This is what makes Step 6's decision bite. Fine to defer if the loop already feels tense.

---

## 5. Editor checklist

- **Collision layers** (using the Phase 0 named layers):
  - Diver `CharacterBody2D`: layer = `player`, mask = `wall` (add `hazard` in Phase 3).
  - Pearl `Area2D`: layer = `pearl`, mask = `player`, **Monitoring on**.
- **Diver.collect** fires from the pearl's `body_entered(body)` — confirm the diver is on the `player` layer so the pearl sees it.
- **Main scene:** set to `Game.tscn` (Project → Project Settings → Application → Run).
- **BreathComponent** is a plain `Node` child of the diver so it can read the diver's velocity directly via `get_parent()` (or an exported `@export var diver: CharacterBody2D`).
- **HUD** on a `CanvasLayer` so it ignores the camera.
- **ProgressBar:** set `max_value` from `breath_changed`'s `maximum` arg rather than hardcoding, so upgrades in Phase 4 just work.

---

## 6. Key logic sketches

These are structure, not implementations — bodies are yours to write.

**Swim movement (Diver `_physics_process`):**
```gdscript
var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
var target := input_dir * max_speed
var rate := accel if input_dir != Vector2.ZERO else drag   # drag < accel = gliding
velocity = velocity.move_toward(target, rate * delta)
move_and_slide()
```
Tune for feel: fairly high `max_speed`, medium `accel`, low `drag` so momentum carries. Skip buoyancy in Phase 1 (it belongs with the weighted-belt upgrade later).

**Breath drain (BreathComponent, while draining):**
```gdscript
var speed_ratio := diver.velocity.length() / diver.max_speed
var exertion := 1.0 + speed_ratio * EXERTION_BONUS      # e.g. BONUS 0.5 -> up to 1.5x
# Phase 1 optional: exertion += diver.carried_weight * WEIGHT_FACTOR
current_breath -= base_drain * exertion * delta
Events.breath_changed.emit(current_breath, max_breath)
if current_breath <= 0.0:
    set_draining(false)
    Events.breath_depleted.emit()
```

**Diver carry state:**
```gdscript
var carried_count: int = 0
var carried_value: int = 0
var carried_weight: float = 0.0

func collect(data: PearlData) -> void:
    carried_count += 1
    carried_value += data.value
    carried_weight += data.carry_weight
    Events.pearl_collected.emit(data)

func clear_carry() -> void:
    carried_count = 0; carried_value = 0; carried_weight = 0.0
```

**Banking (RunManager, on surface crossing while SUBMERGED):**
```gdscript
GameState.add_pearls(diver.carried_value)   # add_pearls already emits pearls_banked
Events.player_surfaced.emit(diver.carried_value)
diver.clear_carry()
```

---

## 7. Scope notes

**Deferred out of Phase 1 (don't build these yet):**
- Multiple pearl types / real value curve → Phase 2 (`.tres` files, that's it).
- Depth zones (color/behavior shifts) → Phase 2.
- Hazards → Phase 3.
- Shop/upgrades → Phase 4 (this is why `reset_run()` exists instead of reloading the scene — Phase 4 slots the shop in between RUN_OVER and AT_SURFACE).
- Any art/audio/juice → Phase 5.

**If you fall behind:** the loop must survive first. In order, cut Step 7 (carry weight), then Step 6 pearl variety (one pearl is enough to prove banking), then HUD polish (a temp label works). Do **not** cut the state machine or surface detection — that *is* the game.
