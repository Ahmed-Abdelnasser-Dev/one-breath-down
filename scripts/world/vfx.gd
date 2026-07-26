extends Node
class_name Vfx
## One-shot sprite-sheet effects (slashes, impacts, smoke puffs).
##
## The sheets in `visuals/Visual Effects /` are grids of 64x64 white frames —
## white so they can be tinted per use, grids rather than strips so they need
## both hframes and vframes. Everything here is fire-and-forget: spawn it into
## the world, it animates once and frees itself.

enum Kind { SLASH, IMPACT, SMOKE, WAVE }

const SHEETS := {
	Kind.SLASH: {"path": "res://visuals/Visual Effects /slash 01.png", "h": 2, "v": 3, "fps": 26.0},
	Kind.IMPACT: {"path": "res://visuals/Visual Effects /impact 01.png", "h": 2, "v": 2, "fps": 22.0},
	Kind.SMOKE: {"path": "res://visuals/Visual Effects /smoke.png", "h": 2, "v": 3, "fps": 16.0},
	Kind.WAVE: {"path": "res://visuals/Visual Effects /wave slash 01.png", "h": 3, "v": 3, "fps": 24.0},
}

static var _cache: Dictionary = {}


static func _sheet(kind: int) -> Texture2D:
	if not _cache.has(kind):
		_cache[kind] = load(SHEETS[kind]["path"]) as Texture2D
	return _cache[kind]


## Spawns an effect under `host` at world `pos`. Returns the sprite so callers
## can parent-follow it if they want it to track a moving enemy.
static func spawn(host: Node, kind: int, pos: Vector2, tint: Color = Color.WHITE,
		scale: float = 1.0, rotation: float = 0.0, flip: bool = false) -> Sprite2D:
	if host == null or not is_instance_valid(host):
		return null
	var info: Dictionary = SHEETS[kind]
	var spr := Sprite2D.new()
	spr.texture = _sheet(kind)
	spr.hframes = int(info["h"])
	spr.vframes = int(info["v"])
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.global_position = pos
	spr.rotation = rotation
	spr.flip_h = flip
	spr.scale = Vector2(scale, scale)
	spr.modulate = tint
	# Additive: these are light-like flashes, and it keeps them readable against
	# both the bright shallows and the near-black deep.
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	spr.material = mat
	host.add_child(spr)

	var frames: int = int(info["h"]) * int(info["v"])
	var fps: float = float(info["fps"])
	var tween := spr.create_tween()
	for i in frames:
		tween.tween_callback(func() -> void:
			if is_instance_valid(spr):
				spr.frame = i
		)
		tween.tween_interval(1.0 / fps)
	tween.tween_callback(spr.queue_free)
	return spr
