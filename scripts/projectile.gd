extends Area2D

# ==========================================
# МАГИЧЕСКИЙ СНАРЯД
# Летит к цели (врагу), при столкновении наносит урон.
# ==========================================

var target: Node = null           # Цель (узел Enemy)
var speed: float = 400.0          # Скорость снаряда
var damage: int = 1               # Урон

# Флаг: уже нанесли урон — исключает двойное попадание
# (через _physics_process distance-check И через body_entered одновременно)
var _hit: bool = false

# Автоудаление если цель исчезла
@onready var lifetime_timer: Timer = $LifetimeTimer


func _ready() -> void:
	# Автоуничтожение через 5 секунд (если промахнулись)
	lifetime_timer.wait_time = 5.0
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(queue_free)
	lifetime_timer.start()

	# Соединяем сигнал столкновения
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		# Цель уничтожена — исчезаем
		queue_free()
		return

	# Летим к цели
	var direction: Vector2 = (target.global_position - global_position).normalized()
	global_position += direction * speed * delta

	# Поворачиваем спрайт в сторону движения
	rotation = direction.angle()

	# Проверяем дистанцию — если достигли цели
	if global_position.distance_to(target.global_position) < 20.0:
		_hit_target()


# ─────────────────────────────────────────
# УСТАНОВКА ЦЕЛИ (вызывается из Player)
# ─────────────────────────────────────────
func set_target(enemy: Node) -> void:
	target = enemy


# ─────────────────────────────────────────
# ПОПАДАНИЕ В ЦЕЛЬ
# ─────────────────────────────────────────
func _hit_target() -> void:
	if _hit:
		return
	_hit = true
	if target != null and is_instance_valid(target):
		if target.has_method("take_damage"):
			target.take_damage(damage)
	queue_free()


func _on_body_entered(body: Node) -> void:
	# Реагируем только на врагов
	if body.is_in_group("enemies"):
		if _hit:
			return
		_hit = true
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
