# Visual Bible — One Breath Down

Single source of truth for the game's look. Cross-check any new visual work (color, effect,
layer, HUD element) against this document before shipping it. If something here turns out wrong
once seen in-game, fix it here first, then propagate the fix to the code — don't let the two drift.

This supersedes `docs/gdd.md` Section 5's original "Gulf pearl-diving heritage" cultural framing
(dhow boats, ropes/baskets). See **Thematic Direction** below.

## 1. Thematic Direction

**Full mystical sunken-ruins.** The dive descends through the remains of a drowned civilization —
broken statues, collapsed columns, coral-reclaimed stonework — not a realistic Gulf coastline.
No dhow boats, no rope-and-basket motifs, no sun-bleached coastal realism. The reef *is* ruins;
depth is descent into an older and stranger world, which is also why pearls get more valuable and
more dangerous the deeper you go.

## 2. Palette

Every stop below was sampled from the actual shipped pixel art (not invented), so the palette
describes what's *already* mostly true and pins down the handful of places that drifted from it.
All colors are hex `#rrggbb`.

### 2.1 Surface band (above the waterline, y < 0)
| Role | Color |
|---|---|
| Sky base | `#2060b0` |
| Sky deep / cloud shadow | `#000050` |
| Cloud mid-tone | `#40a0d0` |
| Cloud highlight | `#d0f0f0` / `#a0e0f0` |

### 2.2 Reef family (statues, columns, rock spires, dunes — the near-camera ruins art)
| Role | Color |
|---|---|
| Darkest navy (dominant shadow tone) | `#122c64` |
| Mid blue | `#17427e` / `#16417d` |
| Light blue | `#185b99` |
| Teal accent (kelp fronds, coral highlights) | `#2381a1` / `#33a6b5` |
| Sand/dune dark | `#234fa1` |
| Sand/dune mid | `#2b5db8` |
| Sand/dune light | `#356cc2` |
| Sand/dune accent | `#4c7fab` |

This is the anchor family: every new asset (the `DeepFormations` mountains, any future reef
dressing) should be recolored to sit inside this navy → mid-blue → teal ramp rather than
introducing a new hue family. **`Tile.png`'s slope pieces are gold/brown (`#300000`/`#803000`/
`#905800`) and are the one shipped asset that does NOT belong to this family** — always recolor
them into the reef ramp above before using them (see §5).

### 2.3 Open water gradient (`water_body.gdshader`, posterized by depth)
| Zone | Color | Notes |
|---|---|---|
| Sunlit | `#296bc7` | Harmonized toward the far-band blue / sky blue — was too teal (`#3399b3`) before this pass |
| Shallow (Sunlit→Twilight) | `#194785` | Bridges sunlit blue to the reef's mid-blue `#17427e` |
| Twilight (in) | `#122b63` | Deliberately ~identical to reef navy `#122c64` — the water and the ruins converge in tone here |
| Twilight (out) | `#091733` | Deepening further toward midnight |
| Midnight | `#03050d` | Holds forever past ~225m |

`FarBand` (`far.png`, `#346dd6`/`#3e79dd`) is the bright "open lit water in the distance" read and
should stay as shipped — it's what the harmonized Sunlit water color above was tuned to match.

### 2.4 Vignette
`depth_vignette.gdshader` vignette color: `#03050d` (exact match to the Midnight water stop, so
the tightening vignette reads as "the same dark water," not a separate overlay color).

## 3. Composition Rules

### 3.1 Parallax convention
Parallax factor `1.0` = fully world-locked (moves fastest on screen, reads as **nearest**).
Parallax factor `0.0` = fully camera-locked (stays fixed on screen, reads as **farthest**).
Layer stack, far to near (draw order = back to front — `WaterBody` MUST stay backmost or its
opaque shader paints over every pixel-art layer above it):

1. `WaterBody` (shader, camera-follow, no parallax — always covers the viewport)
2. `Sky` / `Clouds` (parallax 0.3 / 0.5 — above the waterline only)
3. `FarBand` (parallax 0.55 — persists at all depths, fixed low alpha floor)
4. `DeepFormations` (parallax ~0.65 — persists at all depths, large-period alternating variants, §3.2)
5. Surface reef: `ReefSand` (0.7) → `ReefMid` (0.8) → `ReefNear` (0.9) → `ReefFloor` (1.0) — fades
   away entirely by ~70m; this is the "you left the shallows" beat, meant to be seen once per dive
6. Sparse deeper accents (one-off, non-tiled reuse of reef assets at fixed depths, §3.3)
7. `AmbientFollow` particles (bubbles, marine snow, light flecks)
8. `Vignette` (top `CanvasLayer`)

### 3.2 The vertical-repetition rule
**This game's camera moves primarily downward, not sideways.** A layer with a small vertical tile
period will loop constantly during a single dive — far more noticeable than horizontal looping
ever is for a bounded, oscillating swim path. Any layer meant to persist across the whole descent
(not just a one-time surface beat) must:
- Use a **large vertical period** (~3000-4000px, i.e. 150-200m) between repeats, not the ~1000px
  horizontal-tile scale used for the surface reef.
- Alternate between **2-3 visually distinct variants** through that period, so consecutive loops
  don't show the same silhouette back to back.
- Never rely on a single small tile repeating indefinitely down the Y axis.

### 3.3 One-off reuse over new art
Before authoring new art, check whether an existing asset can be reused at a different depth,
scale, or tint. Depth-appropriate darkening (toward the Twilight/Midnight stops in §2.3) makes a
second appearance of the same silhouette read as a *different, deeper* ruin rather than an
obvious repeat — this is cheaper than new art and reinforces "this world keeps going."

## 4. Pixel-Perfect Technical Contract

- **Internal resolution**: 480×270, integer-scaled to the window (`window/stretch/scale_mode=
  "integer"`, `aspect="keep"`). Never change this without re-deriving the layer periods below.
- **Camera & units (canonical, matches shipped code)**: Diver's `Camera2D` runs at **zoom 1.0**
  — the visible world region is 480×270 world px. `GameState.PIXELS_PER_METRE = 32`. Gameplay
  sprites (diver 48px frames, enemies, pearls) therefore render 1 texture pixel : 1 internal
  pixel. Background layers use `scale = 4` (1 bg texture pixel : 4 internal pixels) — the
  deliberately chunkier grain is the depth cue separating "world you touch" from "world behind."
  Every tiled background sprite's tiling period is `native_texture_width * 4`; changing either
  the camera zoom or the ×4 background scale silently breaks every parallax period and must be
  re-derived project-wide. (An earlier draft of this section described a zoom-0.25 / PPM-20
  contract that never shipped — this paragraph documents the code as it actually runs.)
- **Texture filter**: nearest everywhere (`textures/canvas_textures/default_texture_filter=0`
  project-wide; explicit `texture_filter=1` on every background `Sprite2D` regardless, since it
  must never depend on inherited defaults).
- **Pixel snapping**: `rendering/2d/snap/snap_2d_transforms_to_pixel` and
  `snap_2d_vertices_to_pixel` both `true`.
- **Movement smoothness**: `physics/common/physics_interpolation=true` (Godot 4.3+) is required
  project-wide so physics-driven nodes (the diver, and the `Camera2D` riding it) interpolate
  between fixed-rate physics ticks instead of visibly stepping at the low internal resolution.
  If motion still reads choppy after this, the fallback is `Camera2D.position_smoothing_enabled`
  with a modest `position_smoothing_speed` (~15-20) — try interpolation alone first.
- **Fonts**: `fonts/Pixellari.ttf.import` uses MSDF (`multichannel_signed_distance_field=true`),
  `antialiasing=1`, `hinting=1`, and `subpixel_positioning=1` for crisp, sharp vector-rendered pixel font glyphs at all resolutions. Use a consistent type scale across UI/HUD (base `12px`, header `16px`).

## 5. Effects Policy

- **No smooth gradients, anywhere.** Every color transition (water depth, tints) is posterized /
  stepped. This is the single most important rule — a smooth gradient is the #1 thing that breaks
  the pixel-art read (this was the root cause of the very first background attempt reading as
  "flat and clear with no depth").
- **No god-rays.** Deliberate choice, not an oversight — lighting mood comes from the posterized
  water-color bands (§2.3), particulate density ramping with depth, and the vignette (§2.4) only.
  Do not reintroduce a light-shaft effect without updating this document first.
- **Recolor before reuse.** Any asset whose native colors fall outside the palette in §2 (e.g.
  `Tile.png`'s gold/brown slope caps) must be recolored into the appropriate family — luminance-
  preserving hue shift, not just a color multiply — before it ships as a background layer.
- **Particles**: bubbles and light flecks use additive blending (`CanvasItemMaterial.blend_mode=1`)
  and are the only non-posterized elements by nature (GPU particles), kept small/sparse so they
  read as accents, not as a competing smooth-gradient effect.

## 6. References

Pulled in while establishing this direction — useful if the palette or composition ever needs
re-grounding:
- [Paleto — Deep Sea](https://paleto.itch.io/paleto-deep-sea) — 16-color palette purpose-built for
  underwater depth zones; its zone-named structure (void/abyssal/midnight/trench/shallow/surface)
  is the model for this doc's zone-based palette table, even though the exact hex stops here come
  from our own shipped art rather than that palette directly.
- [Paleto — Water](https://paleto.itch.io/paleto-water) — aquatic palette, teal/foam/bioluminescent
  reference point.
- [Free Underwater World Parallax Game Backgrounds (CraftPix)](https://craftpix.net/freebies/free-underwater-world-parallax-game-backgrounds/) and the
  [itch.io parallax + water tag](https://itch.io/game-assets/tag-parallax/tag-water) — confirm the
  "layered silhouettes receding into blue haze" composition already in use here is the standard
  genre convention, not a one-off choice.

## 7. Change Log

- Initial version. Documents the palette harmonization, vertical-repetition rule, and thematic
  direction decided alongside the `DeepFormations` layer / movement-jank / HUD pixel-perfect pass.
