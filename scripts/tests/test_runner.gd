extends Node
## Test runner scene node for execution within Godot environment with full autoload support.

func _ready() -> void:
	print("--- Running One Breath Down Test Runner Scene ---")
	var failures: int = 0
	
	failures += _test_game_state()
	failures += _test_depth_spawner()
	failures += _test_pearl_resources()
	failures += _test_diver_upgrades()
	
	if failures == 0:
		print("SUCCESS: All unit tests passed cleanly!")
		get_tree().quit(0)
	else:
		print("FAILURE: %d test(s) failed." % failures)
		get_tree().quit(1)


func _test_game_state() -> int:
	print("[Test] GameState & Upgrade system")
	var fails := 0
	GameState.pearls = 100
	GameState.owned_upgrades.clear()
	
	if not GameState.purchase_upgrade(&"lungs_1", 15):
		print("  FAIL: Unable to purchase lungs_1 with 100 pearls")
		fails += 1
	if GameState.pearls != 85:
		print("  FAIL: Expected 85 pearls remaining, got %d" % GameState.pearls)
		fails += 1
	if GameState.get_upgrade_level("lungs_") != 1:
		print("  FAIL: Expected lungs level 1, got %d" % GameState.get_upgrade_level("lungs_"))
		fails += 1
		
	# Try purchasing duplicate
	if GameState.purchase_upgrade(&"lungs_1", 15):
		print("  FAIL: Should not be able to purchase duplicate upgrade")
		fails += 1
		
	# Try purchasing level 2
	if not GameState.purchase_upgrade(&"lungs_2", 40):
		print("  FAIL: Unable to purchase lungs_2")
		fails += 1
	if GameState.get_upgrade_level("lungs_") != 2:
		print("  FAIL: Expected lungs level 2, got %d" % GameState.get_upgrade_level("lungs_"))
		fails += 1
		
	return fails


func _test_depth_spawner() -> int:
	print("[Test] DepthSpawner Zone Lookup")
	var fails := 0
	
	if DepthSpawner.get_zone_name_for_depth(5.0) != "Sunlight Zone":
		print("  FAIL: 5m should be Sunlight Zone")
		fails += 1
	if DepthSpawner.get_zone_name_for_depth(30.0) != "Twilight Zone":
		print("  FAIL: 30m should be Twilight Zone")
		fails += 1
	if DepthSpawner.get_zone_name_for_depth(75.0) != "Midnight Zone":
		print("  FAIL: 75m should be Midnight Zone")
		fails += 1
	if DepthSpawner.get_zone_name_for_depth(150.0) != "The Abyss":
		print("  FAIL: 150m should be The Abyss")
		fails += 1
		
	return fails


func _test_pearl_resources() -> int:
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
		
	if gold_p.min_depth <= seed_p.min_depth:
		print("  FAIL: Golden pearl min depth (%.1fm) should be deeper than seed pearl (%.1fm)" % [gold_p.min_depth, seed_p.min_depth])
		fails += 1
		
	return fails


func _test_diver_upgrades() -> int:
	print("[Test] Diver & Weight Speed Calculation")
	var fails := 0
	
	var diver := Diver.new()
	diver._ready()
	
	# Default base speed without fins
	GameState.owned_upgrades.clear()
	diver.apply_upgrades()
	if abs(diver.max_speed - 400.0) > 1.0:
		print("  FAIL: Expected base max_speed 400.0, got %.1f" % diver.max_speed)
		fails += 1
		
	# Add Fins level 1
	GameState.owned_upgrades.append(&"fins_1")
	diver.apply_upgrades()
	if abs(diver.max_speed - 500.0) > 1.0:
		print("  FAIL: Expected Fins 1 max_speed 500.0, got %.1f" % diver.max_speed)
		fails += 1
		
	diver.free()
	return fails
