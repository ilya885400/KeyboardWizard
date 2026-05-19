extends CanvasLayer

# ==========================================
# КОМПАС РЕЛИКВИИ
# Нажми M — появляется мини-карта с направлением
# и расстоянием до реликвии.
# Если реликвия подобрана — карта показывает "Получено!".
# ==========================================

var _visible: bool  = false
var _relic_pos: Vector2 = Vector2.ZERO
var _relic_collected: bool = false

# Узлы, создаются динамически
var _panel: Panel         = null
var _canvas: Node2D       = null
var _dist_label: Label    = null
var _hint_label: Label    = null
var _status_label: Label  = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build_ui()
	_panel.visible = false


func set_relic_position(pos: Vector2) -> void:
	_relic_pos = pos
	_relic_collected = false


func on_relic_collected() -> void:
	_relic_collected = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			_toggle()
			get_viewport().set_input_as_handled()


func _toggle() -> void:
	_visible = !_visible
	_panel.visible = _visible


func _process(_delta: float) -> void:
	if not _visible:
		return
	_update_compass()


func _update_compass() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return

	if _relic_collected:
		_dist_label.text  = "✦ Реликвия получена! ✦"
		_status_label.text = "Особое улучшение разблокировано"
		_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		# Перерисовываем — просто галочка в центре
		_canvas.queue_redraw()
		return

	var player_pos: Vector2 = player.global_position
	var to_relic: Vector2   = _relic_pos - player_pos
	var dist: float         = to_relic.length()

	_dist_label.text = "Расстояние: %d px" % int(dist)
	_status_label.text = "Направление к реликвии"
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))

	_canvas.queue_redraw()


func _build_ui() -> void:
	# Фоновая панель
	var panel := Panel.new()
	panel.size = Vector2(220, 260)
	# Позиция — правый нижний угол (якорь через anchors)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.position = Vector2(-230, -270)
	add_child(panel)
	_panel = panel

	# Заголовок
	var title := Label.new()
	title.text = "[ КАРТА — M ]"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))
	title.position = Vector2(10, 8)
	panel.add_child(title)

	# Мини-карта (круглый компас) — рисуем через _draw
	var canvas := CompassDraw.new()
	canvas.compass_ref = self
	canvas.position = Vector2(110, 130)   # центр панели
	canvas.size = Vector2(0, 0)
	panel.add_child(canvas)
	_canvas = canvas

	# Дистанция
	var dist_lbl := Label.new()
	dist_lbl.text = "Расстояние: ?"
	dist_lbl.add_theme_font_size_override("font_size", 11)
	dist_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	dist_lbl.position = Vector2(10, 210)
	dist_lbl.size = Vector2(200, 20)
	panel.add_child(dist_lbl)
	_dist_label = dist_lbl

	# Статус
	var status_lbl := Label.new()
	status_lbl.text = "Направление к реликвии"
	status_lbl.add_theme_font_size_override("font_size", 10)
	status_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))
	status_lbl.position = Vector2(10, 230)
	status_lbl.size = Vector2(200, 20)
	panel.add_child(status_lbl)
	_status_label = status_lbl

	# Подсказка
	var hint := Label.new()
	hint.text = "M — закрыть"
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	hint.position = Vector2(10, 246)
	hint.size = Vector2(200, 16)
	panel.add_child(hint)


# ──────────────────────────────────────────────────────────────────────────────
# Внутренний класс — Node2D который рисует компас через _draw
# ──────────────────────────────────────────────────────────────────────────────
class CompassDraw extends Node2D:
	var compass_ref: Node = null   # ссылка на RelicCompass

	const RADIUS := 80.0

	func _draw() -> void:
		if compass_ref == null:
			return

		# Фон круга
		draw_circle(Vector2.ZERO, RADIUS, Color(0.05, 0.05, 0.1, 0.85))
		# Обводка
		draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 48, Color(1.0, 0.85, 0.1, 0.6), 2.0)

		# Крестик сторон света
		var cross_color := Color(0.4, 0.4, 0.5, 0.5)
		draw_line(Vector2(0, -RADIUS + 6), Vector2(0, RADIUS - 6), cross_color, 1.0)
		draw_line(Vector2(-RADIUS + 6, 0), Vector2(RADIUS - 6, 0), cross_color, 1.0)

		# Буквы сторон
		# (draw_string недоступен без шрифта — рисуем маленькие маркеры)
		var tick_color := Color(0.7, 0.7, 0.8, 0.7)
		for i in range(8):
			var a := TAU * i / 8.0
			var p_inner := Vector2(cos(a), sin(a)) * (RADIUS - 10)
			var p_outer := Vector2(cos(a), sin(a)) * (RADIUS - 3)
			draw_line(p_inner, p_outer, tick_color, 1.5)

		# Игрок в центре
		draw_circle(Vector2.ZERO, 5.0, Color(0.3, 0.8, 1.0, 1.0))

		if compass_ref._relic_collected:
			# Рисуем звезду в центре
			_draw_star(Vector2.ZERO, 22.0, Color(0.3, 1.0, 0.5, 1.0))
			return

		# Направление к реликвии
		var player = get_tree().get_first_node_in_group("player")
		if player == null or not is_instance_valid(player):
			return

		var to_relic: Vector2 = compass_ref._relic_pos - player.global_position
		var dist: float       = to_relic.length()

		if dist < 1.0:
			_draw_star(Vector2.ZERO, 22.0, Color(1.0, 0.92, 0.15, 1.0))
			return

		var dir := to_relic.normalized()

		# Пунктирная линия от центра к краю
		var steps := 8
		for i in range(steps):
			if i % 2 == 0:
				var t0 := float(i) / float(steps)
				var t1 := float(i + 1) / float(steps)
				draw_line(dir * (RADIUS - 14) * t0, dir * (RADIUS - 14) * t1,
						  Color(1.0, 0.85, 0.1, 0.55), 1.5)

		# Стрелка
		var arrow_tip  := dir * (RADIUS - 10)
		var arrow_left := dir.rotated(deg_to_rad(140)) * 12.0
		var arrow_right := dir.rotated(deg_to_rad(-140)) * 12.0
		draw_line(Vector2.ZERO, arrow_tip, Color(1.0, 0.92, 0.15, 1.0), 2.5)
		draw_line(arrow_tip, arrow_tip + arrow_left, Color(1.0, 0.92, 0.15, 1.0), 2.0)
		draw_line(arrow_tip, arrow_tip + arrow_right, Color(1.0, 0.92, 0.15, 1.0), 2.0)

		# Точка реликвии (масштабируется по дистанции — чем дальше, тем ближе к краю)
		var map_scale := clamp(dist / 800.0, 0.0, 1.0)
		var dot_pos   := dir * (RADIUS - 14) * map_scale
		draw_circle(dot_pos, 5.0, Color(1.0, 0.92, 0.15, 1.0))
		draw_arc(dot_pos, 7.0, 0, TAU, 16, Color(1.0, 0.92, 0.15, 0.5), 1.5)


	func _draw_star(center: Vector2, size: float, color: Color) -> void:
		var pts: PackedVector2Array = []
		for i in range(10):
			var a := TAU * i / 10.0 - PI / 2.0
			var r := size if i % 2 == 0 else size * 0.45
			pts.append(center + Vector2(cos(a), sin(a)) * r)
		for i in range(pts.size()):
			draw_line(pts[i], pts[(i + 1) % pts.size()], color, 1.8)
