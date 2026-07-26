extends Control
## Loadout screen. Two jobs: show what the passive upgrades are doing, and let
## the player assign bought consumables to the X and C slots.
##
## This screen was previously read-only and advertised gear that didn't exist.
## The consumable rows are the reason it has a purpose now: buying puts an item
## in your stock, and this is where you decide which two kinds you dive with.

signal closed

## prefix -> display name, plus the per-level effect summary. Mirrors the real
## upgrade families in shop_screen.gd's CATALOG so it can't advertise
## unimplemented gear.
const ITEMS: Array[Dictionary] = [
	{"prefix": "lungs_", "name": "Lungs", "levels": ["50s breath", "75s breath", "100s breath"]},
	{"prefix": "fins_", "name": "Fins", "levels": ["base speed", "+20% speed, less air", "+40% speed, least air"]},
	{"prefix": "basket_", "name": "Basket", "levels": ["3.0kg carry", "4.5kg carry", "6.0kg carry"]},
	{"prefix": "lantern_", "name": "Lantern", "levels": ["no lamp, midnight is blind", "bright lamp"]},
	{"prefix": "wetsuit_", "name": "Wetsuit", "levels": ["100 health", "130 health", "160 health"]},
	{"prefix": "vigor_", "name": "Vigor", "levels": ["100 stamina", "130 stamina", "160 stamina"]},
]

@onready var run_manager: RunManager = get_parent().get_parent()
@onready var carry_weight_label: Label = $Panel/Margin/VBox/Header/CarryWeightLabel
@onready var items_list: VBoxContainer = $Panel/Margin/VBox/ItemsList
@onready var loadout_label: Label = $Panel/Margin/VBox/LoadoutLabel
@onready var close_button: Button = $Panel/Margin/VBox/CloseButton

var _rows: Array[Dictionary] = []
var _consumable_rows: Array[Dictionary] = []
var _slot_labels: Array[Label] = []


func _ready() -> void:
	for item in ITEMS:
		var built := _build_row(item)
		items_list.add_child(built["row"])
		_rows.append({"prefix": item["prefix"], "item": item,
			"check": built["check"], "note": built["note"]})

	_build_consumable_section()
	close_button.pressed.connect(func() -> void: closed.emit())
	Events.consumables_changed.connect(_refresh)


func focus_default() -> void:
	_refresh()
	close_button.grab_focus()


## Divider plus one row per consumable: icon, name, stock, and two buttons that
## bind it to a slot. Buttons rather than a drag interaction because this has to
## work on the keyboard.
func _build_consumable_section() -> void:
	var sep := HSeparator.new()
	items_list.add_child(sep)

	var header := Label.new()
	header.text = "CONSUMABLES   (two kinds max, three charges each)"
	header.add_theme_font_size_override("font_size", 8)
	header.add_theme_color_override("font_color", Color(1, 0.88, 0.4))
	items_list.add_child(header)

	for c in Consumables.all():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var icon := TextureRect.new()
		icon.texture = c.icon
		icon.custom_minimum_size = Vector2(12, 12)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)

		var name_label := Label.new()
		name_label.text = c.display_name
		name_label.custom_minimum_size = Vector2(84, 0)
		name_label.add_theme_font_size_override("font_size", 8)
		row.add_child(name_label)

		var stock := Label.new()
		stock.custom_minimum_size = Vector2(26, 0)
		stock.add_theme_font_size_override("font_size", 8)
		row.add_child(stock)

		var slot_buttons: Array[Button] = []
		for slot in GameState.CONSUMABLE_SLOTS:
			var b := Button.new()
			b.text = _slot_key(slot)
			b.custom_minimum_size = Vector2(18, 0)
			b.add_theme_font_size_override("font_size", 8)
			var id := c.id
			var s := slot
			b.pressed.connect(func() -> void: _on_slot_pressed(s, id))
			row.add_child(b)
			slot_buttons.append(b)

		items_list.add_child(row)
		_consumable_rows.append({"data": c, "stock": stock, "buttons": slot_buttons,
			"name": name_label})


## Pressing the slot button of an already-equipped item unequips it, so one
## button does both and nothing needs a separate "clear" control.
func _on_slot_pressed(slot: int, id: StringName) -> void:
	if GameState.equipped[slot] == id:
		GameState.clear_slot(slot)
	else:
		GameState.equip_consumable(slot, id)
	_refresh()


func _slot_key(slot: int) -> String:
	var action := &"use_slot_1" if slot == 0 else &"use_slot_2"
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return (event as InputEventKey).as_text_physical_keycode()
	return str(slot + 1)


func _refresh() -> void:
	carry_weight_label.text = "Carry %.2f / %.1f kg" % [
		run_manager.diver.carried_weight, GameState.weight_capacity
	]

	for entry in _rows:
		var level: int = GameState.get_upgrade_level(entry["prefix"])
		if entry["prefix"] == "lantern_":
			level = 1 if GameState.has_upgrade(&"lantern_1") else 0
		var levels: Array = entry["item"]["levels"]
		var idx: int = clampi(level, 0, levels.size() - 1)
		var check: CheckButton = entry["check"]
		var note: Label = entry["note"]
		check.button_pressed = level > 0
		note.text = "> " + str(levels[idx])
		note.modulate = Color(1, 1, 1) if level > 0 else Color(0.55, 0.6, 0.68)

	for row in _consumable_rows:
		var c := row["data"] as ConsumableData
		var held := GameState.consumable_count(c.id)
		var stock_label := row["stock"] as Label
		stock_label.text = "x%d" % held
		stock_label.modulate = Color(1, 1, 1) if held > 0 else Color(0.5, 0.55, 0.62)
		(row["name"] as Label).modulate = Color(1, 1, 1) if held > 0 else Color(0.55, 0.6, 0.68)
		var buttons: Array = row["buttons"]
		for slot in buttons.size():
			var b := buttons[slot] as Button
			var mine: bool = GameState.equipped[slot] == c.id
			b.disabled = held <= 0 and not mine
			b.modulate = Color(0.45, 1.0, 0.55) if mine else Color.WHITE

	var speed_ms := run_manager.diver.max_speed / GameState.PIXELS_PER_METRE
	loadout_label.text = "Breath %ds     Swim %.1f m/s     Slots: %s" % [
		int(run_manager.breath.max_breath), speed_ms, _slot_summary()
	]


func _slot_summary() -> String:
	var parts: PackedStringArray = []
	for slot in GameState.CONSUMABLE_SLOTS:
		var id: StringName = GameState.equipped[slot]
		var c := Consumables.get_by_id(id) if id != &"" else null
		parts.append("%s=%s" % [_slot_key(slot), c.display_name if c else "empty"])
	return "  ".join(parts)


func _build_row(item: Dictionary) -> Dictionary:
	var row := HBoxContainer.new()
	var check := CheckButton.new()
	check.disabled = true
	row.add_child(check)
	var name_label := Label.new()
	name_label.text = item["name"]
	name_label.custom_minimum_size = Vector2(62, 0)
	row.add_child(name_label)
	var note_label := Label.new()
	row.add_child(note_label)
	return {"row": row, "check": check, "note": note_label}
