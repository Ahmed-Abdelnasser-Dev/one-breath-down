extends Node
## Sound. The project shipped with none at all — audio/ held only a bus layout,
## so the options menu was mixing three buses that nothing ever played through.
##
## Like Juice, this listens to the Events bus rather than being called from
## gameplay code, so no script needs a reference to an AudioStreamPlayer. Clips
## are generated (see the generator in the Phase 2 commit) and deliberately
## low-passed: everything down here is heard through water.

const POLYPHONY := 10

const PACK := "res://audio/mp3/JDSherbert - Pixel Game Essentials SFX Pack - %s.mp3"

## Authored clips (the JDSherbert pack) where one exists for the moment, and the
## generated underwater set for the things a generic pack has no equivalent of —
## a held breath, a heartbeat, a body of water.
const CLIPS := {
	&"pearl_pickup": PACK % "Coin 1",
	&"pearl_rare": PACK % "Coin 2",
	&"swing": PACK % "Shoot 1",
	&"hit": PACK % "Box Break 1",
	&"enemy_attack": PACK % "Shoot 2",
	&"hurt": PACK % "Damage 1",
	&"enemy_death": PACK % "Die 2",
	&"player_death": PACK % "Die 1",
	&"drowned": PACK % "Level Fail 1",
	&"bank": PACK % "Level Complete 1",
	&"upgrade": PACK % "Powerup 1",
	&"ui_click": PACK % "Switch 1",
	&"ui_confirm": PACK % "Checkpoint 1",
	# No pack equivalent — keep the generated underwater ones.
	&"splash": "res://audio/sfx/splash.wav",
	&"heartbeat": "res://audio/sfx/heartbeat.wav",
}

const MUSIC_TRACK := "res://audio/gam music.mp3"

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
var _music: AudioStreamPlayer
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
		# loop_end defaults to 0, which is an empty loop range — setting only
		# loop_mode left the bed playing once and then stopping for good.
		var wav := _ambience.stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		@warning_ignore("integer_division")
		wav.loop_end = wav.data.size() / 2   # 16-bit mono: 2 bytes per frame
	_ambience.volume_db = -80.0
	add_child(_ambience)
	_ambience.play()

	# Music sits under everything on its own bus so the options slider governs
	# it independently of the SFX.
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	_music.stream = load(MUSIC_TRACK) as AudioStream
	if _music.stream is AudioStreamMP3:
		(_music.stream as AudioStreamMP3).loop = true
	_music.volume_db = -14.0
	add_child(_music)
	if _music.stream != null:
		_music.play()

	# UI sounds are attached centrally by watching the tree rather than wiring
	# every screen by hand: menus are built across a dozen scenes (and some rows
	# are created at runtime), so anything else would miss some and drift.
	get_tree().node_added.connect(_attach_ui_sound)
	_attach_ui_sound_recursive(get_tree().root)

	Events.pearl_collected.connect(_on_pearl_collected)
	Events.pearls_banked.connect(func(_amount: int) -> void: play(&"bank"))
	Events.player_attacked.connect(func() -> void: play(&"swing", 0.12, -4.0))
	Events.enemy_damaged.connect(func(_id: StringName, _amt: int) -> void: play(&"hit", 0.14))
	Events.enemy_attacked.connect(func(_id: StringName, _at: Vector2) -> void: play(&"enemy_attack", 0.16, -6.0))
	Events.enemy_killed.connect(func(_id: StringName, _at: Vector2) -> void: play(&"enemy_death", 0.1))
	Events.player_damaged.connect(func(_amt: int, _src: StringName) -> void: play(&"hurt", 0.08))
	Events.breath_changed.connect(_on_breath_changed)
	Events.upgrade_purchased.connect(func(_id: StringName) -> void: play(&"upgrade"))
	Events.run_started.connect(func() -> void: _submerged = true)
	Events.run_reset.connect(func() -> void: _submerged = false)
	Events.player_died.connect(_on_player_died)
	Events.player_surfaced.connect(func(_banked: int) -> void: _submerged = false)


func _attach_ui_sound_recursive(node: Node) -> void:
	_attach_ui_sound(node)
	for c in node.get_children():
		_attach_ui_sound_recursive(c)


## Click on press, softer tick on hover/focus — so keyboard navigation sounds
## the same as the mouse. Disabled buttons stay silent.
func _attach_ui_sound(node: Node) -> void:
	if node is BaseButton:
		var b := node as BaseButton
		if b.has_meta(&"sfx_wired"):
			return
		b.set_meta(&"sfx_wired", true)
		b.pressed.connect(func() -> void: play(&"ui_confirm", 0.04, -5.0))
		b.focus_entered.connect(func() -> void: play(&"ui_click", 0.05, -13.0))
		b.mouse_entered.connect(func() -> void:
			if not b.disabled:
				play(&"ui_click", 0.05, -13.0)
		)
	elif node is ItemList:
		var l := node as ItemList
		if l.has_meta(&"sfx_wired"):
			return
		l.set_meta(&"sfx_wired", true)
		l.item_selected.connect(func(_i: int) -> void: play(&"ui_click", 0.05, -10.0))


## Drowning and being eaten deserve different last sounds.
func _on_player_died(cause: String) -> void:
	_submerged = false
	play(&"player_death" if cause == "killed" else &"drowned")


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
	# Null whenever no run scene is live — this autoload outlives the run, so it
	# doubles as the "are we actually diving" test below.
	var zone := ZoneManager.get_current_zone()

	# Ambience swells with depth so the deep sounds heavier than the shallows.
	if _ambience != null:
		# Safety net: if the bed ever stops (import settings, seek, device
		# change), bring it back rather than leaving the dive silent forever.
		if not _ambience.playing:
			_ambience.play()
		var target := -80.0
		if _submerged and zone != null:
			target = lerpf(-26.0, -12.0, zone.darkness)
		_ambience.volume_db = lerpf(_ambience.volume_db, target, clampf(delta * 1.5, 0.0, 1.0))

	# Heartbeat: only underwater, only when the countdown is genuinely biting,
	# accelerating as it runs out. The zone check doubles as "are we still in a
	# run at all" — quitting to the menu mid-dive never clears _submerged.
	if zone == null or not _submerged or _breath_ratio > HEARTBEAT_AT or _breath_ratio <= 0.0:
		_heartbeat_timer = 0.0
		return
	var urgency: float = clampf(1.0 - _breath_ratio / HEARTBEAT_AT, 0.0, 1.0)
	_heartbeat_timer -= delta
	if _heartbeat_timer <= 0.0:
		_heartbeat_timer = lerpf(HEARTBEAT_SLOW, HEARTBEAT_FAST, urgency)
		play(&"heartbeat", 0.0, lerpf(-14.0, -3.0, urgency))
