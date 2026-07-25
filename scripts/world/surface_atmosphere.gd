extends Node2D
class_name SurfaceAtmosphere
## Visual surface atmosphere controller: animated waterline wave overlay,
## splash particle effects, Sun disc in sky, and GPUParticles2D for sea foam and spray.

@onready var water_surface_tile: Sprite2D = $WaterSurfaceTile
## Drawn over the boat and the diver, so anything crossing y=0 is visibly
## half-submerged instead of pasted on top of the sea.
@onready var water_surface_front: Sprite2D = get_node_or_null("WaterSurfaceFront") as Sprite2D
@onready var splash_sprite: Sprite2D = $SplashSprite
@onready var distant_boat: Sprite2D = get_node_or_null("DistantBoat") as Sprite2D

var _time := 0.0
var _splash_timer := 0.0
var _boat_timer := 0.0
var _boat_home_x := 600.0
const SPLASH_FPS := 10.0
const BOAT_FPS := 6.0

## Width of one wave tile in Water.png. The surface band is the sheet's top
## row only — the rows below it are diagonal shoreline corner tiles, and
## including them is what made the old waterline look stitched together.
const WAVE_TILE_W := 96.0
const WAVE_SCROLL_SPEED := 11.0

## The distant fishing boat's sheet ships one corrupt frame (index 7 is a solid
## black silhouette), which read in-game as the boat flickering to black. These
## are the frames that actually draw.
const BOAT_FRAMES: Array[int] = [0, 1, 2, 3, 4, 5, 6, 8]

var _boat_frame_index := 0


func _ready() -> void:
	if splash_sprite != null:
		splash_sprite.visible = true


func _process(delta: float) -> void:
	_time += delta

	# Waves scroll in texture space, not by moving the node: with
	# snap_2d_transforms_to_pixel on, animating the node's position made the
	# whole waterline visibly judder a pixel at a time.
	if water_surface_tile != null:
		var region := water_surface_tile.region_rect
		region.position.x = fmod(_time * WAVE_SCROLL_SPEED, WAVE_TILE_W)
		water_surface_tile.region_rect = region

	# Scrolls the other way and slower, so the two layers never lock into one
	# moving pattern.
	if water_surface_front != null:
		var front := water_surface_front.region_rect
		front.position.x = fmod(-_time * WAVE_SCROLL_SPEED * 0.6, WAVE_TILE_W)
		water_surface_front.region_rect = front

	# Animate water splash sheet along the waterline
	_splash_timer += delta
	if _splash_timer >= (1.0 / SPLASH_FPS):
		_splash_timer -= (1.0 / SPLASH_FPS)
		if splash_sprite != null and splash_sprite.hframes > 1:
			splash_sprite.frame = (splash_sprite.frame + 1) % splash_sprite.hframes

	# A neighbour's boat works the horizon — slow drift + bob, silhouetted.
	if distant_boat != null:
		_boat_timer += delta
		if _boat_timer >= (1.0 / BOAT_FPS):
			_boat_timer -= (1.0 / BOAT_FPS)
			_boat_frame_index = (_boat_frame_index + 1) % BOAT_FRAMES.size()
			distant_boat.frame = BOAT_FRAMES[_boat_frame_index]
		distant_boat.position.x = _boat_home_x + sin(_time * 0.11) * 160.0
		distant_boat.position.y = -30.0 + sin(_time * 1.3) * 2.0
