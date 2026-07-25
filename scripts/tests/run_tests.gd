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
	failures += _test_enemy_band_selection()
	failures += _test_health_and_stamina()

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


func _test_enemy_band_selection() -> int:
	print("[Test] EnemySpawner Depth-Band Selection")
	var fails := 0

	var shallow: EnemyData = load("res://data/enemies/turtle.tres")     # band 0-55m
	var deep: EnemyData = load("res://data/enemies/octopus.tres")      # band 140-200m

	if shallow == null or deep == null:
		print("  FAIL: Enemy data resources could not be loaded")
		return fails + 1

	var spawner := EnemySpawner.new()
	spawner.enemy_types = [shallow, deep]
	spawner.rng.seed = 1

	var pick_shallow := spawner._pick_type_for_depth(20)
	if pick_shallow == null or pick_shallow.id != shallow.id:
		print("  FAIL: Depth 20m should only match turtle, got %s" % [pick_shallow.id if pick_shallow else "null"])
		fails += 1

	var pick_deep := spawner._pick_type_for_depth(180)
	if pick_deep == null or pick_deep.id != deep.id:
		print("  FAIL: Depth 180m should only match octopus, got %s" % [pick_deep.id if pick_deep else "null"])
		fails += 1

	var pick_none := spawner._pick_type_for_depth(100)
	if pick_none != null:
		print("  FAIL: Depth 100m matches neither band, expected null, got %s" % pick_none.id)
		fails += 1

	spawner.free()
	return fails


func _test_health_and_stamina() -> int:
	print("[Test] HealthComponent & StaminaComponent")
	var fails := 0

	var health := HealthComponent.new()
	health._ready()

	if abs(health.current_hp - health.max_hp) > 0.01:
		print("  FAIL: HealthComponent should start at full HP")
		fails += 1
	if not health.can_be_hit():
		print("  FAIL: HealthComponent should start hittable (no i-frames yet)")
		fails += 1

	health.apply_damage(30.0)
	if abs(health.current_hp - (health.max_hp - 30.0)) > 0.01:
		print("  FAIL: Expected HP %.1f after 30 damage, got %.1f" % [health.max_hp - 30.0, health.current_hp])
		fails += 1
	if health.can_be_hit():
		print("  FAIL: HealthComponent should be invulnerable immediately after taking damage")
		fails += 1

	# A second hit during the i-frame window must be a no-op.
	health.apply_damage(30.0)
	if abs(health.current_hp - (health.max_hp - 30.0)) > 0.01:
		print("  FAIL: A hit during i-frames should not apply additional damage")
		fails += 1

	health.free()

	var stamina := StaminaComponent.new()
	stamina._ready()

	if not stamina.can_spend():
		print("  FAIL: StaminaComponent should start able to afford an attack")
		fails += 1

	if not stamina.spend():
		print("  FAIL: First spend() should succeed")
		fails += 1
	var expected_after_spend := stamina.max_stamina - stamina.attack_cost
	if abs(stamina.current_stamina - expected_after_spend) > 0.01:
		print("  FAIL: Expected stamina %.1f after spend, got %.1f" % [expected_after_spend, stamina.current_stamina])
		fails += 1

	# Draining the pool below one more attack_cost must make spend() refuse cleanly.
	stamina.current_stamina = stamina.attack_cost - 1.0
	if stamina.spend():
		print("  FAIL: spend() should refuse when stamina is insufficient")
		fails += 1

	stamina.free()
	return fails
