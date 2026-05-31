extends Control

@onready var music_menu_slider: HSlider = $ScrollContainer/VBox/MusicMenuRow/MusicMenuSlider
@onready var music_menu_value: Label    = $ScrollContainer/VBox/MusicMenuRow/MusicMenuValue
@onready var music_game_slider: HSlider = $ScrollContainer/VBox/MusicGameRow/MusicGameSlider
@onready var music_game_value: Label    = $ScrollContainer/VBox/MusicGameRow/MusicGameValue
@onready var sfx_slider: HSlider        = $ScrollContainer/VBox/SFXRow/SFXSlider
@onready var sfx_value: Label           = $ScrollContainer/VBox/SFXRow/SFXValue
@onready var master_slider: HSlider     = $ScrollContainer/VBox/MasterRow/MasterSlider
@onready var master_value: Label        = $ScrollContainer/VBox/MasterRow/MasterValue
@onready var brightness_slider: HSlider = $ScrollContainer/VBox/BrightnessRow/BrightnessSlider
@onready var brightness_value: Label    = $ScrollContainer/VBox/BrightnessRow/BrightnessValue
@onready var brightness_preview: ColorRect = $ScrollContainer/VBox/BrightnessPreview/PreviewContent/PreviewRect
@onready var back_btn: Button           = $ScrollContainer/VBox/BackButton

const SAVE_PATH_RECORDS  := "user://records.cfg"
const SAVE_PATH_TUTORIAL := "user://tutorial_done.cfg"
const SAVE_PATH_OPTIONS  := "user://options.cfg"
const SECRET_CODE: String = "SOMBRA2024"
const RESET_CODE: String  = "RESETAR2024"

func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	back_btn.pressed.connect(AudioManager.play_ui_click)
	back_btn.mouse_entered.connect(AudioManager.play_ui_hover)

	_style_button(back_btn)
	_style_sliders()
	_load_options()

	music_menu_slider.value_changed.connect(_on_music_menu_changed)
	music_game_slider.value_changed.connect(_on_music_game_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	master_slider.value_changed.connect(_on_master_changed)
	brightness_slider.value_changed.connect(_on_brightness_changed)

	# Código
	var code_input  := $ScrollContainer/VBox/CodeRow/CodeInput as LineEdit
	var code_button := $ScrollContainer/VBox/CodeRow/CodeButton as Button
	code_button.pressed.connect(func(): _on_code_submitted(code_input))
	code_input.text_submitted.connect(func(_t): _on_code_submitted(code_input))

	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func _setup_color_buttons() -> void:
	var color_map := {"default": "ColorDefault", "easy": "ColorEasy",
					  "normal": "ColorNormal",   "hard": "ColorHard", "shadow": "ColorShadow"}
	for key in color_map:
		var btn := get_node_or_null("VBox/ColorRow/" + color_map[key]) as Button
		if not btn:
			continue
		var unlocked: bool = GameManager.unlocked_colors.has(key)
		btn.disabled = not unlocked
		btn.modulate.a = 1.0 if unlocked else 0.4
		if unlocked:
			btn.pressed.connect(func(): _select_color(key))
			btn.pressed.connect(AudioManager.play_ui_click)

func _select_color(key: String) -> void:
	GameManager.selected_color = key
	GameManager._save_records()

# ── Callbacks dos sliders ─────────────────────────────────────
func _on_music_menu_changed(val: float) -> void:
	music_menu_value.text = "%d%%" % int(val * 100)
	AudioManager.set_menu_music_volume(val)
	_save_options()

func _on_music_game_changed(val: float) -> void:
	music_game_value.text = "%d%%" % int(val * 100)
	AudioManager.set_game_music_volume(val)
	_save_options()

func _on_sfx_changed(val: float) -> void:
	sfx_value.text = "%d%%" % int(val * 100)
	AudioManager.set_sfx_volume(val)
	_save_options()

func _on_master_changed(val: float) -> void:
	master_value.text = "%d%%" % int(val * 100)
	AudioManager.set_master_volume(val)
	_save_options()

func _on_brightness_changed(val: float) -> void:
	brightness_value.text = "%d%%" % int(val * 100)
	GameManager.brightness = val

	# Atualiza a prévia
	var base := Color(0.14, 0.11, 0.18, 1.0)
	if val < 1.0:
		brightness_preview.color = base.darkened(1.0 - val)
	else:
		brightness_preview.color = base.lightened((val - 1.0) * 0.5)

	# Aplica no CanvasModulate em tempo real se estiver no jogo
	var canvas := get_tree().current_scene.get_node_or_null("CanvasModulate") as CanvasModulate
	if canvas:
		var adjusted := base
		if val < 1.0:
			adjusted = base.darkened((1.0 - val) * 0.8)
		else:
			adjusted = base.lightened((val - 1.0) * 0.5)
		canvas.color = adjusted

	_save_options()

# ── Salvar / Carregar ─────────────────────────────────────────
func _save_options() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_menu", music_menu_slider.value)
	cfg.set_value("audio", "music_game", music_game_slider.value)
	cfg.set_value("audio", "sfx",        sfx_slider.value)
	cfg.set_value("audio", "master",     master_slider.value)
	cfg.set_value("video", "brightness", brightness_slider.value)
	cfg.save(SAVE_PATH_OPTIONS)

func _load_options() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH_OPTIONS) != OK:
		return
	var mm: float = cfg.get_value("audio", "music_menu", 1.0)
	var mg: float = cfg.get_value("audio", "music_game", 1.0)
	var sf: float = cfg.get_value("audio", "sfx",        1.0)
	var ms: float = cfg.get_value("audio", "master",     1.0)
	var br: float = cfg.get_value("video", "brightness", 1.0)

	music_menu_slider.value = mm
	music_game_slider.value = mg
	sfx_slider.value        = sf
	master_slider.value     = ms
	brightness_slider.value = br

	music_menu_value.text = "%d%%" % int(mm * 100)
	music_game_value.text = "%d%%" % int(mg * 100)
	sfx_value.text        = "%d%%" % int(sf * 100)
	master_value.text     = "%d%%" % int(ms * 100)
	brightness_value.text = "%d%%" % int(br * 100)

	AudioManager.set_menu_music_volume(mm)
	AudioManager.set_game_music_volume(mg)
	AudioManager.set_sfx_volume(sf)
	AudioManager.set_master_volume(ms)
	GameManager.brightness = br
	# Atualiza a prévia ao carregar
	var base := Color(0.14, 0.11, 0.18, 1.0)
	if br < 1.0:
		brightness_preview.color = base.darkened(1.0 - br)
	else:
		brightness_preview.color = base.lightened((br - 1.0) * 0.5)

# ── Estilo ────────────────────────────────────────────────────
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

func _style_sliders() -> void:
	for slider in [music_menu_slider, music_game_slider, sfx_slider, master_slider]:
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.7, 0.1, 0.1, 1.0)
		fill.set_corner_radius_all(4)
		slider.add_theme_stylebox_override("grabber_area", fill)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.2, 0.05, 0.05, 0.8)
		bg.set_corner_radius_all(4)
		slider.add_theme_stylebox_override("slider", bg)

func _on_back() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		# Se foi aberto como overlay (pai é CanvasLayer), remove o pai
		if get_parent() is CanvasLayer and get_parent().get_parent() != get_tree().root:
			get_parent().queue_free()
		else:
			get_tree().change_scene_to_file(GameManager.options_return_scene)
	)

func _on_code_submitted(code_input: LineEdit) -> void:
	var feedback := $ScrollContainer/VBox/CodeFeedback as Label
	var entered  := code_input.text.strip_edges().to_upper()

	if entered == SECRET_CODE:
		for key in ["default", "easy", "normal", "hard", "shadow"]:
			GameManager.unlock_color(key)
		GameManager._save_records()
		feedback.text = "✓ Tudo desbloqueado!"
		feedback.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4, 1.0))
		code_input.text = ""

	elif entered == RESET_CODE:
		GameManager.best_time         = 0.0
		GameManager.best_deaths       = 999
		GameManager.total_runs        = 0
		GameManager.total_escapes     = 0
		GameManager.total_deaths_ever = 0
		GameManager.total_time_played = 0.0
		GameManager.shadow_completed  = false
		GameManager.selected_color    = "default"
		GameManager.unlocked_colors   = ["default"]
		GameManager.endless_mode      = false
		for id in GameManager.achievements:
			GameManager.achievements[id]["unlocked"] = false
		for path in [GameManager.SAVE_PATH, "user://tutorial_done.cfg", SAVE_PATH_OPTIONS]:
			if FileAccess.file_exists(path):
				OS.move_to_trash(ProjectSettings.globalize_path(path))
		feedback.text = "✓ Jogo resetado!"
		feedback.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2, 1.0))
		await get_tree().create_timer(1.5).timeout
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

	else:
		feedback.text = "✗ Código inválido."
		feedback.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))
		code_input.text = ""
		await get_tree().create_timer(2.0).timeout
		feedback.text = ""
