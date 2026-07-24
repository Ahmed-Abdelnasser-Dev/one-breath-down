extends Node
## Global signal bus. Emitters never reference listeners.

# Run lifecycle
signal run_started
signal player_surfaced(pearls_banked: int)
signal player_died(cause: String)
signal run_reset

# Breath / countdown
signal breath_changed(current: float, maximum: float)
signal breath_depleted

# Depth
signal depth_changed(metres: int)       # only on whole-metre change, not per frame
signal zone_changed(zone: ZoneData)
signal new_best_depth(metres: int)

# Economy
signal pearl_collected(data: PearlData)
signal carry_weight_changed(current: float, capacity: float)
signal pearls_banked(amount: int)
signal upgrade_purchased(id: StringName)