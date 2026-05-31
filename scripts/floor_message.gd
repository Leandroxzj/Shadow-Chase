extends Area2D

# Mensagem no chão — aparece quando o player se aproxima

@export var message: String = ""
@export var message_index: int = 0  # escolhe da lista se message estiver vazio

const MESSAGES: Array[String] = [
	"Ele está sempre te observando...",
	"Não olhe para trás.",
	"Eu tentei fugir. Não consegui.",
	"As chaves são uma armadilha.",
	"Corra. Não pare. Nunca pare.",
	"Ele aprende com seus erros.",
	"Você não está sozinho aqui.",
	"A saída não existe.",
	"Eu ouvi passos. Eram os meus.",
	"Apague a lanterna. Ele vê a luz.",
	"Já fui como você. Cheio de esperança.",
	"Não confie nas chaves vermelhas.",
	"Ele fica mais rápido quando você corre.",
	"Fique quieto. Respire devagar.",
	"Eu contei 3 sombras. Você?",
	"A saída muda de lugar às vezes...",
	"Ele não dorme. Nunca.",
	"Ouvi um grito. Fui eu mesmo.",
	"Quanto tempo você acha que tem?",
	"Bem-vindo ao labirinto. Boa sorte.",
]

const READ_RADIUS: float  = 80.0
const FADE_RADIUS: float  = 140.0

var _label: Label         = null
var _player_ref: Node     = null
var _is_visible: bool     = false
var _tween: Tween         = null

func _ready() -> void:
	_build_visual()
	await get_tree().process_frame
	_player_ref = get_tree().get_first_node_in_group("player")

func _build_visual() -> void:
	# Texto no chão
	_label = Label.new()
	var msg := message if message != "" else MESSAGES[message_index % MESSAGES.size()]
	_label.text = msg
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.7, 0.55, 0.55, 0.0))
	_label.position = Vector2(-120, -10)
	_label.size = Vector2(240, 20)
	add_child(_label)

	# Linha decorativa embaixo do texto
	var line := ColorRect.new()
	line.size = Vector2(200, 1)
	line.position = Vector2(-100, 8)
	line.color = Color(0.5, 0.2, 0.2, 0.0)
	line.name = "Line"
	add_child(line)

	# Collision para detecção de proximidade
	var shape := CircleShape2D.new()
	shape.radius = FADE_RADIUS
	var col := CollisionShape2D.new()
	col.shape = shape
	col.name = "Col"
	add_child(col)

func _process(_delta: float) -> void:
	if not is_instance_valid(_player_ref):
		return

	var dist := global_position.distance_to(_player_ref.global_position)

	if dist < READ_RADIUS and not _is_visible:
		_show()
	elif dist > FADE_RADIUS and _is_visible:
		_hide()

func _show() -> void:
	_is_visible = true
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_label, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	var line := get_node_or_null("Line")
	if line:
		_tween.tween_property(line, "color:a", 0.5, 0.6)

func _hide() -> void:
	_is_visible = false
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_label, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE)
	var line := get_node_or_null("Line")
	if line:
		_tween.tween_property(line, "color:a", 0.0, 1.0)
