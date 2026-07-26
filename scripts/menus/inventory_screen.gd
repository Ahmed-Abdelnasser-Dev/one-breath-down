extends Control
## Read-only loadout summary: what you own and what it's doing for you.
##
## Rows mirror the real upgrade families in shop_screen.gd's CATALOG and read
## their state from GameState, so this can't drift into advertising gear that
## doesn't exist — it previously listed a Weighted Belt and a Knife, neither of
## which is implemented anywhere in the project.

signal closed

## prefix -> display name, plus the per-level effect summary.
const ITEMS: Array[Dictionary] = [
	{"prefix": "lungs_", "name": "Lungs", "levels": ["50s breath", "75s breath", "100s breath"]},
	{"prefix": "fins_", "name": "Fins", "levels": ["base speed", "+20% speed, less air", "+40% speed, least air"]},
	{"prefix": "basket_", "name": "Basket", "levels": ["3.0kg carry", "4.5kg carry", "6.0kg carry"]},
	{"prefix": "lantern_", "name": "Lantern", "levels": ["no lamp — midnight is blind", "bright lamp"]},
	{"prefix": "wetsuit_", "name": "Wetsuit", "levels": ["100 health", "130 health", "160 health"]},
	{"prefix": "vigor_", "name": "Vigor", "levels": ["100 stamina", "130 stamina", "160 stamina"]},
]

@onready var run_manager: RunManager = get_parent().get_parent()
@onready var carry_weight_label: Label = $Panel/Margin/VBox/Header/CarryWeightLabel
@onready var items_list: VBoxContainer = $Panel/Margin/VBox/ItemsList
@onready var loadout_label: Label = $Panel/Margin/VBox/LoadoutLabel
@onready var close_button: Button = $Panel/Margin/VBox/CloseButton

var _rows: Array[Dictionary] = []


func _ready() -> void:
	for item in ITEMS:
		var built := _build_row(item)
		items_list.add_child(built["row"])
		_rows.append({"prefix": item["prefix"], "item": item,
			"check": built["check"], "note": built["note"]})
	close_button.pressed.connect(func() -> void: closed.emit())


func focus_default() -> void:
	_refresh()
	close_button.grab_focus()


func _refresh() -> void:
	carry_weight_label.text = "Carry %.2f / %.1f kg" % [
		run_manager.diver.carried_weight, GameState.weight_capacity
	]

	for entry in _rows:
		var level: int = GameState.get_upgrade_level(entry["prefix"])
		# lantern_1 has no numeric tiers beyond owned/not owned.
		if entry["prefix"] == "lantern_":
			level = 1 if GameState.has_upgrade(&"lantern_1") else 0
		var levels: Array = entry["item"]["levels"]
		var idx: int = clampi(level, 0, levels.size() - 1)
		var check: CheckButton = entry["check"]
		var note: Label = entry["note"]
		check.button_pressed = level > 0
		note.text = "— " + str(levels[idx])
		note.modulate = Color(1, 1, 1) if level > 0 else Color(0.55, 0.6, 0.68)

	# Metres per second, not engine pixels — this used to print "Swim 224px/s".
	var speed_ms := run_manager.diver.max_speed / GameState.PIXELS_PER_METRE
	loadout_label.text = "Breath %ds     Swim %.1f m/s" % [
		int(run_manager.breath.max_breath), speed_ms
	]


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
