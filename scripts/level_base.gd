extends Node2D

@export var level_number: int = 1
@export var spawn_position: Vector2 = Vector2(100, 400)
@export var finish_position: Vector2 = Vector2(3000, 400)

var player_ref: CharacterBody2D
var creature_ref: CharacterBody2D
var chat_timer: Timer

func _ready() -> void:
	GameManager.reset()
	GameManager.current_level = level_number
	GameManager.is_maze_level = false
	_setup_player()
	_setup_creature()
	_setup_chat_timer()
	_setup_camera()
	AudioManager.play_ambient()
	await get_tree().process_frame
	ChatManager.send_game_event("level_start")

func _setup_player() -> void:
	player_ref = $Player
	player_ref.global_position = spawn_position
	player_ref.player_died_signal.connect(_on_player_died)

func _setup_creature() -> void:
	creature_ref = $Creature
	creature_ref.global_position = spawn_position + Vector2(-400, 0)

func _setup_chat_timer() -> void:
	chat_timer = Timer.new()
	add_child(chat_timer)
	chat_timer.wait_time = 12.0
	chat_timer.autostart = true
	chat_timer.timeout.connect(_on_chat_timer_timeout)

func _setup_camera() -> void:
	var cam: Camera2D = $Camera2D
	if cam:
		cam.position_smoothing_enabled = true
		cam.position_smoothing_speed = 5.0

func _on_chat_timer_timeout() -> void:
	ChatManager.send_game_event("periodic_check")
	if is_instance_valid(creature_ref):
		creature_ref.increase_aggression(0.05)

func _on_player_died() -> void:
	chat_timer.stop()
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/game_over.tscn")

func _on_finish_area_entered(_body: Node2D) -> void:
	ChatManager.send_game_event("level_complete")
	GameManager.level_completed.emit()
	await get_tree().create_timer(1.5).timeout
	_load_next_level()

func _load_next_level() -> void:
	var next: int = level_number + 1
	# Nível 1 vai para o labirinto (game.tscn)
	if level_number == 1:
		get_tree().change_scene_to_file("res://scenes/game.tscn")
		return
	var path: String = "res://scenes/levels/level_0%d.tscn" % next
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		get_tree().change_scene_to_file("res://scenes/victory.tscn")
