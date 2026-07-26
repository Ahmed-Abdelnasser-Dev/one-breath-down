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

## Zone boundaries in world px, matching data/zones/*.tres (50m / 150m at
## PIXELS_PER_METRE 32). Props key off these so the gameplay layer and the
## background bands tell the same story at the same depths.
const TWILIGHT_START_Y := 1600.0
const MIDNIGHT_START_Y := 4800.0

const BUBBLE_TEXTURE: Texture2D = preload("res://visuals/water particle effectd/proj_bubblebeam3_sheet.png")

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
	_spawn_bubble_vents()


func _wall_range(y: float) -> Vector2:
	if _cave != null:
		return Vector2(_cave.get_left_wall_x(y) + 60.0, _cave.get_right_wall_x(y) - 60.0)
	return Vector2(160.0, 1440.0)


## Rock formations — MIDNIGHT ONLY. Each zone gets one identity: clear water
## up top, the drowned fleet through twilight, bare rock at the bottom. Rock
## spires scattered through the shallows is what made the descent read as a
## shuffle of unrelated scenery instead of a journey.
func _spawn_ruins() -> void:
	var y := MIDNIGHT_START_Y
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
		y += _rng.randf_range(420.0, 700.0)


## Wreck cargo — TWILIGHT ONLY, matching the drowned-fleet identity the
## background bands establish for the same depths. The sunlit zone stays clear
## water on purpose: it's the calm the rest of the dive is measured against.
func _spawn_cargo() -> void:
	var y := TWILIGHT_START_Y
	while y < MIDNIGHT_START_Y + 400.0:
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


## Seabed vents streaming bubbles up the shaft. These are the strongest signal
## that the water is alive rather than a still backdrop, and they double as
## vertical motion cues while the diver is descending.
func _spawn_bubble_vents() -> void:
	var y := 500.0
	while y < MAX_DEPTH_Y - 200.0:
		var xr := _wall_range(y)
		# Vents cling to the walls, where a fissure would plausibly be.
		var from_left := _rng.randf() < 0.5
		var x: float = (xr.x + _rng.randf_range(10.0, 90.0)) if from_left \
			else (xr.y - _rng.randf_range(10.0, 90.0))

		var vent := GPUParticles2D.new()
		vent.texture = BUBBLE_TEXTURE
		vent.texture_filter = TEXTURE_FILTER_NEAREST
		vent.position = Vector2(x, y)
		vent.amount = _rng.randi_range(8, 16)
		vent.lifetime = _rng.randf_range(3.0, 5.0)
		vent.preprocess = 3.0
		vent.randomness = 0.6
		# Only simulate vents the diver is near; 20 always-on emitters is waste.
		vent.visibility_rect = Rect2(-60, -420, 120, 460)
		vent.local_coords = false

		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		mat.particles_animation = true
		mat.particles_anim_h_frames = 6
		mat.particles_anim_v_frames = 1
		mat.particles_anim_loop = true
		vent.material = mat

		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(6, 2, 0)
		pm.direction = Vector3(0, -1, 0)
		pm.spread = 9.0
		pm.initial_velocity_min = 18.0
		pm.initial_velocity_max = 42.0
		pm.gravity = Vector3(0, -34, 0)
		pm.scale_min = 0.28
		pm.scale_max = 0.62
		pm.anim_speed_min = 0.8
		pm.anim_speed_max = 1.8
		pm.color = Color(0.85, 0.95, 1.0, 0.6)
		vent.process_material = pm

		add_child(vent)
		y += _rng.randf_range(280.0, 620.0)


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
