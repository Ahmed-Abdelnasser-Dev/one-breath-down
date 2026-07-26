extends Enemy
class_name Chaser
## Continuously re-aims toward the diver's current position while pursuing
## (unlike Charger's one-shot committed lunge) — this is what makes a shark
## genuinely dangerous to try to outrun rather than just sidestep. Once close
## enough to bite it telegraphs briefly (a squash-pulse wind-up, same cue as
## Charger) before the bite actually lands, giving a fair reaction window —
## and the diver can still cancel the bite by breaking distance during the
## windup. Detection uses hysteresis (EnemyData.get_lose_radius(), normally
## 1.7x detect_radius) so it doesn't flicker in and out of the chase right at
## the detection boundary.
##
## Also serves the octopus ambush: move_speed 0 + a small detect_radius means
## it simply sits still until you're on top of it, then lashes out.

var _chasing: bool = false
var _bite_dir: Vector2 = Vector2.RIGHT
var _telegraph_squash: float = 1.0


func _tick_behavior(delta: float) -> void:
	if data == null:
		return

	match state:
		Enemy.State.TELEGRAPH:
			_tick_telegraph(delta)
		Enemy.State.ATTACK:
			_tick_attack(delta)
		Enemy.State.RECOVER:
			_tick_recover(delta)
		_:
			_tick_patrol_or_chase(delta)

	if sprite != null:
		sprite.scale = Vector2(data.sprite_scale * _telegraph_squash, data.sprite_scale)


func _tick_patrol_or_chase(delta: float) -> void:
	state = Enemy.State.PATROL

	var dist := _dist_to_diver()
	if _chasing:
		if dist > data.get_lose_radius():
			_chasing = false
	elif data.detect_radius > 0.0 and dist <= data.detect_radius:
		_chasing = true

	if _chasing:
		if dist <= data.attack_radius:
			state = Enemy.State.TELEGRAPH
			_state_time = 0.0
			velocity = Vector2.ZERO
			_play("idle" if data.move_speed <= 0.0 else "walk")
			return

		var dir := _dir_to_diver()
		if dir != Vector2.ZERO:
			var target_vel := dir * data.burst_speed
			if is_on_wall():
				var normal := get_wall_normal()
				var tangent := Vector2(-normal.y, normal.x)
				if tangent.dot(dir) < 0.0:
					tangent = -tangent
				target_vel = (tangent * 0.85 + normal * 0.15).normalized() * data.burst_speed
			velocity = velocity.move_toward(target_vel, data.accel * delta)
			if absf(dir.x) > 0.01:
				_facing_right = dir.x > 0.0
		_play("walk")
	else:
		# Not pursuing: drift gently back toward the spawn anchor. Ambush
		# species (move_speed 0) simply hold position there instead.
		var to_home := _home - global_position
		if is_on_wall():
			var normal := get_wall_normal()
			to_home += normal * 40.0
		var target := to_home.normalized() * data.move_speed if to_home.length() > 4.0 else Vector2.ZERO
		velocity = velocity.move_toward(target, data.accel * delta)
		if absf(velocity.x) > 5.0:
			_facing_right = velocity.x > 0.0
		_play("walk" if data.move_speed > 0.0 else "idle")


func _tick_telegraph(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, data.accel * delta)
	_telegraph_squash = 1.0 + sin(_state_time * 20.0) * 0.08
	var aim := _dir_to_diver()
	if aim != Vector2.ZERO and absf(aim.x) > 0.01:
		_facing_right = aim.x > 0.0

	if _dist_to_diver() > data.get_lose_radius():
		_telegraph_squash = 1.0
		_chasing = false
		state = Enemy.State.PATROL
		_state_time = 0.0
		return

	if _state_time >= data.telegraph_time:
		_telegraph_squash = 1.0
		_bite_dir = _dir_to_diver()
		if _bite_dir == Vector2.ZERO:
			_bite_dir = Vector2.RIGHT if _facing_right else Vector2.LEFT
		if absf(_bite_dir.x) > 0.01:
			_facing_right = _bite_dir.x > 0.0
		state = Enemy.State.ATTACK
		_state_time = 0.0
		_play("attack")
		notify_attack()


func _tick_attack(delta: float) -> void:
	velocity = velocity.move_toward(_bite_dir * data.burst_speed * 0.7, data.accel * delta)
	_play("attack")
	emit_move_puff(delta)

	if _state_time >= data.attack_time:
		state = Enemy.State.RECOVER
		_state_time = 0.0



func _tick_recover(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, data.accel * 0.5 * delta)
	_play("idle" if data.move_speed <= 0.0 else "walk")

	if _state_time >= data.recover_time:
		state = Enemy.State.PATROL
		_state_time = 0.0
