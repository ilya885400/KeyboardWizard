## KeyboardDiagram.gd
## Рисует визуализацию клавиатуры для экрана информации об уроке.
## Подсвечивает новые клавиши (жёлтым) и уже известные (оранжевым).
## Используется как Control-нода внутри VBoxContainer.
##
## Использование:
##   keyboard_diagram.setup(lang, new_keys_str, all_keys_str)
##   где new_keys_str и all_keys_str — строки через пробел, например "f j"
##
## Добавить в Main.tscn:
##   LessonResultScreen/Panel/VBox/KeyboardDiagram  (type: Control)

extends Control

# ── Публичные поля ────────────────────────────────────────────────────────────
var lang: String = "en"           # "en" или "ru"
var new_keys: Array[String] = []  # Клавиши, которые добавились в этом уроке
var all_keys: Array[String] = []  # Все клавиши урока (включая новые)

# ── Константы раскладок ───────────────────────────────────────────────────────
const QWERTY_ROWS: Array = [
	["q","w","e","r","t","y","u","i","o","p"],
	["a","s","d","f","g","h","j","k","l",";"],
	["z","x","c","v","b","n","m",",",".","/"]
]

const ЙЦУКЕН_ROWS: Array = [
	["й","ц","у","к","е","н","г","ш","щ","з","х","ъ"],
	["ф","ы","в","а","п","р","о","л","д","ж","э"],
	["я","ч","с","м","и","т","ь","б","ю","."]
]

# Смещение первого ряда (stagger) — доля ширины клавиши
const ROW_STAGGER: Array = [0.0, 0.25, 0.6]

# Клавиши-маркеры (указатели) для «домашней» позиции (F и J)
const HOME_MARKERS_EN: Array = ["f", "j"]
const HOME_MARKERS_RU: Array = ["а", "о"]  # А и О на ЙЦУКЕН

# ── Цвета ─────────────────────────────────────────────────────────────────────
const COLOR_BG          := Color(0.10, 0.06, 0.02, 0.0)   # прозрачный фон
const COLOR_KEY_DARK    := Color(0.14, 0.09, 0.03, 1.0)   # обычная клавиша
const COLOR_KEY_KNOWN   := Color(0.55, 0.28, 0.04, 1.0)   # уже известная
const COLOR_KEY_NEW     := Color(0.92, 0.72, 0.08, 1.0)   # новая в уроке
const COLOR_BORDER_DARK := Color(0.55, 0.30, 0.05, 1.0)
const COLOR_BORDER_NEW  := Color(1.00, 0.90, 0.20, 1.0)
const COLOR_TEXT_DARK   := Color(0.65, 0.45, 0.15, 1.0)
const COLOR_TEXT_KNOWN  := Color(1.00, 0.85, 0.45, 1.0)
const COLOR_TEXT_NEW    := Color(0.10, 0.06, 0.01, 1.0)   # тёмный текст на жёлтом
const COLOR_MARKER      := Color(0.98, 0.55, 0.05, 0.85)  # точка-маркер на F/J
const COLOR_SPACE_BG    := Color(0.14, 0.09, 0.03, 1.0)

# ── Размеры ───────────────────────────────────────────────────────────────────
# Вычисляются в _compute_layout() при каждом draw.
var _key_w: float = 38.0
var _key_h: float = 34.0
var _gap:   float = 4.0
var _corner: float = 5.0
var _font_size: int = 13

# Внутренние кэши
var _rows: Array = []
var _home_markers: Array = []

# ── Публичный API ─────────────────────────────────────────────────────────────
func setup(p_lang: String, new_keys_str: String, all_keys_str: String) -> void:
	lang = p_lang
	new_keys = _split_keys(new_keys_str)
	all_keys = _split_keys(all_keys_str)
	_rows = ЙЦУКЕН_ROWS if lang == "ru" else QWERTY_ROWS
	_home_markers = HOME_MARKERS_RU if lang == "ru" else HOME_MARKERS_EN
	queue_redraw()

# ── Вспомогательные ───────────────────────────────────────────────────────────
func _split_keys(s: String) -> Array[String]:
	var result: Array[String] = []
	for part in s.to_lower().split(" "):
		var trimmed := part.strip_edges()
		if trimmed != "":
			result.append(trimmed)
	return result

func _compute_layout() -> void:
	var avail_w := size.x - 16.0
	# Самый длинный ряд определяет масштаб
	var max_cols := 0
	for row in _rows:
		if row.size() > max_cols:
			max_cols = row.size()
	# Добавляем смещение для stagger
	var total_cols := max_cols + ROW_STAGGER[2]  # самый большой stagger = 0.6
	_gap = maxf(3.0, avail_w * 0.015)
	_key_w = (avail_w - _gap * (total_cols)) / total_cols
	_key_w = clampf(_key_w, 24.0, 50.0)
	_key_h = _key_w * 0.88
	_corner = _key_w * 0.14
	_font_size = clamp(int(_key_w * 0.38), 9, 16)
	# Обновить минимальную высоту
	var rows_h := _key_h * _rows.size() + _gap * (_rows.size() - 1)
	var space_h := _key_h * 0.65  # пробел
	var legend_h := 22.0
	var total_h := 8.0 + rows_h + _gap * 2 + space_h + _gap + legend_h + 8.0
	custom_minimum_size = Vector2(0, total_h)

func _total_keyboard_width() -> float:
	var max_cols := 0
	for row in _rows:
		if row.size() > max_cols:
			max_cols = row.size()
	return max_cols * (_key_w + _gap) - _gap

# ── DRAW ──────────────────────────────────────────────────────────────────────
func _draw() -> void:
	if _rows.is_empty():
		return
	_compute_layout()

	var kbd_w := _total_keyboard_width()
	# Добавляем немного места для stagger правого края
	kbd_w += ROW_STAGGER[2] * (_key_w + _gap)
	var start_x := (size.x - kbd_w) * 0.5
	var start_y := 8.0

	# ── Ряды клавиш ───────────────────────────────────────────────────────────
	for row_i in range(_rows.size()):
		var row: Array = _rows[row_i]
		var stagger_x = ROW_STAGGER[row_i] * (_key_w + _gap)
		for col_i in range(row.size()):
			var key: String = row[col_i]
			var x = start_x + stagger_x + col_i * (_key_w + _gap)
			var y := start_y + row_i * (_key_h + _gap)
			_draw_key(Rect2(x, y, _key_w, _key_h), key)

	# ── Пробел ────────────────────────────────────────────────────────────────
	var rows_h := _rows.size() * (_key_h + _gap)
	var space_y := start_y + rows_h
	var space_w := kbd_w * 0.42
	var space_x := start_x + (kbd_w - space_w) * 0.5
	var space_h := _key_h * 0.65
	#_draw_space_key(Rect2(space_x, space_y, space_w, space_h))

	# ── Легенда ───────────────────────────────────────────────────────────────
	var legend_y := space_y + space_h + _gap + 4.0
	#_draw_legend(start_x, legend_y, kbd_w)

func _draw_key(rect: Rect2, key: String) -> void:
	var is_new   := key in new_keys
	var is_known := key in all_keys and not is_new
	var is_home  := key in _home_markers

	# Фон клавиши
	var bg_col := COLOR_KEY_NEW if is_new else (COLOR_KEY_KNOWN if is_known else COLOR_KEY_DARK)
	var bd_col := COLOR_BORDER_NEW if is_new else COLOR_BORDER_DARK
	draw_rect(rect, bg_col)
	# Рамка (4 стороны — 1px)
	var bw := 1.5 if is_new else 1.0
	draw_rect(rect, bd_col, false, bw)

	# Текст клавиши
	var txt_col := COLOR_TEXT_NEW if is_new else (COLOR_TEXT_KNOWN if is_known else COLOR_TEXT_DARK)
	var upper_key := key.to_upper()
	var font := ThemeDB.fallback_font
	var txt_w := font.get_string_size(upper_key, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
	var tx := rect.position.x + (rect.size.x - txt_w) * 0.5
	var ty := rect.position.y + rect.size.y * 0.5 + _font_size * 0.35
	draw_string(font, Vector2(tx, ty), upper_key, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, txt_col)

	# Маркер-точка для домашних клавиш (F и J)
	if is_home:
		var dot_x := rect.position.x + rect.size.x * 0.5
		var dot_y := rect.position.y + rect.size.y - 4.0
		draw_circle(Vector2(dot_x, dot_y), 2.5, COLOR_MARKER)

func _draw_space_key(rect: Rect2) -> void:
	var is_known := "space" in all_keys or " " in all_keys
	var bg_col := COLOR_KEY_KNOWN if is_known else COLOR_KEY_DARK
	draw_rect(rect, bg_col)
	draw_rect(rect, COLOR_BORDER_DARK, false, 1.0)
	var font := ThemeDB.fallback_font
	var label := "ПРОБЕЛ" if lang == "ru" else "SPACE"
	var txt_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size - 2).x
	var tx := rect.position.x + (rect.size.x - txt_w) * 0.5
	var ty := rect.position.y + rect.size.y * 0.5 + (_font_size - 2) * 0.35
	var txt_col := COLOR_TEXT_KNOWN if is_known else COLOR_TEXT_DARK
	draw_string(font, Vector2(tx, ty), label, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size - 2, txt_col)

func _draw_legend(lx: float, ly: float, kbd_w: float) -> void:
	var font := ThemeDB.fallback_font
	var fs := 11

	# Новые клавиши — жёлтый квадратик
	var sq := 10.0
	draw_rect(Rect2(lx, ly + 2, sq, sq), COLOR_KEY_NEW)
	draw_string(font, Vector2(lx + sq + 5, ly + fs), "— новые клавиши", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COLOR_TEXT_KNOWN)

	# Уже известные — оранжевый
	var lx2 := lx + kbd_w * 0.5
	draw_rect(Rect2(lx2, ly + 2, sq, sq), COLOR_KEY_KNOWN)
	draw_string(font, Vector2(lx2 + sq + 5, ly + fs), "— уже изучены", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.8, 0.6, 0.3, 1.0))
