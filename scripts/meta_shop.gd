extends CanvasLayer

# ==========================================
# МАГАЗИН МЕТА-ПРОГРЕССИИ (MetaShop)
# Показывается на экране победы/поражения.
# Добавить в Main.tscn как CanvasLayer (layer=35)
# с именем MetaShop и этим скриптом.
# ==========================================

# ── Узлы (назначаются из Main.tscn) ──────────────────────────────────────────
@onready var currency_label: Label       = $Panel/VBox/TopRow/CurrencyLabel
@onready var grid:           GridContainer = $Panel/VBox/ScrollContainer/Grid
@onready var close_btn:      Button      = $Panel/VBox/CloseBtn

# Внутренний список карточек для обновления
var _cards: Array = []


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	if close_btn:
		
		close_btn.pressed.connect(_on_close)


# ── Открыть магазин ───────────────────────────────────────────────────────────
func open_shop() -> void:
	_rebuild_grid()
	visible = true
	


# ── Закрыть магазин ───────────────────────────────────────────────────────────
func _on_close() -> void:
	visible = false


# ── Обновить отображение валюты ───────────────────────────────────────────────
func _update_currency_label() -> void:
	if currency_label:
		currency_label.text = "%d монет" % MetaProgress.currency


# ── Пересобрать список карточек улучшений ─────────────────────────────────────
func _rebuild_grid() -> void:
	_update_currency_label()

	# Очищаем старые карточки
	for child in grid.get_children():
		child.queue_free()
	_cards.clear()

	var upgrade_keys: Array = MetaProgress.upgrades.keys()
	for key in upgrade_keys:
		var card := _make_card(key)
		grid.add_child(card)
		_cards.append({"key": key, "card": card})


# ── Создать карточку улучшения ────────────────────────────────────────────────
func _make_card(upgrade_key: String) -> PanelContainer:
	var lvl:     int  = MetaProgress.upgrades[upgrade_key]
	var max_lvl: int  = MetaProgress.MAX_LEVELS[upgrade_key]
	var price:   int  = MetaProgress.get_price(upgrade_key)
	var can_buy: bool = MetaProgress.currency >= price and lvl < max_lvl
	var maxed:   bool = lvl >= max_lvl

	# ── Фон карточки ──────────────────────────────────────────────────────────
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color            = Color(0.08, 0.05, 0.14, 0.95)
	style.border_width_left   = 2
	style.border_width_top    = 2
	style.border_width_right  = 2
	style.border_width_bottom = 2
	style.border_color        = Color(0.68, 0.44, 0.98, 0.8) if can_buy else Color(0.32, 0.22, 0.45, 0.4)
	style.corner_radius_top_left     = 2
	style.corner_radius_top_right    = 2
	style.corner_radius_bottom_left  = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left   = 12
	style.content_margin_right  = 12
	style.content_margin_top    = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(170, 0)
	# Карточка растягивается по вертикали чтобы все были одной высоты в гриде
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Иконка — загружаем PNG из assets/icons/
	const ICON_PATHS: Dictionary = {
		"max_hp":           "res://assets/icons/icon_hp.png",
		"speed":            "res://assets/icons/icon_speed.png",
		"projectile_size":  "res://assets/icons/icon_multishot.png",
		"freeze_radius":    "res://assets/icons/icon_freeze.png",
		"orbital_radius":   "res://assets/icons/icon_orbitals.png",
		"fire_aura_radius": "res://assets/icons/icon_fire_aura.png",
		"currency_bonus":   "res://assets/icons/icon_currency.png",
		"revive_chance":    "res://assets/icons/icon_revive.png",
	}

	var icon_container := CenterContainer.new()
	icon_container.custom_minimum_size = Vector2(0, 36)

	var icon_path: String = ICON_PATHS.get(upgrade_key, "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var tex: Texture2D = load(icon_path)
		var icon_rect := TextureRect.new()
		icon_rect.texture = tex
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(32, 32)
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_container.add_child(icon_rect)
	else:
		var icon_label := Label.new()
		icon_label.text = MetaProgress.ICONS.get(upgrade_key, "?")
		icon_label.add_theme_font_size_override("font_size", 24)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_container.add_child(icon_label)

	vbox.add_child(icon_container)

	# Описание — занимает всё свободное место, толкая звёзды и кнопку вниз
	var desc_label := Label.new()
	desc_label.text = MetaProgress.DESCRIPTIONS.get(upgrade_key, upgrade_key)
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.98))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_label)

	# Полоска уровня
	var lvl_label := Label.new()
	var stars := ""
	for i in range(max_lvl):
		stars += "★" if i < lvl else "☆"
	lvl_label.text = stars
	lvl_label.add_theme_font_size_override("font_size", 12)
	lvl_label.add_theme_color_override("font_color",
		Color(1.0, 0.84, 0.0) if lvl > 0 else Color(0.42, 0.35, 0.52))
	lvl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_label.clip_text = true
	vbox.add_child(lvl_label)

	# Кнопка покупки — всегда внизу
	var buy_btn := Button.new()
	if maxed:
		buy_btn.text = "МАКС"
		buy_btn.disabled = true
		buy_btn.add_theme_color_override("font_color_disabled", Color(0.55, 0.55, 0.55))
	else:
		var icon_texture = preload("res://assets/icons/icon_currency(1).png")
		buy_btn.icon = icon_texture
		buy_btn.text = "%d" % price
		buy_btn.disabled = not can_buy
		buy_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3) if can_buy else Color(0.52, 0.48, 0.58))
		buy_btn.add_theme_color_override("font_color_disabled", Color(0.48, 0.44, 0.52))

	# СТИЛИ КНОПКИ ПОКУПКИ
	var btn_style_n := StyleBoxFlat.new()
	btn_style_n.bg_color            = Color(0.16, 0.1, 0.28, 0.95) if can_buy else Color(0.09, 0.07, 0.15, 0.6)
	btn_style_n.border_width_left   = 2
	btn_style_n.border_width_top    = 2
	btn_style_n.border_width_right  = 2
	btn_style_n.border_width_bottom = 2
	btn_style_n.border_color        = Color(0.68, 0.44, 0.98, 1.0) if can_buy else Color(0.35, 0.25, 0.48, 0.5)
	btn_style_n.corner_radius_top_left     = 2
	btn_style_n.corner_radius_top_right    = 2
	btn_style_n.corner_radius_bottom_left  = 2
	btn_style_n.corner_radius_bottom_right = 2
	btn_style_n.content_margin_top    = 6
	btn_style_n.content_margin_bottom = 6
	buy_btn.add_theme_stylebox_override("normal", btn_style_n)

	var btn_style_h := btn_style_n.duplicate()
	if can_buy:
		btn_style_h.bg_color = Color(0.32, 0.18, 0.54, 1.0)
		btn_style_h.border_color = Color(0.85, 0.65, 1.0, 1.0)
	buy_btn.add_theme_stylebox_override("hover", btn_style_h)

	var btn_style_p := btn_style_n.duplicate()
	if can_buy:
		btn_style_p.bg_color = Color(0.1, 0.05, 0.18, 1.0)
		btn_style_p.border_color = Color(0.52, 0.28, 0.82, 1.0)
	buy_btn.add_theme_stylebox_override("pressed", btn_style_p)

	var btn_style_d := btn_style_n.duplicate()
	btn_style_d.bg_color = Color(0.06, 0.04, 0.1, 0.7)
	btn_style_d.border_color = Color(0.25, 0.18, 0.35, 0.4)
	buy_btn.add_theme_stylebox_override("disabled", btn_style_d)

	buy_btn.add_theme_font_size_override("font_size", 14)
	buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var k := upgrade_key
	buy_btn.pressed.connect(func():

		if MetaProgress.buy_upgrade(k):
			_rebuild_grid()
	)

	vbox.add_child(buy_btn)

	return panel
