extends Control

@onready var easy_btn:    Button = $VBox/EasyButton
@onready var normal_btn:  Button = $VBox/NormalButton
@onready var hard_btn:    Button = $VBox/HardButton
@onready var shadow_btn:  Button = $VBox/ShadowButton
@onready var endless_btn: Button = $VBox/EndlessButton
@onready var back_btn:    Button = $VBox/BackButton
@onready var vbox:        VBoxContainer = $VBox

func _ready() -> void:
	easy_btn.pressed.connect(func(): _select(GameManager.Difficulty.EASY))
	normal_btn.pressed.connect(func(): _select(GameManager.Difficulty.NORMAL))
	hard_btn.pressed.connect(func(): _select(GameManager.Difficulty.HARD))
	shadow_btn.pressed.connect(func(): _select(GameManager.Difficulty.SHADOW))
	endless_btn.pressed.connect(_on_endless_pressed)
	back_btn.pressed.connect(_on_back)

	for btn in [easy_btn, normal_btn, hard_btn, shadow_btn, endless_btn, back_btn]:
		btn.pressed.connect(AudioManager.play_ui_click)
		btn.mouse_entered.connect(AudioManager.play_ui_hover)

	_style_button(easy_btn,    Color(0.04, 0.22, 0.06, 0.9), Color(0.06, 0.40, 0.10, 1.0), Color(0.1, 0.8, 0.2, 0.7))
	_style_button(normal_btn,  Color(0.22, 0.18, 0.02, 0.9), Color(0.40, 0.32, 0.04, 1.0), Color(0.9, 0.7, 0.1, 0.7))
	_style_button(hard_btn,    Color(0.28, 0.04, 0.02, 0.9), Color(0.50, 0.08, 0.04, 1.0), Color(0.9, 0.2, 0.1, 0.7))
	_style_button(shadow_btn,  Color(0.18, 0.02, 0.28, 0.9), Color(0.32, 0.04, 0.50, 1.0), Color(0.6, 0.1, 0.9, 0.7))
	_style_button(endless_btn, Color(0.28, 0.12, 0.02, 0.9), Color(0.50, 0.22, 0.04, 1.0), Color(1.0, 0.5, 0.1, 0.7))
	_style_button(back_btn,    Color(0.12, 0.02, 0.02, 0.9), Color(0.24, 0.04, 0.04, 1.0), Color(0.5, 0.1, 0.1, 0.5))

	# Endless só disponível se zerou todos os modos
	var all_cleared := GameManager.unlocked_colors.has("easy") and \
					   GameManager.unlocked_colors.has("normal") and \
					   GameManager.unlocked_colors.has("hard") and \
					   GameManager.unlocked_colors.has("shadow")
	if not all_cleared:
		endless_btn.disabled   = true
		endless_btn.text       = "♾  ENDLESS  —  Zere todos os modos"
		endless_btn.modulate.a = 0.45

	_update_button_texts()

	vbox.modulate.a  = 0.0
	vbox.position.y += 30.0
	var tween := create_tween()
	tween.tween_property(vbox, "modulate:a", 1.0, 0.4)
	tween.parallel().tween_property(vbox, "position:y", vbox.position.y - 30.0, 0.4).set_trans(Tween.TRANS_BACK)
	easy_btn.grab_focus()

func _update_button_texts() -> void:
	var coop: bool = GameManager.coop_mode
	var bonus: int = 2 if coop else 0
	var suffix: String = " (COOP)" if coop else ""

	easy_btn.text   = "🟢  FÁCIL%s  —  %d criaturas  |  %d chaves"   % [suffix, GameManager.DIFF_CREATURE_COUNT[0] + bonus, GameManager.DIFF_KEY_COUNT[0] + bonus]
	normal_btn.text = "🟡  MÉDIO%s  —  %d criaturas  |  %d chaves"   % [suffix, GameManager.DIFF_CREATURE_COUNT[1] + bonus, GameManager.DIFF_KEY_COUNT[1] + bonus]
	hard_btn.text   = "🔴  DIFÍCIL%s  —  %d criaturas  |  %d chaves" % [suffix, GameManager.DIFF_CREATURE_COUNT[2] + bonus, GameManager.DIFF_KEY_COUNT[2] + bonus]
	shadow_btn.text = "💀  SOMBRA%s  —  %d criaturas  |  %d chaves"  % [suffix, GameManager.DIFF_CREATURE_COUNT[3] + bonus, GameManager.DIFF_KEY_COUNT[3] + bonus]

func _select(diff: GameManager.Difficulty) -> void:
	GameManager.set_difficulty(diff)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/game.tscn"))

func _on_endless_pressed() -> void:
	GameManager.set_difficulty(GameManager.Difficulty.NORMAL)
	GameManager.endless_mode = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/game.tscn"))

func _on_back() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))

func _style_button(btn: Button, normal: Color, hover: Color, border: Color) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = normal
	n.border_color = border
	n.set_border_width_all(2)
	n.set_corner_radius_all(6)
	n.content_margin_left  = 16
	n.content_margin_right = 16
	var h := StyleBoxFlat.new()
	h.bg_color = hover
	h.border_color = border.lightened(0.3)
	h.set_border_width_all(2)
	h.set_corner_radius_all(6)
	h.content_margin_left  = 16
	h.content_margin_right = 16
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover",  h)
	btn.add_theme_stylebox_override("focus",  h)
