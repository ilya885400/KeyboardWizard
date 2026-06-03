extends CanvasLayer

# ==========================================
# МЕНЮ ПАУЗЫ (PauseMenu.tscn)
# Путь: res://scripts/pause_menu.gd
# ==========================================

const SETTINGS_MENU_SCENE  := preload("res://scenes/SettingsMenu.tscn")
const MAIN_MENU_SCENE_PATH := "res://scenes/MainMenu.tscn"

@onready var backdrop:      ColorRect = $Backdrop
@onready var panel:         PanelContainer = $Panel
@onready var resume_btn:    Button = $Panel/VBox/ResumeBtn
@onready var settings_btn:  Button = $Panel/VBox/SettingsBtn
@onready var main_menu_btn: Button = $Panel/VBox/MainMenuBtn
@onready var quit_btn:      Button = $Panel/VBox/QuitBtn


func _ready() -> void:
	resume_btn.pressed.connect(_on_resume)
	settings_btn.pressed.connect(_on_settings)
	main_menu_btn.pressed.connect(_on_main_menu)
	quit_btn.pressed.connect(_on_quit)


func _on_resume() -> void:
	get_tree().paused = false
	queue_free()


func _on_settings() -> void:
	# Скрываем панель паузы (бэкдроп оставляем), показываем настройки
	panel.visible = false
	var settings = SETTINGS_MENU_SCENE.instantiate()
	settings.closed.connect(_on_settings_closed)
	add_child(settings)


func _on_settings_closed() -> void:
	# Настройки закрыты — возвращаем панель паузы
	panel.visible = true


func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _on_quit() -> void:
	get_tree().quit()
