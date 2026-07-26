extends Node
class_name HealthComponent
## Owns player HP. Damage is rejected while invulnerable (post-hit i-frames);
## the i-frame gate lives here (not on Diver) so callers can poll take_hit()
## every physics frame an enemy overlaps without any per-enemy cooldown
## bookkeeping — see Enemy._tick_contact_damage().

const IFRAME_DURATION := 1.0    ## seconds of invulnerability after a hit
const FLASH_PERIOD := 0.12      ## seconds per on/off flash step while invulnerable
const FLASH_ALPHA := 0.35       ## sprite alpha during the "off" half of the flash

@export var base_max_hp: float = 100.0

var max_hp: float = 100.0
var current_hp: float

var _iframe_time: float = 0.0
var _sprite: CanvasItem

@onready var diver: Diver = get_parent()


func _ready() -> void:
	_sprite = get_node_or_null("../AnimatedSprite2D") as CanvasItem
	Events.upgrade_purchased.connect(func(_id): _apply_upgrades())
	Events.run_started.connect(_apply_upgrades)
	Events.run_reset.connect(_apply_upgrades)
	_apply_upgrades()


func _apply_upgrades() -> void:
	# Hook for a future defensive upgrade (e.g. "wetsuit_"), mirroring
	# BreathComponent/Diver's GameState.get_upgrade_level() pattern. No such
	# upgrade exists yet, so this currently always resolves to base_max_hp.
	var wetsuit_level := GameState.get_upgrade_level("wetsuit_")
	if wetsuit_level == 1:
		max_hp = 130.0
	elif wetsuit_level >= 2:
		max_hp = 160.0
	else:
		max_hp = base_max_hp

	current_hp = max_hp
	_iframe_time = 0.0
	if _sprite != null:
		_sprite.modulate.a = 1.0
	Events.health_changed.emit(current_hp, max_hp)


func can_be_hit() -> bool:
	return _iframe_time <= 0.0


func apply_damage(amount: float) -> void:
	if not can_be_hit() or amount <= 0.0:
		return

	current_hp = maxf(0.0, current_hp - amount)
	_iframe_time = IFRAME_DURATION
	Events.health_changed.emit(current_hp, max_hp)

	if current_hp <= 0.0:
		Events.health_depleted.emit()


## Partial heal, for consumables. Distinct from restore_health(), which is the
## ship's full top-up.
func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	current_hp = minf(max_hp, current_hp + amount)
	Events.health_changed.emit(current_hp, max_hp)


func restore_health() -> void:
	current_hp = max_hp
	if _sprite != null:
		_sprite.modulate.a = 1.0
	Events.health_changed.emit(current_hp, max_hp)


func _physics_process(delta: float) -> void:
	if _iframe_time <= 0.0:
		return

	_iframe_time = maxf(0.0, _iframe_time - delta)

	if _sprite != null:
		if _iframe_time <= 0.0:
			_sprite.modulate.a = 1.0
		else:
			var phase := fmod(_iframe_time, FLASH_PERIOD * 2.0)
			_sprite.modulate.a = FLASH_ALPHA if phase < FLASH_PERIOD else 1.0
