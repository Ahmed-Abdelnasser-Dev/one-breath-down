extends Node2D
class_name CaveWallGenerator
## Generates the dive shaft: left wall, right wall, and seabed, with matching
## collision. Walls are bare textured rock — no flora or reef dressing, so the
## boundary always reads as "this is the edge of the world," never as scenery
## you might be able to swim through.

const TWILIGHT_TINT := Color(0.071, 0.169, 0.388)
const MIDNIGHT_TINT := Color(0.012, 0.020, 0.051)
const TWILIGHT_END := 3000.0
const VIGNETTE_RAMP_RANGE := 1500.0

@export var max_depth_y: float = 6400.0
## Sampling step down the wall. Has to stay under the fine-detail noise's
## feature size (~90px) or the roughness aliases into smooth diagonals.
@export var step_y: float = 24.0
@export var base_left_x: float = 120.0
@export var base_right_x: float = 1480.0
@export var noise_amplitude_x: float = 75.0
@export var seabed_base_y: float = 6350.0
@export var seabed_amplitude_y: float = 45.0

@export var outer_left_x: float = -400.0
@export var outer_right_x: float = 2000.0
@export var seabed_bottom_y: float = 6800.0

## The shaft is built from three noise scales plus a hand-authored width
## profile. One noise layer alone reads as uniform wobble — which is what made
## the walls look the same at every depth no matter how far you descended.
var noise := FastNoiseLite.new()          ## mid detail: ledges and bulges, ~20m
var chamber_noise := FastNoiseLite.new()  ## cathedral scale: ~90m chambers
var detail_noise := FastNoiseLite.new()   ## fine roughness: ~3m jaggedness

const SHAFT_CENTRE_X := 800.0

## Designed geography, keyed to depth in metres and deliberately NOT seeded:
## every dive has the same landmarks in the same places (so players can learn
## the descent) while the rock detail around them re-rolls each run.
## Pairs of [depth_m, half_width_px].
const WIDTH_PROFILE: Array = [
	[0.0, 800.0],    # open mouth at the surface
	[6.0, 640.0],
	[28.0, 700.0],   # sunlit basin — roomy, forgiving
	[52.0, 430.0],   # THE THROAT: pinch at the twilight boundary
	[68.0, 520.0],
	[95.0, 660.0],   # twilight gallery — opens back up
	[126.0, 450.0],  # second pinch before midnight
	[152.0, 600.0],  # midnight chasm
	[178.0, 520.0],
	[200.0, 680.0],  # abyss floor, widening out
]

# All of these are created on demand by _ensure_nodes(); the scene ships this
# node childless, so $-path lookups here would just error at ready time.
var left_body: StaticBody2D
var right_body: StaticBody2D
var seabed_body: StaticBody2D

var left_poly: Polygon2D
var right_poly: Polygon2D
var seabed_poly: Polygon2D

var left_line: Line2D
var right_line: Line2D
var seabed_line: Line2D

var left_col: CollisionPolygon2D
var right_col: CollisionPolygon2D
var seabed_col: CollisionPolygon2D

const ROCK_TEXTURE: Texture2D = preload("res://visuals/background/wall_rock.png")

## Fill is near-white now that the rock texture carries the colour — modulate
## only applies the depth tint on top of it.
var _base_fill_color := Color("9fb6d8")
var _base_edge_color := Color("185b99")

func _ready() -> void:
	_init_noise()
	# DiveSpawner (group "spawner") drives set_seed() -> generate_walls() at
	# startup and on every run_reset. Only self-drive when no spawner exists,
	# otherwise every reset would rebuild the walls twice.
	if get_tree().get_first_node_in_group("spawner") == null:
		if Events.has_signal("run_reset"):
			Events.run_reset.connect(_on_run_reset)
		generate_walls()


func _init_noise() -> void:
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.0016
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.5
	_sync_derived_noise()


## Chamber and detail layers ride the same seed so a given seed reproduces the
## whole shaft, not just its mid-scale wobble.
func _sync_derived_noise() -> void:
	chamber_noise.seed = noise.seed + 1013
	chamber_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	chamber_noise.frequency = 0.00035
	chamber_noise.fractal_octaves = 2

	detail_noise.seed = noise.seed + 2027
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail_noise.frequency = 0.011
	detail_noise.fractal_octaves = 2


## Half-width of the open shaft at depth `y`, from WIDTH_PROFILE with
## smoothstep between keyframes so chambers ease open instead of cornering.
func _profile_half_width(y: float) -> float:
	var depth_m := y / GameState.PIXELS_PER_METRE
	var last: int = WIDTH_PROFILE.size() - 1
	if depth_m <= float(WIDTH_PROFILE[0][0]):
		return float(WIDTH_PROFILE[0][1])
	if depth_m >= float(WIDTH_PROFILE[last][0]):
		return float(WIDTH_PROFILE[last][1])
	for i in range(last):
		var a: Array = WIDTH_PROFILE[i]
		var b: Array = WIDTH_PROFILE[i + 1]
		if depth_m >= float(a[0]) and depth_m <= float(b[0]):
			var t := smoothstep(float(a[0]), float(b[0]), depth_m)
			return lerpf(float(a[1]), float(b[1]), t)
	return float(WIDTH_PROFILE[last][1])


## Signed wall offset shared by both sides. `side_key` decorrelates the two
## walls so they don't mirror each other into a symmetrical corridor.
func _wall_offset(y: float, side_key: float) -> float:
	var chamber := chamber_noise.get_noise_2d(side_key, y * 0.55) * 190.0
	var mid := noise.get_noise_2d(side_key + 40.0, y * 0.8) * 70.0
	var fine := detail_noise.get_noise_2d(side_key + 90.0, y) * 16.0
	return chamber + mid + fine


func set_seed(p_seed: int) -> void:
	noise.seed = p_seed
	_sync_derived_noise()
	generate_walls()


func _on_run_reset() -> void:
	generate_walls()


func get_left_wall_x(y: float) -> float:
	if y <= 0.0:
		return 0.0
	var half := _profile_half_width(y)
	var target_x := clampf(SHAFT_CENTRE_X - half - _wall_offset(y, 0.0), 20.0, 430.0)
	if y < 150.0:
		return lerpf(0.0, target_x, y / 150.0)
	return target_x


func get_right_wall_x(y: float) -> float:
	if y <= 0.0:
		return 1600.0
	var half := _profile_half_width(y)
	var target_x := clampf(SHAFT_CENTRE_X + half + _wall_offset(y, 500.0), 1170.0, 1580.0)
	if y < 150.0:
		return lerpf(1600.0, target_x, y / 150.0)
	return target_x


func get_seabed_y(x: float) -> float:
	var n := noise.get_noise_2d(x * 0.8, max_depth_y)
	return seabed_base_y + n * seabed_amplitude_y


func generate_walls() -> void:
	_ensure_nodes()
	_generate_left_wall()
	_generate_right_wall()
	_generate_seabed()


func _ensure_nodes() -> void:
	if left_body == null:
		left_body = _get_or_create_body("LeftWallBody")
		right_body = _get_or_create_body("RightWallBody")
		seabed_body = _get_or_create_body("SeabedBody")

		left_col = _get_or_create_col(left_body)
		right_col = _get_or_create_col(right_body)
		seabed_col = _get_or_create_col(seabed_body)

		left_poly = _get_or_create_poly("LeftWallPoly")
		right_poly = _get_or_create_poly("RightWallPoly")
		seabed_poly = _get_or_create_poly("SeabedPoly")

		left_line = _get_or_create_line("LeftWallLine")
		right_line = _get_or_create_line("RightWallLine")
		seabed_line = _get_or_create_line("SeabedLine")


func _get_or_create_body(p_name: String) -> StaticBody2D:
	var node := get_node_or_null(p_name) as StaticBody2D
	if node == null:
		node = StaticBody2D.new()
		node.name = p_name
		node.collision_layer = 8
		add_child(node)
	return node


func _get_or_create_col(parent: Node) -> CollisionPolygon2D:
	var node := parent.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	if node == null:
		node = CollisionPolygon2D.new()
		node.name = "CollisionPolygon2D"
		parent.add_child(node)
	return node


## Walls are textured, not flat-filled. With `uv` left empty a Polygon2D uses
## its vertex positions as UVs, so a repeating rock tile projects across the
## whole wall in world space for free — no UV bookkeeping as the silhouette
## regenerates. Mirrored repeat hides the tile seam.
func _get_or_create_poly(p_name: String) -> Polygon2D:
	var node := get_node_or_null(p_name) as Polygon2D
	if node == null:
		node = Polygon2D.new()
		node.name = p_name
		node.texture = ROCK_TEXTURE
		node.texture_scale = Vector2(0.34, 0.34)
		node.texture_filter = TEXTURE_FILTER_NEAREST
		node.texture_repeat = TEXTURE_REPEAT_MIRROR
		add_child(node)
	return node


func _get_or_create_line(p_name: String) -> Line2D:
	var node := get_node_or_null(p_name) as Line2D
	if node == null:
		node = Line2D.new()
		node.name = p_name
		node.width = 4.0
		node.antialiased = true
		add_child(node)
	return node


func _generate_left_wall() -> void:
	var inner_points: Array[Vector2] = []
	var y := 0.0
	while y <= max_depth_y:
		var x := get_left_wall_x(y)
		inner_points.append(Vector2(x, y))
		y += step_y

	var poly_points: Array[Vector2] = []
	poly_points.append(Vector2(outer_left_x, 0.0))
	for pt in inner_points:
		poly_points.append(pt)
	poly_points.append(Vector2(outer_left_x, max_depth_y))

	var packed := PackedVector2Array(poly_points)
	left_poly.polygon = packed
	left_col.polygon = packed
	left_line.points = PackedVector2Array(inner_points)


func _generate_right_wall() -> void:
	var inner_points: Array[Vector2] = []
	var y := 0.0
	while y <= max_depth_y:
		var x := get_right_wall_x(y)
		inner_points.append(Vector2(x, y))
		y += step_y

	var poly_points: Array[Vector2] = []
	poly_points.append(Vector2(outer_right_x, 0.0))
	for pt in inner_points:
		poly_points.append(pt)
	poly_points.append(Vector2(outer_right_x, max_depth_y))

	var packed := PackedVector2Array(poly_points)
	right_poly.polygon = packed
	right_col.polygon = packed
	right_line.points = PackedVector2Array(inner_points)


func _generate_seabed() -> void:
	var top_points: Array[Vector2] = []
	var start_x := get_left_wall_x(max_depth_y) - 50.0
	var end_x := get_right_wall_x(max_depth_y) + 50.0
	var x := start_x

	while x <= end_x:
		var y := get_seabed_y(x)
		top_points.append(Vector2(x, y))
		x += step_y

	var poly_points: Array[Vector2] = []
	poly_points.append(Vector2(start_x, seabed_bottom_y))
	for pt in top_points:
		poly_points.append(pt)
	poly_points.append(Vector2(end_x, seabed_bottom_y))

	var packed := PackedVector2Array(poly_points)
	seabed_poly.polygon = packed
	seabed_col.polygon = packed
	seabed_line.points = PackedVector2Array(top_points)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return

	var center := cam.get_screen_center_position()
	var depth: float = maxf(center.y, 0.0)

	var tint := _depth_tint(depth)
	var fill_color := _base_fill_color * tint
	fill_color.a = 1.0
	var edge_color := _base_edge_color * tint
	edge_color.a = 0.9

	if left_poly != null: left_poly.color = fill_color
	if right_poly != null: right_poly.color = fill_color
	if seabed_poly != null: seabed_poly.color = fill_color

	if left_line != null: left_line.default_color = edge_color
	if right_line != null: right_line.default_color = edge_color
	if seabed_line != null: seabed_line.default_color = edge_color


func _depth_tint(depth: float) -> Color:
	var twilight_t: float = clampf(depth / TWILIGHT_END, 0.0, 1.0)
	var midnight_t: float = clampf((depth - TWILIGHT_END) / VIGNETTE_RAMP_RANGE, 0.0, 1.0)
	return Color(1.0, 1.0, 1.0).lerp(TWILIGHT_TINT, twilight_t).lerp(MIDNIGHT_TINT, midnight_t)
