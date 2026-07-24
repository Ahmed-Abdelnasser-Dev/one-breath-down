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

# Economy
signal pearl_collected(data: PearlData)
signal pearls_banked(amount: int)
signal upgrade_purchased(id: StringName)