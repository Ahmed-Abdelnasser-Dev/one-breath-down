extends Node
class_name ConsumableComponent
## Fires the diver's two equipped consumables (X and C) and applies their
## effects. Sits on the Diver alongside the breath/health/stamina components and
## reaches only into its siblings, never outward.
##
## Ownership and charges live in GameState; this is purely "what happens when
## the key is pressed".

const JET_SPEED_WINDOW := 0.5   ## seconds the speed cap is lifted after a jet

@onready var diver: Diver = get_parent() as Diver

var _sink_time := 0.0
var _boost_time := 0.0


func _ready() -> void:
	set_physics_process(true)


func _unhandled_input(event: InputEvent) -> void:
	# Consumables are dive-only; the shop and inventory are open at the surface
	# and X/C would otherwise fire behind an open menu.
	if get_tree().paused:
		return
	if event.is_action_pressed(&"use_slot_1"):
		_try_use(0)
	elif event.is_action_pressed(&"use_slot_2"):
		_try_use(1)


func _physics_process(delta: float) -> void:
	if _boost_time > 0.0:
		_boost_time -= delta
	if _sink_time > 0.0:
		_sink_time -= delta
		# Ballast: a steady downward pull rather than a one-off shove, so the
		# player keeps some steering while plummeting.
		diver.velocity.y += 900.0 * delta


## True while a jet is still carrying, so the diver can allow speeds above the
## normal cap without the movement code fighting the impulse.
func is_boosting() -> bool:
	return _boost_time > 0.0


func _try_use(slot: int) -> void:
	var id := GameState.equipped[slot] if slot < GameState.equipped.size() else &""
	if id == &"":
		return
	var data := Consumables.get_by_id(id)
	if data == null:
		return
	# Refuse rather than waste the charge where the effect would do nothing.
	if not _would_have_effect(data):
		Sfx.play(&"ui_click", 0.0, -8.0)
		return
	if GameState.consume_slot(slot) == &"":
		Sfx.play(&"ui_click", 0.0, -8.0)
		return
	_apply(data)


## Guards against burning a charge for no benefit — using an Air Bubble at full
## breath or a Patch Kit at full health is the kind of thing that feels like the
## game stole from you.
func _would_have_effect(data: ConsumableData) -> bool:
	match data.effect:
		ConsumableData.Effect.AIR:
			var breath := get_parent().get_node_or_null("BreathComponent") as BreathComponent
			return breath != null and breath.current_breath < breath.max_breath - 1.0
		ConsumableData.Effect.HEAL:
			var health := get_parent().get_node_or_null("HealthComponent") as HealthComponent
			return health != null and health.current_hp < health.max_hp - 1.0
	return true


func _apply(data: ConsumableData) -> void:
	var at := diver.global_position
	Events.consumable_used.emit(data.id, at)

	match data.effect:
		ConsumableData.Effect.JET:
			var dir := diver.aim_direction()
			diver.velocity += dir * data.magnitude
			_boost_time = maxf(_boost_time, JET_SPEED_WINDOW)
			Vfx.spawn(diver.get_parent(), Vfx.Kind.SMOKE, at - dir * 14.0,
				data.fx_color, 0.9, dir.angle())
			Sfx.play(&"jet", 0.08)
			Juice.add_trauma(0.3)

		ConsumableData.Effect.AIR:
			var breath := get_parent().get_node_or_null("BreathComponent") as BreathComponent
			if breath != null:
				breath.refill_step(data.magnitude)
			Vfx.spawn(diver.get_parent(), Vfx.Kind.IMPACT, at, data.fx_color, 0.8)
			Sfx.play(&"air_gain", 0.05)

		ConsumableData.Effect.HEAL:
			var health := get_parent().get_node_or_null("HealthComponent") as HealthComponent
			if health != null:
				health.heal(data.magnitude)
			Vfx.spawn(diver.get_parent(), Vfx.Kind.IMPACT, at, data.fx_color, 0.7)
			Sfx.play(&"heal", 0.05)

		ConsumableData.Effect.BLAST:
			_detonate(data, at)

		ConsumableData.Effect.SINK:
			_sink_time = maxf(_sink_time, data.duration)
			diver.velocity.y += data.magnitude
			Vfx.spawn(diver.get_parent(), Vfx.Kind.SMOKE, at + Vector2(0, -12),
				data.fx_color, 0.8)
			Sfx.play(&"ballast", 0.06)


## Radial damage. Hits through the enemy's normal take_damage so the existing
## flash, stagger, knockback, VFX and death handling all run unchanged.
func _detonate(data: ConsumableData, at: Vector2) -> void:
	Vfx.spawn(diver.get_parent(), Vfx.Kind.WAVE, at, data.fx_color, 1.6)
	Vfx.spawn(diver.get_parent(), Vfx.Kind.IMPACT, at, data.fx_color, 1.3)
	Sfx.play(&"blast", 0.06)
	Juice.add_trauma(0.95)
	Juice.hitstop(0.11)

	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		var e := enemy as Enemy
		if e == null or not is_instance_valid(e):
			continue
		if e.global_position.distance_to(at) <= data.radius:
			e.take_damage(int(data.magnitude), at)
