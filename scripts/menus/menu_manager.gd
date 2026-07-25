extends Node
## Owns the modal-screen stack for pause / options / shop / inventory /
## credits / etc. A real Array-backed stack, not a pile of booleans, so Esc
## always closes exactly the topmost open screen (see docs/hud_ui.md §7.1).
##
## Screens are siblings of this node under MenuLayer. Any screen not yet
## added (e.g. before its task lands) is simply skipped via get_node_or_null,
## so build order doesn't matter.

const SCREEN_NAMES: Array[String] = [
	"PauseMenu", "OptionsScreen", "ControlsScreen", "AboutScreen",
	"CreditsScreen", "ShopScreen", "InventoryScreen",
]

@onready var run_manager: RunManager = get_parent().get_parent()
@onready var scrim: ColorRect = $"../Scrim"

var _stack: Array[Control] = []


func _ready() -> void:
	for screen_name in SCREEN_NAMES:
		var screen := get_node_or_null("../" + screen_name)
		if screen:
			screen.hide()
			if screen.has_signal("closed"):
				screen.closed.connect(pop)
	scrim.hide()


func _unhandled_input(event: InputEvent) -> void:
	var game_over := get_node_or_null("../GameOverScreen")
	if game_over and game_over.visible:
		return   # game-over owns input; don't let pause/shop/inventory interrupt it

	if event.is_action_pressed("pause"):
		_handle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_shop"):
		open_shop()
	elif event.is_action_pressed("open_inventory"):
		open_inventory()


func open_shop() -> void:
	_toggle_surface_screen("../ShopScreen")


func open_inventory() -> void:
	_toggle_surface_screen("../InventoryScreen")



func push(screen: Control) -> void:
	if not _stack.is_empty():
		_stack.back().hide()
	_stack.push_back(screen)
	screen.show()
	if screen.has_method("focus_default"):
		screen.focus_default()
	scrim.show()
	get_tree().paused = true


func pop() -> void:
	if _stack.is_empty():
		return
	var screen: Control = _stack.pop_back()
	screen.hide()
	if _stack.is_empty():
		scrim.hide()
		get_tree().paused = false
	else:
		var top: Control = _stack.back()
		top.show()
		if top.has_method("focus_default"):
			top.focus_default()


func _handle_pause() -> void:
	if not _stack.is_empty():
		pop()
		return
	var pause_menu := get_node_or_null("../PauseMenu")
	if pause_menu:
		push(pause_menu)


## F/I: toggle closed if already the topmost screen; otherwise open, but only
## from an empty stack and only while at the surface (hud_ui.md §5/§6).
func _toggle_surface_screen(relative_path: String) -> void:
	var screen := get_node_or_null(relative_path)
	if not screen:
		return
	if _stack.size() == 1 and _stack.back() == screen:
		pop()
		get_viewport().set_input_as_handled()
	elif _stack.is_empty() and run_manager.state == RunManager.RunState.AT_SURFACE and run_manager._is_at_ship():
		push(screen)
		get_viewport().set_input_as_handled()
