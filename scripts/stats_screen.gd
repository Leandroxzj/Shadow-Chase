extends Control

@onready var stats_text: Label       = $HSplit/StatsPanel/StatsText
@onready var achiev_list: VBoxContainer = $HSplit/AchievPanel/AchievList
@onready var back_btn: Button        = $BackButton

func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	_style_button(back_btn)
	_load_stats()
	_load_achievements()

	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func _load_stats() -> void:
	var gm := GameManager
	var bm := int(gm.best_time) / 60
	var bs := fmod(gm.best_time, 60.0)
	var best_str := "%02d:%04.1f" % [bm, bs] if gm.best_time > 0.0 else "—"

	var th := int(gm.total_time_played) / 3600
	var tm := (int(gm.total_time_played) % 3600) / 60
	var ts := fmod(gm.total_time_played, 60.0)
	var time_str := "%dh %02dm %02.0fs" % [th, tm, ts]

	stats_text.text = (
		"Partidas jogadas:  %d\n" % gm.total_runs +
		"Fugas bem-sucedidas:  %d\n" % gm.total_escapes +
		"Total de mortes:  %d\n" % gm.total_deaths_ever +
		"Tempo total jogado:  %s\n" % time_str +
		"Melhor tempo:  %s\n" % best_str +
		"Modo Sombra completo:  %s" % ("✓ Sim" if gm.shadow_completed else "✗ Não")
	)

func _load_achievements() -> void:
	# Limpa lista anterior
	for child in achiev_list.get_children():
		child.queue_free()

	for id in GameManager.achievements:
		var data: Dictionary = GameManager.achievements[id]
		var unlocked: bool   = data["unlocked"]

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var icon_lbl := Label.new()
		icon_lbl.text = data["icon"] if unlocked else "🔒"
		icon_lbl.add_theme_font_size_override("font_size", 20)
		row.add_child(icon_lbl)

		var info := VBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.text = data["name"]
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color",
			Color(1.0, 0.85, 0.2, 1.0) if unlocked else Color(0.5, 0.4, 0.4, 1.0))
		info.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = data["desc"]
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color",
			Color(0.8, 0.75, 0.6, 1.0) if unlocked else Color(0.4, 0.35, 0.35, 1.0))
		info.add_child(desc_lbl)

		row.add_child(info)
		achiev_list.add_child(row)

func _style_button(btn: Button) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.2, 0.04, 0.04, 0.9)
	n.border_color = Color(0.6, 0.1, 0.1, 0.8)
	n.set_border_width_all(2)
	n.set_corner_radius_all(6)
	n.content_margin_left = 16
	n.content_margin_right = 16
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.38, 0.06, 0.06, 1.0)
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover",  h)
	btn.add_theme_stylebox_override("focus",  h)

func _on_back() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
