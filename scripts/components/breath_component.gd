extends Node
class_name BreathComponent
## Owns the breath countdown. Drains only while submerged; drain scales with
## exertion — swimming hard costs more air than gliding. Refills gradually
## over a given duration rather than snapping to full.

const LOG_INTERVAL := 0.5   ## seconds between "still draining/refilling" log lines

@export var base_max_breath: float = 50.0    ## seconds of breath at rest
@export var base_drain: float = 1.0         ## breath/sec while resting
@export var exertion_bonus: float = 0.5     ## up to +50% drain at full speed
@export var weight_drain: float = 1.0       ## extra breath/sec per unit of carried weight

var max_breath: float = 50.0
var current_breath: float
var draining: bool = false

var _drain_log_timer := 0.0
var _refill_log_timer := 0.0
var _refilling := false
var _refill_start := 0.0
var _refill_elapsed := 0.0
var _refill_duration := 0.0

@onready var diver: Diver = get_parent()


func _ready() -> void:
	Events.upgrade_purchased.connect(func(_id): _apply_upgrades())
	Events.run_started.connect(_apply_upgrades)
	Events.run_reset.connect(_apply_upgrades)
	_apply_upgrades()


func _apply_upgrades() -> void:
	var lungs_level := GameState.get_upgrade_level("lungs_")
	if lungs_level == 1:
		max_breath = 75.0
	elif lungs_level >= 2:
		max_breath = 100.0
	else:
		max_breath = base_max_breath
		
	current_breath = max_breath
	Events.breath_changed.emit(current_breath, max_breath)


func set_draining(value: bool) -> void:
	draining = value
	if value:
		_refilling = false
		_drain_log_timer = 0.0


func refill() -> void:
	_refilling = false
	current_breath = max_breath
	Events.breath_changed.emit(current_breath, max_breath)


func refill_step(amount: float) -> void:
	if current_breath < max_breath:
		current_breath = minf(current_breath + amount, max_breath)
		Events.breath_changed.emit(current_breath, max_breath)


func begin_refill(duration: float) -> void:
	_refilling = true
	_refill_start = current_breath
	_refill_elapsed = 0.0
	_refill_duration = max(duration, 0.001)
	_refill_log_timer = 0.0


const MAX_DRAIN_MULT := 2.5
const DRAIN_PENALTY_PER_UNIT := 0.15


func _current_multiplier() -> float:
	var speed_ratio: float = float(diver.velocity.length()) / maxf(1.0, float(diver.max_speed))
	var exertion: float = 1.0 + speed_ratio * exertion_bonus
	var over: float = maxf(0.0, diver.carried_weight - GameState.weight_capacity)
	var strain: float = 1.0 + over * DRAIN_PENALTY_PER_UNIT
	var zone_mult: float = ZoneManager.instance.current_drain_multiplier if ZoneManager.instance != null else 1.0
	return minf(exertion * strain * zone_mult, MAX_DRAIN_MULT)


func _physics_process(delta: float) -> void:
	if draining:
		var mult := _current_multiplier()
		current_breath -= base_drain * mult * delta
		Events.breath_changed.emit(current_breath, max_breath)

		_drain_log_timer += delta
		if _drain_log_timer >= LOG_INTERVAL:
			_drain_log_timer = 0.0
			print("Breath: %.1f/%.1f (drain x%.2f)" % [current_breath, max_breath, mult])

		if current_breath <= 0.0:
			current_breath = 0.0
			set_draining(false)
			Events.breath_depleted.emit()
		return

	if _refilling:
		_refill_elapsed += delta
		var t: float = clamp(_refill_elapsed / _refill_duration, 0.0, 1.0)
		current_breath = lerp(_refill_start, max_breath, t)
		Events.breath_changed.emit(current_breath, max_breath)

		_refill_log_timer += delta
		if _refill_log_timer >= LOG_INTERVAL:
			_refill_log_timer = 0.0
			print("Refilling: %.1f/%.1f" % [current_breath, max_breath])

		if t >= 1.0:
			_refilling = false
			current_breath = max_breath
