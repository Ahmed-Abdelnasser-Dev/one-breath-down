extends CharacterBody2D
class_name Diver
## Swim movement. Momentum-based underwater physics: accelerates smoothly toward
## input direction, glides (drag) when input is released, and uses fluid turn
## responsiveness when switching directions to prevent snappy vector flips.

const SPEED_PENALTY_PER_UNIT := 0.18
const ATTACK_DAMAGE := 25
const ATTACK_REACH := 28.0     ## px offset of the hitbox from the diver's centre
const ATTACK_DURATION := 0.15  ## seconds the hitbox is live per swing

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
var _health: HealthComponent
var _stamina: StaminaComponent
var _was_underwater: bool = false

var _aim_dir: Vector2 = Vector2.RIGHT
var _swing_time: float = 0.0
var _hit_this_swing: Array[int] = []

@onready var camera: Camera2D = get_node_or_null("Camera2D") as Camera2D
@onready var bubble_particles: GPUParticles2D = get_node_or_null("BubbleTrail") as GPUParticles2D
@onready var splash_particles: GPUParticles2D = get_node_or_null("SplashParticles") as GPUParticles2D
@onready var attack_hitbox: Area2D = get_node_or_null("AttackHitbox") as Area2D
@onready var dive_light: PointLight2D = get_node_or_null("DiveLight") as PointLight2D


func _ready() -> void:
	add_to_group("diver")
	_animator = get_node_or_null("AnimatedSprite2D") as DiverAnimator
	_health = get_node_or_null("HealthComponent") as HealthComponent
	_stamina = get_node_or_null("StaminaComponent") as StaminaComponent
	_was_underwater = global_position.y > 0.0

	if camera != null:
		camera.limit_left = 0
		camera.limit_right = 1600
		camera.limit_bottom = 6400

	Events.run_started.connect(apply_upgrades)
	Events.run_reset.connect(apply_upgrades)
	Events.upgrade_purchased.connect(func(_id): apply_upgrades())
	Events.zone_changed.connect(func(_zone): _update_light())
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
	_update_light()


## The halo earns its keep only where it's dark: energy scales with the
## current zone's darkness (0 in Sunlit, so no daylight glow ring). The
## lantern upgrade is what the shop always claimed it was — a wider,
## brighter radius.
func _update_light() -> void:
	if dive_light == null:
		return
	var darkness := 0.0
	if ZoneManager.instance != null and ZoneManager.instance.current_zone != null:
		darkness = ZoneManager.instance.current_zone.darkness
	var has_lantern := GameState.has_upgrade("lantern_1")
	var target_energy := darkness * (1.8 if has_lantern else 1.1)
	var target_scale := 2.8 if has_lantern else 1.6
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(dive_light, "energy", target_energy, 0.8)
	tween.tween_property(dive_light, "texture_scale", target_scale, 0.8)


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		_aim_dir = input_dir   # movement input takes priority as the aim direction
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
	_update_attack(delta)


func _update_attack(delta: float) -> void:
	if Input.is_action_just_pressed("attack") and _swing_time <= 0.0 and _stamina != null and _stamina.can_spend():
		_stamina.spend()

		# No movement input held: fall back to the sprite's current facing.
		if input_dir_is_zero():
			_aim_dir = Vector2.RIGHT if (_animator == null or _animator.is_facing_right()) else Vector2.LEFT

		if _animator != null:
			_animator.trigger_attack()

		Events.player_attacked.emit()
		_swing_time = 0.25 # Increased duration for sync
		_hit_this_swing.clear()
		
		if attack_hitbox != null:
			var slash = attack_hitbox.get_node_or_null("SlashVisual")
			if slash:
				slash.visible = true
				slash.modulate.a = 1.0
				slash.scale = Vector2(0.3, 0.3)
				var tw = create_tween()
				tw.tween_property(slash, "scale", Vector2(1.8, 1.8), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				tw.parallel().tween_property(slash, "modulate:a", 0.0, 0.2)
				tw.tween_callback(func(): slash.visible = false)

	if _swing_time > 0.0:
		_swing_time -= delta
		if attack_hitbox != null and _swing_time < 0.15: # Sync damage to middle of swing
			attack_hitbox.position = _aim_dir * ATTACK_REACH
			for body in attack_hitbox.get_overlapping_bodies():
				if body is Enemy and not _hit_this_swing.has(body.get_instance_id()):
					_hit_this_swing.append(body.get_instance_id())
					body.take_damage(ATTACK_DAMAGE, global_position)


func input_dir_is_zero() -> bool:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down") == Vector2.ZERO


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


## Called by an enemy's contact hitbox (or aura) every physics tick it
## overlaps the diver. Safe to call repeatedly — HealthComponent's i-frame
## gate makes this idempotent for the duration of the invulnerability window,
## so callers never need their own per-target cooldown bookkeeping.
func take_hit(amount: int, from: Vector2, knock: float) -> void:
	if _health == null or not _health.can_be_hit():
		return

	_health.apply_damage(amount)

	var away := global_position - from
	if away.length() > 0.001:
		velocity += away.normalized() * knock

	if _animator != null:
		_animator.trigger_hurt()

