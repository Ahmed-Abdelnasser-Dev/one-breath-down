extends CharacterBody2D
class_name Diver
## Swim movement. Momentum-based: accelerates toward input direction, glides
## (drag < accel) when input is released. No gravity — this is underwater.

@export var base_max_speed: float = 400.0
@export var accel: float = 2000.0
@export var drag: float = 600.0

var max_speed: float = 400.0
var carried_count: int = 0
var carried_value: int = 0
var carried_weight: float = 0.0

var _animator: DiverAnimator


func _ready() -> void:
	add_to_group("diver")
	_animator = get_node_or_null("AnimatedSprite2D") as DiverAnimator
	Events.run_started.connect(apply_upgrades)
	Events.run_reset.connect(apply_upgrades)
	Events.upgrade_purchased.connect(func(_id): apply_upgrades())
	apply_upgrades()


func apply_upgrades() -> void:
	var speed := base_max_speed
	var fins_level := GameState.get_upgrade_level("fins_")
	if fins_level == 1:
		speed = 500.0
	elif fins_level >= 2:
		speed = 600.0
		
	var basket_level := GameState.get_upgrade_level("basket_")
	var effective_weight := carried_weight
	if basket_level >= 1:
		effective_weight = max(0.0, carried_weight * 0.4)
		
	max_speed = max(150.0, speed - (effective_weight * 120.0))


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
	apply_upgrades()


func clear_carry() -> void:
	carried_count = 0
	carried_value = 0
	carried_weight = 0.0
	apply_upgrades()


func take_hit() -> void:
	if _animator != null:
		_animator.trigger_hurt()
