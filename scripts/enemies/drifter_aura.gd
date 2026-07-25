extends Enemy
class_name DrifterAura
## Drifts vertically around its spawn point and cycles a damaging aura on/off
## (jellyfish). The aura goes through three visible phases each cycle_period:
## dormant -> telegraph (charging, EnemyData.telegraph_time long) -> live
## (damaging, for cycle_active_ratio of the remaining cycle). AuraVisual draws
## the ring so the telegraph is actually readable at 480x270.
##
## Movement is expressed as velocity (integrated by move_and_slide in the
## base), never as a direct position write — see the pearl.gd bob trap this
## avoids: writing position.y directly from a sine wave would fight knockback
## and wall collision every frame.

enum AuraPhase { DORMANT, TELEGRAPH, LIVE }

var _drift_phase: float = 0.0
var _cycle_time: float = 0.0
var _aura_phase: AuraPhase = AuraPhase.DORMANT

@onready var aura_area: Area2D = get_node_or_null("AuraArea") as Area2D
@onready var aura_visual: Node2D = get_node_or_null("AuraArea/AuraVisual") as Node2D


func _ready() -> void:
	super._ready()
	_drift_phase = randf() * TAU   # desync multiple jellyfish from each other


func _apply_data() -> void:
	super._apply_data()
	if aura_area != null:
		var shape_node := aura_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node != null and shape_node.shape is CircleShape2D and data != null:
			(shape_node.shape as CircleShape2D).radius = data.aura_radius
	_update_aura_visual()


func _tick_behavior(delta: float) -> void:
	if data == null:
		return

	# Gentle vertical drift, amplitude = patrol_range, centred on the home y.
	_drift_phase += delta * (data.move_speed / maxf(1.0, data.patrol_range))
	var target_y := _home.y + sin(_drift_phase) * data.patrol_range
	velocity.y = (target_y - global_position.y) * 2.0
	velocity.x = move_toward(velocity.x, 0.0, data.accel * delta)

	_tick_aura_cycle(delta)
	_play("idle")


func _tick_aura_cycle(delta: float) -> void:
	if data.cycle_period <= 0.0:
		return

	_cycle_time += delta
	if _cycle_time >= data.cycle_period:
		_cycle_time -= data.cycle_period

	var live_duration := data.cycle_period * data.cycle_active_ratio
	var telegraph_start := data.cycle_period - live_duration - data.telegraph_time

	var new_phase: AuraPhase
	if _cycle_time >= data.cycle_period - live_duration:
		new_phase = AuraPhase.LIVE
	elif _cycle_time >= telegraph_start:
		new_phase = AuraPhase.TELEGRAPH
	else:
		new_phase = AuraPhase.DORMANT

	if new_phase != _aura_phase:
		_aura_phase = new_phase
		_update_aura_visual()

	if _aura_phase == AuraPhase.LIVE:
		_tick_aura_damage()


func _tick_aura_damage() -> void:
	if aura_area == null or data.aura_damage <= 0:
		return
	for body in aura_area.get_overlapping_bodies():
		if body is Diver:
			body.take_hit(data.aura_damage, global_position, data.player_knockback)


func _update_aura_visual() -> void:
	if aura_visual == null or data == null:
		return
	aura_visual.visible = _aura_phase != AuraPhase.DORMANT
	if aura_visual.has_method("set_state"):
		aura_visual.call("set_state", _aura_phase, data.aura_radius, data.aura_color)
