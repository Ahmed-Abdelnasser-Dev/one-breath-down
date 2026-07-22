extends Node2D

func _ready() -> void:
	Events.pearls_banked.connect(_on_pearls_banked)
	print("Boot OK — banked pearls: %d" % GameState.pearls)
	GameState.add_pearls(3)   # should print via the signal below

func _on_pearls_banked(amount: int) -> void:
	print("Signal bus OK — banked +%d (total %d)" % [amount, GameState.pearls])