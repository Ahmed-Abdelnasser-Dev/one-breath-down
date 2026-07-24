extends AnimatedSprite2D
class_name DiverAnimator
## Visual animator for the pixel diver.
## Manages movement states (idle, swim up, swim down, horizontal swim, dive, hurt, death),
## pixel-snapped pitch rotations, dynamic stroke speed, and integer buoyancy bobbing.

enum State { IDLE, SWIM_HORIZONTAL, SWIM_UP, SWIM_DOWN, DIVE, HURT, DEATH }

const MOVE_THRESHOLD := 15.0         ## px/sec below which the diver counts as "idle"
const FACING_THRESHOLD := 10.0       ## px/sec of horizontal speed needed to flip facing
const VERTICAL_THRESHOLD := 20.0     ## px/sec of vertical speed to trigger swim up/down
const PITCH_STEP_DEGREES := 15.0     ## discrete pixel rotation step for crisp pixel feel
const MAX_PITCH_DEGREES := 65.0      ## maximum pitch tilt angle in degrees

var state: State = State.IDLE
var _facing_right: bool = true
var _target_pitch_deg: float = 0.0
var _current_pitch_deg: float = 0.0
var _idle_time: float = 0.0
var _base_offset: Vector2 = Vector2.ZERO

@onready var diver: Diver = get_parent()


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	_base_offset = offset
	animation_finished.connect(_on_animation_finished)
	Events.run_started.connect(_on_run_started)
	Events.player_died.connect(_on_player_died)
	Events.run_reset.connect(_on_run_reset)
	play("idle")


var _squish_x: float = 1.0


func _process(delta: float) -> void:
	if diver == null:
		return
	_update_facing(delta)
	_update_state(delta)
	_update_pitch(delta)
	_update_buoyancy(delta)


func trigger_hurt() -> void:
	if state == State.DEATH:
		return
	state = State.HURT
	play("hurt")


func _update_state(delta: float) -> void:
	if state in [State.DIVE, State.HURT, State.DEATH]:
		return

	var speed := diver.velocity.length()
	var vel_y := diver.velocity.y

	if speed < MOVE_THRESHOLD:
		if state != State.IDLE:
			_enter_movement_state(State.IDLE)
	else:
		# Determine swim direction (up, down, or horizontal)
		var target_state := State.SWIM_HORIZONTAL
		if vel_y < -VERTICAL_THRESHOLD:
			target_state = State.SWIM_UP
		elif vel_y > VERTICAL_THRESHOLD:
			target_state = State.SWIM_DOWN

		if target_state != state:
			_enter_movement_state(target_state)

		# Scale animation stroke speed to movement velocity for game feel
		var speed_ratio := clampf(speed / max(1.0, float(diver.max_speed)), 0.5, 1.8)
		speed_scale = speed_ratio


func _enter_movement_state(target: State) -> void:
	state = target
	speed_scale = 1.0

	match state:
		State.IDLE:
			# Play idle2 if carrying heavy load, otherwise idle
			play("idle2" if diver.carried_weight > 2.0 else "idle")
		State.SWIM_UP:
			play("swim2")
		State.SWIM_DOWN:
			play("swim")
		State.SWIM_HORIZONTAL:
			play("swim")


func _update_facing(delta: float) -> void:
	if absf(diver.velocity.x) > FACING_THRESHOLD:
		var new_facing := diver.velocity.x > 0.0
		if new_facing != _facing_right:
			_facing_right = new_facing
			_squish_x = 0.75  # Organic squish juice on turn!

	_squish_x = lerpf(_squish_x, 1.0, 14.0 * delta)
	scale.x = _squish_x
	flip_h = not _facing_right


func _update_pitch(delta: float) -> void:
	if state in [State.HURT, State.DEATH]:
		_target_pitch_deg = 0.0
	else:
		var speed_y := diver.velocity.y
		var speed_ratio := clampf(speed_y / max(1.0, float(diver.max_speed)), -1.0, 1.0)
		_target_pitch_deg = speed_ratio * MAX_PITCH_DEGREES

	# Smoothly interpolate target pitch, then snap to discrete pixel-art degree steps
	_current_pitch_deg = lerpf(_current_pitch_deg, _target_pitch_deg, 12.0 * delta)
	var snapped_deg := roundf(_current_pitch_deg / PITCH_STEP_DEGREES) * PITCH_STEP_DEGREES

	# Adjust pitch orientation based on facing direction
	var final_deg := snapped_deg if _facing_right else -snapped_deg
	rotation_degrees = final_deg


func _update_buoyancy(delta: float) -> void:
	if state == State.IDLE:
		_idle_time += delta * 4.0
		# Discrete 1-pixel integer bob step for pixel aesthetic
		var pixel_bob := int(round(sin(_idle_time)))
		offset = _base_offset + Vector2(0, pixel_bob)
	else:
		_idle_time = 0.0
		offset = _base_offset


func _on_animation_finished() -> void:
	match state:
		State.DIVE, State.HURT:
			var moving := diver.velocity.length() > MOVE_THRESHOLD
			if moving:
				_enter_movement_state(State.SWIM_UP if diver.velocity.y < -VERTICAL_THRESHOLD else State.SWIM_HORIZONTAL)
			else:
				_enter_movement_state(State.IDLE)


func _on_run_started() -> void:
	if state == State.DEATH:
		return
	state = State.DIVE
	play("dive")


func _on_player_died(_cause: String) -> void:
	state = State.DEATH
	play("death")


func _on_run_reset() -> void:
	state = State.IDLE
	rotation = 0.0
	_current_pitch_deg = 0.0
	_target_pitch_deg = 0.0
	offset = _base_offset
	speed_scale = 1.0
	play("idle")
