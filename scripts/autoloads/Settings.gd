extends Node
## Persistent display/audio settings autoload.
## Controls Fullscreen vs Windowed modes, 16:9 pixel viewport resolutions,
## VSync, and audio bus volumes. Applies settings in _ready() before the first frame.

const SAVE_PATH := "user://settings.cfg"

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(960, 540),    ## 2x pixel scale
	Vector2i(1280, 720),   ## 720p HD
	Vector2i(1600, 900),   ## 900p HD+
	Vector2i(1920, 1080),  ## 1080p Full HD
	Vector2i(2560, 1440),  ## 1440p QHD
	Vector2i(3840, 2160),  ## 4K UHD
]

const BUS_NAMES: Array[String] = ["Master", "Music", "SFX"]

var fullscreen: bool = false
var resolution: Vector2i = Vector2i(1280, 720)
var vsync: bool = true
var bus_volumes: Dictionary = {"Master": 1.0, "Music": 1.0, "SFX": 1.0}


func _ready() -> void:
	_load()
	apply_all()


func apply_all() -> void:
	_apply_window_mode()
	_apply_resolution()
	_apply_vsync()
	for bus_name in BUS_NAMES:
		_apply_bus_volume(bus_name)


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	_apply_window_mode()
	_apply_resolution()
	save()


func set_resolution(size: Vector2i) -> void:
	resolution = size
	_apply_resolution()
	save()


func set_vsync(enabled: bool) -> void:
	vsync = enabled
	_apply_vsync()
	save()


func set_bus_volume(bus_name: String, value: float) -> void:
	bus_volumes[bus_name] = clampf(value, 0.0, 1.0)
	_apply_bus_volume(bus_name)
	save()


func apply_display_and_audio(
	new_fullscreen: bool,
	new_resolution: Vector2i,
	new_vsync: bool,
	new_volumes: Dictionary
) -> void:
	fullscreen = new_fullscreen
	resolution = new_resolution
	vsync = new_vsync
	for bus_name in BUS_NAMES:
		bus_volumes[bus_name] = clampf(new_volumes.get(bus_name, 1.0), 0.0, 1.0)
	apply_all()
	save()


func get_bus_volume(bus_name: String) -> float:
	return bus_volumes.get(bus_name, 1.0)


func _is_window_embedded() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	if get_tree() and get_tree().root and get_tree().root.gui_embed_subwindows:
		return true
	return false


func _apply_window_mode() -> void:
	if _is_window_embedded():
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


func _apply_resolution() -> void:
	if fullscreen or _is_window_embedded():
		return
	if DisplayServer.window_get_size() != resolution:
		DisplayServer.window_set_size(resolution)
		var current_screen := DisplayServer.window_get_current_screen()
		var screen_size := DisplayServer.screen_get_size(current_screen)
		var screen_pos := DisplayServer.screen_get_position(current_screen)
		var centered_pos := screen_pos + (screen_size - resolution) / 2
		DisplayServer.window_set_position(centered_pos)


func _apply_vsync() -> void:
	var mode := DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)


func _apply_bus_volume(bus_name: String) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return
	var value: float = bus_volumes.get(bus_name, 1.0)
	AudioServer.set_bus_mute(bus_index, value < 0.001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "resolution", resolution)
	cfg.set_value("display", "vsync", vsync)
	for bus_name in BUS_NAMES:
		cfg.set_value("audio", bus_name, bus_volumes.get(bus_name, 1.0))
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	fullscreen = cfg.get_value("display", "fullscreen", fullscreen)
	resolution = cfg.get_value("display", "resolution", resolution)
	vsync = cfg.get_value("display", "vsync", vsync)
	for bus_name in BUS_NAMES:
		bus_volumes[bus_name] = cfg.get_value("audio", bus_name, bus_volumes.get(bus_name, 1.0))
