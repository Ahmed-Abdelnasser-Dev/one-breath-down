extends SceneTree
## Command-line test runner for One Breath Down core game logic.

const GameStateScript = preload("res://scripts/autoloads/GameState.gd")
const DepthSpawnerScript = preload("res://scripts/world/depth_spawner.gd")

var game_state: Node
var depth_spawner: Node


func _init() -> void:
	print("--- Running One Breath Down Core Test Suite ---")
	
	if root.has_node("GameState"):
		game_state = root.get_node("GameState")
	else:
		game_state = GameStateScript.new()
		root.add_child(game_state)
		
	if root.has_node("DepthSpawner"):
		depth_spawner = root.get_node("DepthSpawner")
	else:
		depth_spawner = DepthSpawnerScript.new()
		root.add_child(depth_spawner)

	var failures: int = 0
	failures += _test_game_state()
	failures += _test_depth_spawner()
	failures += _test_pearl_generation()
	failures += _test_diver_upgrades()
	
	if failures == 0:
		print("SUCCESS: All tests passed cleanly!")
	else:
		print("FAILURE: %d test(s) failed." % failures)
		
	quit(failures)


func _test_game_state() -> int:
	print("[Test] GameState & Upgrade system")
	var fails := 0
	game_state.pearls = 100
	game_state.owned_upgrades.clear()
	
	if not game_state.purchase_upgrade(&"lungs_1", 15):
		print("  FAIL: Unable to purchase lungs_1 with 100 pearls")
		fails += 1
	if game_state.pearls != 85:
		print("  FAIL: Expected 85 pearls remaining, got %d" % game_state.pearls)
		fails += 1
	if game_state.get_upgrade_level("lungs_") != 1:
		print("  FAIL: Expected lungs level 1, got %d" % game_state.get_upgrade_level("lungs_"))
		fails += 1
		
	# Try purchasing duplicate
	if game_state.purchase_upgrade(&"lungs_1", 15):
		print("  FAIL: Should not be able to purchase duplicate upgrade")
		fails += 1
		
	# Try purchasing level 2
	if not game_state.purchase_upgrade(&"lungs_2", 40):
		print("  FAIL: Unable to purchase lungs_2")
		fails += 1
	if game_state.get_upgrade_level("lungs_") != 2:
		print("  FAIL: Expected lungs level 2, got %d" % game_state.get_upgrade_level("lungs_"))
		fails += 1
		
	return fails


func _test_depth_spawner() -> int:
	print("[Test] DepthSpawner Zone Lookup")
	var fails := 0
	
	if depth_spawner.get_zone_name_for_depth(5.0) != "Sunlight Zone":
		print("  FAIL: 5m should be Sunlight Zone")
		fails += 1
	if depth_spawner.get_zone_name_for_depth(30.0) != "Twilight Zone":
		print("  FAIL: 30m should be Twilight Zone")
		fails += 1
	if depth_spawner.get_zone_name_for_depth(75.0) != "Midnight Zone":
		print("  FAIL: 75m should be Midnight Zone")
		fails += 1
	if depth_spawner.get_zone_name_for_depth(150.0) != "The Abyss":
		print("  FAIL: 150m should be The Abyss")
		fails += 1
		
	return fails


func _test_pearl_generation() -> int:
	print("[Test] Pearl Data Resources")
	var fails := 0
	
	var seed_p: PearlData = load("res://data/pearls/seed_pearl.tres")
	var gold_p: PearlData = load("res://data/pearls/golden_pearl.tres")
	
	if seed_p == null or gold_p == null:
		print("  FAIL: Pearl resources could not be loaded")
		return fails + 1
		
	if gold_p.value <= seed_p.value:
		print("  FAIL: Golden pearl value (%d) should be greater than seed pearl (%d)" % [gold_p.value, seed_p.value])
		fails += 1
		
	if gold_p.depth_min <= seed_p.depth_min:
		print("  FAIL: Golden pearl depth min (%.1fm) should be deeper than seed pearl (%.1fm)" % [gold_p.depth_min, seed_p.depth_min])
		fails += 1
		
	return fails


func _test_diver_upgrades() -> int:
	print("[Test] Diver & Weight Speed Calculation")
	var fails := 0
	
	var diver := Diver.new()
	diver._ready()
	
	# Default base speed without fins
	game_state.owned_upgrades.clear()
	diver.apply_upgrades()
	if abs(diver.max_speed - 400.0) > 1.0:
		print("  FAIL: Expected base max_speed 400.0, got %.1f" % diver.max_speed)
		fails += 1
		
	# Add Fins level 1
	game_state.owned_upgrades.append(&"fins_1")
	diver.apply_upgrades()
	if abs(diver.max_speed - 500.0) > 1.0:
		print("  FAIL: Expected Fins 1 max_speed 500.0, got %.1f" % diver.max_speed)
		fails += 1
		
	diver.free()
	return fails
