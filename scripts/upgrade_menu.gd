extends CanvasLayer

# ==========================================
# МЕНЮ ПРОКАЧКИ — расширенное
# Пул: 3 базовых + 5 заклинаний = 8 вариантов.
# Каждый раз случайно выбираются 3 из доступных.
# ==========================================

@onready var panel: Panel               = $Panel
@onready var level_label: Label         = $Panel/LevelLabel

@onready var card_a: PanelContainer    = $Panel/VBox/SpeedCard
@onready var card_b: PanelContainer    = $Panel/VBox/WordsCard
@onready var card_c: PanelContainer    = $Panel/VBox/HPCard

@onready var icon_a:  TextureRect = $Panel/VBox/SpeedCard/VBox/HBox/IconBG/Icon
@onready var title_a: Label = $Panel/VBox/SpeedCard/VBox/HBox/TextVBox/Title
@onready var desc_a:  Label = $Panel/VBox/SpeedCard/VBox/HBox/TextVBox/Desc
@onready var word_a:  Label = $Panel/VBox/SpeedCard/VBox/WordRow/WordLabel

@onready var icon_b:  TextureRect = $Panel/VBox/WordsCard/VBox/HBox/IconBG/Icon
@onready var title_b: Label = $Panel/VBox/WordsCard/VBox/HBox/TextVBox/Title
@onready var desc_b:  Label = $Panel/VBox/WordsCard/VBox/HBox/TextVBox/Desc
@onready var word_b:  Label = $Panel/VBox/WordsCard/VBox/WordRow/WordLabel

@onready var icon_c:  TextureRect = $Panel/VBox/HPCard/VBox/HBox/IconBG/Icon
@onready var title_c: Label = $Panel/VBox/HPCard/VBox/HBox/TextVBox/Title
@onready var desc_c:  Label = $Panel/VBox/HPCard/VBox/HBox/TextVBox/Desc
@onready var word_c:  Label = $Panel/VBox/HPCard/VBox/WordRow/WordLabel

@onready var input_label: Label = $Panel/VBox/InputContainer/InputRow/InputLabel
var player: Node = null

# ── Флаг: реликвия подобрана → особый апгрейд доступен ───────────────────────
var relic_collected: bool = false

# ── Все возможные апгрейды ─────────────────────────────────────────────────────
# { id, icon, title, desc, method, relic_required }
const ALL_UPGRADES := [
	{
		"id": "speed",
		"icon": "⚡",
		"title": "Скорость бега",
		"desc": "+40 к скорости перемещения",
		"method": "upgrade_speed",
		"relic_required": false
	},
	{
		"id": "words",
		"icon": "📖",
		"title": "Короче слова",
		"desc": "−1 буква к длине слов врагов",
		"method": "upgrade_shorter_words",
		"relic_required": false
	},
	{
		"id": "hp",
		"icon": "❤️",
		"title": "Жизненная сила",
		"desc": "+30 HP и восстановление",
		"method": "upgrade_max_hp",
		"relic_required": false
	},
	{
		"id": "fire_aura",
		"icon": "🔥",
		"title": "Аура огня",
		"desc": "Пассивный урон врагам в радиусе. Повторно: радиус и урон",
		"method": "spell_fire_aura",
		"relic_required": false
	},
	{
		"id": "orbitals",
		"icon": "🌀",
		"title": "Орбитальные сферы",
		"desc": "Шары вращаются вокруг тебя и бьют врагов. Повторно: +1 шар",
		"method": "spell_orbitals",
		"relic_required": false
	},
	{
		"id": "chain",
		"icon": "⚡",
		"title": "Цепная молния",
		"desc": "Выстрел бьёт по 2 доп. врагам. Повторно: +1 прыжок",
		"method": "spell_chain",
		"relic_required": false
	},
	{
		"id": "freeze",
		"icon": "❄️",
		"title": "Волна заморозки",
		"desc": "Каждые 8с замедляет всех врагов. Повторно: дольше и чаще",
		"method": "spell_freeze",
		"relic_required": false
	},
	{
		"id": "multishot",
		"icon": "✨",
		"title": "Мультивыстрел",
		"desc": "+2 снаряда в стороны при каждом выстреле. Повторно: +1",
		"method": "spell_multishot",
		"relic_required": false
	},
	{
		"id": "thunder_strike",
		"icon": "☇",
		"title": "✦ ГРОМОВОЙ УДАР ✦",
		"desc": "Каждый выстрел с шансом 35% бьёт молнией по всем врагам рядом. Повторно: урон и радиус",
		"method": "spell_thunder_strike",
		"relic_required": true
	},
]

const TRIGGER_WORDS := [
	"fire", "mana", "bolt", "ice", "rune", "arc",
	"hex", "nova", "void", "fury", "soul", "dawn",
	"ash", "beam", "flux", "gale", "iron", "lore",
	"zap", "orb", "rime", "wave", "arc", "sear"
]

const RU_TRIGGER_WORDS := [
	"огонь", "мана", "руна", "лёд", "дух", "тьма",
	"гром", "свет", "яд", "туман", "прах", "щит",
	"меч", "хаос", "кара", "искра", "холод", "зелье",
	"посох", "вихрь", "пламя", "стрела", "клинок", "алтарь"
]

# Выбранные на этот показ 3 апгрейда
var chosen_upgrades: Array = []
var upgrade_words: Array[String] = ["", "", ""]
var current_input: String = ""
var focused_upgrade: int  = -1

const COLOR_TYPED  := Color(0.4, 1.0, 0.6)
const COLOR_NORMAL := Color(0.9, 0.9, 1.0)
const COLOR_ERROR  := Color(1.0, 0.35, 0.35)

const ICON_PATHS: Dictionary = {
	"speed":           "res://assets/icons/icon_speed.png",
	"words":           "res://assets/icons/icon_words.png",
	"hp":              "res://assets/icons/icon_hp.png",
	"fire_aura":       "res://assets/icons/icon_fire_aura.png",
	"orbitals":        "res://assets/icons/icon_orbitals.png",
	"chain":           "res://assets/icons/icon_chain.png",
	"freeze":          "res://assets/icons/icon_freeze.png",
	"multishot":       "res://assets/icons/icon_multishot.png",
	"thunder_strike":  "res://assets/icons/icon_thunder_strike.png",
}
 
var _icon_cache: Dictionary = {}
 
func _ready() -> void:
	# Предзагрузка текстур
	for id in ICON_PATHS:
		_icon_cache[id] = load(ICON_PATHS[id])
	panel.visible = false
	process_mode  = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(false)
 


func show_upgrade_menu(new_level: int) -> void:
	level_label.text = "Уровень %d!\nВыбери улучшение:" % new_level
	_pick_upgrades()
	_assign_words()
	current_input    = ""
	focused_upgrade  = -1
	_refresh_all_cards()
	input_label.text = ""
	visible       = true
	panel.visible = true
	get_tree().paused = true
	set_process_unhandled_input(true)


func _hide_menu() -> void:
	set_process_unhandled_input(false)
	visible       = false
	panel.visible = false
	get_tree().paused = false


# ─────────────────────────────────────────
# ВЫБОР 3 АПГРЕЙДОВ ИЗ ПУЛА
# ─────────────────────────────────────────
func _pick_upgrades() -> void:
	# Фильтруем: особые апгрейды только если реликвия подобрана
	var pool := ALL_UPGRADES.filter(func(u):
		return not u["relic_required"] or relic_collected
	).duplicate()
	pool.shuffle()
	chosen_upgrades = pool.slice(0, 3)


# ─────────────────────────────────────────
# НАЗНАЧЕНИЕ СЛОВ (уникальные первые буквы)
# ─────────────────────────────────────────
func _assign_words() -> void:
	# Выбираем пул слов по текущему языку игры
	var mgr = get_tree().get_first_node_in_group("enemy_manager")
	var lang := "en"
	if mgr and "game_language" in mgr:
		lang = mgr.game_language

	var pool := (RU_TRIGGER_WORDS if lang == "ru" else TRIGGER_WORDS).duplicate()
	pool.shuffle()
	var chosen: Array[String] = []
	var used_first: Array[String] = []

	for w in pool:
		if w[0] not in used_first:
			chosen.append(w)
			used_first.append(w[0])
		if chosen.size() == 3:
			break

	while chosen.size() < 3:
		chosen.append(pool[chosen.size() % pool.size()])

	upgrade_words[0] = chosen[0]
	upgrade_words[1] = chosen[1]
	upgrade_words[2] = chosen[2]


# ─────────────────────────────────────────
# ОТРИСОВКА КАРТОЧЕК
# ─────────────────────────────────────────
func _refresh_all_cards() -> void:
	_fill_card(0, icon_a, title_a, desc_a, word_a)
	_fill_card(1, icon_b, title_b, desc_b, word_b)
	_fill_card(2, icon_c, title_c, desc_c, word_c)


func _fill_card(idx: int, icon_lbl: TextureRect, title_lbl: Label, desc_lbl: Label, word_lbl: Label) -> void:
	var upg: Dictionary = chosen_upgrades[idx]
	icon_lbl.texture = _icon_cache.get(upg["id"])
	title_lbl.text = upg["title"]
	desc_lbl.text  = upg["desc"]

	# Слово
	if focused_upgrade == idx:
		var word  := upgrade_words[idx]
		var typed := word.substr(0, current_input.length())
		var rest  := word.substr(current_input.length())
		word_lbl.text = typed + "|" + rest
		word_lbl.add_theme_color_override("font_color", COLOR_TYPED)
	else:
		word_lbl.text = upgrade_words[idx]
		word_lbl.add_theme_color_override("font_color", COLOR_NORMAL)


# ─────────────────────────────────────────
# ОБРАБОТКА ВВОДА
# ─────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if Input.is_key_pressed(KEY_SHIFT):
		return
	var uni = event.unicode
	if uni <= 0:
		return
	var ch  := String.chr(uni).to_lower()
	var cp  := ch.unicode_at(0)

	# Определяем язык из менеджера врагов
	var mgr = get_tree().get_first_node_in_group("enemy_manager")
	var lang := "en"
	if mgr and "game_language" in mgr:
		lang = mgr.game_language

	var key_char := ""
	if lang == "ru":
		if (cp >= 0x430 and cp <= 0x44F) or cp == 0x451:
			key_char = ch
	else:
		if ch.length() == 1 and ch >= "a" and ch <= "z":
			key_char = ch

	if key_char == "":
		return
	get_viewport().set_input_as_handled()
	_process_letter(key_char)


func _process_letter(letter: String) -> void:
	if focused_upgrade == -1:
		for i in range(3):
			if upgrade_words[i].begins_with(letter):
				focused_upgrade = i
				current_input   = letter
				_refresh_all_cards()
				_update_input_display()
				return
		_flash_error()
		return

	var word: String = upgrade_words[focused_upgrade]
	var expected: String = word[current_input.length()]

	if letter == expected:
		current_input += letter
		_refresh_all_cards()
		_update_input_display()
		if current_input.length() >= word.length():
			_apply_upgrade(focused_upgrade)
	else:
		focused_upgrade = -1
		current_input   = ""
		_flash_error()
		_refresh_all_cards()
		_update_input_display()


func _update_input_display() -> void:
	if focused_upgrade == -1:
		input_label.text = ""
		input_label.add_theme_color_override("font_color", COLOR_NORMAL)
	else:
		var word := upgrade_words[focused_upgrade]
		input_label.text = current_input + word.substr(current_input.length())
		input_label.add_theme_color_override("font_color", COLOR_TYPED)


func _flash_error() -> void:
	input_label.text = "✗"
	input_label.add_theme_color_override("font_color", COLOR_ERROR)
	get_tree().create_timer(0.25).timeout.connect(func():
		input_label.text = ""
		input_label.add_theme_color_override("font_color", COLOR_NORMAL)
	)


# ─────────────────────────────────────────
# ПРИМЕНЕНИЕ АПГРЕЙДА
# ─────────────────────────────────────────
func _apply_upgrade(idx: int) -> void:
	var upg: Dictionary = chosen_upgrades[idx]
	var method: String  = upg["method"]
	if player and player.has_method(method):
		player.call(method)
	_hide_menu()
