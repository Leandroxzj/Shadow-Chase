extends CanvasLayer

# Tutorial — aparece na primeira vez que o jogador abre o jogo
# Mostra dicas em sequência que somem ao pressionar qualquer tecla

const SAVE_PATH := "user://tutorial_done.cfg"

const TIPS: Array[String] = [
	"Use WASD ou as setas para se mover.",
	"Segure SHIFT para correr — mas cuidado com a stamina!",
	"Clique com o botão DIREITO para ligar/desligar a lanterna.\nAtenção: a luz atrai as criaturas!",
	"Colete as 🗝 chaves espalhadas pelo mapa\npara abrir a saída.",
	"Ao pegar a 1ª chave, a criatura acorda.\nNão deixe ela te alcançar!",
	"Pressione ESC para pausar o jogo.",
	"Boa sorte... você vai precisar. 😈",
]

var _current_tip: int    = 0
var _panel: PanelContainer = null
var _tip_label: Label    = null
var _counter_label: Label = null
var _skip_label: Label   = null
var _active: bool        = false

func _ready() -> void:
	layer = 50  # acima de tudo
	if _already_done():
		queue_free()
		return
	_build_ui()
	_show_tip()

func _already_done() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(SAVE_PATH) == OK

func _mark_done() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("tutorial", "done", true)
	cfg.save(SAVE_PATH)

func _build_ui() -> void:
	# Overlay escuro
	var overlay := ColorRect.new()
	overlay.set_anchor(SIDE_RIGHT, 1.0)
	overlay.set_anchor(SIDE_BOTTOM, 1.0)
	overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	# Painel central
	_panel = PanelContainer.new()
	_panel.set_anchor(SIDE_LEFT, 0.5)
	_panel.set_anchor(SIDE_RIGHT, 0.5)
	_panel.set_anchor(SIDE_TOP, 0.5)
	_panel.set_anchor(SIDE_BOTTOM, 0.5)
	_panel.offset_left   = -280.0
	_panel.offset_right  = 280.0
	_panel.offset_top    = -100.0
	_panel.offset_bottom = 100.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.02, 0.02, 0.96)
	style.border_color = Color(0.7, 0.1, 0.1, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left   = 24
	style.content_margin_right  = 24
	style.content_margin_top    = 20
	style.content_margin_bottom = 20
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "— TUTORIAL —"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1))
	vbox.add_child(title)

	_tip_label = Label.new()
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.add_theme_font_size_override("font_size", 18)
	_tip_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.9, 1))
	vbox.add_child(_tip_label)

	_counter_label = Label.new()
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter_label.add_theme_font_size_override("font_size", 12)
	_counter_label.add_theme_color_override("font_color", Color(0.5, 0.4, 0.4, 1))
	vbox.add_child(_counter_label)

	_skip_label = Label.new()
	_skip_label.text = "[ Pressione qualquer tecla para continuar ]"
	_skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip_label.add_theme_font_size_override("font_size", 12)
	_skip_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.5, 0.8))
	vbox.add_child(_skip_label)

	# Pulso no skip label
	var pulse := create_tween().set_loops()
	pulse.tween_property(_skip_label, "modulate:a", 0.4, 0.8)
	pulse.tween_property(_skip_label, "modulate:a", 1.0, 0.8)

func _show_tip() -> void:
	_active = true
	_tip_label.text = TIPS[_current_tip]
	_counter_label.text = "%d / %d" % [_current_tip + 1, TIPS.size()]

	_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.3)

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_pressed() and not event.is_echo():
		_next_tip()

func _next_tip() -> void:
	_current_tip += 1
	if _current_tip >= TIPS.size():
		_finish()
		return
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, 0.2)
	tween.tween_callback(_show_tip)

func _finish() -> void:
	_active = false
	_mark_done()
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)
