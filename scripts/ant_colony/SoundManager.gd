extends Node
## Asset-backed Audio Manager: CC0 BGM + CC0 ant-die squish + WAV SFX in assets/ant_colony/audio/.
const BGM_STREAM = preload("res://assets/ant_colony/audio/bgm_forest.mp3")
const SFX_ANT_DIE = preload("res://assets/ant_colony/audio/ant_die.mp3")
const SFX_COIN = preload("res://assets/ant_colony/audio/coin.wav")
const SFX_STAR = preload("res://assets/ant_colony/audio/star.wav")
const SFX_SUGAR = preload("res://assets/ant_colony/audio/power_sugar.wav")
const SFX_SHIELD = preload("res://assets/ant_colony/audio/power_shield.wav")
const SFX_RALLY = preload("res://assets/ant_colony/audio/power_rally.wav")
const SFX_HONEY = preload("res://assets/ant_colony/audio/power_honey.wav")
const SFX_WIN = preload("res://assets/ant_colony/audio/win.wav")
const SFX_LOSE = preload("res://assets/ant_colony/audio/lose.wav")
const SFX_DEPLOY = preload("res://assets/ant_colony/audio/deploy.wav")
const SFX_CAPTURE_WIN = preload("res://assets/ant_colony/audio/capture_win.wav")
const SFX_CAPTURE_LOSE = preload("res://assets/ant_colony/audio/capture_lose.wav")
const SFX_CLICK = preload("res://assets/ant_colony/audio/ui_click.wav")

var muted := false
var music_muted := false
var _last_hit_ms := 0
var _bgm_player: AudioStreamPlayer
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0

func _ready() -> void:
	muted = GameProgress.sound_muted
	music_muted = GameProgress.music_muted

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = -13.0
	_bgm_player.stream = BGM_STREAM
	_bgm_player.finished.connect(_on_bgm_finished)
	add_child(_bgm_player)
	if not music_muted:
		_bgm_player.play()

	for i in range(8):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)

func _on_bgm_finished() -> void:
	if not music_muted and is_instance_valid(_bgm_player):
		_bgm_player.play()

func set_muted(value: bool) -> void:
	muted = value
	GameProgress.sound_muted = value
	GameProgress.save_progress()

func toggle_mute() -> bool:
	set_muted(not muted)
	if not muted:
		play_click()
	return muted

func set_music_muted(value: bool) -> void:
	music_muted = value
	GameProgress.music_muted = value
	GameProgress.save_progress()
	if is_instance_valid(_bgm_player):
		if music_muted:
			_bgm_player.stop()
		elif not _bgm_player.playing:
			_bgm_player.play()

func toggle_music() -> bool:
	set_music_muted(not music_muted)
	play_click()
	return music_muted

func play_click() -> void:
	_play_stream(SFX_CLICK, -4.0)

func play_deploy() -> void:
	_play_stream(SFX_DEPLOY, -3.0)

func play_coin() -> void:
	_play_stream(SFX_COIN, -2.0)

func play_star() -> void:
	_play_stream(SFX_STAR, -2.0)

func play_ant_die() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_hit_ms < 95:
		return
	_last_hit_ms = now
	_play_stream(SFX_ANT_DIE, -7.0, randf_range(0.92, 1.12))

func play_hit() -> void:
	play_ant_die()

func play_capture(player_won: bool) -> void:
	_play_stream(SFX_CAPTURE_WIN if player_won else SFX_CAPTURE_LOSE, -1.0)

func play_powerup(key: String) -> void:
	match key:
		"sugar":
			_play_stream(SFX_SUGAR, -1.0)
		"shield":
			_play_stream(SFX_SHIELD, -1.0)
		"rally":
			_play_stream(SFX_RALLY, -1.0)
		"honey":
			_play_stream(SFX_HONEY, -1.0)
		_:
			play_click()

func play_victory() -> void:
	_play_stream(SFX_WIN, -1.0)

func play_defeat() -> void:
	_play_stream(SFX_LOSE, -1.0)

func _play_stream(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if muted or stream == null or _players.is_empty():
		return
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()
