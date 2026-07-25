extends Node2D
class_name Background
## Drives every part of the background with clean depth stratification and
## wide, non-cluttered parallax layers across sky, surface, and deep ocean zones.
##
## Layer Architecture (Back to Front):
## 1. WaterBody (Opaque depth caustics shader background)
## 2. Sky Layers: Sky0 (Far), Sky1 (Mid), Clouds (Drifting), Sky2, SkySprite (Horizon)
## 3. Underwater Landmarks & Strata:
##    - FarBand (Sunlit distant ruins, Parallax 0.20)
##    - SunkenShip (Ocean1.png landmark at Y=1200, Parallax 0.35)
##    - RockArches (Ocean2.png arches at Y=2200, Parallax 0.50)
##    - DeepFormations (deep_formations.png, Parallax 0.65)
## 4. Surface Reef (sand, mid, near, floor - Parallax 0.70-0.90)
## 5. Accent Spire & Statue (Sparse deep ruins)
## 6. Ambient Particles (Bubbles, Marine Snow, Light Flecks) & Vignette Overlay

const SUNLIT_END := 1000.0     ## px — end of Sunlit zone (50m)
const TWILIGHT_END := 3000.0   ## px — end of Twilight zone (150m)
const FLECKS_FADE_RANGE := 900.0
const VIGNETTE_RAMP_RANGE := 1500.0

const SKY_FADE_RANGE := 450.0     ## px — sky fades out as diver descends past surface line
const REEF_FADE_RANGE := 1400.0

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


func _ready() -> void:
	if accent_spire != null:
		accent_spire.position.y = ACCENT_SPIRE_DEPTH - ACCENT_HALF_WIDTH
		var spire_color := _depth_tint(ACCENT_SPIRE_DEPTH)
		spire_color.a = ACCENT_ALPHA
		accent_spire.modulate = spire_color
		
	if accent_statue != null:
		accent_statue.position.y = ACCENT_STATUE_DEPTH - ACCENT_HALF_WIDTH
		var statue_color := _depth_tint(ACCENT_STATUE_DEPTH)
		statue_color.a = ACCENT_ALPHA
		accent_statue.modulate = statue_color


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

	# 2. Underwater Strata
	_snap_tile_x(far_band, FAR_BASE_Y, center.x * FAR_PARALLAX_X, FAR_PERIOD, QUAD_TILES)
	_snap_tile_x(rock_arches, ARCHES_BASE_Y, center.x * ARCHES_PARALLAX_X, ARCHES_PERIOD, QUAD_TILES)
	_snap_tile_x(deep_formations, DEEPFORM_BASE_Y, center.x * DEEPFORM_PARALLAX_X, DEEPFORM_PERIOD, QUAD_TILES)

	# Sunken Ship Landmark (single impressive shipwreck at Y=1100)
	if sunken_ship != null:
		sunken_ship.position.x = center.x * SHIP_PARALLAX_X + 200.0
		sunken_ship.position.y = SUNKEN_SHIP_Y
		var ship_tint := _depth_tint(SUNKEN_SHIP_Y)
		ship_tint.a = clampf(1.0 - absf(center.y - SUNKEN_SHIP_Y) / 1600.0, 0.2, 0.9)
		sunken_ship.modulate = ship_tint

	# Surface Reef
	_snap_tile_x(reef_sand, SAND_BASE_Y, center.x * SAND_PARALLAX_X, SAND_PERIOD, QUAD_TILES)
	_snap_tile_x(reef_mid, MID_BASE_Y, center.x * MID_PARALLAX_X, MID_PERIOD, QUAD_TILES)
	_snap_tile_x(reef_near, NEAR_BASE_Y, center.x * NEAR_PARALLAX_X, NEAR_PERIOD, QUAD_TILES)
	_snap_tile_x(reef_floor, FLOOR_BASE_Y, center.x * FLOOR_PARALLAX_X, FLOOR_PERIOD, QUAD_TILES)

	# Accents
	if accent_spire != null: accent_spire.position.x = center.x - ACCENT_HALF_WIDTH
	if accent_statue != null: accent_statue.position.x = center.x - ACCENT_HALF_WIDTH

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

	var far_color := _depth_tint(depth)
	far_color.a = lerpf(1.0, 0.20, clampf(depth / TWILIGHT_END, 0.0, 1.0))
	if far_band != null: far_band.modulate = far_color

	var deepform_color := _depth_tint(depth)
	deepform_color.a = lerpf(0.85, 0.25, clampf(depth / TWILIGHT_END, 0.0, 1.0))
	if deep_formations != null: deep_formations.modulate = deepform_color

	# Ocean2 is a ~78%-opaque strip; at full alpha its top edge hard-cuts the
	# DeepFormations pattern behind it (the "seam" at ~65m). Kept translucent
	# so it reads as a mid-depth band, not a wall.
	if rock_arches != null:
		var arches_color := deepform_color
		arches_color.a = deepform_color.a * 0.4
		rock_arches.modulate = arches_color

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
