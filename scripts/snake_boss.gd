extends Node2D

# ==========================================
# БОСС — ЗМЕЯ
# Состоит из головы + N сегментов тела + хвост.
# Ползает вокруг игрока, периодически откладывает яйца.
# ==========================================

@export var speed: float = 120.0
@export var orbit_radius: float = 220.0
@export var num_body_segments: int = 8
@export var egg_interval: float = 6.0
@export var egg_scene: PackedScene
@export var hp: int = 5
@export var exp_reward: int = 80
@export var score_reward: int = 200

# Слово для печатного боя
var word: String = ""
var typed_count: int = 0
var max_hp: int = 5

# Угол вокруг игрока (радианы)
var _orbit_angle: float = 0.0
# Таймер яиц
var _egg_timer: float = 0.0
# Позиции прошлых сегментов (след)
var _trail: Array[Vector2] = []
const TRAIL_SPACING: float = 28.0   # расстояние между сегментами в пикселях

var player: Node = null
var _dying: bool = false
var _slowed: bool = false
var _base_speed: float = 0.0

# Дочерние узлы сегментов (спавним в _ready)
var _head_node: Node2D = null
var _body_nodes: Array[Node2D] = []
var _tail_node: Node2D = null

@onready var _word_label: RichTextLabel = $WordLabel
@onready var _hp_bar: ProgressBar       = $HPBar

signal boss_died

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("enemies")
	add_to_group("snake_boss")
	max_hp      = hp
	_base_speed = speed
	_orbit_angle = randf() * TAU

	# Инициализируем трейл достаточно длинным
	var total_segments = 1 + num_body_segments + 1   # head + body + tail
	for i in range(total_segments * int(TRAIL_SPACING) + 10):
		_trail.append(global_position)

	_spawn_visual_segments()
	_update_hp_bar()
	_refresh_label()


func _spawn_visual_segments() -> void:
	# Голова
	_head_node = _make_anim_node("snake_head", 4, 3.0, "mouth_open")
	add_child(_head_node)

	# Сегменты тела — скрыты до первого выхода из головы
	for i in range(num_body_segments):
		var seg = _make_anim_node("snake_body", 3, 6.0, "idle")
		seg.visible = false
		seg.scale*=0.7
		add_child(seg)
		_body_nodes.append(seg)

	# Хвост — скрыт до первого выхода
	_tail_node = _make_anim_node("snake_tail", 2, 6.0, "idle")
	_tail_node.visible = false
	_tail_node.scale.x*=-0.7
	_tail_node.scale.y*=0.7

	add_child(_tail_node)


func _make_anim_node(sprite_name: String, frame_count: int, fps: float, anim_name: String) -> AnimatedSprite2D:
	var tex_path = "res://pixel_assets/pixel_enemies/snake_boss/%s.png" % sprite_name
	var tex: Texture2D = load(tex_path)

	var frames = SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation(anim_name)
	frames.set_animation_loop(anim_name, true)
	frames.set_animation_speed(anim_name, fps)

	for i in range(frame_count):
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * 32, 0, 32, 32)
		frames.add_frame(anim_name, atlas)

	var anim_spr = AnimatedSprite2D.new()
	anim_spr.sprite_frames = frames
	anim_spr.scale = Vector2(3.0, 3.0)
	anim_spr.play(anim_name)
	return anim_spr


# ─────────────────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if _dying:
		return

	_find_player()
	if player == null:
		return

	_check_offscreen_and_reposition()

	# Орбита вокруг игрока
	_orbit_angle += (speed / orbit_radius) * delta
	if _orbit_angle > TAU:
		_orbit_angle -= TAU

	var target_pos = player.global_position + Vector2(
		cos(_orbit_angle) * orbit_radius,
		sin(_orbit_angle) * orbit_radius * 0.6   # немного приплюснем по Y
	)

	# Плавно движемся к целевой точке
	var dir = (target_pos - global_position).normalized()
	var dist = global_position.distance_to(target_pos)
	var move_speed = min(speed, dist * 4.0)
	global_position += dir * move_speed * delta

	# Добавляем позицию в трейл
	_trail.push_front(global_position)
	if _trail.size() > 300:
		_trail.pop_back()

	# Обновляем позиции сегментов
	_update_segment_positions()

	# Таймер яиц
	_egg_timer += delta
	if _egg_timer >= egg_interval:
		_egg_timer = 0.0
		_lay_egg()


func _update_segment_positions() -> void:
	var total_segs = 1 + num_body_segments + 1

	# Голова — это сам Node2D
	if _head_node:
		_head_node.global_position = global_position
		# Поворот головы в направлении движения
		var vel = global_position - (_trail[1] if _trail.size() > 1 else global_position)
		if vel.length() > 0.1:
			_head_node.rotation = vel.angle()
			_head_node.scale.x = 3.0   # flip при необходимости

	# Сегменты тела — показываем когда трейл достаточно длинный
	for i in range(num_body_segments):
		var trail_idx = int((i + 1) * TRAIL_SPACING)
		if trail_idx < _trail.size() and _body_nodes[i] != null:
			# Показываем сегмент только когда он впервые вышел из зоны головы
			if not _body_nodes[i].visible:
				var dist_to_head = _trail[trail_idx].distance_to(global_position)
				if dist_to_head > TRAIL_SPACING * 0.8:
					_body_nodes[i].visible = true
			_body_nodes[i].global_position = _trail[trail_idx]
			# Ориентация сегмента
			var prev_idx = max(0, trail_idx - 5)
			if prev_idx < _trail.size():
				var dir_vec = _trail[prev_idx] - _trail[trail_idx]
				if dir_vec.length() > 0.1:
					_body_nodes[i].rotation = dir_vec.angle()

	# Хвост
	var tail_trail_idx = int((num_body_segments + 1) * TRAIL_SPACING)
	if tail_trail_idx < _trail.size() and _tail_node != null:
		if not _tail_node.visible:
			var dist_to_head = _trail[tail_trail_idx].distance_to(global_position)
			if dist_to_head > TRAIL_SPACING * 0.8:
				_tail_node.visible = true
		_tail_node.global_position = _trail[tail_trail_idx]
		var prev_idx = max(0, tail_trail_idx - 5)
		if prev_idx < _trail.size():
			var dir_vec = _trail[prev_idx] - _trail[tail_trail_idx]
			if dir_vec.length() > 0.1:
				_tail_node.rotation = dir_vec.angle()


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
		var new_pos: Vector2
		match side:
			0: new_pos = cam_center + Vector2(randf_range(-half_w, half_w), -(half_h + margin))
			1: new_pos = cam_center + Vector2(randf_range(-half_w, half_w),  (half_h + margin))
			2: new_pos = cam_center + Vector2(-(half_w + margin), randf_range(-half_h, half_h))
			3: new_pos = cam_center + Vector2( (half_w + margin), randf_range(-half_h, half_h))
		global_position = new_pos
		# Сбрасываем трейл — сегменты снова прячем до выхода из головы
		_trail.fill(new_pos)
		for seg in _body_nodes:
			if is_instance_valid(seg):
				seg.visible = false
		if is_instance_valid(_tail_node):
			_tail_node.visible = false


func _find_player() -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")


# ─────────────────────────────────────────────────────────────────────────────
# ЯЙЦо
# ─────────────────────────────────────────────────────────────────────────────
func _lay_egg() -> void:
	if egg_scene == null:
		push_warning("SnakeBoss: egg_scene не назначена!")
		return
	# Откладываем яйцо в хвостовой позиции
	var egg_pos = global_position
	if _trail.size() > int(num_body_segments * TRAIL_SPACING):
		egg_pos = _trail[int(num_body_segments * TRAIL_SPACING)]
	egg_pos += Vector2(randf_range(-20, 20), randf_range(-20, 20))

	var egg = egg_scene.instantiate()
	get_tree().current_scene.add_child(egg)
	egg.global_position = egg_pos
	egg.player = player

	# Визуальный сигнал — открыть рот
	if _head_node and _head_node.sprite_frames:
		_head_node.play("mouth_open")
		get_tree().create_timer(0.5).timeout.connect(func():
			if is_instance_valid(_head_node):
				_head_node.play("idle")
		)


# ─────────────────────────────────────────────────────────────────────────────
# СЛОВО / УРОН
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
	if _word_label == null or word.is_empty():
		return
	var result := "[center]"
	for i in range(word.length()):
		var ch := word[i].to_upper()
		if i < typed_count:
			result += "[color=#33ff66]%s[/color]" % ch
		else:
			result += "[color=#ffff00]%s[/color]" % ch
	result += "[/center]"
	_word_label.text = result

func _update_hp_bar() -> void:
	if _hp_bar == null:
		return
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_bar.visible = true

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

func _assign_new_word() -> void:
	var manager = get_tree().get_first_node_in_group("enemy_manager")
	if manager and manager.has_method("get_random_word"):
		set_word(manager.get_random_word())

# ─────────────────────────────────────────────────────────────────────────────
# ЗАМЕДЛЕНИЕ
# ─────────────────────────────────────────────────────────────────────────────
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

# ─────────────────────────────────────────────────────────────────────────────
# СМЕРТЬ
# ─────────────────────────────────────────────────────────────────────────────
func _die() -> void:
	if _dying:
		return
	_dying = true
	remove_from_group("enemies")
	remove_from_group("snake_boss")

	emit_signal("boss_died")

	var player_node = get_tree().get_first_node_in_group("player")
	if player_node and player_node.has_method("gain_experience"):
		player_node.gain_experience(exp_reward)

	var manager = get_tree().get_first_node_in_group("enemy_manager")
	if manager and manager.has_method("report_kill"):
		manager.report_kill(score_reward)

	# Уничтожаем все сегменты
	for node in _body_nodes:
		if is_instance_valid(node):
			node.queue_free()
	if is_instance_valid(_head_node): _head_node.queue_free()
	if is_instance_valid(_tail_node): _tail_node.queue_free()

	modulate = Color(1, 0.3, 0.3)
	get_tree().create_timer(0.2).timeout.connect(func():
		if is_instance_valid(self):
			queue_free()
	)
