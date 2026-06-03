extends CanvasLayer

# ==========================================
# МЕНЮ НАСТРОЕК (SettingsMenu.tscn)
# ==========================================

# Сигнал: закрыть меню настроек и вернуться к вызывающему
signal closed

@onready var master_slider: HSlider = $Panel/VBox/MasterRow/MasterSlider
@onready var music_slider:  HSlider = $Panel/VBox/MusicRow/MusicSlider
@onready var sfx_slider:    HSlider = $Panel/VBox/SfxRow/SfxSlider

@onready var master_label: Label = $Panel/VBox/MasterRow/MasterValueLabel
@onready var music_label:  Label = $Panel/VBox/MusicRow/MusicValueLabel
@onready var sfx_label:    Label = $Panel/VBox/SfxRow/SfxValueLabel

@onready var fullscreen_btn: Button = $Panel/VBox/ScreenRow/FullscreenBtn
@onready var back_btn:       Button = $Panel/VBox/BackBtn


func _ready() -> void:
	# Инициализируем ползунки из текущих настроек
	master_slider.value = SettingsManager.master_volume
	music_slider.value  = SettingsManager.music_volume
	sfx_slider.value    = SettingsManager.sfx_volume
	_update_labels()
	_update_fullscreen_btn()

	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	fullscreen_btn.pressed.connect(_on_fullscreen_toggled)
	back_btn.pressed.connect(_on_back_pressed)


func _on_master_changed(v: float) -> void:
	SettingsManager.set_master_volume(v)
	_update_labels()


func _on_music_changed(v: float) -> void:
	SettingsManager.set_music_volume(v)
	_update_labels()


func _on_sfx_changed(v: float) -> void:
	SettingsManager.set_sfx_volume(v)
	_update_labels()


func _on_fullscreen_toggled() -> void:
	SettingsManager.set_fullscreen(not SettingsManager.fullscreen)
	_update_fullscreen_btn()


func _update_fullscreen_btn() -> void:
	fullscreen_btn.text = "ПОЛНЫЙ ЭКРАН" if SettingsManager.fullscreen else "□  ОКОННЫЙ РЕЖИМ"


func _update_labels() -> void:
	master_label.text = "%d%%" % int(SettingsManager.master_volume * 100)
	music_label.text  = "%d%%" % int(SettingsManager.music_volume  * 100)
	sfx_label.text    = "%d%%" % int(SettingsManager.sfx_volume    * 100)


func _on_back_pressed() -> void:
	emit_signal("closed")
	queue_free()
