extends Control

@onready var start_button:   Button      = $VBox/StartButton
@onready var coop_button:    Button      = $VBox/CoopButton
@onready var stats_button:   Button      = $VBox/StatsButton
@onready var options_button: Button      = $VBox/OptionsButton
@onready var extras_button:  Button      = $VBox/ExtrasButton
@onready var quit_button:    Button      = $VBox/QuitButton
@onready var vbox:           VBoxContainer = $VBox
@onready var particles_node: Node2D      = $Particles

const SCREEN_W: float     = 1280.0
const SCREEN_H: float     = 720.0
const PARTICLE_COUNT: int = 18

const COLOR_NORMAL:  Color = Color(0.55, 0.52, 0.50, 1.0)
const COLOR_FOCUSED: Color = Color(1.00, 0.97, 0.95, 1.0)
const COLOR_FIRST:   Color = Color(0.85, 0.82, 0.80, 1.0)

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	coop_button.pressed.connect(_on_coop_pressed)
	stats_button.pressed.connect(_on_stats_pressed)
	options_button.pressed.connect(_on_options_pressed)
	extras_button.pressed.connect(_on_extras_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	var all_btns := [start_button, coop_button, stats_button, options_button, extras_button, quit_button]

	for btn in all_btns:
		btn.pressed.connect(AudioManager.play_ui_click)
		btn.mouse_entered.connect(AudioManager.play_ui_hover)
		_style_text_button(btn)

	# Hover
	start_button.mouse_entered.connect(func(): _on_hover(start_button))
	start_button.mouse_exited.connect(func():  _on_unhover(start_button, COLOR_FIRST))
	coop_button.mouse_entered.connect(func(): _on_hover(coop_button))
	coop_button.mouse_exited.connect(func():  _on_unhover(coop_button, COLOR_NORMAL))
	stats_button.mouse_entered.connect(func(): _on_hover(stats_button))
	stats_button.mouse_exited.connect(func():  _on_unhover(stats_button, COLOR_NORMAL))
	options_button.mouse_entered.connect(func(): _on_hover(options_button))
	options_button.mouse_exited.connect(func():  _on_unhover(options_button, COLOR_NORMAL))
	extras_button.mouse_entered.connect(func(): _on_hover(extras_button))
	extras_button.mouse_exited.connect(func():  _on_unhover(extras_button, Color(0.85, 0.75, 0.3, 1.0)))
	quit_button.mouse_entered.connect(func(): _on_hover(quit_button))
	quit_button.mouse_exited.connect(func():  _on_unhover(quit_button, COLOR_NORMAL))

	# Mostra EXTRAS se desbloqueado (zerou pelo menos o Fácil)
	if GameManager.unlocked_colors.size() > 1:
		extras_button.visible = true

	_spawn_particles()
	_animate_entrance()
	AudioManager.play_menu_music()
	# Foco inicial para navegação por controle
	start_button.grab_focus()

func _style_text_button(btn: Button) -> void:
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal",   empty)
	btn.add_theme_stylebox_override("hover",    empty)
	btn.add_theme_stylebox_override("pressed",  empty)
	btn.add_theme_stylebox_override("focus",    empty)
	btn.add_theme_stylebox_override("disabled", empty)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

func _on_hover(btn: Button) -> void:
	btn.add_theme_color_override("font_color", COLOR_FOCUSED)
	btn.add_theme_font_size_override("font_size", 40)

func _on_unhover(btn: Button, base_color: Color) -> void:
	btn.add_theme_color_override("font_color", base_color)
	btn.add_theme_font_size_override("font_size", 36)

# ── Partículas ────────────────────────────────────────────────
func _spawn_particles() -> void:
	for i in PARTICLE_COUNT:
		var p := ColorRect.new()
		var sz := randf_range(1.5, 4.0)
		p.size = Vector2(sz, sz)
		p.color = Color(1.0, 0.9, 0.8, randf_range(0.05, 0.2))
		p.position = Vector2(randf_range(0, SCREEN_W), randf_range(0, SCREEN_H))
		particles_node.add_child(p)
		_animate_particle(p)

func _animate_particle(p: ColorRect) -> void:
	var duration := randf_range(6.0, 14.0)
	var target_y := p.position.y - randf_range(60.0, 180.0)
	var target_x := p.position.x + randf_range(-40.0, 40.0)
	var tween := create_tween().set_loops()
	tween.tween_property(p, "position", Vector2(target_x, target_y), duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(p, "modulate:a", 0.0, duration * 0.3)
	tween.tween_callback(func():
		p.position = Vector2(randf_range(0, SCREEN_W), SCREEN_H + 10.0)
		p.modulate.a = randf_range(0.05, 0.2)
	)
	tween.tween_property(p, "modulate:a", randf_range(0.05, 0.2), 0.5)

# ── Animação de entrada ───────────────────────────────────────
func _animate_entrance() -> void:
	vbox.modulate.a  = 0.0
	vbox.position.x -= 30.0
	var tween := create_tween()
	tween.tween_property(vbox, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(vbox, "position:x", vbox.position.x + 30.0, 0.7).set_trans(Tween.TRANS_SINE)

# ── Ações ─────────────────────────────────────────────────────
func _on_start_pressed() -> void:
	GameManager.coop_mode = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/difficulty_select.tscn"))

func _on_coop_pressed() -> void:
	GameManager.coop_mode = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/difficulty_select.tscn"))

func _on_stats_pressed() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/stats_screen.tscn"))

func _on_options_pressed() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func():
		GameManager.options_return_scene = "res://scenes/main_menu.tscn"
		get_tree().change_scene_to_file("res://scenes/options_screen.tscn")
	)

func _on_extras_pressed() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/extras_screen.tscn"))

func _on_quit_pressed() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): get_tree().quit())
