extends Control
## Functional DISPLAY + SOUND settings. Edits are staged locally and only
## committed to the Settings autoload (and applied to the live window/audio
## buses) when Apply is pressed — Cancel discards the staged edits and
## reverts every control back to Settings' last-saved values.

signal closed

@onready var window_mode_option: OptionButton = $Panel/Margin/VBox/WindowModeRow/OptionButton
@onready var resolution_row: HBoxContainer = $Panel/Margin/VBox/ResolutionRow
@onready var resolution_option: OptionButton = $Panel/Margin/VBox/ResolutionRow/OptionButton
@onready var master_slider: HSlider = $Panel/Margin/VBox/MasterRow/HSlider
@onready var music_slider: HSlider = $Panel/Margin/VBox/MusicRow/HSlider
@onready var sfx_slider: HSlider = $Panel/Margin/VBox/SfxRow/HSlider
@onready var cancel_button: Button = $Panel/Margin/VBox/FooterRow/CancelButton
@onready var apply_button: Button = $Panel/Margin/VBox/FooterRow/ApplyButton

var _pending_fullscreen: bool
var _pending_resolution: Vector2i
var _pending_volumes: Dictionary


func _ready() -> void:
	window_mode_option.clear()
	window_mode_option.add_item("Windowed")
	window_mode_option.add_item("Fullscreen")
	window_mode_option.item_selected.connect(_on_window_mode_selected)

	resolution_option.clear()
	for res in Settings.RESOLUTIONS:
		resolution_option.add_item("%d x %d" % [res.x, res.y])
	resolution_option.item_selected.connect(_on_resolution_selected)
	# The browser owns the canvas size, so offering a resolution picker there
	# would be a control that silently does nothing.
	resolution_row.visible = Settings.supports_resolution()

	_setup_volume_slider(master_slider, "Master")
	_setup_volume_slider(music_slider, "Music")
	_setup_volume_slider(sfx_slider, "SFX")

	cancel_button.pressed.connect(_on_cancel_pressed)
	apply_button.pressed.connect(_on_apply_pressed)


func focus_default() -> void:
	_load_pending_from_settings()
	window_mode_option.grab_focus()


func _load_pending_from_settings() -> void:
	_pending_fullscreen = Settings.fullscreen
	_pending_resolution = Settings.resolution
	_pending_volumes = Settings.bus_volumes.duplicate()

	window_mode_option.selected = 1 if _pending_fullscreen else 0

	var res_index := Settings.RESOLUTIONS.find(_pending_resolution)
	if res_index == -1:
		# The live window can be an off-list size (first launch, or a manual
		# resize). Snap to the closest entry so the dropdown never lies.
		res_index = _nearest_resolution_index(_pending_resolution)
		_pending_resolution = Settings.RESOLUTIONS[res_index]
	resolution_option.selected = res_index

	master_slider.value = _pending_volumes.get("Master", 1.0)
	music_slider.value = _pending_volumes.get("Music", 1.0)
	sfx_slider.value = _pending_volumes.get("SFX", 1.0)


func _nearest_resolution_index(target: Vector2i) -> int:
	var best_index := 0
	var best_distance := absi(Settings.RESOLUTIONS[0].x - target.x)
	for i in Settings.RESOLUTIONS.size():
		var distance := absi(Settings.RESOLUTIONS[i].x - target.x)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index


func _setup_volume_slider(slider: HSlider, bus_name: String) -> void:
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value_changed.connect(func(v: float) -> void: _pending_volumes[bus_name] = v)


func _on_window_mode_selected(index: int) -> void:
	_pending_fullscreen = index == 1


func _on_resolution_selected(index: int) -> void:
	_pending_resolution = Settings.RESOLUTIONS[index]


func _on_apply_pressed() -> void:
	Settings.apply_display_and_audio(
		_pending_fullscreen, _pending_resolution, _pending_volumes
	)
	closed.emit()


func _on_cancel_pressed() -> void:
	_load_pending_from_settings()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
