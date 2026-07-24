extends Control
## Display-only shop shell: lists the GDD's upgrade set with placeholder
## costs and shows the before/after-style detail pane. Purchasing isn't
## wired yet (GameState.spend_pearls exists and is ready for it later).

signal closed

const UPGRADES: Array[Dictionary] = [
	{"name": "Bigger Lungs", "effect": "Increases base breath duration.", "cost": 100},
	{"name": "Fins", "effect": "Faster swim speed, less oxygen spent per metre.", "cost": 120},
	{"name": "Knife", "effect": "Escape nets instantly instead of losing time.", "cost": 80},
	{"name": "Weighted Belt", "effect": "Sink faster; harder to control ascent. Risk item.", "cost": 60},
	{"name": "Lantern", "effect": "Visibility in deep zones; helps avoid ambush hazards.", "cost": 90},
	{"name": "Pearl Basket", "effect": "Raises the weight threshold before the speed penalty kicks in.", "cost": 110},
]

@onready var money_label: Label = $Panel/Margin/VBox/Header/MoneyLabel
@onready var item_list: ItemList = $Panel/Margin/VBox/Columns/ItemList
@onready var detail_name: Label = $Panel/Margin/VBox/Columns/Detail/NameLabel
@onready var detail_effect: Label = $Panel/Margin/VBox/Columns/Detail/EffectLabel
@onready var detail_cost: Label = $Panel/Margin/VBox/Columns/Detail/CostLabel
@onready var close_button: Button = $Panel/Margin/VBox/CloseButton


func _ready() -> void:
	for upgrade in UPGRADES:
		item_list.add_item(upgrade["name"])
	item_list.item_selected.connect(_on_item_selected)
	close_button.pressed.connect(func() -> void: closed.emit())
	if not UPGRADES.is_empty():
		item_list.select(0)
		_on_item_selected(0)


func focus_default() -> void:
	_refresh_money()
	item_list.grab_focus()


func _refresh_money() -> void:
	money_label.text = "⌾ %d" % GameState.pearls


func _on_item_selected(index: int) -> void:
	var upgrade: Dictionary = UPGRADES[index]
	detail_name.text = upgrade["name"]
	detail_effect.text = upgrade["effect"]
	detail_cost.text = "COST %d" % upgrade["cost"]
	var affordable: bool = GameState.pearls >= upgrade["cost"]
	detail_cost.modulate = Color(1, 1, 1, 1) if affordable else Color(1, 0.4, 0.4, 1)
