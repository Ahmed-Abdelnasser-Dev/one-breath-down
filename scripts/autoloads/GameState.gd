extends Node
## Persistent progression: banked currency + owned upgrades.

var pearls: int = 0
var owned_upgrades: Array[StringName] = []
var best_depth: float = 0.0

const SAVE_PATH := "user://save.cfg"


func _ready() -> void:
	load_game()


func has_upgrade(id: StringName) -> bool:
	return id in owned_upgrades


func add_pearls(amount: int) -> void:
	pearls += amount
	Events.pearls_banked.emit(amount)
	save()


func spend_pearls(amount: int) -> bool:
	if pearls < amount:
		return false
	pearls -= amount
	save()
	return true


func purchase_upgrade(id: StringName, cost: int) -> bool:
	if has_upgrade(id):
		return false
	if spend_pearls(cost):
		owned_upgrades.append(id)
		Events.upgrade_purchased.emit(id)
		save()
		print("Purchased upgrade: %s (remaining pearls: %d)" % [id, pearls])
		return true
	return false


func get_upgrade_level(prefix: String) -> int:
	var level := 0
	for upg in owned_upgrades:
		var str_id := String(upg)
		if str_id.begins_with(prefix):
			var lvl_str := str_id.get_slice("_", 1)
			if lvl_str.is_valid_int():
				level = max(level, lvl_str.to_int())
	return level


func update_best_depth(depth: float) -> void:
	if depth > best_depth:
		best_depth = depth
		save()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "pearls", pearls)
	cfg.set_value("progress", "upgrades", owned_upgrades)
	cfg.set_value("progress", "best_depth", best_depth)
	cfg.save(SAVE_PATH)


func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	pearls = cfg.get_value("progress", "pearls", 0)
	owned_upgrades = cfg.get_value("progress", "upgrades", [] as Array[StringName])
	best_depth = cfg.get_value("progress", "best_depth", 0.0)