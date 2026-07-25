extends Resource
class_name EnemyData
## Data for one enemy species/variant. Mirrors PearlData: one behavior script
## per family (see behavior_scene), coloured/tuned entirely from this resource
## so adding a new enemy is a .tres edit, not a new scene or script.

@export var id: StringName             # &"tiger_shark" — payload of enemy_killed/enemy_damaged
@export var display_name: String       # "Tiger Shark"
@export var behavior_scene: PackedScene  # which of the 4 behavior .tscn to instantiate

@export_group("Health & Damage")
@export var max_hp: int = 20
@export var invulnerable: bool = false               ## true for the 3 sharks — never dies
@export var contact_damage: int = 8
@export var contact_damage_requires_attack: bool = false  ## turtle/charger/chaser: only hurts mid-swing
@export var hit_knockback_speed: float = 360.0       ## px/s impulse on the ENEMY when it takes damage
@export var stun_on_hit: float = 0.35                ## seconds of behavior freeze after being damaged
@export var player_knockback: float = 100.0          ## px/s impulse on the DIVER when this enemy lands a hit

@export_group("Movement")
@export var move_speed: float = 40.0        ## cruise / patrol / drift speed
@export var burst_speed: float = 0.0        ## lunge / ram / chase-sprint speed. 0 = no burst mode
@export var accel: float = 220.0            ## px/s^2 steering accel
@export var patrol_range: float = 120.0     ## px half-extent of patrol lane, or drift amplitude

@export_group("Senses & Timing")
@export var detect_radius: float = 0.0      ## 0 = never notices the player
@export var attack_radius: float = 0.0      ## distance at which a chaser commits to a bite
@export var lose_radius: float = 0.0        ## 0 -> derived as detect_radius * 1.7 (chase hysteresis)
@export var telegraph_time: float = 0.5
@export var attack_time: float = 0.45
@export var recover_time: float = 0.8
@export var cycle_period: float = 0.0       ## drifter_aura: full dormant->charge->live loop length
@export var cycle_active_ratio: float = 0.25  ## fraction of cycle_period the aura is live/damaging
@export var aura_radius: float = 0.0
@export var aura_damage: int = 0
@export var aura_color: Color = Color(0.45, 0.9, 1.0, 1.0)

@export_group("Spawning")
@export var min_depth_m: int = 0
@export var max_depth_m: int = 200
@export var spawn_weight: float = 100.0     ## relative pick chance inside its band
@export var max_concurrent: int = 0         ## 0 = unlimited. Sharks: 1.

@export_group("Visuals")
@export var frames: SpriteFrames
@export var faces_left: bool = false        ## art's native facing direction
@export var sprite_scale: float = 1.0
@export var hitbox_radius: float = 12.0     ## body CollisionShape2D + ContactHitbox radius


func get_lose_radius() -> float:
	return lose_radius if lose_radius > 0.0 else detect_radius * 1.7
