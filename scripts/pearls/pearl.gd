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
	
	if sprite and data:
		sprite.modulate = data.color
		
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time_offset += delta * 2.5
	position.y = _base_y + sin(_time_offset) * 3.0


func setup(pearl_data: PearlData) -> void:
	data = pearl_data
	if is_node_ready() and sprite and data:
		sprite.modulate = data.color


func _on_body_entered(body: Node2D) -> void:
	if body is Diver:
		body.collect(data)
		Events.pearl_collected.emit(data)
		queue_free()
