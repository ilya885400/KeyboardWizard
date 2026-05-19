extends Node2D

# ==========================================
# ГЛАВНАЯ СЦЕНА (Main.tscn)
# Поддерживает два режима:
#   - Обычная игра (original gameplay)
#   - Обучение слепой печати (typing_mode)
#
# РЕЖИМ ОБУЧЕНИЯ активируется через экран выбора урока.
# В режиме обучения:
#   • Улучшения (upgrade_menu) отключены.
#   • HUD показывает клавиши текущего урока.
#   • Таймер берётся из параметров урока.
#   • По завершении показывается экран результатов урока.
# ==========================================

@onready var player: CharacterBody2D           = $Player
@onready var enemy_manager: Node2D             = $EnemyManager
@onready var upgrade_menu: CanvasLayer         = $UpgradeMenu
@onready var camera: Camera2D                  = $Player/Camera2D

# ── Стандартный HUD ────────────────────────────────────────────────────────────
@onready var score_label: Label = $HUD/ScorePanel/ScoreLabel
@onready var timer_label: Label = $HUD/TimerPanel/TimerLabel

# ── HUD обучения (добавь в Main.tscn узел $LessonHUD) ─────────────────────────
# LessonHUD/LessonPanel/LessonLabel   — Label "Урок X: название"
# LessonHUD/KeysPanel/KeysLabel       — Label с показом клавиш
# LessonHUD/StatsPanel/AccLabel       — Label "Точность: 100%"
# LessonHUD/StatsPanel/WpmLabel       — Label "Слов: 0"
@onready var lesson_hud: CanvasLayer   = $LessonHUD
@onready var lesson_label: Label       = $LessonHUD/LessonPanel/LessonLabel
@onready var keys_label: Label         = $LessonHUD/KeysPanel/KeysLabel
@onready var acc_label: Label          = $LessonHUD/StatsPanel/AccLabel
@onready var wpm_label: Label          = $LessonHUD/StatsPanel/WpmLabel

# ── Экран выбора урока ─────────────────────────────────────────────────────────
# LessonSelectScreen/Panel/VBox/TitleLabel      — "Выбери урок"
# LessonSelectScreen/Panel/VBox/LessonList      — VBoxContainer со строками уроков
# LessonSelectScreen/Panel/VBox/NormalBtn       — Button "Обычная игра"
# LessonSelectScreen/Panel/VBox/HintLabel       — подсказка
@onready var lesson_select_screen: CanvasLayer = $LessonSelectScreen
@onready var lesson_list_box: VBoxContainer    = $LessonSelectScreen/Panel/VBox/LessonList

# ── Экран результатов урока ───────────────────────────────────────────────────
# LessonResultScreen/Panel/VBox/TitleLabel
# LessonResultScreen/Panel/VBox/ResultLabel
# LessonResultScreen/Panel/VBox/NextBtn  (Button "→ Следующий урок")
# LessonResultScreen/Panel/VBox/RetryBtn (Button "↺ Повторить")
# LessonResultScreen/Panel/VBox/MenuBtn  (Button "↩ В меню уроков")
@onready var lesson_result_screen: CanvasLayer = $LessonResultScreen
@onready var result_label: Label               = $LessonResultScreen/Panel/VBox/ResultLabel
@onready var result_title: Label               = $LessonResultScreen/Panel/VBox/TitleLabel

# ── Экраны победы / поражения (обычный режим) ─────────────────────────────────
@onready var win_screen: CanvasLayer           = $WinScreen
@onready var win_score_label: Label            = $WinScreen/Panel/VBox/ScoreLabel
@onready var win_leader_label: Label           = $WinScreen/Panel/VBox/LeaderLabel

@onready var game_over_screen: CanvasLayer     = $GameOverScreen
@onready var go_score_label: Label             = $GameOverScreen/Panel/VBox/ScoreLabel
@onready var go_leader_label: Label            = $GameOverScreen/Panel/VBox/LeaderLabel

# ── Данные обычного режима ────────────────────────────────────────────────────
const GAME_DURATION    := 120.0
const LEADERBOARD_PATH := "user://leaderboard.json"
const MAX_RECORDS      := 10

var score: int          = 0
var time_elapsed: float = 0.0
var game_active: bool   = false   # становится true после выбора режима

# ── Данные режима обучения ────────────────────────────────────────────────────
var typing_mode: bool   = false
var lesson_duration: float = 90.0

# Статистика урока
var words_typed: int    = 0
var errors_made: int    = 0
var total_letters: int  = 0      # суммарно нажатых правильных букв
var lesson_started: bool = false


func _ready() -> void:
	add_to_group("main_scene")
	_setup_background()

	player.leveled_up.connect(_on_player_leveled_up)
	player.died.connect(_on_player_died)
	enemy_manager.enemy_killed.connect(_on_enemy_killed)

	# Загружаем прогресс уроков
	TypingLessonManager.load_progress()

	# Скрываем все экраны
	win_screen.visible           = false
	game_over_screen.visible     = false
	lesson_hud.visible           = false
	lesson_result_screen.visible = false
	upgrade_menu.visible         = false

	# Подключаем кнопки результата урока (если уже присутствуют)
	_connect_result_buttons()

	# Показываем экран выбора урока
	_show_lesson_select()


# ─────────────────────────────────────────
# ЭКРАН ВЫБОРА УРОКА
# ─────────────────────────────────────────
func _show_lesson_select() -> void:
	get_tree().paused = true
	lesson_select_screen.visible = true
	game_active = false

	# Чистим список и заполняем заново
	for child in lesson_list_box.get_children():
		child.queue_free()

	var count := TypingLessonManager.get_lesson_count()
	var current := TypingLessonManager.current_lesson

	for i in range(count):
		var lesson := TypingLessonManager.get_lesson(i)
		var btn := Button.new()
		var marker := "★ " if i == current else "  "
		btn.text = "%s%s: %s  [%s]" % [marker, lesson["title"], lesson["subtitle"], lesson["keys"]]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		# Стиль кнопок: текущий урок выделен
		if i == current:
			btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		else:
			btn.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))

		var idx := i   # захват переменной
		btn.pressed.connect(func(): _start_typing_lesson(idx))
		lesson_list_box.add_child(btn)

	# Кнопка обычного режима
	var normal_btn := lesson_list_box.get_parent().get_node_or_null("NormalBtn")
	if normal_btn:
		normal_btn.pressed.connect(_start_normal_game)


func _hide_lesson_select() -> void:
	lesson_select_screen.visible = false
	get_tree().paused = false


# ─────────────────────────────────────────
# СТАРТ РЕЖИМА ОБУЧЕНИЯ
# ─────────────────────────────────────────
func _start_typing_lesson(p_lesson_index: int) -> void:
	typing_mode  = true
	TypingLessonManager.set_lesson(p_lesson_index)

	var lesson := TypingLessonManager.get_current_lesson()
	lesson_duration = lesson.get("duration", 90.0)

	# Сбрасываем статистику
	words_typed   = 0
	errors_made   = 0
	total_letters = 0
	time_elapsed  = 0.0

	# Отключаем апгрейды
	upgrade_menu.visible = false
	upgrade_menu.process_mode = Node.PROCESS_MODE_DISABLED

	# Сообщаем EnemyManager о режиме обучения
	enemy_manager.activate_typing_mode(p_lesson_index)

	# Подключаем сигналы статистики игрока
	if not player.word_completed.is_connected(_on_word_completed):
		player.word_completed.connect(_on_word_completed)
	if not player.letter_error.is_connected(_on_letter_error):
		player.letter_error.connect(_on_letter_error)

	_hide_lesson_select()
	_show_lesson_hud(lesson)

	game_active      = true
	lesson_started   = true
	upgrade_menu.player = player   # на всякий случай


# ─────────────────────────────────────────
# СТАРТ ОБЫЧНОГО РЕЖИМА
# ─────────────────────────────────────────
func _start_normal_game() -> void:
	typing_mode = false
	_hide_lesson_select()

	upgrade_menu.visible      = true
	upgrade_menu.process_mode = Node.PROCESS_MODE_INHERIT
	upgrade_menu.player       = player
	lesson_hud.visible        = false

	score        = 0
	time_elapsed = 0.0
	game_active  = true
	_update_hud()


# ─────────────────────────────────────────
# HUD ОБУЧЕНИЯ
# ─────────────────────────────────────────
func _show_lesson_hud(lesson: Dictionary) -> void:
	lesson_hud.visible  = true
	lesson_label.text   = "%s: %s" % [lesson["title"], lesson["subtitle"]]
	keys_label.text     = "[ %s ]" % lesson["keys"]
	_update_lesson_stats()


func _update_lesson_stats() -> void:
	if not lesson_hud.visible:
		return
	var accuracy := 100
	if total_letters + errors_made > 0:
		accuracy = int(float(total_letters) / float(total_letters + errors_made) * 100.0)
	if acc_label:
		acc_label.text = "Точность: %d%%" % accuracy
	if wpm_label:
		wpm_label.text = "Слов: %d" % words_typed


# ─────────────────────────────────────────
# PROCESS
# ─────────────────────────────────────────
func _process(delta: float) -> void:
	if not game_active:
		if not typing_mode:
			if Input.is_action_just_pressed("ui_accept"):
				get_tree().reload_current_scene()
		return

	time_elapsed += delta

	if typing_mode:
		# Таймер урока
		var remaining = max(0.0, lesson_duration - time_elapsed)
		_update_timer_label(remaining)
		if time_elapsed >= lesson_duration:
			_finish_lesson(true)   # победа — дожили до конца
	else:
		# Обычный режим
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
# ОЧКИ
# ─────────────────────────────────────────
func _on_enemy_killed(points: int) -> void:
	score += points
	if not typing_mode:
		score_label.text = "Очки: %d" % score


func add_score(points: int) -> void:
	score += points
	if not typing_mode:
		score_label.text = "Очки: %d" % score


# ─────────────────────────────────────────
# СТАТИСТИКА УРОКА (сигналы от player.gd)
# ─────────────────────────────────────────
func _on_word_completed() -> void:
	words_typed  += 1
	_update_lesson_stats()


func _on_letter_error() -> void:
	errors_made  += 1
	_update_lesson_stats()


func _on_letter_correct() -> void:
	total_letters += 1
	_update_lesson_stats()


# ─────────────────────────────────────────
# ЗАВЕРШЕНИЕ УРОКА
# ─────────────────────────────────────────
func _finish_lesson(survived: bool) -> void:
	if not game_active:
		return
	game_active = false
	get_tree().paused = true

	var accuracy := 100
	if total_letters + errors_made > 0:
		accuracy = int(float(total_letters) / float(total_letters + errors_made) * 100.0)

	var lesson := TypingLessonManager.get_current_lesson()
	var passed := survived and accuracy >= 70

	if passed:
		result_title.text = "✓ УРОК ПРОЙДЕН!"
		result_title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		TypingLessonManager.advance_lesson()
	else:
		result_title.text = "✗ ПОПРОБУЙ ЕЩЁ"
		result_title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))

	result_label.text = (
		"%s\n\n" % lesson["title"] +
		"Слов напечатано: %d\n" % words_typed +
		"Точность: %d%%\n" % accuracy +
		"Ошибок: %d\n\n" % errors_made +
		("Урок разблокирован: %s" % TypingLessonManager.get_lesson(TypingLessonManager.current_lesson)["title"]
			if passed and TypingLessonManager.current_lesson > 0
			else "")
	)

	lesson_result_screen.visible = true


# ─────────────────────────────────────────
# КНОПКИ РЕЗУЛЬТАТА УРОКА
# ─────────────────────────────────────────
func _connect_result_buttons() -> void:
	var next_btn  := lesson_result_screen.get_node_or_null("Panel/VBox/NextBtn")
	var retry_btn := lesson_result_screen.get_node_or_null("Panel/VBox/RetryBtn")
	var menu_btn  := lesson_result_screen.get_node_or_null("Panel/VBox/MenuBtn")

	if next_btn:
		next_btn.pressed.connect(_on_next_lesson_pressed)
	if retry_btn:
		retry_btn.pressed.connect(_on_retry_lesson_pressed)
	if menu_btn:
		menu_btn.pressed.connect(_on_menu_pressed)


func _on_next_lesson_pressed() -> void:
	get_tree().reload_current_scene()


func _on_retry_lesson_pressed() -> void:
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().reload_current_scene()


# ─────────────────────────────────────────
# ПОБЕДА (обычный режим)
# ─────────────────────────────────────────
func _win() -> void:
	if not game_active:
		return
	game_active = false
	get_tree().paused = true
	_save_score(score, true)
	win_score_label.text   = "Ваш счёт: %d" % score
	win_leader_label.text  = _build_leaderboard_text()
	win_screen.visible     = true


# ─────────────────────────────────────────
# ПОРАЖЕНИЕ
# ─────────────────────────────────────────
func _on_player_died() -> void:
	if not game_active:
		return
	game_active = false
	get_tree().paused = true

	if typing_mode:
		_finish_lesson(false)
	else:
		_save_score(score, false)
		go_score_label.text   = "Ваш счёт: %d" % score
		go_leader_label.text  = _build_leaderboard_text()
		game_over_screen.visible = true


# ─────────────────────────────────────────
# ПОВЫШЕНИЕ УРОВНЯ (обычный режим)
# ─────────────────────────────────────────
func _on_player_leveled_up(new_level: int) -> void:
	if typing_mode:
		# В режиме обучения апгрейды не показываем — просто усложняем
		enemy_manager.increase_difficulty()
		return
	enemy_manager.increase_difficulty()
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
	records.append({
		"score": new_score,
		"won": won,
		"time": int(time_elapsed)
	})
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
