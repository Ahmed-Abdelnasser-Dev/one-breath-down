extends Node2D
class_name Background
## Drives every part of the background that can't be a one-time static
## layout, because the dive is infinite in all directions (no fixed bottom,
## no horizontal walls):
## - the water color and depth vignette are re-centered on the camera every
##   frame rather than sized to cover a fixed play area; their shaders take
##   the camera position as a uniform so their patterns stay anchored in the
##   world instead of sliding with the screen
## - sky/clouds/reef/far-band/deep-formations sprites tile infinitely by
##   snapping to the nearest multiple of their texture's seamless repeat
##   width (see _snap_tile_x), so they realign perfectly no matter how far
##   the camera has travelled
## - the reef (sand/statue/rock spire/seabed) sits at a fixed world depth
##   near the surface and is genuinely left behind as the dive continues,
##   per the "surface reef, then open deep water" art direction. FarBand and
##   DeepFormations are each a single very-tall tile (see background.tscn)
##   so they keep covering the screen far past any realistic dive depth,
##   giving the open deep water a persistent silhouette instead of empty
##   flat color — per docs/visual-bible.md §3.2, a layer meant to survive
##   the whole (mostly-vertical) descent needs a large period with a few
##   alternating variants baked into that one tall tile, not a small repeat.
## - AccentSpire/AccentStatue are sparse, non-tiled, single reuses of the
##   surface reef sprites at deeper fixed depths (§3.3 of the bible) — one
##   more glimpse of the ruins on the way down, cheaper than new art.
## - ambient particles (bubbles, marine snow, light flecks) follow the camera
##
## Draw order (back to front): WaterBody, Sky, Clouds, FarBand,
## DeepFormations, the four reef layers, AccentSpire/AccentStatue, then
## particles and the vignette on top. WaterBody MUST stay the backmost node
## or its opaque shader paints over every pixel-art layer above it.
##
## All colors here are pulled from docs/visual-bible.md §2 — don't hand-pick
## a new color for a new layer without adding it there first.
##
## Depth thresholds mirror RunManager's PIXELS_PER_METRE=20 and the GDD's
## zone bands (Sunlit 0-50m, Twilight 50-150m, Midnight 150m+). There is no
## "world bottom" constant on purpose — the dive has no floor.

const SUNLIT_END := 1000.0     ## px — end of Sunlit zone (50m)
const TWILIGHT_END := 3000.0   ## px — end of Twilight zone (150m)
const FLECKS_FADE_RANGE := 900.0      ## px past SUNLIT_END over which light flecks fully fade
const VIGNETTE_RAMP_RANGE := 1500.0   ## px past TWILIGHT_END over which vignette ramps in

const SKY_FADE_RANGE := 500.0     ## px of depth over which sky/clouds fade out after submersion
const REEF_FADE_RANGE := 1400.0   ## px of depth over which the surface reef fades away entirely
const FAR_FADE_START := TWILIGHT_END  ## far-band alpha holds at 1.0 until this depth...
const FAR_FADE_RANGE := 1000.0        ## ...then eases down over this range...
const FAR_MIN_ALPHA := 0.12           ## ...to this floor, which it holds forever (persistent murk)

const DEEPFORM_FADE_START := TWILIGHT_END
const DEEPFORM_FADE_RANGE := 1200.0
const DEEPFORM_NEAR_ALPHA := 0.85  ## sits between FarBand (1.0) and the reef (1.0) in prominence
const DEEPFORM_MIN_ALPHA := 0.20

const ACCENT_SPIRE_DEPTH := 1600.0   ## world-px depth where AccentSpire (reused foreground-1) sits
const ACCENT_STATUE_DEPTH := 2200.0  ## world-px depth where AccentStatue (reused foreground-2) sits
const ACCENT_ALPHA := 0.55           ## dimmer than the surface reef — a passing glimpse, not a focal object
const ACCENT_HALF_WIDTH := 384.0     ## (native 256 * scale 3) / 2, to center each accent on the camera

## docs/visual-bible.md §2.2/§2.3 — the two tints every darkening layer lerps
## through as depth increases: first toward Twilight, then further toward
## Midnight, so persistent layers (FarBand, DeepFormations) keep darkening in
## step with the water color instead of plateauing lighter than their
## surroundings at extreme depth.
const TWILIGHT_TINT := Color(0.071, 0.169, 0.388)
const MIDNIGHT_TINT := Color(0.012, 0.020, 0.051)

const CLOUD_DRIFT_SPEED := 6.0   ## px/sec, constant horizontal cloud drift (wind)

## Parallax factor per layer: 1.0 = fully world-locked (nearest, moves most
## on screen), 0.0 = fully camera-locked (stays fixed on screen, farthest).
const SKY_PARALLAX_X := 0.3
const CLOUDS_PARALLAX_X := 0.5
const FAR_PARALLAX_X := 0.55
const DEEPFORM_PARALLAX_X := 0.65
const SAND_PARALLAX_X := 0.7
const MID_PARALLAX_X := 0.8
const NEAR_PARALLAX_X := 0.9
const FLOOR_PARALLAX_X := 1.0

## One seamless repeat width in world px for each tiled sprite (base texture
## width * its Sprite2D scale of 4). Positions snap to multiples of this so
## the tiling never desyncs, however far the camera has travelled.
const SKY_PERIOD := 1344.0    # 336 * 4
const CLOUDS_PERIOD := 1280.0 # 320 * 4
const FAR_PERIOD := 1024.0    # 256 * 4
const DEEPFORM_PERIOD := 2432.0  # 608 * 4
const SAND_PERIOD := 1024.0   # 256 * 4
const MID_PERIOD := 1024.0    # 256 * 4
const NEAR_PERIOD := 1024.0   # 256 * 4
const FLOOR_PERIOD := 2048.0  # 512 * 4
const QUAD_TILES := 4.0       ## shared tile count for every layer's region width

## Fixed world-Y (top-left, sprites are non-centered) for each layer. Sky/
## Clouds sit above the surface line (y=0); the reef layers' textures have a
## transparent band above their art, so these values bottom-align each
## sprite's seabed content a little deeper than the last, giving a gentle
## terraced reef profile. FarBand and DeepFormations start exactly at the
## surface and are tiled extremely tall (see background.tscn) so they never
## need to move vertically.
const SKY_BASE_Y := -960.0
const CLOUDS_BASE_Y := -1160.0
const FAR_BASE_Y := 0.0
const DEEPFORM_BASE_Y := 0.0
const SAND_BASE_Y := -218.0
const MID_BASE_Y := -148.0
const NEAR_BASE_Y := -88.0
const FLOOR_BASE_Y := -28.0

@onready var ambient_follow: Node2D = $AmbientFollow
@onready var particulate: GPUParticles2D = $AmbientFollow/Particulate
@onready var light_flecks: GPUParticles2D = $AmbientFollow/LightFlecks
@onready var water_body: ColorRect = $WaterBody
@onready var vignette: ColorRect = $VignetteLayer/Vignette
@onready var sky_sprite: Sprite2D = $SkySprite
@onready var clouds_sprite: Sprite2D = $CloudsSprite
@onready var far_band: Sprite2D = $FarBand
@onready var deep_formations: Sprite2D = $DeepFormations
@onready var reef_sand: Sprite2D = $ReefSand
@onready var reef_mid: Sprite2D = $ReefMid
@onready var reef_near: Sprite2D = $ReefNear
@onready var reef_floor: Sprite2D = $ReefFloor
@onready var accent_spire: Sprite2D = $AccentSpire
@onready var accent_statue: Sprite2D = $AccentStatue

var _clouds_scroll := 0.0


func _ready() -> void:
	# One-off placements: tint/alpha never change, only X (camera-centered
	# every frame in _process) and Y (fixed depth) matter after this.
	accent_spire.position.y = ACCENT_SPIRE_DEPTH - ACCENT_HALF_WIDTH
	accent_statue.position.y = ACCENT_STATUE_DEPTH - ACCENT_HALF_WIDTH
	var spire_color := _depth_tint(ACCENT_SPIRE_DEPTH)
	spire_color.a = ACCENT_ALPHA
	accent_spire.modulate = spire_color
	var statue_color := _depth_tint(ACCENT_STATUE_DEPTH)
	statue_color.a = ACCENT_ALPHA
	accent_statue.modulate = statue_color


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return

	var center := cam.get_screen_center_position()
	var depth: float = max(center.y, 0.0)

	_snap_tile_x(sky_sprite, SKY_BASE_Y, center.x * SKY_PARALLAX_X, SKY_PERIOD, QUAD_TILES)

	_clouds_scroll += CLOUD_DRIFT_SPEED * delta
	_snap_tile_x(clouds_sprite, CLOUDS_BASE_Y, center.x * CLOUDS_PARALLAX_X + _clouds_scroll, CLOUDS_PERIOD, QUAD_TILES)

	_snap_tile_x(far_band, FAR_BASE_Y, center.x * FAR_PARALLAX_X, FAR_PERIOD, QUAD_TILES)
	_snap_tile_x(deep_formations, DEEPFORM_BASE_Y, center.x * DEEPFORM_PARALLAX_X, DEEPFORM_PERIOD, QUAD_TILES)
	_snap_tile_x(reef_sand, SAND_BASE_Y, center.x * SAND_PARALLAX_X, SAND_PERIOD, QUAD_TILES)
	_snap_tile_x(reef_mid, MID_BASE_Y, center.x * MID_PARALLAX_X, MID_PERIOD, QUAD_TILES)
	_snap_tile_x(reef_near, NEAR_BASE_Y, center.x * NEAR_PARALLAX_X, NEAR_PERIOD, QUAD_TILES)
	_snap_tile_x(reef_floor, FLOOR_BASE_Y, center.x * FLOOR_PARALLAX_X, FLOOR_PERIOD, QUAD_TILES)

	# Sparse one-off accents: centered horizontally on the camera (so they're
	# always seen when their depth scrolls by, regardless of how far the
	# diver has swum sideways), but never tiled or re-picked.
	accent_spire.position.x = center.x - ACCENT_HALF_WIDTH
	accent_statue.position.x = center.x - ACCENT_HALF_WIDTH

	# Full 2D follow: color comes entirely from a shader uniform, so this
	# rect just needs to keep covering the viewport.
	water_body.position = center - water_body.size * 0.5
	water_body.material.set_shader_parameter("camera_y", center.y)

	# Sky/clouds read as "above the surface" — fade them out once the diver
	# has descended a little way rather than relying only on them scrolling
	# off the top of the screen, which avoids a hard pop at the edge.
	var sky_t: float = clamp(1.0 - depth / SKY_FADE_RANGE, 0.0, 1.0)
	sky_sprite.modulate.a = sky_t
	clouds_sprite.modulate.a = sky_t

	# Surface reef: fades away entirely by REEF_FADE_RANGE, darkening toward
	# the depth tint as it goes so it reads as sinking into murk rather than
	# just popping out.
	var reef_t: float = clamp(depth / REEF_FADE_RANGE, 0.0, 1.0)
	var reef_color := _depth_tint(depth)
	reef_color.a = 1.0 - reef_t
	reef_sand.modulate = reef_color
	reef_mid.modulate = reef_color
	reef_near.modulate = reef_color
	reef_floor.modulate = reef_color

	# Far band: holds fully visible (giving the surface reef a hazy distant
	# backdrop, seen through the gaps between kelp/rock silhouettes) through
	# Sunlit and Twilight, then eases down to a low floor that persists at
	# any depth — the "you're never in a featureless void" murk layer.
	var far_deep_t: float = clamp((depth - FAR_FADE_START) / FAR_FADE_RANGE, 0.0, 1.0)
	var far_color := _depth_tint(depth)
	far_color.a = lerp(1.0, FAR_MIN_ALPHA, far_deep_t)
	far_band.modulate = far_color

	# Deep formations: the mid-distance mountain layer, between FarBand and
	# the reef in both parallax and prominence. Also persists forever, at a
	# higher floor alpha than FarBand since it's meant to read as closer.
	var deepform_deep_t: float = clamp((depth - DEEPFORM_FADE_START) / DEEPFORM_FADE_RANGE, 0.0, 1.0)
	var deepform_color := _depth_tint(depth)
	deepform_color.a = lerp(DEEPFORM_NEAR_ALPHA, DEEPFORM_MIN_ALPHA, deepform_deep_t)
	deep_formations.modulate = deepform_color

	var snow_t: float = clamp(depth / TWILIGHT_END, 0.15, 1.0)
	particulate.amount_ratio = snow_t

	var fleck_t: float = clamp(1.0 - (depth - SUNLIT_END) / FLECKS_FADE_RANGE, 0.05, 1.0)
	light_flecks.amount_ratio = fleck_t

	var vignette_t: float = clamp((depth - TWILIGHT_END) / VIGNETTE_RAMP_RANGE, 0.0, 1.0)
	vignette.material.set_shader_parameter("intensity", vignette_t)


## Shared depth->tint curve (docs/visual-bible.md §2.2/§2.3): darkens toward
## TWILIGHT_TINT through Sunlit+Twilight, then continues further toward
## MIDNIGHT_TINT so any layer using this keeps pace with the water color's
## own darkening instead of plateauing lighter than its surroundings.
func _depth_tint(depth: float) -> Color:
	var twilight_t: float = clamp(depth / TWILIGHT_END, 0.0, 1.0)
	var midnight_t: float = clamp((depth - TWILIGHT_END) / VIGNETTE_RAMP_RANGE, 0.0, 1.0)
	return Color(1.0, 1.0, 1.0).lerp(TWILIGHT_TINT, twilight_t).lerp(MIDNIGHT_TINT, midnight_t)


## Keeps a tiled Sprite2D's pattern seamless at any camera distance: snaps its
## position to the nearest multiple of `period` (the texture's own seamless
## repeat width) rather than tracking the camera continuously. Because the
## texture repeats, any snapped multiple looks identical as long as the quad
## (period * quad_tiles wide) still comfortably covers the viewport around
## the camera — which holds at every distance, including huge ones.
func _snap_tile_x(sprite: Sprite2D, base_y: float, scrolled_x: float, period: float, quad_tiles: float) -> void:
	var snapped_x: float = floor(scrolled_x / period) * period
	sprite.position = Vector2(snapped_x - period * quad_tiles * 0.5, base_y)
