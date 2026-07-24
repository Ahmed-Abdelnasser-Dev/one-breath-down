extends Control
## Shop screen for purchasing upgrades with banked pearls.

signal closed

const CATALOG: Array[Dictionary] = [
	{
		"id": &"lungs_1",
		"name": "Bigger Lungs I",
		"effect": "Increases base breath capacity from 30s to 45s.",
		"cost": 15,
		"prereq": &""
	},
	{
		"id": &"lungs_2",
		"name": "Bigger Lungs II",
		"effect": "Increases base breath capacity to 60s.",
		"cost": 40,
		"prereq": &"lungs_1"
	},
	{
		"id": &"fins_1",
		"name": "Swift Fins I",
		"effect": "Increases swim speed by 25% and reduces exertion oxygen drain.",
		"cost": 20,
		"prereq": &""
	},
	{
		"id": &"fins_2",
		"name": "Swift Fins II",
		"effect": "Increases swim speed by 50% total.",
		"cost": 50,
		"prereq": &"fins_1"
	},
	{
		"id": &"basket_1",
		"name": "Woven Pearl Basket",
		"effect": "Reduces speed and oxygen penalties from carried pearl weight.",
		"cost": 25,
		"prereq": &""
	},
	{
		"id": &"lantern_1",
		"name": "Diver's Lantern",
		"effect": "Provides bright illumination when descending into dark twilight and midnight depths.",
		"cost": 30,
		"prereq": &""
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


func _ready() -> void:
	item_list.item_selected.connect(_on_item_selected)
	buy_button.pressed.connect(_on_buy_pressed)
	close_button.pressed.connect(func() -> void: closed.emit())
	refresh_catalog()


func focus_default() -> void:
	refresh_catalog()
	item_list.grab_focus()


func refresh_catalog() -> void:
	money_label.text = "⌾ %d" % GameState.pearls
	item_list.clear()
	
	for item in CATALOG:
		var owned := GameState.has_upgrade(item["id"])
		var label_text: String = item["name"]
		if owned:
			label_text += " [OWNED]"
		item_list.add_item(label_text)
	
	if CATALOG.size() > 0:
		_selected_index = clamp(_selected_index, 0, CATALOG.size() - 1)
		item_list.select(_selected_index)
		_on_item_selected(_selected_index)


func _on_item_selected(index: int) -> void:
	_selected_index = index
	var item: Dictionary = CATALOG[index]
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


func _on_buy_pressed() -> void:
	if _selected_index < 0 or _selected_index >= CATALOG.size():
		return
	var item: Dictionary = CATALOG[_selected_index]
	if GameState.purchase_upgrade(item["id"], item["cost"]):
		refresh_catalog()
