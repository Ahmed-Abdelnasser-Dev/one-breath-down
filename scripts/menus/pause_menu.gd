extends Control
## Resume / Options / Main Menu / Exit Game. Options is pushed as a further
## MenuManager stack entry (not swapped in-place) so Esc from Options
## returns here rather than closing everything in one step (hud_ui.md §7.1).

signal closed

@onready var resume_button: Button = $Panel/Margin/VBox/ResumeButton
@onready var options_button: Button = $Panel/Margin/VBox/OptionsButton
@onready var main_menu_button: Button = $Panel/Margin/VBox/MainMenuButton
@onready var exit_button: Button = $Panel/Margin/VBox/ExitButton

@onready var menu_manager: Node = $"../MenuManager"
@onready var options_screen: Control = $"../OptionsScreen"


func _ready() -> void:
	resume_button.pressed.connect(func() -> void: closed.emit())
	options_button.pressed.connect(func() -> void: menu_manager.push(options_screen))
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	exit_button.pressed.connect(func() -> void: get_tree().quit())


func focus_default() -> void:
	resume_button.grab_focus()


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
