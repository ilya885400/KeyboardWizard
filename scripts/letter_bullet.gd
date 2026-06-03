extends Area2D

# ==========================================
# СНАРЯД-БУКВА (LetterBullet)
#
# Выпускается Одержимой Книгой. Летит к игроку.
# Если игрок нажимает правильную клавишу —
# снаряд отражается и уничтожается (засчитывается
# как одно слово). Если долетает до игрока —
# наносит урон.
# ==========================================

@export var speed: float       = 180.0
@export var damage: int        = 8
@export var lifetime: float    = 6.0

var _letter: String = ""
var _target: Node   = null  # игрок
var _shooter: Node  = null  # книга-босс (для избежания самопопадания)
var _direction: Vector2 = Vector2.ZERO
var _lifetime_left: float = 0.0
var _destroyed: bool = false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var letter_label: RichTextLabel    = $LetterLabel


func _ready() -> void:
	add_to_group("letter_bullets")
	_lifetime_left = lifetime
	body_entered.connect(_on_body_entered)
	if anim:
		anim.play("spin")


func setup(letter: String, target: Node, shooter: Node) -> void:
	_letter    = letter
	_target    = target
	_shooter   = shooter

	if letter_label:
		letter_label.text = letter.to_upper()

	# Направление к игроку
	if target and is_instance_valid(target):
		_direction = (target.global_position - global_position).normalized()
	else:
		_direction = Vector2.RIGHT


func _physics_process(delta: float) -> void:
	if _destroyed:
		return

	_lifetime_left -= delta
	if _lifetime_left <= 0:
		_destroy_quietly()
		return

	global_position += _direction * speed * delta

	# Слабое самонаведение — подправляем направление к игроку
	if _target and is_instance_valid(_target):
		var to_player = (_target.global_position - global_position).normalized()
		_direction = _direction.lerp(to_player, 0.03).normalized()


func _on_body_entered(body: Node) -> void:
	if _destroyed:
		return
	if body == _shooter:
		return

	if body.is_in_group("player"):
		# Игрок не отразил — наносим урон
		if body.has_method("take_damage"):
			body.take_damage(damage)
		_destroy_with_effect(Color(1, 0.3, 0.3))


# ─────────────────────────────────────────
# ОТРАЖЕНИЕ ИГРОКОМ
# Вызывается из player.gd или специального
# обработчика когда игрок нажал нужную букву.
# ─────────────────────────────────────────
func try_reflect(pressed_letter: String) -> bool:
	if _destroyed:
		return false
	if pressed_letter.to_lower() == _letter.to_lower():
		_reflect_success()
		return true
	return false


func get_letter() -> String:
	return _letter


func _reflect_success() -> void:
	# Эффект отражения — яркая вспышка и исчезновение
	_destroy_with_effect(Color(1.5, 1.5, 0.3))


func _destroy_with_effect(flash_color: Color) -> void:
	_destroyed = true
	set_physics_process(false)

	# Вспышка
	modulate = flash_color
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector2(2.0, 2.0), 0.15)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)


func _destroy_quietly() -> void:
	_destroyed = true
	queue_free()
