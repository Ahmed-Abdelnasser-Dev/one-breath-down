extends CanvasLayer
class_name Hud
## Pure listener — reads Events/GameState and the world it needs to poll
## (breath, depth). Never reached into by other scripts.

@onready var run_manager: RunManager = get_parent()

@onready var breath_bar: ProgressBar = $TopLeftSection/VBoxContainer/BreathRow/BreathBar
@onready var breath_counter_text: Label = $TopLeftSection/VBoxContainer/BreathRow/BreathCounterText
@onready var health_bar: ProgressBar = $TopLeftSection/VBoxContainer/HealthRow/HealthBar
@onready var stamina_bar: ProgressBar = $TopLeftSection/VBoxContainer/StaminaRow/StaminaBar
@onready var money_text: Label = $TopLeftSection/VBoxContainer/StatusSubRow/MoneyRow/MoneyText
@onready var weight_text: Label = $TopLeftSection/VBoxContainer/StatusSubRow/WeightRow/WeightText
@onready var loot_text: Label = $TopRightSection/VBoxContainer/LootText
@onready var depth_text: Label = $DepthSection/DepthText
@onready var best_depth_text: Label = $TopLeftSection/VBoxContainer/StatusSubRow/BestRow/BestDepthText
@onready var prompt_bar_panel: PanelContainer = $PromptBarPanel
@onready var prompt_bar: Label = $PromptBarPanel/PromptBar

var carried_count: int = 0
var carried_value: int = 0

var _pulse_time: float = 0.0
var _current_ratio: float = 1.0
var _fill_stylebox: StyleBoxFlat
var _health_fill_stylebox: StyleBoxFlat
var _stamina_fill_stylebox: StyleBoxFlat


func _ready() -> void:
	# Duplicate styleboxes so each bar's fill color can be modulated per-instance
	# without the three bars fighting over one shared StyleBoxFlat resource.
	var sb := breath_bar.get_theme_stylebox("fill")
	if sb is StyleBoxFlat:
		_fill_stylebox = sb.duplicate()
		breath_bar.add_theme_stylebox_override("fill", _fill_stylebox)

	var health_sb := health_bar.get_theme_stylebox("fill")
	if health_sb is StyleBoxFlat:
		_health_fill_stylebox = health_sb.duplicate()
		health_bar.add_theme_stylebox_override("fill", _health_fill_stylebox)

	var stamina_sb := stamina_bar.get_theme_stylebox("fill")
	if stamina_sb is StyleBoxFlat:
		_stamina_fill_stylebox = stamina_sb.duplicate()
		stamina_bar.add_theme_stylebox_override("fill", _stamina_fill_stylebox)

	Events.breath_changed.connect(_on_breath_changed)
	Events.health_changed.connect(_on_health_changed)
	Events.stamina_changed.connect(_on_stamina_changed)
	Events.pearl_collected.connect(_on_pearl_collected)
	Events.pearls_banked.connect(_on_pearls_banked)
	Events.player_surfaced.connect(_on_run_ended)
	Events.player_died.connect(_on_run_ended)
	Events.depth_changed.connect(_on_depth_changed)
	Events.new_best_depth.connect(_on_new_best_depth)

	var breath := get_node_or_null("../Diver/BreathComponent") as BreathComponent
	if breath != null:
		_on_breath_changed(breath.current_breath, breath.max_breath)

	var health := get_node_or_null("../Diver/HealthComponent") as HealthComponent
	if health != null:
		_on_health_changed(health.current_hp, health.max_hp)

	var stamina := get_node_or_null("../Diver/StaminaComponent") as StaminaComponent
	if stamina != null:
		_on_stamina_changed(stamina.current_stamina, stamina.max_stamina)

	money_text.text = "%d" % GameState.pearls
	weight_text.text = "0.00 kg"
	depth_text.text = "DEPTH: 0 m"
	best_depth_text.text = "BEST: %d m" % GameState.best_depth_m
	_refresh_loot()

	prompt_bar.text = "Press [%s] Shop    Press [%s] Inventory" % [
		_bound_key_text("open_shop"), _bound_key_text("open_inventory")
	]
	prompt_bar_panel.hide()


func _process(delta: float) -> void:
	# Only advertise F/I where MenuManager will actually honor them: at the
	# surface AND docked at the ship.
	prompt_bar_panel.visible = (
		run_manager.state == RunManager.RunState.AT_SURFACE and run_manager.is_at_ship()
	)

	# Low breath visual warning pulse
	if _current_ratio < 0.25:
		_pulse_time += delta * 6.0
		var pulse := (sin(_pulse_time) + 1.0) * 0.5   # 0.0..1.0
		var danger_red := Color(1.0, 0.2 + pulse * 0.3, 0.2, 1.0)
		if _fill_stylebox:
			_fill_stylebox.bg_color = danger_red
		breath_counter_text.add_theme_color_override("font_color", danger_red)
	else:
		_pulse_time = 0.0


func _on_depth_changed(metres: int) -> void:
	depth_text.text = "DEPTH: %d m" % metres


func _on_new_best_depth(metres: int) -> void:
	best_depth_text.text = "BEST: %d m" % metres


func _on_breath_changed(current: float, max_breath: float) -> void:
	breath_bar.max_value = max_breath
	breath_bar.value = clamp(current, 0.0, max_breath)
	breath_counter_text.text = _format_breath(current)

	_current_ratio = current / max_breath if max_breath > 0 else 0.0

	# Dynamic color transitions matching dive urgency
	if _fill_stylebox:
		if _current_ratio >= 0.5:
			_fill_stylebox.bg_color = Color(0.23, 0.82, 0.92, 1.0)   # Ocean Cyan
			breath_counter_text.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 1.0))
		elif _current_ratio >= 0.25:
			_fill_stylebox.bg_color = Color(0.98, 0.72, 0.2, 1.0)    # Amber Warning
			breath_counter_text.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1.0))


func _on_health_changed(current: float, max_hp: float) -> void:
	health_bar.max_value = max_hp
	health_bar.value = clamp(current, 0.0, max_hp)


func _on_stamina_changed(current: float, max_stamina: float) -> void:
	stamina_bar.max_value = max_stamina
	stamina_bar.value = clamp(current, 0.0, max_stamina)


func _on_pearl_collected(data: PearlData) -> void:
	carried_count += 1
	carried_value += data.value
	weight_text.text = "%.2f kg" % run_manager.diver.carried_weight
	_refresh_loot()


func _on_pearls_banked(_amount: int) -> void:
	money_text.text = "%d" % GameState.pearls


func _on_run_ended(_arg) -> void:
	carried_count = 0
	carried_value = 0
	weight_text.text = "0.00 kg"
	_refresh_loot()


func _refresh_loot() -> void:
	loot_text.text = "Pearls x%d" % carried_count


## Above 10s: "M:SS". Below 10s: "S.s".
func _format_breath(seconds: float) -> String:
	var s: float = max(seconds, 0.0)
	if s >= 10.0:
		var whole := int(s)
		@warning_ignore("integer_division")
		return "%d:%02d" % [whole / 60, whole % 60]
	return "%.1f" % s


func _bound_key_text(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event.as_text_physical_keycode()
	return "?"
