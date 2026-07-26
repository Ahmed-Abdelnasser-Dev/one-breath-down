extends Node2D
class_name DiveSpawner

const MAX_DEPTH_M := 200
const BAND_M := 10
const PLAY_WIDTH_MIN := 100.0
const PLAY_WIDTH_MAX := 1500.0
const MIN_PEARL_SEPARATION := 40.0

@export var pearl_scene: PackedScene = preload("res://scenes/pearls/pearl.tscn")
@export var pearl_types: Array[PearlData] = [
	preload("res://data/pearls/seed_pearl.tres"),
	preload("res://data/pearls/rose_pearl.tres"),
	preload("res://data/pearls/black_pearl.tres"),
	preload("res://data/pearls/golden_pearl.tres")
]

@export var pearls_container_path: NodePath = "../Pearls"
@export var cave_wall_generator_path: NodePath = "../CaveWallGenerator"

var rng := RandomNumberGenerator.new()
var current_seed: int = 0

var _pearls_container: Node2D
var _cave_wall_generator: CaveWallGenerator


func _ready() -> void:
	Events.run_reset.connect(_on_run_reset)
	Events.run_started.connect(_on_run_started)
	_cache_references()
	_on_run_reset()


func _cache_references() -> void:
	_pearls_container = get_node_or_null(pearls_container_path) as Node2D
	if _pearls_container == null:
		_pearls_container = self
	_cave_wall_generator = get_node_or_null(cave_wall_generator_path) as CaveWallGenerator
	if _cave_wall_generator == null and get_parent() != null:
		_cave_wall_generator = get_parent().get_node_or_null("CaveWallGenerator") as CaveWallGenerator


func _cache_container() -> void:
	_cache_references()


func set_seed(new_seed: int) -> void:
	current_seed = new_seed
	rng.seed = current_seed
	if _cave_wall_generator != null:
		_cave_wall_generator.set_seed(new_seed)


func randomize_seed() -> void:
	current_seed = randi()
	rng.seed = current_seed
	if _cave_wall_generator != null:
		_cave_wall_generator.set_seed(current_seed)


func _on_run_started() -> void:
	if _pearls_container == null or _pearls_container.get_child_count() == 0:
		spawn_column()


func _on_run_reset() -> void:
	randomize_seed()
	spawn_column()


func spawn_column() -> void:
	_clear_pearls()
	_cache_references()

	for band_top in range(10, MAX_DEPTH_M, BAND_M):
		var t := float(band_top) / float(MAX_DEPTH_M)
		var expected_count := lerpf(2.5, 0.8, t)
		# randi_range(floor, ceil) has a mean of floor+0.5 regardless of the
		# fraction, which turned the intended smooth 2.5 -> 0.8 taper into a
		# step function: a flat 2.5 for the first 60m, then a cliff. Taking the
		# fractional part as a probability actually reproduces the curve.
		var count := floori(expected_count)
		if rng.randf() < expected_count - float(count):
			count += 1

		var band_placed_positions: Array[Vector2] = []

		for i in range(count):
			var depth := band_top + rng.randi_range(0, BAND_M - 1)
			var data := _pick_type_for_depth(depth)
			if data == null:
				continue

			var depth_y := depth * GameState.PIXELS_PER_METRE

			var spawn_pos := Vector2.ZERO
			var attempts := 0
			var valid := false

			var min_x := PLAY_WIDTH_MIN
			var max_x := PLAY_WIDTH_MAX
			if _cave_wall_generator != null:
				min_x = _cave_wall_generator.get_left_wall_x(depth_y) + 30.0
				max_x = _cave_wall_generator.get_right_wall_x(depth_y) - 30.0

			while attempts < 10 and not valid:
				attempts += 1
				var spawn_x := rng.randf_range(min_x, max_x)
				var spawn_y := depth_y + rng.randf_range(-10.0, 10.0)
				spawn_pos = Vector2(spawn_x, spawn_y)

				valid = true
				for prev_pos in band_placed_positions:
					if prev_pos.distance_to(spawn_pos) < MIN_PEARL_SEPARATION:
						valid = false
						break

			if valid or attempts >= 10:
				band_placed_positions.append(spawn_pos)
				_place_pearl(data, spawn_pos)


func _pick_type_for_depth(depth: int) -> PearlData:
	var pool: Array[PearlData] = []
	var total := 0.0
	for p in pearl_types:
		if depth >= p.min_depth_m and depth <= p.max_depth_m:
			pool.append(p)
			total += p.spawn_weight

	if pool.is_empty() or total <= 0.0:
		return null

	var roll := rng.randf_range(0.0, total)
	var current := 0.0
	for p in pool:
		current += p.spawn_weight
		if roll <= current:
			return p
	return pool.back()


func _place_pearl(p_data: PearlData, pos: Vector2) -> void:
	if pearl_scene == null:
		return

	var inst := pearl_scene.instantiate() as Pearl
	inst.global_position = pos
	inst.setup(p_data)
	if _pearls_container != null:
		_pearls_container.add_child(inst)
	else:
		add_child(inst)


func _clear_pearls() -> void:
	_cache_container()
	if _pearls_container != null:
		for child in _pearls_container.get_children():
			child.queue_free()
