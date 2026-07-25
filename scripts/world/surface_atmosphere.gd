extends Node2D
class_name SurfaceAtmosphere
## Visual surface atmosphere controller: animated waterline wave overlay,
## splash particle effects, Sun disc in sky, and GPUParticles2D for sea foam and spray.

@onready var water_surface_tile: Sprite2D = $WaterSurfaceTile
@onready var splash_sprite: Sprite2D = $SplashSprite
@onready var distant_boat: Sprite2D = get_node_or_null("DistantBoat") as Sprite2D

var _time := 0.0
var _splash_timer := 0.0
var _boat_timer := 0.0
var _boat_home_x := 600.0
const SPLASH_FPS := 10.0
const BOAT_FPS := 6.0


func _ready() -> void:
	if splash_sprite != null:
		splash_sprite.visible = true


func _process(delta: float) -> void:
	_time += delta

	# Animate water surface tile to simulate rolling surface waves
	if water_surface_tile != null:
		water_surface_tile.position.x = -400.0 + sin(_time * 1.4) * 10.0
		water_surface_tile.position.y = -10.0 + cos(_time * 1.8) * 3.0

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
			if distant_boat.hframes > 1:
				distant_boat.frame = (distant_boat.frame + 1) % distant_boat.hframes
		distant_boat.position.x = _boat_home_x + sin(_time * 0.11) * 160.0
		distant_boat.position.y = -26.0 + sin(_time * 1.3) * 2.0
