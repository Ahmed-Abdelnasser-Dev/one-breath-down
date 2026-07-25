extends Node2D
class_name CaveWallGenerator
## Generates organic underwater cave walls with varying width on the Left, Right,
## and Seabed boundaries. Builds matching physics collision shapes, depth-tinted visuals,
## and procedural underwater flora/grass props along wall ledges.

const TWILIGHT_TINT := Color(0.071, 0.169, 0.388)
const MIDNIGHT_TINT := Color(0.012, 0.020, 0.051)
const TWILIGHT_END := 3000.0
const VIGNETTE_RAMP_RANGE := 1500.0

@export var max_depth_y: float = 6400.0
@export var step_y: float = 40.0
@export var base_left_x: float = 120.0
@export var base_right_x: float = 1480.0
@export var noise_amplitude_x: float = 75.0
@export var seabed_base_y: float = 6350.0
@export var seabed_amplitude_y: float = 45.0

@export var outer_left_x: float = -400.0
@export var outer_right_x: float = 2000.0
@export var seabed_bottom_y: float = 6800.0

var noise := FastNoiseLite.new()

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

var flora_container: Node2D

var _base_fill_color := Color("122c64")
var _base_edge_color := Color("185b99")

# Flora textures
var grass_textures: Array[Texture2D] = [
	preload("res://visuals/general assets/Grass1.png"),
	preload("res://visuals/general assets/Grass2.png"),
	preload("res://visuals/general assets/Grass3.png"),
	preload("res://visuals/general assets/Grass4.png")
]

var _flora_sprites: Array[Sprite2D] = []


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
	noise.frequency = 0.003
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.5


func set_seed(p_seed: int) -> void:
	noise.seed = p_seed
	generate_walls()


func _on_run_reset() -> void:
	generate_walls()


func get_left_wall_x(y: float) -> float:
	if y <= 0.0:
		return 0.0
	var noise_val := noise.get_noise_2d(0.0, y * 0.8)
	var raw_x := base_left_x + noise_val * noise_amplitude_x
	var target_x := clampf(raw_x, 20.0, 300.0)
	if y < 150.0:
		var t := y / 150.0
		return lerpf(0.0, target_x, t)
	return target_x


func get_right_wall_x(y: float) -> float:
	if y <= 0.0:
		return 1600.0
	var noise_val := noise.get_noise_2d(500.0, y * 0.8)
	var raw_x := base_right_x + noise_val * noise_amplitude_x
	var target_x := clampf(raw_x, 1300.0, 1580.0)
	if y < 150.0:
		var t := y / 150.0
		return lerpf(1600.0, target_x, t)
	return target_x


func get_seabed_y(x: float) -> float:
	var n := noise.get_noise_2d(x * 0.8, max_depth_y)
	return seabed_base_y + n * seabed_amplitude_y


func generate_walls() -> void:
	_ensure_nodes()
	_generate_left_wall()
	_generate_right_wall()
	_generate_seabed()
	_generate_flora_props()


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

	if flora_container == null:
		var fc := get_node_or_null("FloraContainer") as Node2D
		if fc == null:
			fc = Node2D.new()
			fc.name = "FloraContainer"
			add_child(fc)
		flora_container = fc


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


func _get_or_create_poly(p_name: String) -> Polygon2D:
	var node := get_node_or_null(p_name) as Polygon2D
	if node == null:
		node = Polygon2D.new()
		node.name = p_name
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


func _generate_flora_props() -> void:
	# Clear previous flora
	for sp in _flora_sprites:
		if is_instance_valid(sp):
			sp.queue_free()
	_flora_sprites.clear()

	if flora_container == null or grass_textures.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = noise.seed + 42

	# Left Wall Flora
	var y := 120.0
	while y < max_depth_y - 200.0:
		if rng.randf() < 0.35:  # 35% chance per interval
			var wall_x := get_left_wall_x(y)
			var spr := Sprite2D.new()
			spr.texture_filter = TEXTURE_FILTER_NEAREST
			spr.texture = grass_textures[rng.randi() % grass_textures.size()]
			spr.position = Vector2(wall_x + rng.randf_range(2.0, 10.0), y)
			spr.scale = Vector2(rng.randf_range(1.5, 2.5), rng.randf_range(1.5, 2.5))
			spr.rotation = rng.randf_range(-0.2, 0.4)
			flora_container.add_child(spr)
			_flora_sprites.append(spr)
		y += step_y * rng.randf_range(1.5, 3.0)

	# Right Wall Flora
	y = 120.0
	while y < max_depth_y - 200.0:
		if rng.randf() < 0.35:
			var wall_x := get_right_wall_x(y)
			var spr := Sprite2D.new()
			spr.texture_filter = TEXTURE_FILTER_NEAREST
			spr.texture = grass_textures[rng.randi() % grass_textures.size()]
			spr.position = Vector2(wall_x - rng.randf_range(2.0, 10.0), y)
			spr.scale = Vector2(-rng.randf_range(1.5, 2.5), rng.randf_range(1.5, 2.5))
			spr.rotation = rng.randf_range(-0.4, 0.2)
			flora_container.add_child(spr)
			_flora_sprites.append(spr)
		y += step_y * rng.randf_range(1.5, 3.0)

	# Seabed Flora
	var sb_x := get_left_wall_x(max_depth_y) + 50.0
	var sb_end_x := get_right_wall_x(max_depth_y) - 50.0
	while sb_x < sb_end_x:
		if rng.randf() < 0.5:
			var sb_y := get_seabed_y(sb_x)
			var spr := Sprite2D.new()
			spr.texture_filter = TEXTURE_FILTER_NEAREST
			spr.texture = grass_textures[rng.randi() % grass_textures.size()]
			spr.position = Vector2(sb_x, sb_y - 12.0)
			spr.scale = Vector2(rng.randf_range(2.0, 3.0), rng.randf_range(2.0, 3.0))
			flora_container.add_child(spr)
			_flora_sprites.append(spr)
		sb_x += step_y * rng.randf_range(1.0, 2.2)


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

	# Modulate flora sprites with depth
	for spr in _flora_sprites:
		if is_instance_valid(spr):
			spr.modulate = _depth_tint(spr.position.y)


func _depth_tint(depth: float) -> Color:
	var twilight_t: float = clampf(depth / TWILIGHT_END, 0.0, 1.0)
	var midnight_t: float = clampf((depth - TWILIGHT_END) / VIGNETTE_RAMP_RANGE, 0.0, 1.0)
	return Color(1.0, 1.0, 1.0).lerp(TWILIGHT_TINT, twilight_t).lerp(MIDNIGHT_TINT, midnight_t)
