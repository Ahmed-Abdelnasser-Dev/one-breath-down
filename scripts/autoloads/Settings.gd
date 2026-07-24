extends Node
## Persistent display/audio settings. Applies itself in _ready(), before the
## first frame renders, so the player never sees a flash of the wrong mode.

const SAVE_PATH := "user://settings.cfg"

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

const BUS_NAMES: Array[String] = ["Master", "Music", "SFX"]

var fullscreen: bool = true
var resolution: Vector2i = Vector2i(1920, 1080)
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
	_apply_resolution()   # windowed size only takes effect once out of fullscreen
	save()


func set_resolution(size: Vector2i) -> void:
	resolution = size
	_apply_resolution()
	save()


func set_vsync(enabled: bool) -> void:
	vsync = enabled
	_apply_vsync()
	save()


## value is linear 0..1; converted to dB at the point of application.
func set_bus_volume(bus_name: String, value: float) -> void:
	bus_volumes[bus_name] = clampf(value, 0.0, 1.0)
	_apply_bus_volume(bus_name)
	save()


func get_bus_volume(bus_name: String) -> float:
	return bus_volumes.get(bus_name, 1.0)


func _apply_window_mode() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func _apply_resolution() -> void:
	if fullscreen:
		return
	DisplayServer.window_set_size(resolution)
	var screen_size := DisplayServer.screen_get_size()
	DisplayServer.window_set_position((screen_size - resolution) / 2 as Vector2i)


func _apply_vsync() -> void:
	var mode := DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)


## Godot audio buses are decibels; a 0..1 slider is linear. Floor near-zero to
## a hard mute instead of a very quiet -80 dB (the standard trap, see hud_ui.md).
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
