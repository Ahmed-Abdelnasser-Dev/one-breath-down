extends Enemy
class_name Patroller
## Cruises back and forth along a horizontal lane centred on its spawn point
## (EnemyData.patrol_range). If EnemyData.burst_speed > 0 it also rams the
## diver on approach (turtle); otherwise it's pure contact damage with no
## lunge (ugly-fish). EnemyData.contact_damage_requires_attack gates whether
## merely touching it hurts, or only a committed ram does.

var _dir: float = 1.0   ## +1 = swimming toward home.x + patrol_range, -1 = back


func _tick_behavior(delta: float) -> void:
	if data == null:
		return

	# Reverse direction at the lane edges.
	var offset_x := global_position.x - _home.x
	if offset_x >= data.patrol_range:
		_dir = -1.0
	elif offset_x <= -data.patrol_range:
		_dir = 1.0

	var target_speed := data.move_speed
	if data.burst_speed > 0.0 and data.detect_radius > 0.0 and _dist_to_diver() <= data.detect_radius:
		# Ram: commit toward the diver's current x rather than the lane.
		target_speed = data.burst_speed
		_dir = signf(_dir_to_diver().x) if _dir_to_diver().x != 0.0 else _dir
		state = Enemy.State.ATTACK
	else:
		state = Enemy.State.PATROL

	velocity.x = move_toward(velocity.x, target_speed * _dir, data.accel * delta)
	velocity.y = move_toward(velocity.y, 0.0, data.accel * delta)

	if absf(velocity.x) > 5.0:
		_facing_right = velocity.x > 0.0

	_play("walk")
