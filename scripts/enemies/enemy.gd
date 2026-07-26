extends CharacterBody2D
class_name Enemy
## Shared enemy base. Owns HP, hit reaction (knockback + stun + flash), contact
## damage against the diver, and death — the same "one script per behavior,
## coloured entirely from a Resource" pattern as Pearl/PearlData. The single
## override point for the four behavior subclasses (drifter_aura, patroller,
## charger, chaser) is _tick_behavior(); nothing else here should be overridden.

enum State { IDLE, PATROL, TELEGRAPH, ATTACK, RECOVER, HURT, DEAD }

const KNOCKBACK_DECAY := 1600.0   ## px/s^2 — how fast a knockback impulse bleeds off

@export var data: EnemyData

var hp: int = 0
var state: State = State.IDLE
var _state_time: float = 0.0
var _stun_time: float = 0.0
var _knockback: Vector2 = Vector2.ZERO
var _facing_right: bool = true
var _home: Vector2 = Vector2.ZERO   ## spawn anchor, captured once — never re-read as a live position source
var _diver: Diver

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var body_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
@onready var contact_hitbox: Area2D = get_node_or_null("ContactHitbox") as Area2D

static var _glow_texture: Texture2D = preload("res://visuals/lights/light_radial_stepped.tres")
var _glow: PointLight2D


func _ready() -> void:
	_home = global_position
	if data != null:
		_apply_data()
	_setup_glow()


## Faint self-light so a threat in Twilight/Midnight reads as a silhouette
## instead of an invisible hitbox. Scales with zone darkness — zero in Sunlit.
func _setup_glow() -> void:
	_glow = PointLight2D.new()
	_glow.texture = _glow_texture
	_glow.texture_scale = 0.6
	_glow.energy = 0.0
	add_child(_glow)
	Events.zone_changed.connect(func(_zone): _update_glow())
	_update_glow()


func _update_glow() -> void:
	if _glow == null:
		return
	var darkness := 0.0
	var zone := ZoneManager.get_current_zone()
	if zone != null:
		darkness = zone.darkness
	_glow.energy = darkness * 0.7


func setup(d: EnemyData) -> void:
	data = d
	_apply_data()


func _apply_data() -> void:
	if data == null:
		return

	hp = data.max_hp

	if sprite != null:
		sprite.sprite_frames = data.frames
		sprite.scale = Vector2(data.sprite_scale, data.sprite_scale)
		_play("idle")

	if body_shape != null and body_shape.shape is CircleShape2D:
		(body_shape.shape as CircleShape2D).radius = data.hitbox_radius

	if contact_hitbox != null:
		var shape_node := contact_hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node != null and shape_node.shape is CircleShape2D:
			(shape_node.shape as CircleShape2D).radius = data.hitbox_radius

	_update_facing()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	if _diver == null:
		_diver = get_tree().get_first_node_in_group("diver") as Diver
		if _diver == null:
			return

	_state_time += delta

	if _stun_time > 0.0:
		_stun_time -= delta
		velocity = Vector2.ZERO
		if _stun_time <= 0.0 and state == State.HURT:
			state = State.IDLE
	else:
		_tick_behavior(delta)

	velocity += _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)

	move_and_slide()
	_update_facing()
	_tick_contact_damage()


## Override point for the 4 behavior subclasses. A bare Enemy with no
## subclass just sits still (and can still be attacked/killed) — useful for
## quick hand-placed testing.
func _tick_behavior(_delta: float) -> void:
	pass


func _update_facing() -> void:
	if sprite == null or data == null:
		return
	sprite.flip_h = _facing_right if data.faces_left else not _facing_right


func _dist_to_diver() -> float:
	if _diver == null:
		return INF
	return global_position.distance_to(_diver.global_position)


func _dir_to_diver() -> Vector2:
	if _diver == null:
		return Vector2.ZERO
	var d := _diver.global_position - global_position
	if d.length() < 0.001:
		return Vector2.ZERO
	return d.normalized()


## Called by the diver's swing hitbox. Sharks (data.invulnerable) flash and
## stun but never lose HP or die.
func take_damage(amount: int, from: Vector2) -> void:
	if state == State.DEAD or data == null:
		return

	var away := global_position - from
	if away.length() > 0.001:
		_knockback = away.normalized() * data.hit_knockback_speed

	if data.invulnerable:
		_stun_time = maxf(_stun_time, 1.0)
		_flash()
		return

	_stun_time = maxf(_stun_time, data.stun_on_hit)
	hp -= amount
	Events.enemy_damaged.emit(data.id, amount)

	if hp <= 0:
		_die()
	else:
		_enter_hurt()


func _enter_hurt() -> void:
	state = State.HURT
	_play("hurt")
	_flash()


func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO

	if contact_hitbox != null:
		contact_hitbox.set_deferred("monitoring", false)
	if body_shape != null:
		body_shape.set_deferred("disabled", true)
	if data != null:
		Events.enemy_killed.emit(data.id, global_position)

	if _glow != null:
		_glow.energy = 0.0

	# A kill used to be an instant queue_free() with no acknowledgement at all.
	# Flash white, then sink and fade so the body reads as a body. Species that
	# ship a death animation still play it underneath (sharks don't have one).
	if sprite != null:
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("death"):
			_play("death")
		sprite.modulate = Color(3.0, 3.0, 3.0, 1.0)
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color(0.7, 0.8, 1.0, 1.0), 0.09)
		tween.set_parallel(true)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.45).set_delay(0.09)
		tween.tween_property(self, "position:y", position.y + 26.0, 0.54) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_property(sprite, "rotation", sprite.rotation + 0.7, 0.54)
		tween.chain().tween_callback(queue_free)
	else:
		queue_free()


func _flash() -> void:
	if sprite == null:
		return
	sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)


## Wrapper so species missing an animation (sharks have no hurt/death) never
## spam "Animation not found" every frame that animation is requested.
func _play(anim_name: StringName) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)


func _tick_contact_damage() -> void:
	if data == null or data.contact_damage <= 0 or contact_hitbox == null:
		return
	if data.contact_damage_requires_attack and state != State.ATTACK:
		return
	for body in contact_hitbox.get_overlapping_bodies():
		if body is Diver:
			body.take_hit(data.contact_damage, global_position, data.player_knockback)
