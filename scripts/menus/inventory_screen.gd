extends Control
## Inventory & Loadout screen. Allows equipping bought consumables into dive slots X and C,
## displaying consumables in a 2-column icon grid, and presenting a clean diver stats summary.

signal closed

@onready var run_manager: RunManager = get_parent().get_parent()
@onready var carry_weight_label: Label = $Panel/Margin/VBox/Header/CarryWeightLabel

@onready var slot1_key_lbl: Label = $Panel/Margin/VBox/EquippedRow/Slot1Panel/Slot1HBox/Slot1Key
@onready var slot1_icon: TextureRect = $Panel/Margin/VBox/EquippedRow/Slot1Panel/Slot1HBox/Slot1Icon
@onready var slot1_lbl: Label = $Panel/Margin/VBox/EquippedRow/Slot1Panel/Slot1HBox/Slot1Label
@onready var slot1_clear_btn: Button = $Panel/Margin/VBox/EquippedRow/Slot1Panel/Slot1HBox/Slot1UnequipBtn

@onready var slot2_key_lbl: Label = $Panel/Margin/VBox/EquippedRow/Slot2Panel/Slot2HBox/Slot2Key
@onready var slot2_icon: TextureRect = $Panel/Margin/VBox/EquippedRow/Slot2Panel/Slot2HBox/Slot2Icon
@onready var slot2_lbl: Label = $Panel/Margin/VBox/EquippedRow/Slot2Panel/Slot2HBox/Slot2Label
@onready var slot2_clear_btn: Button = $Panel/Margin/VBox/EquippedRow/Slot2Panel/Slot2HBox/Slot2UnequipBtn

@onready var item_grid: GridContainer = $Panel/Margin/VBox/Columns/Scroll/ItemGrid
@onready var detail_icon: TextureRect = $Panel/Margin/VBox/Columns/Detail/Header/DetailIcon
@onready var detail_name: Label = $Panel/Margin/VBox/Columns/Detail/Header/NameLabel
@onready var detail_desc: Label = $Panel/Margin/VBox/Columns/Detail/DescriptionLabel
@onready var detail_stock: Label = $Panel/Margin/VBox/Columns/Detail/StockLabel
@onready var equip_slot1_btn: Button = $Panel/Margin/VBox/Columns/Detail/EquipSlot1Btn
@onready var equip_slot2_btn: Button = $Panel/Margin/VBox/Columns/Detail/EquipSlot2Btn

@onready var stats_summary_label: Label = $Panel/Margin/VBox/StatsSummaryLabel
@onready var close_button: Button = $Panel/Margin/VBox/CloseButton

var _selected_index: int = 0
var _consumables: Array[ConsumableData] = []
var _grid_buttons: Array[Button] = []


func _ready() -> void:
	close_button.pressed.connect(func() -> void: closed.emit())
	slot1_clear_btn.pressed.connect(func() -> void: GameState.clear_slot(0))
	slot2_clear_btn.pressed.connect(func() -> void: GameState.clear_slot(1))
	equip_slot1_btn.pressed.connect(func() -> void: _equip_selected(0))
	equip_slot2_btn.pressed.connect(func() -> void: _equip_selected(1))

	Events.consumables_changed.connect(_refresh)


func focus_default() -> void:
	_refresh()
	if not _grid_buttons.is_empty():
		_grid_buttons[clampi(_selected_index, 0, _grid_buttons.size() - 1)].grab_focus()
	else:
		close_button.grab_focus()


func _refresh() -> void:
	var key1 := _slot_key(0)
	var key2 := _slot_key(1)
	slot1_key_lbl.text = "[%s]" % key1
	slot2_key_lbl.text = "[%s]" % key2

	equip_slot1_btn.text = "Equip [%s]" % key1
	equip_slot2_btn.text = "Equip [%s]" % key2

	# Carry weight
	if run_manager != null and run_manager.diver != null:
		carry_weight_label.text = "Carry %.2f / %.1f kg" % [
			run_manager.diver.carried_weight, GameState.weight_capacity
		]
	else:
		carry_weight_label.text = "Capacity: %.1f kg" % GameState.weight_capacity

	# Equipped slots status
	_update_equipped_slot_ui(0, slot1_icon, slot1_lbl, slot1_clear_btn)
	_update_equipped_slot_ui(1, slot2_icon, slot2_lbl, slot2_clear_btn)

	# Grid refresh
	_consumables = Consumables.all()
	_grid_buttons.clear()

	for child in item_grid.get_children():
		child.queue_free()

	for i in _consumables.size():
		var c := _consumables[i]
		var btn := _create_grid_button(i, c)
		item_grid.add_child(btn)
		_grid_buttons.append(btn)

	if not _consumables.is_empty():
		_selected_index = clampi(_selected_index, 0, _consumables.size() - 1)
		_select_consumable(_selected_index)

	# Diver stats summary
	_update_stats_summary()


func _update_equipped_slot_ui(slot_idx: int, icon_rect: TextureRect, label: Label, clear_btn: Button) -> void:
	var id: StringName = GameState.equipped[slot_idx]
	var data := Consumables.get_by_id(id) if id != &"" else null
	if data != null:
		icon_rect.texture = data.icon
		var count := GameState.consumable_count(id)
		label.text = "%s (x%d)" % [data.display_name, count]
		clear_btn.disabled = false
	else:
		icon_rect.texture = null
		label.text = "Empty"
		clear_btn.disabled = true


func _create_grid_button(index: int, c: ConsumableData) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(102, 38)
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
	icon_rect.texture = c.icon
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
	name_lbl.text = c.display_name
	name_lbl.add_theme_font_size_override("font_size", 8)
	name_lbl.clip_text = true
	vbox.add_child(name_lbl)

	var count := GameState.consumable_count(c.id)
	var count_lbl := Label.new()
	count_lbl.text = "Stock: %d" % count
	count_lbl.add_theme_font_size_override("font_size", 7)
	count_lbl.clip_text = true
	vbox.add_child(count_lbl)

	var is_equipped: bool = GameState.equipped.has(c.id)
	if is_equipped:
		btn.modulate = Color(0.45, 1.0, 0.55)
		count_lbl.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55))
	elif count <= 0:
		btn.modulate = Color(0.6, 0.6, 0.6, 0.7)
		count_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	else:
		count_lbl.add_theme_color_override("font_color", Color(1, 0.88, 0.4))

	btn.pressed.connect(func() -> void: _select_consumable(index))
	btn.focus_entered.connect(func() -> void: _select_consumable(index))
	return btn


func _select_consumable(index: int) -> void:
	_selected_index = index
	if index < 0 or index >= _consumables.size():
		return
	var c := _consumables[index]
	detail_icon.texture = c.icon
	detail_name.text = c.display_name
	detail_desc.text = c.description
	var count := GameState.consumable_count(c.id)
	detail_stock.text = "Stock: %d / %d" % [count, GameState.MAX_PER_KIND]

	var can_equip := count > 0
	equip_slot1_btn.disabled = not can_equip
	equip_slot2_btn.disabled = not can_equip


func _equip_selected(slot: int) -> void:
	if _selected_index < 0 or _selected_index >= _consumables.size():
		return
	var c := _consumables[_selected_index]
	if GameState.consumable_count(c.id) > 0:
		GameState.equip_consumable(slot, c.id)
		_refresh()


func _update_stats_summary() -> void:
	var breath_cap := 50
	var lungs_lvl := GameState.get_upgrade_level("lungs_")
	if lungs_lvl == 1: breath_cap = 75
	elif lungs_lvl >= 2: breath_cap = 100

	var has_lamp := GameState.has_upgrade(&"lantern_1")
	var lamp_str := "Lamp: YES" if has_lamp else "Lamp: NO"

	var hp := 100 + (30 if GameState.has_upgrade(&"wetsuit_1") else 0) + (30 if GameState.has_upgrade(&"wetsuit_2") else 0)
	var sta := 100 + (30 if GameState.has_upgrade(&"vigor_1") else 0) + (30 if GameState.has_upgrade(&"vigor_2") else 0)

	var speed_ms := 4.0
	if run_manager != null and run_manager.diver != null:
		speed_ms = run_manager.diver.max_speed / GameState.PIXELS_PER_METRE

	stats_summary_label.text = "KIT STATS: Breath %ds  |  Swim %.1f m/s  |  HP %d  |  Sta %d  |  Carry %.1fkg  |  %s" % [
		breath_cap, speed_ms, hp, sta, GameState.weight_capacity, lamp_str
	]


func _slot_key(slot: int) -> String:
	var action := &"use_slot_1" if slot == 0 else &"use_slot_2"
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return (event as InputEventKey).as_text_physical_keycode()
	return str(slot + 1)
