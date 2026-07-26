extends Node
## Persistent display/audio settings autoload.
## Controls Fullscreen vs Windowed modes, 16:9 pixel viewport resolutions,
## and audio bus volumes. Applies settings in _ready() before the first frame.

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
var bus_volumes: Dictionary = {"Master": 1.0, "Music": 1.0, "SFX": 1.0}


var _loaded_from_disk: bool = false


func _ready() -> void:
	_loaded_from_disk = _load()
	if not _loaded_from_disk and _has_window():
		# First launch: adopt whatever window the project opened with instead of
		# forcing our defaults over it (notably the editor's size override).
		resolution = DisplayServer.window_get_size()
		fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	apply_all()


## `user_initiated` must be true when this runs from a button press: browsers
## only grant fullscreen from inside a real input event, so a saved fullscreen
## preference can't be restored at boot — it lands on the next Apply instead.
func apply_all(user_initiated: bool = false) -> void:
	_apply_window_mode(user_initiated)
	# Only ever resize a window the player has actually expressed a preference
	# about — a first launch keeps whatever size the project opened with.
	if user_initiated or _loaded_from_disk:
		_apply_resolution()
	_disable_vsync()
	for bus_name in BUS_NAMES:
		_apply_bus_volume(bus_name)


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	apply_all(true)
	save()


func set_resolution(size: Vector2i) -> void:
	resolution = size
	apply_all(true)
	save()


func set_bus_volume(bus_name: String, value: float) -> void:
	bus_volumes[bus_name] = clampf(value, 0.0, 1.0)
	_apply_bus_volume(bus_name)
	save()


func apply_display_and_audio(
	new_fullscreen: bool,
	new_resolution: Vector2i,
	new_volumes: Dictionary
) -> void:
	fullscreen = new_fullscreen
	resolution = new_resolution
	for bus_name in BUS_NAMES:
		bus_volumes[bus_name] = clampf(new_volumes.get(bus_name, 1.0), 0.0, 1.0)
	apply_all(true)
	save()


func get_bus_volume(bus_name: String) -> float:
	return bus_volumes.get(bus_name, 1.0)


## False only where there is no OS window to talk to at all.
func _has_window() -> bool:
	return DisplayServer.get_name() != "headless"


## The browser canvas is sized by the embedding page (an itch.io iframe, say),
## so an arbitrary window size is meaningless there — Options hides the row.
func supports_resolution() -> bool:
	return _has_window() and not OS.has_feature("web")


func _apply_window_mode(user_initiated: bool) -> void:
	if not _has_window():
		return
	if OS.has_feature("web") and not user_initiated:
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _apply_resolution() -> void:
	if not supports_resolution():
		return
	if not fullscreen:
		DisplayServer.window_set_size(resolution)
		var current_screen := DisplayServer.window_get_current_screen()
		var screen_size := DisplayServer.screen_get_size(current_screen)
		var screen_pos := DisplayServer.screen_get_position(current_screen)
		@warning_ignore("integer_division")
		var centered_pos := screen_pos + (screen_size - resolution) / 2
		DisplayServer.window_set_position(centered_pos)


func _disable_vsync() -> void:
	if _has_window():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


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
	for bus_name in BUS_NAMES:
		cfg.set_value("audio", bus_name, bus_volumes.get(bus_name, 1.0))
	cfg.save(SAVE_PATH)


## Returns whether a settings file actually existed, so _ready() can tell a
## real saved preference apart from an untouched first launch.
func _load() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	fullscreen = cfg.get_value("display", "fullscreen", fullscreen)
	resolution = cfg.get_value("display", "resolution", resolution)
	for bus_name in BUS_NAMES:
		bus_volumes[bus_name] = cfg.get_value("audio", bus_name, bus_volumes.get(bus_name, 1.0))
	return true
