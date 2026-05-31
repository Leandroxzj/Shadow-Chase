extends CharacterBody2D

# ── Velocidades ──────────────────────────────────────────────
const BASE_SPEED: float    = 90.0
const MAX_SPEED: float     = 160.0
const PATROL_SPEED: float  = 50.0
const ATTACK_RANGE: float  = 22.0

# ── Modo fantasma ─────────────────────────────────────────────
@export var ghost_mode: bool = false
const GHOST_SPEED_MULT: float = 0.62

# ── Detecção ─────────────────────────────────────────────────
const VISION_RANGE: float     = 320.0
const VISION_ANGLE: float     = 70.0
const HEAR_RANGE: float       = 180.0
const FLASHLIGHT_RANGE: float = 500.0
const LOSE_TIME: float        = 4.0

# ── Estados ──────────────────────────────────────────────────
enum State { PATROL, ALERT, CHASE, STUNNED }
var state: State = State.PATROL

var speed: float            = PATROL_SPEED
var target: CharacterBody2D = null
var aggression_level: float = 0.0
var anim: AnimatedSprite2D

var _current_dir: Vector2    = Vector2.ZERO
var _patrol_target: Vector2  = Vector2.ZERO
var _patrol_timer: float     = 0.0
var _lose_timer: float       = 0.0
var _last_known_pos: Vector2 = Vector2.ZERO
var _stun_timer: float       = 0.0

# ── Rastro de sombra ──────────────────────────────────────────
const TRAIL_INTERVAL: float  = 0.06
const TRAIL_COUNT: int       = 12
var _trail_timer: float      = 0.0

func _ready() -> void:
	add_to_group("creature")
	collision_layer = 1
	collision_mask  = 1
	anim = $AnimatedSprite2D
	anim.play("idle")
	target = get_tree().get_first_node_in_group("player")
	$AttackArea.body_entered.connect(_on_attack_area_body_entered)
	_pick_patrol_point()

	if ghost_mode:
		collision_layer = 0
		collision_mask  = 0
		modulate = Color(0.5, 0.6, 1.0, 0.55)
		var pulse := create_tween().set_loops()
		pulse.tween_property(self, "modulate:a", 0.55, 1.2).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(self, "modulate:a", 0.92, 1.2).set_trans(Tween.TRANS_SINE)

# ─────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return

	# Stun — fica parado
	if state == State.STUNNED:
		_stun_timer -= delta
		velocity = Vector2.ZERO
		if _stun_timer <= 0.0:
			_enter_patrol()
		return

	_update_state(delta)

	match state:
		State.PATROL: _do_patrol(delta)
		State.ALERT:  _do_alert(delta)
		State.CHASE:  _do_chase(delta)

	_update_distance()
	_update_trail(delta)

	if ghost_mode:
		global_position += velocity * delta
	else:
		move_and_slide()

	_update_visuals()

# ── Stun (para por N segundos) ────────────────────────────────
func stun(duration: float) -> void:
	state = State.STUNNED
	_stun_timer = duration
	velocity = Vector2.ZERO
	# Visual: pisca branco
	var tween := create_tween().set_loops(int(duration / 0.3))
	tween.tween_property(self, "modulate:a", 0.2, 0.15)
	tween.tween_property(self, "modulate:a", 1.0, 0.15)

# ── Rastro de sombra ──────────────────────────────────────────
func _update_trail(delta: float) -> void:
	if velocity.length() < 20.0:
		return
	_trail_timer -= delta
	if _trail_timer > 0.0:
		return
	_trail_timer = TRAIL_INTERVAL
	_spawn_trail_particle()

func _spawn_trail_particle() -> void:
	var p := ColorRect.new()
	var sz := randf_range(8.0, 18.0)
	p.size = Vector2(sz, sz)
	p.position = global_position - Vector2(sz * 0.5, sz * 0.5)
	# Cor do rastro: vermelho escuro para criatura normal, azul para fantasma
	if ghost_mode:
		p.color = Color(0.2, 0.3, 0.8, 0.5)
	else:
		p.color = Color(0.3, 0.0, 0.0, 0.55)
	get_tree().current_scene.add_child(p)

	# Fade out e some
	var tween := p.create_tween()
	tween.tween_property(p, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(p, "scale", Vector2(0.1, 0.1), 0.2)
	tween.tween_callback(p.queue_free)

# ── Máquina de estados ────────────────────────────────────────
func _update_state(delta: float) -> void:
	var can_see     := _can_see_player()
	var can_hear    := _can_hear_player()
	var light_alert := _attracted_by_flashlight()

	match state:
		State.PATROL:
			if can_see or can_hear or light_alert:
				_enter_chase()
		State.ALERT:
			if can_see or can_hear or light_alert:
				_enter_chase()
			else:
				_lose_timer -= delta
				if _lose_timer <= 0.0:
					_enter_patrol()
		State.CHASE:
			if can_see or can_hear or light_alert:
				_lose_timer = LOSE_TIME
				_last_known_pos = target.global_position
				if not AudioManager.is_chase_mode:
					AudioManager.play_chase()
			else:
				_lose_timer -= delta
				if _lose_timer <= 0.0:
					_enter_alert()

func _enter_patrol() -> void:
	state = State.PATROL
	speed = PATROL_SPEED
	if not ghost_mode:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
	_pick_patrol_point()

func _enter_alert() -> void:
	state = State.ALERT
	speed = PATROL_SPEED * 1.3
	_lose_timer = LOSE_TIME
	_patrol_target = _last_known_pos

func _enter_chase() -> void:
	state = State.CHASE
	_lose_timer = LOSE_TIME
	_last_known_pos = target.global_position
	if not ghost_mode:
		modulate = Color(1.0, 0.4, 0.4, 1.0)

# ── Comportamentos ────────────────────────────────────────────
func _do_patrol(delta: float) -> void:
	_patrol_timer -= delta
	var dist_to_pt := global_position.distance_to(_patrol_target)
	if dist_to_pt < 24.0 or _patrol_timer <= 0.0:
		_pick_patrol_point()
		return
	var desired := (_patrol_target - global_position).normalized()
	if ghost_mode:
		_current_dir = _current_dir.lerp(desired, 5.0 * delta)
	else:
		var best := _pick_best_direction(desired)
		_current_dir = _current_dir.lerp(best, 6.0 * delta)
	var patrol_spd := PATROL_SPEED * (GHOST_SPEED_MULT if ghost_mode else 1.0)
	velocity = _current_dir * patrol_spd

func _do_alert(delta: float) -> void:
	var dist := global_position.distance_to(_patrol_target)
	if dist < 32.0:
		velocity = Vector2.ZERO
		return
	var desired := (_patrol_target - global_position).normalized()
	if ghost_mode:
		_current_dir = _current_dir.lerp(desired, 6.0 * delta)
	else:
		var best := _pick_best_direction(desired)
		_current_dir = _current_dir.lerp(best, 7.0 * delta)
	velocity = _current_dir * speed

func _do_chase(delta: float) -> void:
	var to_player := target.global_position - global_position
	var dist      := to_player.length()
	if dist < 4.0:
		velocity = Vector2.ZERO
		return
	var desired := to_player.normalized()
	if ghost_mode:
		_current_dir = _current_dir.lerp(desired, 6.0 * delta)
	else:
		var best := _pick_best_direction(desired)
		_current_dir = _current_dir.lerp(best, 8.0 * delta)

	var chase_speed := (BASE_SPEED + (MAX_SPEED - BASE_SPEED) * aggression_level)
	chase_speed *= GameManager.get_creature_speed_mult()
	if ghost_mode:
		chase_speed *= GHOST_SPEED_MULT
	speed = lerp(speed, chase_speed, 0.05)
	velocity = _current_dir * speed

# ── Detecção ─────────────────────────────────────────────────
func _can_see_player() -> bool:
	var to_player := target.global_position - global_position
	var dist      := to_player.length()
	if dist > VISION_RANGE:
		return false
	if _current_dir.length() > 0.1:
		var angle := rad_to_deg(_current_dir.angle_to(to_player.normalized()))
		if abs(angle) > VISION_ANGLE:
			return false
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	query.exclude = [self]
	query.collision_mask = 1
	var result := space.intersect_ray(query)
	return result.is_empty() or result.collider == target

func _can_hear_player() -> bool:
	var dist := global_position.distance_to(target.global_position)
	if dist > HEAR_RANGE:
		return false
	var player_state: String = GameManager.get_game_data().get("player_state", "idle")
	return player_state == "walk"

func _attracted_by_flashlight() -> bool:
	if not is_instance_valid(target):
		return false
	if not target.get("flashlight_on"):
		return false
	var dist := global_position.distance_to(target.global_position)
	if dist > FLASHLIGHT_RANGE:
		return false
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	query.exclude = [self]
	query.collision_mask = 1
	var result := space.intersect_ray(query)
	return result.is_empty() or result.collider == target

func _pick_patrol_point() -> void:
	var angle  := randf() * TAU
	var radius := randf_range(150.0, 400.0)
	_patrol_target = global_position + Vector2(cos(angle), sin(angle)) * radius
	_patrol_timer  = randf_range(4.0, 8.0)

func _pick_best_direction(desired: Vector2) -> Vector2:
	var angles: Array = [0.0, 30.0, -30.0, 60.0, -60.0, 90.0, -90.0, 120.0, -120.0]
	var space  := get_world_2d().direct_space_state
	var ray_len: float = 40.0
	for deg in angles:
		var test_dir := desired.rotated(deg_to_rad(deg))
		var query    := PhysicsRayQueryParameters2D.create(
			global_position, global_position + test_dir * ray_len
		)
		query.exclude        = [self]
		query.collision_mask = 1
		if space.intersect_ray(query).is_empty():
			return test_dir
	return Vector2.ZERO

func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("die"):
		AudioManager.play_sfx("creature_growl")
		body.die()

func _update_distance() -> void:
	if is_instance_valid(target):
		GameManager.update_creature_distance(
			global_position.distance_to(target.global_position)
		)

func _update_visuals() -> void:
	if velocity.length() > 10.0:
		if anim.animation != "walk":
			anim.play("walk")
		anim.flip_h = velocity.x < 0.0
	else:
		if anim.animation != "idle":
			anim.play("idle")

func increase_aggression(amount: float) -> void:
	aggression_level = clamp(aggression_level + amount, 0.0, 1.0)

func attract_to(pos: Vector2) -> void:
	# Força a criatura a ir até a posição da isca
	if state == State.PATROL or state == State.ALERT:
		_last_known_pos = pos
		_enter_alert()
