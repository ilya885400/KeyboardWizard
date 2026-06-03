extends Node

# ==========================================
# МЕТА-ПРОГРЕССИЯ (Autoload: MetaProgress)
# Хранит валюту и постоянные улучшения между сессиями.
# Добавь в Project → Project Settings → Autoload:g
#   Path: res://scripts/MetaProgress.gd
#   Name: MetaProgress
# ==========================================

const SAVE_PATH := "user://meta_progress.json"

# ── Валюта ────────────────────────────────────────────────────────────────────
var currency: int = 0

# ── Уровни улучшений (0 = не куплено) ────────────────────────────────────────
var upgrades: Dictionary = {
	"max_hp":           0,   # +10 HP за уровень
	"speed":            0,   # +15 скорости за уровень
	"projectile_size":  0,   # +20% размера снаряда за уровень
	"freeze_radius":    0,   # +30 к радиусу заморозки
	"orbital_radius":   0,   # +20 к радиусу орбиталей
	"fire_aura_radius": 0,   # +20 к радиусу огненной ауры
	"currency_bonus":   0,   # +25% монет с врагов за уровень
	"revive_chance":    0,   # шанс воскреснуть (макс 3 уровня = 75%)
}

# ── Максимальные уровни улучшений ─────────────────────────────────────────────
const MAX_LEVELS: Dictionary = {
	"max_hp":           10,
	"speed":            8,
	"projectile_size":  5,
	"freeze_radius":    5,
	"orbital_radius":   5,
	"fire_aura_radius": 5,
	"currency_bonus":   6,
	"revive_chance":    3,
}

# ── Базовые цены (растут с каждым уровнем) ────────────────────────────────────
const BASE_PRICES: Dictionary = {
	"max_hp":           40,
	"speed":            50,
	"projectile_size":  80,
	"freeze_radius":    70,
	"orbital_radius":   70,
	"fire_aura_radius": 70,
	"currency_bonus":   60,
	"revive_chance":    120,
}

# ── Описания улучшений ────────────────────────────────────────────────────────
const DESCRIPTIONS: Dictionary = {
	"max_hp":           "Макс. здоровье\n+10 HP",
	"speed":            "Скорость\n+15 к движению",
	"projectile_size":  "Размер снарядов\n+15% к масштабу",
	"freeze_radius":    "Область заморозки\n+20 к радиусу",
	"orbital_radius":   "Орбиталь\n+20 к радиусу вращения",
	"fire_aura_radius": "Огненная аура\n+15 к радиусу",
	"currency_bonus":   "Доход монет\n+25% монет с врагов",
	"revive_chance":    "Шанс воскрешения\n+25% шанс при смерти",
}

const ICONS: Dictionary = {
	"max_hp":           "❤",
	"speed":            "⚡",
	"projectile_size":  "✦",
	"freeze_radius":    "❄",
	"orbital_radius":   "◎",
	"fire_aura_radius": "🔥",
	"currency_bonus":   "💰",
	"revive_chance":    "✙",
}


func _ready() -> void:
	load_progress()


# ── Цена следующего уровня ─────────────────────────────────────────────────────
func get_price(upgrade_key: String) -> int:
	var lvl: int = upgrades.get(upgrade_key, 0)
	return int(BASE_PRICES[upgrade_key] * pow(1.5, lvl))


# ── Покупка улучшения ─────────────────────────────────────────────────────────
func buy_upgrade(upgrade_key: String) -> bool:
	var lvl: int = upgrades.get(upgrade_key, 0)
	if lvl >= MAX_LEVELS[upgrade_key]:
		return false
	var price: int = get_price(upgrade_key)
	if currency < price:
		return false
	currency -= price
	upgrades[upgrade_key] = lvl + 1
	save_progress()
	return true

	# Размер снарядов (сохраняем для передачи в снаряд)
func apply_to_projectile(projectile: Node) -> void:
	projectile.meta_projectile_scale = 1.0 + upgrades["projectile_size"] * 0.15

# ── Применить мета-апгрейды к игроку ─────────────────────────────────────────
func apply_to_player(player: Node) -> void:
	# Здоровье — всегда устанавливаем от базового значения, чтобы не накапливать
	var base_hp: float = player.get_meta("base_max_hp", -1.0)
	if base_hp < 0.0:
		# Первый вызов — запоминаем оригинальное значение
		player.set_meta("base_max_hp", player.max_hp)
		base_hp = player.max_hp
	player.max_hp = int(base_hp) + upgrades["max_hp"] * 10
	player.current_hp = player.max_hp

	# Скорость — аналогично
	var base_speed: float = player.get_meta("base_speed", -1.0)
	if base_speed < 0.0:
		player.set_meta("base_speed", player.speed)
		base_speed = player.speed
	player.speed = base_speed + upgrades["speed"] * 15.0

	# Радиусы заклинаний — применяются через spell_manager
	var sm = player.get_node_or_null("SpellManager")
	if sm:
		sm.meta_freeze_radius_bonus    = upgrades["freeze_radius"]    * 20.0
		sm.meta_orbital_radius_bonus   = upgrades["orbital_radius"]   * 20.0
		sm.meta_fire_aura_radius_bonus = upgrades["fire_aura_radius"] * 15.0


# ── Доход монет (множитель) ───────────────────────────────────────────────────
func get_currency_multiplier() -> float:
	return 1.0 + upgrades["currency_bonus"] * 0.25


# ── Шанс воскреснуть ──────────────────────────────────────────────────────────
func get_revive_chance() -> float:
	return upgrades["revive_chance"] * 0.25   # 0%, 25%, 50%, 75%


# ── Добавить монеты (с учётом бонуса) ────────────────────────────────────────
func add_currency(amount: int) -> void:
	var total := int(amount * get_currency_multiplier())
	currency += total
	save_progress()


# ── Сохранение / Загрузка ─────────────────────────────────────────────────────
func save_progress() -> void:
	var data := {
		"currency": currency,
		"upgrades": upgrades,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()


func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		currency = parsed.get("currency", 0)
		var saved_upg = parsed.get("upgrades", {})
		for key in upgrades:
			if saved_upg.has(key):
				upgrades[key] = saved_upg[key]


# ── Сброс (для отладки) ───────────────────────────────────────────────────────
func reset_all() -> void:
	currency = 0
	for key in upgrades:
		upgrades[key] = 0
	save_progress()
