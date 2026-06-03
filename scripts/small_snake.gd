extends CharacterBody2D

# ==========================================
# МАЛЕНЬКАЯ ЗМЕЯ
# Вылупляется из яйца, бежит к игроку.
# Периодически накладывает яд (poison DoT).
# ==========================================

@export var speed: float = 70.0
@export var hp: float = 1.0
@export var exp_reward: int = 2
@export var score_reward: int = 5

# Яд
@export var poison_damage_per_tick: float = 0.2
@export var poison_tick_interval: float = 1.5
@export var poison_duration: float = 6.0
@export var poison_chance: float = 0.4   # 40% шанс нанести яд при касании

var word: String = ""
var typed_count: int = 0
var max_hp: float = 1.0
var player: Node = null
var _dying: bool = false
var _slowed: bool = false
var _base_speed: float = 0.0

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var _label: RichTextLabel   = $WordLabel
@onready var _hp_bar: ProgressBar    = $HPBar


func _ready() -> void:
	add_to_group("enemies")
	max_hp      = hp
	_base_speed = speed
	_assign_new_word()
	_refresh_label()
	_update_hp_bar()
	if _anim:
		_anim.play("walk")


func _physics_process(delta: float) -> void:
	if _dying:
		return
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return

	_check_offscreen_and_reposition()

	var direction = (player.global_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()

	if _anim:
		_anim.flip_h = direction.x < 0

	# Проверяем касание с игроком
	if global_position.distance_to(player.global_position) < 30.0:
		_on_player_contact()


func _check_offscreen_and_reposition() -> void:
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


func _on_player_contact() -> void:
	# Наносим обычный урон через стандартный механизм игрока
	if player.has_method("take_damage"):
		player.take_damage(8)
	# С шансом накладываем яд
	if randf() < poison_chance:
		_apply_poison_to_player()


func _apply_poison_to_player() -> void:
	if not player.has_method("apply_poison"):
		# Если в player.gd нет apply_poison — применяем через тиковый урон напрямую
		_start_poison_ticks()
		return
	player.apply_poison(poison_damage_per_tick, poison_tick_interval, poison_duration)


func _start_poison_ticks() -> void:
	# Визуальный эффект яда на игроке
	if player:
		player.modulate = Color(0.6, 1.0, 0.3)
		get_tree().create_timer(poison_duration).timeout.connect(func():
			if is_instance_valid(player):
				player.modulate = Color(1, 1, 1)
		)

	# Тиковый урон
	var ticks = int(poison_duration / poison_tick_interval)
	for t in range(ticks):
		get_tree().create_timer(poison_tick_interval * (t + 1)).timeout.connect(func():
			if is_instance_valid(player) and player.has_method("take_damage"):
				# Яд игнорирует неуязвимость
				player.current_hp -= poison_damage_per_tick
				player.current_hp = max(0, player.current_hp)
				player._update_ui()
				if player.current_hp <= 0:
					player._die()
				# Зелёные частицы (если есть)
				_spawn_poison_fx(player.global_position)
		)


func _spawn_poison_fx(pos: Vector2) -> void:
	# Простая метка "+яд"
	var lbl = Label.new()
	lbl.text = "☠ яд"
	lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.2))
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.global_position = pos + Vector2(randf_range(-20, 20), -30)
	get_tree().current_scene.add_child(lbl)
	var tw = lbl.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 30, 1.0)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.0)
	tw.tween_callback(lbl.queue_free)


# ─────────────────────────────────────────────────────────────────────────────
# СЛОВО
# ─────────────────────────────────────────────────────────────────────────────
func set_word(new_word: String) -> void:
	word = new_word.to_lower()
	typed_count = 0
	_refresh_label()

func get_word() -> String:
	return word

func highlight_progress(count: int) -> void:
	typed_count = count
	_refresh_label()

func _refresh_label() -> void:
	if _label == null or word.is_empty():
		return
	var result := "[center]"
	for i in range(word.length()):
		var ch = word[i].to_upper()
		if i < typed_count:
			result += "[color=#33ff66]%s[/color]" % ch
		else:
			result += "[color=#aaffaa]%s[/color]" % ch
	result += "[/center]"
	_label.text = result

func _update_hp_bar() -> void:
	if _hp_bar:
		_hp_bar.max_value = max_hp
		_hp_bar.value = hp
		_hp_bar.visible = max_hp > 1

func _assign_new_word() -> void:
	var manager = get_tree().get_first_node_in_group("enemy_manager")
	if manager and manager.has_method("get_random_word"):
		set_word(manager.get_random_word())

# ─────────────────────────────────────────────────────────────────────────────
# УРОН И СМЕРТЬ
# ─────────────────────────────────────────────────────────────────────────────
func take_damage(amount: int) -> void:
	if _dying:
		return
	hp -= amount
	_update_hp_bar()
	if hp <= 0:
		GameEvents.play_sfx.emit("enemy_death")
		_die()
	else:
		GameEvents.play_sfx.emit("enemy_take_damage")
		_flash_hit()

func _flash_hit() -> void:
	modulate = Color(1, 0.4, 0.4)
	get_tree().create_timer(0.2).timeout.connect(func():
		if is_instance_valid(self) and not _dying:
			modulate = Color(1, 1, 1)
	)

func apply_slow(slow_factor: float, duration: float) -> void:
	if _dying:
		return
	speed = _base_speed * slow_factor
	_slowed = true
	modulate = Color(0.5, 0.8, 1.0, 0.85)
	get_tree().create_timer(duration).timeout.connect(_remove_slow)

func _remove_slow() -> void:
	if not is_instance_valid(self) or _dying:
		return
	speed = _base_speed
	_slowed = false
	modulate = Color(1, 1, 1)

func _die() -> void:
	if _dying:
		return
	_dying = true
	remove_from_group("enemies")

	var player_node = get_tree().get_first_node_in_group("player")
	if player_node and player_node.has_method("gain_experience"):
		player_node.gain_experience(exp_reward)

	var manager = get_tree().get_first_node_in_group("enemy_manager")
	if manager and manager.has_method("report_kill"):
		manager.report_kill(score_reward)

	modulate = Color(0.5, 1.0, 0.2)
	get_tree().create_timer(0.1).timeout.connect(func():
		if is_instance_valid(self):
			queue_free()
	)
