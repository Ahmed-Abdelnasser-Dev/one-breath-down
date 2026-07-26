extends CharacterBody2D
class_name Diver
## Swim movement. Momentum-based underwater physics: accelerates smoothly toward
## input direction, glides (drag) when input is released, and uses fluid turn
## responsiveness when switching directions to prevent snappy vector flips.

const SPEED_PENALTY_PER_UNIT := 0.18
const ATTACK_DAMAGE := 25
const ATTACK_REACH := 28.0     ## px offset of the hitbox from the diver's centre
const SWING_DURATION := 0.25   ## seconds a swing lasts, start to finish
const DAMAGE_WINDOW := 0.15    ## the tail of the swing during which damage lands
## The slash FX plays over its own, longer clock rather than the swing's: the
## diver's attack animation is 6 frames at 12fps (0.5s), so driving 16 sheet
## frames off the 0.25s swing made the slash finish while the arm was still
## moving. Damage timing is unchanged — only the visual was too fast.
const SLASH_FX_DURATION := 0.5

@export var base_max_speed: float = 160.0   ## = 5 m/s at PIXELS_PER_METRE 32; see docs/phase_2.md §7
@export var accel: float = 540.0            ## Forward swimming acceleration
@export var turn_accel: float = 850.0       ## Turn responsiveness acceleration when reversing direction
@export var drag: float = 400.0             ## Underwater gliding deceleration when input is released

var max_speed: float = 160.0
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

const KNOCK_LOCK_TIME := 0.16   ## seconds steering is ignored after taking a hit
var _knock_lock: float = 0.0
var _slash_time: float = 0.0

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
	var target_energy := darkness * (1.7 if has_lantern else 1.0)
	var target_scale := 1.9 if has_lantern else 1.1
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(dive_light, "energy", target_energy, 0.8)
	tween.tween_property(dive_light, "texture_scale", target_scale, 0.8)


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# While knocked back, steering is ignored and the impulse is allowed to
	# carry — otherwise a held direction cancels the hit within a few frames.
	if _knock_lock > 0.0:
		_knock_lock -= delta
		input_dir = Vector2.ZERO

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
		# Smooth underwater gliding drag — much gentler while knocked back so
		# the impulse actually travels before it bleeds off.
		var glide_drag := drag * (0.25 if _knock_lock > 0.0 else 1.0)
		velocity = velocity.move_toward(Vector2.ZERO, glide_drag * delta)

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
		_swing_time = SWING_DURATION
		_hit_this_swing.clear()

		if attack_hitbox != null:
			# Aim the hitbox NOW, not when the damage window opens. It used to be
			# assigned inside the damage branch below, so for the first ~0.1s the
			# slash was drawn at the previous swing's angle and then teleported.
			attack_hitbox.position = _aim_dir * ATTACK_REACH
			var slash := attack_hitbox.get_node_or_null("SlashVisual") as Sprite2D
			if slash != null:
				slash.visible = true
				slash.frame = 0
				slash.rotation = _aim_dir.angle()
				slash.modulate.a = 0.95
				_slash_time = 0.0

	if _swing_time > 0.0:
		_swing_time -= delta
		if attack_hitbox != null and _swing_time < DAMAGE_WINDOW: # damage lands mid-swing
			for body in attack_hitbox.get_overlapping_bodies():
				if body is Enemy and not _hit_this_swing.has(body.get_instance_id()):
					_hit_this_swing.append(body.get_instance_id())
					body.take_damage(ATTACK_DAMAGE, global_position)

	# The FX runs on its own clock so it can outlast the damage window and stay
	# in step with the diver's attack animation.
	if attack_hitbox != null:
		var slash := attack_hitbox.get_node_or_null("SlashVisual") as Sprite2D
		if slash != null and slash.visible:
			_slash_time += delta
			var played: float = _slash_time / SLASH_FX_DURATION
			if played >= 1.0:
				slash.visible = false
			else:
				slash.frame = clampi(int(played * slash.hframes), 0, slash.hframes - 1)
				slash.modulate.a = 0.95 * clampf(1.0 - maxf(played - 0.6, 0.0) / 0.4, 0.0, 1.0)


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
		Sfx.play(&"splash", 0.1)

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
		# Briefly refuse steering input. Without this the knockback is erased on
		# the very next physics tick by move_toward() if the player happens to be
		# holding a direction, and the hit never registers as a physical event.
		_knock_lock = KNOCK_LOCK_TIME

	if _animator != null:
		_animator.trigger_hurt()

	# Drives screen shake / hitstop via the Juice autoload. This signal was
	# declared on the Events bus but never actually emitted by anything.
	Events.player_damaged.emit(amount, &"contact")
