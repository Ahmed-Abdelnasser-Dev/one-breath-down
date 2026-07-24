extends Control
class_name ZoneBanner

@onready var label: Label = $Label

var _tween: Tween


func _ready() -> void:
	modulate.a = 0.0
	Events.zone_changed.connect(_on_zone_changed)


func _on_zone_changed(zone: ZoneData) -> void:
	if label == null or zone == null:
		return

	label.text = zone.display_name.to_upper()

	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_interval(1.5)
	_tween.tween_property(self, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
