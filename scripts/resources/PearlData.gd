extends Resource
class_name PearlData

@export var id: StringName
@export var display_name: String
@export var value: int = 1
@export var min_depth: float = 0.0      ## metres before this can spawn
@export var carry_weight: float = 0.0   ## added speed / oxygen penalty
@export var sprite: Texture2D