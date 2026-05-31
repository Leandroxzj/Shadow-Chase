extends Area2D

# Armadilha no chão — mata o player ao pisar
# Adicione este script a um Area2D com CollisionShape2D e um sprite/label visual

@export var trap_type: String = "spike"  # "spike" ou "hole"

var _triggered: bool = false

func _ready() -> void:
	add_to_group("trap")
	body_entered.connect(_on_body_entered)
	_build_visual()

func _build_visual() -> void:
	# Cria visual simples via código (sem precisar de sprite externo)
	var rect := ColorRect.new()
	rect.custom_minimum_size = Vector2(32, 32)
	rect.offset_left   = -16
	rect.offset_top    = -16
	rect.offset_right  = 16
	rect.offset_bottom = 16

	if trap_type == "spike":
		rect.color = Color(0.7, 0.1, 0.1, 0.85)
	else:
		rect.color = Color(0.05, 0.05, 0.05, 0.95)

	add_child(rect)

	# Label com ícone
	var lbl := Label.new()
	lbl.text = "✦" if trap_type == "spike" else "◉"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.offset_left   = -16
	lbl.offset_top    = -16
	lbl.offset_right  = 16
	lbl.offset_bottom = 16
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.8, 1.0))
	add_child(lbl)

	# Pulso sutil para chamar atenção
	var tween := create_tween().set_loops()
	tween.tween_property(rect, "modulate:a", 0.5, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(rect, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)

func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if body.is_in_group("player") and body.has_method("die"):
		_triggered = true
		_trigger_effect()
		body.die()

func _trigger_effect() -> void:
	# Flash vermelho rápido ao ativar
	var rect := get_child(0) as ColorRect
	if rect:
		var tween := create_tween()
		tween.tween_property(rect, "color", Color(1.0, 0.0, 0.0, 1.0), 0.05)
		tween.tween_property(rect, "modulate:a", 0.0, 0.3)
