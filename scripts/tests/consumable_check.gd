extends Node
## Headless integration check for the consumable system. Loads the real run
## scene, buys/equips through the real GameState API, then fires each effect
## through the real component and asserts the observable result.
##
## Run: godot --headless --path . res://scenes/tests/consumable_check.tscn
## (a scene, not --script: autoloads like GameState only exist for scenes)

var _fails: int = 0


func _ok(label: String, cond: bool, detail: String = "") -> void:
	print("%s %s%s" % ["PASS" if cond else "FAIL", label, ("  " + detail) if detail else ""])
	if not cond:
		_fails += 1


func _ready() -> void:
	var packed := load("res://scenes/Game.tscn") as PackedScene
	if packed == null:
		print("FAIL Game.tscn did not load at all")
		get_tree().quit(1)
		return
	var g: Node = packed.instantiate()
	if g == null:
		print("FAIL Game.tscn loaded but did not instantiate")
		get_tree().quit(1)
		return
	g.name = "Game"
	# Deferred: the root is mid-_ready and refuses direct add_child here.
	get_tree().root.add_child.call_deferred(g)
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var game := get_tree().root.get_node_or_null("Game")
	if game == null:
		print("FAIL could not instantiate Game.tscn")
		get_tree().quit(1)
		return

	var diver := game.get_node("Diver")
	var comp := diver.get_node("ConsumableComponent")
	var breath := diver.get_node("BreathComponent")
	var health := diver.get_node("HealthComponent")

	# --- capacity rules -----------------------------------------------------
	GameState.reset_progress()
	GameState.pearls = 1000
	for i in 4:
		GameState.buy_consumable(&"jet_boost", 0)
	_ok("per-kind cap is 3", GameState.consumable_count(&"jet_boost") == 3,
		"got %d" % GameState.consumable_count(&"jet_boost"))

	GameState.buy_consumable(&"depth_charge", 0)
	GameState.buy_consumable(&"air_bubble", 0)
	_ok("only two kinds equipped", GameState.equipped.count(&"") == 0
		and GameState.equipped[0] != GameState.equipped[1], str(GameState.equipped))
	_ok("third kind owned but unequipped", not GameState.equipped.has(&"air_bubble"),
		str(GameState.equipped))

	GameState.equip_consumable(0, &"air_bubble")
	_ok("equip swaps, never duplicates",
		GameState.equipped[0] == &"air_bubble" and GameState.equipped[1] != &"air_bubble",
		str(GameState.equipped))

	# --- AIR refunds breath -------------------------------------------------
	diver.global_position = Vector2(800, 2000)
	breath.current_breath = 5.0
	GameState.equip_consumable(0, &"air_bubble")
	var air_before: float = breath.current_breath
	comp._try_use(0)
	_ok("air bubble refunds breath", breath.current_breath > air_before + 10.0,
		"%.1f -> %.1f" % [air_before, breath.current_breath])
	_ok("air bubble spent a charge", GameState.consumable_count(&"air_bubble") == 0)

	# --- refuses to waste a charge -----------------------------------------
	GameState.buy_consumable(&"air_bubble", 0)
	breath.current_breath = breath.max_breath
	var stock_before: int = GameState.consumable_count(&"air_bubble")
	comp._try_use(0)
	_ok("refuses air bubble at full breath",
		GameState.consumable_count(&"air_bubble") == stock_before,
		"stock %d" % GameState.consumable_count(&"air_bubble"))

	# --- HEAL ---------------------------------------------------------------
	GameState.buy_consumable(&"patch_kit", 0)
	GameState.equip_consumable(0, &"patch_kit")
	health.current_hp = 20.0
	comp._try_use(0)
	_ok("patch kit heals", health.current_hp > 20.0, "hp %.0f" % health.current_hp)

	# --- JET ----------------------------------------------------------------
	GameState.buy_consumable(&"jet_boost", 0)
	GameState.equip_consumable(0, &"jet_boost")
	diver.velocity = Vector2.ZERO
	comp._try_use(0)
	_ok("jet applies impulse", diver.velocity.length() > 200.0,
		"speed %.0f" % diver.velocity.length())
	_ok("jet lifts the speed cap briefly", comp.is_boosting())

	# --- BLAST --------------------------------------------------------------
	var enemy_scene: PackedScene = load("res://scenes/enemies/patroller.tscn")
	var e = enemy_scene.instantiate()
	e.data = load("res://data/enemies/ugly_fish.tres")
	game.get_node("World/Enemies").add_child(e)
	await get_tree().process_frame
	e.global_position = diver.global_position + Vector2(40, 0)
	var hp_before: int = e.hp
	GameState.buy_consumable(&"depth_charge", 0)
	GameState.equip_consumable(0, &"depth_charge")
	comp._try_use(0)
	await get_tree().process_frame
	_ok("depth charge damages nearby enemy", e.hp < hp_before,
		"%d -> %d" % [hp_before, e.hp])

	# --- empty slot is a no-op ---------------------------------------------
	GameState.clear_slot(0)
	comp._try_use(0)
	_ok("empty slot is harmless", true)

	print("---- %s ----" % ("ALL PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)
