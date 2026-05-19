extends Area2D

# ==========================================
# РЕЛИКВИЯ — особый предмет на карте.
# Игрок должен дойти до неё пешком.
# После подбора разблокирует особое
# улучшение "Громовой удар" в меню прокачки.
# ==========================================

signal collected   # главная сцена слушает этот сигнал

const COLLECT_RADIUS := 40.0
const PULSE_SPEED    := 2.5

var _age: float = 0.0
var _glow: Node2D = null
var _label_node: Label = null


func _ready() -> void:
	collision_layer = 0
	collision_mask  = 0
	add_to_group("relic")
	_build_visual()


func _process(delta: float) -> void:
	_age += delta

	# Пульсация
	if _glow:
		var s := 1.0 + 0.18 * sin(_age * PULSE_SPEED)
		_glow.scale = Vector2(s, s)

	# Вращение звезды
	if _glow:
		_glow.rotation += delta * 1.2

	# Проверяем подбор
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		if global_position.distance_to(player.global_position) < COLLECT_RADIUS:
			_collect()


func _collect() -> void:
	emit_signal("collected")
	_spawn_collect_burst()
	queue_free()


func _spawn_collect_burst() -> void:
	for i in range(8):
		var spark := ColorRect.new()
		spark.size = Vector2(6, 6)
		spark.color = Color(1.0, 0.85, 0.1, 1.0)
		get_tree().current_scene.add_child(spark)
		spark.global_position = global_position + Vector2(randf_range(-5, 5), randf_range(-5, 5))
		var angle := TAU * i / 8.0
		var target := global_position + Vector2(cos(angle), sin(angle)) * 50.0
		var tw := spark.create_tween()
		tw.tween_property(spark, "global_position", target, 0.4)
		tw.parallel().tween_property(spark, "modulate:a", 0.0, 0.4)
		tw.tween_callback(spark.queue_free)


func _build_visual() -> void:
	var root := Node2D.new()
	_glow = root

	# Внешний круг
	var outer := _make_circle(28.0, Color(1.0, 0.85, 0.1, 0.22))
	root.add_child(outer)

	# Средний круг
	var mid := _make_circle(18.0, Color(1.0, 0.85, 0.1, 0.45))
	root.add_child(mid)

	# Ядро — ярко-жёлтый квадрат (имитация кристалла)
	var core := ColorRect.new()
	core.size = Vector2(14, 14)
	core.position = Vector2(-7, -7)
	core.color = Color(1.0, 0.92, 0.15, 1.0)
	root.add_child(core)

	# Внутренний блик
	var shine := ColorRect.new()
	shine.size = Vector2(5, 5)
	shine.position = Vector2(-5, -5)
	shine.color = Color(1.0, 1.0, 0.95, 0.9)
	root.add_child(shine)

	add_child(root)

	# Подпись
	var lbl := Label.new()
	lbl.text = "✦ РЕЛИКВИЯ ✦"
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3, 1.0))
	lbl.position = Vector2(-38, -38)
	add_child(lbl)
	_label_node = lbl

	# Покачивание подписи
	var tw := create_tween().set_loops()
	tw.tween_property(lbl, "position:y", -42.0, 0.9).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(lbl, "position:y", -34.0, 0.9).set_ease(Tween.EASE_IN_OUT)


func _make_circle(radius: float, color: Color) -> Node2D:
	var node := Node2D.new()
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = color
	var pts: PackedVector2Array = []
	for i in range(33):
		var a := TAU * i / 32.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	line.points = pts
	node.add_child(line)
	return node
