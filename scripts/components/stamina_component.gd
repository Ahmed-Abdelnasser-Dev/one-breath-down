extends Node
class_name StaminaComponent
## Owns the attack-stamina pool. A pool rather than a flat cooldown so the
## player can burst two swings back to back, then is forced to wait out the
## regen delay — see docs decision: "Pool with regen".

@export var base_max_stamina: float = 100.0
@export var regen_rate: float = 25.0        ## stamina/sec once regen_delay has elapsed
@export var regen_delay: float = 0.4        ## seconds after a spend before regen resumes
@export var attack_cost: float = 35.0

var max_stamina: float = 100.0
var current_stamina: float

var _regen_wait: float = 0.0


func _ready() -> void:
	Events.upgrade_purchased.connect(func(_id): _apply_upgrades())
	Events.run_started.connect(_apply_upgrades)
	Events.run_reset.connect(_apply_upgrades)
	_apply_upgrades()


func _apply_upgrades() -> void:
	# Hook for a future stamina upgrade (e.g. "vigor_"), mirroring
	# BreathComponent's GameState.get_upgrade_level() pattern. No such
	# upgrade exists yet, so this currently always resolves to base_max_stamina.
	var vigor_level := GameState.get_upgrade_level("vigor_")
	if vigor_level == 1:
		max_stamina = 130.0
	elif vigor_level >= 2:
		max_stamina = 160.0
	else:
		max_stamina = base_max_stamina

	current_stamina = max_stamina
	_regen_wait = 0.0
	Events.stamina_changed.emit(current_stamina, max_stamina)


func can_spend(amount: float = -1.0) -> bool:
	var cost := attack_cost if amount < 0.0 else amount
	return current_stamina >= cost


func spend(amount: float = -1.0) -> bool:
	var cost := attack_cost if amount < 0.0 else amount
	if current_stamina < cost:
		return false

	current_stamina -= cost
	_regen_wait = regen_delay
	Events.stamina_changed.emit(current_stamina, max_stamina)
	return true


func _physics_process(delta: float) -> void:
	if current_stamina >= max_stamina:
		return

	if _regen_wait > 0.0:
		_regen_wait -= delta
		return

	current_stamina = minf(max_stamina, current_stamina + regen_rate * delta)
	Events.stamina_changed.emit(current_stamina, max_stamina)
