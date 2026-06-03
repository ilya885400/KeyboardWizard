extends CharacterBody2D
# Вставь это в верхнюю часть player.gd
signal word_completed
signal letter_error
signal letter_correct
# ==========================================
# ИГРОК — Волшебник
# ==========================================

@export var speed: float = 200.0
@export var projectile_scene: PackedScene

var lesson_lang: String = ""

var max_hp: float = 50
var current_hp: float = 50
var invincible: bool = false
const INVINCIBILITY_TIME := 0.8
const ENEMY_CONTACT_DAMAGE := 10

var experience: float = 0
var level: int = 1
var exp_to_next_level: float = 10

var current_input: String = ""
var target_enemy: Node = null

# Флаг для контроля анимации атаки
var is_attacking: bool = false

var was_completed: bool = false


signal leveled_up(new_level: int)
signal died

@onready var anim_player: AnimatedSprite2D = $AnimatedSprite2D
@onready var anim_player_shadow: AnimatedSprite2D = $AnimatedSprite2D/Shadow

@onready var exp_label: Label   = $CanvasLayer/StatsPanel/VBox/XPRow/XPHeaderRow/ExpLabel
@onready var level_label: Label = $CanvasLayer/StatsPanel/VBox/LevelRow/LevelLabel
@onready var hp_label: Label    = $CanvasLayer/StatsPanel/VBox/HPRow/HPHeaderRow/HPLabel
@onready var input_label: Label = $CanvasLayer/InputPanel/HBox/InputLabel
@onready var hp_bar: ProgressBar = $CanvasLayer/StatsPanel/VBox/HPRow/HPBar
@onready var exp_bar: ProgressBar = $CanvasLayer/StatsPanel/VBox/XPRow/XPBar

@onready var _invincibility_timer: Timer = $InvincibilityTimer
@onready var _flash_timer: Timer         = $FlashTimer
@onready var spell_manager               = $SpellManager


func _ready() -> void:
	MetaProgress.apply_to_player(self)

	add_to_group("player")
	current_hp = max_hp
	velocity   = Vector2.ZERO
	_update_ui()

	_invincibility_timer.wait_time = INVINCIBILITY_TIME
	_invincibility_timer.one_shot  = true
	_invincibility_timer.timeout.connect(_on_invincibility_timer_timeout)

	_flash_timer.wait_time = 0.15
	_flash_timer.one_shot  = true
	_flash_timer.timeout.connect(_on_flash_timer_timeout)

	if anim_player:
		anim_player.animation_finished.connect(_on_animation_finished)
		anim_player_shadow.animation_finished.connect(_on_animation_finished)

	spell_manager.player          = self
	spell_manager.projectile_scene = projectile_scene

func _physics_process(delta: float) -> void:
	_handle_movement()
	move_and_slide()
	_update_animations()
	_check_enemy_contact()


# ─────────────────────────────────────────
# ДВИЖЕНИЕ
# ─────────────────────────────────────────
func _handle_movement() -> void:
	if not Input.is_key_pressed(KEY_SHIFT):
		velocity = Vector2.ZERO
		return
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_D): direction.x -= 1
	if Input.is_key_pressed(KEY_K): direction.x += 1
	if Input.is_key_pressed(KEY_J): direction.y -= 1
	if Input.is_key_pressed(KEY_F): direction.y += 1
	velocity = direction.normalized() * speed


# ─────────────────────────────────────────
# АНИМАЦИИ
# ─────────────────────────────────────────
func _update_animations() -> void:
	if anim_player == null:
		return

	if is_attacking:
		return

	if velocity.length() > 0:
		anim_player.play("walk")
		anim_player_shadow.play("walk")
		if velocity.x < 0:
			anim_player.flip_h = true
			anim_player_shadow.flip_h = true
		elif velocity.x > 0:
			anim_player.flip_h = false
			anim_player_shadow.flip_h = false
	else:
		anim_player.play("idle")
		anim_player_shadow.play("idle")


func _on_animation_finished() -> void:
	if anim_player.animation == "attack":
		is_attacking = false
		anim_player.animation = "idle"
		anim_player_shadow.animation = "idle"


# ─────────────────────────────────────────
# УРОН ОТ КАСАНИЯ
# ─────────────────────────────────────────
func _check_enemy_contact() -> void:
	if invincible:
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) < 40.0:
			take_damage(ENEMY_CONTACT_DAMAGE)
			return


func take_damage(amount: int) -> void:
	if invincible:
		return
	current_hp -= amount
	_flash_damage()
	GameEvents.play_sfx.emit("player_take_damage")

	invincible = true
	_invincibility_timer.start()
	_update_ui()
	if current_hp <= 0:
		current_hp = 0
		_die()


func _on_invincibility_timer_timeout() -> void:
	invincible = false


func _flash_damage() -> void:
	modulate = Color(1.0, 0.3, 0.3)
	_flash_timer.start()


func _on_flash_timer_timeout() -> void:
	modulate = Color(1, 1, 1)


func _die() -> void:
	emit_signal("died")
	#MusicPlayer.fade_out()
	#GameEvents.play_sfx.emit("player_death")
	#set_physics_process(false)
	#set_process_unhandled_input(false)
	#visible = false



# ─────────────────────────────────────────
# ВВОД БУКВ
# ─────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if Input.is_key_pressed(KEY_SHIFT):
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var key_char := _extract_char(event)
		if key_char != "":
			_process_letter(key_char)

func _extract_char(event: InputEventKey) -> String:
	var uni: int = event.unicode
	if uni <= 0:
		return ""

	var ch  := String.chr(uni)
	var low := ch.to_lower()
	var cp  := low.unicode_at(0)

	var active_lang := lesson_lang
	if active_lang == "":
		var mgr = get_tree().get_first_node_in_group("enemy_manager")
		if mgr and "game_language" in mgr:
			active_lang = mgr.game_language

	if active_lang == "ru":
		if (cp >= 0x430 and cp <= 0x44F) or cp == 0x451:
			return low
		return ""
	else:
		if low.length() == 1 and low >= "a" and low <= "z":
			return low
		return ""

func _process_letter(letter: String) -> void:
	if _try_reflect_letter_bullet(letter):
		return

	# 1. Если цели нет, пытаемся найти новую
	
	if target_enemy == null or not is_instance_valid(target_enemy):
		var found := _find_and_lock_target(letter)
		if found:
			emit_signal("letter_correct")
			# Сразу проверяем: вдруг слово этого врага состояло всего из одной буквы?
			_check_and_execute_word_completion()
		else:
			emit_signal("letter_error")
		_update_input_display()
		return

	# 2. Если цель есть, проверяем ожидаемую букву
	var word: String = target_enemy.get_word()
	if current_input.length() >= word.length():
		_reset_target_and_error()
		return

	var expected_letter: String = word[current_input.length()]

	if letter == expected_letter:
		current_input += letter
		target_enemy.highlight_progress(current_input.length())
		emit_signal("letter_correct")

		# ПРОВЕРКА НА ИДЕАЛЬНОЕ СОВПАДЕНИЕ С ДРУГИМ ВРАГОМ
		# Если текущий ввод идеально завершает слово какого-то ДРУГОГО врага,
		# который сейчас ближе или просто имеет точное совпадение, переключаемся на него.
		var exact_enemy = _find_exact_match(current_input)
		if exact_enemy and exact_enemy != target_enemy:
			# Сбрасываем подсветку старой длинной цели
			target_enemy.highlight_progress(0)
			target_enemy = exact_enemy

		# Проверяем, завершено ли слово текущей (или обновленной точной) цели
		_check_and_execute_word_completion()
	else:
		# Логика переключения на другое слово при ошибке (остается твоя оригинальная)
		var combined_string := current_input + letter
		var switched := _find_and_lock_target(combined_string)

		if switched:
			emit_signal("letter_correct")
			_check_and_execute_word_completion()
		else:
			_reset_target_and_error()
			var found_new := _find_and_lock_target(letter)
			if found_new:
				emit_signal("letter_correct")
				_check_and_execute_word_completion()

	_update_input_display()

# Вспомогательный метод, чтобы не дублировать код выстрела и сброса
func _check_and_execute_word_completion() -> void:
	if target_enemy == null or not is_instance_valid(target_enemy):
		return
		
	var word: String = target_enemy.get_word()
	if current_input.length() >= word.length():
		was_completed = true
		emit_signal("word_completed")
		target_enemy._assign_new_word()
		_shoot_projectile(target_enemy)
		current_input = ""
		target_enemy = null

# Новый метод для поиска точного совпадения слова
func _find_exact_match(full_word: String) -> Node:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var closest_distance := INF
	var closest_enemy: Node = null

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		# Ищем только тех, у кого слово РАВНО вводу, а не просто начинается с него
		if enemy.get_word() == full_word:
			var dist := global_position.distance_to(enemy.global_position)
			if dist < closest_distance:
				closest_distance = dist
				closest_enemy = enemy
				
	return closest_enemy

func _reset_target_and_error() -> void:
	emit_signal("letter_error")
	if target_enemy != null and is_instance_valid(target_enemy):
		target_enemy.highlight_progress(0)
	target_enemy = null
	current_input = ""


func _find_and_lock_target(prefix: String) -> bool:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var closest_distance := INF
	var closest_enemy: Node = null

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var word: String = enemy.get_word()
		if word.begins_with(prefix):
			var dist := global_position.distance_to(enemy.global_position)
			if dist < closest_distance:
				closest_distance = dist
				closest_enemy    = enemy

	if closest_enemy != null:
		if target_enemy != null and is_instance_valid(target_enemy) and target_enemy != closest_enemy:
			target_enemy.highlight_progress(0)

		target_enemy = closest_enemy
		current_input = prefix
		target_enemy.highlight_progress(prefix.length())
		return true

	return false

func _shoot_projectile(enemy: Node) -> void:
	if projectile_scene == null:
		return
	var projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position
	projectile.set_target(enemy)

	if anim_player:
		GameEvents.play_sfx.emit("player_attack")
		is_attacking = true
		anim_player.play("attack")
		anim_player_shadow.play("attack")
		if enemy.global_position.x < global_position.x:
			anim_player.flip_h = true
			anim_player_shadow.flip_h = true
		else:
			anim_player.flip_h = false
			anim_player_shadow.flip_h = false

	if spell_manager.has_chain:
		projectile.connect("tree_exiting", func():
			spell_manager.trigger_chain(enemy)
		)

	if spell_manager.has_multishot:
		spell_manager.trigger_multishot(global_position, enemy)

	if spell_manager.has_thunder_strike:
		spell_manager.trigger_thunder_strike()


# ─────────────────────────────────────────
# ОПЫТ И УРОВНИ
# ─────────────────────────────────────────
func gain_experience(amount: int) -> void:
	experience += amount
	if experience >= exp_to_next_level:
		_level_up()
	_update_ui()


func _level_up() -> void:
	level += 1
	experience -= exp_to_next_level
	exp_to_next_level = int(exp_to_next_level * 1.5)
	emit_signal("leveled_up", level)
	_update_ui()


# ─────────────────────────────────────────
# UI
# ─────────────────────────────────────────
func _update_ui() -> void:
	if exp_label:   exp_label.text   = "XP: %d / %d" % [experience, exp_to_next_level]
	if level_label: level_label.text = "Уровень: %d"  % level
	if hp_label:    hp_label.text    = "HP: %d / %d"  % [current_hp, max_hp]

	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp

	if exp_bar:
		exp_bar.max_value = exp_to_next_level
		exp_bar.value = experience

func _update_input_display() -> void:
	if input_label and not was_completed:
		input_label.text = current_input if current_input.length() > 0 else ""
	if was_completed:
		was_completed = not was_completed

# ─────────────────────────────────────────
# АПГРЕЙДЫ (внутриигровые)
# ─────────────────────────────────────────
func upgrade_max_hp() -> void:
	max_hp += 30
	current_hp = mini(current_hp + 30, max_hp)
	_update_ui()


func heal(amount: int) -> void:
	if current_hp >= max_hp:
		return
	current_hp = min(current_hp + amount, max_hp)
	modulate = Color(0.4, 1.0, 0.5)
	get_tree().create_timer(0.2).timeout.connect(func():
		if is_instance_valid(self):
			modulate = Color(1, 1, 1)
	)
	_update_ui()


func upgrade_speed() -> void:
	speed += 40.0


func upgrade_shorter_words() -> void:
	get_tree().get_first_node_in_group("enemy_manager").reduce_word_length()


# ── Заклинания (делегируем SpellManager) ──────────────────────────────────────
func spell_fire_aura() -> void:
	if spell_manager.has_fire_aura: spell_manager.upgrade_fire_aura()
	else: spell_manager.activate_fire_aura()

func spell_orbitals() -> void:
	if spell_manager.has_orbitals: spell_manager.upgrade_orbitals()
	else: spell_manager.activate_orbitals()

func spell_chain() -> void:
	if spell_manager.has_chain: spell_manager.upgrade_chain()
	else: spell_manager.activate_chain()

func spell_freeze() -> void:
	if spell_manager.has_freeze: spell_manager.upgrade_freeze()
	else: spell_manager.activate_freeze()

func spell_multishot() -> void:
	if spell_manager.has_multishot: spell_manager.upgrade_multishot()
	else: spell_manager.activate_multishot()

func spell_thunder_strike() -> void:
	if spell_manager.has_thunder_strike: spell_manager.upgrade_thunder_strike()
	else: spell_manager.activate_thunder_strike()

func _try_reflect_letter_bullet(letter: String) -> bool:
	var bullets := get_tree().get_nodes_in_group("letter_bullets")
	if bullets.is_empty():
		return false
 
	# Ищем ближайший снаряд с подходящей буквой
	var best_dist := INF
	var best_bullet: Node = null
 
	for bullet in bullets:
		if not is_instance_valid(bullet):
			continue
		if bullet.get_letter().to_lower() == letter.to_lower():
			var dist := global_position.distance_to(bullet.global_position)
			if dist < best_dist:
				best_dist   = dist
				best_bullet = bullet
 
	if best_bullet != null and best_dist < 600.0:
		# Снаряд достаточно близко — отражаем
		best_bullet.try_reflect(letter)
		# Засчитываем как слово (одна буква = одно слово)
		was_completed = true
		emit_signal("word_completed")
		emit_signal("letter_correct")
		_update_input_display()
		return true
 
	return false
