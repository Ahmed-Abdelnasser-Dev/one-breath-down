extends Control
## Functional DISPLAY + SOUND settings. Reads/writes through the Settings
## autoload so every change applies immediately and persists to
## user://settings.cfg.

signal closed

@onready var window_mode_option: OptionButton = $Panel/Margin/VBox/WindowModeRow/OptionButton
@onready var resolution_option: OptionButton = $Panel/Margin/VBox/ResolutionRow/OptionButton
@onready var vsync_check: CheckButton = $Panel/Margin/VBox/VsyncRow/CheckButton
@onready var master_slider: HSlider = $Panel/Margin/VBox/MasterRow/HSlider
@onready var music_slider: HSlider = $Panel/Margin/VBox/MusicRow/HSlider
@onready var sfx_slider: HSlider = $Panel/Margin/VBox/SfxRow/HSlider
@onready var back_button: Button = $Panel/Margin/VBox/BackButton


func _ready() -> void:
	window_mode_option.clear()
	window_mode_option.add_item("Windowed")
	window_mode_option.add_item("Fullscreen")
	window_mode_option.selected = 1 if Settings.fullscreen else 0
	window_mode_option.item_selected.connect(_on_window_mode_selected)

	resolution_option.clear()
	for res in Settings.RESOLUTIONS:
		resolution_option.add_item("%d x %d" % [res.x, res.y])
	var current_index := Settings.RESOLUTIONS.find(Settings.resolution)
	resolution_option.selected = maxi(current_index, 0)
	resolution_option.item_selected.connect(_on_resolution_selected)

	vsync_check.button_pressed = Settings.vsync
	vsync_check.toggled.connect(_on_vsync_toggled)

	_setup_volume_slider(master_slider, "Master")
	_setup_volume_slider(music_slider, "Music")
	_setup_volume_slider(sfx_slider, "SFX")

	back_button.pressed.connect(func() -> void: closed.emit())


func focus_default() -> void:
	back_button.grab_focus()


func _setup_volume_slider(slider: HSlider, bus_name: String) -> void:
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = Settings.get_bus_volume(bus_name)
	slider.value_changed.connect(func(v: float) -> void: Settings.set_bus_volume(bus_name, v))


func _on_window_mode_selected(index: int) -> void:
	Settings.set_fullscreen(index == 1)


func _on_resolution_selected(index: int) -> void:
	Settings.set_resolution(Settings.RESOLUTIONS[index])


func _on_vsync_toggled(pressed: bool) -> void:
	Settings.set_vsync(pressed)
