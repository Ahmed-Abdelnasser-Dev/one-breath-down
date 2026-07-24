extends PanelContainer
class_name DepthPanel

@onready var depth_text: Label = $VBoxContainer/DepthText
@onready var best_depth_text: Label = $VBoxContainer/BestDepthText


func _ready() -> void:
	Events.depth_changed.connect(_on_depth_changed)
	Events.new_best_depth.connect(_on_new_best_depth)
	depth_text.text = "DEPTH: 0 m"
	best_depth_text.text = "BEST: %d m" % GameState.best_depth_m


func _on_depth_changed(m: int) -> void:
	depth_text.text = "DEPTH: %d m" % m


func _on_new_best_depth(m: int) -> void:
	best_depth_text.text = "BEST: %d m" % m
