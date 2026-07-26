extends Node
## Global signal bus. Emitters never reference listeners.
##
## Every signal here is emitted/connected from other scripts, so the
## "declared but never explicitly used in the class" warning is a false
## positive by design — ignored per signal below.

# Run lifecycle
@warning_ignore("unused_signal")
signal run_started
@warning_ignore("unused_signal")
signal player_surfaced(pearls_banked: int)
@warning_ignore("unused_signal")
signal player_died(cause: String)
@warning_ignore("unused_signal")
signal run_reset

# Breath / countdown
@warning_ignore("unused_signal")
signal breath_changed(current: float, maximum: float)
@warning_ignore("unused_signal")
signal breath_depleted

# Depth
@warning_ignore("unused_signal")
signal depth_changed(metres: int)       # only on whole-metre change, not per frame
@warning_ignore("unused_signal")
signal zone_changed(zone: ZoneData)
@warning_ignore("unused_signal")
signal new_best_depth(metres: int)

# Economy
@warning_ignore("unused_signal")
signal pearl_collected(data: PearlData)
@warning_ignore("unused_signal")
signal carry_weight_changed(current: float, capacity: float)
@warning_ignore("unused_signal")
signal pearls_banked(amount: int)
@warning_ignore("unused_signal")
signal upgrade_purchased(id: StringName)
@warning_ignore("unused_signal")
signal consumables_changed
@warning_ignore("unused_signal")
signal consumable_used(id: StringName, at: Vector2)

# Combat / vitals
@warning_ignore("unused_signal")
signal health_changed(current: float, maximum: float)
@warning_ignore("unused_signal")
signal health_depleted
@warning_ignore("unused_signal")
signal stamina_changed(current: float, maximum: float)
@warning_ignore("unused_signal")
signal player_damaged(amount: int, source_id: StringName)
@warning_ignore("unused_signal")
signal player_attacked
@warning_ignore("unused_signal")
signal enemy_attacked(id: StringName, at: Vector2)
@warning_ignore("unused_signal")
signal enemy_damaged(id: StringName, amount: int)
@warning_ignore("unused_signal")
signal enemy_killed(id: StringName, at: Vector2)
