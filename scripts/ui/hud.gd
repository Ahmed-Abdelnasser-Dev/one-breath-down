extends CanvasLayer
class_name Hud
## Pure listener — reads Events/GameState and the world it needs to poll
## (breath, depth). Never reached into by other scripts.

@onready var run_manager: RunManager = get_parent()

@onready var breath_bar: TextureProgressBar = $TopLeftSection/VBoxContainer/HBoxContainer/BreathBar
@onready var breath_counter_text: Label = $TopLeftSection/VBoxContainer/HBoxContainer/BreathCounterText
@onready var money_text: Label = $TopLeftSection/VBoxContainer/MoneyText
@onready var weight_text: Label = $TopLeftSection/VBoxContainer/WeightText
@onready var loot_text: Label = $TopRightSection/VBoxContainer/LootText
@onready var run_value_text: Label = $TopRightSection/VBoxContainer/RunValueText
@onready var depth_text: Label = $BottomRightSection/VBoxContainer/DepthText
@onready var best_depth_text: Label = $BottomRightSection/VBoxContainer/BestDepthText

var carried_count: int = 0
var carried_value: int = 0


func _ready() -> void:
	Events.breath_changed.connect(_on_breath_changed)
	Events.pearl_collected.connect(_on_pearl_collected)
	Events.pearls_banked.connect(_on_pearls_banked)
	Events.player_surfaced.connect(_on_run_ended)
	Events.player_died.connect(_on_run_ended)

	# Read the breath state directly rather than through run_manager's own
	# @onready vars — Hud is a sibling of Diver, so it readies before Game
	# does, and the initial breath_changed emit (fired from BreathComponent's
	# own _ready) happens before this listener is even connected.
	var breath: BreathComponent = get_node("../Diver/BreathComponent")
	_on_breath_changed(breath.current_breath, breath.max_breath)

	money_text.text = "%d" % GameState.pearls
	best_depth_text.text = "BEST %d m" % int(GameState.best_depth)
	_refresh_loot()


func _process(_delta: float) -> void:
	var depth: float = run_manager.get_depth_meters()
	depth_text.text = "DEPTH %d m" % int(depth)
	if depth > GameState.best_depth:
		GameState.best_depth = depth
		best_depth_text.text = "BEST %d m" % int(depth)


func _on_breath_changed(current: float, max_breath: float) -> void:
	breath_bar.max_value = max_breath
	breath_bar.value = current
	breath_counter_text.text = _format_breath(current)



func _on_pearl_collected(data: PearlData) -> void:
	carried_count += 1
	carried_value += data.value
	weight_text.text = "%.2f" % run_manager.diver.carried_weight
	_refresh_loot()


func _on_pearls_banked(_amount: int) -> void:
	money_text.text = "%d" % GameState.pearls


func _on_run_ended(_arg) -> void:
	carried_count = 0
	carried_value = 0
	weight_text.text = "0.00"
	_refresh_loot()


func _refresh_loot() -> void:
	loot_text.text = "Seed x%d" % carried_count
	run_value_text.text = "RUN VALUE %d" % carried_value


## Above 10s: "M:SS". Below 10s: one decimal, so the last stretch reads faster.
func _format_breath(seconds: float) -> String:
	var s: float = max(seconds, 0.0)
	if s >= 10.0:
		var whole := int(s)
		return "%d:%02d" % [whole / 60, whole % 60]
	return "%.1f" % s
