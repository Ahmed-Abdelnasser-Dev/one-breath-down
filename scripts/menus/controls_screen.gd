extends Control
## Lists the game's key bindings, read live from InputMap rather than
## hardcoded strings, so this screen can't drift out of date with the
## actual bindings in project.godot.

signal closed

## action name -> friendly label
const DISPLAY_ACTIONS: Array = [
	["move_up", "Swim Up"],
	["move_down", "Swim Down"],
	["move_left", "Swim Left"],
	["move_right", "Swim Right"],
	["open_shop", "Open Shop"],
	["open_inventory", "Open Inventory"],
	["pause", "Pause"],
]

@onready var actions_list: VBoxContainer = $Panel/Margin/VBox/Scroll/ActionsList
@onready var back_button: Button = $Panel/Margin/VBox/BackButton


func _ready() -> void:
	for entry in DISPLAY_ACTIONS:
		actions_list.add_child(_build_row(entry[0], entry[1]))
	back_button.pressed.connect(func() -> void: closed.emit())


func focus_default() -> void:
	back_button.grab_focus()


func _build_row(action: StringName, label: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = label
	name_label.custom_minimum_size = Vector2(110, 0)
	row.add_child(name_label)
	var key_label := Label.new()
	key_label.text = _bound_key_text(action)
	row.add_child(key_label)
	return row


func _bound_key_text(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event.as_text_physical_keycode()
	return "-"
