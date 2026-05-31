extends CanvasLayer

@onready var message_label: Label = $Panel/MessageLabel
@onready var panel: Panel = $Panel
@onready var whisper_label: Label = $WhisperLabel

const DISPLAY_DURATION: float = 5.0
const WHISPER_DURATION: float = 3.5

func _ready() -> void:
	panel.modulate.a = 0.0
	whisper_label.modulate.a = 0.0
	ChatManager.message_received.connect(_on_message_received)
	ChatManager.whisper_received.connect(_on_whisper_received)

func _on_message_received(text: String) -> void:
	message_label.text = text
	AudioManager.play_sfx("whisper")
	var tween: Tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.4)
	tween.tween_interval(DISPLAY_DURATION)
	tween.tween_property(panel, "modulate:a", 0.0, 0.8)

func _on_whisper_received(text: String) -> void:
	whisper_label.text = text
	var tween: Tween = create_tween()
	tween.tween_property(whisper_label, "modulate:a", 1.0, 0.2)
	tween.tween_interval(WHISPER_DURATION)
	tween.tween_property(whisper_label, "modulate:a", 0.0, 1.0)
