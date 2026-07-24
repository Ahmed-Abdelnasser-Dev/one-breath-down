extends CharacterBody2D
class_name Diver
## Swim movement. Momentum-based: accelerates toward input direction, glides
## (drag < accel) when input is released. No gravity — this is underwater.

@export var max_speed: float = 400.0
@export var accel: float = 2000.0
@export var drag: float = 600.0

var carried_count: int = 0
var carried_value: int = 0
var carried_weight: float = 0.0

@onready var _animator: DiverAnimator = $AnimatedSprite2D


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target := input_dir * max_speed
	var rate := accel if input_dir != Vector2.ZERO else drag
	velocity = velocity.move_toward(target, rate * delta)
	move_and_slide()


func collect(data: PearlData) -> void:
	carried_count += 1
	carried_value += data.value
	carried_weight += data.carry_weight
	Events.pearl_collected.emit(data)


func clear_carry() -> void:
	carried_count = 0
	carried_value = 0
	carried_weight = 0.0


## Single entry point for hazards to react against — forwards to the visual
## state machine. Movement/health effects belong to whatever calls this.
func take_hit() -> void:
	_animator.trigger_hurt()

