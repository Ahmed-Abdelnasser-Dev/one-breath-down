extends Node
## Central impact feedback: camera shake and hitstop.
##
## Listens to the Events bus rather than being called directly, so no gameplay
## script needs a reference to the camera or to this node. Shake is applied as
## a per-frame offset on whatever Camera2D is current, and always decays back
## to zero, so it composes with the camera's own position smoothing.

const MAX_OFFSET := 6.0          ## px — hard ceiling so shake never hides the diver
const DECAY := 9.0               ## trauma units/sec
const SHAKE_SPEED := 34.0        ## noise sampling rate

var _trauma: float = 0.0
var _time: float = 0.0
var _noise := FastNoiseLite.new()
var _hitstop_until_msec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_noise.seed = randi()
	_noise.frequency = 0.9

	Events.enemy_damaged.connect(_on_enemy_damaged)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.player_damaged.connect(_on_player_damaged)
	Events.player_died.connect(_on_player_died)


## `amount` is trauma, not pixels: it accumulates and is squared on apply, so
## small hits stay subtle while several at once genuinely rattle the frame.
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


## Freezes gameplay for a beat so a hit reads as contact rather than overlap.
## Uses wall-clock time and an unscaled timer, so it can't be stretched by the
## very time_scale it sets.
func hitstop(duration_sec: float) -> void:
	if get_tree().paused:
		return
	var until := Time.get_ticks_msec() + int(duration_sec * 1000.0)
	if until <= _hitstop_until_msec:
		return
	_hitstop_until_msec = until
	Engine.time_scale = 0.02
	await get_tree().create_timer(duration_sec, true, false, true).timeout
	if Time.get_ticks_msec() >= _hitstop_until_msec:
		Engine.time_scale = 1.0


func _process(delta: float) -> void:
	if _trauma <= 0.0:
		return
	_time += delta * SHAKE_SPEED
	_trauma = maxf(_trauma - DECAY * delta * 0.1, 0.0)

	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return

	var shake := _trauma * _trauma
	if _trauma <= 0.001:
		cam.offset = Vector2.ZERO
		return
	cam.offset = Vector2(
		_noise.get_noise_2d(_time, 0.0) * MAX_OFFSET * shake,
		_noise.get_noise_2d(0.0, _time) * MAX_OFFSET * shake
	)


func _on_enemy_damaged(_id: StringName, _amount: int) -> void:
	add_trauma(0.28)
	hitstop(0.05)


func _on_enemy_killed(_id: StringName, _at: Vector2) -> void:
	add_trauma(0.4)
	hitstop(0.08)


func _on_player_damaged(_amount: int, _source_id: StringName) -> void:
	add_trauma(0.62)
	hitstop(0.07)


func _on_player_died(_cause: String) -> void:
	add_trauma(0.9)
