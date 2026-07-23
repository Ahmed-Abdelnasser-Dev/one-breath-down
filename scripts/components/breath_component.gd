extends Node
class_name BreathComponent
## Owns the breath countdown. Drains only while submerged; drain scales with
## exertion — swimming hard costs more air than gliding. Refills gradually
## over a given duration rather than snapping to full.

const LOG_INTERVAL := 0.5   ## seconds between "still draining/refilling" log lines

@export var max_breath: float = 30.0        ## seconds of breath at rest
@export var base_drain: float = 1.0         ## breath/sec while resting
@export var exertion_bonus: float = 0.5     ## up to +50% drain at full speed

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


## Ticks current_breath up to max_breath over `duration` seconds instead of
## snapping instantly.
func begin_refill(duration: float) -> void:
	_refilling = true
	_refill_start = current_breath
	_refill_elapsed = 0.0
	_refill_duration = max(duration, 0.001)
	_refill_log_timer = 0.0


func _physics_process(delta: float) -> void:
	if draining:
		var speed_ratio := diver.velocity.length() / diver.max_speed
		var exertion := 1.0 + speed_ratio * exertion_bonus
		current_breath -= base_drain * exertion * delta
		Events.breath_changed.emit(current_breath, max_breath)

		_drain_log_timer += delta
		if _drain_log_timer >= LOG_INTERVAL:
			_drain_log_timer = 0.0
			print("Breath: %.1f/%.1f (exertion x%.2f)" % [current_breath, max_breath, exertion])

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
