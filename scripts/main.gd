extends Node2D

# ==========================================
# ГЛАВНАЯ СЦЕНА (Main.tscn)
#
# Три режима:
#   1. Обычная игра                  (lesson_lang == "")
#   2. Обучение английской печати    (lesson_lang == "en")
#   3. Обучение русской печати       (lesson_lang == "ru")
#
# Экран выбора:
#   ┌─ LessonSelectScreen ──────────────────────────────────┐
#   │  [🇬🇧 English (QWERTY)]   [🇷🇺 Русский (ЙЦУКЕН)]       │
#   │  [Обычная игра]                                        │
#   │  ─── Список уроков выбранного языка ───               │
#   └───────────────────────────────────────────────────────┘
#
# Структура новых узлов в Main.tscn (добавить вручную):
#
# ── LessonHUD : CanvasLayer ──────────────────────────────────────────────────
#   LessonHUD/LessonPanel/LessonLabel   Label — "EN 3 · Home row: …"
#   LessonHUD/KeysPanel/KeysLabel       Label — "[ F · J · D · K ]"
#   LessonHUD/StatsPanel/AccLabel       Label — "Точность: 100%"
#   LessonHUD/StatsPanel/WpmLabel       Label — "Слов: 0"
#
# ── LessonSelectScreen : CanvasLayer ─────────────────────────────────────────
#   .../Panel/VBox/TitleLabel           Label  — "Режим обучения"
#   .../Panel/VBox/LangRow/EnBtn        Button — "🇬🇧 English"
#   .../Panel/VBox/LangRow/RuBtn        Button — "🇷🇺 Русский"
#   .../Panel/VBox/LessonScroll/LessonList  VBoxContainer — заполняется кодом
#   .../Panel/VBox/NormalBtn            Button — "⚔ Обычная игра"
#
# ── LessonResultScreen : CanvasLayer ─────────────────────────────────────────
#   .../Panel/VBox/TitleLabel           Label
#   .../Panel/VBox/ResultLabel          Label
#   .../Panel/VBox/NextBtn              Button — "→ Следующий урок"
#   .../Panel/VBox/RetryBtn             Button — "↺ Повторить"
#   .../Panel/VBox/MenuBtn              Button — "↩ В меню уроков"
# ==========================================

@onready var player: CharacterBody2D       = $Player
@onready var enemy_manager: Node2D         = $EnemyManager
@onready var upgrade_menu: CanvasLayer     = $UpgradeMenu
@onready var camera: Camera2D             = $Player/Camera2D

# ── Стандартный HUD ────────────────────────────────────────────────────────────
@onready var score_label: Label = $GameOverScreen/Panel/VBox/ScoreRow/ScoreLabel
@onready var timer_label: Label = $HUD/TimerPanel/HBox/TimerLabel

# ── HUD урока ──────────────────────────────────────────────────────────────────
@onready var lesson_hud: CanvasLayer = $LessonHUD
@onready var lesson_label: Label     = $LessonHUD/LessonPanel/LessonLabel
@onready var keys_label: Label       = $LessonHUD/KeysPanel/KeysLabel
@onready var acc_label: Label        = $LessonHUD/StatsPanel/VBox/AccLabel
@onready var wpm_label: Label        = $LessonHUD/StatsPanel/VBox/WpmLabel

# ── Экран выбора урока ─────────────────────────────────────────────────────────
@onready var lesson_select_screen: CanvasLayer = $LessonSelectScreen
@onready var lesson_list_box: VBoxContainer    = $LessonSelectScreen/Panel/VBox/ScrollContainer/LessonList
@onready var en_btn: Button  = $LessonSelectScreen/Panel/VBox/LangRow/EnBtn
@onready var ru_btn: Button  = $LessonSelectScreen/Panel/VBox/LangRow/RuBtn
# ── Экран результата урока ─────────────────────────────────────────────────────
@onready var lesson_result_screen: CanvasLayer = $LessonResultScreen
@onready var result_title: Label               = $LessonResultScreen/Panel/VBox/TitleLabel
@onready var result_label: Label               = $LessonResultScreen/Panel/VBox/ResultLabel

# ── Обычные экраны победы / поражения ─────────────────────────────────────────
@onready var win_screen: CanvasLayer       = $WinScreen
@onready var win_score_label: Label        = $WinScreen/Panel/VBox/ScoreRow/ScoreLabel
@onready var win_leader_label: Label       = $WinScreen/Panel/VBox/LeaderLabel
@onready var game_over_screen: CanvasLayer = $GameOverScreen
@onready var go_score_label: Label         = $GameOverScreen/Panel/VBox/ScoreRow/ScoreLabel
@onready var go_leader_label: Label        = $GameOverScreen/Panel/VBox/LeaderLabel

# ── Константы ──────────────────────────────────────────────────────────────────
const GAME_DURATION    := 120.0
const LEADERBOARD_PATH := "user://leaderboard.json"
const MAX_RECORDS      := 10

# ── Состояние ──────────────────────────────────────────────────────────────────
var score: int          = 0
var time_elapsed: float = 0.0
var game_active: bool   = false

# Обучение
var lesson_lang: String    = "en"   # выбранный язык в меню
var lesson_index: int      = 0
var lesson_duration: float = 90.0

# Статистика урока
var words_typed: int   = 0
var errors_made: int   = 0
var correct_letters: int = 0


func _ready() -> void:
	add_to_group("main_scene")
	_setup_background()
	upgrade_menu.player = player

	player.leveled_up.connect(_on_player_leveled_up)
	player.died.connect(_on_player_died)
	enemy_manager.enemy_killed.connect(_on_enemy_killed)

	TypingLessonManager.load_progress()

	# Скрываем всё
	win_screen.visible           = false
	game_over_screen.visible     = false
	lesson_hud.visible           = false
	lesson_result_screen.visible = false
	upgrade_menu.visible         = false

	# Подключаем кнопки языка
	if en_btn:
		en_btn.pressed.connect(func(): _select_lang("en"))
	if ru_btn:
		ru_btn.pressed.connect(func(): _select_lang("ru"))

	# Кнопка обычной игры
	var normal_btn := lesson_select_screen.get_node_or_null("Panel/VBox/NormalBtn")
	if normal_btn:
		normal_btn.pressed.connect(_start_normal_game)

	# Кнопки результата
	_connect_result_buttons()

	# Показываем экран выбора с последним языком
	_rebuild_lesson_list()
	lesson_select_screen.visible = true
	get_tree().paused = true


# ─────────────────────────────────────────
# ВЫБОР ЯЗЫКА
# ─────────────────────────────────────────
func _select_lang(lang: String) -> void:
	lesson_lang = lang
	_rebuild_lesson_list()
	# Подсвечиваем активную кнопку
	if en_btn: en_btn.add_theme_color_override("font_color",
		Color(1.0, 0.9, 0.3) if lang == "en" else Color(0.8, 0.85, 1.0))
	if ru_btn: ru_btn.add_theme_color_override("font_color",
		Color(1.0, 0.9, 0.3) if lang == "ru" else Color(0.8, 0.85, 1.0))


func _rebuild_lesson_list() -> void:
	# Очищаем старые кнопки
	for child in lesson_list_box.get_children():
		child.queue_free()

	var count   = TypingLessonManager.get_lesson_count(lesson_lang)
	var current = TypingLessonManager.get_current_index(lesson_lang)

	for i in range(count):
		var lesson = TypingLessonManager.get_lesson(lesson_lang, i)
		var btn    := Button.new()

		var star := "★ " if i == current else "  "
		# Формат: "★ EN 3 · Home row: S D F J K L  [S·D·F·J·K·L]"
		btn.text = "%s%s · %s" % [star, lesson["title"], lesson["subtitle"]] #lesson["keys"]]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_color_override("font_color",
			Color(1.0, 0.9, 0.3) if i == current else Color(0.8, 0.85, 1.0))

		var idx := i
		btn.pressed.connect(func(): _start_typing_lesson(lesson_lang, idx))
		lesson_list_box.add_child(btn)


# ─────────────────────────────────────────
# СТАРТ УРОКА
# ─────────────────────────────────────────
func _start_typing_lesson(p_lang: String, p_lesson_index: int) -> void:
	lesson_lang  = p_lang
	lesson_index = p_lesson_index
	TypingLessonManager.set_lesson(p_lang, p_lesson_index)

	var lesson     = TypingLessonManager.get_current_lesson(p_lang)
	lesson_duration = lesson.get("duration", 90.0)

	# Сброс статистики
	words_typed     = 0
	errors_made     = 0
	correct_letters = 0
	time_elapsed    = 0.0
	score           = 0

	# Передаём язык игроку
	player.lesson_lang = p_lang

	# Отключаем апгрейды
	upgrade_menu.visible      = false
	upgrade_menu.process_mode = Node.PROCESS_MODE_DISABLED

	# Активируем EnemyManager
	enemy_manager.activate_typing_mode(p_lang, p_lesson_index)

	# Подключаем статистику (с защитой от двойного подключения)
	if not player.word_completed.is_connected(_on_word_completed):
		player.word_completed.connect(_on_word_completed)
	if not player.letter_error.is_connected(_on_letter_error):
		player.letter_error.connect(_on_letter_error)
	if not player.letter_correct.is_connected(_on_letter_correct):
		player.letter_correct.connect(_on_letter_correct)

	lesson_select_screen.visible = false
	get_tree().paused = false

	# Показываем HUD урока
	lesson_hud.visible    = true
	lesson_label.text     = "%s · %s" % [lesson["title"], lesson["subtitle"]]
	keys_label.text       = "[ %s ]" % lesson["keys"]
	_update_lesson_stats()

	game_active = true


# ─────────────────────────────────────────
# СТАРТ ОБЫЧНОЙ ИГРЫ
# ─────────────────────────────────────────
func _start_normal_game() -> void:
	player.lesson_lang = ""

	upgrade_menu.visible      = false
	upgrade_menu.process_mode = Node.PROCESS_MODE_INHERIT
	upgrade_menu.player       = player
	lesson_hud.visible        = false

	score        = 0
	time_elapsed = 0.0
	lesson_lang  = ""

	lesson_select_screen.visible = false
	get_tree().paused = false

	game_active = true
	_update_hud()


# ─────────────────────────────────────────
# PROCESS
# ─────────────────────────────────────────
func _process(delta: float) -> void:
	if not game_active:
		if lesson_lang == "":   # обычный режим — Enter перезапускает
			if Input.is_action_just_pressed("ui_accept"):
				get_tree().reload_current_scene()
		return

	time_elapsed += delta

	if lesson_lang != "":
		var remaining = max(0.0, lesson_duration - time_elapsed)
		_update_timer_label(remaining)
		if time_elapsed >= lesson_duration:
			_finish_lesson(true)
	else:
		var remaining = max(0.0, GAME_DURATION - time_elapsed)
		_update_timer_label(remaining)
		if time_elapsed >= GAME_DURATION:
			_win()


# ─────────────────────────────────────────
# HUD (обычный режим)
# ─────────────────────────────────────────
func _update_hud() -> void:
	score_label.text = "Очки: %d" % score
	_update_timer_label(GAME_DURATION)


func _update_timer_label(remaining: float) -> void:
	var mins := int(remaining) / 60
	var secs := int(remaining) % 60
	timer_label.text = "Время: %02d:%02d" % [mins, secs]


# ─────────────────────────────────────────
# HUD УРОКА
# ─────────────────────────────────────────
func _update_lesson_stats() -> void:
	if not lesson_hud.visible:
		return
	var total := correct_letters + errors_made
	var accuracy := 100 if total == 0 else int(float(correct_letters) / float(total) * 100.0)
	if acc_label: acc_label.text = "Точность: %d%%" % accuracy
	if wpm_label: wpm_label.text = "Слов: %d"       % words_typed


# ─────────────────────────────────────────
# ОЧКИ
# ─────────────────────────────────────────
func _on_enemy_killed(points: int) -> void:
	score += points
	if lesson_lang == "":
		score_label.text = "Очки: %d" % score


func add_score(points: int) -> void:
	score += points
	if lesson_lang == "":
		score_label.text = "Очки: %d" % score


# ─────────────────────────────────────────
# СТАТИСТИКА УРОКА
# ─────────────────────────────────────────
func _on_word_completed() -> void:
	words_typed += 1
	_update_lesson_stats()


func _on_letter_error() -> void:
	errors_made += 1
	_update_lesson_stats()


func _on_letter_correct() -> void:
	correct_letters += 1
	_update_lesson_stats()


# ─────────────────────────────────────────
# ЗАВЕРШЕНИЕ УРОКА
# ─────────────────────────────────────────
func _finish_lesson(survived: bool) -> void:
	if not game_active:
		return
	game_active = false
	get_tree().paused = true

	var total    := correct_letters + errors_made
	var accuracy := 100 if total == 0 else int(float(correct_letters) / float(total) * 100.0)
	var passed   := survived and accuracy >= 70

	var lesson := TypingLessonManager.get_current_lesson(lesson_lang)

	if passed:
		result_title.text = "✓ УРОК ПРОЙДЕН!"
		result_title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		TypingLessonManager.advance_lesson(lesson_lang)
	else:
		result_title.text = "✗ ПОПРОБУЙ ЕЩЁ"
		result_title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))

	var lang_name := "English (QWERTY)" if lesson_lang == "en" else "Русский (ЙЦУКЕН)"
	var next_lesson := TypingLessonManager.get_current_lesson(lesson_lang)

	result_label.text = (
		"%s — %s\n\n" % [lesson["title"], lesson["subtitle"]] +
		"Язык: %s\n" % lang_name +
		"Слов напечатано: %d\n" % words_typed +
		"Точность: %d%%\n" % accuracy +
		"Ошибок: %d\n" % errors_made +
		("\n→ Открыт: %s · %s" % [next_lesson["title"], next_lesson["subtitle"]] if passed else "")
	)

	lesson_result_screen.visible = true


# ─────────────────────────────────────────
# КНОПКИ РЕЗУЛЬТАТА
# ─────────────────────────────────────────
func _connect_result_buttons() -> void:
	var next_btn  := lesson_result_screen.get_node_or_null("Panel/VBox/BtnRow/NextBtn")
	var retry_btn := lesson_result_screen.get_node_or_null("$Panel/VBox/BtnRow/RetryBtn")
	var menu_btn  := lesson_result_screen.get_node_or_null("Panel/VBox/BtnRow/MenuBtn")

	if next_btn:
		next_btn.pressed.connect(func():
			# Запускаем следующий урок того же языка
			var next_idx := TypingLessonManager.get_current_index(lesson_lang)
			get_tree().paused = false
			lesson_result_screen.visible = false
			_start_typing_lesson(lesson_lang, next_idx)
		)
	if retry_btn:
		retry_btn.pressed.connect(func():
			get_tree().paused = false
			lesson_result_screen.visible = false
			_start_typing_lesson(lesson_lang, lesson_index)
		)
	if menu_btn:
		menu_btn.pressed.connect(func():
			get_tree().reload_current_scene()
		)


# ─────────────────────────────────────────
# ПОБЕДА (обычный режим)
# ─────────────────────────────────────────
func _win() -> void:
	if not game_active:
		return
	game_active = false
	get_tree().paused = true
	_save_score(score, true)
	win_score_label.text  = "Ваш счёт: %d" % score
	win_leader_label.text = _build_leaderboard_text()
	win_screen.visible    = true


# ─────────────────────────────────────────
# ПОРАЖЕНИЕ
# ─────────────────────────────────────────
func _on_player_died() -> void:
	if not game_active:
		return
	game_active = false
	get_tree().paused = true

	if lesson_lang != "":
		_finish_lesson(false)
	else:
		_save_score(score, false)
		go_score_label.text   = "Ваш счёт: %d" % score
		go_leader_label.text  = _build_leaderboard_text()
		game_over_screen.visible = true


# ─────────────────────────────────────────
# ПОВЫШЕНИЕ УРОВНЯ
# ─────────────────────────────────────────
func _on_player_leveled_up(new_level: int) -> void:
	enemy_manager.increase_difficulty()
	if lesson_lang == "":
		upgrade_menu.show_upgrade_menu(new_level)


# ─────────────────────────────────────────
# ТАБЛИЦА РЕКОРДОВ
# ─────────────────────────────────────────
func _load_leaderboard() -> Array:
	if not FileAccess.file_exists(LEADERBOARD_PATH):
		return []
	var f := FileAccess.open(LEADERBOARD_PATH, FileAccess.READ)
	if f == null:
		return []
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if parsed is Array:
		return parsed
	return []


func _save_score(new_score: int, won: bool) -> void:
	var records: Array = _load_leaderboard()
	records.append({"score": new_score, "won": won, "time": int(time_elapsed)})
	records.sort_custom(func(a, b): return a["score"] > b["score"])
	if records.size() > MAX_RECORDS:
		records.resize(MAX_RECORDS)
	var f := FileAccess.open(LEADERBOARD_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(records, "\t"))
		f.close()


func _build_leaderboard_text() -> String:
	var records: Array = _load_leaderboard()
	if records.is_empty():
		return "Таблица рекордов пуста"
	var text := "── Таблица рекордов ──\n"
	for i in range(records.size()):
		var r = records[i]
		var mins := int(r["time"]) / 60
		var secs := int(r["time"]) % 60
		var result := "Победа" if r["won"] else "Поражение"
		text += "%d. %d очков  [%s]  %02d:%02d\n" % [i + 1, r["score"], result, mins, secs]
	return text


# ─────────────────────────────────────────
# ФОН
# ─────────────────────────────────────────
func _setup_background() -> void:
	var bg_texture: Texture2D = load("res://pixel_assets/background/one_background_tile.png")
	if bg_texture == null:
		push_error("Main: не удалось загрузить фон")
		return

	var old_bg := get_node_or_null("Background")
	if old_bg:
		old_bg.queue_free()

	var parallax := Parallax2D.new()
	parallax.name    = "ParallaxBackground"
	parallax.z_index = -10
	add_child(parallax)
	move_child(parallax, 0)

	var layer := Parallax2D.new()
	layer.repeat_times = 30
	layer.repeat_size  = Vector2(bg_texture.get_width() * 6, bg_texture.get_height() * 6)
	parallax.add_child(layer)

	var sprite := Sprite2D.new()
	sprite.texture  = bg_texture
	sprite.centered = false
	sprite.scale    = Vector2(6, 6)
	layer.add_child(sprite)
