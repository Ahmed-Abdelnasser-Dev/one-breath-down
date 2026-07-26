extends Enemy
class_name Charger
## Hovers near its spawn point until the diver enters detect_radius, then
## telegraphs (a brief squash-pulse wind-up — there's no dedicated telegraph
## animation in the shipped art, so the cue is a scale pulse) before locking
## in the diver's current position and committing to a straight-line lunge
## for attack_time seconds. The lunge does NOT steer once launched — dodge
## sideways rather than trying to outrun it. Recover afterward is the
## intended punish window: movement decays to a stop while vulnerable.

var _lunge_dir: Vector2 = Vector2.ZERO
var _telegraph_squash: float = 1.0


func _tick_behavior(delta: float) -> void:
	if data == null:
		return

	if is_on_wall() and state == Enemy.State.PATROL:
		var normal := get_wall_normal()
		velocity += normal * data.accel * delta

	match state:
		Enemy.State.TELEGRAPH:
			_tick_telegraph(delta)
		Enemy.State.ATTACK:
			_tick_attack()
		Enemy.State.RECOVER:
			_tick_recover(delta)
		_:
			_tick_hover(delta)

	if sprite != null:
		sprite.scale = Vector2(data.sprite_scale * _telegraph_squash, data.sprite_scale)


func _tick_hover(delta: float) -> void:
	if state != Enemy.State.PATROL:
		state = Enemy.State.PATROL
		_state_time = 0.0

	# Gentle pull back toward the spawn anchor so it doesn't drift off-station.
	velocity = velocity.move_toward((_home - global_position) * 1.5, data.accel * delta)
	_play("idle")

	if data.detect_radius > 0.0 and _dist_to_diver() <= data.detect_radius:
		state = Enemy.State.TELEGRAPH
		_state_time = 0.0


func _tick_telegraph(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, data.accel * delta)
	_telegraph_squash = 1.0 + sin(_state_time * 18.0) * 0.06
	var aim := _dir_to_diver()
	if aim != Vector2.ZERO and absf(aim.x) > 0.01:
		_facing_right = aim.x > 0.0
	_play("idle")

	if _state_time >= data.telegraph_time:
		_telegraph_squash = 1.0
		var target_pos := _diver.global_position + _diver.velocity * 0.35 if _diver != null else global_position
		var predicted_dir := (target_pos - global_position).normalized()
		_lunge_dir = predicted_dir if predicted_dir != Vector2.ZERO else _dir_to_diver()
		if _lunge_dir == Vector2.ZERO:
			_lunge_dir = Vector2.RIGHT if _facing_right else Vector2.LEFT
		if absf(_lunge_dir.x) > 0.01:
			_facing_right = _lunge_dir.x > 0.0
		state = Enemy.State.ATTACK
		_state_time = 0.0
		_play("attack")
		notify_attack()



func _tick_attack() -> void:
	velocity = _lunge_dir * data.burst_speed
	_play("attack")
	emit_move_puff(get_physics_process_delta_time())

	if _state_time >= data.attack_time or (is_on_wall() and _state_time > 0.15):
		state = Enemy.State.RECOVER
		_state_time = 0.0


func _tick_recover(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, data.accel * 0.5 * delta)
	_play("idle")

	if _state_time >= data.recover_time:
		state = Enemy.State.PATROL
		_state_time = 0.0

