extends Resource
class_name ConsumableData
## A single-use item bought in the shop, equipped to a slot, and fired with a
## key mid-dive. Data only — the effects themselves live in
## scripts/components/consumable_component.gd, keyed off `id`.

## What the item actually does. Kept as an enum rather than a script-per-item
## because every effect is a couple of lines against the diver.
enum Effect {
	JET,            ## burst of speed in the facing direction
	AIR,            ## refund breath
	HEAL,           ## restore health
	BLAST,          ## radial damage to nearby enemies
	SINK,           ## heavy descent for a few seconds
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var cost: int = 40
@export var effect: Effect = Effect.JET
## Primary number: px/s impulse, seconds of breath, HP healed, or damage.
@export var magnitude: float = 0.0
## Seconds the effect lasts, for the ones that aren't instant.
@export var duration: float = 0.0
## Radius in px, for BLAST.
@export var radius: float = 0.0
@export var icon: Texture2D
## Tint used for the item's VFX burst so each consumable reads differently.
@export var fx_color: Color = Color.WHITE
