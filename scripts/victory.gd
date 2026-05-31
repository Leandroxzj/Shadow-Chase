extends Control

@onready var bg: ColorRect              = $Background
@onready var glow: ColorRect            = $GlowOverlay
@onready var title_label: Label         = $TitleContainer/TitleLabel
@onready var play_again_button: Button  = $VBox/PlayAgainButton
@onready var menu_button: Button        = $VBox/MenuButton
@onready var time_label: Label          = $StatsContainer/TimeLabel
@onready var deaths_label: Label        = $StatsContainer/DeathsLabel
@onready var record_label: Label        = $StatsContainer/RecordLabel
@onready var new_record_label: Label    = $StatsContainer/NewRecordLabel
@onready var vbox: VBoxContainer        = $VBox
@onready var stats_container: VBoxContainer = $StatsContainer

func _ready() -> void:
	play_again_button.pressed.connect(_on_play_again_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

	_style_button(play_again_button, Color(0.04, 0.28, 0.08, 0.9), Color(0.08, 0.48, 0.14, 1.0))
	_style_button(menu_button,       Color(0.02, 0.16, 0.04, 0.9), Color(0.05, 0.32, 0.08, 1.0))

	# Stats
	var total: float  = GameManager.total_time
	var minutes: int  = int(total) / 60
	var seconds: float = fmod(total, 60.0)
	time_label.text   = "⏱ Tempo: %02d:%04.1f" % [minutes, seconds]
	deaths_label.text = "💀 Mortes: %d" % GameManager.player_deaths

	# Recorde e conquistas
	var is_record := GameManager.try_save_record(total, GameManager.player_deaths)
	GameManager.check_achievements(true, total, GameManager.player_deaths)

	# Desbloqueia cor da dificuldade completada
	var diff_names: Array = ["easy", "normal", "hard", "shadow"]
	var diff_idx: int = clamp(GameManager.difficulty, 0, diff_names.size() - 1)
	var diff_name: String = diff_names[diff_idx]
	GameManager.unlock_color(diff_name)
	if is_record:
		new_record_label.text = "🏆 NOVO RECORDE!"
		record_label.text     = ""
	elif GameManager.best_time > 0.0:
		var bm := int(GameManager.best_time) / 60
		var bs := fmod(GameManager.best_time, 60.0)
		record_label.text     = "🏆 Melhor tempo: %02d:%04.1f" % [bm, bs]
		new_record_label.text = ""

	# Começa invisível
	bg.modulate.a             = 0.0
	glow.color.a              = 0.0
	title_label.scale         = Vector2(0.6, 0.6)
	title_label.modulate.a    = 0.0
	stats_container.modulate.a = 0.0
	vbox.modulate.a           = 0.0

	_animate_entrance()

func _animate_entrance() -> void:
	var tween := create_tween().set_parallel(false)

	# Fundo verde aparece
	tween.tween_property(bg, "modulate:a", 1.0, 0.4)
	tween.tween_property(glow, "color:a", 0.3, 0.3)
	tween.tween_property(glow, "color:a", 0.0, 0.8)

	# Título cresce
	tween.tween_property(title_label, "scale", Vector2(1.1, 1.1), 0.5).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(title_label, "modulate:a", 1.0, 0.5)
	tween.tween_property(title_label, "scale", Vector2.ONE, 0.15)

	# Stats e botões
	tween.tween_property(stats_container, "modulate:a", 1.0, 0.4)
	tween.tween_property(vbox, "modulate:a", 1.0, 0.4)

	tween.tween_callback(_start_title_pulse)

func _start_title_pulse() -> void:
	var pulse := create_tween().set_loops()
	pulse.tween_property(title_label, "modulate", Color(0.5, 1.0, 0.6, 1.0), 2.0).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(title_label, "modulate", Color(0.15, 0.8, 0.3, 1.0), 2.0).set_trans(Tween.TRANS_SINE)

func _style_button(btn: Button, normal: Color, hover: Color) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = normal
	n.border_color = Color(0.1, 0.6, 0.2, 0.8)
	n.set_border_width_all(2)
	n.set_corner_radius_all(6)
	n.content_margin_left = 16
	n.content_margin_right = 16
	var h := StyleBoxFlat.new()
	h.bg_color = hover
	h.border_color = Color(0.2, 1.0, 0.4, 1.0)
	h.set_border_width_all(2)
	h.set_corner_radius_all(6)
	h.content_margin_left = 16
	h.content_margin_right = 16
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover",  h)
	btn.add_theme_stylebox_override("focus",  h)

func _on_play_again_pressed() -> void:
	GameManager.player_deaths = 0
	GameManager.current_level = 1
	GameManager.total_time    = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/game.tscn"))

func _on_menu_pressed() -> void:
	GameManager.player_deaths = 0
	GameManager.current_level = 1
	GameManager.total_time    = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
