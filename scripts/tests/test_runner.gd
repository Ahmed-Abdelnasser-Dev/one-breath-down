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
	failures += _test_enemy_band_selection()
	failures += _test_health_and_stamina()
	failures += _test_prop_spawner()

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


func _test_enemy_band_selection() -> int:
	print("[Test] EnemySpawner Depth-Band Selection")
	var fails := 0

	var shallow: EnemyData = load("res://data/enemies/turtle.tres")     # band 0-30m
	var deep: EnemyData = load("res://data/enemies/octopus.tres")      # band 120-160m

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

	var pick_deep := spawner._pick_type_for_depth(140)
	if pick_deep == null or pick_deep.id != deep.id:
		print("  FAIL: Depth 140m should only match octopus, got %s" % [pick_deep.id if pick_deep else "null"])
		fails += 1

	var pick_none := spawner._pick_type_for_depth(60)
	if pick_none != null:
		print("  FAIL: Depth 60m matches neither band, expected null, got %s" % pick_none.id)
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


func _test_prop_spawner() -> int:
	print("[Test] PropSpawner background props generation & blue overlay tint")
	var fails := 0

	var spawner := PropSpawner.new()
	spawner._ready()

	var child_count := spawner.get_child_count()
	if child_count == 0:
		print("  FAIL: PropSpawner should generate background prop children")
		fails += 1

	var sprite_count := 0
	var blue_tinted_count := 0
	for child in spawner.get_children():
		if child is Sprite2D:
			sprite_count += 1
			# Verify blue background wash overlay tint is applied
			if child.modulate.b > 0.3:
				blue_tinted_count += 1

	if sprite_count == 0:
		print("  FAIL: PropSpawner should generate Sprite2D background props")
		fails += 1

	if blue_tinted_count < sprite_count * 0.9:
		print("  FAIL: Background props should have blue underwater wash overlay applied")
		fails += 1

	spawner.free()
	return fails

