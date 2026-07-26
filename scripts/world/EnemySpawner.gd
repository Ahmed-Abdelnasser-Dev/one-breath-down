extends Node2D
class_name EnemySpawner
## Streams enemies in around the camera rather than pre-building the whole
## column like DiveSpawner does for pearls: spawns ahead of the diver, culls
## behind, and enforces a per-zone live cap plus a minimum separation between
## enemies so a 480x270 viewport never feels cramped or empty. Diverges from
## DiveSpawner in three ways: type is picked AFTER a spawn depth is chosen
## (so the zone cap can't starve deep-only species), a failed placement is
## skipped rather than force-placed (overlapping enemies are not harmless the
## way overlapping pearls are), and this runs in _physics_process since
## everything it reads (diver.global_position) is physics-driven.

const SPAWN_MIN_AHEAD := 400.0
const SPAWN_MAX_AHEAD := 1400.0
const CULL_ABOVE := 1200.0    ## diver.y - this -> free (behind on the way down)
const CULL_BELOW := 2200.0    ## diver.y + this -> free (behind on the way back up)
const MIN_SEPARATION := 180.0
const MIN_DIVER_CLEAR := 260.0
const SPAWN_COOLDOWN := 1.2
const PLACEMENT_TRIES := 8
const SEABED_Y := 6400.0
## 120px was 3.75m — about a diver and a half below the waterline, despite the
## comment claiming it prevented surface ambushes.
const MIN_SPAWN_Y := 400.0
const WALL_MARGIN := 70.0     ## keep spawns off the cave walls

## The GDD wants the ascent to be the dangerous half of the dive, but spawning
## only ever looked *down*: everything appeared below the diver and was culled
## 1200px above, so the water you climbed back through was guaranteed empty.
## While carrying loot and heading up, some spawns now appear above instead.
const ASCENT_SPAWN_CHANCE := 0.55
const SPAWN_MIN_BEHIND := 420.0
const SPAWN_MAX_BEHIND := 1000.0
const DEFAULT_CAP := 3        ## used when ZoneManager.instance is unavailable (e.g. test runner)

@export var enemy_types: Array[EnemyData] = []
@export var enemies_container_path: NodePath = "../Enemies"

var rng := RandomNumberGenerator.new()
var _live: Array[Enemy] = []
var _cooldown: float = 0.0
var _diver: Diver
var _container: Node2D
var _cave: CaveWallGenerator


func _ready() -> void:
	rng.randomize()
	Events.run_reset.connect(clear_all)
	_cache_container()


func _cache_container() -> void:
	_container = get_node_or_null(enemies_container_path) as Node2D
	if _container == null:
		_container = self
	_cave = get_parent().get_node_or_null("CaveWallGenerator") as CaveWallGenerator if get_parent() != null else null


## Spawn X used to be hardcoded to 80..1520 regardless of the cave, so enemies
## could be placed inside solid rock — and a Charger's home anchor would end up
## embedded, leaving it hovering back toward a point it could never reach.
## DiveSpawner already asked the generator for this; the enemy spawner didn't.
func _playable_x_range(y: float) -> Vector2:
	if _cave != null:
		var lo := _cave.get_left_wall_x(y) + WALL_MARGIN
		var hi := _cave.get_right_wall_x(y) - WALL_MARGIN
		if hi > lo:
			return Vector2(lo, hi)
	return Vector2(80.0, 1520.0)


func _physics_process(delta: float) -> void:
	if _diver == null:
		_diver = get_tree().get_first_node_in_group("diver") as Diver
		if _diver == null:
			return

	var dy := _diver.global_position.y

	_prune_and_cull(dy)

	_cooldown -= delta
	if _cooldown > 0.0:
		return

	if dy < MIN_SPAWN_Y:
		return

	var cap := DEFAULT_CAP
	if ZoneManager.instance != null and ZoneManager.instance.current_zone != null:
		cap = ZoneManager.instance.current_zone.max_live_enemies
	if _live.size() >= cap:
		return

	# Ascending with pearls in hand is the moment the run is worth threatening.
	var ascending := _diver.velocity.y < -20.0 and _diver.carried_value > 0
	var offset := rng.randf_range(SPAWN_MIN_AHEAD, SPAWN_MAX_AHEAD)
	if ascending and rng.randf() < ASCENT_SPAWN_CHANCE:
		offset = -rng.randf_range(SPAWN_MIN_BEHIND, SPAWN_MAX_BEHIND)
	var spawn_y := clampf(dy + offset, MIN_SPAWN_Y, SEABED_Y - 80.0)
	var depth_m := int(spawn_y / GameState.PIXELS_PER_METRE)
	var player_depth_m := int(dy / GameState.PIXELS_PER_METRE)
	var data := _pick_type_for_depth(depth_m, player_depth_m)
	if data == null:
		_cooldown = SPAWN_COOLDOWN
		return

	var pos := Vector2.ZERO
	var placed := false
	for _try in range(PLACEMENT_TRIES):
		var candidate_y := spawn_y + rng.randf_range(-200.0, 200.0)
		var x_range := _playable_x_range(candidate_y)
		var candidate := Vector2(rng.randf_range(x_range.x, x_range.y), candidate_y)
		if candidate.distance_to(_diver.global_position) < MIN_DIVER_CLEAR:
			continue
		var clear := true
		for e in _live:
			if is_instance_valid(e) and e.global_position.distance_to(candidate) < MIN_SEPARATION:
				clear = false
				break
		if clear:
			pos = candidate
			placed = true
			break

	# Unlike DiveSpawner, we do NOT force-place after exhausting attempts:
	# clustered enemies are unreadable at this resolution, so we just skip
	# this tick and try again after the cooldown.
	if not placed:
		_cooldown = SPAWN_COOLDOWN
		return

	_spawn(data, pos)
	_cooldown = SPAWN_COOLDOWN


func _prune_and_cull(diver_y: float) -> void:
	var i := _live.size() - 1
	while i >= 0:
		var e := _live[i]
		if not is_instance_valid(e):
			_live.remove_at(i)
		elif e.global_position.y < diver_y - CULL_ABOVE or e.global_position.y > diver_y + CULL_BELOW:
			e.queue_free()
			_live.remove_at(i)
		i -= 1


func _pick_type_for_depth(depth_m: int, player_depth_m: int) -> EnemyData:
	var pool: Array[Dictionary] = []
	var total := 0.0
	for d in enemy_types:
		if depth_m < d.min_depth_m or depth_m > d.max_depth_m:
			continue
		if d.max_concurrent > 0 and _count_live_of(d.id) >= d.max_concurrent:
			continue
			
		var is_hard := d.max_hp > 50 or d.invulnerable
		var weight := d.spawn_weight
		
		if is_hard:
			weight *= 0.3
			weight += player_depth_m * 0.1
		else:
			weight *= 2.0
			weight += player_depth_m * 0.05
			
		pool.append({"data": d, "weight": weight})
		total += weight

	if pool.is_empty() or total <= 0.0:
		return null

	var roll := rng.randf_range(0.0, total)
	var acc := 0.0
	for item in pool:
		acc += item.weight
		if roll <= acc:
			return item.data
	return pool.back().data


func _count_live_of(id: StringName) -> int:
	var n := 0
	for e in _live:
		if is_instance_valid(e) and e.data != null and e.data.id == id:
			n += 1
	return n


func _spawn(data: EnemyData, pos: Vector2) -> void:
	if data.behavior_scene == null:
		return

	var inst := data.behavior_scene.instantiate() as Enemy
	inst.setup(data)
	inst.global_position = pos
	_container.add_child(inst)
	inst.reset_physics_interpolation()
	_live.append(inst)


func clear_all() -> void:
	for e in _live:
		if is_instance_valid(e):
			e.queue_free()
	_live.clear()
	_cooldown = 0.0
