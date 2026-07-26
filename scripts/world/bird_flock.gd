extends Node2D
class_name BirdFlock
## Seabirds working the air above the dive site.
##
## No bird art shipped with the project (the "birds flying" folder is eight
## misnamed fishing-boat sheets), so visuals/birds/gull_strip5.png is authored
## for this: a five-frame flap cycle drawn as a silhouette, because at this
## distance and scale shape and timing read and detail does not.
##
## Birds are plain Sprite2Ds rather than particles — each one needs its own
## flap phase, glide pauses and wrap, which a ParticleProcessMaterial can't
## express. The whole flock is a handful of draw calls.

const BIRD_TEXTURE: Texture2D = preload("res://visuals/birds/gull_strip5.png")
const FRAME_COUNT := 5

## Three depth bands. Nearer birds are bigger, faster, darker and flap harder;
## far ones are pale specks that mostly glide. That spread is what sells it as
## sky rather than a row of identical sprites.
## Y values are tuned to the sky actually on screen while docked: the camera
## sits at about y=-6, so the visible band above the waterline is roughly
## world -140 (screen top) to -20 (just above the waves). Birds placed higher
## than that are simulated and never seen.
const BANDS: Array = [
	# [count, scale, y_min, y_max, speed_min, speed_max, alpha, parallax]
	[16, 1.0, -138.0, -104.0, 10.0, 18.0, 0.34, 0.18],   # far specks
	[12, 1.6, -116.0, -74.0, 16.0, 27.0, 0.58, 0.34],    # mid
	[8, 2.4, -88.0, -38.0, 24.0, 40.0, 0.80, 0.52],      # near
]

const SPAN_X := 1500.0          ## horizontal wrap width around the dive site
const CENTRE_X := 800.0
## Above this depth the flock is worth drawing at all; it fades out as the
## diver descends and is hidden entirely below the surface glow.
const FADE_OUT_DEPTH := 420.0

var _birds: Array[Sprite2D] = []
var _vel: Array[float] = []
var _base_y: Array[float] = []
var _bob_phase: Array[float] = []
var _bob_amp: Array[float] = []
var _flap_phase: Array[float] = []
var _flap_speed: Array[float] = []
var _glide_until: Array[float] = []
var _parallax: Array[float] = []
var _alpha: Array[float] = []

var _time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 8814772
	for band in BANDS:
		for i in int(band[0]):
			_add_bird(band)


func _add_bird(band: Array) -> void:
	var spr := Sprite2D.new()
	spr.texture = BIRD_TEXTURE
	spr.hframes = FRAME_COUNT
	spr.texture_filter = TEXTURE_FILTER_NEAREST
	var s: float = float(band[1])
	spr.scale = Vector2(s, s)
	spr.position = Vector2(
		_rng.randf_range(CENTRE_X - SPAN_X * 0.5, CENTRE_X + SPAN_X * 0.5),
		_rng.randf_range(float(band[2]), float(band[3]))
	)
	var speed := _rng.randf_range(float(band[4]), float(band[5]))
	if _rng.randf() < 0.45:
		speed = -speed
	spr.flip_h = speed < 0.0
	add_child(spr)

	_birds.append(spr)
	_vel.append(speed)
	_base_y.append(spr.position.y)
	_bob_phase.append(_rng.randf() * TAU)
	_bob_amp.append(_rng.randf_range(1.5, 5.0))
	_flap_phase.append(_rng.randf() * TAU)
	# Bigger birds flap slower — small ones flutter.
	_flap_speed.append(_rng.randf_range(7.0, 12.0) / maxf(s, 0.5))
	_glide_until.append(0.0)
	_parallax.append(float(band[7]))
	_alpha.append(float(band[6]))


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var centre := cam.get_screen_center_position()
	var depth: float = maxf(centre.y, 0.0)

	# Once under water the sky is gone; skip the whole flock rather than
	# drawing 25 invisible sprites every frame.
	var visible_amount: float = clampf(1.0 - depth / FADE_OUT_DEPTH, 0.0, 1.0)
	if visible_amount <= 0.001:
		if visible:
			hide()
		return
	if not visible:
		show()

	_time += delta

	for i in _birds.size():
		var b := _birds[i]

		b.position.x += _vel[i] * delta
		# Wrap around the dive site so the sky is never empty on one side.
		var half := SPAN_X * 0.5
		if b.position.x < CENTRE_X - half:
			b.position.x = CENTRE_X + half
		elif b.position.x > CENTRE_X + half:
			b.position.x = CENTRE_X - half

		# Gentle rise and fall on a per-bird phase.
		b.position.y = _base_y[i] + sin(_time * 0.8 + _bob_phase[i]) * _bob_amp[i] \
			+ centre.y * _parallax[i] * 0.12

		# Flap in bursts with glides between — constant flapping looks mechanical.
		if _time >= _glide_until[i]:
			_flap_phase[i] += delta * _flap_speed[i]
			var frame_idx := int(_flap_phase[i]) % FRAME_COUNT
			b.frame = frame_idx
			if frame_idx == 0 and _rng.randf() < 0.012:
				_glide_until[i] = _time + _rng.randf_range(0.6, 2.2)
		else:
			b.frame = 2   # flat-winged glide pose

		b.modulate.a = _alpha[i] * visible_amount
