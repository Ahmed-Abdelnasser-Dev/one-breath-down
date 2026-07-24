extends CharacterBody2D
class_name Diver
## Swim movement. Momentum-based underwater physics: accelerates smoothly toward
## input direction, glides (drag) when input is released, and uses fluid turn
## responsiveness when switching directions to prevent snappy vector flips.

const SPEED_PENALTY_PER_UNIT := 0.18

@export var base_max_speed: float = 160.0   ## = 5 m/s at PIXELS_PER_METRE 32; see docs/phase_2.md §7
@export var accel: float = 540.0            ## Forward swimming acceleration
@export var turn_accel: float = 850.0       ## Turn responsiveness acceleration when reversing direction
@export var drag: float = 400.0             ## Underwater gliding deceleration when input is released

var max_speed: float = 160.0
var unweighted_max_speed: float = 160.0
var carried_count: int = 0
var carried_value: int = 0
var carried_weight: float = 0.0

var _animator: DiverAnimator
var _was_underwater: bool = false
@onready var camera: Camera2D = get_node_or_null("Camera2D") as Camera2D
@onready var bubble_particles: GPUParticles2D = get_node_or_null("BubbleTrail") as GPUParticles2D
@onready var splash_particles: GPUParticles2D = get_node_or_null("SplashParticles") as GPUParticles2D


func _ready() -> void:
	add_to_group("diver")
	_animator = get_node_or_null("AnimatedSprite2D") as DiverAnimator
	_was_underwater = global_position.y > 0.0

	if camera != null:
		camera.limit_left = 0
		camera.limit_right = 1600
		camera.limit_bottom = 6400

	Events.run_started.connect(apply_upgrades)
	Events.run_reset.connect(apply_upgrades)
	Events.upgrade_purchased.connect(func(_id): apply_upgrades())
	apply_upgrades()


func _speed_multiplier() -> float:
	var over := maxf(0.0, carried_weight - GameState.weight_capacity)
	return 1.0 / (1.0 + over * SPEED_PENALTY_PER_UNIT)


func apply_upgrades() -> void:
	var speed := base_max_speed
	var fins_level := GameState.get_upgrade_level("fins_")
	if fins_level == 1:
		speed = 192.0 # 6 m/s
	elif fins_level >= 2:
		speed = 224.0 # 7 m/s
		
	unweighted_max_speed = speed
	max_speed = speed * _speed_multiplier()


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		var target := input_dir * max_speed
		
		# Turn responsiveness: calculate direction alignment with current velocity
		var current_speed := velocity.length()
		var current_accel := accel
		if current_speed > 10.0:
			var dot := velocity.normalized().dot(input_dir)
			# If reversing or making a sharp turn (dot < 0.2), scale up turn acceleration
			if dot < 0.2:
				var turn_factor := clampf((0.2 - dot) / 1.2, 0.0, 1.0)
				current_accel = lerpf(accel, turn_accel, turn_factor)
				
		velocity = velocity.move_toward(target, current_accel * delta)
	else:
		# Smooth underwater gliding drag
		velocity = velocity.move_toward(Vector2.ZERO, drag * delta)
		
	move_and_slide()
	_update_particles_and_surface()


func _update_particles_and_surface() -> void:
	var is_underwater := global_position.y > 0.0
	
	# Surface entry/exit splash detection
	if is_underwater != _was_underwater:
		_was_underwater = is_underwater
		if splash_particles != null:
			splash_particles.restart()
			splash_particles.emitting = true

	# Bubble trail emission control
	if bubble_particles != null:
		var is_moving := velocity.length() > 20.0
		bubble_particles.emitting = is_underwater and is_moving


func collect(data: PearlData) -> void:
	carried_count += 1
	carried_value += data.value
	carried_weight += data.carry_weight
	apply_upgrades()
	Events.carry_weight_changed.emit(carried_weight, GameState.weight_capacity)


func clear_carry() -> void:
	carried_count = 0
	carried_value = 0
	carried_weight = 0.0
	apply_upgrades()
	Events.carry_weight_changed.emit(carried_weight, GameState.weight_capacity)


func take_hit() -> void:
	if _animator != null:
		_animator.trigger_hurt()

