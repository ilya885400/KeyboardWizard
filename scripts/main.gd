extends Node2D

# ==========================================
# ГЛАВНАЯ СЦЕНА (Main.tscn)
# Связывает Player, EnemyManager и UpgradeMenu.
# Добавлено: очки, таймер 10 минут, таблица рекордов.
# ==========================================

@onready var player: CharacterBody2D           = $Player
@onready var enemy_manager: Node2D             = $EnemyManager
@onready var upgrade_menu: CanvasLayer         = $UpgradeMenu
@onready var camera: Camera2D                  = $Player/Camera2D

# ── HUD ────────────────────────────────────────────────────────────────────────
# Добавь в Main.tscn узел CanvasLayer (name="HUD") с дочерними узлами:
#   HUD/ScoreLabel   — Label, якорь верх-по-центру
#   HUD/TimerLabel   — Label, якорь верх-по-центру (под ScoreLabel)
@onready var score_label: Label = $HUD/ScorePanel/ScoreLabel
@onready var timer_label: Label = $HUD/TimerPanel/TimerLabel

# ── Экран победы ───────────────────────────────────────────────────────────────
# Добавь в Main.tscn узел CanvasLayer (name="WinScreen") → Panel → VBox:
#   WinScreen/Panel/VBox/TitleLabel    — Label "ПОБЕДА!"
#   WinScreen/Panel/VBox/ScoreLabel    — Label с итоговыми очками
#   WinScreen/Panel/VBox/LeaderLabel   — Label с таблицей рекордов
#   WinScreen/Panel/VBox/HintLabel     — Label "Нажми Enter чтобы сыграть снова"
@onready var win_screen: CanvasLayer           = $WinScreen
@onready var win_score_label: Label            = $WinScreen/Panel/VBox/ScoreLabel
@onready var win_leader_label: Label           = $WinScreen/Panel/VBox/LeaderLabel

# ── Экран поражения ────────────────────────────────────────────────────────────
# Добавь в Main.tscn узел CanvasLayer (name="GameOverScreen") → Panel → VBox:
#   GameOverScreen/Panel/VBox/TitleLabel   — Label "ПОРАЖЕНИЕ"
#   GameOverScreen/Panel/VBox/ScoreLabel   — Label с очками
#   GameOverScreen/Panel/VBox/LeaderLabel  — Label с таблицей рекордов
#   GameOverScreen/Panel/VBox/HintLabel    — Label "Нажми Enter чтобы сыграть снова"
@onready var game_over_screen: CanvasLayer     = $GameOverScreen
@onready var go_score_label: Label             = $GameOverScreen/Panel/VBox/ScoreLabel
@onready var go_leader_label: Label            = $GameOverScreen/Panel/VBox/LeaderLabel

# ── Данные ─────────────────────────────────────────────────────────────────────
const GAME_DURATION   := 120.0          # 10 минут в секундах
const LEADERBOARD_PATH := "user://leaderboard.json"
const MAX_RECORDS      := 10            # сколько рекордов хранить

var score: int             = 0
var time_elapsed: float    = 0.0
var game_active: bool      = true       # false когда показан экран победы/поражения


func _ready() -> void:
	add_to_group("main_scene")   # pickup.gd ищет главную сцену через эту группу
	_setup_background()
	upgrade_menu.player = player

	player.leveled_up.connect(_on_player_leveled_up)
	player.died.connect(_on_player_died)          # ← НОВОЕ

	# Подключаем сигнал очков от менеджера врагов
	enemy_manager.enemy_killed.connect(_on_enemy_killed)   # ← НОВОЕ

	win_screen.visible      = false
	game_over_screen.visible = false

	_update_hud()

	## ── Фикс телепортации камеры ───────────────────────────────────────────────
	#camera.position_smoothing_enabled = false
	#await get_tree().process_frame
	#camera.reset_smoothing()
	#camera.position_smoothing_enabled = true


func _process(delta: float) -> void:
	if not game_active:
		# Ожидаем Enter для перезапуска
		if Input.is_action_just_pressed("ui_accept"):
			get_tree().reload_current_scene()

		return

	time_elapsed += delta
	var remaining: float = max(0.0, GAME_DURATION - time_elapsed)
	_update_timer_label(remaining)

	if time_elapsed >= GAME_DURATION:
		_win()


# ─────────────────────────────────────────
# HUD
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
	score_label.text = "Очки: %d" % score


func add_score(points: int) -> void:
	score += points
	score_label.text = "Очки: %d" % score


# ─────────────────────────────────────────
# ПОБЕДА
# ─────────────────────────────────────────
func _win() -> void:
	if not game_active:
		return
	game_active = false
	get_tree().paused = true
	_save_score(score, true)
	win_score_label.text = "Ваш счёт: %d" % score
	win_leader_label.text = _build_leaderboard_text()
	win_screen.visible = true


# ─────────────────────────────────────────
# ПОРАЖЕНИЕ
# ─────────────────────────────────────────
func _on_player_died() -> void:
	if not game_active:
		return
	game_active = false
	# Не перезагружаем сцену — показываем экран поражения
	get_tree().paused = true
	_save_score(score, false)
	go_score_label.text = "Ваш счёт: %d" % score
	go_leader_label.text = _build_leaderboard_text()
	game_over_screen.visible = true


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
	# Сортируем по убыванию очков
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
# ПОВЫШЕНИЕ УРОВНЯ
# ─────────────────────────────────────────
func _on_player_leveled_up(new_level: int) -> void:
	enemy_manager.increase_difficulty()
	upgrade_menu.show_upgrade_menu(new_level)


# ─────────────────────────────────────────
# ФОН
# ─────────────────────────────────────────
func _setup_background() -> void:
	var bg_texture: Texture2D = load("res://pixel_assets/background/one_background_tile.png")
	if bg_texture == null:
		push_error("Main: не удалось загрузить res://pixel_assets/background/one_background_tile.png")
		return

	var old_bg := get_node_or_null("Background")
	if old_bg:
		old_bg.queue_free()

	var parallax := Parallax2D.new()
	parallax.name = "ParallaxBackground"
	parallax.z_index = -10
	add_child(parallax)
	move_child(parallax, 0)

	var layer := Parallax2D.new()

	# Увеличиваем шаг повторения в 6 раз
	layer.repeat_times = 30
	layer.repeat_size = Vector2(bg_texture.get_width() * 6, bg_texture.get_height() * 6)
	parallax.add_child(layer)

	var sprite := Sprite2D.new()
	sprite.texture = bg_texture
	sprite.centered = false
	
	# ТАКТИЧЕСКИЙ ХОД: Масштабируем сам спрайт в 6 раз
	sprite.scale = Vector2(6, 6)
	
	layer.add_child(sprite)
