extends Node

const API_URL: String = "http://localhost:8000/chat"
const CHAT_COOLDOWN: float = 8.0  # segundos entre mensagens

var http_request: HTTPRequest
var last_message_time: float = 0.0
var is_requesting: bool = false

signal message_received(text: String)
signal whisper_received(text: String)

func _ready() -> void:
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

func can_send_message() -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	return not is_requesting and (now - last_message_time) >= CHAT_COOLDOWN

func send_game_event(event_type: String = "") -> void:
	if not can_send_message():
		return
	var data: Dictionary = GameManager.get_game_data()
	if event_type != "":
		data["event"] = event_type
	var json_body: String = JSON.stringify(data)
	var headers: PackedStringArray = ["Content-Type: application/json"]
	var error: int = http_request.request(
		API_URL,
		headers,
		HTTPClient.METHOD_POST,
		json_body
	)
	if error == OK:
		is_requesting = true
		last_message_time = Time.get_ticks_msec() / 1000.0
	else:
		push_warning("ChatManager: Falha ao enviar requisição")

func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	is_requesting = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("ChatManager: Resposta inválida do servidor")
		return
	var json: JSON = JSON.new()
	var parse_result: int = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		push_warning("ChatManager: Erro ao parsear JSON")
		return
	var response: Dictionary = json.get_data()
	var message: String = response.get("message", "")
	var msg_type: String = response.get("type", "normal")
	if message != "":
		if msg_type == "whisper":
			whisper_received.emit(message)
		else:
			message_received.emit(message)
