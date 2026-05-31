extends CanvasLayer

@onready var overlay: ColorRect = $Overlay
@onready var panel: PanelContainer = $Panel
@onready var resume_button: Button = $Panel/VBox/ResumeButton
@onready var options_button: Button = $Panel/VBox/OptionsButton
@onready var menu_button: Button = $Panel/VBox/MenuButton
@onready var quit_button: Button = $Panel/VBox/QuitButton

var is_paused: bool = false

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	resume_button.pressed.connect(_on_resume_pressed)
	options_button.pressed.connect(_on_options_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Sons de UI
	resume_button.pressed.connect(AudioManager.play_ui_click)
	options_button.pressed.connect(AudioManager.play_ui_click)
	menu_button.pressed.connect(AudioManager.play_ui_click)
	quit_button.pressed.connect(AudioManager.play_ui_click)
	resume_button.mouse_entered.connect(AudioManager.play_ui_hover)
	options_button.mouse_entered.connect(AudioManager.play_ui_hover)
	menu_button.mouse_entered.connect(AudioManager.play_ui_hover)
	quit_button.mouse_entered.connect(AudioManager.play_ui_hover)

	_style_panel()
	_style_button(resume_button, Color(0.3, 0.04, 0.04, 0.9), Color(0.5, 0.08, 0.08, 1.0))
	_style_button(options_button, Color(0.18, 0.04, 0.04, 0.9), Color(0.36, 0.06, 0.06, 1.0))
	_style_button(menu_button, Color(0.18, 0.02, 0.02, 0.9), Color(0.38, 0.05, 0.05, 1.0))
	_style_button(quit_button, Color(0.22, 0.02, 0.02, 0.9), Color(0.45, 0.06, 0.06, 1.0))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action("ui_cancel") and event.is_pressed() and not event.is_echo():
		if is_paused:
			_on_resume_pressed()
		else:
			_show_pause()

func _show_pause() -> void:
	is_paused = true
	get_tree().paused = true
	visible = true

	overlay.color.a = 0.0
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.85, 0.85)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(overlay, "color:a", 0.65, 0.25)
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	# Foco no primeiro botão para navegação por controle
	resume_button.grab_focus()

func _on_resume_pressed() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(overlay, "color:a", 0.0, 0.2)
	tween.tween_property(panel, "modulate:a", 0.0, 0.2)
	tween.tween_property(panel, "scale", Vector2(0.85, 0.85), 0.2)
	await tween.finished

	is_paused = false
	get_tree().paused = false
	visible = false

func _on_menu_pressed() -> void:
	get_tree().paused = false
	is_paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_options_pressed() -> void:
	# Abre opções como overlay por cima do jogo pausado
	var opts_scene := load("res://scenes/options_screen.tscn") as PackedScene
	if opts_scene:
		var opts := opts_scene.instantiate()
		opts.process_mode = Node.PROCESS_MODE_ALWAYS
		# Garante que está no topo visualmente
		var canvas := CanvasLayer.new()
		canvas.layer = 20
		canvas.process_mode = Node.PROCESS_MODE_ALWAYS
		canvas.add_child(opts)
		get_tree().current_scene.add_child(canvas)

func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()

func _style_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.01, 0.01, 0.96)
	style.border_color = Color(0.7, 0.1, 0.1, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", style)

func _style_button(btn: Button, normal_color: Color, hover_color: Color) -> void:
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = normal_color
	normal_style.border_color = Color(0.7, 0.1, 0.1, 0.7)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(6)
	normal_style.content_margin_left = 12
	normal_style.content_margin_right = 12

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = hover_color
	hover_style.border_color = Color(1.0, 0.2, 0.2, 1.0)
	hover_style.set_border_width_all(2)
	hover_style.set_corner_radius_all(6)
	hover_style.content_margin_left = 12
	hover_style.content_margin_right = 12

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.05, 0.01, 0.01, 1.0)
	pressed_style.border_color = Color(1.0, 0.4, 0.4, 1.0)
	pressed_style.set_border_width_all(2)
	pressed_style.set_corner_radius_all(6)
	pressed_style.content_margin_left = 12
	pressed_style.content_margin_right = 12

	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_stylebox_override("focus", hover_style)
