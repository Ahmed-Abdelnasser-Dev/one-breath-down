extends Object
class_name Consumables
## Registry for the consumable catalogue. Everything that needs to look an item
## up by id — shop, inventory, HUD bar, the diver — goes through here so the
## list of items lives in exactly one place.

const PATHS: Array[String] = [
	"res://data/consumables/jet_boost.tres",
	"res://data/consumables/air_bubble.tres",
	"res://data/consumables/patch_kit.tres",
	"res://data/consumables/depth_charge.tres",
	"res://data/consumables/ballast_weight.tres",
]

static var _all: Array[ConsumableData] = []
static var _by_id: Dictionary = {}


static func all() -> Array[ConsumableData]:
	if _all.is_empty():
		for path in PATHS:
			var res := load(path) as ConsumableData
			if res != null:
				_all.append(res)
				_by_id[res.id] = res
	return _all


static func get_by_id(id: StringName) -> ConsumableData:
	if _by_id.is_empty():
		all()
	return _by_id.get(id, null)
