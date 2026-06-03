extends Node2D

# ==========================================
# ГЛАВНАЯ СЦЕНА (Main.tscn)
# ==========================================

# Прелоад сцены паузы для интеграции с pause_menu.gd
const PAUSE_MENU_SCENE  := preload("res://scenes/PauseMenu.tscn")
const MAIN_MENU_SCENE_PATH := "res://scenes/MainMenu.tscn"

@onready var player: CharacterBody2D       = $Player
@onready var enemy_manager: Node2D         = $EnemyManager
@onready var upgrade_menu: CanvasLayer     = $UpgradeMenu
@onready var camera: Camera2D              = $Player/Camera2D

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
@onready var keyboard_diagram: Control         = $LessonResultScreen/Panel/VBox/KeyboardDiagram

# ── Обычные экраны победы / поражения ─────────────────────────────────────────
@onready var win_screen: CanvasLayer       = $WinScreen
@onready var win_score_label: Label        = $WinScreen/Panel/VBox/ScoreRow/ScoreLabel
@onready var win_leader_label: Label       = $WinScreen/Panel/VBox/LeaderLabel
@onready var game_over_screen: CanvasLayer = $GameOverScreen
@onready var go_score_label: Label         = $GameOverScreen/Panel/VBox/ScoreRow/ScoreLabel
@onready var go_leader_label: Label        = $GameOverScreen/Panel/VBox/LeaderLabel

# ── Магазин мета-прогрессии ───────────────────────────────────────────────────
@onready var meta_shop: CanvasLayer = $MetaShop

# ── HUD монеты ────────────────────────────────────────────────────────────────
@onready var currency_hud_label: Label = $HUD/CurrencyPanel/HBox/CurrencyLabel

@onready var sfx_attack = $AudioManager/SFX_Cast
@onready var sfx_player_death = $AudioManager/SFX_PlayerDeath
@onready var sfx_enemy_death = $AudioManager/SFX_PlayerDeath
@onready var sfx_enemy_take_damage = $AudioManager/EnemyTakeDamage
@onready var sfx_player_take_damage = $AudioManager/PlayerTakeDamage

# ── Константы ──────────────────────────────────────────────────────────────────
const GAME_DURATION    := 120.0
const LEADERBOARD_PATH := "user://leaderboard_v2.json" 
const MAX_RECORDS      := 10

# ── Состояние ──────────────────────────────────────────────────────────────────
var score: int          = 0   
var time_elapsed: float = 0.0
var game_active: bool   = false
var is_endless: bool    = false 

# Флаг воскрешения 
var _revived_this_run: bool = false

# Обучение
var lesson_lang: String    = "en"
var lesson_index: int      = 0
var lesson_duration: float = 90.0

# Статистика урока
var words_typed: int     = 0
var errors_made: int     = 0
var correct_letters: int = 0


func _ready() -> void:
	# Главный класс должен всегда обрабатывать ввод, чтобы поймать Esc во время паузы
	process_mode = Node.PROCESS_MODE_ALWAYS
	MetaProgress.load_progress()
	
	
	add_to_group("main_scene")
	_setup_background()
	upgrade_menu.player = player

	player.leveled_up.connect(_on_player_leveled_up)
	player.died.connect(_on_player_died)
	enemy_manager.enemy_killed.connect(_on_enemy_killed)
	TypingLessonManager.load_progress()

	# Скрываем все игровые экраны
	win_screen.visible           = false
	game_over_screen.visible     = false
	lesson_hud.visible           = false
	lesson_result_screen.visible = false
	upgrade_menu.visible         = false
	if meta_shop: meta_shop.visible = false

	GameEvents.play_sfx.connect(_on_play_sfx)

	# Подключаем кнопки языка
	if en_btn: en_btn.pressed.connect(func(): _select_lang("en"))
	if ru_btn: ru_btn.pressed.connect(func(): _select_lang("ru"))

	# Кнопка обычной игры
	var normal_btn := lesson_select_screen.get_node_or_null("Panel/VBox/BottomRow/NormalBtn")
	if normal_btn:
		normal_btn.pressed.connect(_start_normal_game)

	# Кнопка бесконечного режима
	var endless_btn := lesson_select_screen.get_node_or_null("Panel/VBox/BottomRow/EndlessBtn")
	if endless_btn:
		endless_btn.pressed.connect(_start_endless_game)

	# Кнопка магазина в экране выбора урока
	var shop_btn := lesson_select_screen.get_node_or_null("Panel/VBox/BottomRow/ShopBtn")
	if shop_btn:
		shop_btn.pressed.connect(_open_meta_shop)

	# Кнопки магазина в экранах победы/поражения
	var win_shop_btn := win_screen.get_node_or_null("Panel/VBox/BtnRow/ShopBtn")
	if win_shop_btn: win_shop_btn.pressed.connect(_open_meta_shop)

	var go_shop_btn := game_over_screen.get_node_or_null("Panel/VBox/BtnRow/ShopBtn")
	if go_shop_btn: go_shop_btn.pressed.connect(_open_meta_shop)

	# Кнопки «В главное меню» в экранах победы/поражения
	var win_menu_btn := win_screen.get_node_or_null("Panel/VBox/BtnRow/MainMenuBtn")
	if win_menu_btn: win_menu_btn.pressed.connect(_go_to_main_menu)

	var go_menu_btn := game_over_screen.get_node_or_null("Panel/VBox/BtnRow/MainMenuBtn")
	if go_menu_btn: go_menu_btn.pressed.connect(_go_to_main_menu)

	# Кнопка «Выйти из игры» в экранах победы/поражения
	var win_quit_btn := win_screen.get_node_or_null("Panel/VBox/BtnRow/QuitBtn")
	if win_quit_btn: win_quit_btn.pressed.connect(get_tree().quit)

	var go_quit_btn := game_over_screen.get_node_or_null("Panel/VBox/BtnRow/QuitBtn")
	if go_quit_btn: go_quit_btn.pressed.connect(get_tree().quit)

	_connect_result_buttons()

	lesson_select_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	lesson_result_screen.process_mode = Node.PROCESS_MODE_ALWAYS

	_rebuild_lesson_list()
	_select_lang(lesson_lang)
	lesson_select_screen.visible = true
	get_tree().paused = true


# ── Интеграция Меню Паузы ──────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	# Если нажата клавиша Cancel (по дефолту Esc) и игра в данный момент запущена
	if event.is_action_pressed("ui_cancel") and game_active:
		# Проверяем, не открыто ли уже меню паузы, чтобы избежать дублирования
		if not has_node("PauseMenu"):
			get_tree().paused = true
			var pause_menu_instance = PAUSE_MENU_SCENE.instantiate()
			pause_menu_instance.name = "PauseMenu"
			add_child(pause_menu_instance)


func _on_play_sfx(sfx_name: String):
	match sfx_name:
		"enemy_death": sfx_enemy_death.play()
		"enemy_take_damage": sfx_enemy_take_damage.play()
		"player_take_damage": sfx_player_take_damage.play()
		"player_attack": sfx_attack.play()
		"player_death": sfx_player_death.play()


func _show_lesson_info(lang: String, index: int) -> void:
	var lesson = TypingLessonManager.get_lesson(lang, index)

	lesson_lang = lang
	lesson_index = index

	result_title.text = "%s · %s" % [lesson["title"], lesson["subtitle"]]
	result_title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))

	result_label.text = "\n%s\n\nКлавиши: %s\n" % [lesson["description"], lesson["keys"]]
	result_label.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	result_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var all_keys_str: String = " ".join(lesson.get("allowed", "")).to_upper()
	var new_keys_str: String = " ".join(lesson.get("new_letters", all_keys_str)).to_upper()

	if keyboard_diagram:
		keyboard_diagram.setup(lang, new_keys_str, all_keys_str)
		keyboard_diagram.visible = true

	var next_btn  := lesson_result_screen.get_node_or_null("Panel/VBox/BtnRow/NextBtn")
	var retry_btn := lesson_result_screen.get_node_or_null("Panel/VBox/BtnRow/RetryBtn")
	
	var endless_lesson_btn := lesson_result_screen.get_node_or_null("Panel/VBox/BtnRow/EndlessLessonBtn")
	if endless_lesson_btn:
		endless_lesson_btn.visible = true
		if not endless_lesson_btn.pressed.is_connected(_start_endless_lesson):
			endless_lesson_btn.pressed.connect(_start_endless_lesson)

	if next_btn: next_btn.visible = false
	if retry_btn: retry_btn.text = "НАЧАТЬ УРОВЕНЬ"

	lesson_result_screen.visible = true


# ── Магазин ───────────────────────────────────────────────────────────────────
func _open_meta_shop() -> void:
	if meta_shop:
		meta_shop.open_shop()


# ── Главное меню ──────────────────────────────────────────────────────────────
func _go_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


# ─────────────────────────────────────────
# ВЫБОР ЯЗЫКА
# ─────────────────────────────────────────
func _select_lang(lang: String) -> void:
	lesson_lang = lang
	_rebuild_lesson_list()
	if en_btn: en_btn.add_theme_color_override("font_color",
		Color(1.0, 0.9, 0.3) if lang == "en" else Color(0.8, 0.85, 1.0))
	if ru_btn: ru_btn.add_theme_color_override("font_color",
		Color(1.0, 0.9, 0.3) if lang == "ru" else Color(0.8, 0.85, 1.0))


func _rebuild_lesson_list() -> void:
	for child in lesson_list_box.get_children():
		child.queue_free()

	var count   = TypingLessonManager.get_lesson_count(lesson_lang)
	var current = TypingLessonManager.get_current_index(lesson_lang)

	for i in range(count):
		var lesson = TypingLessonManager.get_lesson(lesson_lang, i)
		var btn    := Button.new()
		var is_locked = i > current

		var star := "★ " if i == current else "  "
		btn.text = "%s%s · %s" % [star, lesson["title"], lesson["subtitle"]]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		if is_locked:
			btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			btn.disabled = true
		else:
			btn.add_theme_color_override("font_color",
				Color(1.0, 0.9, 0.3) if i == current else Color(0.8, 0.85, 1.0))

			var idx := i
			btn.pressed.connect(func(): _show_lesson_info(lesson_lang, idx))
		lesson_list_box.add_child(btn)


# ─────────────────────────────────────────
# СТАРТ УРОКА
# ─────────────────────────────────────────
func _start_typing_lesson(p_lang: String, p_lesson_index: int) -> void:
	is_endless = false
	_init_typing_mode(p_lang, p_lesson_index)

func _start_endless_lesson() -> void:
	is_endless = true
	_init_typing_mode(lesson_lang, lesson_index)

func _init_typing_mode(p_lang: String, p_lesson_index: int) -> void:

	MusicPlayer.play_music()
	$HUD.visible = true
	
	var level_row = player.get_node_or_null("CanvasLayer/StatsPanel/VBox/LevelRow")
	var xp_row = player.get_node_or_null("CanvasLayer/StatsPanel/VBox/XPRow")
	if level_row: level_row.visible = false
	if xp_row: xp_row.visible = false

	var p_canvas = player.get_node_or_null("CanvasLayer")
	if p_canvas: p_canvas.visible = true

	MetaProgress.apply_to_player(player)
	player._update_ui()

	player.current_hp = player.max_hp
	player.visible = true
	player.set_physics_process(true)
	player.set_process_unhandled_input(true)
	player.modulate = Color(1, 1, 1)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()

	lesson_lang  = p_lang
	lesson_index = p_lesson_index
	TypingLessonManager.set_lesson(p_lang, p_lesson_index)

	var lesson     = TypingLessonManager.get_current_lesson(p_lang)
	lesson_duration = lesson.get("duration", 90.0)
	
	_update_hud(0 if is_endless else lesson_duration)
	
	words_typed     = 0
	errors_made     = 0
	correct_letters = 0
	time_elapsed    = 0.0
	score           = 0
	_revived_this_run = false

	player.lesson_lang = p_lang

	upgrade_menu.visible      = false
	upgrade_menu.process_mode = Node.PROCESS_MODE_DISABLED

	enemy_manager.activate_typing_mode(p_lang, p_lesson_index)
	DifficultyAi.start_lesson(p_lang, p_lesson_index)

	if not player.word_completed.is_connected(_on_word_completed):
		player.word_completed.connect(_on_word_completed)
	if not player.letter_error.is_connected(_on_letter_error):
		player.letter_error.connect(_on_letter_error)
	if not player.letter_correct.is_connected(_on_letter_correct):
		player.letter_correct.connect(_on_letter_correct)

	lesson_select_screen.visible = false
	lesson_result_screen.visible = false
	get_tree().paused = false

	lesson_hud.visible    = true
	lesson_label.text     = ("∞ " if is_endless else "") + "%s · %s" % [lesson["title"], lesson["subtitle"]]
	keys_label.text       = "[ %s ]" % lesson["keys"]
	_update_lesson_stats()

	game_active = true


# ─────────────────────────────────────────
# СТАРТ ОБЫЧНОЙ ИГРЫ
# ─────────────────────────────────────────
func _start_normal_game() -> void:
	is_endless = false
	_init_normal_mode()

func _start_endless_game() -> void:
	is_endless = true
	_init_normal_mode()

func _init_normal_mode() -> void:

	MusicPlayer.play_music()
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	
	var selected_lang: String = lesson_lang if lesson_lang != "" else "en"
	player.lesson_lang = ""
	lesson_lang = ""
	MetaProgress.apply_to_player(player)
	player._update_ui()

	player.current_hp = player.max_hp
	player.visible = true
	player.set_physics_process(true)
	player.set_process_unhandled_input(true)
	player.modulate = Color(1, 1, 1)
		
	$HUD.visible = true
	var p_canvas = player.get_node_or_null("CanvasLayer")
	if p_canvas: p_canvas.visible = true

	var level_row = player.get_node_or_null("CanvasLayer/StatsPanel/VBox/LevelRow")
	var xp_row = player.get_node_or_null("CanvasLayer/StatsPanel/VBox/XPRow")
	if level_row: level_row.visible = true
	if xp_row: xp_row.visible = true

	upgrade_menu.visible      = false
	upgrade_menu.process_mode = Node.PROCESS_MODE_INHERIT
	upgrade_menu.player       = player
	lesson_hud.visible        = false

	score        = 0
	time_elapsed = 0.0
	_revived_this_run = false

	lesson_select_screen.visible = false
	get_tree().paused = false

	game_active = true

	_update_hud(0 if is_endless else GAME_DURATION)
	enemy_manager.activate_normal_mode(selected_lang)

	if not player.word_completed.is_connected(_on_word_completed):
		player.word_completed.connect(_on_word_completed)
	if not player.letter_error.is_connected(_on_letter_error):
		player.letter_error.connect(_on_letter_error)
	if not player.letter_correct.is_connected(_on_letter_correct):
		player.letter_correct.connect(_on_letter_correct)
	DifficultyAi.start(player, selected_lang)


# ─────────────────────────────────────────
# PROCESS
# ─────────────────────────────────────────
func _process(delta: float) -> void:
	if not game_active:
		if lesson_lang == "":
			if Input.is_action_just_pressed("ui_accept"):
				_go_to_main_menu()
		return

	time_elapsed += delta

	if lesson_lang != "":
		if is_endless:
			_update_timer_label(time_elapsed)
		else:
			var remaining = max(0.0, lesson_duration - time_elapsed)
			_update_timer_label(remaining)
			if time_elapsed >= lesson_duration:
				enemy_manager.spawn_timer.stop()

				var enemies = get_tree().get_nodes_in_group("enemies")
				if enemies.size() == 0:
					MusicPlayer.fade_out()
					_finish_lesson(true)
					$HUD.visible = false
					var p_canvas = player.get_node_or_null("CanvasLayer")
					if p_canvas: p_canvas.visible = false
	else:
		if is_endless:
			_update_timer_label(time_elapsed)
		else:
			var remaining = max(0.0, GAME_DURATION - time_elapsed)
			_update_timer_label(remaining)
			if time_elapsed >= GAME_DURATION:
				MusicPlayer.fade_out()
				enemy_manager.spawn_timer.stop()

				var enemies = get_tree().get_nodes_in_group("enemies")
				if enemies.size() == 0:
					_win()
					$HUD.visible = false
					var p_canvas = player.get_node_or_null("CanvasLayer")
					if p_canvas: p_canvas.visible = false


# ─────────────────────────────────────────
# HUD (обычный режим)
# ─────────────────────────────────────────
func _update_hud(time: int) -> void:
	score_label.text = "Монеты: %d" % MetaProgress.currency
	_update_currency_hud()
	_update_timer_label(time)


func _update_currency_hud() -> void:
	if currency_hud_label:
		currency_hud_label.text = "%d" % MetaProgress.currency


func _update_timer_label(time_value: float) -> void:
	var mins := int(time_value) / 60
	var secs := int(time_value) % 60
	if is_endless:
		timer_label.text = "Время (Беск.): %02d:%02d" % [mins, secs]
	else:
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
# МОНЕТЫ
# ─────────────────────────────────────────
func _on_enemy_killed(points: int) -> void:
	score += points
	MetaProgress.add_currency(points)
	DifficultyAi.record_kill()
	_update_currency_hud()


func add_score(points: int) -> void:
	score += points
	MetaProgress.add_currency(points)
	if lesson_lang == "":
		_update_currency_hud()


# ─────────────────────────────────────────
# СТАТИСТИКА УРОКА
# ─────────────────────────────────────────
func _on_word_completed() -> void:
	words_typed += 1
	DifficultyAi.record_word()
	_update_lesson_stats()


func _is_lich_active() -> bool:
	return get_tree().get_first_node_in_group("lich_boss") != null


func _on_letter_error() -> void:
	if _is_lich_active():
		return   # во время боя с личем ошибки не считаем
	errors_made += 1
	DifficultyAi.record_error()
	_update_lesson_stats()


func _on_letter_correct() -> void:
	if _is_lich_active():
		return   # во время боя с личем правильные нажатия тоже не считаем
	correct_letters += 1
	DifficultyAi.record_correct()
	_update_lesson_stats()


# ─────────────────────────────────────────
# ЗАВЕРШЕНИЕ УРОКА
# ─────────────────────────────────────────
func _finish_lesson(survived: bool) -> void:
	if not game_active:
		return
	$HUD.visible = false
	if keyboard_diagram: keyboard_diagram.visible = false

	var p_canvas = player.get_node_or_null("CanvasLayer")
	if p_canvas: p_canvas.visible = true

	game_active = false
	get_tree().paused = true

	var total    := correct_letters + errors_made
	var accuracy := 100 if total == 0 else int(float(correct_letters) / float(total) * 100.0)
	
	var passed   := (survived or is_endless) and accuracy >= 70

	var lesson := TypingLessonManager.get_current_lesson(lesson_lang)
	var next_btn  := lesson_result_screen.get_node_or_null("Panel/VBox/BtnRow/NextBtn")
	var retry_btn := lesson_result_screen.get_node_or_null("Panel/VBox/BtnRow/RetryBtn")

	var endless_lesson_btn := lesson_result_screen.get_node_or_null("Panel/VBox/BtnRow/EndlessLessonBtn")
	if endless_lesson_btn: endless_lesson_btn.visible = false

	if passed:
		result_title.text = "✓ УРОК ПРОЙДЕН!" if not is_endless else "∞ ТРЕНИРОВКА ЗАВЕРШЕНА!"
		result_title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		if not is_endless:
			TypingLessonManager.advance_lesson(lesson_lang)
		if next_btn: next_btn.visible = not is_endless
	else:
		result_title.text = "✗ ПОПРОБУЙ ЕЩЁ"
		result_title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
		if next_btn: next_btn.visible = false

	var lang_name := "English (QWERTY)" if lesson_lang == "en" else "Русский (ЙЦУКЕН)"
	var next_lesson := TypingLessonManager.get_current_lesson(lesson_lang)

	if retry_btn:
		retry_btn.text = "ПОВТОРИТЬ" if not is_endless else "ЕЩЁ РАЗ"
		retry_btn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3) if is_endless else Color(1.0, 0.4, 0.3))

	if is_endless:
		_save_score(score, false)

	var stats_text := (
		"%s — %s\n\n" % [lesson["title"], lesson["subtitle"]] +
		"Режим: %s\n" % ("Бесконечный" if is_endless else "Обычный") +
		"Язык: %s\n" % lang_name +
		"Слов напечатано: %d\n" % words_typed +
		"Точность: %d%%\n" % accuracy +
		"Ошибок: %d\n\n" % errors_made
	)
	
	if is_endless:
		stats_text += _build_leaderboard_text()
	elif passed:
		stats_text += "→ Открыт: %s · %s" % [next_lesson["title"], next_lesson["subtitle"]]

	result_label.text = stats_text
	lesson_result_screen.visible = true


# ─────────────────────────────────────────
# КНОПКИ РЕЗУЛЬТАТА
# ─────────────────────────────────────────
func _connect_result_buttons() -> void:
	var next_btn  := lesson_result_screen.get_node_or_null("Panel/VBox/BtnRow/NextBtn")
	var retry_btn := lesson_result_screen.get_node_or_null("Panel/VBox/BtnRow/RetryBtn")
	var menu_btn  := lesson_result_screen.get_node_or_null("Panel/VBox/BtnRow/MenuBtn")

	if next_btn:
		next_btn.pressed.connect(func():
			var next_idx := TypingLessonManager.get_current_index(lesson_lang)
			get_tree().paused = false
			lesson_result_screen.visible = false
			_start_typing_lesson(lesson_lang, next_idx)
		)
	if retry_btn:
		retry_btn.pressed.connect(func():
			get_tree().paused = false
			lesson_result_screen.visible = false
			if is_endless:
				_start_endless_lesson()
			else:
				_start_typing_lesson(lesson_lang, lesson_index)
		)
	if menu_btn:
		menu_btn.pressed.connect(func():
			lesson_result_screen.visible = false
			lesson_hud.visible = false
			$HUD.visible = false
			_select_lang(lesson_lang)
			lesson_select_screen.visible = true
			get_tree().paused = true
		)


# ─────────────────────────────────────────
# ПОБЕДА
# ─────────────────────────────────────────
func _win() -> void:
	if not game_active:
		return
	DifficultyAi.stop()
	game_active = false
	get_tree().paused = true
	_save_score(score, true)
	win_score_label.text  = "Монеты за игру: %d" % MetaProgress.currency
	win_leader_label.text = _build_leaderboard_text()
	win_screen.visible    = true


# ─────────────────────────────────────────
# ПОРАЖЕНИЕ
# ─────────────────────────────────────────
func _on_player_died() -> void:
	if not game_active:
		return

	if not _revived_this_run:
		var revive_chance = MetaProgress.get_revive_chance()
		if revive_chance > 0.0 and randf() < revive_chance:
			_revived_this_run = true
			_do_revive()
			return
			
	MusicPlayer.fade_out()
	GameEvents.play_sfx.emit("player_death")
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.visible = false
	
	DifficultyAi.stop()
	get_tree().paused = true

	if lesson_lang != "":
		_finish_lesson(false) 
	else:
		game_active = false
		_save_score(score, false)
		go_score_label.text   = "Монеты за игру: %d" % MetaProgress.currency
		go_leader_label.text  = _build_leaderboard_text()
		game_over_screen.visible = true
		
	$HUD.visible = false
	var p_canvas = player.get_node_or_null("CanvasLayer")
	if p_canvas: p_canvas.visible = false


func _do_revive() -> void:
	player.current_hp = int(player.max_hp * 0.4)
	player.invincible = false
	player.visible    = true
	player.set_physics_process(true)
	player.set_process_unhandled_input(true)
	player.modulate = Color(1, 1, 1)
	player._update_ui()

	var flash := ColorRect.new()
	flash.color = Color(0.5, 1.0, 0.7, 0.6)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().current_scene.add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.6)
	tw.tween_callback(flash.queue_free)

	var label := Label.new()
	label.text = "✙ ВОСКРЕШЕНИЕ!"
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	get_tree().current_scene.add_child(label)
	var tw2 := label.create_tween()
	tw2.tween_property(label, "position:y", label.position.y - 60, 1.2)
	tw2.parallel().tween_property(label, "modulate:a", 0.0, 1.2)
	tw2.tween_callback(label.queue_free)


# ─────────────────────────────────────────
# ПОВЫШЕНИЕ УРОВНЯ
# ─────────────────────────────────────────
func _on_player_leveled_up(new_level: int) -> void:
	enemy_manager.increase_difficulty()
	if lesson_lang == "":
		upgrade_menu.show_upgrade_menu(new_level)


# ─────────────────────────────────────────
# СИСТЕМА РЕКОРДОВ
# ─────────────────────────────────────────
func _get_current_mode_key() -> String:
	if lesson_lang != "":
		var mode_suffix := "_endless" if is_endless else "_normal"
		return "lesson_" + str(lesson_index) + "_" + lesson_lang + mode_suffix
	else:
		return "normal_endless" if is_endless else "normal_timed"


func _load_leaderboard() -> Dictionary:
	if not FileAccess.file_exists(LEADERBOARD_PATH):
		return {}
	var f := FileAccess.open(LEADERBOARD_PATH, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


func _save_score(new_score: int, won: bool) -> void:
	var all_data := _load_leaderboard()
	var mode_key := _get_current_mode_key()
	
	if not all_data.has(mode_key):
		all_data[mode_key] = []
		
	var records: Array = all_data[mode_key]
	records.append({"score": new_score, "won": won, "time": int(time_elapsed)})
	
	if is_endless:
		records.sort_custom(func(a, b): return a["time"] > b["time"])
	else:
		records.sort_custom(func(a, b): return a["score"] > b["score"])
		
	if records.size() > MAX_RECORDS:
		records.resize(MAX_RECORDS)
		
	all_data[mode_key] = records
	
	var f := FileAccess.open(LEADERBOARD_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(all_data, "\t"))
		f.close()


func _build_leaderboard_text() -> String:
	var all_data := _load_leaderboard()
	var mode_key := _get_current_mode_key()
	
	if not all_data.has(mode_key) or all_data[mode_key].is_empty():
		return "── Рекорды режима ──\nИстория рекордов пока пуста"
		
	var records: Array = all_data[mode_key]
	var text := "── Рекорды (Сортировка: %s) ──\n" % ("Время" if is_endless else "Очки")
	
	for i in range(records.size()):
		var r = records[i]
		var mins := int(r["time"]) / 60
		var secs := int(r["time"]) % 60
		var result := "Победа" if r["won"] else "Поражение"
		
		if is_endless:
			text += "%d. %02d:%02d минут  [%d монет]\n" % [i + 1, mins, secs, r["score"]]
		else:
			text += "%d. %d монет  [%s]  %02d:%02d\n" % [i + 1, r["score"], result, mins, secs]
			
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
