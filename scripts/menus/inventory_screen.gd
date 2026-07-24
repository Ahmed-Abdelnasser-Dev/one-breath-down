extends Control
## Display-only loadout shell: equip toggles are disabled since nothing is
## purchasable yet (shop is a display-only shell too, see shop_screen.gd).
## The loadout summary line reads real current stats off the diver/breath
## component rather than fabricated numbers, so it stays honest even before
## upgrades do anything.

signal closed

## name -> tradeoff note shown next to the (disabled) checkbox
const ITEMS: Array[Dictionary] = [
	{"name": "Fins", "note": "faster swim, less oxygen per metre"},
	{"name": "Lantern", "note": "visibility in deep zones"},
	{"name": "Weighted Belt", "note": "sink faster — harder to control ascent"},
	{"name": "Knife", "note": "escape nets instantly"},
]

@onready var run_manager: RunManager = get_parent().get_parent()
@onready var carry_weight_label: Label = $Panel/Margin/VBox/Header/CarryWeightLabel
@onready var items_list: VBoxContainer = $Panel/Margin/VBox/ItemsList
@onready var loadout_label: Label = $Panel/Margin/VBox/LoadoutLabel
@onready var close_button: Button = $Panel/Margin/VBox/CloseButton


func _ready() -> void:
	for item in ITEMS:
		items_list.add_child(_build_row(item["name"], item["note"]))
	close_button.pressed.connect(func() -> void: closed.emit())


func focus_default() -> void:
	_refresh()
	close_button.grab_focus()


func _refresh() -> void:
	carry_weight_label.text = "Carry weight %.2f" % run_manager.diver.carried_weight
	loadout_label.text = "Loadout effect:  Breath %ds   Swim %dpx/s" % [
		int(run_manager.breath.max_breath), int(run_manager.diver.max_speed)
	]


func _build_row(item_name: String, note: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var check := CheckButton.new()
	check.disabled = true
	row.add_child(check)
	var name_label := Label.new()
	name_label.text = item_name
	name_label.custom_minimum_size = Vector2(70, 0)
	row.add_child(name_label)
	var note_label := Label.new()
	note_label.text = "— " + note
	row.add_child(note_label)
	return row
