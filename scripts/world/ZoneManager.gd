extends Node
class_name ZoneManager

static var instance: ZoneManager

@export var zones: Array[ZoneData] = [
	preload("res://data/zones/sunlit.tres"),
	preload("res://data/zones/twilight.tres"),
	preload("res://data/zones/midnight.tres")
]

@export var water_background_path: NodePath = "../WaterBackground"
@export var dark_overlay_rect_path: NodePath = "../../DarkOverlay/ColorRect"

var current_zone: ZoneData
var current_drain_multiplier: float = 1.0

var _water_bg: ColorRect
var _dark_overlay_rect: ColorRect


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	# Ensure zones are sorted by start depth ascending
	zones.sort_custom(func(a: ZoneData, b: ZoneData): return a.start_depth_m < b.start_depth_m)
	assert(zones.size() > 0, "ZoneManager requires at least one zone!")

	current_zone = zones[0]
	current_drain_multiplier = current_zone.drain_multiplier

	Events.depth_changed.connect(_on_depth_changed)
	Events.run_reset.connect(_on_run_reset)

	call_deferred("_cache_nodes")


func _cache_nodes() -> void:
	_water_bg = get_node_or_null(water_background_path) as ColorRect
	if _water_bg == null:
		_water_bg = get_tree().get_first_node_in_group("water_background") as ColorRect

	_dark_overlay_rect = get_node_or_null(dark_overlay_rect_path) as ColorRect
	if _dark_overlay_rect == null:
		_dark_overlay_rect = get_tree().get_first_node_in_group("dark_overlay") as ColorRect


func _on_run_reset() -> void:
	_on_depth_changed(0)


func _on_depth_changed(m: int) -> void:
	var target_zone := zones[0]
	for zone in zones:
		if m >= zone.start_depth_m:
			target_zone = zone

	if target_zone != current_zone:
		current_zone = target_zone
		current_drain_multiplier = current_zone.drain_multiplier
		Events.zone_changed.emit(current_zone)


func _process(delta: float) -> void:
	if current_zone == null:
		return

	# Smoothly transition water background color
	if _water_bg != null:
		_water_bg.color = _water_bg.color.lerp(current_zone.water_color, delta * 2.0)

	# Smoothly transition dark overlay alpha
	if _dark_overlay_rect != null:
		var target_color := Color(0, 0, 0, current_zone.darkness)
		_dark_overlay_rect.color = _dark_overlay_rect.color.lerp(target_color, delta * 2.0)
