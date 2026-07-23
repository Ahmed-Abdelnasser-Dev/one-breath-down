extends CharacterBody2D
class_name Diver
## Swim movement. Momentum-based: accelerates toward input direction, glides
## (drag < accel) when input is released. No gravity — this is underwater.

@export var max_speed: float = 400.0
@export var accel: float = 2000.0
@export var drag: float = 600.0


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target := input_dir * max_speed
	var rate := accel if input_dir != Vector2.ZERO else drag
	velocity = velocity.move_toward(target, rate * delta)
	move_and_slide()
