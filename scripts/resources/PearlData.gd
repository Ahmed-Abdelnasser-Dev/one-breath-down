extends Resource
class_name PearlData

@export var id: StringName            # "black"
@export var display_name: String      # "Black pearl"
@export var value: int = 10
@export var carry_weight: float = 0.2

@export_group("Spawning")
@export var min_depth_m: int = 0
@export var max_depth_m: int = 40
@export var spawn_weight: float = 100.0  # relative pick chance inside its band

@export_group("Placeholder visuals")     # replaced by a texture in Phase 5
@export var color: Color = Color.WHITE
@export var radius: float = 8.0
@export var sprite: Texture2D