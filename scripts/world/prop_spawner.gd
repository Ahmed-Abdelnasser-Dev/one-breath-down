extends Node2D
class_name PropSpawner
## Dresses the open water between the cave walls: sunken cargo, large ruin
## silhouettes, and small ambient fish. Pure visuals — nothing here collides.
## Regenerates on run_reset like DiveSpawner; tint follows the same
## depth-tint convention as CaveWallGenerator's flora.

const TWILIGHT_END := 3000.0
const RAMP_RANGE := 1500.0
const TWILIGHT_TINT := Color(0.071, 0.169, 0.388)
const MIDNIGHT_TINT := Color(0.012, 0.020, 0.051)

const MAX_DEPTH_Y := 6300.0

var cargo_textures: Array[Texture2D] = [
	preload("res://visuals/general assets/Catch/Barrel.png"),
	preload("res://visuals/general assets/Catch/Box.png"),
	preload("res://visuals/general assets/Catch/Chest.png"),
	preload("res://visuals/general assets/Fishbarrel3.png"),
	preload("res://visuals/general assets/Fishbarrel4.png"),
]

var ruin_textures: Array[Texture2D] = [
	preload("res://visuals/background/foreground-1.png"),
	preload("res://visuals/background/foreground-2.png"),
]

## Deliberately excludes Catch/4 and Catch/6 — both are shark silhouettes, and
## harmless background fish must never share a shape with an actual threat.
var fish_textures: Array[Texture2D] = [
	preload("res://visuals/general assets/Catch/1.png"),
	preload("res://visuals/general assets/Catch/2.png"),
	preload("res://visuals/general assets/Catch/3.png"),
	preload("res://visuals/general assets/Catch/7.png"),
]

@export var cave_wall_generator_path: NodePath = "../CaveWallGenerator"

var _cave: CaveWallGenerator
var _rng := RandomNumberGenerator.new()
var _fish: Array[Sprite2D] = []
var _fish_speeds: Array[float] = []


func _ready() -> void:
	_cave = get_node_or_null(cave_wall_generator_path) as CaveWallGenerator
	Events.run_reset.connect(_respawn)
	_respawn()


func _respawn() -> void:
	for c in get_children():
		c.queue_free()
	_fish.clear()
	_fish_speeds.clear()
	_rng.randomize()
	_spawn_ruins()
	_spawn_cargo()
	_spawn_fish()


func _wall_range(y: float) -> Vector2:
	if _cave != null:
		return Vector2(_cave.get_left_wall_x(y) + 60.0, _cave.get_right_wall_x(y) - 60.0)
	return Vector2(160.0, 1440.0)


## Large ruin silhouettes: one broken reef/column formation every ~25-40m so
## every screen of open water has an anchor shape. Semi-transparent and
## depth-tinted, so they read as "further back" than gameplay objects.
func _spawn_ruins() -> void:
	var y := 700.0
	while y < MAX_DEPTH_Y - 300.0:
		var tex: Texture2D = ruin_textures[_rng.randi() % ruin_textures.size()]
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.texture_filter = TEXTURE_FILTER_NEAREST
		spr.flip_h = _rng.randf() < 0.5
		var s := _rng.randf_range(1.2, 2.0)
		spr.scale = Vector2(s, s)
		var xr := _wall_range(y)
		spr.position = Vector2(_rng.randf_range(xr.x + 80.0, xr.y - 80.0), y)
		spr.modulate = _prop_tint(y, 0.5)
		add_child(spr)
		y += _rng.randf_range(520.0, 900.0)


## Small sunken cargo scattered on a tighter cadence — the "people were here"
## details you swim right past.
func _spawn_cargo() -> void:
	var y := 350.0
	while y < MAX_DEPTH_Y:
		for i in _rng.randi_range(1, 2):
			var tex: Texture2D = cargo_textures[_rng.randi() % cargo_textures.size()]
			var spr := Sprite2D.new()
			spr.texture = tex
			spr.texture_filter = TEXTURE_FILTER_NEAREST
			spr.flip_h = _rng.randf() < 0.5
			spr.rotation = _rng.randf_range(-0.35, 0.35)
			var s := _rng.randf_range(1.6, 2.4)
			spr.scale = Vector2(s, s)
			var xr := _wall_range(y)
			spr.position = Vector2(_rng.randf_range(xr.x, xr.y), y + _rng.randf_range(-80.0, 80.0))
			spr.modulate = _prop_tint(y, 0.62)
			add_child(spr)
		y += _rng.randf_range(160.0, 260.0)


## Ambient fish: dense near the surface, thinning out until Midnight has
## almost none — life visibly retreating is part of the descent's mood.
func _spawn_fish() -> void:
	var y := 120.0
	while y < TWILIGHT_END + 800.0:
		var band_t := clampf(y / (TWILIGHT_END + 800.0), 0.0, 1.0)
		if _rng.randf() < lerpf(0.95, 0.15, band_t):
			var school := _rng.randi_range(1, 3)
			var base_x := _rng.randf_range(_wall_range(y).x, _wall_range(y).y)
			var speed := _rng.randf_range(14.0, 38.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
			for i in school:
				var tex: Texture2D = fish_textures[_rng.randi() % fish_textures.size()]
				var spr := Sprite2D.new()
				spr.texture = tex
				spr.texture_filter = TEXTURE_FILTER_NEAREST
				var s := _rng.randf_range(1.0, 1.8)
				spr.scale = Vector2(s, s)
				spr.position = Vector2(base_x + _rng.randf_range(-50.0, 50.0), y + _rng.randf_range(-30.0, 30.0))
				spr.modulate = _prop_tint(y, 0.62)
				spr.flip_h = speed < 0.0
				add_child(spr)
				_fish.append(spr)
				_fish_speeds.append(speed * _rng.randf_range(0.9, 1.1))
		y += _rng.randf_range(120.0, 260.0)


func _process(delta: float) -> void:
	for i in _fish.size():
		var f := _fish[i]
		if not is_instance_valid(f):
			continue
		f.position.x += _fish_speeds[i] * delta
		var xr := _wall_range(f.position.y)
		if f.position.x < xr.x:
			_fish_speeds[i] = absf(_fish_speeds[i])
			f.flip_h = false
		elif f.position.x > xr.y:
			_fish_speeds[i] = -absf(_fish_speeds[i])
			f.flip_h = true


func _depth_tint(depth: float) -> Color:
	var twilight_t: float = clampf(depth / TWILIGHT_END, 0.0, 1.0)
	var midnight_t: float = clampf((depth - TWILIGHT_END) / RAMP_RANGE, 0.0, 1.0)
	return Color(1.0, 1.0, 1.0).lerp(TWILIGHT_TINT, twilight_t).lerp(MIDNIGHT_TINT, midnight_t)


## Blue haze wash. Props must read as *background* at a glance — anything that
## keeps its native brown/green sits in the same visual layer as enemies and
## pearls, and the player ends up dodging scenery. Multiplying by a blue-
## dominant color drops the warm channels, which is what atmospheric distance
## does in the shipped art (visual-bible §2.2 reef ramp).
const BACKGROUND_WASH := Color(0.34, 0.52, 0.92)


## Props only lean partway toward the depth tint — the CanvasModulate darkness
## already darkens the whole world, so a full tint would double-darken them
## into the water color (which is exactly what made the first pass invisible).
func _prop_tint(depth: float, alpha: float) -> Color:
	var c := BACKGROUND_WASH * Color.WHITE.lerp(_depth_tint(depth), 0.45)
	c.a = alpha
	return c
