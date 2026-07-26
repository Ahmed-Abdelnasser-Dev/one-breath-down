extends Node
## Central impact feedback: camera shake and hitstop.
##
## Listens to the Events bus rather than being called directly, so no gameplay
## script needs a reference to the camera or to this node. Shake is applied as
## a per-frame offset on whatever Camera2D is current, and always decays back
## to zero, so it composes with the camera's own position smoothing.

const MAX_OFFSET := 6.0          ## px — hard ceiling so shake never hides the diver
const DECAY := 1.9               ## trauma units/sec
const SHAKE_SPEED := 34.0        ## noise sampling rate
const HITSTOP_SCALE := 0.05      ## Engine.time_scale during a freeze frame

var _trauma: float = 0.0
var _time: float = 0.0
var _noise := FastNoiseLite.new()
var _hitstop_until_msec: int = 0
var _hitstop_active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_noise.seed = randi()
	_noise.frequency = 0.9
	Engine.time_scale = 1.0

	Events.enemy_damaged.connect(_on_enemy_damaged)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.player_damaged.connect(_on_player_damaged)
	Events.player_died.connect(_on_player_died)

	# Belt and braces: a run boundary always returns the engine to normal speed
	# and drops any leftover shake, whatever happened during the previous run.
	Events.run_reset.connect(_reset_all)
	Events.player_died.connect(func(_cause: String) -> void: _end_hitstop())
	Events.player_surfaced.connect(func(_banked: int) -> void: _end_hitstop())


func _reset_all() -> void:
	_end_hitstop()
	_trauma = 0.0
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		cam.offset = Vector2.ZERO


## `amount` is trauma, not pixels: it accumulates and is squared on apply, so
## small hits stay subtle while several at once genuinely rattle the frame.
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


## Freezes gameplay for a beat so a hit reads as contact rather than overlap.
##
## Deliberately NOT implemented with `await a timer then restore` — that version
## hung the game. The restore was gated on a wall-clock comparison that failed
## whenever the timer fired a millisecond early, so time_scale was left at its
## frozen value forever and the game appeared locked up. Instead the deadline is
## just a timestamp and _process (which still runs at full rate under any
## time_scale) always restores once it passes, so there is no path that can
## leave the engine slowed down.
func hitstop(duration_sec: float) -> void:
	if get_tree().paused:
		return
	_hitstop_until_msec = maxi(_hitstop_until_msec, Time.get_ticks_msec() + int(duration_sec * 1000.0))
	if not _hitstop_active:
		_hitstop_active = true
		Engine.time_scale = HITSTOP_SCALE


func _process(delta: float) -> void:
	# `delta` is scaled by time_scale, so the deadline uses wall-clock instead.
	if _hitstop_active and (Time.get_ticks_msec() >= _hitstop_until_msec or get_tree().paused):
		_end_hitstop()

	if _trauma <= 0.0:
		return

	# Shake advances on real time too, so a freeze frame doesn't stall it.
	var real_delta: float = delta / maxf(Engine.time_scale, 0.001)
	_time += real_delta * SHAKE_SPEED
	_trauma = maxf(_trauma - DECAY * real_delta, 0.0)

	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return

	if _trauma <= 0.001:
		cam.offset = Vector2.ZERO
		return
	var shake := _trauma * _trauma
	cam.offset = Vector2(
		_noise.get_noise_2d(_time, 0.0) * MAX_OFFSET * shake,
		_noise.get_noise_2d(0.0, _time) * MAX_OFFSET * shake
	)


func _end_hitstop() -> void:
	_hitstop_active = false
	_hitstop_until_msec = 0
	Engine.time_scale = 1.0


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
