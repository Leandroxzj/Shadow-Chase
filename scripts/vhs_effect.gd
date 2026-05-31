extends CanvasLayer

# Efeito VHS — aparece ao iniciar o jogo e some depois de alguns segundos

const DURATION: float     = 3.5   # duração total do efeito
const SCANLINE_COUNT: int = 12    # linhas de scan visíveis

var _time: float          = 0.0
var _active: bool         = true
var _scanlines: Array     = []
var _noise_rects: Array   = []
var _glitch_timer: float  = 0.0
var _overlay: ColorRect   = null
var _chroma_r: ColorRect  = null
var _chroma_b: ColorRect  = null
var _static_label: Label  = null

func _ready() -> void:
	layer = 20  # acima de tudo
	_build_effect()
	_start_intro()

func _build_effect() -> void:
	var vp := get_viewport().get_visible_rect().size

	# Overlay geral escuro que vai clareando
	_overlay = ColorRect.new()
	_overlay.size = vp
	_overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	# Aberração cromática — camada vermelha
	_chroma_r = ColorRect.new()
	_chroma_r.size = vp
	_chroma_r.color = Color(1.0, 0.0, 0.0, 0.06)
	_chroma_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chroma_r.position.x = 3.0
	add_child(_chroma_r)

	# Aberração cromática — camada azul
	_chroma_b = ColorRect.new()
	_chroma_b.size = vp
	_chroma_b.color = Color(0.0, 0.0, 1.0, 0.06)
	_chroma_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chroma_b.position.x = -3.0
	add_child(_chroma_b)

	# Linhas de scanline
	var step := vp.y / SCANLINE_COUNT
	for i in SCANLINE_COUNT:
		var line := ColorRect.new()
		line.size = Vector2(vp.x, 2)
		line.position = Vector2(0, i * step)
		line.color = Color(0.0, 0.0, 0.0, 0.25)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(line)
		_scanlines.append(line)

	# Ruído estático
	for i in 30:
		var r := ColorRect.new()
		r.size = Vector2(randf_range(2, 80), randf_range(1, 4))
		r.color = Color(1.0, 1.0, 1.0, randf_range(0.3, 0.8))
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
		_noise_rects.append(r)

	# Label "REC" piscando — canto superior direito
	_static_label = Label.new()
	_static_label.text = "● REC"
	_static_label.position = Vector2(vp.x - 100.0, 20)
	_static_label.add_theme_font_size_override("font_size", 16)
	_static_label.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1, 1.0))
	add_child(_static_label)

func _start_intro() -> void:
	# Começa com tela preta e vai revelando
	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE)

	# REC pisca
	var rec_tween := create_tween().set_loops(5)
	rec_tween.tween_property(_static_label, "modulate:a", 0.0, 0.3)
	rec_tween.tween_property(_static_label, "modulate:a", 1.0, 0.3)

func _process(delta: float) -> void:
	if not _active:
		return

	_time += delta
	_glitch_timer -= delta

	# Anima ruído estático
	for r in _noise_rects:
		var vp := get_viewport().get_visible_rect().size
		if randf() < 0.3:
			r.position = Vector2(
				randf_range(0, vp.x),
				randf_range(0, vp.y)
			)
			r.color.a = randf_range(0.1, 0.6)
		else:
			r.color.a = 0.0

	# Glitch ocasional — desloca as camadas de cor
	if _glitch_timer <= 0.0:
		_glitch_timer = randf_range(0.1, 0.5)
		var offset := randf_range(-6.0, 6.0)
		_chroma_r.position.x = offset + 3.0
		_chroma_b.position.x = -offset - 3.0
		# Glitch nas scanlines
		if randf() < 0.4:
			for line in _scanlines:
				line.position.y += randf_range(-2.0, 2.0)

	# Fade out no final
	if _time > DURATION - 0.8:
		var alpha: float = 1.0 - clamp((_time - (DURATION - 0.8)) / 0.8, 0.0, 1.0)
		_overlay.color.a = alpha * 0.0  # overlay já foi para 0, usa chroma
		_chroma_r.color.a = 0.06 * alpha
		_chroma_b.color.a = 0.06 * alpha
		for line in _scanlines:
			line.color.a = 0.25 * alpha
		for r in _noise_rects:
			r.color.a = r.color.a * alpha
		_static_label.modulate.a = alpha

	# Remove ao terminar
	if _time >= DURATION:
		_active = false
		queue_free()
