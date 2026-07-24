extends Node
## Test runner scene node for execution within Godot environment with full autoload support.

func _ready() -> void:
	print("--- Running One Breath Down Test Runner Scene (Phase 2) ---")
	var failures: int = 0
	
	failures += _test_game_state()
	failures += _test_zone_manager()
	failures += _test_pearl_resources()
	failures += _test_diver_upgrades()
	failures += _test_report_depth()

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


func _test_zone_manager() -> int:
	print("[Test] ZoneManager Depth Resolution")
	var fails := 0
	
	var zm := ZoneManager.new()
	zm._ready()

	zm._on_depth_changed(0)
	if zm.current_zone.id != &"sunlit":
		print("  FAIL: 0m should be Sunlit zone, got %s" % zm.current_zone.id)
		fails += 1

	zm._on_depth_changed(60)
	if zm.current_zone.id != &"twilight":
		print("  FAIL: 60m should be Twilight zone, got %s" % zm.current_zone.id)
		fails += 1

	zm._on_depth_changed(160)
	if zm.current_zone.id != &"midnight":
		print("  FAIL: 160m should be Midnight zone, got %s" % zm.current_zone.id)
		fails += 1

	zm.free()
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
		
	if gold_p.min_depth_m <= seed_p.min_depth_m:
		print("  FAIL: Golden pearl min depth (%dm) should be deeper than seed pearl (%dm)" % [gold_p.min_depth_m, seed_p.min_depth_m])
		fails += 1
		
	return fails


func _test_diver_upgrades() -> int:
	print("[Test] Diver & Weight Speed Calculation")
	var fails := 0
	
	var diver := Diver.new()
	diver._ready()
	
	# Default base speed without fins (160.0)
	GameState.owned_upgrades.clear()
	diver.apply_upgrades()
	if abs(diver.max_speed - 160.0) > 1.0:
		print("  FAIL: Expected base max_speed 160.0, got %.1f" % diver.max_speed)
		fails += 1

	# Add Fins level 1 (192.0)
	GameState.owned_upgrades.append(&"fins_1")
	diver.apply_upgrades()
	if abs(diver.max_speed - 192.0) > 1.0:
		print("  FAIL: Expected Fins 1 max_speed 192.0, got %.1f" % diver.max_speed)
		fails += 1

	diver.free()
	return fails


func _test_report_depth() -> int:
	print("[Test] GameState.report_depth (best-depth persistence)")
	var fails := 0

	GameState.best_depth_m = 0

	GameState.report_depth(10)
	if GameState.best_depth_m != 10:
		print("  FAIL: Expected best_depth_m 10 after first report, got %d" % GameState.best_depth_m)
		fails += 1

	# Lower depth than the record must be a no-op
	GameState.report_depth(5)
	if GameState.best_depth_m != 10:
		print("  FAIL: report_depth(5) should not lower an existing record of 10, got %d" % GameState.best_depth_m)
		fails += 1

	# New record raises it
	GameState.report_depth(25)
	if GameState.best_depth_m != 25:
		print("  FAIL: Expected best_depth_m 25 after new record, got %d" % GameState.best_depth_m)
		fails += 1

	return fails
