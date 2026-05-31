extends Control

@onready var skins_container: HBoxContainer = $SkinsContainer
@onready var back_btn: Button               = $BackButton
@onready var selected_label: Label          = $SelectedLabel
@onready var code_input: LineEdit           = $CodeContainer/CodeInput
@onready var code_button: Button            = $CodeContainer/CodeButton
@onready var code_feedback: Label           = $CodeFeedback

# Código secreto — mude para o que quiser
const SECRET_CODE: String  = "SOMBRA2024"
const RESET_CODE: String   = "RESETAR2024"

const SKINS: Array = [
	{"key": "default", "label": "PADRÃO",  "req": "",        "color": Color(1.0, 1.0, 1.0, 1.0)},
	{"key": "easy",    "label": "FÁCIL",   "req": "Fácil",   "color": Color(0.3, 1.0, 0.4, 1.0)},
	{"key": "normal",  "label": "MÉDIO",   "req": "Médio",   "color": Color(0.4, 0.6, 1.0, 1.0)},
	{"key": "hard",    "label": "DIFÍCIL", "req": "Difícil", "color": Color(1.0, 0.3, 0.3, 1.0)},
	{"key": "shadow",  "label": "SOMBRA",  "req": "Sombra",  "color": Color(0.1, 0.1, 0.1, 1.0)},
]

var _sprite_tex: Texture2D = null

func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	back_btn.pressed.connect(AudioManager.play_ui_click)
	back_btn.mouse_entered.connect(AudioManager.play_ui_hover)
	_style_back_button()

	code_button.pressed.connect(_on_code_submitted)
	code_input.text_submitted.connect(func(_t): _on_code_submitted())
	code_feedback.text = ""

	# Carrega o sprite do personagem
	_sprite_tex = load("res://sprites/idle_down.png") as Texture2D

	_build_skins()
	_update_selected_label()

	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.35)

func _on_code_submitted() -> void:
	var entered := code_input.text.strip_edges().to_upper()
	if entered == SECRET_CODE:
		# Desbloqueia tudo
		for s in SKINS:
			GameManager.unlock_color(s["key"])
		if not GameManager.unlocked_colors.has("easy"):
			GameManager.unlock_color("easy")
		GameManager._save_records()
		code_feedback.text = "✓ Tudo desbloqueado!"
		code_feedback.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4, 1.0))
		await get_tree().create_timer(1.0).timeout
		get_tree().reload_current_scene()
	elif entered == RESET_CODE:
		# Reseta tudo — como se fosse a primeira vez
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

		# Apaga os arquivos de save
		var save_path    := GameManager.SAVE_PATH
		var tutorial_path := "user://tutorial_done.cfg"
		var options_path  := "user://options.cfg"
		if FileAccess.file_exists(save_path):
			OS.move_to_trash(ProjectSettings.globalize_path(save_path))
		if FileAccess.file_exists(tutorial_path):
			OS.move_to_trash(ProjectSettings.globalize_path(tutorial_path))
		if FileAccess.file_exists(options_path):
			OS.move_to_trash(ProjectSettings.globalize_path(options_path))

		code_feedback.text = "✓ Jogo resetado com sucesso!"
		code_feedback.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2, 1.0))
		await get_tree().create_timer(1.5).timeout
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	else:
		code_feedback.text = "✗ Código inválido."
		code_feedback.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))
		var tween := create_tween()
		tween.tween_interval(2.0)
		tween.tween_callback(func(): code_feedback.text = "")

func _update_selected_label() -> void:
	var current := GameManager.selected_color
	for s in SKINS:
		if s["key"] == current:
			selected_label.text = "Equipado: %s" % s["label"]
			selected_label.add_theme_color_override("font_color", s["color"])
			break

func _build_skins() -> void:
	for skin in SKINS:
		var key: String    = skin["key"]
		var label: String  = skin["label"]
		var req: String    = skin["req"]
		var color: Color   = skin["color"]
		var unlocked: bool = GameManager.unlocked_colors.has(key)
		var selected: bool = GameManager.selected_color == key

		var card := _make_card(key, label, req, color, unlocked, selected)
		skins_container.add_child(card)

func _make_card(key: String, label: String, req: String,
				color: Color, unlocked: bool, selected: bool) -> PanelContainer:

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(130, 200)

	# Estilo do card
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.07, 0.04, 0.04, 0.92) if unlocked else Color(0.04, 0.03, 0.03, 0.85)
	card_style.border_color = color if selected else (Color(color.r, color.g, color.b, 0.4) if unlocked else Color(0.25, 0.2, 0.2, 0.5))
	card_style.set_border_width_all(3 if selected else 1)
	card_style.set_corner_radius_all(10)
	card_style.content_margin_left   = 10
	card_style.content_margin_right  = 10
	card_style.content_margin_top    = 12
	card_style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	# Preview do personagem com a cor da skin
	var preview_container := Control.new()
	preview_container.custom_minimum_size = Vector2(110, 100)
	vbox.add_child(preview_container)

	if _sprite_tex and unlocked:
		# Usa o primeiro frame do idle_down (96x80 px)
		var atlas := AtlasTexture.new()
		atlas.atlas  = _sprite_tex
		atlas.region = Rect2(0, 0, 96, 80)

		var sprite := TextureRect.new()
		sprite.texture        = atlas
		sprite.expand_mode    = 1
		sprite.stretch_mode   = 5
		sprite.custom_minimum_size = Vector2(96, 80)
		sprite.position       = Vector2(7, 10)
		sprite.modulate       = color
		preview_container.add_child(sprite)

		# Brilho ao redor se selecionado
		if selected:
			var glow := ColorRect.new()
			glow.size     = Vector2(110, 100)
			glow.color    = Color(color.r, color.g, color.b, 0.12)
			glow.position = Vector2(0, 0)
			preview_container.add_child(glow)
			preview_container.move_child(glow, 0)
	else:
		# Bloqueado — mostra cadeado
		var lock_bg := ColorRect.new()
		lock_bg.size     = Vector2(110, 100)
		lock_bg.color    = Color(0.08, 0.06, 0.06, 1.0)
		preview_container.add_child(lock_bg)

		var lock_lbl := Label.new()
		lock_lbl.text = "🔒"
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lock_lbl.add_theme_font_size_override("font_size", 32)
		lock_lbl.set_anchor(SIDE_RIGHT, 1.0)
		lock_lbl.set_anchor(SIDE_BOTTOM, 1.0)
		preview_container.add_child(lock_lbl)

	# Nome da skin
	var name_lbl := Label.new()
	name_lbl.text = label
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color",
		color if unlocked else Color(0.35, 0.3, 0.3, 1.0))
	vbox.add_child(name_lbl)

	# Requisito ou status
	var sub_lbl := Label.new()
	if selected:
		sub_lbl.text = "✓ Equipado"
		sub_lbl.add_theme_color_override("font_color", color)
	elif not unlocked:
		sub_lbl.text = "Zere: %s" % req
		sub_lbl.add_theme_color_override("font_color", Color(0.5, 0.4, 0.4, 0.8))
	else:
		sub_lbl.text = "Disponível"
		sub_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.8))
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(sub_lbl)

	# Botão equipar
	if unlocked and not selected:
		var btn := Button.new()
		btn.text = "EQUIPAR"
		btn.add_theme_font_size_override("font_size", 13)
		var n := StyleBoxFlat.new()
		n.bg_color = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.9)
		n.border_color = color
		n.set_border_width_all(1)
		n.set_corner_radius_all(5)
		var h := n.duplicate() as StyleBoxFlat
		h.bg_color = Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 1.0)
		btn.add_theme_stylebox_override("normal", n)
		btn.add_theme_stylebox_override("hover",  h)
		btn.add_theme_color_override("font_color", color)
		vbox.add_child(btn)
		btn.pressed.connect(func(): _select_skin(key))
		btn.pressed.connect(AudioManager.play_ui_click)

	return card

func _select_skin(key: String) -> void:
	GameManager.selected_color = key
	GameManager._save_records()
	get_tree().reload_current_scene()

func _style_back_button() -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.2, 0.04, 0.04, 0.9)
	n.border_color = Color(0.6, 0.1, 0.1, 0.8)
	n.set_border_width_all(2)
	n.set_corner_radius_all(6)
	n.content_margin_left = 16
	n.content_margin_right = 16
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.38, 0.06, 0.06, 1.0)
	back_btn.add_theme_stylebox_override("normal", n)
	back_btn.add_theme_stylebox_override("hover",  h)
	back_btn.add_theme_stylebox_override("focus",  h)

func _on_back() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
