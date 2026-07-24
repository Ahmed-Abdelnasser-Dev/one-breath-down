extends Control
## Launch screen. Start loads the dive scene; Options/Controls/Credits/About
## are the same reusable overlay screens the in-game pause menu uses.
##
## Camera drifts in a gentle looping figure-8 via chained Tweens.
## Title and buttons animate in with staggered fade+slide on first load.

const CENTER := Vector2(240.0, 135.0)
const DRIFT_X := 15.0       ## max horizontal camera drift from center
const DRIFT_Y := 8.0        ## max vertical camera drift from center
const DRIFT_DURATION := 10.0 ## seconds per full camera drift loop

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
@onready var camera_2d: Camera2D = $Camera2D
@onready var title_label: Label = $TitleLabel

var _overlays: Array[Control] = []
var _cam_tween: Tween


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

	# --- entrance animations ---
	_animate_entrance()
	_start_camera_drift()


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


## ─── Camera drift ────────────────────────────────────────────────────
## Looping figure-8 via chained waypoints. Each leg uses EASE_IN_OUT +
## TRANS_SINE so the camera decelerates/accelerates smoothly at the
## turning points, giving a dreamy underwater sway.

func _start_camera_drift() -> void:
	if _cam_tween and _cam_tween.is_valid():
		_cam_tween.kill()

	camera_2d.position = CENTER
	_cam_tween = create_tween().bind_node(self)
	_cam_tween.set_ease(Tween.EASE_IN_OUT)
	_cam_tween.set_trans(Tween.TRANS_SINE)
	_cam_tween.set_loops()  # infinite

	# Four waypoints tracing a figure-8 around CENTER
	var quarter := DRIFT_DURATION / 4.0
	_cam_tween.tween_property(
		camera_2d, "position",
		CENTER + Vector2(DRIFT_X, -DRIFT_Y), quarter
	)
	_cam_tween.tween_property(
		camera_2d, "position",
		CENTER + Vector2(-DRIFT_X * 0.5, DRIFT_Y), quarter
	)
	_cam_tween.tween_property(
		camera_2d, "position",
		CENTER + Vector2(-DRIFT_X, -DRIFT_Y * 0.6), quarter
	)
	_cam_tween.tween_property(
		camera_2d, "position",
		CENTER, quarter
	)


## ─── Entrance animations ─────────────────────────────────────────────
## Title fades in + slides down, then the panel fades in and each button
## staggers in from the left with a slight overshoot.

func _animate_entrance() -> void:
	# --- Title ---
	var title_final_top := title_label.offset_top
	title_label.modulate.a = 0.0
	title_label.offset_top = title_final_top - 20.0

	var title_tween := create_tween().bind_node(title_label)
	title_tween.set_ease(Tween.EASE_OUT)
	title_tween.set_trans(Tween.TRANS_QUAD)
	title_tween.set_parallel(true)
	title_tween.tween_property(title_label, "modulate:a", 1.0, 0.6)
	title_tween.tween_property(title_label, "offset_top", title_final_top, 0.6)

	# --- Buttons panel ---
	buttons_panel.modulate.a = 0.0
	var panel_tween := create_tween().bind_node(buttons_panel)
	panel_tween.tween_interval(0.2)
	panel_tween.tween_property(buttons_panel, "modulate:a", 1.0, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# --- Staggered button entrance ---
	var buttons: Array[Button] = [
		start_button, options_button, controls_button,
		credits_button, about_button, exit_button,
	]

	for btn in buttons:
		btn.modulate.a = 0.0

	var btn_tween := create_tween().bind_node(buttons_panel)
	btn_tween.tween_interval(0.5)  # wait for panel to begin fading in

	for i in buttons.size():
		var btn := buttons[i]
		var final_x := btn.position.x
		btn.position.x = final_x - 30.0

		# Each button gets a parallel pair (fade + slide), then the next
		# button starts after a short stagger delay.
		btn_tween.tween_property(btn, "modulate:a", 1.0, 0.4) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		btn_tween.parallel().tween_property(btn, "position:x", final_x, 0.4) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

		if i < buttons.size() - 1:
			btn_tween.tween_interval(0.08)

	# Grab focus only after buttons are visible
	btn_tween.tween_callback(start_button.grab_focus)
