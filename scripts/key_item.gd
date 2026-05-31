extends Area2D

signal key_collected(index: int)
signal fake_key_triggered   # sinal para o maze_level spawnar criatura extra

@export var key_index: int  = 0
@export var is_fake: bool   = false  # se true, spawna criatura ao coletar

var collected: bool    = false
var _teleport_timer: Timer
var _is_blinking: bool = false

const TELEPORT_POSITIONS: Array[Vector2] = [
	Vector2(700,  450),   Vector2(1344, 1344), Vector2(2100, 1980),
	Vector2(400,  1800),  Vector2(2200, 400),  Vector2(1800, 800),
	Vector2(500,  900),   Vector2(1600, 1600), Vector2(900,  2100),
	Vector2(2100, 1100),  Vector2(1100, 600),  Vector2(600,  1500),
	Vector2(1900, 2200),  Vector2(800,  400),  Vector2(1400, 800),
	Vector2(400,  600),   Vector2(1800, 1200), Vector2(600,  2000),
	Vector2(1200, 500),   Vector2(2000, 1600), Vector2(1600, 400),
	Vector2(400,  1400),  Vector2(1000, 1800), Vector2(1800, 2100),
]

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_visual()
	_start_float()
	_setup_teleport_timer()

func _apply_visual() -> void:
	if is_fake:
		# Chave falsa tem tom avermelhado sutil — difícil de notar
		modulate = Color(1.1, 0.75, 0.75, 1.0)

func _start_float() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(self, "global_position:y", global_position.y - 8.0, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "global_position:y", global_position.y, 0.8).set_trans(Tween.TRANS_SINE)

func _setup_teleport_timer() -> void:
	_teleport_timer = Timer.new()
	_teleport_timer.wait_time = GameManager.get_key_teleport_time()
	_teleport_timer.autostart = true
	_teleport_timer.one_shot  = false
	_teleport_timer.timeout.connect(_on_teleport_timeout)
	add_child(_teleport_timer)

func _on_teleport_timeout() -> void:
	if collected or _is_blinking:
		return
	_blink_and_teleport()

func _blink_and_teleport() -> void:
	_is_blinking = true
	var blink := create_tween()
	for _i in 4:
		blink.tween_property(self, "modulate:a", 0.05, 0.15)
		blink.tween_property(self, "modulate:a", 1.0,  0.15)
	blink.tween_property(self, "modulate:a", 0.0, 0.2)
	blink.tween_callback(_do_teleport)

func _do_teleport() -> void:
	if collected:
		return
	var current := global_position
	var candidates: Array[Vector2] = []
	for p in TELEPORT_POSITIONS:
		if current.distance_to(p) > 300.0:
			candidates.append(p)
	if candidates.is_empty():
		candidates = TELEPORT_POSITIONS

	var new_pos: Vector2 = candidates[randi() % candidates.size()]
	global_position = new_pos
	modulate.a = 1.0
	scale = Vector2.ZERO
	_is_blinking = false

	var appear := create_tween()
	appear.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)
	appear.tween_callback(_start_float)

func _on_body_entered(body: Node2D) -> void:
	if collected or not body.is_in_group("player"):
		return
	collected = true
	_teleport_timer.stop()

	if is_fake:
		_trigger_fake()
	else:
		key_collected.emit(key_index)
		AudioManager.play_sfx("jump")
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_BACK)
		tween.tween_callback(queue_free)

func _trigger_fake() -> void:
	# Flash vermelho + tremida para indicar que foi armadilha
	var flash := create_tween()
	flash.tween_property(self, "modulate", Color(1.0, 0.0, 0.0, 1.0), 0.05)
	flash.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.3)
	flash.tween_callback(queue_free)
	fake_key_triggered.emit()
