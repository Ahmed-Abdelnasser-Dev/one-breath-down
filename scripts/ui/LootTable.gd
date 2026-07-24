extends Control
class_name LootTable

@onready var rows_container: VBoxContainer = $MarginContainer/VBoxContainer/RowsContainer
@onready var run_value_label: Label = $MarginContainer/VBoxContainer/RunValueLabel
@onready var strain_indicator: Label = $MarginContainer/VBoxContainer/StrainIndicator

# Dictionary mapping PearlData -> { "count": int, "label": Label }
var _collected_types: Dictionary = {}
var _total_value: int = 0


func _ready() -> void:
	Events.pearl_collected.connect(_on_pearl_collected)
	Events.carry_weight_changed.connect(_on_carry_weight_changed)
	Events.run_started.connect(clear)
	Events.run_reset.connect(clear)
	clear()


func clear() -> void:
	_collected_types.clear()
	_total_value = 0
	if rows_container:
		for child in rows_container.get_children():
			child.queue_free()
	if run_value_label:
		run_value_label.text = "RUN VALUE: 0"
	if strain_indicator:
		strain_indicator.hide()


func _on_pearl_collected(data: PearlData) -> void:
	if data == null:
		return

	_total_value += data.value

	if _collected_types.has(data.id):
		_collected_types[data.id]["count"] += 1
	else:
		var row_label := Label.new()
		row_label.add_theme_font_size_override("font_size", 11)
		rows_container.add_child(row_label)
		_collected_types[data.id] = {
			"data": data,
			"count": 1,
			"label": row_label
		}

	_update_display()


func _on_carry_weight_changed(current: float, capacity: float) -> void:
	if strain_indicator != null:
		if current > capacity:
			strain_indicator.show()
			strain_indicator.text = "OVERBURDENED! (%.1f / %.1f kg)" % [current, capacity]
			strain_indicator.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2))
		else:
			strain_indicator.hide()


func _update_display() -> void:
	# Sort rows by pearl value ascending
	var items: Array = _collected_types.values()
	items.sort_custom(func(a, b): return a["data"].value < b["data"].value)

	for item in items:
		var data: PearlData = item["data"]
		var count: int = item["count"]
		var lbl: Label = item["label"]
		lbl.text = "%s x%d  (%d)" % [data.display_name, count, data.value * count]
		lbl.modulate = data.color

		# Keep order in container
		rows_container.move_child(lbl, rows_container.get_child_count() - 1)

	if run_value_label:
		run_value_label.text = "RUN VALUE: %d" % _total_value
