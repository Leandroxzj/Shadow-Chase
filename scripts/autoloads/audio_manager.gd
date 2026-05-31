extends Node

var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var menu_music_player: AudioStreamPlayer

var chase_music: AudioStream
var ambient_music: AudioStream
var menu_music: AudioStream
var is_chase_mode: bool = false

# Cache de SFX
var _sfx_cache: Dictionary = {}

func _ready() -> void:
	music_player       = AudioStreamPlayer.new()
	sfx_player         = AudioStreamPlayer.new()
	menu_music_player  = AudioStreamPlayer.new()
	add_child(music_player)
	add_child(sfx_player)
	add_child(menu_music_player)

	music_player.bus      = "Music"
	sfx_player.bus        = "SFX"
	menu_music_player.bus = "Music"
	menu_music_player.volume_db = -6.0

	_load_streams()
	load_saved_options()

func _load_streams() -> void:
	var exts := ["mp3", "ogg", "wav"]

	for ext in exts:
		if ResourceLoader.exists("res://assets/audio/music/ambient_loop.%s" % ext):
			ambient_music = load("res://assets/audio/music/ambient_loop.%s" % ext)
			break
	for ext in exts:
		if ResourceLoader.exists("res://assets/audio/music/chase_loop.%s" % ext):
			chase_music = load("res://assets/audio/music/chase_loop.%s" % ext)
			break
	for ext in exts:
		if ResourceLoader.exists("res://assets/audio/music/menu_music.%s" % ext):
			menu_music = load("res://assets/audio/music/menu_music.%s" % ext)
			break

func play_menu_music() -> void:
	if menu_music and not menu_music_player.playing:
		menu_music_player.stream = menu_music
		menu_music_player.play()

func stop_menu_music() -> void:
	if menu_music_player.playing:
		var tween := create_tween()
		tween.tween_property(menu_music_player, "volume_db", -40.0, 1.0)
		tween.tween_callback(menu_music_player.stop)
		tween.tween_callback(func(): menu_music_player.volume_db = -6.0)

func play_ambient() -> void:
	stop_menu_music()
	if is_chase_mode:
		return
	if ambient_music:
		music_player.stream = ambient_music
		music_player.play()

func play_chase() -> void:
	if is_chase_mode:
		return
	is_chase_mode = true
	if chase_music:
		music_player.stream = chase_music
		music_player.play()

func stop_chase() -> void:
	is_chase_mode = false
	if music_player.playing:
		music_player.stop()
	play_ambient()

func reset_music() -> void:
	is_chase_mode = false
	music_player.stop()

func play_sfx(sfx_name: String) -> void:
	# Tenta mp3, ogg, wav em ordem
	var stream: AudioStream = null
	if _sfx_cache.has(sfx_name):
		stream = _sfx_cache[sfx_name]
	else:
		for ext in ["mp3", "ogg", "wav"]:
			var path := "res://assets/audio/sfx/%s.%s" % [sfx_name, ext]
			if ResourceLoader.exists(path):
				stream = load(path)
				_sfx_cache[sfx_name] = stream
				break
	if stream:
		sfx_player.stream = stream
		sfx_player.play()

func play_ui_click() -> void:
	play_sfx("button_click")

func play_ui_hover() -> void:
	play_sfx("button_hover")

# ── Volume ────────────────────────────────────────────────────
func set_master_volume(val: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(val))

func set_menu_music_volume(val: float) -> void:
	menu_music_player.volume_db = linear_to_db(val) if val > 0.0 else -80.0

func set_game_music_volume(val: float) -> void:
	music_player.volume_db = linear_to_db(val) if val > 0.0 else -80.0

func set_sfx_volume(val: float) -> void:
	sfx_player.volume_db = linear_to_db(val) if val > 0.0 else -80.0

func load_saved_options() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://options.cfg") != OK:
		return
	set_menu_music_volume(cfg.get_value("audio", "music_menu", 1.0))
	set_game_music_volume(cfg.get_value("audio", "music_game", 1.0))
	set_sfx_volume(cfg.get_value("audio", "sfx", 1.0))
	set_master_volume(cfg.get_value("audio", "master", 1.0))
	GameManager.brightness = cfg.get_value("video", "brightness", 1.0)
