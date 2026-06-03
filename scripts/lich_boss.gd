extends Node2D

# ==========================================
# ЛИЧ — ФИНАЛЬНЫЙ БОСС
# ==========================================
# Условие победы: игрок вводит длинное стихотворение.
# Нет полоски здоровья — только «фаза» (0..3).
#
# Способности:
#   1. heal_random_enemy() — каждые HEAL_INTERVAL секунд восстанавливает
#      случайному врагу 1 HP + анимация частиц.
#   2. Пассивно занимает весь экран (растянут через CanvasLayer).
# ==========================================

const HEAL_INTERVAL  := 6.0    # секунд между лечениями
const POEM_EN := """To be, or not to be, that is the question:
Whether 'tis nobler in the mind to suffer
The slings and arrows of outrageous fortune,
Or to take arms against a sea of troubles
And by opposing end them."""

const POEM_RU := """Буря мглою небо кроет,
вихри снежные крутя;
то, как зверь, она завоет,
то заплачет, как дитя."""

# Нормализованные строчные версии для сравнения
var _poem_en_normalized: String = ""
var _poem_ru_normalized: String = ""

# Текущее стихотворение (зависит от языка урока)
var _target_poem: String   = ""
var _typed_buffer: String  = ""  # что уже напечатал игрок (без ошибок)
var _progress: int         = 0   # сколько символов верно введено

var _heal_timer: float = 0.0
var _phase: int        = 0   # 0=idle, 1=active, 2=casting_heal, 3=dying

# Ссылки
var player: Node = null
var _anim: AnimatedSprite2D = null
var _overlay_sprite: Sprite2D = null  # полупрозрачный спрайт на весь экран
var _poem_label: RichTextLabel = null
var _title_label: Label        = null

# Частицы для анимации лечения
var _particle_pool: Array = []

signal lich_defeated


func _ready() -> void:
	add_to_group("lich_boss")
	add_to_group("enemies")   # чтобы другие системы его видели

	_build_overlay()
	_build_ui()
	_play_anim("idle")

	# Нормализуем стихи
	_poem_en_normalized = _normalize(POEM_EN)
	_poem_ru_normalized = _normalize(POEM_RU)

	# Определяем язык: берём из enemy_manager
	var mgr = get_tree().get_first_node_in_group("enemy_manager")
	if mgr and mgr.lesson_lang == "ru":
		_target_poem = _poem_ru_normalized
	else:
		_target_poem = _poem_en_normalized

	_skip_non_typeable()   # пропускаем ведущие не-буквы если есть
	_refresh_poem_label()

	# Подключаемся к вводу игрока
	var pl = get_tree().get_first_node_in_group("player")
	if pl:
		player = pl
		# Подключаемся к сигналам ввода если они есть
		if pl.has_signal("word_completed"):
			pl.word_completed.connect(_on_word_completed)

	# Таймер появления
	_phase = 1
	modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 1.5)


func _process(delta: float) -> void:
	if _phase == 0 or _phase == 3:
		return

	# Хилим случайного врага каждые HEAL_INTERVAL сек
	_heal_timer += delta
	if _heal_timer >= HEAL_INTERVAL:
		_heal_timer = 0.0
		_do_heal_enemy()

	# Лёгкое покачивание оверлея
	if _overlay_sprite:
		_overlay_sprite.modulate.a = 0.18 + sin(Time.get_ticks_msec() * 0.001) * 0.04


# ─────────────────────────────────────────
# ВВОД ИГРОКА — перехватываем _unhandled_input
# ─────────────────────────────────────────
func _unhandled_key_input(event: InputEvent) -> void:
	if _phase != 1:
		return
	if not event is InputEventKey:
		return
	if not event.pressed:
		return

	var ch := ""
	# Получаем символ
	if event.unicode != 0:
		ch = char(event.unicode).to_lower()
	else:
		return   # пробел/Enter/пунктуацию игрок не вводит — они пропускаются автоматически

	# Сравниваем с ожидаемым символом
	var expected := _target_poem[_progress] if _progress < _target_poem.length() else ""

	if ch == expected:
		_progress += 1
		_typed_buffer += ch
		_skip_non_typeable()   # автоматически перепрыгиваем пробелы и пунктуацию
		_refresh_poem_label()
		# Небольшая вспышка спрайта
		if _overlay_sprite:
			var flash_tw = create_tween()
			flash_tw.tween_property(_overlay_sprite, "modulate:a", 0.35, 0.06)
			flash_tw.tween_property(_overlay_sprite, "modulate:a", 0.18, 0.12)

		if _progress >= _target_poem.length():
			_start_death()
	else:
		# Ошибка — небольшая подсветка красным
		if _overlay_sprite:
			_overlay_sprite.modulate = Color(1.5, 0.3, 0.3, 0.3)
			get_tree().create_timer(0.15).timeout.connect(func():
				if is_instance_valid(_overlay_sprite):
					_overlay_sprite.modulate = Color(1,1,1,0.18)
			)


# ─────────────────────────────────────────
# ЛЕЧЕНИЕ ВРАГА
# ─────────────────────────────────────────
func _do_heal_enemy() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	# Убираем себя из списка
	var targets := enemies.filter(func(e): return e != self and is_instance_valid(e) and e.has_method("take_damage"))
	if targets.is_empty():
		return

	var target = targets.pick_random()
	# Восстанавливаем 1 HP
	if target.has_method("_heal"):
		target.hp+=1
	elif "hp" in target and "max_hp" in target:
		target.hp = min(target.hp + 1, target.max_hp)
		if target.has_method("_update_hp_bar"):
			target._update_hp_bar()

	_play_anim("heal")
	get_tree().create_timer(0.8).timeout.connect(func():
		if is_instance_valid(self) and _phase == 1:
			_play_anim("idle")
	)

	# Анимация частиц: зелёный луч от Лича к врагу
	_spawn_heal_particles(target.global_position)


func _spawn_heal_particles(target_pos: Vector2) -> void:
	# Создаём CPUParticles2D прямо на сцене
	var particles := CPUParticles2D.new()
	get_tree().current_scene.add_child(particles)

	# Стартуем из центра экрана (позиция Лича условно = центр камеры)
	var cam_center := Vector2(
		get_viewport().get_visible_rect().size / 2
	)
	# Переводим в мировые координаты через камеру
	var cam = get_tree().get_first_node_in_group("player")
	var world_center = cam.global_position if cam else Vector2.ZERO
	particles.global_position = world_center

	particles.emitting          = true
	particles.one_shot          = true
	particles.lifetime          = 0.7
	particles.amount            = 20
	particles.spread            = 15.0
	particles.gravity           = Vector2.ZERO
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 160.0
	particles.color             = Color(0.2, 1.0, 0.4, 0.9)
	particles.scale_amount_min  = 3.0
	particles.scale_amount_max  = 6.0
	# Направляем к цели
	var dir = (target_pos - world_center).normalized()
	particles.direction         = dir

	# Метка "+HP" над целью
	var hp_label := Label.new()
	hp_label.text = "+1 HP"
	hp_label.add_theme_font_size_override("font_size", 18)
	hp_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	get_tree().current_scene.add_child(hp_label)
	hp_label.global_position = target_pos + Vector2(-20, -30)
	var tw = hp_label.create_tween()
	tw.tween_property(hp_label, "position:y", hp_label.position.y - 30, 0.8)
	tw.parallel().tween_property(hp_label, "modulate:a", 0.0, 0.8)
	tw.tween_callback(hp_label.queue_free)

	# Удаляем частицы
	get_tree().create_timer(1.2).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)


# ─────────────────────────────────────────
# СМЕРТЬ ЛИЧА
# ─────────────────────────────────────────
func _start_death() -> void:
	_phase = 3
	_play_anim("attack")  # финальная поза

	# Большой флеш экрана
	var flash := ColorRect.new()
	flash.color = Color(0.6, 0.2, 1.0, 0.0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.z_index = 100
	get_tree().current_scene.add_child(flash)
	var tw_flash = flash.create_tween()
	tw_flash.tween_property(flash, "color:a", 0.9, 0.3)
	tw_flash.tween_property(flash, "color:a", 0.0, 0.8)
	tw_flash.tween_callback(flash.queue_free)

	# Затухание оверлея
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 1.2)
	tw.tween_callback(_finish_death)

	# Объявление победы
	_show_victory_text()

	emit_signal("lich_defeated")

	# Сообщаем менеджеру очки
	var mgr = get_tree().get_first_node_in_group("enemy_manager")
	if mgr and mgr.has_method("report_kill"):
		mgr.report_kill(500)


func _finish_death() -> void:
	remove_from_group("enemies")
	remove_from_group("lich_boss")
	if is_instance_valid(_poem_label): _poem_label.queue_free()
	if is_instance_valid(_title_label): _title_label.queue_free()
	queue_free()


func _show_victory_text() -> void:
	var label := Label.new()
	label.text = "ЛИЧ ПОВЕРЖЕН! ☠\n+500 очков"
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color(0.8, 0.4, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.z_index = 200
	get_tree().current_scene.add_child(label)
	var tw = label.create_tween()
	tw.tween_property(label, "scale", Vector2(1.4, 1.4), 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "scale", Vector2(1.0, 1.0), 0.15)
	tw.tween_interval(1.5)
	tw.tween_property(label, "modulate:a", 0.0, 0.8)
	tw.tween_callback(label.queue_free)


# ─────────────────────────────────────────
# ПОСТРОЕНИЕ ОВЕРЛЕЯ (спрайт на весь экран)
# ─────────────────────────────────────────
func _build_overlay() -> void:
	# CanvasLayer с z=5 чтобы быть поверх игры, но под UI
	var canvas := CanvasLayer.new()
	canvas.layer = 5
	add_child(canvas)

	_overlay_sprite = Sprite2D.new()
	_overlay_sprite.name = "LichOverlay"

	# Загружаем спрайтшит (назначь путь к ресурсу в проекте)
	var tex := load("res://pixel_assets/bosses/lich_spritesheet.png")
	if tex == null:
		# Fallback: генерируем простую текстуру-заглушку программно
		tex = _make_fallback_texture()

	_overlay_sprite.texture = tex
	# Растягиваем на весь viewport
	var vp_size := Vector2(1152, 648)  # замени на реальный размер вьюпорта
	if get_viewport():
		vp_size = get_viewport().get_visible_rect().size
	# Берём первый кадр (64px широкий из 320px листа)
	_overlay_sprite.region_enabled = true
	_overlay_sprite.region_rect    = Rect2(0, 0, 64, 64)
	var scale_x := vp_size.x / 64.0
	var scale_y := vp_size.y / 64.0
	_overlay_sprite.scale   = Vector2(scale_x, scale_y)
	_overlay_sprite.centered = false
	_overlay_sprite.position = Vector2.ZERO
	_overlay_sprite.modulate = Color(1, 1, 1, 0.18)
	_overlay_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # пиксельный
	canvas.add_child(_overlay_sprite)


func _make_fallback_texture() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.25, 0.05, 0.5, 0.6))
	# Рисуем простые глаза
	for x in range(24, 28):
		img.set_pixel(x, 20, Color(0.5, 0.2, 1.0, 1.0))
	for x in range(36, 40):
		img.set_pixel(x, 20, Color(0.5, 0.2, 1.0, 1.0))
	return ImageTexture.create_from_image(img)


# ─────────────────────────────────────────
# UI — метка со стихотворением
# ─────────────────────────────────────────
func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	# Заголовок
	_title_label = Label.new()
	_title_label.text = "☠  ЛИЧ — ВВЕДИ СТИХОТВОРЕНИЕ  ☠"
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(0.8, 0.4, 1.0))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title_label.offset_top = 8
	canvas.add_child(_title_label)

	# Поле стихотворения
	_poem_label = RichTextLabel.new()
	_poem_label.bbcode_enabled = true
	_poem_label.fit_content    = true
	_poem_label.scroll_active  = false
	_poem_label.add_theme_font_size_override("normal_font_size", 18)
	_poem_label.custom_minimum_size = Vector2(700, 0)
	_poem_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_poem_label.offset_left  = -350
	_poem_label.offset_right = 350
	_poem_label.offset_top   = -80
	_poem_label.offset_bottom = 120
	canvas.add_child(_poem_label)


func _refresh_poem_label() -> void:
	if _poem_label == null:
		return
	var raw := _get_display_poem()
	var result := "[center]"
	for i in range(raw.length()):
		var ch := raw[i]
		if ch == "\n":
			result += "\n"
			continue
		if i < _progress:
			result += "[color=#33ff66]%s[/color]" % ch
		elif i == _progress:
			result += "[color=#ffff44][bgcolor=#441188]%s[/bgcolor][/color]" % ch
		else:
			result += "[color=#aaaaaa]%s[/color]" % ch
	result += "[/center]"
	_poem_label.text = result


func _get_display_poem() -> String:
	# Возвращаем оригинал с переносами (для отображения)
	var mgr = get_tree().get_first_node_in_group("enemy_manager")
	if mgr and mgr.lesson_lang == "ru":
		return POEM_RU
	return POEM_EN


# ─────────────────────────────────────────
# АНИМАЦИЯ
# ─────────────────────────────────────────
func _play_anim(anim_name: String) -> void:
	if _anim == null:
		return
	if _anim.sprite_frames and _anim.sprite_frames.has_animation(anim_name):
		_anim.play(anim_name)


# ─────────────────────────────────────────
# ВСПОМОГАТЕЛЬНЫЕ
# ─────────────────────────────────────────

# Перематывает _progress через символы которые не нужно вводить:
# пробелы, переносы строк, знаки препинания.
# Вызывать ПОСЛЕ каждого засчитанного символа.
func _skip_non_typeable() -> void:
	while _progress < _target_poem.length():
		var ch := _target_poem[_progress]
		if ch.unicode_at(0) < 32:          # управляющие символы (\n, \r…)
			_progress += 1
			continue
		if not ch.strip_edges().is_empty() and ch.to_lower() != ch.to_upper():
			# Буква — остановить перемотку
			break
		# Символ не является буквой (пробел, пунктуация, цифра) — пропустить
		_progress += 1


func _normalize(text: String) -> String:
	# Переводим в нижний регистр, убираем лишние пробелы
	var s := text.strip_edges().to_lower()
	# Схлопываем множественные пробелы
	while "  " in s:
		s = s.replace("  ", " ")
	return s


# ─────────────────────────────────────────
# СКРЫТЬ UI (при проигрыше / выходе в настройки)
# ─────────────────────────────────────────
func hide_ui() -> void:
	_phase = 0   # остановить процессинг
	# Скрываем весь узел вместе со всеми CanvasLayer-детьми
	visible = false
	# Дополнительно скрываем labels если они в отдельных CanvasLayer
	if is_instance_valid(_poem_label):  _poem_label.visible  = false
	if is_instance_valid(_title_label): _title_label.visible = false


# Публичный метод — нет HP, Лич не умирает от урона
func take_damage(_amount: int) -> void:
	pass   # неуязвим — только стих его уничтожает


# Совместимость с word-системой игрока (если нужна)
func set_word(_w: String) -> void:
	pass

func get_word() -> String:
	return ""


func _on_word_completed() -> void:
	pass  # зарезервировано для будущих механик
