extends Node

# ==========================================
# МЕНЕДЖЕР УРОКОВ СЛЕПОЙ ПЕЧАТИ
# Singleton: добавь в Project → Autoload как "TypingLessonManager"
#
# СТРУКТУРА УРОКОВ:
#   Каждый урок вводит новые клавиши поверх предыдущих.
#   Слова составлены ТОЛЬКО из освоенных букв.
#   Сложность растёт: больше врагов, быстрее, длиннее слова.
#
# ЗОНЫ КЛАВИАТУРЫ (QWERTY, home-row first):
#   Урок 1  — f j           (указательные, home row)
#   Урок 2  — f j d k       (+ средние пальцы home row)
#   Урок 3  — f j d k s l   (+ безымянные home row)
#   Урок 4  — f j d k s l a ;  (+ мизинцы home row — полный home row)
#   Урок 5  — + e i          (верхний ряд, указательные)
#   Урок 6  — + r u          (верхний ряд, указательные 2)
#   Урок 7  — + t y          (верхний ряд, центр)
#   Урок 8  — + w o          (верхний ряд, средние)
#   Урок 9  — + q p          (верхний ряд, крайние)
#   Урок 10 — + v m          (нижний ряд, указательные)
#   Урок 11 — + c ,          (нижний ряд, средние)
#   Урок 12 — + x .          (нижний ряд, безымянные)
#   Урок 13 — + z /  + b n  (нижний ряд, полный)
#   Урок 14 — весь алфавит  (финал — все буквы)
# ==========================================

signal lesson_changed(lesson_index: int, lesson_data: Dictionary)

# Текущий урок (0-based)
var current_lesson: int = 0
var typing_mode: bool = false

# ─────────────────────────────────────────
# ДАННЫЕ УРОКОВ
# ─────────────────────────────────────────
const LESSONS := [
	# ── Урок 1: f j ──────────────────────────────────────────────────
	{
		"title": "Урок 1",
		"subtitle": "Домашний ряд: F J",
		"keys": "F  J",
		"allowed": ["f", "j"],
		"description": "Указательные пальцы обеих рук. Это твоя база — не смотри на клавиатуру!",
		"words": [
			"ff", "jj", "fj", "jf", "fjf", "jfj", "ffj", "jjf",
			"fjj", "jff", "ffjj", "jjff", "fjfj", "jfjf",
			"fffj", "jjjf", "fjff", "jfjj"
		],
		# Параметры сложности
		"spawn_interval": 3.5,
		"max_enemies": 8,
		"enemy_speed_mult": 0.55,
		"duration": 90.0,
		"hp_mult": 0.7,
	},
	# ── Урок 2: f j d k ──────────────────────────────────────────────
	{
		"title": "Урок 2",
		"subtitle": "Домашний ряд: F J D K",
		"keys": "F  J  D  K",
		"allowed": ["f", "j", "d", "k"],
		"description": "Добавляем средние пальцы. D — левый, K — правый.",
		"words": [
			"df", "kj", "dk", "fk", "jd", "dkf", "fjk", "jkd",
			"fdk", "jdf", "dfk", "kjf", "dfjk", "jkfd",
			"fdkj", "jkdf", "dkfj", "fjdk", "ffjd", "kkdj",
			"dfjj", "kffd", "jkdk", "fdfd", "kjkj"
		],
		"spawn_interval": 3.2,
		"max_enemies": 10,
		"enemy_speed_mult": 0.60,
		"duration": 100.0,
		"hp_mult": 0.8,
	},
	# ── Урок 3: f j d k s l ──────────────────────────────────────────
	{
		"title": "Урок 3",
		"subtitle": "Домашний ряд: F J D K S L",
		"keys": "F  J  D  K  S  L",
		"allowed": ["f", "j", "d", "k", "s", "l"],
		"description": "Безымянные пальцы: S — левый, L — правый. Не двигай остальные!",
		"words": [
			"sl", "ls", "sf", "lj", "sdf", "lkj", "slk", "fls",
			"dsl", "kjl", "sdfl", "lkjs", "fsdl", "jlks",
			"sldf", "lkjf", "dsfl", "jkls", "sfdk", "ljkd",
			"fsdkl", "jlkds", "sdlkf", "lkjfs", "dslkj"
		],
		"spawn_interval": 3.0,
		"max_enemies": 12,
		"enemy_speed_mult": 0.65,
		"duration": 110.0,
		"hp_mult": 0.85,
	},
	# ── Урок 4: полный home row + a ──────────────────────────────────
	{
		"title": "Урок 4",
		"subtitle": "Полный домашний ряд: A S D F J K L",
		"keys": "A  S  D  F  J  K  L",
		"allowed": ["a", "s", "d", "f", "j", "k", "l"],
		"description": "Мизинец левой руки — A. Полный домашний ряд освоен!",
		"words": [
			"as", "ask", "fad", "lad", "sad", "lass", "fall", "dask",
			"flask", "salad", "flak", "alsk", "flags", "lfads",
			"dfall", "kalfs", "asdfl", "jklsa", "fdask", "ljksa",
			"flask", "adsfl", "salfl", "klasd", "fadsl"
		],
		"spawn_interval": 2.8,
		"max_enemies": 14,
		"enemy_speed_mult": 0.70,
		"duration": 110.0,
		"hp_mult": 0.9,
	},
	# ── Урок 5: + e i ────────────────────────────────────────────────
	{
		"title": "Урок 5",
		"subtitle": "Верхний ряд: E I",
		"keys": "A S D F J K L  +  E I",
		"allowed": ["a", "s", "d", "f", "j", "k", "l", "e", "i"],
		"description": "Средние пальцы вверх: E — левый (над D), I — правый (над K).",
		"words": [
			"idea", "side", "file", "aide", "said", "sail", "fail",
			"deal", "dial", "isle", "idea", "slid", "deli", "idle",
			"field", "ideal", "slide", "aside", "fidelity",
			"fails", "deals", "filed", "aided", "alias",
			"diesel", "inside", "ladies", "detail"
		],
		"spawn_interval": 2.6,
		"max_enemies": 14,
		"enemy_speed_mult": 0.72,
		"duration": 120.0,
		"hp_mult": 0.9,
	},
	# ── Урок 6: + r u ────────────────────────────────────────────────
	{
		"title": "Урок 6",
		"subtitle": "Верхний ряд: R U",
		"keys": "A S D F J K L E I  +  R U",
		"allowed": ["a", "s", "d", "f", "j", "k", "l", "e", "i", "r", "u"],
		"description": "Указательные пальцы вверх: R — левый (над F), U — правый (над J).",
		"words": [
			"rule", "rude", "sure", "lure", "duel", "fuel", "ruse",
			"ride", "rife", "furl", "slur", "druid", "ruler",
			"raise", "rural", "ideal", "fluid", "fired", "tired",
			"skier", "rueful", "feudal", "lurid", "ursula",
			"slide", "figure", "desire", "uries", "flurry"
		],
		"spawn_interval": 2.5,
		"max_enemies": 15,
		"enemy_speed_mult": 0.75,
		"duration": 120.0,
		"hp_mult": 1.0,
	},
	# ── Урок 7: + t y ────────────────────────────────────────────────
	{
		"title": "Урок 7",
		"subtitle": "Верхний ряд: T Y",
		"keys": "A S D F J K L E I R U  +  T Y",
		"allowed": ["a", "s", "d", "f", "j", "k", "l", "e", "i", "r", "u", "t", "y"],
		"description": "Центр верхнего ряда: T — левый указательный, Y — правый указательный.",
		"words": [
			"try", "yet", "stay", "tray", "year", "style", "truly",
			"layer", "ready", "study", "dirty", "rusty", "dusty",
			"trend", "stead", "daily", "trial", "tired", "tears",
			"stray", "ultra", "trust", "yeast", "tasty",
			"starry", "yearly", "steady", "sturdy", "reality"
		],
		"spawn_interval": 2.4,
		"max_enemies": 16,
		"enemy_speed_mult": 0.77,
		"duration": 130.0,
		"hp_mult": 1.0,
	},
	# ── Урок 8: + w o ────────────────────────────────────────────────
	{
		"title": "Урок 8",
		"subtitle": "Верхний ряд: W O",
		"keys": "... + W O",
		"allowed": ["a", "s", "d", "f", "j", "k", "l", "e", "i", "r", "u", "t", "y", "w", "o"],
		"description": "Средние пальцы: W — над S (левый), O — над L (правый).",
		"words": [
			"word", "work", "world", "row", "flow", "glow", "slow",
			"tower", "lower", "power", "sword", "storm", "story",
			"worry", "worth", "wrist", "wrote", "trowel",
			"toward", "worker", "forest", "effort", "roster",
			"software", "workout", "outward", "desktop"
		],
		"spawn_interval": 2.3,
		"max_enemies": 17,
		"enemy_speed_mult": 0.80,
		"duration": 130.0,
		"hp_mult": 1.0,
	},
	# ── Урок 9: + q p ────────────────────────────────────────────────
	{
		"title": "Урок 9",
		"subtitle": "Верхний ряд: Q P",
		"keys": "... + Q P",
		"allowed": ["a", "s", "d", "f", "j", "k", "l", "e", "i", "r", "u", "t", "y", "w", "o", "q", "p"],
		"description": "Мизинцы: Q — левый (над A), P — правый (над L). Растяни пальцы!",
		"words": [
			"stop", "sport", "drip", "trip", "strip", "quip",
			"prowl", "optic", "tulip", "pilot", "depot",
			"squat", "quart", "equity", "potion", "poetry",
			"report", "expert", "effort", "output", "laptop",
			"support", "deposit", "quality", "quartet", "property"
		],
		"spawn_interval": 2.2,
		"max_enemies": 18,
		"enemy_speed_mult": 0.82,
		"duration": 130.0,
		"hp_mult": 1.05,
	},
	# ── Урок 10: + v m (нижний ряд) ──────────────────────────────────
	{
		"title": "Урок 10",
		"subtitle": "Нижний ряд: V M",
		"keys": "... + V M",
		"allowed": ["a", "s", "d", "f", "j", "k", "l", "e", "i", "r", "u", "t", "y", "w", "o", "q", "p", "v", "m"],
		"description": "Указательные вниз: V — левый (под F), M — правый (под J).",
		"words": [
			"move", "mover", "value", "vital", "vivid", "marvel",
			"storm", "mortal", "volume", "market", "mature",
			"vertex", "movies", "remote", "victim", "system",
			"master", "timber", "memory", "summer", "mirror",
			"vampire", "mixture", "improve", "primary", "symptom"
		],
		"spawn_interval": 2.1,
		"max_enemies": 19,
		"enemy_speed_mult": 0.85,
		"duration": 140.0,
		"hp_mult": 1.1,
	},
	# ── Урок 11: + c n ───────────────────────────────────────────────
	{
		"title": "Урок 11",
		"subtitle": "Нижний ряд: C N",
		"keys": "... + C N",
		"allowed": ["a", "s", "d", "f", "j", "k", "l", "e", "i", "r", "u", "t", "y", "w", "o", "q", "p", "v", "m", "c", "n"],
		"description": "Средние пальцы вниз: C — левый (под D), N — правый (под J).",
		"words": [
			"can", "scan", "nice", "mice", "ince", "since", "fence",
			"clinic", "cosmic", "iconic", "mentor", "nation",
			"concert", "concern", "control", "contact", "content",
			"central", "science", "opinion", "context", "concept",
			"contract", "medicine", "currency", "function", "incident"
		],
		"spawn_interval": 2.0,
		"max_enemies": 20,
		"enemy_speed_mult": 0.87,
		"duration": 140.0,
		"hp_mult": 1.1,
	},
	# ── Урок 12: + x b ───────────────────────────────────────────────
	{
		"title": "Урок 12",
		"subtitle": "Нижний ряд: X B",
		"keys": "... + X B",
		"allowed": ["a", "s", "d", "f", "j", "k", "l", "e", "i", "r", "u", "t", "y", "w", "o", "q", "p", "v", "m", "c", "n", "x", "b"],
		"description": "Безымянный вниз: X — левый (под S), B — правый указательный (между V и N).",
		"words": [
			"box", "fox", "flex", "text", "next", "exit", "extra",
			"boxer", "toxic", "exact", "excel", "exert",
			"combat", "submit", "object", "subject", "combine",
			"context", "exhibit", "explore", "express", "extreme",
			"exciting", "exchange", "excellent", "existence"
		],
		"spawn_interval": 1.9,
		"max_enemies": 21,
		"enemy_speed_mult": 0.90,
		"duration": 140.0,
		"hp_mult": 1.15,
	},
	# ── Урок 13: + z g h ──────────────────────────────────────────────
	{
		"title": "Урок 13",
		"subtitle": "Нижний ряд: Z + G H",
		"keys": "... + Z G H",
		"allowed": ["a", "s", "d", "f", "j", "k", "l", "e", "i", "r", "u", "t", "y", "w", "o", "q", "p", "v", "m", "c", "n", "x", "b", "z", "g", "h"],
		"description": "Мизинец вниз: Z (под A). Плюс G — левый указательный (рядом с F), H — правый (рядом с J).",
		"words": [
			"zone", "zero", "gaze", "haze", "graze", "glaze",
			"ghost", "zoning", "hazard", "zenith", "bizarre",
			"height", "growth", "gather", "health", "breath",
			"hunger", "garden", "gather", "handle", "hunger",
			"grizzly", "weather", "heather", "together", "although"
		],
		"spawn_interval": 1.8,
		"max_enemies": 22,
		"enemy_speed_mult": 0.92,
		"duration": 150.0,
		"hp_mult": 1.2,
	},
	# ── Урок 14: ФИНАЛ — весь алфавит ────────────────────────────────
	{
		"title": "Урок 14",
		"subtitle": "ФИНАЛ: Весь алфавит",
		"keys": "Все клавиши",
		"allowed": ["a","b","c","d","e","f","g","h","i","j","k","l","m",
					"n","o","p","q","r","s","t","u","v","w","x","y","z"],
		"description": "Ты освоил все клавиши. Теперь докажи мастерство!",
		"words": [
			"quick", "brown", "jumps", "sphinx", "waltz", "fjord",
			"blitz", "proxy", "glyph", "vex", "jinx", "quiz",
			"complex", "quantum", "wizard", "zombie", "oxygen",
			"python", "jungle", "whiskey", "triumph", "boycott",
			"symptom", "develop", "example", "kingdom", "mixture",
			"network", "obscure", "perfect", "require", "station",
			"thunder", "uniform", "venture", "warning", "extreme",
			"younger", "zealous", "absolute", "boundary", "champion"
		],
		"spawn_interval": 1.5,
		"max_enemies": 25,
		"enemy_speed_mult": 1.0,
		"duration": 180.0,
		"hp_mult": 1.3,
	},
]

# ─────────────────────────────────────────
# МЕТОДЫ
# ─────────────────────────────────────────

func get_lesson_count() -> int:
	return LESSONS.size()


func get_lesson(index: int) -> Dictionary:
	if index < 0 or index >= LESSONS.size():
		return LESSONS[LESSONS.size() - 1]
	return LESSONS[index]


func get_current_lesson() -> Dictionary:
	return get_lesson(current_lesson)


func set_lesson(index: int) -> void:
	current_lesson = clamp(index, 0, LESSONS.size() - 1)
	emit_signal("lesson_changed", current_lesson, get_current_lesson())


func get_word_for_lesson(lesson_index: int) -> String:
	var lesson := get_lesson(lesson_index)
	var words: Array = lesson["words"]
	return words.pick_random()


func get_keys_display(lesson_index: int) -> String:
	return get_lesson(lesson_index)["keys"]


func get_allowed_letters(lesson_index: int) -> Array:
	return get_lesson(lesson_index)["allowed"]


# Проверяет, является ли слово допустимым для данного урока
func is_word_valid_for_lesson(word: String, lesson_index: int) -> bool:
	var allowed := get_allowed_letters(lesson_index)
	for ch in word.to_lower():
		if ch not in allowed:
			return false
	return true


# Загрузка прогресса (сохранённый номер урока)
const SAVE_PATH := "user://typing_progress.json"

func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		current_lesson = 0
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if data is Dictionary and data.has("lesson"):
		current_lesson = clamp(int(data["lesson"]), 0, LESSONS.size() - 1)


func save_progress() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"lesson": current_lesson}))
		f.close()


func advance_lesson() -> void:
	if current_lesson < LESSONS.size() - 1:
		current_lesson += 1
		save_progress()
