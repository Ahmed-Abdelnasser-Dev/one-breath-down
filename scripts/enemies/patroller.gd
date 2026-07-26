extends Enemy
class_name Patroller
## Cruises back and forth along a horizontal lane centred on its spawn point
## (EnemyData.patrol_range). If EnemyData.burst_speed > 0 it also rams the
## diver on approach (turtle); otherwise it's pure contact damage with no
## lunge (ugly-fish). EnemyData.contact_damage_requires_attack gates whether
## merely touching it hurts, or only a committed ram does.

var _dir: float = 1.0   ## +1 = swimming toward home.x + patrol_range, -1 = back
var _aggro: bool = false


func _tick_behavior(delta: float) -> void:
	if data == null:
		return

	var dist := _dist_to_diver()
	var lose_r := data.get_lose_radius()
	if _aggro:
		if dist > lose_r:
			_aggro = false
	elif data.detect_radius > 0.0 and dist <= data.detect_radius:
		_aggro = true

	if _aggro and data.burst_speed > 0.0:
		# Ram: aggressively pursue diver in 2D (X and Y) toward diver's position
		var target_speed := data.burst_speed
		var dir := _dir_to_diver()
		if dir != Vector2.ZERO:
			velocity = velocity.move_toward(dir * target_speed, data.accel * delta)
			if absf(dir.x) > 0.01:
				_facing_right = dir.x > 0.0
		state = Enemy.State.ATTACK
	else:
		state = Enemy.State.PATROL
		# Reverse direction at the lane edges or when hitting a wall.
		var offset_x := global_position.x - _home.x
		if offset_x >= data.patrol_range:
			_dir = -1.0
		elif offset_x <= -data.patrol_range:
			_dir = 1.0

		if is_on_wall():
			var normal := get_wall_normal()
			if normal.x != 0.0:
				_dir = signf(normal.x)
			else:
				_dir = -_dir

		velocity.x = move_toward(velocity.x, data.move_speed * _dir, data.accel * delta)
		velocity.y = move_toward(velocity.y, 0.0, data.accel * delta)
		if absf(velocity.x) > 5.0:
			_facing_right = velocity.x > 0.0



	if state == Enemy.State.ATTACK:
		_play("attack")
	else:
		_play("walk")

