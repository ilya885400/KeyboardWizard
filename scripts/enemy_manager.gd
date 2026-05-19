extends Node2D

# ==========================================
# МЕНЕДЖЕР ВРАГОВ
# Спавнит разные типы врагов в зависимости от сложности.
# Skeleton → появляется сразу.
# Goblin   → добавляется с уровня 2 (быстрый, слабый).
# Wraith   → добавляется с уровня 3 (средний, 2 HP).
# Troll    → добавляется с уровня 5 (медленный, 4 HP).
# ==========================================

@export var enemy_scene: PackedScene           # Enemy.tscn (скелет, оригинал)
@export var goblin_scene: PackedScene          # EnemyGoblin.tscn
@export var wraith_scene: PackedScene          # EnemyWraith.tscn
@export var troll_scene: PackedScene           # EnemyTroll.tscn

@export var spawn_interval: float = 2.5
@export var spawn_radius: float = 650.0
@export var max_enemies: int = 30

@onready var spawn_timer: Timer = $SpawnTimer

# ── НОВОЕ: сигнал для передачи очков в Main ───────────────────────────────────
signal enemy_killed(points: int)

# ─────────────────────────────────────────
# СЛОВАРЬ СЛОВ
# ─────────────────────────────────────────
const WORDS_SHORT  := ["fire", "bolt", "mana", "ice", "arc", "hex"]
const WORDS_MEDIUM := ["flame", "storm", "rune", "curse", "spell", "shade"]
const WORDS_LONG   := ["inferno", "blizzard", "grimoire", "sorcery", "eldritch"]

var word_pool: Array[String] = []
var max_word_length: int = 7

# Текущий уровень сложности (растёт с каждым левел-апом игрока)
var difficulty_level: int = 1


func _ready() -> void:
	add_to_group("enemy_manager")
	_rebuild_word_pool()

	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start()


# ─────────────────────────────────────────
# ПЕРЕСБОРКА ПУЛА СЛОВ
# ─────────────────────────────────────────
func _rebuild_word_pool() -> void:
	word_pool.clear()
	for w in (WORDS_SHORT + WORDS_MEDIUM + WORDS_LONG):
		if w.length() <= max_word_length:
			word_pool.append(w)
	if word_pool.is_empty():
		word_pool = WORDS_SHORT.duplicate()


func get_random_word() -> String:
	return word_pool.pick_random()


func reduce_word_length() -> void:
	max_word_length = max(3, max_word_length - 1)
	_rebuild_word_pool()


# ─────────────────────────────────────────
# ОЧКИ — вызывается из enemy.gd при смерти врага
# ─────────────────────────────────────────
func report_kill(points: int) -> void:
	emit_signal("enemy_killed", points)


# ─────────────────────────────────────────
# СПАВН
# ─────────────────────────────────────────
func _on_spawn_timer_timeout() -> void:
	if get_tree().get_nodes_in_group("enemies").size() >= max_enemies:
		return
	_spawn_enemy()


func _spawn_enemy() -> void:
	var scene := _pick_enemy_scene()
	if scene == null:
		push_error("EnemyManager: сцена врага не назначена!")
		return

	var angle := randf() * TAU
	var spawn_pos := _get_camera_center() + Vector2(cos(angle), sin(angle)) * spawn_radius

	var enemy = scene.instantiate()
	add_child(enemy)
	enemy.global_position = spawn_pos

	var player = get_tree().get_first_node_in_group("player")
	enemy.player = player

	enemy.set_word(get_random_word())


func _pick_enemy_scene() -> PackedScene:
	var pool: Array[PackedScene] = []

	if enemy_scene:
		for i in range(4):
			pool.append(enemy_scene)

	if difficulty_level >= 2 and goblin_scene:
		for i in range(3):
			pool.append(goblin_scene)

	if difficulty_level >= 3 and wraith_scene:
		for i in range(2):
			pool.append(wraith_scene)

	if difficulty_level >= 5 and troll_scene:
		pool.append(troll_scene)

	if pool.is_empty():
		return enemy_scene

	return pool.pick_random()


# ─────────────────────────────────────────
# ПОЗИЦИЯ КАМЕРЫ
# ─────────────────────────────────────────
func _get_camera_center() -> Vector2:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		return player.global_position
	return Vector2.ZERO


# ─────────────────────────────────────────
# СЛОЖНОСТЬ
# ─────────────────────────────────────────
func increase_difficulty() -> void:
	difficulty_level += 1
	spawn_interval = max(0.5, spawn_interval - 0.2)
	spawn_timer.wait_time = spawn_interval
	spawn_timer.start()
