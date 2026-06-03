extends Node2D

# ==========================================
# ЯЙЦо ЗМЕИ
# Лежит на земле, анимируется (целое → трещина → вылупление),
# затем спавнит маленькую змею.
# ==========================================

@export var hatch_time: float = 4.0      # секунд до вылупления
@export var small_snake_scene: PackedScene

var player: Node = null
var _timer: float = 0.0
var _hatched: bool = false
var _anim: AnimatedSprite2D = null

# Фазы: 0=целое, 1=трещины (hatch_time*0.5), 2=светится (hatch_time*0.8)
var _phase: int = 0

func _ready() -> void:
	add_to_group("snake_eggs")
	_anim = $AnimatedSprite2D
	if _anim:
		_play_phase(0)
	# Небольшое случайное смещение старта
	_timer = randf_range(0.0, 0.5)


func _process(delta: float) -> void:
	if _hatched:
		return
	_timer += delta

	# Переход фаз
	if _phase == 0 and _timer >= hatch_time * 0.5:
		_phase = 1
		_play_phase(1)
	elif _phase == 1 and _timer >= hatch_time * 0.8:
		_phase = 2
		_play_phase(2)
	elif _timer >= hatch_time:
		_hatch()


func _play_phase(phase: int) -> void:
	if _anim == null:
		return
	# Анимированный спрайт имеет 3 анимации: "whole", "cracked", "hatching"
	match phase:
		0: _anim.play("whole")
		1: _anim.play("cracked")
		2: _anim.play("hatching")


func _hatch() -> void:
	_hatched = true
	remove_from_group("snake_eggs")

	# Вспышка
	modulate = Color(2, 2, 0.5)
	get_tree().create_timer(0.1).timeout.connect(func():
		if is_instance_valid(self):
			modulate = Color(1, 1, 1)
	)

	# Спавн маленькой змеи
	if small_snake_scene != null:
		var snake = small_snake_scene.instantiate()
		get_tree().current_scene.add_child(snake)
		snake.global_position = global_position
		if player != null:
			snake.player = player
	else:
		push_warning("SnakeEgg: small_snake_scene не назначена!")

	get_tree().create_timer(0.15).timeout.connect(func():
		if is_instance_valid(self):
			queue_free()
	)
