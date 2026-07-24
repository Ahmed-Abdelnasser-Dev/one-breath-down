extends SceneTree
## Command-line test runner for One Breath Down Phase 2 logic.

const GameStateScript = preload("res://scripts/autoloads/GameState.gd")
const ZoneManagerScript = preload("res://scripts/world/ZoneManager.gd")
const ZoneDataScript = preload("res://scripts/resources/ZoneData.gd")

var game_state: Node
var zone_manager: Node


func _init() -> void:
	print("--- Running One Breath Down Core Test Suite (Phase 2) ---")
	
	if root.has_node("GameState"):
		game_state = root.get_node("GameState")
	else:
		game_state = GameStateScript.new()
		root.add_child(game_state)
		
	if root.has_node("ZoneManager"):
		zone_manager = root.get_node("ZoneManager")
	else:
		zone_manager = ZoneManagerScript.new()
		root.add_child(zone_manager)

	var failures: int = 0
	failures += _test_game_state()
	failures += _test_zone_manager()
	failures += _test_pearl_generation()
	failures += _test_diver_upgrades_and_weight()
	failures += _test_report_depth()

	if failures == 0:
		print("SUCCESS: All Phase 2 tests passed cleanly!")
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


func _test_zone_manager() -> int:
	print("[Test] ZoneManager Depth Resolution")
	var fails := 0
	
	zone_manager._on_depth_changed(0)
	if zone_manager.current_zone.id != &"sunlit":
		print("  FAIL: 0m should be Sunlit zone, got %s" % zone_manager.current_zone.id)
		fails += 1

	zone_manager._on_depth_changed(60)
	if zone_manager.current_zone.id != &"twilight":
		print("  FAIL: 60m should be Twilight zone, got %s" % zone_manager.current_zone.id)
		fails += 1

	zone_manager._on_depth_changed(160)
	if zone_manager.current_zone.id != &"midnight":
		print("  FAIL: 160m should be Midnight zone, got %s" % zone_manager.current_zone.id)
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
		
	if gold_p.min_depth_m <= seed_p.min_depth_m:
		print("  FAIL: Golden pearl min depth (%dm) should be deeper than seed pearl (%dm)" % [gold_p.min_depth_m, seed_p.min_depth_m])
		fails += 1

	return fails


func _test_diver_upgrades_and_weight() -> int:
	print("[Test] Diver & Weight Speed Calculation")
	var fails := 0

	var diver := Diver.new()
	diver._ready()

	# Default base speed without fins (base_max_speed = 160.0)
	game_state.owned_upgrades.clear()
	diver.apply_upgrades()
	if abs(diver.max_speed - 160.0) > 1.0:
		print("  FAIL: Expected base max_speed 160.0, got %.1f" % diver.max_speed)
		fails += 1

	# Add Fins level 1 (192.0)
	game_state.owned_upgrades.append(&"fins_1")
	diver.apply_upgrades()
	if abs(diver.max_speed - 192.0) > 1.0:
		print("  FAIL: Expected Fins 1 max_speed 192.0, got %.1f" % diver.max_speed)
		fails += 1

	# Test weight penalty formula
	diver.carried_weight = GameState.weight_capacity + 2.0
	diver.apply_upgrades()
	# over = 2.0 -> mult = 1 / (1 + 2.0 * 0.18) = 1 / 1.36 ~= 0.735 -> speed ~ 141.1
	var expected_speed := 192.0 / (1.0 + 2.0 * 0.18)
	if abs(diver.max_speed - expected_speed) > 1.0:
		print("  FAIL: Expected overweight max_speed %.1f, got %.1f" % [expected_speed, diver.max_speed])
		fails += 1

	diver.free()
	return fails


func _test_report_depth() -> int:
	print("[Test] GameState.report_depth (best-depth persistence)")
	var fails := 0

	game_state.best_depth_m = 0

	game_state.report_depth(10)
	if game_state.best_depth_m != 10:
		print("  FAIL: Expected best_depth_m 10 after first report, got %d" % game_state.best_depth_m)
		fails += 1

	# Lower depth than the record must be a no-op
	game_state.report_depth(5)
	if game_state.best_depth_m != 10:
		print("  FAIL: report_depth(5) should not lower an existing record of 10, got %d" % game_state.best_depth_m)
		fails += 1

	# New record raises it
	game_state.report_depth(25)
	if game_state.best_depth_m != 25:
		print("  FAIL: Expected best_depth_m 25 after new record, got %d" % game_state.best_depth_m)
		fails += 1

	return fails
