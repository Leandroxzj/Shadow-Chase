extends Node2D

const VANISH_DIST: float       = 280.0
const FLASHLIGHT_DIST: float   = 380.0
const MIN_SPAWN_DIST: float    = 250.0  # mínimo longe do player

# Tempos por dificuldade [EASY, NORMAL, HARD, SHADOW]
const DIFF_REAPPEAR_MIN: Array = [12.0, 7.0,  3.0,  1.0]
const DIFF_REAPPEAR_MAX: Array = [22.0, 15.0, 8.0,  3.5]

const DARK_POSITIONS: Array[Vector2] = [
	Vector2(300,  300),   Vector2(2200, 300),  Vector2(300,  2200),
	Vector2(2200, 2200),  Vector2(1280, 400),  Vector2(400,  1280),
	Vector2(2100, 1280),  Vector2(1280, 2100), Vector2(700,  700),
	Vector2(1800, 700),   Vector2(700,  1800), Vector2(1800, 1800),
	Vector2(1000, 1000),  Vector2(1500, 1500), Vector2(500,  1500),
	Vector2(1500, 500),   Vector2(900,  300),  Vector2(2100, 900),
	Vector2(300,  900),   Vector2(900,  2100), Vector2(1700, 300),
]

var _sprite: Sprite2D      = null
var _player: Node2D        = null
var _hud: Node             = null
var _visible_sorriso: bool = false
var _reappear_timer: float = 0.0
var _tween: Tween          = null
var _pulse_tween: Tween    = null

func _ready() -> void:
	_build_sprite()
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	_hud    = get_tree().get_first_node_in_group("hud")
	_sprite.modulate.a = 0.0
	var diff: int = GameManager.difficulty
	_reappear_timer = randf_range(DIFF_REAPPEAR_MIN[diff], DIFF_REAPPEAR_MAX[diff])

func _build_sprite() -> void:
	_sprite = Sprite2D.new()
	var tex := load("res://images/Sorriso1.png") as Texture2D
	if tex:
		_sprite.texture = tex
	_sprite.scale      = Vector2(0.25, 0.25)
	_sprite.modulate.a = 0.0
	_sprite.z_index    = 10
	add_child(_sprite)

func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		return

	# Recupera sanidade
	if is_instance_valid(_hud) and _hud.has_method("recover_sanity"):
		_hud.recover_sanity(delta)

	if not _visible_sorriso:
		_reappear_timer -= delta
		if _reappear_timer <= 0.0:
			_try_appear()
		return

	# Verifica distância de TODOS os jogadores
	var vanish := false
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p):
			continue
		var dist: float = global_position.distance_to(p.global_position)
		var fl_on: bool = p.get("flashlight_on") if p.get("flashlight_on") != null else false
		if dist < VANISH_DIST or (fl_on and dist < FLASHLIGHT_DIST):
			vanish = true
			break

	if vanish:
		_vanish_with_sanity()

func _try_appear() -> void:
	if not is_instance_valid(_player):
		return

	# Pega a câmera do player para calcular o campo de visão
	var camera := _player.get_node_or_null("Camera2D") as Camera2D
	var cam_pos := _player.global_position
	var zoom := Vector2(1.5, 1.5)
	if camera:
		cam_pos = camera.get_screen_center_position()
		zoom    = camera.zoom

	# Tamanho visível do mundo (viewport / zoom)
	var vp_size := _player.get_viewport().get_visible_rect().size
	var half_w: float = (vp_size.x / zoom.x) * 0.5
	var half_h: float = (vp_size.y / zoom.y) * 0.5

	# Escolhe posição dentro da tela mas não muito perto do player
	var attempts := 0
	var chosen := Vector2.ZERO
	while attempts < 20:
		attempts += 1
		var rx: float = randf_range(-half_w * 0.85, half_w * 0.85)
		var ry: float = randf_range(-half_h * 0.85, half_h * 0.85)
		var candidate := cam_pos + Vector2(rx, ry)
		var dist_to_player: float = _player.global_position.distance_to(candidate)
		# Deve estar visível mas não tão perto que some imediatamente
		if dist_to_player >= VANISH_DIST + 60.0:
			chosen = candidate
			break

	if chosen == Vector2.ZERO:
		# Fallback — coloca na borda da tela
		chosen = cam_pos + Vector2(half_w * 0.7, half_h * 0.7)

	global_position  = chosen
	_visible_sorriso = true

	if _tween:
		_tween.kill()
	if _pulse_tween:
		_pulse_tween.kill()

	_tween = create_tween()
	_tween.tween_property(_sprite, "modulate:a", 0.0, 0.0)
	_tween.tween_interval(randf_range(0.3, 1.0))
	_tween.tween_property(_sprite, "modulate:a", randf_range(0.6, 0.9), 0.8).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(_start_idle_pulse)

	# Toca som do sorriso
	AudioManager.play_sfx("Sorriso")

func _start_idle_pulse() -> void:
	if not _visible_sorriso:
		return
	if _pulse_tween:
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	var base_a: float = _sprite.modulate.a
	_pulse_tween.tween_property(_sprite, "modulate:a", base_a * 0.55, randf_range(1.2, 2.5)).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_sprite, "modulate:a", base_a, randf_range(1.2, 2.5)).set_trans(Tween.TRANS_SINE)

func _vanish_with_sanity() -> void:
	_visible_sorriso = false

	if _tween:
		_tween.kill()
	if _pulse_tween:
		_pulse_tween.kill()

	_tween = create_tween()
	_tween.tween_property(_sprite, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_EXPO)

	if is_instance_valid(_hud) and _hud.has_method("trigger_sanity_event"):
		_hud.trigger_sanity_event()

	# Quanto menor a sanidade E maior a dificuldade, mais rápido reaparece
	var sanity_val: float  = _hud.sanity if is_instance_valid(_hud) else 100.0
	var sanity_factor: float = sanity_val / 100.0
	var diff: int          = GameManager.difficulty
	var base_min: float    = DIFF_REAPPEAR_MIN[diff]
	var base_max: float    = DIFF_REAPPEAR_MAX[diff]
	var min_time: float    = lerp(base_min * 0.15, base_min, sanity_factor)
	var max_time: float    = lerp(base_max * 0.2,  base_max, sanity_factor)
	_reappear_timer = randf_range(min_time, max_time)
