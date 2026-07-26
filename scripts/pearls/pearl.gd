extends Area2D
class_name Pearl

@export var data: PearlData

@onready var sprite: Sprite2D = $Sprite2D

static var _glow_texture: Texture2D = preload("res://visuals/lights/light_radial_stepped.tres")
static var _pop_texture: Texture2D = preload("res://visuals/water particle effectd/proj_bubblebeam3_end_sheet.png")

var _base_y: float = 0.0
var _time_offset: float = 0.0
var _glow: PointLight2D


func _ready() -> void:
	if data == null:
		data = preload("res://data/pearls/seed_pearl.tres")

	_base_y = position.y
	_time_offset = randf() * TAU

	_apply_data()
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time_offset += delta * 2.5
	position.y = _base_y + sin(_time_offset) * 4.0


## A puff of bubbles where the pearl was. Reparented to the pearl's container so
## it outlives the pearl — the pearl frees itself a fraction of a second later.
func _burst_bubbles() -> void:
	var host := get_parent()
	if host == null:
		return

	var puff := GPUParticles2D.new()
	puff.texture = _pop_texture
	puff.texture_filter = TEXTURE_FILTER_NEAREST
	puff.amount = 10
	puff.lifetime = 0.7
	puff.one_shot = true
	puff.explosiveness = 0.95
	puff.global_position = global_position

	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.particles_animation = true
	mat.particles_anim_h_frames = 3
	mat.particles_anim_v_frames = 1
	mat.particles_anim_loop = false
	puff.material = mat

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 5.0
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 55.0
	pm.initial_velocity_min = 24.0
	pm.initial_velocity_max = 62.0
	pm.gravity = Vector3(0, -40, 0)
	pm.scale_min = 0.35
	pm.scale_max = 0.75
	pm.color = data.color if data != null else Color.WHITE
	puff.process_material = pm

	host.add_child(puff)
	puff.emitting = true
	puff.finished.connect(puff.queue_free, CONNECT_ONE_SHOT)


func setup(pearl_data: PearlData) -> void:
	data = pearl_data
	_apply_data()


func _apply_data() -> void:
	if data == null or sprite == null:
		return

	if data.sprite != null:
		sprite.texture = data.sprite
	else:
		sprite.texture = preload("res://visuals/hud/icon_pearl.tres")

	sprite.modulate = data.color

	# Scale pearls appropriately relative to the player diver (~32px)
	var base_scale := 1.1
	var s := base_scale * (data.radius / 8.0)
	sprite.scale = Vector2(s, s)

	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col and col.shape is CircleShape2D:
		(col.shape as CircleShape2D).radius = maxf(6.0, data.radius * 0.75)

	# Soft rarity-tinted glow — the one thing that must stay findable in the
	# dark IS the treasure. Richer pearls glow brighter (golden reads at range).
	if _glow == null:
		_glow = PointLight2D.new()
		_glow.texture = _glow_texture
		add_child(_glow)
	_glow.color = data.color
	_glow.texture_scale = 0.45
	_glow.energy = clampf(0.25 + float(data.value) / 350.0 * 0.55, 0.25, 0.8)


var _collected := false


## The most-repeated action in the game used to be a same-frame queue_free() —
## the pearl simply vanished. It now pops, flares and drifts up before it goes,
## so picking one up registers as an event.
func _on_body_entered(body: Node2D) -> void:
	if _collected or not (body is Diver):
		return
	_collected = true

	body.collect(data)
	Events.pearl_collected.emit(data)

	set_deferred("monitoring", false)
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col != null:
		col.set_deferred("disabled", true)
	set_process(false)
	_burst_bubbles()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", sprite.scale * 2.1, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y - 22.0, 0.26) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.26).set_delay(0.06)
	if _glow != null:
		tween.tween_property(_glow, "energy", _glow.energy * 2.6, 0.10)
		tween.tween_property(_glow, "energy", 0.0, 0.18).set_delay(0.10)
	tween.chain().tween_callback(queue_free)
