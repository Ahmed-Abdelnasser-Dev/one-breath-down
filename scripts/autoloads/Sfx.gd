extends Node
## Sound. The project shipped with none at all — audio/ held only a bus layout,
## so the options menu was mixing three buses that nothing ever played through.
##
## Like Juice, this listens to the Events bus rather than being called from
## gameplay code, so no script needs a reference to an AudioStreamPlayer. Clips
## are generated (see the generator in the Phase 2 commit) and deliberately
## low-passed: everything down here is heard through water.

const POLYPHONY := 10

const CLIPS := {
	&"pearl_pickup": "res://audio/sfx/pearl_pickup.wav",
	&"pearl_rare": "res://audio/sfx/pearl_rare.wav",
	&"swing": "res://audio/sfx/swing.wav",
	&"hit": "res://audio/sfx/hit.wav",
	&"hurt": "res://audio/sfx/hurt.wav",
	&"enemy_death": "res://audio/sfx/enemy_death.wav",
	&"splash": "res://audio/sfx/splash.wav",
	&"heartbeat": "res://audio/sfx/heartbeat.wav",
	&"bank": "res://audio/sfx/bank.wav",
	&"ui_click": "res://audio/sfx/ui_click.wav",
	&"ui_confirm": "res://audio/sfx/ui_confirm.wav",
}

## Value above which a pearl gets the richer pickup sound — a golden pearl
## should not sound like a seed pearl.
const RARE_PEARL_VALUE := 100

## Breath fraction under which the heartbeat starts, and its beat spacing at
## the extremes. The GDD calls this out as juice priority #1.
const HEARTBEAT_AT := 0.3
const HEARTBEAT_SLOW := 1.15
const HEARTBEAT_FAST := 0.42

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0

var _ambience: AudioStreamPlayer
var _heartbeat_timer := 0.0
var _breath_ratio := 1.0
var _submerged := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	for id in CLIPS:
		var stream := load(CLIPS[id]) as AudioStream
		if stream != null:
			_streams[id] = stream

	for i in POLYPHONY:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)

	_ambience = AudioStreamPlayer.new()
	_ambience.bus = &"Music"
	_ambience.stream = load("res://audio/sfx/ambient_deep.wav") as AudioStream
	if _ambience.stream is AudioStreamWAV:
		(_ambience.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_ambience.volume_db = -80.0
	add_child(_ambience)
	_ambience.play()

	Events.pearl_collected.connect(_on_pearl_collected)
	Events.pearls_banked.connect(func(_amount: int) -> void: play(&"bank"))
	Events.player_attacked.connect(func() -> void: play(&"swing", 0.12))
	Events.enemy_damaged.connect(func(_id: StringName, _amt: int) -> void: play(&"hit", 0.14))
	Events.enemy_killed.connect(func(_id: StringName, _at: Vector2) -> void: play(&"enemy_death", 0.1))
	Events.player_damaged.connect(func(_amt: int, _src: StringName) -> void: play(&"hurt", 0.08))
	Events.breath_changed.connect(_on_breath_changed)
	Events.upgrade_purchased.connect(func(_id: StringName) -> void: play(&"ui_confirm"))
	Events.run_started.connect(func() -> void: _submerged = true)
	Events.run_reset.connect(func() -> void: _submerged = false)
	Events.player_died.connect(func(_cause: String) -> void: _submerged = false)
	Events.player_surfaced.connect(func(_banked: int) -> void: _submerged = false)


## Round-robin voice stealing: with POLYPHONY voices a burst of pickups or hits
## overlaps instead of cutting itself off.
func play(id: StringName, pitch_jitter: float = 0.0, volume_db: float = 0.0) -> void:
	if not _streams.has(id) or _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[id]
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.volume_db = volume_db
	p.play()


func _on_pearl_collected(data: PearlData) -> void:
	if data != null and data.value >= RARE_PEARL_VALUE:
		play(&"pearl_rare", 0.04)
	else:
		play(&"pearl_pickup", 0.09)


func _on_breath_changed(current: float, maximum: float) -> void:
	_breath_ratio = current / maximum if maximum > 0.0 else 0.0


func _process(delta: float) -> void:
	# Ambience swells with depth so the deep sounds heavier than the shallows.
	if _ambience != null:
		var target := -80.0
		if _submerged and ZoneManager.instance != null and ZoneManager.instance.current_zone != null:
			target = lerpf(-26.0, -12.0, ZoneManager.instance.current_zone.darkness)
		_ambience.volume_db = lerpf(_ambience.volume_db, target, clampf(delta * 1.5, 0.0, 1.0))

	# Heartbeat: only underwater, only when the countdown is genuinely biting,
	# accelerating as it runs out.
	if not _submerged or _breath_ratio > HEARTBEAT_AT or _breath_ratio <= 0.0:
		_heartbeat_timer = 0.0
		return
	var urgency: float = clampf(1.0 - _breath_ratio / HEARTBEAT_AT, 0.0, 1.0)
	_heartbeat_timer -= delta
	if _heartbeat_timer <= 0.0:
		_heartbeat_timer = lerpf(HEARTBEAT_SLOW, HEARTBEAT_FAST, urgency)
		play(&"heartbeat", 0.0, lerpf(-14.0, -3.0, urgency))
