extends Node2D

# ==========================================
# МЕНЕДЖЕР ВРАГОВ
# Поддерживает два режима:
#   1. Обычная игра (typing_mode = false) — оригинальное поведение.
#   2. Обучение слепой печати (typing_mode = true) — слова только из
#      словаря текущего урока, параметры сложности из урока.
# ==========================================

@export var enemy_scene: PackedScene           # Enemy.tscn (скелет)
@export var goblin_scene: PackedScene          # EnemyGoblin.tscn
@export var wraith_scene: PackedScene          # EnemyWraith.tscn
@export var troll_scene: PackedScene           # EnemyTroll.tscn

@export var spawn_interval: float = 2.5
@export var spawn_radius: float = 650.0
@export var max_enemies: int = 30

@onready var spawn_timer: Timer = $SpawnTimer

signal enemy_killed(points: int)

# ─────────────────────────────────────────
# РЕЖИМ ОБУЧЕНИЯ
# ─────────────────────────────────────────
var typing_mode: bool = false
var lesson_index: int = 0

# ─────────────────────────────────────────
# ОРИГИНАЛЬНЫЙ СЛОВАРЬ (обычный режим)
# ─────────────────────────────────────────
const WORDS_SHORT  := ["fire", "bolt", "mana", "ice", "arc", "hex"]
const WORDS_MEDIUM := ["flame", "storm", "rune", "curse", "spell", "shade"]
const WORDS_LONG   := ["inferno", "blizzard", "grimoire", "sorcery", "eldritch"]

var word_pool: Array[String] = []
var max_word_length: int = 7

# Текущий уровень сложности (растёт с каждым левел-апом игрока)
var difficulty_level: int = 1

# Базовая скорость врага (для масштабирования в режиме обучения)
const BASE_ENEMY_SPEED := 80.0


func _ready() -> void:
	add_to_group("enemy_manager")
	_rebuild_word_pool()

	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start()


# ─────────────────────────────────────────
# АКТИВАЦИЯ РЕЖИМА ОБУЧЕНИЯ
# Вызывается из main.gd перед стартом урока.
# ─────────────────────────────────────────
func activate_typing_mode(p_lesson_index: int) -> void:
	typing_mode  = true
	lesson_index = p_lesson_index

	var lesson := TypingLessonManager.get_lesson(p_lesson_index)

	# Применяем параметры урока
	spawn_interval = lesson.get("spawn_interval", 2.5)
	max_enemies    = lesson.get("max_enemies", 15)

	spawn_timer.wait_time = spawn_interval
	spawn_timer.start()


# ─────────────────────────────────────────
# ПЕРЕСБОРКА ПУЛА СЛОВ (обычный режим)
# ─────────────────────────────────────────
func _rebuild_word_pool() -> void:
	word_pool.clear()
	for w in (WORDS_SHORT + WORDS_MEDIUM + WORDS_LONG):
		if w.length() <= max_word_length:
			word_pool.append(w)
	if word_pool.is_empty():
		word_pool = WORDS_SHORT.duplicate()


func get_random_word() -> String:
	if typing_mode:
		return TypingLessonManager.get_word_for_lesson(lesson_index)
	return word_pool.pick_random()


func reduce_word_length() -> void:
	if typing_mode:
		return   # В режиме обучения длина слов задаётся уроком
	max_word_length = max(3, max_word_length - 1)
	_rebuild_word_pool()


# ─────────────────────────────────────────
# ОЧКИ
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

	# ── В режиме обучения масштабируем скорость врага ─────────────────
	if typing_mode:
		var lesson := TypingLessonManager.get_lesson(lesson_index)
		var speed_mult: float = lesson.get("enemy_speed_mult", 0.6)
		var hp_mult: float    = lesson.get("hp_mult", 1.0)
		enemy.speed = BASE_ENEMY_SPEED * speed_mult
		# Масштабируем HP только у врагов с несколькими очками жизни
		if enemy.hp > 1:
			enemy.hp    = max(1, int(enemy.hp * hp_mult))
			enemy.max_hp = enemy.hp

	add_child(enemy)
	enemy.global_position = spawn_pos

	var player = get_tree().get_first_node_in_group("player")
	enemy.player = player

	enemy.set_word(get_random_word())


func _pick_enemy_scene() -> PackedScene:
	if typing_mode:
		# В режиме обучения: только скелеты (простые враги) на первых уроках,
		# потом добавляем разнообразие
		var pool: Array[PackedScene] = []
		if enemy_scene:
			pool.append(enemy_scene)
			pool.append(enemy_scene)
			pool.append(enemy_scene)

		if lesson_index >= 4 and goblin_scene:
			pool.append(goblin_scene)
			pool.append(goblin_scene)

		if lesson_index >= 8 and wraith_scene:
			pool.append(wraith_scene)

		if lesson_index >= 12 and troll_scene:
			pool.append(troll_scene)

		if pool.is_empty():
			return enemy_scene
		return pool.pick_random()

	# ── Обычный режим ─────────────────────────────────────────────────
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
# СЛОЖНОСТЬ (обычный режим)
# ─────────────────────────────────────────
func increase_difficulty() -> void:
	if typing_mode:
		return   # В режиме обучения сложность фиксирована уроком
	difficulty_level += 1
	spawn_interval = max(0.5, spawn_interval - 0.2)
	spawn_timer.wait_time = spawn_interval
	spawn_timer.start()
