extends CharacterBody2D

# ==========================================
# ОДЕРЖИМАЯ КНИГА — Минибосс
#
# Ведёт себя как обычный враг: движется к игроку,
# наносит урон при касании, убивается вводом слова.
#
# ОСОБАЯ СПОСОБНОСТЬ: периодически выстреливает
# буквой-снарядом в игрока. Каждая такая буква
# засчитывается как одно отдельное слово для игрока
# (игрок должен нажать соответствующую клавишу, чтобы
# отразить снаряд — или принять урон).
# ==========================================

@export var speed: float        = 55.0
@export var hp: int             = 25
@export var max_hp: int         = 25
@export var points: int         = 50
@export var contact_damage: int = 12

# Снаряд-буква (назначь LetterBullet.tscn в инспекторе)
@export var letter_bullet_scene: PackedScene

# Интервал между выстрелами (секунды)
@export var shoot_interval: float = 4.0

var player: Node = null
var _word: String = ""
var _shoot_timer: float = 0.0
var _is_dead: bool = false

# Буквы, которые книга может выстреливать (из разрешённых уроком)
var _allowed_letters: Array = []

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var word_label: RichTextLabel       = $WordLabel
@onready var hp_bar: ProgressBar     = $HPBar

signal killed(points: int)


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("book_boss")
	hp     = max_hp
	_shoot_timer = shoot_interval * 0.5  # первый выстрел чуть раньше

	if anim:
		anim.play("walk")

	_update_hp_bar()
	_update_word_display()


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_check_offscreen_and_reposition()
	_move_toward_player(delta)
	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_shoot_timer = shoot_interval
		_fire_letter()

	move_and_slide()
	_update_animation()


func _check_offscreen_and_reposition() -> void:
	if player == null or not is_instance_valid(player):
		return
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam == null:
		return
	var cam_center := cam.get_screen_center_position()
	var viewport_size := get_viewport().get_visible_rect().size / cam.zoom
	var half_w := viewport_size.x * 0.5
	var half_h := viewport_size.y * 0.5
	var diff := global_position - cam_center
	if abs(diff.x) > half_w + 120.0 or abs(diff.y) > half_h + 120.0:
		var margin := 32.0
		var side := randi() % 4
		match side:
			0: global_position = cam_center + Vector2(randf_range(-half_w, half_w), -(half_h + margin))
			1: global_position = cam_center + Vector2(randf_range(-half_w, half_w),  (half_h + margin))
			2: global_position = cam_center + Vector2(-(half_w + margin), randf_range(-half_h, half_h))
			3: global_position = cam_center + Vector2( (half_w + margin), randf_range(-half_h, half_h))


# ─────────────────────────────────────────
# ДВИЖЕНИЕ
# ─────────────────────────────────────────
func _move_toward_player(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var dir = (player.global_position - global_position).normalized()
	velocity = dir * speed


func _update_animation() -> void:
	if anim == null:
		return
	# Отражаем спрайт по направлению движения
	if velocity.x < 0:
		anim.flip_h = true
	elif velocity.x > 0:
		anim.flip_h = false


# ─────────────────────────────────────────
# СЛОВО (интерфейс совместимости с Enemy)
# ─────────────────────────────────────────
func set_word(w: String) -> void:
	_word = w
	_update_word_display()


func get_word() -> String:
	return _word


func _assign_new_word() -> void:
	# Вызывается игроком после полного ввода слова
	var mgr = get_tree().get_first_node_in_group("enemy_manager")
	if mgr and mgr.has_method("get_random_word"):
		set_word(mgr.get_random_word())
	_play_attack_flash()


func highlight_progress(chars_done: int) -> void:
	if word_label == null:
		return
	var full  := _word.to_upper()
	var typed := full.substr(0, chars_done)
	var rest  := full.substr(chars_done)
	word_label.text = "[color=ffff66]%s[/color][color=ffffff]%s[/color]" % [typed, rest]
	word_label.bbcode_enabled = true


func _update_word_display() -> void:
	if word_label == null:
		return
	word_label.text = _word.to_upper()
	word_label.bbcode_enabled = false


# ─────────────────────────────────────────
# ВЫСТРЕЛ БУКВОЙ
# ─────────────────────────────────────────
func _fire_letter() -> void:
	if letter_bullet_scene == null:
		return
	if player == null or not is_instance_valid(player):
		return

	# Выбираем случайную разрешённую букву
	var letter := _pick_shoot_letter()
	if letter == "":
		return

	# Анимация атаки
	if anim:
		anim.play("attack")
		await anim.animation_finished
		if anim and not _is_dead:
			anim.play("walk")

	if _is_dead or not is_instance_valid(self):
		return

	# Создаём снаряд
	var bullet = letter_bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position
	bullet.setup(letter, player, self)

	# Спецэффект — мерцание
	modulate = Color(1.5, 1.0, 2.0)
	get_tree().create_timer(0.15).timeout.connect(func():
		if is_instance_valid(self):
			modulate = Color(1, 1, 1)
	)


func _pick_shoot_letter() -> String:
	if _allowed_letters.is_empty():
		# Пытаемся получить список из менеджера
		var mgr = get_tree().get_first_node_in_group("enemy_manager")
		if mgr and mgr.has_method("get_lesson_allowed_letters"):
			_allowed_letters = mgr.get_lesson_allowed_letters()
		if _allowed_letters.is_empty():
			# Запасной вариант
			_allowed_letters = ["a","s","d","f","j","k","l"]
	return _allowed_letters.pick_random()


func set_allowed_letters(letters: Array) -> void:
	_allowed_letters = letters


# ─────────────────────────────────────────
# ПОЛУЧЕНИЕ УРОНА / СМЕРТЬ
# ─────────────────────────────────────────
func take_damage(amount: int = 1) -> void:
	if _is_dead:
		return
	hp -= amount
	_update_hp_bar()
	_play_hit_flash()

	if hp <= 0:
		_die()


func _die() -> void:
	if _is_dead:
		return
	_is_dead = true

	# Сигнал очков менеджеру
	var mgr = get_tree().get_first_node_in_group("enemy_manager")
	if mgr and mgr.has_method("report_kill"):
		mgr.report_kill(points)

	emit_signal("killed", points)

	# Эффект смерти — вспышка и исчезновение
	modulate = Color(2, 1.5, 2.5)
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)


func _play_hit_flash() -> void:
	modulate = Color(2, 0.4, 0.4)
	get_tree().create_timer(0.12).timeout.connect(func():
		if is_instance_valid(self) and not _is_dead:
			modulate = Color(1, 1, 1)
	)


func _play_attack_flash() -> void:
	modulate = Color(1.2, 0.8, 2.0)
	get_tree().create_timer(0.1).timeout.connect(func():
		if is_instance_valid(self) and not _is_dead:
			modulate = Color(1, 1, 1)
	)


# ─────────────────────────────────────────
# HP BAR
# ─────────────────────────────────────────
func _update_hp_bar() -> void:
	if hp_bar == null:
		return
	hp_bar.max_value = max_hp
	hp_bar.value     = hp
