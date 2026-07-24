extends Control
## Launch screen. Start loads the dive scene; Options/Controls/Credits/About
## are the same reusable overlay screens the in-game pause menu uses.

@onready var buttons_panel: Panel = $ButtonsPanel
@onready var start_button: Button = $ButtonsPanel/Margin/VBox/StartButton
@onready var options_button: Button = $ButtonsPanel/Margin/VBox/OptionsButton
@onready var controls_button: Button = $ButtonsPanel/Margin/VBox/ControlsButton
@onready var credits_button: Button = $ButtonsPanel/Margin/VBox/CreditsButton
@onready var about_button: Button = $ButtonsPanel/Margin/VBox/AboutButton
@onready var exit_button: Button = $ButtonsPanel/Margin/VBox/ExitButton

@onready var options_screen: Control = $OptionsScreen
@onready var controls_screen: Control = $ControlsScreen
@onready var about_screen: Control = $AboutScreen
@onready var credits_screen: Control = $CreditsScreen

var _overlays: Array[Control] = []


func _ready() -> void:
	_overlays = [options_screen, controls_screen, about_screen, credits_screen]
	for overlay in _overlays:
		overlay.hide()
		overlay.closed.connect(_show_main_buttons)

	start_button.pressed.connect(_on_start_pressed)
	options_button.pressed.connect(func() -> void: _show_overlay(options_screen))
	controls_button.pressed.connect(func() -> void: _show_overlay(controls_screen))
	credits_button.pressed.connect(func() -> void: _show_overlay(credits_screen))
	about_button.pressed.connect(func() -> void: _show_overlay(about_screen))
	exit_button.pressed.connect(func() -> void: get_tree().quit())

	start_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	for overlay in _overlays:
		if overlay.visible:
			_show_main_buttons()
			get_viewport().set_input_as_handled()
			return


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _show_overlay(overlay: Control) -> void:
	buttons_panel.hide()
	overlay.show()
	overlay.focus_default()


func _show_main_buttons() -> void:
	for overlay in _overlays:
		overlay.hide()
	buttons_panel.show()
	start_button.grab_focus()
