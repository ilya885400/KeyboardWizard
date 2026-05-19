extends CharacterBody2D

# ==========================================
# ВРАГ
# ==========================================

@export var speed: float = 80.0
@export var hp: float = 1
@export var exp_reward: int = 5
@export var score_reward: int = 10
@export var enemy_type: String = "skeleton"

var word: String = ""
var typed_count: int = 0
var max_hp: float = 1

const COLOR_DEFAULT := Color(1, 1, 1)
const COLOR_TYPED   := Color(0.2, 1, 0.4)

@onready var label: RichTextLabel = $WordLabel
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hp_bar: ProgressBar = $HPBar

var player: Node = null
var _dying: bool = false

# ── Замедление (заморозка) ────────────────────────────────────────────────────
var _base_speed: float = 0.0
var _slowed: bool = false


func _ready() -> void:
	add_to_group("enemies")
	max_hp      = hp
	_base_speed = speed
	_update_hp_bar()
	_refresh_label()


func _physics_process(_delta: float) -> void:
	if _dying:
		return
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	var direction: Vector2 = (player.global_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()
	anim_sprite.flip_h = direction.x < 0


# ─────────────────────────────────────────
# СЛОВО
# ─────────────────────────────────────────
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
	if label == null or word.is_empty():
		return
	var result := "[center]"
	for i in range(word.length()):
		var ch := word[i].to_upper()
		if i < typed_count:
			result += "[color=#33ff66]%s[/color]" % ch
		else:
			result += "[color=#ffffff]%s[/color]" % ch
	result += "[/center]"
	label.text = result


# ─────────────────────────────────────────
# HP BAR
# ─────────────────────────────────────────
func _update_hp_bar() -> void:
	if hp_bar == null:
		return
	hp_bar.max_value = max_hp
	hp_bar.value     = hp
	hp_bar.visible   = max_hp > 1


# ─────────────────────────────────────────
# УРОН
# ─────────────────────────────────────────
func take_damage(amount: int) -> void:
	if _dying:
		return
	hp -= amount
	_update_hp_bar()
	if hp <= 0:
		_die()
	else:
		_flash_hit()


func _flash_hit() -> void:
	modulate = Color(1, 0.4, 0.4)
	get_tree().create_timer(0.12).timeout.connect(
		func():
			if is_instance_valid(self) and not _dying:
				modulate = _default_modulate()
	)


func _default_modulate() -> Color:
	if _slowed:
		return Color(0.5, 0.8, 1.0, 0.85)   # синеватый при заморозке
	match enemy_type:
		"wraith": return Color(0.85, 0.7, 1.0, 0.9)
		_:        return Color(1, 1, 1)


func _assign_new_word() -> void:
	var manager = get_tree().get_first_node_in_group("enemy_manager")
	if manager and manager.has_method("get_random_word"):
		set_word(manager.get_random_word())


# ─────────────────────────────────────────
# ЗАМЕДЛЕНИЕ (заморозка)
# ─────────────────────────────────────────
func apply_slow(slow_factor: float, duration: float) -> void:
	if _dying:
		return
	speed   = _base_speed * slow_factor
	_slowed = true
	modulate = Color(0.5, 0.8, 1.0, 0.85)   # синеватый оттенок
	# Снимаем замедление через duration секунд
	get_tree().create_timer(duration).timeout.connect(_remove_slow)


func _remove_slow() -> void:
	if not is_instance_valid(self):
		return
	if _dying:
		return
	speed    = _base_speed
	_slowed  = false
	modulate = _default_modulate()


# ─────────────────────────────────────────
# СМЕРТЬ
# ─────────────────────────────────────────
func _die() -> void:
	if _dying:
		return
	_dying = true
	# Немедленно убираем из группы чтобы другие системы не трогали врага
	remove_from_group("enemies")

	var player_node = get_tree().get_first_node_in_group("player")
	if player_node and player_node.has_method("gain_experience"):
		player_node.gain_experience(exp_reward)

	var manager = get_tree().get_first_node_in_group("enemy_manager")
	if manager and manager.has_method("report_kill"):
		manager.report_kill(score_reward)

	# ── Спавн подбираемых предметов ───────────────────────────────────────────
	_spawn_pickups(player_node)

	modulate = Color(1, 0.3, 0.3)
	get_tree().create_timer(0.12).timeout.connect(
		func():
			if is_instance_valid(self):
				queue_free()
	)


func _spawn_pickups(player_node: Node) -> void:
	var pickup_script: Script = load("res://scripts/pickup.gd")
	if pickup_script == null:
		push_error("Enemy: не удалось загрузить res://scripts/pickup.gd")
		return

	# Всегда роняем 1–2 монетки с очками
	var coin_count: int = randi_range(1, 2)
	for i in range(coin_count):
		var pickup := Area2D.new()
		pickup.set_script(pickup_script)
		pickup.pickup_type = "score"
		pickup.score_value = max(1, score_reward / 3)   # треть очков врага
		get_tree().current_scene.add_child(pickup)
		# Разлетаются немного в стороны
		var offset := Vector2(randf_range(-20, 20), randf_range(-20, 20))
		pickup.global_position = global_position + offset

	# Аптечка выпадает с шансом, и только если здоровье игрока не полное
	var drop_health: bool = randf() < 0.25   # 25% шанс
	if drop_health and player_node != null:
		var needs_heal: bool = (player_node.current_hp < player_node.max_hp)
		if needs_heal:
			var hp_pickup := Area2D.new()
			hp_pickup.set_script(pickup_script)
			hp_pickup.pickup_type = "health"
			hp_pickup.heal_value  = 15
			get_tree().current_scene.add_child(hp_pickup)
			hp_pickup.global_position = global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
