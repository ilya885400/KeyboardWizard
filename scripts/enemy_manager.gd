extends Node2D

# ==========================================
# МЕНЕДЖЕР ВРАГОВ
# Поддерживает два режима:
#   1. Обычная игра (lesson_lang == "") — оригинальное поведение.
#   2. Обучение (lesson_lang == "en" / "ru") — слова из словаря урока,
#      параметры сложности фиксированы уроком.
#
# МИНИБОСС: На уровне "Полный домашний ряд" (EN 4 / RU 4)
# в конце уровня появляется Одержимая Книга.
# ==========================================

@export var enemy_scene: PackedScene
@export var goblin_scene: PackedScene
@export var wraith_scene: PackedScene
@export var troll_scene: PackedScene
@export var book_boss_scene: PackedScene  # ← НОВОЕ: назначь EnemyBookBoss.tscn
@export var snake_boss_scene: PackedScene
@export var lich_boss_scene: PackedScene

@export var spawn_interval: float = 2.5
@export var spawn_radius: float   = 650.0
@export var max_enemies: int      = 30

# Текущий язык ОБЫЧНОЙ игры. Задается при старте режима.
var game_language: String = "en"

@onready var spawn_timer: Timer = $SpawnTimer

signal enemy_killed(points: int)

# ─────────────────────────────────────────
# РЕЖИМ ОБУЧЕНИЯ
# ─────────────────────────────────────────
var lesson_lang:  String = ""   # "" = обычный режим
var lesson_index: int    = 0

# ─────────────────────────────────────────
# МИНИБОСС — Одержимая Книга
# Индексы уроков "Полный домашний ряд":
#   EN: индекс 3 (EN 4)
#   RU: индекс 3 (RU 4)
# ─────────────────────────────────────────
const BOOK_BOSS_LESSON_INDEX := 3   # 0-based индекс
const SNAKE_BOSS_LESSON_INDEX := 7
const LICH_BOSS_LESSON_INDEX_EN := 13   # последний урок EN (0-based)
const LICH_BOSS_LESSON_INDEX_RU := 14   # последний урок RU (0-based)

var _boss_spawned:       bool  = false
var _boss_spawn_time:    float = 0.0   # через сколько секунд спавнить
var _boss_spawn_pending: bool  = false
var _lich_spawned: bool = false
var _lich_spawn_pending: bool = false

var _lesson_timer:       float = 0.0
var _snake_boss_spawned:       bool  = false
var _snake_boss_spawn_pending: bool  = false
var _snake_boss_spawn_time:    float = 0.0

# ─────────────────────────────────────────
# ОРИГИНАЛЬНЫЙ АНГЛИЙСКИЙ СЛОВАРЬ
# ─────────────────────────────────────────
const EN_WORDS_SHORT := [
	"fire", "bolt", "mana", "ice", "arc", "hex", 
	"soul", "void", "dark", "wind", "dust", "beam", 
	"orb", "fury", "gaze", "bane", "mist", "glow"
]

const EN_WORDS_MEDIUM := [
	"flame", "storm", "rune", "curse", "spell", "shade", 
	"blaze", "chill", "cloak", "ethos", "glyph", "spark", 
	"hallow", "wraith", "venom", "spirit", "shadow", "primal"
]

const EN_WORDS_LONG := [
	"inferno", "blizzard", "grimoire", "sorcery", "eldritch", 
	"tempest", "arcane", "channel", "spectral", "shimmer", 
	"phantom", "eclipse", "conjure", "mystic", "barrier"
]

# ─────────────────────────────────────────
# РУССКИЙ СЛОВАРЬ (для обычной игры)
# ─────────────────────────────────────────
const RU_WORDS_SHORT := [
	"лед", "маг", "дым", "меч", "щит", "дух", "яд", "тьма", 
	"свет", "руна", "мана", "кара", "хаос", "гром", "прах", 
	"луна", "огнь", "цепь", "рука", "удар"
]

const RU_WORDS_MEDIUM := [
	"пламя", "шторм", "порча", "искра", "холод", "туман", 
	"зелье", "посох", "череп", "клинок", "стрела", "алтарь", 
	"стихия", "колдун", "амулет", "свиток", "фантом", "сияние"
]

const RU_WORDS_LONG := [
	"инферно", "гримуар", "призрак", "затмение", "чародей", 
	"артефакт", "алхимия", "иллюзия", "кристалл", "телепорт", 
	"некромант", "проклятие", "заклинание", "колдовство"
]

var word_pool: Array[String] = []
var max_word_length: int     = 7
var difficulty_level: int    = 1


func _ready() -> void:
	add_to_group("enemy_manager")
	_rebuild_word_pool()

	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)


func _process(delta: float) -> void:
	# Тикаем таймер урока для отслеживания момента спавна босса
	if lesson_lang != "" and lesson_index == BOOK_BOSS_LESSON_INDEX and not _boss_spawned:
		_lesson_timer += delta
		if _boss_spawn_pending and _lesson_timer:# >= _boss_spawn_time:
			_boss_spawn_pending = false
			_spawn_book_boss()
	
	if lesson_lang != "" and lesson_index == SNAKE_BOSS_LESSON_INDEX and not _snake_boss_spawned:
		if _snake_boss_spawn_pending: #and _lesson_timer >= _snake_boss_spawn_time:
			_snake_boss_spawn_pending = false
			_spawn_snake_boss()
	if lesson_lang != "" and not _lich_spawned:
		var lich_idx = LICH_BOSS_LESSON_INDEX_EN if lesson_lang == "en" else LICH_BOSS_LESSON_INDEX_RU
		if lesson_index == lich_idx and _lich_spawn_pending:
			_lich_spawn_pending = false
			_spawn_lich_boss()
			print("БООООООООООООООООООООООООООООООООООООООООООООООООСС")




# ─────────────────────────────────────────
# АКТИВАЦИЯ ОБЫЧНОГО РЕЖИМА ИГРЫ
# ─────────────────────────────────────────
func activate_normal_mode(p_lang: String) -> void:
	lesson_lang = "" # Гарантируем, что режим обучения выключен
	game_language = p_lang
	
	difficulty_level = 1
	max_word_length = 7
	spawn_interval = 2.5
	max_enemies = 30
	_boss_spawned       = false
	_boss_spawn_pending = false
	_lesson_timer       = 0.0
	
	_rebuild_word_pool()
	
	spawn_timer.wait_time = spawn_interval
	spawn_timer.start()


# ─────────────────────────────────────────
# АКТИВАЦИЯ РЕЖИМА ОБУЧЕНИЯ
# ─────────────────────────────────────────
func activate_typing_mode(p_lang: String, p_lesson_index: int) -> void:
	lesson_lang  = p_lang
	lesson_index = p_lesson_index

	# Сброс состояния босса
	_boss_spawned       = false
	_boss_spawn_pending = false
	_lesson_timer       = 0.0

	var lesson = TypingLessonManager.get_lesson(p_lang, p_lesson_index)
	spawn_interval = lesson.get("spawn_interval", 2.5)
	max_enemies    = lesson.get("max_enemies",    15)
	
	var duration: float = lesson.get("duration", 105.0)

	# Планируем спавн босса в конце уровня "Полный домашний ряд"
	if p_lesson_index == BOOK_BOSS_LESSON_INDEX and book_boss_scene != null:
		# Босс появляется за 20 секунд до конца уровня
		_boss_spawn_time    = max(duration - 20.0, duration * 0.75)
		_boss_spawn_pending = true
	
	if p_lesson_index == SNAKE_BOSS_LESSON_INDEX and snake_boss_scene != null:
		_snake_boss_spawned       = false
		_snake_boss_spawn_pending = true
		_snake_boss_spawn_time    = max(duration - 25.0, duration * 0.7)
		
	var lich_idx = LICH_BOSS_LESSON_INDEX_EN if p_lang == "en" else LICH_BOSS_LESSON_INDEX_RU
	
	if p_lesson_index == lich_idx and lich_boss_scene != null:
		_lich_spawned = false
		_lich_spawn_pending = true
	
	spawn_timer.wait_time = spawn_interval
	spawn_timer.start()


# ─────────────────────────────────────────
# СПАВН МИНИБОССА
# ─────────────────────────────────────────
func _spawn_book_boss() -> void:
	if _boss_spawned:
		return
	if book_boss_scene == null:
		push_warning("EnemyManager: book_boss_scene не назначена!")
		return

	_boss_spawned = true

	# Спавним чуть дальше обычного, чтобы игрок видел приближение
	var angle     := randf() * TAU
	var spawn_pos := _get_camera_center() + Vector2(cos(angle), sin(angle)) * (spawn_radius * 0.8)

	var boss = book_boss_scene.instantiate()

	# Параметры сложности урока
	var lesson    = TypingLessonManager.get_lesson(lesson_lang, lesson_index)
	var sp_mult   : float = lesson.get("enemy_speed_mult", 0.62)
	var hp_mult_v : float = lesson.get("hp_mult", 0.85)

	boss.speed *= sp_mult
	boss.hp     = max(15, int(boss.hp * hp_mult_v * 1.5))
	boss.max_hp = boss.hp
	boss.points = 100  # Больше очков за минибосса

	# Передаём разрешённые буквы для выстрелов
	var allowed = TypingLessonManager.get_allowed_letters(lesson_lang, lesson_index)
	if boss.has_method("set_allowed_letters"):
		boss.set_allowed_letters(allowed)

	add_child(boss)
	boss.global_position = spawn_pos

	var player_node = get_tree().get_first_node_in_group("player")
	boss.player = player_node
	boss.set_word(get_random_word())

	# Оповещение главной сцены / HUD
	_announce_boss()

func _spawn_snake_boss() -> void:
	if _snake_boss_spawned:
		return
	if snake_boss_scene == null:
		push_warning("EnemyManager: snake_boss_scene не назначена!")
		return
 
	_snake_boss_spawned = true
 
	var angle     := randf() * TAU
	var spawn_pos := _get_camera_center() + Vector2(cos(angle), sin(angle)) * (spawn_radius * 0.9)
 
	var boss = snake_boss_scene.instantiate()
 
	# Передаём ссылки на сцены яиц/маленьких змей из менеджера
	if has_node("SnakeEggScene"):
		boss.egg_scene = get_node("SnakeEggScene")
 
	# Параметры сложности
	if lesson_lang != "":
		var lesson = TypingLessonManager.get_lesson(lesson_lang, lesson_index)
		var sp_mult : float = lesson.get("enemy_speed_mult", 0.7)
		boss.speed *= sp_mult
		boss.hp = min(40, int(boss.hp * lesson.get("hp_mult", 1.0) * 1.5))
		boss.max_hp = boss.hp
 
	add_child(boss)
	boss.global_position = spawn_pos
 
	var player_node = get_tree().get_first_node_in_group("player")
	boss.player = player_node
	boss.set_word(get_random_word())
 
	_announce_snake_boss()
 
 
func _announce_snake_boss() -> void:
	var main = get_tree().get_first_node_in_group("main_scene")
	if main and main.has_method("show_boss_announcement"):
		main.show_boss_announcement(
			"🐍 ЗМЕЯ-БОСС ПОЯВИЛАСЬ! 🐍",
			"Уничтожь её, пока она не отложила слишком много яиц!"
		)
	else:
		var label := Label.new()
		label.text = "🐍 БОСС: ВЕЛИКАЯ ЗМЕЯ! 🐍"
		label.add_theme_font_size_override("font_size", 28)
		label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.2))
		label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		label.offset_top = 120
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		get_tree().current_scene.add_child(label)
		var tw = label.create_tween()
		tw.tween_property(label, "position:y", label.position.y - 40, 1.5)
		tw.parallel().tween_property(label, "modulate:a", 0.0, 3.5)
		tw.tween_callback(label.queue_free)
		
		
		
func _spawn_lich_boss() -> void:
	if _lich_spawned:
		return
	if lich_boss_scene == null:
		push_warning("EnemyManager: lich_boss_scene не назначена!")
		return

	_lich_spawned = true

	var boss = lich_boss_scene.instantiate()
	add_child(boss)
	# Лич — оверлей, позиция не важна, но ставим в центр
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		boss.global_position = player_node.global_position
	boss.player = player_node

	_announce_lich()


func _announce_lich() -> void:
	var main = get_tree().get_first_node_in_group("main_scene")
	if main and main.has_method("show_boss_announcement"):
		main.show_boss_announcement(
			"💀 ЛИЧ ЯВИЛСЯ! 💀",
			"Введи стихотворение, чтобы изгнать его!"
		)
	else:
		var label := Label.new()
		label.text = "💀 ФИНАЛЬНЫЙ БОСС: ЛИЧ! 💀"
		label.add_theme_font_size_override("font_size", 32)
		label.add_theme_color_override("font_color", Color(0.7, 0.2, 1.0))
		label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		label.offset_top = 80
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		get_tree().current_scene.add_child(label)
		var tw = label.create_tween()
		tw.tween_property(label, "scale", Vector2(1.3, 1.3), 0.3)
		tw.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2)
		tw.tween_interval(2.0)
		tw.tween_property(label, "modulate:a", 0.0, 1.0)
		tw.tween_callback(label.queue_free)


func _announce_boss() -> void:
	# Создаём анонс на экране через главную сцену
	var main = get_tree().get_first_node_in_group("main_scene")
	if main and main.has_method("show_boss_announcement"):
		main.show_boss_announcement("⚡ ОДЕРЖИМАЯ КНИГА ПОЯВИЛАСЬ! ⚡",
			"Отражай её буквы нажатием нужной клавиши!")
	else:
		# Запасной вариант — создаём метку напрямую
		var label := Label.new()
		label.text = "⚡ МИНИБОСС: ОДЕРЖИМАЯ КНИГА! ⚡"
		label.add_theme_font_size_override("font_size", 28)
		label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.1))
		label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		label.offset_top = 120
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		get_tree().current_scene.add_child(label)
		var tw = label.create_tween()
		tw.tween_property(label, "position:y", label.position.y - 40, 1.5)
		tw.parallel().tween_property(label, "modulate:a", 0.0, 3.0)
		tw.tween_callback(label.queue_free)


# ─────────────────────────────────────────
# ВСПОМОГАТЕЛЬНЫЙ МЕТОД: разрешённые буквы
# (используется книгой-боссом)
# ─────────────────────────────────────────
func get_lesson_allowed_letters() -> Array:
	if lesson_lang != "":
		return TypingLessonManager.get_allowed_letters(lesson_lang, lesson_index)
	return []


# ─────────────────────────────────────────
# СЛОВАРЬ
# ─────────────────────────────────────────
func _rebuild_word_pool() -> void:
	word_pool.clear()
	
	var short_source := EN_WORDS_SHORT
	var medium_source := EN_WORDS_MEDIUM
	var long_source := EN_WORDS_LONG
	
	if lesson_lang == "" and game_language == "ru":
		short_source = RU_WORDS_SHORT
		medium_source = RU_WORDS_MEDIUM
		long_source = RU_WORDS_LONG
	
	for w in (short_source + medium_source + long_source):
		if w.length() <= max_word_length:
			word_pool.append(w)
			
	if word_pool.is_empty():
		word_pool = short_source.duplicate()


func get_random_word() -> String:
	return DifficultyAi.get_next_word()


func reduce_word_length() -> void:
	if lesson_lang != "":
		return
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

	var angle     := randf() * TAU
	var spawn_pos := _get_camera_center() + Vector2(cos(angle), sin(angle)) * spawn_radius

	var enemy = scene.instantiate()

	if lesson_lang != "":
		var lesson    = TypingLessonManager.get_lesson(lesson_lang, lesson_index)
		var sp_mult   : float = lesson.get("enemy_speed_mult", 0.6)
		var hp_mult_v : float = lesson.get("hp_mult", 1.0)
		enemy.speed *= sp_mult
		if enemy.hp > 1:
			enemy.hp     = max(1, int(enemy.hp * hp_mult_v))
			enemy.max_hp = enemy.hp
	else:
		if Engine.has_singleton("DifficultyAI"):
			enemy.speed *= DifficultyAi.get_speed_mult()

	add_child(enemy)
	enemy.global_position = spawn_pos

	var player_node = get_tree().get_first_node_in_group("player")
	enemy.player = player_node

	enemy.set_word(get_random_word())


func _pick_enemy_scene() -> PackedScene:
	if lesson_lang != "":
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

	# Обычный режим
	var pool: Array[PackedScene] = []
	if enemy_scene:
		for i in range(4): pool.append(enemy_scene)
	if difficulty_level >= 2 and goblin_scene:
		for i in range(3): pool.append(goblin_scene)
	if difficulty_level >= 3 and wraith_scene:
		for i in range(2): pool.append(wraith_scene)
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
# СЛОЖНОСТЬ (только обычный режим)
# ─────────────────────────────────────────
func increase_difficulty() -> void:
	if lesson_lang != "":
		return
	difficulty_level += 1
	spawn_interval = max(0.5, spawn_interval - 0.2)
	spawn_timer.wait_time = spawn_interval
	spawn_timer.start()
