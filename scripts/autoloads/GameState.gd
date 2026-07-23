extends Node
## Persistent progression: banked currency + owned upgrades.

var pearls: int = 0
var owned_upgrades: Array[StringName] = []
var best_depth: float = 0.0

const SAVE_PATH := "user://save.cfg"

func has_upgrade(id: StringName) -> bool:
	return id in owned_upgrades

func add_pearls(amount: int) -> void:
	pearls += amount
	Events.pearls_banked.emit(amount)

func spend_pearls(amount: int) -> bool:
	if pearls < amount:
		return false
	pearls -= amount
	return true

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