extends Node

# Modo Endless — sem saída, sobreviva o máximo possível
# Criaturas ficam mais rápidas a cada 30s, novas criaturas spawnam a cada 60s

const SPEED_INTERVAL: float  = 25.0
const SPAWN_INTERVAL: float  = 45.0
const MAX_CREATURES: int     = 20

var _speed_timer: float  = SPEED_INTERVAL
var _spawn_timer: float  = SPAWN_INTERVAL
var _wave: int           = 0
var _creatures: Array    = []
var _player_ref: Node2D  = null

const SPAWN_POSITIONS: Array[Vector2] = [
	Vector2(2048, 2361), Vector2(256, 2400),  Vector2(2400, 256),
	Vector2(2400, 2400), Vector2(256, 256),   Vector2(1280, 2400),
	Vector2(2400, 1280), Vector2(1280, 256),  Vector2(256, 1280),
	Vector2(1800, 1800),
]

func _ready() -> void:
	await get_tree().process_frame
	_player_ref = get_tree().get_first_node_in_group("player")
	# Registra criaturas existentes
	for c in get_tree().get_nodes_in_group("creature"):
		_creatures.append(c)

func _process(delta: float) -> void:
	_speed_timer -= delta
	_spawn_timer  -= delta

	if _speed_timer <= 0.0:
		_speed_timer = SPEED_INTERVAL
		_increase_speed()

	if _spawn_timer <= 0.0:
		_spawn_timer = SPAWN_INTERVAL
		_spawn_wave()

func _increase_speed() -> void:
	_wave += 1
	for c in _creatures:
		if is_instance_valid(c) and c.has_method("increase_aggression"):
			c.increase_aggression(0.15)

	# Avisa o HUD
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("_show_warning"):
		hud._show_warning("⚠ Elas estão ficando mais rápidas!")

func _spawn_wave() -> void:
	if _creatures.size() >= MAX_CREATURES:
		return

	var creature_scene := load("res://scenes/creature.tscn") as PackedScene
	if not creature_scene:
		return

	# Spawna 1-2 criaturas por wave
	var count := 1 if _wave < 3 else 2
	for i in count:
		if _creatures.size() >= MAX_CREATURES:
			break
		var c := creature_scene.instantiate()
		c.ghost_mode = true
		c.modulate.a = 0.0
		var idx := randi() % SPAWN_POSITIONS.size()
		c.global_position = SPAWN_POSITIONS[idx]
		get_tree().current_scene.add_child(c)
		_creatures.append(c)

		var tween := c.create_tween()
		tween.tween_property(c, "modulate:a", 0.85, 1.5)

	# Avisa
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("_show_warning"):
		hud._show_warning("💀 Mais sombras chegaram!")
