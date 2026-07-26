extends Node2D
class_name Background
## Drives the background. The camera here travels ~6400px straight DOWN, so the
## organising principle is depth, not horizontal scroll — which is the opposite
## of what the source art was drawn for.
##
## Layer Architecture (Back to Front):
## 1. WaterBody — posterized depth-colour shader, camera-locked
## 2. Sky / Clouds — above the waterline only, faded out by 450px
## 3. FarBand + DeepFormations — continuous haze/grain, on slow VERTICAL
##    parallax so neither completes a tile period during a whole dive
## 4. DepthBands — the real depth storytelling: one-off silhouettes, one zone
##    identity each (clear / wrecks / rock). See _band_plan.
## 5. Surface Reef (sand, mid, near, floor) — surface only, fades by 1400px
## 6. Ambient Particles & Vignette
##
## SunkenShip, RockArches, AccentSpire and AccentStatue still exist as nodes in
## background.tscn but are hidden at _ready: the two accents were pinned to the
## camera (they slid with the player), and all four placed scenery at depths
## that contradicted the zone identities. DepthBands replaces all of them.

const SUNLIT_END := 1000.0     ## px — end of Sunlit zone (50m)
const TWILIGHT_END := 3000.0   ## px — end of Twilight zone (150m)
const FLECKS_FADE_RANGE := 900.0
const VIGNETTE_RAMP_RANGE := 1500.0

const SKY_FADE_RANGE := 450.0     ## px — sky fades out as diver descends past surface line
const REEF_FADE_RANGE := 1400.0
const SHAFT_CENTRE_X := 800.0

# Broad, non-cluttered Parallax Factors (0.05 to 0.90)
const SKY0_PARALLAX_X := 0.05
const SKY1_PARALLAX_X := 0.12
const CLOUDS_PARALLAX_X := 0.18
const SKY2_PARALLAX_X := 0.22
const SKY_HORIZON_PARALLAX_X := 0.28

const FAR_PARALLAX_X := 0.20
const SHIP_PARALLAX_X := 0.35
const ARCHES_PARALLAX_X := 0.50
const DEEPFORM_PARALLAX_X := 0.65

## Vertical parallax. This game's camera travels ~6400px straight down, and
## both far.png and deep_formations.png are horizontal-scroller art: far.png is
## a single seabed horizon, deep_formations is three identical coral rows. Tiled
## vertically with a fixed base_y (the old behaviour) their apparent scroll
## equals the full descent, so far.png's horizon repeated every 768px — you
## swam past the same seafloor eight times per dive.
##
## Each factor below is chosen so apparent scroll over the WHOLE descent stays
## under one tile period: the layer drifts for depth feel but never completes a
## repeat. sprite.y = camera.y * (1 - factor)  =>  apparent scroll = descent * factor.
const FAR_PARALLAX_Y := 0.09        # 6400 * 0.09 = 576px < 768px period
const DEEPFORM_PARALLAX_Y := 0.42   # 6400 * 0.42 = 2688px < 3808px period
const VERTICAL_SPAN := 12000.0      # half-height offset keeping the region over the view

const SAND_PARALLAX_X := 0.70
const MID_PARALLAX_X := 0.78
const NEAR_PARALLAX_X := 0.85
const FLOOR_PARALLAX_X := 0.92

# Seamless Tiling Periods (World px = native width * scale 4)
const SKY0_PERIOD := 1024.0     # 256 * 4
const SKY1_PERIOD := 1024.0     # 256 * 4
const CLOUDS_PERIOD := 1280.0   # 320 * 4
const SKY2_PERIOD := 1024.0     # 256 * 4
const SKY_HORIZON_PERIOD := 1344.0  # 336 * 4

const FAR_PERIOD := 1024.0      # 256 * 4
const ARCHES_PERIOD := 4096.0   # 1024 * 4
const DEEPFORM_PERIOD := 2432.0 # 608 * 4

const SAND_PERIOD := 1024.0
const MID_PERIOD := 1024.0
const NEAR_PERIOD := 1024.0
const FLOOR_PERIOD := 2048.0
const QUAD_TILES := 4.0

# Base Y World Positions
const SKY0_BASE_Y := -2800.0
const SKY1_BASE_Y := -2400.0
const CLOUDS_BASE_Y := -1800.0
const SKY2_BASE_Y := -1400.0
const SKY_HORIZON_BASE_Y := -960.0

const FAR_BASE_Y := 0.0
const SUNKEN_SHIP_Y := 1100.0   # Placed at 55m depth as a sunken landmark
const ARCHES_BASE_Y := 2000.0   # Placed at 100m depth as rock arch formation
const DEEPFORM_BASE_Y := 0.0

const SAND_BASE_Y := -218.0
const MID_BASE_Y := -148.0
const NEAR_BASE_Y := -88.0
const FLOOR_BASE_Y := -28.0

const ACCENT_SPIRE_DEPTH := 1600.0
const ACCENT_STATUE_DEPTH := 2500.0
const ACCENT_ALPHA := 0.55
const ACCENT_HALF_WIDTH := 384.0

const TWILIGHT_TINT := Color(0.071, 0.169, 0.388)
const MIDNIGHT_TINT := Color(0.012, 0.020, 0.051)
const CLOUD_DRIFT_SPEED := 7.0

@onready var water_body: ColorRect = $WaterBody
@onready var ambient_follow: Node2D = $AmbientFollow
@onready var particulate: GPUParticles2D = $AmbientFollow/Particulate
@onready var light_flecks: GPUParticles2D = $AmbientFollow/LightFlecks
@onready var vignette: ColorRect = $VignetteLayer/Vignette

@onready var sky0: Sprite2D = $Sky0
@onready var sky1: Sprite2D = $Sky1
@onready var sky2: Sprite2D = $Sky2
@onready var sky_sprite: Sprite2D = $SkySprite
@onready var clouds_sprite: Sprite2D = $CloudsSprite

@onready var far_band: Sprite2D = $FarBand
@onready var sunken_ship: Sprite2D = $SunkenShip
@onready var rock_arches: Sprite2D = $RockArches
@onready var deep_formations: Sprite2D = $DeepFormations

@onready var reef_sand: Sprite2D = $ReefSand
@onready var reef_mid: Sprite2D = $ReefMid
@onready var reef_near: Sprite2D = $ReefNear
@onready var reef_floor: Sprite2D = $ReefFloor

@onready var accent_spire: Sprite2D = $AccentSpire
@onready var accent_statue: Sprite2D = $AccentStatue

var _clouds_scroll := 0.0
var _depth_bands: Node2D
var _band_parallax: Array[float] = []
var _band_offsets: Array[float] = []

## One-off silhouettes you pass exactly once. This is what actually carries
## "I am getting deeper" — a tiling layer can't, because by definition it shows
## you the same thing again.
##
## The plan is ordered so each zone has ONE identity, and the zones read as a
## story rather than a shuffle:
##   Sunlit   (0-50m)    open, clear water — nothing but light and distance
##   Twilight (50-150m)  the drowned fleet — wrecks, and only wrecks
##   Midnight (150m+)    the rock — arches, formations, the old world's bones
## Entries are [world_y, texture, scale, alpha, parallax_x, flip_h, region_row].
## region_row indexes deep_formations.png's three coral bands; -1 = whole texture.
const _DEEPFORM_ROWS: Array = [
	Rect2(0, 120, 608, 120), Rect2(0, 386, 608, 150), Rect2(0, 714, 608, 150),
]

var _band_plan: Array = [
	# --- Twilight: the drowned fleet. Wrecks fade in, get bigger and closer. ---
	[1850.0, "ship", 2.4, 0.62, 0.40, false, -1],
	[2500.0, "ship", 3.2, 0.72, 0.48, true, -1],
	[3250.0, "merged", 3.0, 0.66, 0.44, false, -1],
	[4000.0, "ship", 3.8, 0.80, 0.52, false, -1],
	[4550.0, "ship", 2.8, 0.70, 0.46, true, -1],
	# --- Midnight: the rock takes over completely. ---
	[5050.0, "arch", 2.2, 0.82, 0.46, false, -1],
	[5500.0, "deep", 2.8, 0.78, 0.54, true, 1],
	[5950.0, "arch", 2.6, 0.86, 0.50, true, -1],
	[6300.0, "deep", 2.4, 0.82, 0.56, false, 2],
]


func _band_texture(key: String) -> Texture2D:
	match key:
		"ship": return preload("res://visuals/background/Ocean1.png")
		"merged": return preload("res://visuals/background/foregound-merged.png")
		"deep": return preload("res://visuals/background/deep_formations.png")
		"arch": return preload("res://visuals/background/Ocean2.png")
	return null


func _build_depth_bands() -> void:
	_depth_bands = Node2D.new()
	_depth_bands.name = "DepthBands"
	add_child(_depth_bands)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260726
	for entry in _band_plan:
		var spr := Sprite2D.new()
		spr.texture = _band_texture(entry[1])
		spr.texture_filter = TEXTURE_FILTER_NEAREST
		spr.scale = Vector2(entry[2], entry[2])
		spr.flip_h = entry[5]
		spr.position.y = entry[0]
		var row: int = entry[6]
		if row >= 0:
			spr.region_enabled = true
			spr.region_rect = _DEEPFORM_ROWS[row]
		_depth_bands.add_child(spr)
		_band_parallax.append(entry[4])
		_band_offsets.append(rng.randf_range(-260.0, 260.0))


## A band's horizontal parallax must be a FRACTION of camera movement, never
## the camera position itself — several layers used to be assigned `center.x`
## directly, which pinned them to the viewport so they slid along with the
## player instead of sitting in the world.
func _update_depth_bands(center: Vector2, _depth: float) -> void:
	if _depth_bands == null:
		return
	for i in _depth_bands.get_child_count():
		var spr := _depth_bands.get_child(i) as Sprite2D
		var band_y := float(_band_plan[i][0])
		spr.position.x = SHAFT_CENTRE_X + (center.x - SHAFT_CENTRE_X) * _band_parallax[i] + _band_offsets[i]
		# Bands drift vertically at the same fraction, so they read as far away
		# rather than bolted to a depth.
		spr.position.y = band_y + (center.y - band_y) * _band_parallax[i] * 0.35
		# Only lean partway into the depth tint: DepthDarkness (CanvasModulate)
		# already darkens the whole world by zone, so applying the full tint here
		# too darkened these to invisible against the water they sit in.
		var tint := Color.WHITE.lerp(_depth_tint(band_y), 0.4)
		tint.a = float(_band_plan[i][3]) * clampf(1.0 - absf(center.y - band_y) / 1400.0, 0.0, 1.0)
		spr.modulate = tint


func _ready() -> void:
	_build_depth_bands()

	# Retired in favour of DepthBands. AccentSpire/AccentStatue were assigned
	# `center.x` every frame, i.e. glued to the viewport — they slid along with
	# the player rather than staying put in the world. SunkenShip and RockArches
	# put a wreck at 34m and rock at 62m, which cut across the zone identities
	# (clear water shallow, wrecks mid, rock deep) the bands now establish.
	for retired in [accent_spire, accent_statue, sunken_ship, rock_arches]:
		if retired != null:
			retired.visible = false


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return

	var center := cam.get_screen_center_position()
	var depth: float = maxf(center.y, 0.0)

	# 1. Sky Parallax Layers
	_snap_tile_x(sky0, SKY0_BASE_Y, center.x * SKY0_PARALLAX_X, SKY0_PERIOD, QUAD_TILES)
	_snap_tile_x(sky1, SKY1_BASE_Y, center.x * SKY1_PARALLAX_X, SKY1_PERIOD, QUAD_TILES)
	_clouds_scroll += CLOUD_DRIFT_SPEED * delta
	_snap_tile_x(clouds_sprite, CLOUDS_BASE_Y, center.x * CLOUDS_PARALLAX_X + _clouds_scroll, CLOUDS_PERIOD, QUAD_TILES)
	_snap_tile_x(sky2, SKY2_BASE_Y, center.x * SKY2_PARALLAX_X, SKY2_PERIOD, QUAD_TILES)
	_snap_tile_x(sky_sprite, SKY_HORIZON_BASE_Y, center.x * SKY_HORIZON_PARALLAX_X, SKY_HORIZON_PERIOD, QUAD_TILES)

	# Sky Alpha Fade on Submersion
	var sky_t: float = clampf(1.0 - depth / SKY_FADE_RANGE, 0.0, 1.0)
	if sky0 != null: sky0.modulate.a = sky_t
	if sky1 != null: sky1.modulate.a = sky_t
	if sky2 != null: sky2.modulate.a = sky_t
	if sky_sprite != null: sky_sprite.modulate.a = sky_t
	if clouds_sprite != null: clouds_sprite.modulate.a = sky_t

	# 2. Underwater Strata — vertical parallax (see FAR_PARALLAX_Y) keeps these
	# drifting without ever completing a tile period during a dive.
	_snap_tile_x(far_band, center.y * (1.0 - FAR_PARALLAX_Y) - VERTICAL_SPAN,
		center.x * FAR_PARALLAX_X, FAR_PERIOD, QUAD_TILES)
	_snap_tile_x(deep_formations, center.y * (1.0 - DEEPFORM_PARALLAX_Y) - VERTICAL_SPAN,
		center.x * DEEPFORM_PARALLAX_X, DEEPFORM_PERIOD, QUAD_TILES)
	_update_depth_bands(center, depth)

	# Surface Reef
	_snap_tile_x(reef_sand, SAND_BASE_Y, center.x * SAND_PARALLAX_X, SAND_PERIOD, QUAD_TILES)
	_snap_tile_x(reef_mid, MID_BASE_Y, center.x * MID_PARALLAX_X, MID_PERIOD, QUAD_TILES)
	_snap_tile_x(reef_near, NEAR_BASE_Y, center.x * NEAR_PARALLAX_X, NEAR_PERIOD, QUAD_TILES)
	_snap_tile_x(reef_floor, FLOOR_BASE_Y, center.x * FLOOR_PARALLAX_X, FLOOR_PERIOD, QUAD_TILES)

	# 3. Water Body Shader & Particles
	if water_body != null:
		water_body.position = center - water_body.size * 0.5
		water_body.material.set_shader_parameter("camera_y", center.y)
		water_body.material.set_shader_parameter("camera_x", center.x)

	if ambient_follow != null:
		ambient_follow.position = center

	# Dynamic Depth Color Modulation for Reef & Far Formations
	var reef_t: float = clampf(depth / REEF_FADE_RANGE, 0.0, 1.0)
	var reef_color := _depth_tint(depth)
	reef_color.a = 1.0 - reef_t
	if reef_sand != null: reef_sand.modulate = reef_color
	if reef_mid != null: reef_mid.modulate = reef_color
	if reef_near != null: reef_near.modulate = reef_color
	if reef_floor != null: reef_floor.modulate = reef_color

	# far.png is 100% opaque, so a 1.0 alpha here painted over the WaterBody
	# shader entirely and the posterized depth colour never showed. Capped so it
	# stays a haze the depth gradient reads through.
	var far_color := _depth_tint(depth)
	far_color.a = lerpf(0.5, 0.14, clampf(depth / TWILIGHT_END, 0.0, 1.0))
	if far_band != null: far_band.modulate = far_color

	# Demoted to a faint grain. The DepthBands now carry the "world changes as
	# you descend" read; this layer's job is only to keep open water from being
	# a dead flat colour, so it must not compete with them.
	var deepform_color := _depth_tint(depth)
	deepform_color.a = lerpf(0.22, 0.08, clampf(depth / TWILIGHT_END, 0.0, 1.0))
	if deep_formations != null: deep_formations.modulate = deepform_color

	# Particle & Vignette Scaling
	if particulate != null: particulate.amount_ratio = clampf(depth / TWILIGHT_END, 0.15, 1.0)
	if light_flecks != null: light_flecks.amount_ratio = clampf(1.0 - depth / SUNLIT_END, 0.05, 1.0)
	if vignette != null and vignette.material != null:
		vignette.material.set_shader_parameter("intensity", clampf((depth - TWILIGHT_END) / VIGNETTE_RAMP_RANGE, 0.0, 1.0))


func _depth_tint(depth: float) -> Color:
	var twilight_t: float = clampf(depth / TWILIGHT_END, 0.0, 1.0)
	var midnight_t: float = clampf((depth - TWILIGHT_END) / VIGNETTE_RAMP_RANGE, 0.0, 1.0)
	return Color(1.0, 1.0, 1.0).lerp(TWILIGHT_TINT, twilight_t).lerp(MIDNIGHT_TINT, midnight_t)


func _snap_tile_x(sprite: Sprite2D, base_y: float, scrolled_x: float, period: float, quad_tiles: float) -> void:
	if sprite == null: return
	var snapped_x: float = floor(scrolled_x / period) * period
	sprite.position = Vector2(snapped_x - period * quad_tiles * 0.5, base_y)
