extends Control
## Shop screen for purchasing upgrades with banked gold coins (earned from selling pearls).
## Displays items in a clean 2-column icon grid without text clipping.

signal closed

const CATALOG: Array[Dictionary] = [
	{
		"id": &"lungs_1",
		"name": "Bigger Lungs 1",
		"effect": "Increases base breath capacity from 50s to 75s.",
		"cost": 60,
		"prereq": &"",
		"icon_path": "res://visuals/items/icons/icon_lungs.tres"
	},
	{
		"id": &"lungs_2",
		"name": "Bigger Lungs 2",
		"effect": "Increases base breath capacity to 100s.",
		"cost": 165,
		"prereq": &"lungs_1",
		"icon_path": "res://visuals/items/icons/icon_lungs.tres"
	},
	{
		"id": &"fins_1",
		"name": "Swift Fins 1",
		"effect": "Swim 20% faster, and hard swimming costs less air.",
		"cost": 55,
		"prereq": &"",
		"icon_path": "res://visuals/items/icons/icon_fins.tres"
	},
	{
		"id": &"fins_2",
		"name": "Swift Fins 2",
		"effect": "Swim 40% faster, and hard swimming costs less air still.",
		"cost": 140,
		"prereq": &"fins_1",
		"icon_path": "res://visuals/items/icons/icon_fins.tres"
	},
	{
		"id": &"basket_1",
		"name": "Pearl Basket 1",
		"effect": "Carry 4.5kg before pearls start slowing you and burning air.",
		"cost": 70,
		"prereq": &"",
		"icon_path": "res://visuals/items/icons/icon_basket.tres"
	},
	{
		"id": &"basket_2",
		"name": "Pearl Basket 2",
		"effect": "Carry 6.0kg before the weight penalty begins.",
		"cost": 155,
		"prereq": &"basket_1",
		"icon_path": "res://visuals/items/icons/icon_basket.tres"
	},
	{
		"id": &"lantern_1",
		"name": "Diver's Lantern",
		"effect": "A wide, bright lamp. The only way to see in the midnight zone.",
		"cost": 95,
		"prereq": &"",
		"icon_path": "res://visuals/items/icons/icon_lantern.tres"
	},
	{
		"id": &"wetsuit_1",
		"name": "Wetsuit 1",
		"effect": "Raises health from 100 to 130.",
		"cost": 80,
		"prereq": &"",
		"icon_path": "res://visuals/items/icons/icon_wetsuit.tres"
	},
	{
		"id": &"wetsuit_2",
		"name": "Wetsuit 2",
		"effect": "Raises health to 160.",
		"cost": 175,
		"prereq": &"wetsuit_1",
		"icon_path": "res://visuals/items/icons/icon_wetsuit.tres"
	},
	{
		"id": &"vigor_1",
		"name": "Vigor 1",
		"effect": "Raises stamina to 130, so you get more swings before you tire.",
		"cost": 75,
		"prereq": &"",
		"icon_path": "res://visuals/items/icons/icon_vigor.tres"
	},
	{
		"id": &"vigor_2",
		"name": "Vigor 2",
		"effect": "Raises stamina to 160.",
		"cost": 160,
		"prereq": &"vigor_1",
		"icon_path": "res://visuals/items/icons/icon_vigor.tres"
	}
]

@onready var money_label: Label = $Panel/Margin/VBox/Header/MoneyLabel
@onready var item_grid: GridContainer = $Panel/Margin/VBox/Columns/Scroll/ItemGrid
@onready var detail_icon: TextureRect = $Panel/Margin/VBox/Columns/Detail/Header/DetailIcon
@onready var detail_name: Label = $Panel/Margin/VBox/Columns/Detail/Header/NameLabel
@onready var detail_effect: Label = $Panel/Margin/VBox/Columns/Detail/EffectLabel
@onready var detail_cost: Label = $Panel/Margin/VBox/Columns/Detail/CostLabel
@onready var buy_button: Button = $Panel/Margin/VBox/Columns/Detail/BuyButton
@onready var close_button: Button = $Panel/Margin/VBox/CloseButton

var _selected_index: int = 0
var _rows: Array = []
var _grid_buttons: Array[Button] = []


func _ready() -> void:
	buy_button.pressed.connect(_on_buy_pressed)
	close_button.pressed.connect(func() -> void: closed.emit())
	refresh_catalog()


func focus_default() -> void:
	refresh_catalog()
	if not _grid_buttons.is_empty():
		_grid_buttons[clampi(_selected_index, 0, _grid_buttons.size() - 1)].grab_focus()


func refresh_catalog() -> void:
	money_label.text = "Gold Coins: %d" % GameState.pearls
	_rows.clear()
	_grid_buttons.clear()

	for child in item_grid.get_children():
		child.queue_free()

	# Upgrades
	for item in CATALOG:
		_rows.append({"kind": "upgrade", "data": item})

	# Consumables
	for c in Consumables.all():
		_rows.append({"kind": "consumable", "data": c})

	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var button := _create_grid_button(i, row)
		item_grid.add_child(button)
		_grid_buttons.append(button)

	if not _rows.is_empty():
		_selected_index = clampi(_selected_index, 0, _rows.size() - 1)
		_select_item(_selected_index)


func _create_grid_button(index: int, row: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(108, 38)
	btn.focus_mode = Control.FOCUS_ALL
	btn.clip_text = true

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 3)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 3)
	margin.add_theme_constant_override("margin_bottom", 2)
	btn.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	margin.add_child(hbox)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(16, 16)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icon_rect)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	hbox.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.add_theme_font_size_override("font_size", 8)
	name_lbl.clip_text = true
	vbox.add_child(name_lbl)

	var badge_lbl := Label.new()
	badge_lbl.add_theme_font_size_override("font_size", 7)
	badge_lbl.clip_text = true
	vbox.add_child(badge_lbl)

	if row["kind"] == "upgrade":
		var item: Dictionary = row["data"]
		if ResourceLoader.exists(item["icon_path"]):
			icon_rect.texture = load(item["icon_path"])
		name_lbl.text = item["name"]
		var owned: bool = GameState.has_upgrade(String(item["id"]))
		if owned:
			badge_lbl.text = "OWNED"
			badge_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
			btn.modulate = Color(0.8, 1.0, 0.8)
		else:
			badge_lbl.text = "%d Coins" % item["cost"]
			var prereq_ok: bool = String(item["prereq"]) == "" or GameState.has_upgrade(String(item["prereq"]))
			if not prereq_ok:
				badge_lbl.text = "LOCKED"
				badge_lbl.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
				btn.modulate = Color(0.6, 0.6, 0.6, 0.7)
			else:
				badge_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	else:
		var c := row["data"] as ConsumableData
		icon_rect.texture = c.icon
		name_lbl.text = c.display_name
		var held := GameState.consumable_count(c.id)
		badge_lbl.text = "%d/%d (%d Coins)" % [held, GameState.MAX_PER_KIND, c.cost]
		if held >= GameState.MAX_PER_KIND:
			badge_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
		else:
			badge_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.35))

	btn.pressed.connect(func() -> void: _select_item(index))
	btn.focus_entered.connect(func() -> void: _select_item(index))
	return btn


func _select_item(index: int) -> void:
	_selected_index = index
	if index < 0 or index >= _rows.size():
		return

	var row: Dictionary = _rows[index]
	if row["kind"] == "consumable":
		_show_consumable(row["data"] as ConsumableData)
		return

	var item: Dictionary = row["data"]
	if ResourceLoader.exists(item["icon_path"]):
		detail_icon.texture = load(item["icon_path"])
	else:
		detail_icon.texture = null

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
		detail_cost.text = "COST: %d Coins" % item["cost"]
		var affordable: bool = GameState.pearls >= item["cost"]
		detail_cost.modulate = Color(1, 1, 1, 1) if affordable else Color(1, 0.4, 0.4, 1)
		buy_button.disabled = not affordable
		buy_button.text = "Buy Upgrade"


func _show_consumable(c: ConsumableData) -> void:
	detail_icon.texture = c.icon
	var held := GameState.consumable_count(c.id)
	detail_name.text = c.display_name
	detail_effect.text = "%s\n\nHeld: %d / %d. Equip in Inventory." % [
		c.description, held, GameState.MAX_PER_KIND
	]

	if not GameState.can_buy_consumable(c.id):
		detail_cost.text = "FULL STOCK (%d/%d)" % [held, GameState.MAX_PER_KIND]
		detail_cost.modulate = Color(0.4, 0.9, 0.4, 1)
		buy_button.disabled = true
		buy_button.text = "Full"
		return

	detail_cost.text = "COST: %d Coins" % c.cost
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
