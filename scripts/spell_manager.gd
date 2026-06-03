extends Node

# ==========================================
# МЕНЕДЖЕР ЗАКЛИНАНИЙ (дочерний узел Player)
# Поддерживает мета-бонусы к радиусам от MetaProgress.
# ==========================================

# ── Флаги активных заклинаний ─────────────────────────────────────────────────
var has_fire_aura:      bool = false
var has_orbitals:       bool = false
var has_chain:          bool = false
var has_freeze:         bool = false
var has_multishot:      bool = false

# ── Базовые параметры ─────────────────────────────────────────────────────────
var fire_aura_radius:   float = 90.0
var fire_aura_damage:   int   = 1
var fire_aura_interval: float = 1.5
var orbital_count:      int   = 3
var orbital_speed:      float = 2.5
var orbital_radius:     float = 70.0
var orbital_damage:     int   = 1
var orbital_respawn_cooldown: float = 3.0

var _orbital_respawn_timer: float = 0.02

var chain_jumps:        int   = 2
var chain_range:        float = 200.0

var freeze_interval:    float = 8.0
var freeze_duration:    float = 2.5
var freeze_slow:        float = 0.3

var multishot_count:    int   = 2
var multishot_angle:    float = 30.0

# ── Мета-бонусы радиусов (задаются из MetaProgress.apply_to_player) ───────────
var meta_freeze_radius_bonus:    float = 0.0
var meta_orbital_radius_bonus:   float = 0.0
var meta_fire_aura_radius_bonus: float = 0.0

# ── Внутренние таймеры ────────────────────────────────────────────────────────
var _aura_timer:    float = 0.0
var _orbital_timer: float = 0.0
var _freeze_timer:  float = 0.0

# ── Орбитальные узлы ──────────────────────────────────────────────────────────
var _orbital_nodes: Array = []
var _orbital_angle: float = 0.0

var player: Node = null
var projectile_scene: PackedScene = null


func _ready() -> void:
	player = get_parent()


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	if has_fire_aura:
		_tick_fire_aura(delta)

	if has_orbitals:
		_tick_orbitals(delta)

	if has_freeze:
		_tick_freeze(delta)


# ── Итоговые радиусы (база + мета-бонус) ──────────────────────────────────────
func get_fire_aura_radius() -> float:
	return fire_aura_radius + meta_fire_aura_radius_bonus

func get_orbital_radius() -> float:
	return orbital_radius + meta_orbital_radius_bonus

func get_freeze_visual_radius() -> float:
	return 500.0   # визуальная волна всегда большая


# ══════════════════════════════════════════════════════════════════════════════
# АУРА ОГНЯ
# ══════════════════════════════════════════════════════════════════════════════
func activate_fire_aura() -> void:
	has_fire_aura = true
	_spawn_aura_visual()


func upgrade_fire_aura() -> void:
	fire_aura_radius   += 15.0
	fire_aura_damage   += 1
	fire_aura_interval  = max(0.8, fire_aura_interval - 0.1)
	var v := player.get_node_or_null("AuraVisual")
	if v:
		v.queue_free()
	_spawn_aura_visual()


func _spawn_aura_visual() -> void:
	var circle := _make_circle_visual(get_fire_aura_radius(), Color(1.0, 0.4, 0.05, 0.18))
	circle.name = "AuraVisual"
	player.add_child(circle)


func _tick_fire_aura(delta: float) -> void:
	_aura_timer += delta
	if _aura_timer < fire_aura_interval:
		return
	_aura_timer = 0.0

	var r := get_fire_aura_radius()
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if player.global_position.distance_to(enemy.global_position) <= r:
			if enemy.has_method("take_damage"):
				enemy.take_damage(fire_aura_damage)


# ══════════════════════════════════════════════════════════════════════════════
# ОРБИТАЛЬ
# ══════════════════════════════════════════════════════════════════════════════
func activate_orbitals() -> void:
	has_orbitals = true
	_rebuild_orbitals()


func upgrade_orbitals() -> void:
	orbital_count += 1
	_rebuild_orbitals()


func _rebuild_orbitals() -> void:
	for n in _orbital_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_orbital_nodes.clear()
	_orbital_respawn_timer = 0.0

	for i in range(orbital_count):
		var orb := _make_orbital_node()
		get_tree().current_scene.add_child(orb)
		_orbital_nodes.append(orb)


func _make_orbital_node() -> Node2D:
	var orb := Node2D.new()

	var sprite := ColorRect.new()
	sprite.size = Vector2(14, 14)
	sprite.position = Vector2(-7, -7)
	sprite.color = Color(0.3, 0.6, 1.0, 0.9)
	orb.add_child(sprite)

	var area := Area2D.new()
	var col  := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	col.shape = shape

	area.collision_layer = 4
	area.collision_mask = 1

	area.add_child(col)
	area.body_entered.connect(_on_orbital_hit.bind(orb))
	area.area_entered.connect(_on_orbital_hit.bind(orb))

	orb.add_child(area)
	return orb


func _tick_orbitals(delta: float) -> void:
	_orbital_nodes = _orbital_nodes.filter(func(node): return is_instance_valid(node))

	_orbital_angle += orbital_speed * delta
	var current_count := _orbital_nodes.size()
	var r := get_orbital_radius()

	if current_count > 0:
		var step: float = TAU / current_count
		for i in range(current_count):
			var orb = _orbital_nodes[i]
			var angle := _orbital_angle + step * i
			orb.global_position = player.global_position + Vector2(cos(angle), sin(angle)) * r

	if current_count < orbital_count:
		_orbital_respawn_timer += delta
		if _orbital_respawn_timer >= orbital_respawn_cooldown:
			_orbital_respawn_timer = 0.0
			var new_orb := _make_orbital_node()
			get_tree().current_scene.add_child(new_orb)
			_orbital_nodes.append(new_orb)


func _on_orbital_hit(node: Node, orb: Node2D) -> void:
	if not is_instance_valid(orb) or orb.is_queued_for_deletion():
		return

	if node.is_in_group("enemies") and node.has_method("take_damage"):
		node.take_damage(orbital_damage)

		if orb in _orbital_nodes:
			_orbital_nodes.erase(orb)
		orb.queue_free()


# ══════════════════════════════════════════════════════════════════════════════
# ЦЕПНАЯ МОЛНИЯ
# ══════════════════════════════════════════════════════════════════════════════
func activate_chain() -> void:
	has_chain = true


func upgrade_chain() -> void:
	chain_jumps += 1
	chain_range += 40.0


func trigger_chain(origin_enemy: Node) -> void:
	if origin_enemy == null or not is_instance_valid(origin_enemy):
		return
	if not has_chain:
		return
	var hit_set: Array = [origin_enemy]
	var current := origin_enemy

	for _i in range(chain_jumps):
		var next := _find_chain_target(current, hit_set)
		if next == null:
			break
		hit_set.append(next)
		if next.has_method("take_damage"):
			next.take_damage(1)
		_spawn_chain_visual(current.global_position, next.global_position)
		current = next


func _find_chain_target(from: Node, exclude: Array) -> Node:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var best: Node = null
	var best_dist := chain_range

	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			return null
		if not is_instance_valid(enemy) or enemy in exclude:
			continue
		var d : float = from.global_position.distance_to(enemy.global_position)
		if d < best_dist:
			best_dist = d
			best = enemy
	return best


func _spawn_chain_visual(from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = Color(0.5, 0.8, 1.0, 0.9)
	var points: PackedVector2Array = []
	var steps := 6
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var p := from.lerp(to, t)
		if i > 0 and i < steps:
			p += Vector2(randf_range(-12, 12), randf_range(-12, 12))
		points.append(p)
	line.points = points
	get_tree().current_scene.add_child.call_deferred(line)
	get_tree().create_timer(0.25).timeout.connect(line.queue_free)


# ══════════════════════════════════════════════════════════════════════════════
# ЗАМОРОЗКА
# ══════════════════════════════════════════════════════════════════════════════
func activate_freeze() -> void:
	has_freeze = true


func upgrade_freeze() -> void:
	freeze_duration += 1.0
	freeze_interval  = max(3.0, freeze_interval - 1.5)
	freeze_slow      = max(0.1, freeze_slow - 0.05)


func _tick_freeze(delta: float) -> void:
	_freeze_timer += delta
	if _freeze_timer < freeze_interval:
		return
	_freeze_timer = 0.0
	_do_freeze()


func _do_freeze() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("apply_slow"):
			enemy.apply_slow(freeze_slow, freeze_duration)
	_spawn_freeze_visual()


func _spawn_freeze_visual() -> void:
	# Радиус визуала учитывает мета-бонус
	var visual_r := 500.0 + meta_freeze_radius_bonus
	var circle := _make_circle_visual(visual_r, Color(0.4, 0.8, 1.0, 0.22))
	circle.global_position = player.global_position
	get_tree().current_scene.add_child(circle)
	var tween := get_tree().create_tween()
	tween.tween_property(circle, "modulate:a", 0.0, 0.5)
	tween.tween_callback(circle.queue_free)


# ══════════════════════════════════════════════════════════════════════════════
# МУЛЬТИВЫСТРЕЛ
# ══════════════════════════════════════════════════════════════════════════════
func activate_multishot() -> void:
	has_multishot = true


func upgrade_multishot() -> void:
	multishot_count += 1
	multishot_angle  = max(15.0, multishot_angle - 5.0)


func trigger_multishot(from_pos: Vector2, primary_target: Node) -> void:
	if not has_multishot or projectile_scene == null:
		return
	if primary_target == null or not is_instance_valid(primary_target):
		return

	var base_dir : Vector2 = (primary_target.global_position - from_pos).normalized()
	var step : float = multishot_angle / max(1, multishot_count - 1) if multishot_count > 1 else multishot_angle
	var start_offset := -multishot_angle / 2.0 if multishot_count > 1 else multishot_angle / 2.0

	for i in range(multishot_count):
		var angle_deg := start_offset + step * i
		var dir : Vector2 = base_dir.rotated(deg_to_rad(angle_deg))
		_spawn_direction_projectile(from_pos, dir)


func _spawn_direction_projectile(from: Vector2, direction: Vector2) -> void:
	var proj = projectile_scene.instantiate()
	proj.set_script(load("res://scripts/projectile_dir.gd"))
	proj.global_position = from
	get_tree().current_scene.add_child(proj)
	if proj.has_method("set_direction"):
		proj.set_direction(direction)


# ══════════════════════════════════════════════════════════════════════════════
# ГРОМОВОЙ УДАР
# ══════════════════════════════════════════════════════════════════════════════
var has_thunder_strike: bool  = false
var thunder_damage:     int   = 8
var thunder_radius:     float = 180.0
var thunder_chance:     float = 0.35


func activate_thunder_strike() -> void:
	has_thunder_strike = true


func upgrade_thunder_strike() -> void:
	thunder_damage += 5
	thunder_radius += 30.0
	thunder_chance  = min(0.7, thunder_chance + 0.1)


func trigger_thunder_strike() -> void:
	if not has_thunder_strike:
		return
	if randf() > thunder_chance:
		return

	var enemies := get_tree().get_nodes_in_group("enemies")
	var hit_any := false
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if player.global_position.distance_to(enemy.global_position) <= thunder_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(thunder_damage)
			_spawn_chain_visual(player.global_position, enemy.global_position)
			hit_any = true

	if hit_any:
		_spawn_thunder_visual()


func _spawn_thunder_visual() -> void:
	var circle := _make_circle_visual(thunder_radius, Color(0.7, 0.85, 1.0, 0.55))
	circle.global_position = player.global_position
	get_tree().current_scene.add_child(circle)
	var tw := get_tree().create_tween()
	tw.tween_property(circle, "modulate:a", 0.0, 0.35)
	tw.tween_callback(circle.queue_free)


func _make_circle_visual(radius: float, color: Color) -> Node2D:
	var node := Node2D.new()
	var line := Line2D.new()
	line.width = 2.5
	line.default_color = color
	var pts: PackedVector2Array = []
	var steps := 48
	for i in range(steps + 1):
		var a := TAU * i / steps
		pts.append(Vector2(cos(a), sin(a)) * radius)
	line.points = pts
	node.add_child(line)
	return node
