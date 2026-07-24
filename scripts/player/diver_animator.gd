extends AnimatedSprite2D
class_name DiverAnimator
## Visual state machine for the diver. Never touches movement — only reads
## the parent Diver's velocity and reacts to Events. One-shots (dive/hurt/
## death) always play to completion before movement anims resume; facing
## and banking are tweened so turning/pitching never snaps.

enum State { IDLE, SWIM, DIVE, HURT, DEATH }

const MOVE_THRESHOLD := 15.0     ## px/sec below which the diver counts as "idle"
const FACING_THRESHOLD := 10.0   ## px/sec of horizontal speed needed to flip facing
const BASE_SCALE := 3.0          ## matches AnimatedSprite2D.scale set in the scene
const TURN_SPEED := 10.0         ## how fast scale.x eases toward the target facing
const BANK_EASE := 6.0           ## exponential ease rate for the tilt (higher = snappier)
const MAX_BANK_RADIANS := 0.35

var state: State = State.IDLE
var _facing: float = 1.0   ## +1 right, -1 left
var _bank_tilt: float = 0.0

@onready var diver: Diver = get_parent()


func _ready() -> void:
	animation_finished.connect(_on_animation_finished)
	Events.run_started.connect(_on_run_started)
	Events.player_died.connect(_on_player_died)
	Events.run_reset.connect(_on_run_reset)
	play("idle")


func _process(delta: float) -> void:
	_update_facing(delta)
	_update_banking(delta)
	_update_state()


## Public hook for future hazards — plays the hurt one-shot unless the diver
## is already dead.
func trigger_hurt() -> void:
	if state == State.DEATH:
		return
	state = State.HURT
	play("hurt")


func _update_state() -> void:
	# One-shots and death own the animation until they release it.
	if state in [State.DIVE, State.HURT, State.DEATH]:
		return

	var moving := diver.velocity.length() > MOVE_THRESHOLD
	var target := State.SWIM if moving else State.IDLE
	if target != state:
		_enter_movement_state(target)


## Unconditionally plays the movement anim for `target` and updates state.
## Used both by the per-frame check above and by one-shots handing control
## back — the latter must not rely on the `target != state` guard, since
## `state` may already have been reset to IDLE by the caller.
func _enter_movement_state(target: State) -> void:
	state = target
	play("swim" if target == State.SWIM else "idle")


func _update_facing(delta: float) -> void:
	if absf(diver.velocity.x) > FACING_THRESHOLD:
		_facing = signf(diver.velocity.x)
	scale.x = move_toward(scale.x, BASE_SCALE * _facing, TURN_SPEED * BASE_SCALE * delta)


func _update_banking(delta: float) -> void:
	var speed_ratio := clampf(diver.velocity.y / diver.max_speed, -1.0, 1.0)
	var target_tilt := speed_ratio * MAX_BANK_RADIANS
	_bank_tilt = lerpf(_bank_tilt, target_tilt, clampf(BANK_EASE * delta, 0.0, 1.0))
	# Mirror the tilt when facing left so it still reads as "nose toward travel".
	rotation = _bank_tilt if scale.x >= 0.0 else -_bank_tilt


func _on_animation_finished() -> void:
	match state:
		State.DIVE, State.HURT:
			var moving := diver.velocity.length() > MOVE_THRESHOLD
			_enter_movement_state(State.SWIM if moving else State.IDLE)


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
	_bank_tilt = 0.0
	play("idle")
