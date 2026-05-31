extends Node

# ── Estado global ─────────────────────────────────────────────
var player_state: String      = "running"
var creature_distance: float  = 500.0
var game_time: float          = 0.0
var total_time: float         = 0.0
var current_level: int        = 1
var player_deaths: int        = 0
var is_being_chased: bool     = false
var last_error: String        = ""
var is_maze_level: bool       = false
var keys_collected_total: int = 0
var endless_mode: bool        = false
var coop_mode: bool           = false
var brightness: float         = 1.0
var options_return_scene: String = "res://scenes/main_menu.tscn"

# ── Desbloqueáveis ────────────────────────────────────────────
const UNLOCK_COLORS: Dictionary = {
	"default": Color(1.0, 1.0, 1.0, 1.0),
	"easy":    Color(0.3, 1.0, 0.4, 1.0),
	"normal":  Color(0.4, 0.6, 1.0, 1.0),
	"hard":    Color(1.0, 0.3, 0.3, 1.0),
	"shadow":  Color(0.1, 0.1, 0.1, 1.0),
}
var selected_color: String  = "default"
var unlocked_colors: Array  = ["default"]

# ── Dificuldade ───────────────────────────────────────────────
enum Difficulty { EASY, NORMAL, HARD, SHADOW }
var difficulty: Difficulty = Difficulty.NORMAL

# [EASY, NORMAL, HARD, SHADOW]
const DIFF_CREATURE_COUNT: Array  = [3,    4,    5,    10  ]
const DIFF_KEY_COUNT: Array       = [3,    5,    8,    13  ]
const DIFF_CREATURE_SPEED: Array  = [0.85, 1.1,  1.45, 1.9 ]
const DIFF_BATTERY_DRAIN: Array   = [0.5,  1.0,  1.8,  2.5 ]
const DIFF_STAMINA_DRAIN: Array   = [0.6,  1.0,  1.5,  2.0 ]
const DIFF_KEY_TELEPORT: Array    = [25.0, 15.0, 8.0,  5.0 ]
const DIFF_NAMES: Array           = ["Fácil", "Médio", "Difícil", "Sombra"]
const DIFF_COLORS: Array          = [
	Color(0.2, 0.8, 0.2, 1),
	Color(0.9, 0.7, 0.1, 1),
	Color(0.9, 0.2, 0.1, 1),
	Color(0.5, 0.0, 0.8, 1),
]

# ── Recorde local ─────────────────────────────────────────────
const SAVE_PATH := "user://records.cfg"
var best_time: float  = 0.0
var best_deaths: int  = 999

# ── Estatísticas globais ──────────────────────────────────────
var total_runs: int        = 0
var total_escapes: int     = 0
var total_deaths_ever: int = 0
var total_time_played: float = 0.0
var shadow_completed: bool = false

# ── Conquistas ────────────────────────────────────────────────
var achievements: Dictionary = {
	"first_key":       {"name": "Primeira Chave",      "desc": "Colete a primeira chave",               "icon": "🗝", "unlocked": false},
	"first_escape":    {"name": "Primeira Fuga",       "desc": "Escape pela primeira vez",              "icon": "🏃", "unlocked": false},
	"no_death":        {"name": "Intocável",            "desc": "Escape sem morrer nenhuma vez",         "icon": "🛡", "unlocked": false},
	"survivor_3min":   {"name": "Sobrevivente",         "desc": "Sobreviva por 3 minutos",               "icon": "⏱", "unlocked": false},
	"shadow_mode":     {"name": "Mestre das Sombras",   "desc": "Complete o modo Sombra",                "icon": "💀", "unlocked": false},
	"all_keys_fast":   {"name": "Colecionador",         "desc": "Colete todas as chaves em menos de 2min","icon": "🗝", "unlocked": false},
	"hard_no_death":   {"name": "Lendário",             "desc": "Complete Difícil sem morrer",           "icon": "👑", "unlocked": false},
	"10_runs":         {"name": "Persistente",          "desc": "Jogue 10 partidas",                     "icon": "🔄", "unlocked": false},
	# ── Coop ──────────────────────────────────────────────────
	"coop_first":      {"name": "Dupla Dinâmica",       "desc": "Escape pela primeira vez em coop",      "icon": "👥", "unlocked": false},
	"coop_no_death":   {"name": "Parceiros Perfeitos",  "desc": "Escape em coop sem nenhum morrer",      "icon": "💑", "unlocked": false},
	"coop_shadow":     {"name": "Sombras Duplas",       "desc": "Complete o modo Sombra em coop",        "icon": "👻", "unlocked": false},
	"coop_fast":       {"name": "Velocidade Dupla",     "desc": "Escape em coop em menos de 3 minutos",  "icon": "⚡", "unlocked": false},
	"coop_10_runs":    {"name": "Inseparáveis",         "desc": "Jogue 10 partidas em coop",             "icon": "🤝", "unlocked": false},
}

signal achievement_unlocked(id: String)

signal game_started
signal player_died
signal level_completed
signal game_over

func _ready() -> void:
	_load_records()

func _process(delta: float) -> void:
	if player_state != "dead":
		game_time  += delta
		total_time += delta
	# Reseta a cada frame para que update_creature_distance pegue o mínimo
	creature_distance = 9999.0

func reset() -> void:
	player_state         = "running"
	creature_distance    = 500.0
	game_time            = 0.0
	is_being_chased      = false
	last_error           = ""
	keys_collected_total = 0
	# Não reseta coop_mode nem endless_mode aqui — são definidos antes de entrar no jogo

func get_game_data() -> Dictionary:
	return {
		"player_state":      player_state,
		"creature_distance": snappedf(creature_distance, 0.1),
		"game_time":         snappedf(game_time, 0.1),
		"current_level":     current_level,
		"is_being_chased":   is_being_chased,
		"last_error":        last_error
	}

func set_player_state(state: String) -> void:
	player_state = state

func update_creature_distance(dist: float) -> void:
	# Mantém sempre a menor distância entre todas as criaturas
	if dist < creature_distance:
		creature_distance = dist
	is_being_chased = creature_distance < 200.0

func register_error(error_type: String) -> void:
	last_error    = error_type
	player_deaths += 1

# ── Getters de dificuldade ────────────────────────────────────
func get_creature_count() -> int:
	var base: int = DIFF_CREATURE_COUNT[difficulty]
	# Coop: +2 criaturas extras
	return base + (2 if coop_mode else 0)

func get_key_count() -> int:
	var base: int = DIFF_KEY_COUNT[difficulty]
	# Coop: +2 chaves extras
	return base + (2 if coop_mode else 0)

func get_creature_speed_mult() -> float:
	var base: float = DIFF_CREATURE_SPEED[difficulty]
	# Coop: criaturas 20% mais rápidas
	return base * (1.2 if coop_mode else 1.0)

func get_battery_drain_mult() -> float:
	return DIFF_BATTERY_DRAIN[difficulty]

func get_stamina_drain_mult() -> float:
	return DIFF_STAMINA_DRAIN[difficulty]

func get_key_teleport_time() -> float:
	return DIFF_KEY_TELEPORT[difficulty]

func get_difficulty_name() -> String:
	return DIFF_NAMES[difficulty]

func get_difficulty_color() -> Color:
	return DIFF_COLORS[difficulty]

func set_difficulty(d: Difficulty) -> void:
	difficulty = d

# ── Recorde local ─────────────────────────────────────────────
func try_save_record(time: float, deaths: int) -> bool:
	var is_record := false
	if best_time <= 0.0 or time < best_time:
		best_time = time
		is_record = true
	if deaths < best_deaths:
		best_deaths = deaths
		is_record   = true
	if is_record:
		_save_records()
	return is_record

func _save_records() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("records", "best_time",          best_time)
	cfg.set_value("records", "best_deaths",        best_deaths)
	cfg.set_value("stats",   "total_runs",         total_runs)
	cfg.set_value("stats",   "total_escapes",      total_escapes)
	cfg.set_value("stats",   "total_deaths_ever",  total_deaths_ever)
	cfg.set_value("stats",   "total_time_played",  total_time_played)
	cfg.set_value("stats",   "shadow_completed",   shadow_completed)
	for id in achievements:
		cfg.set_value("achievements", id, achievements[id]["unlocked"])
	cfg.set_value("unlocks", "colors",         unlocked_colors)
	cfg.set_value("unlocks", "selected_color", selected_color)
	cfg.save(SAVE_PATH)

func _load_records() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_time         = cfg.get_value("records", "best_time",         0.0)
		best_deaths       = cfg.get_value("records", "best_deaths",       999)
		total_runs        = cfg.get_value("stats",   "total_runs",        0)
		total_escapes     = cfg.get_value("stats",   "total_escapes",     0)
		total_deaths_ever = cfg.get_value("stats",   "total_deaths_ever", 0)
		total_time_played = cfg.get_value("stats",   "total_time_played", 0.0)
		shadow_completed  = cfg.get_value("stats",   "shadow_completed",  false)
		for id in achievements:
			achievements[id]["unlocked"] = cfg.get_value("achievements", id, false)
		unlocked_colors = cfg.get_value("unlocks", "colors",         ["default"])
		selected_color  = cfg.get_value("unlocks", "selected_color", "default")

# ── Conquistas ────────────────────────────────────────────────
func unlock_achievement(id: String) -> void:
	if not achievements.has(id):
		return
	if achievements[id]["unlocked"]:
		return
	achievements[id]["unlocked"] = true
	_save_records()
	achievement_unlocked.emit(id)

func check_achievements(escaped: bool, time: float, deaths: int) -> void:
	total_runs        += 1
	total_deaths_ever += deaths
	total_time_played += time
	if escaped:
		total_escapes += 1

	if escaped:
		unlock_achievement("first_escape")
	if escaped and deaths == 0:
		unlock_achievement("no_death")
	if time >= 180.0:
		unlock_achievement("survivor_3min")
	if escaped and difficulty == Difficulty.SHADOW:
		unlock_achievement("shadow_mode")
		shadow_completed = true
	if escaped and keys_collected_total > 0 and time < 120.0:
		unlock_achievement("all_keys_fast")
	if escaped and difficulty == Difficulty.HARD and deaths == 0:
		unlock_achievement("hard_no_death")
	if total_runs >= 10:
		unlock_achievement("10_runs")

	# ── Conquistas Coop ───────────────────────────────────────
	if coop_mode:
		if escaped:
			unlock_achievement("coop_first")
		if escaped and deaths == 0:
			unlock_achievement("coop_no_death")
		if escaped and difficulty == Difficulty.SHADOW:
			unlock_achievement("coop_shadow")
		if escaped and time < 180.0:
			unlock_achievement("coop_fast")
		if total_runs >= 10:
			unlock_achievement("coop_10_runs")

	_save_records()

func unlock_color(diff_name: String) -> void:
	if not unlocked_colors.has(diff_name):
		unlocked_colors.append(diff_name)
		_save_records()

func get_player_color() -> Color:
	return UNLOCK_COLORS.get(selected_color, UNLOCK_COLORS["default"])
