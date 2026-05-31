extends Area2D

# Isca — faz barulho e atrai criaturas por alguns segundos

const ATTRACT_RADIUS: float = 400.0
const DURATION: float       = 6.0

var _timer: float = DURATION
var _vis: ColorRect = null

func _ready() -> void:
	add_to_group("bait")
	_build_visual()
	_make_noise()

	var shape := CircleShape2D.new()
	shape.radius = ATTRACT_RADIUS
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

func _build_visual() -> void:
	_vis = ColorRect.new()
	_vis.size = Vector2(14, 14)
	_vis.position = Vector2(-7, -7)
	_vis.color = Color(0.9, 0.7, 0.1, 0.9)
	add_child(_vis)

	var lbl := Label.new()
	lbl.text = "●"
	lbl.position = Vector2(-6, -10)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	add_child(lbl)

	# Pulso
	var pulse := create_tween().set_loops()
	pulse.tween_property(_vis, "modulate:a", 0.3, 0.3)
	pulse.tween_property(_vis, "modulate:a", 1.0, 0.3)

func _make_noise() -> void:
	# Toca som de passos na posição da isca para atrair criaturas
	var sfx := AudioStreamPlayer2D.new()
	sfx.position = global_position
	sfx.max_distance = ATTRACT_RADIUS
	sfx.attenuation = 0.5
	get_tree().current_scene.add_child(sfx)
	for ext in ["mp3", "ogg", "wav"]:
		var path := "res://assets/audio/sfx/footstep.%s" % ext
		if ResourceLoader.exists(path):
			sfx.stream = load(path)
			sfx.play()
			break
	# Repete o som algumas vezes
	var t := create_tween()
	for i in 5:
		t.tween_interval(1.0)
		t.tween_callback(func():
			if is_instance_valid(sfx):
				sfx.play()
		)
	t.tween_callback(sfx.queue_free)

func _process(delta: float) -> void:
	_timer -= delta

	# Força criaturas a irem até a isca
	for c in get_tree().get_nodes_in_group("creature"):
		if is_instance_valid(c) and c.is_physics_processing():
			var dist: float = global_position.distance_to(c.global_position)
			if dist < ATTRACT_RADIUS:
				# Força estado de alerta na posição da isca
				if c.has_method("attract_to"):
					c.attract_to(global_position)

	if _timer <= 0.0:
		var tween := create_tween()
		tween.tween_property(_vis, "modulate:a", 0.0, 0.3)
		tween.tween_callback(queue_free)
