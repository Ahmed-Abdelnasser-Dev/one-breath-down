# One Breath Down — Full Game Audit & Fix Plan

*Audit date: 2026-07-26. Produced by playing the game end-to-end (menus, ship hub, dives to 197m,
combat, three deaths, shop/inventory/pause), reading the runtime error log, and cross-referencing
every finding against the code, the scenes, `docs/gdd.md`, and `docs/visual-bible.md`.*

The one-sentence diagnosis: **most of the systems that would make the game feel "complete and
whole" are already written — they are just disconnected, invisible, or unbalanced.** The plan
below is mostly re-wiring and tuning, not new construction.

---

## A. What's already good (do not touch, or use as the standard)

- Pixel-art technical foundation is correct: 480×270 viewport, integer scaling, nearest filter,
  pixel snap, MSDF Pixellari font (`project.godot`).
- `docs/visual-bible.md` is a genuinely strong style guide (palette, posterization rule,
  vertical-repetition rule). The fix work below should be checked against it.
- The background layer stack (`scenes/background/background.tscn`: Sky→Clouds→FarBand→
  DeepFormations→Reef bands→SunkenShip/RockArches) reads well in the sunlit zone.
- Diver animator polish: turn squash, quantized pitch, integer idle bob
  (`scripts/player/diver_animator.gd`).
- Menu stack architecture (`scripts/menus/menu_manager.gd`), zone banner tween, game-over darken,
  enemy hit-flash, jellyfish aura telegraph (`scripts/enemies/aura_visual.gd`).
- Data-driven pearls/zones/enemies (`data/**/*.tres`).

---

## B. Findings

### B1. Broken wiring (P0 — the game is objectively malfunctioning)

1. **CaveWallGenerator is dead on arrival.** `scenes/Game.tscn:58` has it as a bare `Node2D`
   with zero children, but `scripts/world/cave_wall_generator.gd:26-42` expects 13 pre-built
   children (`LeftWallBody`, `RightWallPoly`, `SeabedBody`, `FloraContainer`, …). Every launch
   logs 13 "Node not found" errors and **no cave walls, no seabed, no collision, no flora ever
   generate**. This single break removes most of the intended world.
2. **Owned "Diver's Lantern" does nothing.** The shop sells it ("provides bright illumination…"),
   the test save owns it, and at 197m the screen is still 100% black. There is no light system
   anywhere (no `PointLight2D`/`CanvasModulate`; `DarkOverlay` is a plain ColorRect driven only
   by zone in `scripts/world/ZoneManager.gd:75-77`).
3. **"Woven Pearl Basket" does nothing.** `GameState.weight_capacity` (GameState.gd:11) is never
   written by any code path.
4. **Fins' shop copy lies.** Says "reduces exertion oxygen drain" (`shop_screen.gd:24`) but only
   `base_max_speed` changes (`diver.gd:61-70`); `exertion_bonus` is untouched.
5. **Shop/inventory can be unopenable at the ship.** After a reset the diver spawns on the boat
   but `ShipHub.is_diver_at_ship` is false (dock `Area2D` doesn't cover the spawn point), so F/I
   silently do nothing while the HUD permanently says "Press [F] Shop". Verified live:
   `open_shop()` refused until `is_diver_at_ship` was forced true.
   Related: `ship_hub.gd:51` also opens the shop on `ui_accept` (Space) — which is *also* the
   attack key. One Space press at the dock swings and opens the shop.
6. **No world bounds above the surface or beyond the walls.** Holding up flies the diver into
   the sky indefinitely (verified at y=-9,583, x=2,742 — ~300m above the water, past the world
   edge, camera staring at void). `barrier.tscn` does not contain the top or the area above the
   waterline.
7. **Death cause mislabeled.** Killed by an enemy → screen says "DROWNED" (`game_over_screen`
   ignores the `cause` string that `run_manager.gd:116` emits).
8. **Death message conflates count and value.** Carrying 3 pearls worth 55 shows "55 pearls
   lost" while the HUD counts "Pearls x3".
9. **Infinite-breath exploit.** Breath refills at 40/s anywhere `y <= 0` (`run_manager.gd:36-40`)
   — the entire 1600px-wide surface, not just the ship. Pop up anywhere, 1.25s later you have
   full air, cargo intact. This deletes the countdown mechanic the game is named after.
10. **Console spam & stale references.** Breath debug `print` every second
    (`breath_component.gd`), `Game.tscn:7` invalid UID warning for `background.tscn`, walls
    regenerate twice per reset (`cave_wall_generator.gd:60-61` + `DiveSpawner.gd:55-69`),
    ~20 unused-signal warnings at boot.
11. **Persisted save state masquerades as a fresh game.** `user://save.cfg` carried $865, fins
    L2, lantern, BEST 190m into what looks like a new game; there is no New Game/Continue
    distinction anywhere in the menu flow.

### B2. World building & look-and-feel

12. **The gameplay space is an empty flat-color void.** With darkness lifted at 117m the view is
    a flat navy field: no walls in view, no props, no ruins. The GDD/About screen promise
    "broken statues, drowned colonnades, coral-reclaimed stonework" — none of it exists as
    gameplay-space dressing; everything scenic lives in the distant parallax background. Fixing
    #1 helps the edges; the middle of the 1600px column needs set dressing.
13. **Midnight zone is unplayable-black.** 0.75 darkness + no light source + no silhouettes +
    no glow = players die to enemies they cannot see (verified: 7 enemies within ~700px, one
    87px away, zero visible). Whatever the lantern fix does, the *base* experience must keep
    enemies/pearls minimally readable (silhouette, bioluminescence, rim glow).
14. **`deep_formations` seam.** At ~65m the pattern band ends in a hard horizontal cut against
    flat color (violates visual-bible §3.2 vertical-repetition rule).
15. **Surface sky looks placeholder.** `SunGlow`/`SunCore` are giant flat cyan `Polygon2D` blobs
    (`scenes/world/surface_atmosphere.tscn`); above the waterline reads as unfinished. Sky/water
    share nearly the same blue with only a thin line separating them.
16. **Doc/code coordinate drift.** visual-bible §4 mandates `PIXELS_PER_METRE=20` + camera zoom
    0.25 (4:1 render ratio); shipped code is `PIXELS_PER_METRE := 32` (GameState.gd:6) and the
    diver camera has **no zoom set** (1.0). Either update the bible to the shipped contract or
    re-derive — right now every "period"/parallax rationale in the bible is wrong on paper.
17. **Pearls are nearly invisible in-world.** `scenes/pearls/pearl.tscn` uses the 16px *HUD
    icon* AtlasTexture at scale 1 as the world sprite — a dim 16px dot, no glow, no bob, no
    rarity tint. The single most important object in the game has the least presence.

### B3. Enemies & combat

18. **Ascent is guaranteed empty.** Spawner only spawns *below* the diver
    (`EnemySpawner.gd:72`) and culls 1200px above (line 15). GDD explicitly wants the return
    trip to be the dangerous part (gdd.md:23,64). Verified live: after surfacing, all live
    enemies sat at 160-200m.
19. **Combat is trivial except vs sharks.** `ATTACK_DAMAGE 25` one/two-shots every killable
    enemy (max HP 45). Only the three invulnerable sharks threaten anyone.
20. **Slash FX assets unused; visual desyncs from hitbox.** Attack renders a code `Polygon2D`
    while 16 purchased SlashFX sheets sit in `visuals/slash/`. The visual starts at press time
    but the hitbox position is set later (`diver.gd:117-130`), so the slash renders at the
    previous swing's angle for ~0.1s.
21. **Knockback cancels under held input** (`diver.gd:185` impulse vs `:91` move_toward), hits
    barely register physically. No hitstop, no shake, no damage numbers, no death burst
    (`enemy.gd:148-163` insta-frees).
22. **Enemies spawn inside where walls should be** — spawner clamps to hardcoded 80–1520
    (`EnemySpawner.gd:21-22`), ignoring the generator's 20–300 / 1300–1580 wall bands; and
    `MIN_SPAWN_Y = 120px` is only ~1.5 diver-heights below the surface.

### B4. Economy & balance

23. **Shop prices are ~6% of one dive column.** Whole shop = 180; a column holds ~33 pearls
    worth ~3,000 in aggregate; a single golden pearl (350) buys the shop twice. The intended
    "deep zone unreachable until upgraded" gate (phase_2.md:318) collapses on dive one.
24. **Density taper is a step function.** `randi_range(floori(e), ceili(e))`
    (`DiveSpawner.gd:79`) turns the intended smooth 2.5→0.8 curve into flat plateaus.
25. **`MAX_DRAIN_MULT = 2.5` makes hoarding free** past ~4 units over capacity
    (`breath_component.gd:75,85`) — greed pressure flattens exactly where it should steepen.
26. **The "greed meter" exists and isn't on screen.** `scenes/ui/LootTable.tscn` +
    `scripts/ui/LootTable.gd` (with the only OVERBURDENED warning in the game) is fully built,
    never instanced. Same for `DepthPanel.tscn`, `DepthRuler.tscn`.
27. **GDD tables are stale** (pearl bands, 60s breath math) vs shipped `.tres` values — sync the
    doc to the code once tuning lands.

### B5. UI / HUD / menus

28. **HUD ignores the purchased pixel UI pack.** `visuals/hud/` contains breath-bar frames,
    panels, inventory slots (`breath_bar_frame.png`, `character_panel.png`, `Inventory_Slot.png`,
    "Woods Journey UI Basic Pack") — all unused; the HUD is 15 code `StyleBoxFlat`s.
29. **Inventory screen is half-placeholder**: empty gray circles for icons, lists "Weighted
    Belt" and "Knife" which don't exist in the game, leaks "Swim 224px/s" engine units.
30. **Shop screen**: default-gray `ItemList` (unthemed), item names truncate ("Woven Pearl
    Bask…"), smooth modern scrollbar.
31. **Options screen**: its panel doesn't cover the menu title behind it (text bleeds through at
    the top edge), sliders/toggle are smooth modern styles (violates pixel look), **Esc doesn't
    close it** and Cancel is mouse-only from the main menu path.
32. **Timer format inconsistency**: AIR shows `1:40` normally but raw `4.5` under 10s
    (`hud.gd` int division warning is related).
33. **Credits**: raw URLs wrap mid-word; cramped.
34. **GMTK logo watermark** sits on the main menu permanently (4 more logo variants unused in
    `visuals/GMTK Game Jam 2026/`). Decide: splash-only, About-only, or keep.
35. **Prompt bar always claims "Press [F] Shop"** even mid-dive at 197m where it does nothing.

### B6. Feedback & juice (systemically absent)

36. **Zero audio.** Not one `AudioStreamPlayer` in the project. The options menu proudly mixes
    three buses that nothing plays through. GDD's #1 juice priority (heartbeat at low air,
    gdd.md:35,103) doesn't exist.
37. **Pearl pickup is a silent same-frame `queue_free()`** (`pearl.gd:54-58`) — no pop, no
    particles, no counter roll, no sound. Most-repeated action in the game.
38. **Ready-made hooks are dangling**: `Events.player_attacked` (emitted, 0 listeners),
    `Events.enemy_damaged` (emitted, 0 listeners), `Events.player_damaged` (never even emitted).
39. **Breath vignette is driven by depth, not breath** (`background.gd:206`) — the GDD asks for
    vignette tightening with low oxygen.
40. **No screen shake anywhere; instant state snaps** (HP restore at ship, breath bar hard color
    bands, death popup with no sequence).

### B7. Dead code & unused assets

- **Dead scripts**: `scripts/world/depth_spawner.gd` (118 lines, competing spawner, never
  instanced — delete); `UpgradeData.gd` (no .tres uses it; shop hardcodes a dict).
- **Dead hooks that look like features**: `wetsuit_1/2` (health_component.gd:35-41) and
  `vigor_1/2` (stamina_component.gd:29-35) — no shop entries.
- **Unused assets** (decide: wire in during the phases below, or move to an `unused/` folder):
  - `visuals/birds flying/` — 8 sheets (fishing boats + platform; misnamed folder)
  - `visuals/slash/` — all 16 SlashFX sheets (→ use in Phase 2 combat juice)
  - `visuals/hud/` — the entire UI pack except `Hydration_Bar.png` (→ use in Phase 4)
  - `visuals/general assets/` — `Catch/1-8`+`Barrel`, `Fishbarrel3/4`, `Fishing_hut.png`,
    `Pier_Tiles.png`, `Boat.png`, `Stay.png` (→ ship-hub/world dressing in Phase 1)
  - `visuals/background/Ocean0.png`, `Tile.png` (Tile.png needs recolor per bible §5)
  - `visuals/water particle effectd/` — 4 of 5 sheets unused
  - `visuals/GMTK Game Jam 2026/` — 4 of 5 logos unused
- `mcp_interaction_server.gd` in repo root — dev tool; must be excluded from any export.
- Misspelled folders worth renaming while few things reference them: `sowrd-fish`,
  `water particle effectd`, `birds flying` (contains boats).

---

## C. The Fix Plan

Ordered so each phase leaves the game strictly more "complete and whole". Within a phase, items
are independent. Keep the pixel style: every visual change must pass visual-bible §2 palette,
§5 no-smooth-gradients, and the nearest-filter/integer-scale contract.

### Phase 0 — Repair the wiring (≈ the game starts working as built)
1. **Rebuild CaveWallGenerator's children.** Either add the 13 nodes to `Game.tscn` or (more
   robust) have `cave_wall_generator.gd` create them in `_ready()`. Acceptance: zero node-not-
   found errors; walls + seabed visible and collidable; flora appears; single regen per reset
   (remove the double `generate_walls()` path via DiveSpawner).
2. **World bounds**: extend `barrier.tscn` (or generator collision) to cap ~1 diver-height above
   the waterline and both sides for y < 0. Acceptance: cannot leave the play space.
3. **Dock reliability**: enlarge `ShipDockArea` to cover the spawn/deck; drop the `ui_accept`
   shop-open in `ship_hub.gd` (F/I via MenuManager only); show the "Press [F]" prompt only when
   actually openable (`AT_SURFACE` + at ship).
4. **Death correctness**: pass `cause` through to GameOverScreen ("DROWNED" vs "KILLED — <enemy>");
   change loss line to "Lost 3 pearls (worth 55)".
5. **Fix `Game.tscn` UID reference; strip breath debug prints; fix the ~20 boot warnings** that
   are trivial (`@warning_ignore` for the Events signal false-positives, int division).
6. **Save hygiene**: main menu becomes New Game / Continue; New Game clears `user://save.cfg`.

### Phase 1 — Visibility & world identity (biggest look-and-feel win)
7. **Light system**: replace the `DarkOverlay` ColorRect with `CanvasModulate` (zone-tinted per
   visual-bible §2.3 stops, posterized steps not smooth lerp) + `PointLight2D` on the diver
   (small base halo; **Lantern upgrade = bigger/brighter radius** — finally implementing what
   the shop sells). Enemies in dark zones get a faint rim/eye glow so threats read as
   silhouettes. Pearls glow (below).
8. **Pearl presence**: dedicated world sprite (from `items.png` atlas), ~2× current size,
   rarity-tinted, slow bob + soft additive glow (stronger for black/golden). Acceptance: a pearl
   is identifiable at a glance in every zone.
9. **Mid-column set dressing**: extend `DiveSpawner` to scatter non-colliding ruin props between
   the walls — reuse `SunkenShip`/`RockArches`/`deep_formations` fragments and `Catch/` props,
   recolored into the reef ramp (bible §3.3/§5), density by zone. Acceptance: any random
   screenshot between 20-190m contains at least one silhouette besides the diver.
10. **Fix `deep_formations` seam** with 2-3 alternating variants over a 3000-4000px period
    (bible §3.2).
11. **Surface pass**: replace `SunGlow`/`SunCore` polygon blobs with a small posterized sun +
    horizon band; drift 1-2 `birds flying` boat/platform strips along the horizon; distinct
    sky-vs-water tone at the waterline.
12. **Resolve the PPM/zoom doc drift** (#16): decide shipped values are canonical (PPM=32,
    zoom=1) and rewrite bible §4, or actually adopt the 4:1 contract. Recommendation: canonize
    the shipped values — the current framing looks correct on screen.

### Phase 2 — Feedback & juice
13. **Pearl pickup**: scale-pop tween + 4-6 particle burst + HUD counter roll-up + pickup SFX;
    golden pearl gets a bigger moment (brief glow flash).
14. **Combat feel**: swap `SlashVisual` Polygon2D for an `AnimatedSprite2D` using one SlashFX
    sheet (they're 192px frames — scale to diver size); set hitbox offset at press time (fix
    desync); 0.05s hitstop + 2-3px camera shake on `Events.enemy_damaged`; emit and consume
    `Events.player_damaged` (shake + brief red vignette + knockback input-lock ~0.15s); enemy
    death = white flash + bubble burst + sink tween (assets: `impact_water_sheet` and friends).
15. **Breath tension**: vignette intensity keyed to breath fraction below 30% (keep depth
    component additive); HUD bar color interpolates instead of hard-banding; heartbeat SFX
    under 25% (GDD's own priority list).
16. **Death sequence**: 0.5-1s slow-fade/sink before the popup; distinct drowned vs killed
    presentation.
17. **Audio pass** (single PR): ambient underwater loop per zone (low-pass deepening), surface
    gulls/waves, pickup/swing/hit/hurt/splash/banner/UI-click SFX, shop cha-ching. CC0 sources
    (Kenney audio packs / freesound) — the bus plumbing in `Settings.gd` already works.

### Phase 3 — Balance & economy
18. **Kill the surface-refill exploit**: full refill only while docked at the ship; open water
    surface = slow trickle (e.g. 4/s) or breath-hold pause. This restores the loop the game is
    named after.
19. **Re-cost the shop** against actual earnings (fix #23): roughly ×4-8 current prices
    (e.g. lungs 60/150, fins 50/120, basket 60/140, lantern 90) — tune so dive #1 in sunlit
    water (~60-120 earned) buys exactly one small upgrade. Implement **basket levels actually
    raising `weight_capacity`** (3.0→4.5→6.0) and **fins reducing `exertion_bonus`** per copy
    (or fix the copy text). Add `wetsuit`/`vigor` as shop rows since the hooks exist.
20. **Density curve**: use `randf() < frac(e)` for the fractional part (fix #24); slightly
    raise deep-band value so golden pearls stay rare but reachable.
21. **Drain clamp**: raise `MAX_DRAIN_MULT` to ~4.0 (fix #25) and instance `LootTable.tscn` in
    the HUD as the greed/overburden meter it was built to be.
22. **Ascent danger**: EnemySpawner also seeds 400-1000px *above* the diver while ascending
    with cargo (biased to chargers), cull margins symmetric; respect the wall x-band from the
    generator instead of hardcoded 80-1520; `MIN_SPAWN_Y` → ~400.
23. **Combat tuning**: killable-enemy HP ×2 (jelly 30, ugly 40, sword 50, snake 60, octopus 80,
    turtle 90) so the knife matters but nothing is a sponge; keep sharks invulnerable.
24. **Sync `docs/gdd.md` tables** to shipped values once tuned.

### Phase 4 — UI/HUD coherence
25. **Re-skin HUD with the owned pixel UI pack**: `breath_bar_frame/water` for AIR,
    `character_panel` for the stat cluster, `Inventory_Slot/select` for loot; pixel-art
    progress fill (stepped, not smooth).
26. **Theme the menus once, centrally**: extend the existing theme resource with pixel
    StyleBoxTexture sliders/checkbox/ItemList so Options/Shop stop looking default-Godot;
    fix Options panel occlusion; Esc closes/backs out of every screen (wire `closed` on all).
27. **Shop/Inventory content fixes**: no truncation (wrap or widen), real icons from
    `items.png` atlas instead of gray circles, m/s + seconds units, remove or implement
    Weighted Belt/Knife rows (recommend: remove until Phase 5+).
28. **HUD copy**: consistent `m:ss` air format at all values; contextual bottom prompt (only
    show F/I when usable, show "↑ Surface to bank!" when carrying + submerged).
29. **GMTK branding**: move logo to About/Credits (or a 2s boot splash); remove from main menu.

### Phase 5 — Cleanup & guardrails
30. Delete `depth_spawner.gd`; delete or instance `DepthPanel`/`DepthRuler`; remove
    `Diver.unweighted_max_speed`, `carried_count`, `ATTACK_DURATION`, `ShipHub._open_inventory`
    dead members; make the shop consume `UpgradeData` .tres files (matches the project's own
    data-driven pattern) or delete the class.
31. Prune/relocate unused assets not claimed by Phases 1-4; rename `sowrd-fish`,
    `water particle effectd`, `birds flying` folders.
32. Exclude `mcp_interaction_server.gd` from export presets when they're added.
33. Update `CLAUDE.md` — it still describes an empty skeleton repo, which this no longer is.

---

## D. Verification (per phase, via Godot MCP)

1. Launch, read `get_debug_output` — Phase 0 done = zero ERROR lines.
2. Scripted dive to 60m / 120m / 190m, screenshot each: walls + props + pearls visible;
   Midnight readable (silhouettes/glow) with and without lantern.
3. Kill an enemy / take a hit / grab a pearl — screenshot mid-effect; confirm shake, slash
   sheet, pickup pop.
4. Economy sim: run 3 scripted dives, assert first-dive earnings land in the 60-120 band and
   full shop cost ≥ ~6 successful dives (consider `godot-monte-carlo-balancer` skill for this).
5. Exploit checks: breath does not refill in open water; cannot exit the play volume; shop
   opens with F on the deck 100% of resets.
6. Full-run smoke: menu → new game → dive → die (both causes) → new run → buy upgrade →
   verify effect actually changes stats (lungs seconds, fins speed, basket capacity, lantern
   radius).
