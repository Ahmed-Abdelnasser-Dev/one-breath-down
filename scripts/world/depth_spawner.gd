extends Node2D
class_name DepthSpawner
## Dynamically spawns pearls, reef formations, and hazards based on dive depth.
## Cleans up offscreen nodes above the camera and resets on new runs.

const CHUNK_HEIGHT := 200.0        ## Height of each procedural chunk in pixels (10m)
const SPAWN_AHEAD_DISTANCE := 1600.0 ## How far below camera to pre-generate
const DESPAWN_BEHIND_DISTANCE := 1200.0 ## How far above camera to queue_free

@export var pearl_scene: PackedScene = preload("res://scenes/pearls/pearl.tscn")

@export var seed_pearl_data: PearlData = preload("res://data/pearls/seed_pearl.tres")
@export var rose_pearl_data: PearlData = preload("res://data/pearls/rose_pearl.tres")
@export var black_pearl_data: PearlData = preload("res://data/pearls/black_pearl.tres")
@export var golden_pearl_data: PearlData = preload("res://data/pearls/golden_pearl.tres")

var _spawned_depth_y: float = 200.0  ## Starts generating below surface (200px)
var _active_objects: Array[Node2D] = []
var _diver: Diver


static func get_zone_name_for_depth(depth_m: float) -> String:
	if depth_m < 20.0:
		return "Sunlight Zone"
	elif depth_m < 50.0:
		return "Twilight Zone"
	elif depth_m < 100.0:
		return "Midnight Zone"
	else:
		return "The Abyss"


func _ready() -> void:
	Events.run_reset.connect(clear_all)
	_diver = get_tree().get_first_node_in_group("diver") as Diver
	if _diver == null:
		_diver = get_node_or_null("../Diver")


func _process(_delta: float) -> void:
	if _diver == null:
		_diver = get_tree().get_first_node_in_group("diver") as Diver
		if _diver == null:
			return

	var diver_y := _diver.global_position.y
	var target_spawn_y := diver_y + SPAWN_AHEAD_DISTANCE

	while _spawned_depth_y < target_spawn_y and _spawned_depth_y < 100000.0:
		_generate_chunk(_spawned_depth_y)
		_spawned_depth_y += CHUNK_HEIGHT

	_cull_distant_objects(diver_y)


func _generate_chunk(chunk_y: float) -> void:
	var depth_m: float = max(0.0, chunk_y / GameState.PIXELS_PER_METRE)
	var pearl_count := randi_range(1, 3)
	
	for i in range(pearl_count):
		var pearl_data: PearlData = _select_pearl_for_depth(depth_m)
		if pearl_data == null:
			continue
			
		var spawn_x := randf_range(300.0, 1600.0)
		var spawn_y := chunk_y + randf_range(20.0, CHUNK_HEIGHT - 20.0)
		
		var pearl_inst := pearl_scene.instantiate() as Pearl
		pearl_inst.global_position = Vector2(spawn_x, spawn_y)
		pearl_inst.setup(pearl_data)
		
		add_child(pearl_inst)
		_active_objects.append(pearl_inst)


func _select_pearl_for_depth(depth_m: float) -> PearlData:
	var roll := randf()
	
	if depth_m < 35.0:
		if roll < 0.75:
			return seed_pearl_data
		else:
			return rose_pearl_data
	elif depth_m < 90.0:
		if roll < 0.35:
			return seed_pearl_data
		elif roll < 0.75:
			return rose_pearl_data
		else:
			return black_pearl_data
	else:
		if roll < 0.20:
			return rose_pearl_data
		elif roll < 0.65:
			return black_pearl_data
		else:
			return golden_pearl_data


func _cull_distant_objects(diver_y: float) -> void:
	var min_valid_y := diver_y - DESPAWN_BEHIND_DISTANCE
	var i := _active_objects.size() - 1
	while i >= 0:
		var obj := _active_objects[i]
		if not is_instance_valid(obj):
			_active_objects.remove_at(i)
		elif obj.global_position.y < min_valid_y:
			obj.queue_free()
			_active_objects.remove_at(i)
		i -= 1


func clear_all() -> void:
	for obj in _active_objects:
		if is_instance_valid(obj):
			obj.queue_free()
	_active_objects.clear()
	_spawned_depth_y = 200.0
