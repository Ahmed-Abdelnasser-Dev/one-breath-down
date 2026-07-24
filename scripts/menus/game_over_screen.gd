extends Control
## Delayed darken + game-over panel on drown/death, replacing the old silent
## auto-reset: the player sees what they lost before choosing to go again.
## Not part of MenuManager's push/pop stack (it's driven by Events.player_died,
## not by input) — MenuManager instead checks this screen's own `visible` and
## refuses to open pause/shop/inventory over it.

const DARKEN_DURATION := 1.0
const PANEL_DELAY := 0.3
const PANEL_FADE_DURATION := 0.4

@onready var run_manager: RunManager = get_parent().get_parent()
@onready var darken: ColorRect = $Darken
@onready var panel: PanelContainer = $Panel
@onready var lost_label: Label = $Panel/Margin/VBox/LostLabel
@onready var new_run_button: Button = $Panel/Margin/VBox/NewRunButton
@onready var exit_button: Button = $Panel/Margin/VBox/ExitButton


func _ready() -> void:
	hide()
	darken.color.a = 0.0
	panel.hide()
	panel.modulate.a = 0.0

	Events.player_died.connect(_on_player_died)
	new_run_button.pressed.connect(_on_new_run_pressed)
	exit_button.pressed.connect(func() -> void: get_tree().quit())


func _on_player_died(_cause: String) -> void:
	lost_label.text = "%d pearls lost" % run_manager.diver.carried_value
	show()
	get_tree().paused = true

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(darken, "color:a", 0.85, DARKEN_DURATION)
	tween.tween_interval(PANEL_DELAY)
	tween.tween_callback(_reveal_panel)
	tween.tween_property(panel, "modulate:a", 1.0, PANEL_FADE_DURATION)


func _reveal_panel() -> void:
	panel.show()
	new_run_button.grab_focus()


func _on_new_run_pressed() -> void:
	hide()
	darken.color.a = 0.0
	panel.hide()
	panel.modulate.a = 0.0
	get_tree().paused = false
	run_manager.reset_run()
