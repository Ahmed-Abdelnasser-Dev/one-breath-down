extends Control
## Functional DISPLAY + SOUND settings. Edits are staged locally and only
## committed to the Settings autoload (and applied to the live window/audio
## buses) when Apply is pressed — Cancel discards the staged edits and
## reverts every control back to Settings' last-saved values.

signal closed

@onready var window_mode_option: OptionButton = $Panel/Margin/VBox/WindowModeRow/OptionButton
@onready var resolution_option: OptionButton = $Panel/Margin/VBox/ResolutionRow/OptionButton
@onready var vsync_check: CheckButton = $Panel/Margin/VBox/VsyncRow/CheckButton
@onready var master_slider: HSlider = $Panel/Margin/VBox/MasterRow/HSlider
@onready var music_slider: HSlider = $Panel/Margin/VBox/MusicRow/HSlider
@onready var sfx_slider: HSlider = $Panel/Margin/VBox/SfxRow/HSlider
@onready var cancel_button: Button = $Panel/Margin/VBox/FooterRow/CancelButton
@onready var apply_button: Button = $Panel/Margin/VBox/FooterRow/ApplyButton

var _pending_fullscreen: bool
var _pending_resolution: Vector2i
var _pending_vsync: bool
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

	vsync_check.toggled.connect(_on_vsync_toggled)

	_setup_volume_slider(master_slider, "Master")
	_setup_volume_slider(music_slider, "Music")
	_setup_volume_slider(sfx_slider, "SFX")

	cancel_button.pressed.connect(_on_cancel_pressed)
	apply_button.pressed.connect(_on_apply_pressed)


## MenuManager calls this every time the screen is pushed onto the stack —
## including a bare Esc/pop, which bypasses Cancel entirely. Re-syncing here
## (rather than only in _ready) guarantees any edits left over from a
## discarded-without-Cancel visit never leak into the next time this opens.
func focus_default() -> void:
	_load_pending_from_settings()
	window_mode_option.grab_focus()


## Re-reads Settings' current (last-applied) values into the pending state
## and refreshes every control to match — used on open and on Cancel.
func _load_pending_from_settings() -> void:
	_pending_fullscreen = Settings.fullscreen
	_pending_resolution = Settings.resolution
	_pending_vsync = Settings.vsync
	_pending_volumes = Settings.bus_volumes.duplicate()

	window_mode_option.selected = 1 if _pending_fullscreen else 0

	var res_index := Settings.RESOLUTIONS.find(_pending_resolution)
	resolution_option.selected = maxi(res_index, 0)

	vsync_check.button_pressed = _pending_vsync

	master_slider.value = _pending_volumes.get("Master", 1.0)
	music_slider.value = _pending_volumes.get("Music", 1.0)
	sfx_slider.value = _pending_volumes.get("SFX", 1.0)


func _setup_volume_slider(slider: HSlider, bus_name: String) -> void:
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value_changed.connect(func(v: float) -> void: _pending_volumes[bus_name] = v)


func _on_window_mode_selected(index: int) -> void:
	_pending_fullscreen = index == 1


func _on_resolution_selected(index: int) -> void:
	_pending_resolution = Settings.RESOLUTIONS[index]


func _on_vsync_toggled(pressed: bool) -> void:
	_pending_vsync = pressed


func _on_apply_pressed() -> void:
	Settings.apply_display_and_audio(
		_pending_fullscreen, _pending_resolution, _pending_vsync, _pending_volumes
	)
	closed.emit()


func _on_cancel_pressed() -> void:
	_load_pending_from_settings()
	closed.emit()
