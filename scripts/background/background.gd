extends Node2D
class_name Background
## Drives every part of the background that can't be a one-time static
## layout, because the dive is infinite in all directions (no fixed bottom,
## no horizontal walls):
## - the water color, caustics, god rays and waterline are all re-centered on
##   the camera every frame rather than sized to cover a fixed play area;
##   their shaders take the camera position as a uniform so their patterns
##   stay anchored in the world instead of sliding with the screen
## - sky/clouds tile infinitely by snapping to the nearest multiple of their
##   texture's seamless repeat width (see _snap_tile_x), so they realign
##   perfectly no matter how far the camera has travelled
## - ambient particles (bubbles, marine snow, light flecks) follow the camera
## - god rays fade out, particulate/light-fleck density ramps, and the
##   deep-zone vignette tightens, all driven by depth
##
## Depth thresholds mirror RunManager's PIXELS_PER_METRE=20 and the GDD's
## zone bands (Sunlit 0-50m, Twilight 50-150m, Midnight 150m+). There is no
## "world bottom" constant on purpose — the dive has no floor.

const SUNLIT_END := 1000.0     ## px — end of Sunlit zone (50m)
const TWILIGHT_END := 3000.0   ## px — end of Twilight zone (150m)
const GOD_RAY_FADE_RANGE := 600.0     ## px past SUNLIT_END over which rays fully fade
const CAUSTICS_FADE_RANGE := 800.0    ## px past TWILIGHT_END over which caustics fully fade
const FLECKS_FADE_RANGE := 900.0      ## px past SUNLIT_END over which light flecks fully fade
const VIGNETTE_RAMP_RANGE := 1500.0   ## px past TWILIGHT_END over which vignette ramps in

const CLOUD_DRIFT_SPEED := 6.0   ## px/sec, constant horizontal cloud drift (wind)

## Parallax factor per layer: 1.0 = fully world-locked, 0.0 = fully
## camera-locked (stays fixed on screen). Values in between lag behind the
## camera's motion, reading as "farther away".
const SKY_PARALLAX_X := 0.4
const CLOUDS_PARALLAX_X := 0.6

## One seamless repeat width in world px for each tiled sprite (base texture
## width * its Sprite2D scale). Positions snap to multiples of this so the
## tiling never desyncs, however far the camera has travelled.
const SKY_PERIOD := 1344.0    # 336 * 4
const CLOUDS_PERIOD := 1280.0 # 320 * 4
const SKY_QUAD_TILES := 4.0
const CLOUDS_QUAD_TILES := 4.0
const SKY_BASE_Y := -960.0
const CLOUDS_BASE_Y := -1160.0

@onready var ambient_follow: Node2D = $AmbientFollow
@onready var particulate: GPUParticles2D = $AmbientFollow/Particulate
@onready var light_flecks: GPUParticles2D = $AmbientFollow/LightFlecks
@onready var water_body: ColorRect = $WaterBody
@onready var caustics: ColorRect = $Caustics
@onready var god_rays: ColorRect = $GodRays
@onready var waterline: ColorRect = $Waterline
@onready var vignette: ColorRect = $VignetteLayer/Vignette
@onready var sky_sprite: Sprite2D = $SkySprite
@onready var clouds_sprite: Sprite2D = $CloudsSprite

var _clouds_scroll := 0.0


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return

	var center := cam.get_screen_center_position()

	_snap_tile_x(sky_sprite, SKY_BASE_Y, center.x * SKY_PARALLAX_X, SKY_PERIOD, SKY_QUAD_TILES)

	_clouds_scroll += CLOUD_DRIFT_SPEED * delta
	_snap_tile_x(clouds_sprite, CLOUDS_BASE_Y, center.x * CLOUDS_PARALLAX_X + _clouds_scroll, CLOUDS_PERIOD, CLOUDS_QUAD_TILES)

	# Full 2D follow: color/caustics come entirely from shader uniforms, so
	# these rects just need to keep covering the viewport.
	water_body.position = center - water_body.size * 0.5
	water_body.material.set_shader_parameter("camera_y", center.y)

	caustics.position = center - caustics.size * 0.5
	caustics.material.set_shader_parameter("camera_pos", center)

	# X-only follow: the sunlit band / surface line are fixed absolute
	# world-Y locations, only the infinite X axis needs tracking.
	god_rays.position.x = center.x - god_rays.size.x * 0.5
	god_rays.material.set_shader_parameter("camera_x", center.x)

	waterline.position.x = center.x - waterline.size.x * 0.5
	waterline.material.set_shader_parameter("camera_x", center.x)

	ambient_follow.global_position = center

	var depth: float = max(center.y, 0.0)

	var ray_t: float = clamp(1.0 - (depth - SUNLIT_END) / GOD_RAY_FADE_RANGE, 0.0, 1.0)
	god_rays.material.set_shader_parameter("strength", ray_t)

	var caustic_t: float = clamp(1.0 - (depth - TWILIGHT_END) / CAUSTICS_FADE_RANGE, 0.0, 1.0)
	caustics.material.set_shader_parameter("strength", caustic_t)

	var snow_t: float = clamp(depth / TWILIGHT_END, 0.15, 1.0)
	particulate.amount_ratio = snow_t

	var fleck_t: float = clamp(1.0 - (depth - SUNLIT_END) / FLECKS_FADE_RANGE, 0.05, 1.0)
	light_flecks.amount_ratio = fleck_t

	var vignette_t: float = clamp((depth - TWILIGHT_END) / VIGNETTE_RAMP_RANGE, 0.0, 1.0)
	vignette.material.set_shader_parameter("intensity", vignette_t)


## Keeps a tiled Sprite2D's pattern seamless at any camera distance: snaps its
## position to the nearest multiple of `period` (the texture's own seamless
## repeat width) rather than tracking the camera continuously. Because the
## texture repeats, any snapped multiple looks identical as long as the quad
## (period * quad_tiles wide) still comfortably covers the viewport around
## the camera — which holds at every distance, including huge ones.
func _snap_tile_x(sprite: Sprite2D, base_y: float, scrolled_x: float, period: float, quad_tiles: float) -> void:
	var snapped_x: float = floor(scrolled_x / period) * period
	sprite.position = Vector2(snapped_x - period * quad_tiles * 0.5, base_y)
