extends Control

@onready var retry_button: Button   = $VBox/RetryButton
@onready var menu_button: Button    = $VBox/MenuButton
@onready var bg: ColorRect          = $Background
@onready var blood: ColorRect       = $BloodOverlay
@onready var title_label: Label     = $TitleContainer/GameOverLabel
@onready var time_label: Label      = $StatsContainer/TimeLabel
@onready var keys_label: Label      = $StatsContainer/KeysLabel
@onready var deaths_label: Label    = $StatsContainer/DeathsLabel
@onready var record_label: Label    = $StatsContainer/RecordLabel
@onready var vbox: VBoxContainer    = $VBox

func _ready() -> void:
	retry_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

	_style_button(retry_button, Color(0.28, 0.04, 0.04, 0.9), Color(0.5, 0.08, 0.08, 1.0))
	_style_button(menu_button,  Color(0.16, 0.02, 0.02, 0.9), Color(0.36, 0.05, 0.05, 1.0))

	# Stats
	var t := GameManager.game_time
	var m := int(t) / 60
	var s := fmod(t, 60.0)
	time_label.text   = "⏱ Tempo sobrevivido: %02d:%04.1f" % [m, s]
	keys_label.text   = "🗝 Chaves coletadas: %d / 3" % GameManager.keys_collected_total
	deaths_label.text = "💀 Total de mortes: %d" % GameManager.player_deaths

	# Recorde
	if GameManager.best_time > 0.0:
		var bm := int(GameManager.best_time) / 60
		var bs := fmod(GameManager.best_time, 60.0)
		record_label.text = "🏆 Melhor tempo: %02d:%04.1f" % [bm, bs]

	# Registra partida nas estatísticas (não escapou)
	GameManager.check_achievements(false, GameManager.game_time, GameManager.player_deaths)

	# Esconde tudo e anima entrada
	bg.modulate.a      = 0.0
	blood.color.a      = 0.0
	title_label.scale  = Vector2(0.5, 0.5)
	title_label.modulate.a = 0.0
	vbox.modulate.a    = 0.0
	$StatsContainer.modulate.a = 0.0

	_animate_entrance()

func _animate_entrance() -> void:
	# Fundo aparece com flash de sangue
	var tween := create_tween().set_parallel(false)
	tween.tween_property(bg, "modulate:a", 1.0, 0.3)
	tween.tween_property(blood, "color:a", 0.45, 0.2)
	tween.tween_property(blood, "color:a", 0.0, 0.6)

	# Título cai com impacto
	tween.tween_property(title_label, "scale", Vector2(1.15, 1.15), 0.4).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(title_label, "modulate:a", 1.0, 0.4)
	tween.tween_property(title_label, "scale", Vector2.ONE, 0.15)

	# Stats aparecem
	tween.tween_property($StatsContainer, "modulate:a", 1.0, 0.5)

	# Botões sobem
	tween.tween_property(vbox, "modulate:a", 1.0, 0.4)

	# Pulso no título
	tween.tween_callback(_start_pulse)

func _start_pulse() -> void:
	var pulse := create_tween().set_loops()
	pulse.tween_property(title_label, "modulate", Color(1.0, 0.3, 0.3, 1.0), 1.5).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(title_label, "modulate", Color(0.7, 0.05, 0.05, 1.0), 1.5).set_trans(Tween.TRANS_SINE)

func _style_button(btn: Button, normal: Color, hover: Color) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = normal
	n.border_color = Color(0.6, 0.1, 0.1, 0.8)
	n.set_border_width_all(2)
	n.set_corner_radius_all(6)
	n.content_margin_left = 16
	n.content_margin_right = 16
	var h := StyleBoxFlat.new()
	h.bg_color = hover
	h.border_color = Color(1.0, 0.3, 0.3, 1.0)
	h.set_border_width_all(2)
	h.set_corner_radius_all(6)
	h.content_margin_left = 16
	h.content_margin_right = 16
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover",  h)
	btn.add_theme_stylebox_override("focus",  h)

func _on_retry_pressed() -> void:
	GameManager.total_time = 0.0
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
