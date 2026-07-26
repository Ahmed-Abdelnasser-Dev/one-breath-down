extends Area2D
class_name Pearl

@export var data: PearlData

@onready var sprite: Sprite2D = $Sprite2D

static var _glow_texture: Texture2D = preload("res://visuals/lights/light_radial_stepped.tres")

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
