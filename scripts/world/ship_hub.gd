extends Node2D
class_name ShipHub
## Surface Pearl Diver Ship Hub & Pier.
## Serves as the starting point of the dive, the docking point for banking pearls & money,
## and the shop/inventory access hub.

signal diver_docked
signal diver_undocked

@onready var boat: Sprite2D = $Boat
@onready var dock_area: Area2D = $ShipDockArea
@onready var prompt_label: Label = $PromptLabel

var _time := 0.0
var _anim_timer := 0.0
var _initial_boat_y := -24.0
var is_diver_at_ship := false

const FPS := 8.0  # Boat animation frames per second


func _ready() -> void:
	if boat != null:
		_initial_boat_y = boat.position.y
	if dock_area != null:
		dock_area.body_entered.connect(_on_body_entered)
		dock_area.body_exited.connect(_on_body_exited)
	if prompt_label != null:
		prompt_label.visible = false


func _process(delta: float) -> void:
	_time += delta
	
	# Animate the 9-frame boat spritesheet
	_anim_timer += delta
	if _anim_timer >= (1.0 / FPS):
		_anim_timer -= (1.0 / FPS)
		if boat != null and boat.hframes > 1:
			boat.frame = (boat.frame + 1) % boat.hframes

	# Gentle buoyant bobbing & subtle sway tilt
	var bob := sin(_time * 1.6) * 3.5
	var tilt := sin(_time * 1.2) * 0.03
	if boat != null:
		boat.position.y = _initial_boat_y + bob
		boat.rotation = tilt

	# Dock prompt key interaction
	if is_diver_at_ship:
		if Input.is_action_just_pressed("ui_accept"):
			_open_shop()


func _on_body_entered(body: Node2D) -> void:
	if body is Diver:
		is_diver_at_ship = true
		diver_docked.emit()
		if prompt_label != null:
			prompt_label.visible = true
			
		var health = body.get_node_or_null("HealthComponent") as HealthComponent
		if health != null:
			health.restore_health()


func _on_body_exited(body: Node2D) -> void:
	if body is Diver:
		is_diver_at_ship = false
		diver_undocked.emit()
		if prompt_label != null:
			prompt_label.visible = false


func _open_shop() -> void:
	var menu_mgr := get_tree().get_first_node_in_group("menu_manager")
	if menu_mgr != null and menu_mgr.has_method("open_shop"):
		menu_mgr.open_shop()


func _open_inventory() -> void:
	var menu_mgr := get_tree().get_first_node_in_group("menu_manager")
	if menu_mgr != null and menu_mgr.has_method("open_inventory"):
		menu_mgr.open_inventory()
