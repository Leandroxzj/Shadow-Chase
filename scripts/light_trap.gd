extends Area2D

# Armadilha de luz — paralisa criaturas que passam perto por 3s
# Colocada no mapa pelo maze_level, ativada quando criatura entra no raio

const STUN_DURATION: float  = 3.0
const TRAP_RADIUS: float    = 80.0
const TRAP_COUNT: int       = 4   # quantas por mapa

var _triggered: bool = false
var _light: PointLight2D = null

func _ready() -> void:
	add_to_group("light_trap")
	body_entered.connect(_on_body_entered)
	_build_visual()

func _build_visual() -> void:
	# Círculo de luz no chão
	var vis := ColorRect.new()
	vis.size = Vector2(24, 24)
	vis.position = Vector2(-12, -12)
	vis.color = Color(1.0, 0.9, 0.3, 0.7)
	add_child(vis)

	var lbl := Label.new()
	lbl.text = "✦"
	lbl.position = Vector2(-8, -12)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4, 1.0))
	add_child(lbl)

	# Pulso suave
	var pulse := create_tween().set_loops()
	pulse.tween_property(vis, "modulate:a", 0.3, 0.8).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(vis, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)

	var shape := CircleShape2D.new()
	shape.radius = TRAP_RADIUS
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

func _on_body_entered(body: Node) -> void:
	if _triggered:
		return
	if not body.is_in_group("creature"):
		return
	_triggered = true
	_activate(body)

func _activate(creature: Node) -> void:
	# Stun na criatura
	if creature.has_method("stun"):
		creature.stun(STUN_DURATION)

	# Flash de luz ao ativar
	var tween := create_tween()
	tween.tween_property(get_child(0), "color", Color(1.0, 1.0, 1.0, 1.0), 0.05)
	tween.tween_property(get_child(0), "color", Color(1.0, 0.9, 0.3, 0.0), 0.4)
	tween.tween_callback(queue_free)
