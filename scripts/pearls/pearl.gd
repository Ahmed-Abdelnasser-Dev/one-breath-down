extends Area2D
class_name Pearl

@export var data: PearlData


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Diver:
		body.collect(data)
		queue_free()
