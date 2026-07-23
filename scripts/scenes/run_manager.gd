extends Node2D
class_name RunManager
## Owns the run lifecycle: surface detection, breath toggling, banking, reset.
## Communicates only through Events / GameState — never reached into by others.

enum RunState { AT_SURFACE, SUBMERGED, RUN_OVER }

const RESET_DELAY := 2.5   ## seconds RUN_OVER lingers before reset_run() — also
                            ## how long breath takes to visibly refill (see below)
const PIXELS_PER_METRE := 20.0

@onready var diver: Diver = $Diver
@onready var breath: BreathComponent = $Diver/BreathComponent
@onready var surface_line: Marker2D = $World/SurfaceLine

var state: RunState = RunState.AT_SURFACE
var _diver_start_position: Vector2


func _ready() -> void:
	_diver_start_position = diver.global_position
	Events.breath_depleted.connect(_on_breath_depleted)


func _physics_process(_delta: float) -> void:
	match state:
		RunState.AT_SURFACE:
			if _is_submerged():
				_enter_submerged()
		RunState.SUBMERGED:
			if not _is_submerged():
				_enter_run_over(true)   # surfaced alive → success


func _is_submerged() -> bool:
	return diver.global_position.y > surface_line.global_position.y


## Current dive depth in metres. 0 at or above the surface line.
func get_depth_meters() -> float:
	return max(0.0, (diver.global_position.y - surface_line.global_position.y) / PIXELS_PER_METRE)


func _enter_submerged() -> void:
	state = RunState.SUBMERGED
	breath.set_draining(true)
	Events.run_started.emit()
	print("Dive — breath draining (%.1f/%.1f)" % [breath.current_breath, breath.max_breath])


func _on_breath_depleted() -> void:
	print("Breath depleted")
	if state == RunState.SUBMERGED:
		_enter_run_over(false)   # drowned


func _enter_run_over(success: bool) -> void:
	state = RunState.RUN_OVER
	breath.set_draining(false)
	if success:
		GameState.add_pearls(diver.carried_value)   # 0 until Step 4; emits pearls_banked
		Events.player_surfaced.emit(diver.carried_value)
		print("Surfaced — banked %d pearls (total %d)" % [diver.carried_value, GameState.pearls])
	else:
		Events.player_died.emit("drowned")           # carried pearls lost on reset
		print("Drowned — %d pearls lost" % diver.carried_value)
	breath.begin_refill(RESET_DELAY)   # ticks up to full over the pause below
	get_tree().create_timer(RESET_DELAY).timeout.connect(reset_run)


func reset_run() -> void:
	diver.global_position = _diver_start_position
	diver.velocity = Vector2.ZERO
	diver.clear_carry()
	breath.refill()   # closes the tiny gap if the refill tween hasn't quite hit max yet
	state = RunState.AT_SURFACE
	print("Run reset — carry cleared, breath at %.1f/%.1f" % [breath.current_breath, breath.max_breath])
