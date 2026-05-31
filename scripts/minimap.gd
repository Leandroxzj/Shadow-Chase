extends CanvasLayer

# Minimapa — mostra posição do player e chaves no canto superior direito
# NÃO mostra as criaturas

const MAP_SIZE: float    = 2560.0   # tamanho real do mapa
const MINI_SIZE: float   = 140.0    # tamanho do minimapa em pixels
const SCALE: float       = MINI_SIZE / MAP_SIZE

var _bg: ColorRect          = null
var _border: ColorRect      = null
var _player_dot: ColorRect  = null
var _key_dots: Array        = []
var _player_ref: Node2D     = null
var _container: Control     = null

func _ready() -> void:
	layer = 12  # acima do HUD normal
	_build_minimap()
	await get_tree().process_frame
	_player_ref = get_tree().get_first_node_in_group("player")
	_build_key_dots()

func _build_minimap() -> void:
	_container = Control.new()
	_container.position = Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width", 1024) - MINI_SIZE - 12,
		12
	)
	_container.size = Vector2(MINI_SIZE, MINI_SIZE)
	add_child(_container)

	# Fundo escuro semitransparente
	_bg = ColorRect.new()
	_bg.size  = Vector2(MINI_SIZE, MINI_SIZE)
	_bg.color = Color(0.05, 0.03, 0.03, 0.75)
	_container.add_child(_bg)

	# Borda vermelha
	for i in 4:
		var line := ColorRect.new()
		match i:
			0: line.size = Vector2(MINI_SIZE, 2); line.position = Vector2(0, 0)
			1: line.size = Vector2(MINI_SIZE, 2); line.position = Vector2(0, MINI_SIZE - 2)
			2: line.size = Vector2(2, MINI_SIZE); line.position = Vector2(0, 0)
			3: line.size = Vector2(2, MINI_SIZE); line.position = Vector2(MINI_SIZE - 2, 0)
		line.color = Color(0.6, 0.1, 0.1, 0.9)
		_container.add_child(line)

	# Label "MAPA"
	var lbl := Label.new()
	lbl.text = "MAPA"
	lbl.position = Vector2(4, 2)
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4, 0.8))
	_container.add_child(lbl)

	# Ponto do player — branco
	_player_dot = ColorRect.new()
	_player_dot.size     = Vector2(6, 6)
	_player_dot.color    = Color(1.0, 1.0, 1.0, 1.0)
	_player_dot.z_index  = 10
	_container.add_child(_player_dot)

func _build_key_dots() -> void:
	for key in get_tree().get_nodes_in_group("key"):
		var dot := ColorRect.new()
		dot.size  = Vector2(5, 5)
		dot.color = Color(1.0, 0.85, 0.1, 0.9)
		dot.set_meta("key_ref", key)
		_container.add_child(dot)
		_key_dots.append(dot)

func _process(_delta: float) -> void:
	if not is_instance_valid(_player_ref):
		return

	# Atualiza posição do player
	var px: float = _player_ref.global_position.x * SCALE - 3.0
	var py: float = _player_ref.global_position.y * SCALE - 3.0
	_player_dot.position = Vector2(clamp(px, 2, MINI_SIZE - 8), clamp(py, 2, MINI_SIZE - 8))

	# Pulso no ponto do player
	var t: float = fmod(Time.get_ticks_msec() / 400.0, TAU)
	_player_dot.color.a = 0.7 + sin(t) * 0.3

	# Atualiza chaves
	for dot in _key_dots:
		if not is_instance_valid(dot):
			continue
		var key_ref = dot.get_meta("key_ref") if dot.has_meta("key_ref") else null
		if not is_instance_valid(key_ref):
			dot.visible = false
			continue
		var kx: float = key_ref.global_position.x * SCALE - 2.5
		var ky: float = key_ref.global_position.y * SCALE - 2.5
		dot.position = Vector2(clamp(kx, 2, MINI_SIZE - 7), clamp(ky, 2, MINI_SIZE - 7))
