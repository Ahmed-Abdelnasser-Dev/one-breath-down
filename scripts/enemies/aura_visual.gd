extends Node2D
class_name AuraVisual
## Draws the jellyfish's electric aura ring so its telegraph/live cycle is
## actually readable at 480x270 — a colored radius with no visible warning
## would just read as random damage. Telegraph = pulsing thin outline,
## live = filled translucent disc + brighter outline.

var _radius: float = 0.0
var _color: Color = Color.WHITE
var _phase: int = 0   ## mirrors DrifterAura.AuraPhase (0=DORMANT, 1=TELEGRAPH, 2=LIVE)
var _pulse_time: float = 0.0


func _process(delta: float) -> void:
	if _phase == 0:
		return
	_pulse_time += delta * (10.0 if _phase == 1 else 4.0)
	queue_redraw()


## Called by DrifterAura whenever the aura phase changes.
func set_state(phase: int, radius: float, color: Color) -> void:
	_phase = phase
	_radius = radius
	_color = color
	_pulse_time = 0.0
	queue_redraw()


func _draw() -> void:
	if _phase == 0 or _radius <= 0.0:
		return

	var pulse := (sin(_pulse_time) + 1.0) * 0.5   # 0..1

	if _phase == 1:
		# Telegraph: thin pulsing outline only, no fill — "charging up".
		var alpha := lerpf(0.25, 0.7, pulse)
		draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 32, Color(_color.r, _color.g, _color.b, alpha), 1.5)
	else:
		# Live: filled translucent disc + a brighter pulsing rim — "damaging now".
		draw_circle(Vector2.ZERO, _radius, Color(_color.r, _color.g, _color.b, 0.22))
		var rim_alpha := lerpf(0.55, 0.95, pulse)
		draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 32, Color(_color.r, _color.g, _color.b, rim_alpha), 2.0)
