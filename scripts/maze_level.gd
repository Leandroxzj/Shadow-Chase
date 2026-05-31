extends Node2D

@export var level_number: int = 1
@export var spawn_position: Vector2 = Vector2(192, 192)

var player_ref: CharacterBody2D
var player2_ref: CharacterBody2D  # P2 no modo coop
var chat_timer: Timer
var fake_sound_timer: Timer
var darkness_timer: Timer
var speed_timer: Timer

var keys_collected: int    = 0
var total_keys: int        = 3
var monster_awakened: bool = false
var _creatures: Array      = []   # todas as criaturas ativas
var _exit_blocker: StaticBody2D = null

# ── Escuridão ─────────────────────────────────────────────────
var _darkness_level: float        = 0.0
const DARKNESS_STEP: float        = 0.06
const DARKNESS_INTERVAL: float    = 20.0
const DARKNESS_MIN_COLOR: Color   = Color(0.04, 0.03, 0.05, 1.0)
const DARKNESS_START_COLOR: Color = Color(0.14, 0.11, 0.18, 1.0)

# ── Aceleração ────────────────────────────────────────────────
const SPEED_INTERVAL: float = 30.0
const SPEED_STEP: float     = 0.12

# ── Posições de spawn das criaturas extras ────────────────────
const CREATURE_SPAWNS: Array[Vector2] = [
	Vector2(2048, 2361),  # original
	Vector2(256,  2400),  # sudoeste
	Vector2(2400, 256),   # nordeste
	Vector2(2400, 2400),  # sudeste
	Vector2(256,  256),   # noroeste
	Vector2(1280, 2400),  # sul centro
	Vector2(2400, 1280),  # leste centro
	Vector2(1280, 256),   # norte centro
	Vector2(256,  1280),  # oeste centro
	Vector2(1800, 1800),  # centro-sul
]

# ── Posições das chaves (pool grande) ────────────────────────
const ALL_KEY_POSITIONS: Array[Vector2] = [
	Vector2(700,  450),   Vector2(1344, 1344), Vector2(2100, 1980),
	Vector2(400,  1800),  Vector2(2200, 400),  Vector2(1800, 800),
	Vector2(500,  900),   Vector2(1600, 1600), Vector2(900,  2100),
	Vector2(2100, 1100),  Vector2(1100, 600),  Vector2(600,  1500),
	Vector2(1900, 2200),
]

# ── Sons falsos ───────────────────────────────────────────────
const FAKE_SOUND_POSITIONS: Array = [
	Vector2(512, 512),   Vector2(1024, 256),  Vector2(1800, 400),
	Vector2(400, 1200),  Vector2(1300, 1300), Vector2(700, 1900),
	Vector2(2100, 700),  Vector2(1600, 2000), Vector2(900, 2200),
	Vector2(2200, 1500)
]

func _ready() -> void:
	GameManager.reset()
	GameManager.current_level = level_number
	GameManager.is_maze_level = true
	total_keys = GameManager.get_key_count()
	AudioManager.reset_music()

	_setup_player()
	_setup_creatures()
	# Aplica brilho salvo nas opções
	await get_tree().process_frame
	_apply_brightness_to_canvas()
	if GameManager.endless_mode:
		# Remove todas as chaves existentes na cena
		for k in get_tree().get_nodes_in_group("key"):
			k.queue_free()
	else:
		_setup_keys()
	_setup_floor_messages()
	_setup_chat_timer()
	_setup_fake_sound_timer()
	_setup_darkness_timer()
	_setup_speed_timer()
	_setup_key_hud()
	if not GameManager.endless_mode:
		_setup_exit_blocker()
	AudioManager.play_ambient()
	_spawn_vhs_effect()
	_spawn_sorriso()
	if GameManager.endless_mode:
		_spawn_endless_manager()
		# Acorda todas as criaturas imediatamente
		for i in _creatures.size():
			_awaken_creature(_creatures[i], i)
		monster_awakened = true
		chat_timer.start()
		fake_sound_timer.start()
		darkness_timer.start()
		speed_timer.start()
	await get_tree().process_frame
	ChatManager.send_game_event("level_start")

# ── Mensagens no chão ─────────────────────────────────────────
const MESSAGE_POSITIONS: Array[Vector2] = [
	Vector2(400,  300),   Vector2(900,  600),   Vector2(500,  1100),
	Vector2(1100, 400),   Vector2(1500, 700),   Vector2(1900, 500),
	Vector2(700,  1500),  Vector2(1200, 1700),  Vector2(1700, 1300),
	Vector2(300,  1900),  Vector2(800,  2100),  Vector2(1400, 2000),
	Vector2(2000, 1700),  Vector2(2200, 900),   Vector2(1600, 2200),
]

func _setup_floor_messages() -> void:
	var msg_script := load("res://scripts/floor_message.gd")
	# Embaralha posições para variar a cada partida
	var positions := MESSAGE_POSITIONS.duplicate()
	positions.shuffle()

	for i in min(positions.size(), 12):
		var node := Area2D.new()
		node.set_script(msg_script)
		node.set("message_index", i)
		node.global_position = positions[i]
		$World.add_child(node)

# ── Player ────────────────────────────────────────────────────
func _setup_player() -> void:
	player_ref = $Player
	player_ref.global_position = spawn_position
	player_ref.player_id = 1
	player_ref.player_died_signal.connect(_on_player_died)

	# Spawna P2 no modo coop
	if GameManager.coop_mode:
		var player_scene := load("res://scenes/player.tscn") as PackedScene
		player2_ref = player_scene.instantiate()
		player2_ref.player_id = 2
		player2_ref.disable_fog = true
		player2_ref.global_position = spawn_position + Vector2(64, 0)
		player2_ref.modulate = Color(0.5, 0.7, 1.0, 1.0)
		add_child(player2_ref)
		# Desativa câmera do P2
		var cam2 := player2_ref.get_node_or_null("Camera2D")
		if cam2:
			cam2.enabled = false
		player2_ref.player_died_signal.connect(_on_player2_died)
		# Câmera do P1 vira coop camera
		var cam1 := player_ref.get_node_or_null("Camera2D") as Camera2D
		if cam1:
			cam1.set_script(load("res://scripts/coop_camera.gd"))

# ── Criaturas ─────────────────────────────────────────────────
func _setup_creatures() -> void:
	var count := GameManager.get_creature_count()
	var creature_scene := load("res://scenes/creature.tscn") as PackedScene

	# Primeira criatura já está na cena
	var first := $Creature
	first.ghost_mode = true
	first.set_physics_process(false)
	first.modulate.a = 0.7
	_creatures.append(first)

	# Spawna as extras
	for i in range(1, count):
		var c := creature_scene.instantiate()
		c.ghost_mode = true
		c.modulate.a = 0.0
		var spawn_idx := i % CREATURE_SPAWNS.size()
		c.global_position = CREATURE_SPAWNS[spawn_idx]
		add_child(c)
		_creatures.append(c)

# ── Chaves ────────────────────────────────────────────────────
func _setup_keys() -> void:
	# Remove chaves existentes na cena e recria pelo total_keys
	var existing := get_tree().get_nodes_in_group("key")
	for k in existing:
		k.queue_free()
	await get_tree().process_frame

	var key_scene_script := load("res://scripts/key_item.gd")
	var ref_frames: SpriteFrames = null

	# Pega frames de referência de qualquer chave existente antes de remover
	# Como já removemos, vamos criar do zero com ColorRect simples
	for i in total_keys:
		var key := Area2D.new()
		key.set_script(key_scene_script)
		key.set("key_index", i)
		key.set("is_fake", false)
		key.add_to_group("key")

		var shape := RectangleShape2D.new()
		shape.size = Vector2(28, 28)
		var col := CollisionShape2D.new()
		col.shape = shape
		key.add_child(col)

		var lbl := Label.new()
		lbl.text = "🗝"
		lbl.position = Vector2(-10, -14)
		lbl.add_theme_font_size_override("font_size", 20)
		key.add_child(lbl)

		# Posição
		var pos_idx := i % ALL_KEY_POSITIONS.size()
		key.global_position = ALL_KEY_POSITIONS[pos_idx]

		key.key_collected.connect(_on_key_collected)
		if key.has_signal("fake_key_triggered"):
			key.fake_key_triggered.connect(_on_fake_key_triggered)
		$World.add_child(key)

	# Spawna 1 chave falsa
	_spawn_fake_key()

func _spawn_fake_key() -> void:
	var key_script := load("res://scripts/key_item.gd")
	var fake := Area2D.new()
	fake.set_script(key_script)
	fake.set("is_fake", true)
	fake.set("key_index", 99)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 28)
	var col := CollisionShape2D.new()
	col.shape = shape
	fake.add_child(col)

	var lbl := Label.new()
	lbl.text = "🗝"
	lbl.position = Vector2(-10, -14)
	lbl.add_theme_font_size_override("font_size", 20)
	fake.add_child(lbl)

	var positions := [
		Vector2(900, 900), Vector2(1600, 600), Vector2(600, 1600),
		Vector2(1800, 1800), Vector2(400, 800)
	]
	fake.global_position = positions[randi() % positions.size()]
	fake.fake_key_triggered.connect(_on_fake_key_triggered)
	$World.add_child(fake)

func _on_fake_key_triggered() -> void:
	for c in _creatures:
		if is_instance_valid(c) and c.has_method("stun"):
			c.stun(5.0)
	var hud = $HUD
	if hud and hud.has_method("_show_warning"):
		hud._show_warning("⚠ Era uma armadilha!")

# ── Timers ────────────────────────────────────────────────────
func _setup_chat_timer() -> void:
	chat_timer = Timer.new()
	add_child(chat_timer)
	chat_timer.wait_time = 12.0
	chat_timer.autostart = false
	chat_timer.timeout.connect(_on_chat_timer_timeout)

func _setup_darkness_timer() -> void:
	darkness_timer = Timer.new()
	add_child(darkness_timer)
	darkness_timer.wait_time = DARKNESS_INTERVAL
	darkness_timer.autostart = false
	darkness_timer.timeout.connect(_on_darkness_tick)

func _on_darkness_tick() -> void:
	_darkness_level = clamp(_darkness_level + DARKNESS_STEP, 0.0, 1.0)
	_apply_brightness_to_canvas()
	if _darkness_level >= 0.5:
		var hud = $HUD
		if hud and hud.has_method("show_darkness_warning"):
			hud.show_darkness_warning()

func _apply_brightness_to_canvas() -> void:
	var canvas := get_node_or_null("CanvasModulate") as CanvasModulate
	if not canvas:
		return
	# Começa da cor base ajustada pelo brilho do jogador
	var br: float = GameManager.brightness
	var base := DARKNESS_START_COLOR
	if br < 1.0:
		base = base.darkened((1.0 - br) * 0.8)
	else:
		base = base.lightened((br - 1.0) * 0.5)
	# Aplica escuridão progressiva por cima
	var final_color := base.lerp(DARKNESS_MIN_COLOR, _darkness_level)
	var tween := create_tween()
	tween.tween_property(canvas, "color", final_color, 0.5).set_trans(Tween.TRANS_SINE)

func _setup_speed_timer() -> void:
	speed_timer = Timer.new()
	add_child(speed_timer)
	speed_timer.wait_time = SPEED_INTERVAL
	speed_timer.autostart = false
	speed_timer.timeout.connect(_on_speed_tick)

func _on_speed_tick() -> void:
	for c in _creatures:
		if is_instance_valid(c):
			c.increase_aggression(SPEED_STEP)

func _setup_fake_sound_timer() -> void:
	fake_sound_timer = Timer.new()
	add_child(fake_sound_timer)
	fake_sound_timer.wait_time = randf_range(8.0, 18.0)
	fake_sound_timer.autostart = false
	fake_sound_timer.one_shot  = true
	fake_sound_timer.timeout.connect(_on_fake_sound_timeout)

func _on_fake_sound_timeout() -> void:
	_play_fake_sound()
	fake_sound_timer.wait_time = randf_range(8.0, 20.0)
	fake_sound_timer.start()

func _play_fake_sound() -> void:
	var candidates: Array = []
	for pos in FAKE_SOUND_POSITIONS:
		if player_ref.global_position.distance_to(pos) > 300.0:
			candidates.append(pos)
	if candidates.is_empty():
		candidates = FAKE_SOUND_POSITIONS
	var chosen_pos: Vector2 = candidates[randi() % candidates.size()]
	var fake_player := AudioStreamPlayer2D.new()
	fake_player.position = chosen_pos
	fake_player.max_distance = 600.0
	fake_player.attenuation = 1.5
	add_child(fake_player)
	var sfx_path := "res://assets/audio/sfx/footstep.ogg"
	if not ResourceLoader.exists(sfx_path):
		sfx_path = "res://assets/audio/sfx/creature_growl.ogg"
	if ResourceLoader.exists(sfx_path):
		fake_player.stream = load(sfx_path)
		fake_player.play()
		await fake_player.finished
	fake_player.queue_free()

# ── HUD / Saída ───────────────────────────────────────────────
func _setup_key_hud() -> void:
	if GameManager.endless_mode:
		return
	var hud = $HUD
	if hud and hud.has_method("set_keys"):
		hud.set_keys(keys_collected, total_keys)

func _setup_exit_blocker() -> void:
	_exit_blocker = StaticBody2D.new()
	_exit_blocker.position = Vector2(2368, 2368)
	_exit_blocker.collision_layer = 1
	_exit_blocker.collision_mask  = 1
	var shape := RectangleShape2D.new()
	shape.size = Vector2(96, 96)
	var col := CollisionShape2D.new()
	col.shape = shape
	_exit_blocker.add_child(col)
	var vis := ColorRect.new()
	vis.size = Vector2(96, 96)
	vis.position = Vector2(-48, -48)
	vis.color = Color(0.5, 0.05, 0.05, 0.85)
	_exit_blocker.add_child(vis)
	var lbl := Label.new()
	lbl.text = "🔒"
	lbl.position = Vector2(-16, -20)
	lbl.add_theme_font_size_override("font_size", 28)
	_exit_blocker.add_child(lbl)
	$World.add_child(_exit_blocker)

# ── Lógica de chaves ──────────────────────────────────────────
func _on_key_collected(_key_index: int) -> void:
	keys_collected += 1
	GameManager.keys_collected_total = keys_collected
	_update_key_hud()

	# Conquista ao pegar primeira chave
	if keys_collected == 1:
		GameManager.unlock_achievement("first_key")

	# Acorda criaturas progressivamente conforme chaves coletadas
	var count := GameManager.get_creature_count()
	var to_wake := int(float(keys_collected) / float(total_keys) * float(count))
	to_wake = clamp(to_wake, 1, count)
	for i in to_wake:
		if i < _creatures.size():
			var c = _creatures[i]
			if is_instance_valid(c) and not c.is_physics_processing():
				_awaken_creature(c, i)

	if not monster_awakened and keys_collected >= 1:
		monster_awakened = true
		chat_timer.start()
		fake_sound_timer.start()
		darkness_timer.start()
		speed_timer.start()

	if keys_collected >= total_keys:
		_open_exit()

func _awaken_creature(c: Node, idx: int) -> void:
	c.set_physics_process(true)
	var tween := create_tween()
	tween.tween_property(c, "modulate:a", 0.92 if c.ghost_mode else 1.0, 1.0)
	if idx == 0:
		ChatManager.send_game_event("chase_start")

func _open_exit() -> void:
	if is_instance_valid(_exit_blocker):
		var tween_block := create_tween()
		tween_block.tween_property(_exit_blocker.get_child(1), "color:a", 0.0, 0.4)
		tween_block.tween_callback(_exit_blocker.queue_free)
	var exit_marker = $World/ExitMarker
	var exit_label  = $World/ExitLabel
	var finish_area = $FinishArea
	if exit_marker:
		var tween := create_tween()
		exit_marker.color = Color(0.0, 0.8, 0.2, 0.15)
		tween.tween_property(exit_marker, "color", Color(0.0, 0.8, 0.2, 0.85), 0.5)
	if exit_label:
		exit_label.modulate = Color(0.2, 1.0, 0.2, 1)
		exit_label.text = "SAÍDA ✓"
	if finish_area:
		finish_area.monitoring = true

func _update_key_hud() -> void:
	var hud = $HUD
	if hud and hud.has_method("set_keys"):
		hud.set_keys(keys_collected, total_keys)

func _on_chat_timer_timeout() -> void:
	ChatManager.send_game_event("periodic_check")
	for c in _creatures:
		if is_instance_valid(c):
			c.increase_aggression(0.08)

func _on_player_died() -> void:
	# No coop, só game over se os dois morreram
	if GameManager.coop_mode and is_instance_valid(player2_ref) and player2_ref.is_alive:
		return
	chat_timer.stop()
	fake_sound_timer.stop()
	darkness_timer.stop()
	speed_timer.stop()
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/game_over.tscn")

func _on_player2_died() -> void:
	# Mesmo comportamento — só game over se os dois morreram
	if is_instance_valid(player_ref) and player_ref.is_alive:
		return
	chat_timer.stop()
	fake_sound_timer.stop()
	darkness_timer.stop()
	speed_timer.stop()
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/game_over.tscn")

func _setup_light_traps() -> void:
	var trap_script := load("res://scripts/light_trap.gd")
	var trap_shape  := CircleShape2D.new()
	trap_shape.radius = 80.0
	var positions := [
		Vector2(640, 640),   Vector2(1920, 640),
		Vector2(640, 1920),  Vector2(1920, 1920),
	]
	for pos in positions:
		var trap := Area2D.new()
		trap.set_script(trap_script)
		trap.global_position = pos
		$World.add_child(trap)

func _spawn_vhs_effect() -> void:
	var vhs_script := load("res://scripts/vhs_effect.gd")
	var vhs := CanvasLayer.new()
	vhs.set_script(vhs_script)
	add_child(vhs)

func _spawn_sorriso() -> void:
	var script := load("res://scripts/sorriso_effect.gd")
	var node := Node2D.new()
	node.set_script(script)
	add_child(node)

func _spawn_minimap() -> void:
	var script := load("res://scripts/minimap.gd")
	var node := CanvasLayer.new()
	node.set_script(script)
	add_child(node)

func _spawn_tutorial() -> void:
	var script := load("res://scripts/tutorial.gd")
	var node := CanvasLayer.new()
	node.set_script(script)
	add_child(node)

func _spawn_endless_manager() -> void:
	var script := load("res://scripts/endless_manager.gd")
	var node := Node.new()
	node.set_script(script)
	add_child(node)

func _on_finish_area_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if keys_collected < total_keys:
		return
	ChatManager.send_game_event("level_complete")
	GameManager.level_completed.emit()
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://scenes/victory.tscn")
