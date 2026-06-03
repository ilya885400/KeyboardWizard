extends Area2D

# ==========================================
# ПОДБИРАЕМЫЙ ПРЕДМЕТ
# Типы: "currency" (монеты), "health" (здоровье)
# ==========================================

@export var pickup_type: String = "currency"
@export var score_value: int    = 5    # монет если тип currency
@export var heal_value: int     = 15   # HP если тип health

const PICKUP_RADIUS   := 30.0
const MAGNET_RADIUS   := 80.0
const MAGNET_SPEED    := 180.0
const LIFETIME        := 12.0

var _age: float     = 0.0
var _sprite: Node2D = null


func _ready() -> void:
	collision_layer = 0
	collision_mask  = 0
	_build_visual()
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.25)


func _process(delta: float) -> void:
	_age += delta

	if _age > LIFETIME - 2.0:
		modulate.a = 0.5 + 0.5 * sin(_age * 10.0)

	if _age >= LIFETIME:
		queue_free()
		return

	var player = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return

	var dist: float = global_position.distance_to(player.global_position)

	if dist < MAGNET_RADIUS:
		var dir: Vector2 = (player.global_position - global_position).normalized()
		global_position += dir * MAGNET_SPEED * delta

	if dist < PICKUP_RADIUS:
		_collect(player)


func _collect(player: Node) -> void:
	match pickup_type:
		"currency", "score":
			# Добавляем монеты через MetaProgress (с учётом бонуса к доходу)
			MetaProgress.add_currency(score_value)
			# Обновляем HUD монет в главной сцене
			var main = get_tree().get_first_node_in_group("main_scene")
			if main and main.has_method("add_score"):
				main.add_score(0)  # обновление HUD без двойного начисления
			# Показываем всплывающий текст
			_spawn_currency_popup(score_value)
		"health":
			if player.has_method("heal"):
				player.heal(heal_value)

	_spawn_collect_effect()
	queue_free()


func _spawn_currency_popup(amount: int) -> void:
	var label := Label.new()
	label.text = "+%d" % int(amount * MetaProgress.get_currency_multiplier())
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	label.global_position = global_position + Vector2(-20, -20)
	get_tree().current_scene.add_child(label)
	var tw := label.create_tween()
	tw.tween_property(label, "position:y", label.position.y - 40, 0.8)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tw.tween_callback(label.queue_free)


func _spawn_collect_effect() -> void:
	var flash := ColorRect.new()
	flash.size = Vector2(18, 18)
	flash.position = global_position - Vector2(9, 9)
	flash.color = Color(1.0, 0.9, 0.2, 0.9) if pickup_type != "health" else Color(0.2, 1.0, 0.4, 0.9)
	get_tree().current_scene.add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.3)
	tw.tween_callback(flash.queue_free)


func _build_visual() -> void:
	var node := Node2D.new()
	_sprite = node

	if pickup_type != "health":
		# Монетка — жёлтый кружок с бликом
		var rect := ColorRect.new()
		rect.size    = Vector2(12, 12)
		rect.position = Vector2(-6, -6)
		rect.color   = Color(1.0, 0.82, 0.05, 1.0)
		node.add_child(rect)

		var shine := ColorRect.new()
		shine.size    = Vector2(4, 4)
		shine.position = Vector2(-3, -5)
		shine.color   = Color(1.0, 1.0, 0.9, 0.8)
		node.add_child(shine)

		# Буква "M" как маркер монетки
		var lbl := Label.new()
		lbl.text = "¢"
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.4, 0.0))
		lbl.position = Vector2(-5, -7)
		node.add_child(lbl)
	else:
		# Красное сердечко
		var left := ColorRect.new()
		left.size    = Vector2(8, 8)
		left.position = Vector2(-8, -6)
		left.color   = Color(0.95, 0.15, 0.2, 1.0)
		node.add_child(left)

		var right := ColorRect.new()
		right.size    = Vector2(8, 8)
		right.position = Vector2(0, -6)
		right.color   = Color(0.95, 0.15, 0.2, 1.0)
		node.add_child(right)

		var bottom := ColorRect.new()
		bottom.size    = Vector2(10, 9)
		bottom.position = Vector2(-5, -1)
		bottom.color   = Color(0.95, 0.15, 0.2, 1.0)
		node.add_child(bottom)

	add_child(node)

	var tw := create_tween().set_loops()
	tw.tween_property(node, "position:y", -4.0, 0.7).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "position:y",  4.0, 0.7).set_ease(Tween.EASE_IN_OUT)
