extends Control
## Shop screen for purchasing upgrades with banked pearls.

signal closed

## Costs are set so the first sunlit dive (~60-120 pearls) buys exactly one
## small upgrade, and the full board takes several successful deep runs. The
## old prices totalled 180 for everything, which is roughly 6% of one full
## column — a single golden pearl bought the entire shop twice over, and the
## "the deep is unreachable until you upgrade" gate collapsed on dive one.
const CATALOG: Array[Dictionary] = [
	{
		"id": &"lungs_1",
		"name": "Bigger Lungs I",
		"effect": "Increases base breath capacity from 50s to 75s.",
		"cost": 60,
		"prereq": &""
	},
	{
		"id": &"lungs_2",
		"name": "Bigger Lungs II",
		"effect": "Increases base breath capacity to 100s.",
		"cost": 165,
		"prereq": &"lungs_1"
	},
	{
		"id": &"fins_1",
		"name": "Swift Fins I",
		"effect": "Swim 20% faster, and hard swimming costs less air.",
		"cost": 55,
		"prereq": &""
	},
	{
		"id": &"fins_2",
		"name": "Swift Fins II",
		"effect": "Swim 40% faster, and hard swimming costs less air still.",
		"cost": 140,
		"prereq": &"fins_1"
	},
	{
		"id": &"basket_1",
		"name": "Woven Pearl Basket",
		"effect": "Carry 4.5kg before pearls start slowing you and burning air.",
		"cost": 70,
		"prereq": &""
	},
	{
		"id": &"basket_2",
		"name": "Reinforced Basket",
		"effect": "Carry 6.0kg before the weight penalty begins.",
		"cost": 155,
		"prereq": &"basket_1"
	},
	{
		"id": &"lantern_1",
		"name": "Diver's Lantern",
		"effect": "A wide, bright lamp. The only way to see in the midnight zone.",
		"cost": 95,
		"prereq": &""
	},
	{
		"id": &"wetsuit_1",
		"name": "Padded Wetsuit",
		"effect": "Raises health from 100 to 130.",
		"cost": 80,
		"prereq": &""
	},
	{
		"id": &"wetsuit_2",
		"name": "Plated Wetsuit",
		"effect": "Raises health to 160.",
		"cost": 175,
		"prereq": &"wetsuit_1"
	},
	{
		"id": &"vigor_1",
		"name": "Diver's Vigor",
		"effect": "Raises stamina to 130, so you get more swings before you tire.",
		"cost": 75,
		"prereq": &""
	},
	{
		"id": &"vigor_2",
		"name": "Deep Lungs Training",
		"effect": "Raises stamina to 160.",
		"cost": 160,
		"prereq": &"vigor_1"
	}
]

@onready var money_label: Label = $Panel/Margin/VBox/Header/MoneyLabel
@onready var item_list: ItemList = $Panel/Margin/VBox/Columns/ItemList
@onready var detail_name: Label = $Panel/Margin/VBox/Columns/Detail/NameLabel
@onready var detail_effect: Label = $Panel/Margin/VBox/Columns/Detail/EffectLabel
@onready var detail_cost: Label = $Panel/Margin/VBox/Columns/Detail/CostLabel
@onready var buy_button: Button = $Panel/Margin/VBox/Columns/Detail/BuyButton
@onready var close_button: Button = $Panel/Margin/VBox/CloseButton

var _selected_index: int = 0
## CATALOG entries followed by the consumables, so one list index maps to either.
## Consumables are repeat-buyable up to GameState.MAX_PER_KIND, unlike upgrades.
var _rows: Array = []


func _ready() -> void:
	item_list.item_selected.connect(_on_item_selected)
	buy_button.pressed.connect(_on_buy_pressed)
	close_button.pressed.connect(func() -> void: closed.emit())
	refresh_catalog()


func focus_default() -> void:
	refresh_catalog()
	item_list.grab_focus()


func refresh_catalog() -> void:
	money_label.text = "\u233e %d" % GameState.pearls
	item_list.clear()
	_rows.clear()

	for item in CATALOG:
		_rows.append({"kind": "upgrade", "data": item})
		var label_text: String = item["name"]
		if GameState.has_upgrade(item["id"]):
			label_text += " [OWNED]"
		item_list.add_item(label_text)

	for c in Consumables.all():
		_rows.append({"kind": "consumable", "data": c})
		item_list.add_item("%s  %d/%d" % [c.display_name,
			GameState.consumable_count(c.id), GameState.MAX_PER_KIND])

	if not _rows.is_empty():
		_selected_index = clamp(_selected_index, 0, _rows.size() - 1)
		item_list.select(_selected_index)
		_on_item_selected(_selected_index)


func _on_item_selected(index: int) -> void:
	_selected_index = index
	if index < 0 or index >= _rows.size():
		return
	var row: Dictionary = _rows[index]
	if row["kind"] == "consumable":
		_show_consumable(row["data"] as ConsumableData)
		return
	var item: Dictionary = row["data"]
	var owned: bool = GameState.has_upgrade(String(item["id"]))
	var prereq_ok: bool = String(item["prereq"]) == "" or GameState.has_upgrade(String(item["prereq"]))
	
	detail_name.text = item["name"]
	detail_effect.text = item["effect"]
	
	if owned:
		detail_cost.text = "PURCHASED"
		detail_cost.modulate = Color(0.4, 0.9, 0.4, 1)
		buy_button.disabled = true
		buy_button.text = "Owned"
	elif not prereq_ok:
		detail_cost.text = "LOCKED (Requires prior upgrade)"
		detail_cost.modulate = Color(0.9, 0.4, 0.4, 1)
		buy_button.disabled = true
		buy_button.text = "Locked"
	else:
		detail_cost.text = "COST: %d Pearls" % item["cost"]
		var affordable: bool = GameState.pearls >= item["cost"]
		detail_cost.modulate = Color(1, 1, 1, 1) if affordable else Color(1, 0.4, 0.4, 1)
		buy_button.disabled = not affordable
		buy_button.text = "Buy Upgrade"


## Consumables show stock and re-buy up to the per-kind cap, and say plainly
## that they are used with X or C — otherwise nothing in the shop explains that.
func _show_consumable(c: ConsumableData) -> void:
	var held := GameState.consumable_count(c.id)
	detail_name.text = c.display_name
	detail_effect.text = "%s\n\nHeld: %d / %d. Equip in the Inventory, use with X or C." % [
		c.description, held, GameState.MAX_PER_KIND
	]
	if not GameState.can_buy_consumable(c.id):
		detail_cost.text = "FULL (%d/%d)" % [held, GameState.MAX_PER_KIND]
		detail_cost.modulate = Color(0.4, 0.9, 0.4, 1)
		buy_button.disabled = true
		buy_button.text = "Full"
		return
	detail_cost.text = "COST: %d Pearls" % c.cost
	var affordable: bool = GameState.pearls >= c.cost
	detail_cost.modulate = Color(1, 1, 1, 1) if affordable else Color(1, 0.4, 0.4, 1)
	buy_button.disabled = not affordable
	buy_button.text = "Buy x1"


func _on_buy_pressed() -> void:
	if _selected_index < 0 or _selected_index >= _rows.size():
		return
	var row: Dictionary = _rows[_selected_index]
	if row["kind"] == "consumable":
		var c := row["data"] as ConsumableData
		if GameState.buy_consumable(c.id, c.cost):
			refresh_catalog()
		return
	var item: Dictionary = row["data"]
	if GameState.purchase_upgrade(item["id"], item["cost"]):
		refresh_catalog()
