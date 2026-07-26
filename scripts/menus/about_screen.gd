extends Control
## Static pitch/flavor screen. No logic beyond wiring the Back button.

signal closed

@onready var back_button: Button = $Panel/Margin/VBox/BackButton


func _ready() -> void:
	back_button.pressed.connect(func() -> void: closed.emit())


func focus_default() -> void:
	back_button.grab_focus()


## Esc backs out of this screen. Handled here and marked consumed so it works
## identically from the main menu (whose own handler sits on a parent node) and
## from the in-game MenuManager stack, without both of them popping at once.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
