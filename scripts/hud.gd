extends CanvasLayer

@onready var time_label: Label        = $MarginContainer/VBox/TimeLabel
@onready var distance_label: Label    = $MarginContainer/VBox/DistanceLabel
@onready var key_label: Label         = $MarginContainer/VBox/KeyLabel
@onready var stamina_bar: ProgressBar = $P1Container/StaminaContainer/StaminaBar
@onready var stamina_icon: Label      = $P1Container/StaminaContainer/StaminaIcon
@onready var warning_label: Label     = $WarningLabel
@onready var vignette: ColorRect      = $Vignette
@onready var battery_bar: ProgressBar = $P1Container/BatteryContainer/BatteryBar
@onready var battery_label: Label     = $P1Container/BatteryContainer/BatteryLabel
@onready var battery_icon: Label      = $P1Container/BatteryContainer/BatteryIcon
@onready var heart_label: Label       = $HeartLabel
@onready var achievement_popup: PanelContainer = $AchievementPopup
@onready var achievement_name: Label  = $AchievementPopup/HBox/VBox/NameLabel
@onready var achievement_icon: Label  = $AchievementPopup/HBox/IconLabel
@onready var sanity_bar: ProgressBar  = $P1Container/SanityContainer/SanityBar
@onready var sanity_label: Label      = $P1Container/SanityContainer/SanityLabel
@onready var sanity_icon: Label       = $P1Container/SanityContainer/SanityIcon
@onready var p1_label: Label          = $P1Container/P1Label
@onready var p2_container: VBoxContainer = $P2Container
@onready var p2_battery_bar: ProgressBar = $P2Container/P2BatteryRow/P2BatteryBar
@onready var p2_battery_label: Label     = $P2Container/P2BatteryRow/P2BatteryLabel
@onready var p2_stamina_bar: ProgressBar = $P2Container/P2StaminaRow/P2StaminaBar
@onready var p2_sanity_bar: ProgressBar  = $P2Container/P2SanityRow/P2SanityBar

var _vignette_tween: Tween  = null
var _warning_tween: Tween   = null
var _heart_tween: Tween     = null
var _heart_active: bool     = false
var _last_heart_dist: float = 9999.0

# ── Sanidade ──────────────────────────────────────────────────
var sanity: float           = 100.0   # 0 = insano, 100 = normal
var _sanity_active: bool    = false
var _sanity_tween: Tween    = null
var _vhs_overlay: ColorRect = null
var _red_overlay: ColorRect = null
var _sanity_heart_tween: Tween = null
var _distortion_overlay: ColorRect = null
var _distortion_timer: float = 0.0

func _ready() -> void:
	add_to_group("hud")
	warning_label.modulate.a = 0.0
	key_label.visible = false
	vignette.color = Color(0.6, 0.0, 0.0, 0.0)
	heart_label.modulate.a = 0.0

	# No modo Sombra começa com sanidade 50
	if GameManager.difficulty == GameManager.Difficulty.SHADOW:
		sanity = 50.0

	# Estiliza barra de stamina
	_style_bar(stamina_bar, Color(0.1, 0.5, 0.9, 1.0))
	# Estiliza barra de sanidade
	_style_bar(sanity_bar, Color(0.4, 0.8, 0.4, 1.0))

	# Estiliza popup de conquista
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = Color(0.08, 0.06, 0.02, 0.92)
	popup_style.border_color = Color(1.0, 0.8, 0.1, 0.9)
	popup_style.set_border_width_all(2)
	popup_style.set_corner_radius_all(8)
	popup_style.content_margin_left   = 12
	popup_style.content_margin_right  = 12
	popup_style.content_margin_top    = 8
	popup_style.content_margin_bottom = 8
	achievement_popup.add_theme_stylebox_override("panel", popup_style)

	# Conecta sinal de conquista
	GameManager.achievement_unlocked.connect(_on_achievement_unlocked)

	# Cria overlays de sanidade
	_build_sanity_overlays()
	_build_distortion_overlay()

	await get_tree().process_frame
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if player.has_signal("battery_changed"):
			player.battery_changed.connect(_on_battery_changed)
		if player.has_signal("stamina_changed"):
			player.stamina_changed.connect(_on_stamina_changed)

	# Coop — mostra HUD do P2
	if GameManager.coop_mode:
		p1_label.visible = true
		p2_container.visible = true
		_style_bar(p2_battery_bar, Color(0.2, 0.8, 0.2, 1.0))
		_style_bar(p2_stamina_bar, Color(0.1, 0.5, 0.9, 1.0))
		_style_bar(p2_sanity_bar,  Color(0.4, 0.8, 0.4, 1.0))
		# Conecta sinais do P2
		await get_tree().process_frame
		for p in get_tree().get_nodes_in_group("player"):
			if p.get("player_id") == 2:
				if p.has_signal("battery_changed"):
					p.battery_changed.connect(_on_p2_battery_changed)
				if p.has_signal("stamina_changed"):
					p.stamina_changed.connect(_on_p2_stamina_changed)
				break

func _process(delta: float) -> void:
	var data: Dictionary = GameManager.get_game_data()
	time_label.text = "Tempo: %.1fs" % data.game_time

	# Calcula distância real da criatura mais próxima diretamente
	var dist: float = _get_nearest_creature_dist()

	var danger: float = 1.0 - clamp((dist - 50.0) / 350.0, 0.0, 1.0)

	_update_vignette(dist)
	_update_heartbeat(dist)
	_update_distortion(delta, dist)
	_update_hallucinations(delta)

	if dist < 150.0:
		_show_warning("CORRE!")
	elif dist < 300.0:
		_show_warning("Ele está se aproximando...")
	else:
		_hide_warning()

func _get_nearest_creature_dist() -> float:
	var player := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return 9999.0
	var nearest := 9999.0
	for c in get_tree().get_nodes_in_group("creature"):
		if is_instance_valid(c):
			var d: float = player.global_position.distance_to(c.global_position)
			if d < nearest:
				nearest = d
	return nearest

# ── Vinheta ───────────────────────────────────────────────────
func _update_vignette(dist: float) -> void:
	var intensity: float = 0.0
	if dist < 300.0:
		intensity = 1.0 - clamp((dist - 50.0) / 250.0, 0.0, 1.0)

	var target_alpha := intensity * 0.55

	if _vignette_tween:
		_vignette_tween.kill()
	_vignette_tween = create_tween()

	if dist < 150.0:
		_vignette_tween.tween_property(vignette, "color:a", target_alpha, 0.15)
		_vignette_tween.tween_property(vignette, "color:a", target_alpha * 0.4, 0.15)
		_vignette_tween.set_loops(0)
	else:
		_vignette_tween.tween_property(vignette, "color:a", target_alpha, 0.4)

# ── Coração pulsando ──────────────────────────────────────────
func _update_heartbeat(dist: float) -> void:
	var should_beat := dist < 300.0

	if should_beat and not _heart_active:
		_heart_active = true
		_last_heart_dist = dist
		_start_heartbeat(dist)
	elif not should_beat and _heart_active:
		_heart_active = false
		_last_heart_dist = 9999.0
		if _heart_tween:
			_heart_tween.kill()
			_heart_tween = null
		var fade := create_tween()
		fade.tween_property(heart_label, "modulate:a", 0.0, 0.5)
	elif should_beat and _heart_active:
		# Só reinicia o tween se a distância mudou significativamente (>30px)
		if abs(dist - _last_heart_dist) > 30.0:
			_last_heart_dist = dist
			_start_heartbeat(dist)

func _start_heartbeat(dist: float) -> void:
	if _heart_tween:
		_heart_tween.kill()

	# Quanto mais perto, mais rápido e mais intenso
	var intensity: float = 1.0 - clamp((dist - 50.0) / 250.0, 0.0, 1.0)
	var beat_speed: float = lerp(0.55, 0.18, intensity)  # 0.55s longe → 0.18s perto
	var max_scale: float  = lerp(1.2, 1.8, intensity)
	var alpha: float      = lerp(0.5, 1.0, intensity)

	# Cor fica mais vermelha/intensa quanto mais perto
	var heart_color := Color(lerp(0.6, 1.0, intensity), 0.05, 0.05, alpha)
	heart_label.add_theme_color_override("font_color", heart_color)

	# Dois batimentos rápidos (lub-dub) depois pausa — ritmo cardíaco real
	_heart_tween = create_tween().set_loops()
	# Lub
	_heart_tween.tween_property(heart_label, "scale", Vector2(max_scale, max_scale), beat_speed * 0.25).set_trans(Tween.TRANS_SINE)
	_heart_tween.tween_property(heart_label, "scale", Vector2.ONE, beat_speed * 0.2).set_trans(Tween.TRANS_SINE)
	# Dub
	_heart_tween.tween_property(heart_label, "scale", Vector2(max_scale * 0.85, max_scale * 0.85), beat_speed * 0.2).set_trans(Tween.TRANS_SINE)
	_heart_tween.tween_property(heart_label, "scale", Vector2.ONE, beat_speed * 0.2).set_trans(Tween.TRANS_SINE)
	# Pausa entre batimentos
	_heart_tween.tween_property(heart_label, "modulate:a", alpha, 0.05)
	_heart_tween.tween_interval(beat_speed * 0.6)

	# Fade in do coração se ainda não estava visível
	if heart_label.modulate.a < 0.3:
		var fade := create_tween()
		fade.tween_property(heart_label, "modulate:a", alpha, 0.4)

# ── Stamina ───────────────────────────────────────────────────
func _on_stamina_changed(value: float, max_value: float) -> void:
	var pct := (value / max_value) * 100.0
	stamina_bar.value = pct

	var bar_style := stamina_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if bar_style == null:
		bar_style = StyleBoxFlat.new()
		stamina_bar.add_theme_stylebox_override("fill", bar_style)

	if pct > 50.0:
		bar_style.bg_color = Color(0.1, 0.5, 0.9, 1.0)
	elif pct > 20.0:
		bar_style.bg_color = Color(0.2, 0.7, 0.4, 1.0)
	else:
		bar_style.bg_color = Color(0.8, 0.3, 0.1, 1.0)

	# Ícone pisca quando stamina esgotada
	stamina_icon.modulate = Color(1.0, 0.3, 0.1, 1.0) if pct <= 15.0 else Color(1.0, 1.0, 1.0, 1.0)

# ── Bateria ───────────────────────────────────────────────────
func _on_battery_changed(value: float, max_value: float) -> void:
	var pct := (value / max_value) * 100.0
	battery_bar.value = pct

	var bar_style := battery_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if bar_style == null:
		bar_style = StyleBoxFlat.new()
		battery_bar.add_theme_stylebox_override("fill", bar_style)

	if pct > 50.0:
		bar_style.bg_color = Color(0.2, 0.8, 0.2, 1.0)
	elif pct > 25.0:
		bar_style.bg_color = Color(0.9, 0.7, 0.1, 1.0)
	else:
		bar_style.bg_color = Color(0.9, 0.1, 0.1, 1.0)

	battery_label.text = "%d%%" % int(pct)
	battery_icon.modulate = Color(1.0, 0.3, 0.3, 1.0) if pct <= 20.0 else Color(1.0, 1.0, 1.0, 1.0)

# ── Helpers ───────────────────────────────────────────────────
func _style_bar(bar: ProgressBar, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	bar.add_theme_stylebox_override("fill", style)

func show_darkness_warning() -> void:
	_show_warning("Está ficando escuro...")

func _on_achievement_unlocked(id: String) -> void:
	var data: Dictionary = GameManager.achievements.get(id, {})
	if data.is_empty():
		return
	achievement_icon.text = data.get("icon", "🏆")
	achievement_name.text = data.get("name", id)

	# Começa fora da tela pelo lado direito e desliza para dentro
	var vw: float = get_viewport().get_visible_rect().size.x
	achievement_popup.modulate.a = 0.0
	achievement_popup.position   = Vector2(vw + 10, 12)

	var tween := create_tween()
	tween.tween_property(achievement_popup, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(achievement_popup, "position:x", vw - 320.0, 0.4).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(3.5)
	tween.tween_property(achievement_popup, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(achievement_popup, "position:x", vw + 10.0, 0.4).set_trans(Tween.TRANS_SINE)

func set_keys(collected: int, total: int) -> void:
	key_label.visible = true
	var icons: String = ""
	for i in total:
		icons += "🗝 " if i < collected else "○ "
	key_label.text = "Chaves: %s" % icons.strip_edges()

func _show_warning(text: String) -> void:
	warning_label.text = text
	if _warning_tween:
		_warning_tween.kill()
	_warning_tween = create_tween()
	_warning_tween.tween_property(warning_label, "modulate:a", 1.0, 0.3)

func _hide_warning() -> void:
	if _warning_tween:
		_warning_tween.kill()
	_warning_tween = create_tween()
	_warning_tween.tween_property(warning_label, "modulate:a", 0.0, 0.5)

# ── Sanidade ──────────────────────────────────────────────────
func _build_sanity_overlays() -> void:
	# Overlay vermelho pulsante
	_red_overlay = ColorRect.new()
	_red_overlay.set_anchor(SIDE_RIGHT, 1.0)
	_red_overlay.set_anchor(SIDE_BOTTOM, 1.0)
	_red_overlay.color = Color(0.6, 0.0, 0.0, 0.0)
	_red_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_red_overlay)

	# Overlay VHS (linhas de scan)
	_vhs_overlay = ColorRect.new()
	_vhs_overlay.set_anchor(SIDE_RIGHT, 1.0)
	_vhs_overlay.set_anchor(SIDE_BOTTOM, 1.0)
	_vhs_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_vhs_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vhs_overlay)

func trigger_sanity_event() -> void:
	# Chamado pelo sorriso quando some
	sanity = clamp(sanity - 25.0, 0.0, 100.0)
	_update_sanity_bar()
	_activate_sanity_effects()

func recover_sanity(delta: float) -> void:
	# No modo Sombra a sanidade máxima é 50
	var max_sanity: float = 50.0 if GameManager.difficulty == GameManager.Difficulty.SHADOW else 100.0
	if sanity < max_sanity:
		sanity = clamp(sanity + delta * 3.0, 0.0, max_sanity)
		_update_sanity_bar()
		if sanity >= max_sanity:
			_deactivate_sanity_effects()

# ── Alucinações ───────────────────────────────────────────────
var _hallucination_timer: float = 0.0

func _update_hallucinations(delta: float) -> void:
	if sanity > 50.0:
		return
	# Quanto menor a sanidade, mais frequente
	var interval: float = lerp(2.0, 8.0, sanity / 50.0)
	_hallucination_timer -= delta
	if _hallucination_timer > 0.0:
		return
	_hallucination_timer = randf_range(interval * 0.5, interval)
	_spawn_hallucination()

func _spawn_hallucination() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return

	# Cria um sorriso falso que some sozinho
	var tex := load("res://images/Sorriso1.png") as Texture2D
	if not tex:
		return

	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.scale   = Vector2(0.2, 0.2)
	sprite.z_index = 15

	# Posição aleatória na visão do player
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	var cam_pos: Vector2 = player.global_position
	if camera:
		cam_pos = camera.get_screen_center_position()
	var vp := player.get_viewport().get_visible_rect().size
	var zoom := camera.zoom if camera else Vector2(1.5, 1.5)
	var hw: float = (vp.x / zoom.x) * 0.4
	var hh: float = (vp.y / zoom.y) * 0.4
	sprite.global_position = cam_pos + Vector2(randf_range(-hw, hw), randf_range(-hh, hh))
	sprite.modulate.a = 0.0

	get_tree().current_scene.add_child(sprite)

	# Aparece e some rapidamente
	var duration: float = randf_range(0.5, 1.5)
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "modulate:a", randf_range(0.3, 0.7), 0.2)
	tween.tween_interval(duration)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(sprite.queue_free)

func _update_sanity_bar() -> void:
	sanity_bar.value  = sanity
	sanity_label.text = "%d%%" % int(sanity)
	var bar_style := sanity_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if bar_style == null:
		bar_style = StyleBoxFlat.new()
		sanity_bar.add_theme_stylebox_override("fill", bar_style)
	if sanity > 60.0:
		bar_style.bg_color = Color(0.2, 0.8, 0.2, 1.0)
	elif sanity > 30.0:
		bar_style.bg_color = Color(0.8, 0.6, 0.1, 1.0)
	else:
		bar_style.bg_color = Color(0.8, 0.1, 0.1, 1.0)
	sanity_icon.modulate = Color(1.0, 0.2, 0.2, 1.0) if sanity <= 25.0 else Color(1.0, 1.0, 1.0, 1.0)
	# Atualiza barra de sanidade do P2 também
	if GameManager.coop_mode and is_instance_valid(p2_sanity_bar):
		p2_sanity_bar.value = sanity

# ── P2 callbacks ──────────────────────────────────────────────
func _on_p2_battery_changed(value: float, max_value: float) -> void:
	var pct := (value / max_value) * 100.0
	p2_battery_bar.value = pct
	p2_battery_label.text = "%d%%" % int(pct)
	var bar_style := p2_battery_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if bar_style == null:
		bar_style = StyleBoxFlat.new()
		p2_battery_bar.add_theme_stylebox_override("fill", bar_style)
	if pct > 50.0:
		bar_style.bg_color = Color(0.2, 0.8, 0.2, 1.0)
	elif pct > 25.0:
		bar_style.bg_color = Color(0.9, 0.7, 0.1, 1.0)
	else:
		bar_style.bg_color = Color(0.9, 0.1, 0.1, 1.0)

func _on_p2_stamina_changed(value: float, max_value: float) -> void:
	var pct := (value / max_value) * 100.0
	p2_stamina_bar.value = pct
	var bar_style := p2_stamina_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if bar_style == null:
		bar_style = StyleBoxFlat.new()
		p2_stamina_bar.add_theme_stylebox_override("fill", bar_style)
	if pct > 50.0:
		bar_style.bg_color = Color(0.1, 0.5, 0.9, 1.0)
	elif pct > 20.0:
		bar_style.bg_color = Color(0.2, 0.7, 0.4, 1.0)
	else:
		bar_style.bg_color = Color(0.8, 0.3, 0.1, 1.0)

func _activate_sanity_effects() -> void:
	_sanity_active = true

	# Overlay vermelho pulsa como coração
	if _sanity_tween:
		_sanity_tween.kill()
	_sanity_tween = create_tween().set_loops()
	var intensity: float = 1.0 - (sanity / 100.0)
	var speed: float     = lerp(1.2, 0.25, intensity)
	var max_alpha: float = lerp(0.2, 0.65, intensity)

	# Lub-dub vermelho
	_sanity_tween.tween_property(_red_overlay, "color:a", max_alpha, speed * 0.25).set_trans(Tween.TRANS_SINE)
	_sanity_tween.tween_property(_red_overlay, "color:a", max_alpha * 0.3, speed * 0.2)
	_sanity_tween.tween_property(_red_overlay, "color:a", max_alpha * 0.8, speed * 0.2).set_trans(Tween.TRANS_SINE)
	_sanity_tween.tween_property(_red_overlay, "color:a", 0.0, speed * 0.35)
	_sanity_tween.tween_interval(speed * 0.4)

	# Efeito VHS — distorção rápida
	_trigger_vhs_flash()

func _trigger_vhs_flash() -> void:
	# Flash de ruído branco rápido
	var vhs_tween := create_tween()
	vhs_tween.tween_property(_vhs_overlay, "color", Color(1.0, 1.0, 1.0, 0.15), 0.05)
	vhs_tween.tween_property(_vhs_overlay, "color", Color(0.0, 0.0, 0.0, 0.0), 0.1)
	vhs_tween.tween_property(_vhs_overlay, "color", Color(1.0, 0.0, 0.0, 0.08), 0.05)
	vhs_tween.tween_property(_vhs_overlay, "color", Color(0.0, 0.0, 0.0, 0.0), 0.15)
	# Repete algumas vezes
	for i in 3:
		vhs_tween.tween_interval(randf_range(0.1, 0.4))
		vhs_tween.tween_property(_vhs_overlay, "color", Color(1.0, 1.0, 1.0, randf_range(0.05, 0.2)), 0.04)
		vhs_tween.tween_property(_vhs_overlay, "color", Color(0.0, 0.0, 0.0, 0.0), 0.08)

func _deactivate_sanity_effects() -> void:
	_sanity_active = false
	if _sanity_tween:
		_sanity_tween.kill()
		_sanity_tween = null
	var fade := create_tween()
	fade.tween_property(_red_overlay, "color:a", 0.0, 1.5)

# ── Distorção ─────────────────────────────────────────────────
func _build_distortion_overlay() -> void:
	_distortion_overlay = ColorRect.new()
	_distortion_overlay.set_anchor(SIDE_RIGHT, 1.0)
	_distortion_overlay.set_anchor(SIDE_BOTTOM, 1.0)
	_distortion_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_distortion_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_distortion_overlay)

func _update_distortion(delta: float, dist: float) -> void:
	if dist > 100.0:
		if _distortion_overlay.color.a > 0.0:
			_distortion_overlay.color.a = move_toward(_distortion_overlay.color.a, 0.0, delta * 2.0)
		return

	_distortion_timer -= delta
	if _distortion_timer > 0.0:
		return
	_distortion_timer = randf_range(0.05, 0.15)

	# Simula distorção com flash rápido de cor aleatória
	var intensity: float = 1.0 - clamp(dist / 100.0, 0.0, 1.0)
	var r := randf_range(0.0, 0.15) * intensity
	var g := randf_range(0.0, 0.05) * intensity
	var b := randf_range(0.0, 0.1) * intensity
	_distortion_overlay.color = Color(r, g, b, intensity * 0.25)
	# Desloca levemente para simular aberração
	_distortion_overlay.position = Vector2(
		randf_range(-4.0, 4.0) * intensity,
		randf_range(-3.0, 3.0) * intensity
	)
