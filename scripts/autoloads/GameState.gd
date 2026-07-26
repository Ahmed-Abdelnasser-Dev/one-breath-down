extends Node
## Persistent progression: banked currency + owned upgrades.

## Canonical world-space -> metres conversion. Every other script that needs
## depth in metres reads this constant rather than keeping its own copy.
const PIXELS_PER_METRE := 32.0

var pearls: int = 0
var owned_upgrades: Array[StringName] = []
var best_depth_m: int = 0

const BASE_WEIGHT_CAPACITY := 3.0

## Kilograms of pearls carried before the speed/oxygen penalty starts. This used
## to be a bare `var = 3.0` that nothing ever wrote, so the Woven Pearl Basket
## was sold in the shop and did literally nothing.
var weight_capacity: float = BASE_WEIGHT_CAPACITY

const SAVE_PATH := "user://save.cfg"

## Consumables. Two equip slots (X and C), each holding one KIND, each carrying
## up to three charges — so a loadout is at most two kinds, three deep. That's
## the rule: three jets and three charges is fine, three *different* kinds isn't.
const CONSUMABLE_SLOTS := 2
const MAX_PER_KIND := 3

## id -> charges owned (0..MAX_PER_KIND).
var consumable_stock: Dictionary = {}
## Slot index -> consumable id, or &"" for an empty slot. Index 0 is X, 1 is C.
var equipped: Array[StringName] = [&"", &""]


func consumable_count(id: StringName) -> int:
	return int(consumable_stock.get(id, 0))


func can_buy_consumable(id: StringName) -> bool:
	return consumable_count(id) < MAX_PER_KIND


## Buying tops up a charge and auto-equips into a free slot, so a first purchase
## is immediately usable without a trip through the inventory screen.
func buy_consumable(id: StringName, cost: int) -> bool:
	if not can_buy_consumable(id):
		return false
	if not spend_pearls(cost):
		return false
	consumable_stock[id] = consumable_count(id) + 1
	if not equipped.has(id):
		var free := equipped.find(&"")
		if free != -1:
			equipped[free] = id
	Events.consumables_changed.emit()
	save()
	return true


## Equipping is a swap: a kind already in the other slot moves rather than
## appearing twice, which would let one kind occupy both slots.
func equip_consumable(slot: int, id: StringName) -> void:
	if slot < 0 or slot >= CONSUMABLE_SLOTS:
		return
	var existing := equipped.find(id)
	if existing != -1 and existing != slot:
		equipped[existing] = equipped[slot]
	equipped[slot] = id
	Events.consumables_changed.emit()
	save()


func clear_slot(slot: int) -> void:
	if slot < 0 or slot >= CONSUMABLE_SLOTS:
		return
	equipped[slot] = &""
	Events.consumables_changed.emit()
	save()


## Spends one charge of whatever is in `slot`. Returns the id actually consumed,
## or &"" if the slot was empty or dry.
func consume_slot(slot: int) -> StringName:
	if slot < 0 or slot >= CONSUMABLE_SLOTS:
		return &""
	var id: StringName = equipped[slot]
	if id == &"" or consumable_count(id) <= 0:
		return &""
	consumable_stock[id] = consumable_count(id) - 1
	Events.consumables_changed.emit()
	save()
	return id


func _ready() -> void:
	load_game()
	_apply_capacity_upgrades()
	Events.upgrade_purchased.connect(func(_id: StringName) -> void: _apply_capacity_upgrades())


func _apply_capacity_upgrades() -> void:
	match get_upgrade_level("basket_"):
		0: weight_capacity = BASE_WEIGHT_CAPACITY
		1: weight_capacity = 4.5
		_: weight_capacity = 6.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()


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


## Reports the current dive depth (whole metres). Only updates/saves/emits
## when it's a new record — called every time depth_changed fires, so this
## must stay cheap on the non-record path.
func report_depth(m: int) -> void:
	if m > best_depth_m:
		best_depth_m = m
		Events.new_best_depth.emit(best_depth_m)
		save()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Wipes progression and the save file — backs the main menu's "New Game".
func reset_progress() -> void:
	pearls = 0
	owned_upgrades = []
	best_depth_m = 0
	weight_capacity = BASE_WEIGHT_CAPACITY
	consumable_stock = {}
	equipped = [&"", &""]
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "pearls", pearls)
	cfg.set_value("progress", "upgrades", owned_upgrades)
	cfg.set_value("progress", "best_depth_m", best_depth_m)
	cfg.set_value("progress", "consumables", consumable_stock)
	cfg.set_value("progress", "equipped", equipped)
	cfg.save(SAVE_PATH)


func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	pearls = cfg.get_value("progress", "pearls", 0)
	owned_upgrades = cfg.get_value("progress", "upgrades", [] as Array[StringName])
	best_depth_m = cfg.get_value("progress", "best_depth_m", 0)
	consumable_stock = cfg.get_value("progress", "consumables", {})
	var saved_slots: Array = cfg.get_value("progress", "equipped", [])
	for i in CONSUMABLE_SLOTS:
		equipped[i] = StringName(saved_slots[i]) if i < saved_slots.size() else &""