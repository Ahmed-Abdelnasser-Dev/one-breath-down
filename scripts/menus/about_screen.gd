extends Control
## Static pitch/flavor screen. No logic beyond wiring the Back button.

signal closed

@onready var back_button: Button = $Panel/Margin/VBox/BackButton


func _ready() -> void:
	back_button.pressed.connect(func() -> void: closed.emit())


func focus_default() -> void:
	back_button.grab_focus()
