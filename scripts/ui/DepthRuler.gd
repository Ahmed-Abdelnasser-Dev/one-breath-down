extends Control
class_name DepthRuler

@export var ruler_width: float = 24.0
@export var tick_color: Color = Color(1.0, 1.0, 1.0, 0.4)
@export var major_tick_color: Color = Color(1.0, 1.0, 1.0, 0.85)
@export var zone_line_color: Color = Color(0.2, 0.8, 1.0, 0.9)

const PIXEL_FONT: Font = preload("res://fonts/Pixellari.ttf")
const TOP_MARGIN: float = 44.0  ## Starts below the top-left HUD (Y=8..38)

var _diver: Diver


func _ready() -> void:
	_diver = get_tree().get_first_node_in_group("diver") as Diver
	Events.depth_changed.connect(func(_m): queue_redraw())


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _diver == null:
		_diver = get_tree().get_first_node_in_group("diver") as Diver
		if _diver == null:
			return

	var vp_height := get_viewport_rect().size.y
	var diver_y := _diver.global_position.y
	
	# Viewport vertical range in world metres
	var top_y := diver_y - vp_height * 0.5
	var bottom_y := diver_y + vp_height * 0.5
	
	var min_m: int = max(0, int(top_y / GameState.PIXELS_PER_METRE) - 1)
	var max_m: int = int(bottom_y / GameState.PIXELS_PER_METRE) + 1

	var font_size: int = 8

	# Draw semi-transparent background strip starting below TopLeftSection
	draw_rect(Rect2(0, TOP_MARGIN, ruler_width, vp_height - TOP_MARGIN), Color(0, 0, 0, 0.25))

	for m in range(min_m, max_m + 1):
		var world_y := m * GameState.PIXELS_PER_METRE
		# Convert world Y to screen Y relative to viewport center
		var screen_y := (world_y - top_y)
		if screen_y < TOP_MARGIN or screen_y > vp_height:
			continue

		# Zone boundaries at 0m, 50m, 150m
		if m == 0 or m == 50 or m == 150:
			draw_line(Vector2(0, screen_y), Vector2(ruler_width, screen_y), zone_line_color, 1.5)
			var zone_name := "SUN" if m == 0 else ("TWI" if m == 50 else "MID")
			draw_string(PIXEL_FONT, Vector2(2, screen_y - 2), zone_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, zone_line_color)
		elif m % 25 == 0:
			# Major tick (every 25m)
			draw_line(Vector2(ruler_width - 10, screen_y), Vector2(ruler_width, screen_y), major_tick_color, 1.0)
			draw_string(PIXEL_FONT, Vector2(2, screen_y + 3), "%dm" % m, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, major_tick_color)
		elif m % 5 == 0:
			# Minor tick (every 5m)
			draw_line(Vector2(ruler_width - 5, screen_y), Vector2(ruler_width, screen_y), tick_color, 1.0)
