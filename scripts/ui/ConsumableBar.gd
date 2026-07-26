extends HBoxContainer
class_name ConsumableBar
## The two consumable slots, drawn bottom-left with their trigger key on them.
##
## Slots are built in code because they're a fixed pair of identical widgets and
## the key label has to come from the InputMap rather than being typed into the
## scene — rebinding X or C should relabel the HUD, not lie about it.

const SLOT_ACTIONS: Array[StringName] = [&"use_slot_1", &"use_slot_2"]
const EMPTY_TINT := Color(1, 1, 1, 0.22)

var _icons: Array[TextureRect] = []
var _counts: Array[Label] = []
var _panels: Array[PanelContainer] = []


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	for i in GameState.CONSUMABLE_SLOTS:
		_build_slot(i)
	Events.consumables_changed.connect(refresh)
	Events.consumable_used.connect(func(_id: StringName, _at: Vector2) -> void: refresh())
	refresh()


func _build_slot(index: int) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.09, 0.16, 0.78)
	style.border_color = Color(0.35, 0.55, 0.75, 0.9)
	style.set_border_width_all(1)
	style.set_content_margin_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	panel.add_child(row)

	# Key cap: reads the real binding so it can't drift from the InputMap.
	var key := Label.new()
	key.text = _key_text(SLOT_ACTIONS[index])
	key.add_theme_font_size_override("font_size", 8)
	key.add_theme_color_override("font_color", Color(1, 0.88, 0.4))
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(key)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(14, 14)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(icon)

	var count := Label.new()
	count.add_theme_font_size_override("font_size", 8)
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(count)

	add_child(panel)
	_panels.append(panel)
	_icons.append(icon)
	_counts.append(count)


func refresh() -> void:
	for i in _panels.size():
		var id: StringName = GameState.equipped[i] if i < GameState.equipped.size() else &""
		var data := Consumables.get_by_id(id) if id != &"" else null
		var charges := GameState.consumable_count(id) if id != &"" else 0

		if data == null:
			_icons[i].texture = null
			_counts[i].text = "--"
			_counts[i].add_theme_color_override("font_color", EMPTY_TINT)
			_panels[i].modulate = Color(1, 1, 1, 0.55)
			continue

		_icons[i].texture = data.icon
		_counts[i].text = "x%d" % charges
		# Dry slots stay visible but greyed: the player should still see what's
		# equipped so they know what to re-buy.
		var dry := charges <= 0
		_icons[i].modulate = EMPTY_TINT if dry else Color.WHITE
		_counts[i].add_theme_color_override("font_color",
			EMPTY_TINT if dry else Color(0.9, 0.95, 1.0))
		_panels[i].modulate = Color(1, 1, 1, 0.6) if dry else Color.WHITE


func _key_text(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return (event as InputEventKey).as_text_physical_keycode()
	return "?"
