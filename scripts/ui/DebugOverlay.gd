extends Control
class_name DebugOverlay

@onready var label: Label = $MarginContainer/Label

var _diver: Diver
var _breath: BreathComponent
var _spawner: DiveSpawner

var is_active: bool = false
var _kills: int = 0


func _ready() -> void:
	visible = false
	_cache_nodes()
	Events.enemy_killed.connect(_on_enemy_killed)


func _on_enemy_killed(_id: StringName, _at: Vector2) -> void:
	_kills += 1


func _cache_nodes() -> void:
	if _diver == null:
		_diver = get_tree().get_first_node_in_group("diver") as Diver
	if _diver != null and _breath == null:
		_breath = _diver.get_node_or_null("BreathComponent") as BreathComponent
	if _spawner == null:
		_spawner = get_tree().get_first_node_in_group("spawner") as DiveSpawner
		if _spawner == null:
			_spawner = get_node_or_null("../../World/DiveSpawner") as DiveSpawner


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.physical_keycode == KEY_F3 or event.physical_keycode == KEY_QUOTELEFT:
			is_active = not is_active
			visible = is_active


func _process(_delta: float) -> void:
	if not visible:
		return

	_cache_nodes()
	if label == null or _diver == null or _breath == null:
		return

	var depth_m: int = max(0, int((_diver.global_position.y) / GameState.PIXELS_PER_METRE))

	var speed_ratio: float = float(_diver.velocity.length()) / maxf(1.0, float(_diver.max_speed))
	var exertion: float = 1.0 + speed_ratio * _breath.exertion_bonus
	var over: float = maxf(0.0, _diver.carried_weight - GameState.weight_capacity)
	var strain: float = 1.0 + over * 0.15
	var zone_mult := ZoneManager.get_drain_multiplier()
	var total_drain: float = _breath._current_multiplier()

	var speed_mult: float = _diver._speed_multiplier()
	var ascent_mps: float = _diver.max_speed / GameState.PIXELS_PER_METRE
	var burn: float = _breath.base_drain * total_drain
	var reachable_m: float = (_breath.current_breath / maxf(0.001, burn)) * ascent_mps

	var seed_val: int = _spawner.current_seed if _spawner != null else 0

	label.text = """=== DEBUG OVERLAY (F3 / ~) ===
Depth: %d m
Speed: %.1f px/s (mult x%.2f)
Weight: %.2f / %.2f kg
Drain Mult: x%.2f [Exertion: x%.2f | Strain: x%.2f | Zone: x%.2f]
RNG Seed: %d
Enemies Killed: %d
--------------------------------
POINT OF NO RETURN:
Reachable Ascent: %.1f m (Current Depth: %d m)
Margin: %s%.1f m
""" % [
		depth_m,
		_diver.velocity.length(),
		speed_mult,
		_diver.carried_weight,
		GameState.weight_capacity,
		total_drain,
		exertion,
		strain,
		zone_mult,
		seed_val,
		_kills,
		reachable_m,
		depth_m,
		"+" if reachable_m >= depth_m else "-",
		abs(reachable_m - depth_m)
	]
