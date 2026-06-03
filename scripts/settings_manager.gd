extends Node

# ==========================================
# МЕНЕДЖЕР НАСТРОЕК (SettingsManager)
# Singleton — добавь в Project → Autoload как "SettingsManager"
# Путь: res://scripts/settings_manager.gd
# ==========================================

const SAVE_PATH := "user://settings.json"

# ── Настройки громкости (0.0 – 1.0) ──────────────────────────────────────────
var master_volume: float = 1.0
var music_volume:  float = 1.0
var sfx_volume:    float = 1.0

# ── Настройки экрана ─────────────────────────────────────────────────────────
var fullscreen: bool = false

# ── Индексы шин AudioServer ───────────────────────────────────────────────────
const BUS_MASTER := "Master"
const BUS_MUSIC  := "Music"
const BUS_SFX    := "SFX"


func _ready() -> void:
	load_settings()
	# call_deferred гарантирует что все шины AudioServer уже инициализированы
	# прежде чем мы попытаемся установить громкость.
	# Именно из-за этого ползунки сохранялись, но не применялись при старте.
	call_deferred("apply_all")


# ─────────────────────────────────────────
# ПРИМЕНЕНИЕ
# ─────────────────────────────────────────
func apply_all() -> void:
	_apply_volume(BUS_MASTER, master_volume)
	_apply_volume(BUS_MUSIC,  music_volume)
	_apply_volume(BUS_SFX,    sfx_volume)
	_apply_fullscreen()


func _apply_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		idx = 0
	AudioServer.set_bus_volume_db(idx, linear_to_db(max(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.0)


func _apply_fullscreen() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


# ─────────────────────────────────────────
# СЕТТЕРЫ (вызываются из UI)
# ─────────────────────────────────────────
func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_volume(BUS_MASTER, master_volume)
	save_settings()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_volume(BUS_MUSIC, music_volume)
	save_settings()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_volume(BUS_SFX, sfx_volume)
	save_settings()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_fullscreen()
	save_settings()


# ─────────────────────────────────────────
# СОХРАНЕНИЕ / ЗАГРУЗКА
# ─────────────────────────────────────────
func save_settings() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"master_volume": master_volume,
			"music_volume":  music_volume,
			"sfx_volume":    sfx_volume,
			"fullscreen":    fullscreen,
		}, "\t"))
		f.close()


func load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if data is Dictionary:
		if data.has("master_volume"): master_volume = clampf(float(data["master_volume"]), 0.0, 1.0)
		if data.has("music_volume"):  music_volume  = clampf(float(data["music_volume"]),  0.0, 1.0)
		if data.has("sfx_volume"):    sfx_volume    = clampf(float(data["sfx_volume"]),    0.0, 1.0)
		if data.has("fullscreen"):    fullscreen    = bool(data["fullscreen"])
