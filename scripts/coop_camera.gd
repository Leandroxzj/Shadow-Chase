extends Camera2D

# Câmera cooperativa — segue o centro entre P1 e P2
# Se um morrer, segue só o que está vivo

var _p2: Node2D = null

func _ready() -> void:
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if p != get_parent() and p.get("player_id") == 2:
			_p2 = p
			break

func _process(_delta: float) -> void:
	var p1 := get_parent() as Node2D
	var p1_alive: bool = p1.get("is_alive") if p1.get("is_alive") != null else true
	var p2_alive: bool = is_instance_valid(_p2) and (_p2.get("is_alive") if _p2.get("is_alive") != null else true)

	if p1_alive and p2_alive:
		# Ambos vivos — segue o centro
		var p1_pos: Vector2 = p1.global_position
		var p2_pos: Vector2 = _p2.global_position
		global_position = (p1_pos + p2_pos) * 0.5
		var dist: float = p1_pos.distance_to(p2_pos)
		var target_zoom: float = clamp(1.5 - (dist / 1200.0), 0.7, 1.5)
		zoom = zoom.lerp(Vector2(target_zoom, target_zoom), 0.05)
	elif p2_alive and is_instance_valid(_p2):
		# Só P2 vivo — segue o P2
		global_position = _p2.global_position
		zoom = zoom.lerp(Vector2(1.5, 1.5), 0.05)
	else:
		# Só P1 vivo ou ambos mortos — segue o P1 normalmente
		zoom = zoom.lerp(Vector2(1.5, 1.5), 0.05)
