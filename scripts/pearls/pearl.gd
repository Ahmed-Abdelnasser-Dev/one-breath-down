extends Area2D
class_name Pearl

@export var data: PearlData

@onready var sprite: Sprite2D = $Sprite2D

var _base_y: float = 0.0
var _time_offset: float = 0.0


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
	var base_scale := 0.75
	var s := base_scale * (data.radius / 8.0)
	sprite.scale = Vector2(s, s)

	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col and col.shape is CircleShape2D:
		(col.shape as CircleShape2D).radius = maxf(6.0, data.radius * 0.75)


func _on_body_entered(body: Node2D) -> void:
	if body is Diver:
		body.collect(data)
		Events.pearl_collected.emit(data)
		queue_free()
