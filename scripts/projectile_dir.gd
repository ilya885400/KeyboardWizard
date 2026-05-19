extends Area2D

# ==========================================
# НАПРАВЛЕННЫЙ СНАРЯД (мультивыстрел)
# Летит в фиксированном направлении, не наводится.
# ==========================================

var direction: Vector2 = Vector2.RIGHT
var speed: float = 380.0
var damage: int  = 1
var _hit: bool   = false

@onready var lifetime_timer: Timer = $LifetimeTimer


func _ready() -> void:
	lifetime_timer.wait_time = 3.0
	lifetime_timer.one_shot  = true
	lifetime_timer.timeout.connect(queue_free)
	lifetime_timer.start()
	body_entered.connect(_on_body_entered)


func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()
	rotation  = direction.angle()


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta


func _on_body_entered(body: Node) -> void:
	if _hit:
		return
	if body.is_in_group("enemies"):
		_hit = true
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
