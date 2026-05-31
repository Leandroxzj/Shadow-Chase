extends CharacterBody2D

@onready var flashlight: PointLight2D  = $FlashlightPivot/Flashlight2D
@onready var flashlight_pivot: Node2D  = $FlashlightPivot
@onready var anim: AnimatedSprite2D    = $AnimatedSprite2D
@onready var camera: Camera2D          = $Camera2D

const SPEED: float        = 145.0
const SPRINT_SPEED: float = 230.0

# ── ID do jogador (1 ou 2) ────────────────────────────────────
@export var player_id: int = 1
@export var disable_fog: bool = false  # true no P2 do coop

# ── Stamina ───────────────────────────────────────────────────
const STAMINA_MAX: float      = 100.0
const STAMINA_DRAIN: float    = 22.0
const STAMINA_RECHARGE: float = 10.0
const STAMINA_MIN_USE: float  = 15.0

var stamina: float     = STAMINA_MAX
var is_sprinting: bool = false

signal stamina_changed(value: float, max_value: float)

# ── Bateria ───────────────────────────────────────────────────
const BATTERY_MAX: float      = 100.0
const BATTERY_DRAIN: float    = 8.0
const BATTERY_RECHARGE: float = 4.0

var battery: float      = BATTERY_MAX
var flashlight_on: bool = false

signal battery_changed(value: float, max_value: float)

# ── Shake ─────────────────────────────────────────────────────
var _shake_intensity: float       = 0.0
const SHAKE_DIST_THRESHOLD: float = 150.0

# ── Respiração ofegante ───────────────────────────────────────
var _breath_player: AudioStreamPlayer2D = null
var _breath_active: bool = false

# ── SFX do player ─────────────────────────────────────────────
var _step_player: AudioStreamPlayer   = null
var _step_timer: float                = 0.0
const STEP_INTERVAL_WALK: float       = 0.38
const STEP_INTERVAL_RUN: float        = 0.22

# ── Rastro do player ─────────────────────────────────────────
var _trail_timer: float       = 0.0
const TRAIL_INTERVAL: float   = 0.06
const TRAIL_DURATION: float   = 0.5

# ── Névoa de guerra ───────────────────────────────────────────
var _fog_canvas: CanvasLayer = null
var _revealed: Array         = []   # células já reveladas
const FOG_CELL_SIZE: int     = 96   # tamanho de cada célula de névoa
const MAP_SIZE: int          = 2560 # tamanho total do mapa
const FOG_REVEAL_RADIUS: int = 3    # células reveladas ao redor do player

# ── Isca ─────────────────────────────────────────────────────
const BAIT_COOLDOWN: float = 12.0
var _bait_timer: float     = 0.0
signal bait_changed(ready: bool, cooldown: float, max_cooldown: float)

var is_alive: bool   = true
var last_dir: String = "down"

signal player_died_signal

func _ready() -> void:
	add_to_group("player")
	GameManager.set_player_state("idle")
	anim.play("idle_down")
	flashlight.enabled = false
	modulate = GameManager.get_player_color()
	_setup_breath()
	_setup_sfx()
	if not disable_fog:
		_setup_fog()

# ── Respiração ────────────────────────────────────────────────
func _setup_breath() -> void:
	_breath_player = AudioStreamPlayer2D.new()
	_breath_player.max_distance = 1.0  # só o player ouve
	add_child(_breath_player)

# ── SFX ───────────────────────────────────────────────────────
func _setup_sfx() -> void:
	_step_player = AudioStreamPlayer.new()
	_step_player.volume_db = -4.0
	_step_player.bus = "SFX"
	add_child(_step_player)

func _update_footsteps(delta: float, moving: bool) -> void:
	if not moving:
		_step_timer = 0.0
		if _step_player.playing:
			_step_player.stop()
		return

	_step_timer -= delta
	if _step_timer > 0.0:
		return

	_step_timer = STEP_INTERVAL_RUN if is_sprinting else STEP_INTERVAL_WALK

	var sfx_name := "footstep_run" if is_sprinting else "footstep"
	var stream := _load_step_stream(sfx_name)
	if stream:
		_step_player.stream = stream
		_step_player.play()

func _load_step_stream(name: String) -> AudioStream:
	for ext in ["mp3", "ogg", "wav"]:
		var path := "res://assets/audio/sfx/%s.%s" % [name, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return null

func _update_breath() -> void:
	var dist: float    = GameManager.creature_distance
	var low_stamina    = stamina < 25.0
	var danger_close   = dist < 200.0
	var should_breathe = low_stamina or danger_close or is_sprinting

	if should_breathe and not _breath_active:
		_breath_active = true
		_play_breath_loop(dist, low_stamina)
	elif not should_breathe and _breath_active:
		_breath_active = false
		_breath_player.stop()

func _play_breath_loop(dist: float, low_stamina: bool) -> void:
	# Sem arquivo de áudio real, simula com pitch do AudioStreamPlayer
	# Se existir o arquivo, toca; senão ignora silenciosamente
	var path := "res://assets/audio/sfx/breath.ogg"
	if not ResourceLoader.exists(path):
		path = "res://assets/audio/sfx/creature_growl.ogg"
	if ResourceLoader.exists(path):
		_breath_player.stream = load(path)
		# Pitch mais alto = mais ofegante
		var danger: float = 1.0 - clamp(dist / 200.0, 0.0, 1.0)
		_breath_player.pitch_scale = lerp(0.9, 1.6, danger)
		_breath_player.volume_db   = lerp(-12.0, 0.0, danger)
		_breath_player.play()

# ── Rastro do player ─────────────────────────────────────────
func _update_trail(delta: float) -> void:
	if velocity.length() < 10.0:
		return
	_trail_timer -= delta
	if _trail_timer > 0.0:
		return
	_trail_timer = TRAIL_INTERVAL

	var ghost := ColorRect.new()
	ghost.size     = Vector2(20, 32)
	ghost.position = global_position - Vector2(10, 16)
	# Cor roxa/escura para o rastro, mais brilhante ao correr
	var alpha: float = 0.35 if is_sprinting else 0.2
	ghost.color = Color(0.3, 0.1, 0.5, alpha)
	get_tree().current_scene.add_child(ghost)

	var tween := ghost.create_tween()
	tween.tween_property(ghost, "color:a", 0.0, TRAIL_DURATION).set_trans(Tween.TRANS_SINE)
	tween.tween_property(ghost, "scale", Vector2(0.5, 0.5), TRAIL_DURATION * 0.8)
	tween.tween_callback(ghost.queue_free)

# ── Névoa de guerra ───────────────────────────────────────────
func _setup_fog() -> void:
	_fog_canvas = CanvasLayer.new()
	_fog_canvas.layer = 5  # acima do jogo, abaixo do HUD
	get_tree().current_scene.add_child(_fog_canvas)

	var cells_per_row := MAP_SIZE / FOG_CELL_SIZE
	_revealed.resize(cells_per_row * cells_per_row)
	_revealed.fill(false)

	# Cria um nó pai para todas as células
	var fog_root := Node2D.new()
	_fog_canvas.add_child(fog_root)

	for y in cells_per_row:
		for x in cells_per_row:
			var cell := ColorRect.new()
			cell.size     = Vector2(FOG_CELL_SIZE, FOG_CELL_SIZE)
			cell.position = Vector2(x * FOG_CELL_SIZE, y * FOG_CELL_SIZE)
			cell.color    = Color(0.0, 0.0, 0.0, 0.88)
			cell.name     = "fog_%d_%d" % [x, y]
			fog_root.add_child(cell)

func _update_fog() -> void:
	if _revealed.is_empty():
		return
	var cells_per_row := MAP_SIZE / FOG_CELL_SIZE
	var px := int(global_position.x / FOG_CELL_SIZE)
	var py := int(global_position.y / FOG_CELL_SIZE)

	for dy in range(-FOG_REVEAL_RADIUS, FOG_REVEAL_RADIUS + 1):
		for dx in range(-FOG_REVEAL_RADIUS, FOG_REVEAL_RADIUS + 1):
			var cx := px + dx
			var cy := py + dy
			if cx < 0 or cy < 0 or cx >= cells_per_row or cy >= cells_per_row:
				continue
			var idx := cy * cells_per_row + cx
			if _revealed[idx]:
				continue
			_revealed[idx] = true
			# Distância do centro para fade circular
			var dist_cells := Vector2(dx, dy).length()
			if dist_cells > FOG_REVEAL_RADIUS:
				continue
			var cell_name := "fog_%d_%d" % [cx, cy]
			var fog_root := _fog_canvas.get_child(0)
			if fog_root:
				var cell := fog_root.get_node_or_null(cell_name)
				if cell:
					var fade_alpha: float = clamp(dist_cells / float(FOG_REVEAL_RADIUS), 0.0, 1.0) * 0.7
					var tween := cell.create_tween()
					tween.tween_property(cell, "color:a", fade_alpha, 0.4)

# ── Input ─────────────────────────────────────────────────────
func _input(_event: InputEvent) -> void:
	var fl_action := "p%d_flashlight" % player_id
	if Input.is_action_just_pressed(fl_action):
		if not flashlight_on and battery <= 0.0:
			return
		flashlight_on = not flashlight_on
		flashlight.enabled = flashlight_on
		AudioManager.play_sfx("flashlight_on" if flashlight_on else "flashlight_off")

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	_update_battery(delta)
	_update_stamina(delta)
	_update_screen_shake(delta)
	_update_breath()
	_update_fog()
	_handle_input()
	_update_footsteps(delta, velocity.length() > 10.0)
	move_and_slide()

# ── Bateria ───────────────────────────────────────────────────
func _update_battery(delta: float) -> void:
	if flashlight_on:
		battery -= BATTERY_DRAIN * GameManager.get_battery_drain_mult() * delta
		if battery <= 0.0:
			battery = 0.0
			flashlight_on = false
			flashlight.enabled = false
	else:
		battery = minf(battery + BATTERY_RECHARGE * delta, BATTERY_MAX)
	battery_changed.emit(battery, BATTERY_MAX)

# ── Stamina ───────────────────────────────────────────────────
func _update_stamina(delta: float) -> void:
	var sprint_action := "p%d_sprint" % player_id
	var want_sprint := Input.is_action_pressed(sprint_action)
	if want_sprint and stamina >= STAMINA_MIN_USE:
		is_sprinting = true
		stamina -= STAMINA_DRAIN * GameManager.get_stamina_drain_mult() * delta
		if stamina <= 0.0:
			stamina = 0.0
			is_sprinting = false
	else:
		is_sprinting = false
		stamina = minf(stamina + STAMINA_RECHARGE * delta, STAMINA_MAX)
	stamina_changed.emit(stamina, STAMINA_MAX)

# ── Shake ─────────────────────────────────────────────────────
func _update_screen_shake(delta: float) -> void:
	var dist: float = GameManager.creature_distance
	if dist < SHAKE_DIST_THRESHOLD:
		var t: float = 1.0 - clamp(dist / SHAKE_DIST_THRESHOLD, 0.0, 1.0)
		_shake_intensity = lerp(_shake_intensity, t * 6.0, 8.0 * delta)
	else:
		_shake_intensity = lerp(_shake_intensity, 0.0, 6.0 * delta)
	if _shake_intensity > 0.1:
		camera.offset = Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
	else:
		camera.offset = Vector2.ZERO

# ── Movimento ─────────────────────────────────────────────────
func _handle_input() -> void:
	var left_action  := "p%d_move_left"  % player_id
	var right_action := "p%d_move_right" % player_id
	var up_action    := "p%d_move_up"    % player_id
	var down_action  := "p%d_move_down"  % player_id

	var dir := Vector2(
		Input.get_axis(left_action, right_action),
		Input.get_axis(up_action, down_action)
	).normalized()

	var current_speed := SPRINT_SPEED if is_sprinting else SPEED
	velocity = dir * current_speed

	if dir != Vector2.ZERO:
		if abs(dir.x) >= abs(dir.y):
			last_dir = "right" if dir.x > 0 else "left"
		else:
			last_dir = "down" if dir.y > 0 else "up"
		var run_anim := "run_" + last_dir
		if anim.animation != run_anim:
			anim.play(run_anim)
		anim.speed_scale = 1.6 if is_sprinting else 1.0
		_update_flashlight_rotation()
		GameManager.set_player_state("walk")
	else:
		var idle_anim := "idle_" + last_dir
		if anim.animation != idle_anim:
			anim.play(idle_anim)
		anim.speed_scale = 1.0
		GameManager.set_player_state("idle")

func _update_flashlight_rotation() -> void:
	match last_dir:
		"right": flashlight_pivot.rotation = 0.0
		"down":  flashlight_pivot.rotation = PI / 2.0
		"left":  flashlight_pivot.rotation = PI
		"up":    flashlight_pivot.rotation = -PI / 2.0

func _throw_bait() -> void:
	if _bait_timer > 0.0:
		return
	_bait_timer = BAIT_COOLDOWN
	bait_changed.emit(false, _bait_timer, BAIT_COOLDOWN)

	# Lança a isca na direção que o player está olhando
	var bait_script := load("res://scripts/bait.gd")
	var bait := Area2D.new()
	bait.set_script(bait_script)
	var throw_dir := Vector2.ZERO
	match last_dir:
		"right": throw_dir = Vector2(1, 0)
		"left":  throw_dir = Vector2(-1, 0)
		"down":  throw_dir = Vector2(0, 1)
		"up":    throw_dir = Vector2(0, -1)
	bait.global_position = global_position + throw_dir * 150.0
	get_tree().current_scene.add_child(bait)

# ── Morte / Respawn ───────────────────────────────────────────
func die() -> void:
	if not is_alive:
		return
	is_alive = false
	velocity = Vector2.ZERO
	camera.offset = Vector2.ZERO
	_breath_player.stop()
	AudioManager.play_sfx("player_death")
	anim.play("death")
	GameManager.set_player_state("dead")
	GameManager.register_error("death")
	ChatManager.send_game_event("player_died")
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.15)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.3)
	tween.tween_callback(func(): player_died_signal.emit())

func respawn(pos: Vector2) -> void:
	is_alive = true
	global_position = pos
	velocity = Vector2.ZERO
	scale = Vector2.ONE
	camera.offset = Vector2.ZERO
	anim.play("idle_" + last_dir)
	GameManager.set_player_state("idle")
