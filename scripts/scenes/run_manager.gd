extends Node2D
class_name RunManager
## Owns the run lifecycle: surface detection, breath toggling, banking, reset.
## Communicates only through Events / GameState — never reached into by others.

enum RunState { AT_SURFACE, SUBMERGED, RUN_OVER }

const RESET_DELAY := 2.5   ## seconds RUN_OVER lingers before reset_run() — also
							## how long breath takes to visibly refill (see below)

@onready var diver: Diver = $Diver
@onready var breath: BreathComponent = $Diver/BreathComponent
@onready var surface_line: Marker2D = $World/SurfaceLine

var state: RunState = RunState.AT_SURFACE
var depth_m: int = 0
var _diver_start_position: Vector2


@onready var ship_hub: ShipHub = $World/ShipHub


func _ready() -> void:
	_diver_start_position = diver.global_position
	Events.breath_depleted.connect(_on_breath_depleted)
	Events.health_depleted.connect(_on_health_depleted)
	if ship_hub != null:
		ship_hub.diver_docked.connect(_on_diver_docked)


func _physics_process(delta: float) -> void:
	if diver == null or surface_line == null:
		return
	_update_depth()

	# Surfacing stops the drain, but only the ship refills you properly —
	# an open-water gasp trickles just enough to limp home. A full refill
	# anywhere on the surface would make the countdown opt-in.
	if not _is_submerged():
		if breath.draining:
			breath.set_draining(false)
		breath.refill_step(delta * (40.0 if is_at_ship() else 4.0))

	match state:
		RunState.AT_SURFACE:
			if _is_submerged():
				_enter_submerged()
		RunState.SUBMERGED:
			if _is_submerged():
				if not breath.draining:
					breath.set_draining(true)
			else:
				# At surface: check if diver reached the ship to bank pearls
				if is_at_ship():
					_enter_run_over(true)


func _is_submerged() -> bool:
	if diver == null or surface_line == null:
		return false
	return diver.global_position.y > surface_line.global_position.y


func is_at_ship() -> bool:
	if ship_hub != null:
		return ship_hub.is_diver_at_ship
	return not _is_submerged()


func _on_diver_docked() -> void:
	if state == RunState.SUBMERGED or (diver != null and diver.carried_value > 0):
		_enter_run_over(true)


## Converts world-space Y to metres once, at the boundary — nothing
## downstream ever sees a pixel coordinate. Only emits/reports on whole-metre
## change, so this is a handful of events per second, not one per frame.
func _update_depth() -> void:
	if diver == null or surface_line == null:
		return
	var raw := (diver.global_position.y - surface_line.global_position.y) / GameState.PIXELS_PER_METRE
	var m := maxi(0, int(raw))
	if m != depth_m:
		depth_m = m
		Events.depth_changed.emit(m)
		GameState.report_depth(m)


func _enter_submerged() -> void:
	state = RunState.SUBMERGED
	breath.set_draining(true)
	Events.run_started.emit()
	print("Dive — breath draining (%.1f/%.1f)" % [breath.current_breath, breath.max_breath])


func _on_breath_depleted() -> void:
	print("Breath depleted")
	if state == RunState.SUBMERGED:
		_enter_run_over(false, "drowned")


func _on_health_depleted() -> void:
	print("Health depleted")
	if state == RunState.SUBMERGED:
		_enter_run_over(false, "killed")


func _enter_run_over(success: bool, cause: String = "drowned") -> void:
	state = RunState.RUN_OVER
	breath.set_draining(false)
	if success:
		GameState.add_pearls(diver.carried_value)   # 0 until Step 4; emits pearls_banked, saves
		Events.player_surfaced.emit(diver.carried_value)
		print("Surfaced — banked %d pearls (total %d)" % [diver.carried_value, GameState.pearls])
		breath.begin_refill(RESET_DELAY)   # ticks up to full over the pause below
		get_tree().create_timer(RESET_DELAY).timeout.connect(reset_run)
	else:
		Events.player_died.emit(cause)   # carried pearls lost; GameOverScreen drives the reset
		print("%s — %d pearls lost" % [cause.capitalize(), diver.carried_value])
		GameState.save()   # best depth this dive reached is still worth keeping


func reset_run() -> void:
	diver.global_position = _diver_start_position
	diver.velocity = Vector2.ZERO
	diver.clear_carry()
	breath.refill()   # closes the tiny gap if the refill tween hasn't quite hit max yet
	state = RunState.AT_SURFACE
	Events.run_reset.emit()
	print("Run reset — carry cleared, breath at %.1f/%.1f" % [breath.current_breath, breath.max_breath])
