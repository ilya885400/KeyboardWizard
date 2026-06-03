extends CanvasLayer

# ==========================================
# ГЛАВНОЕ МЕНЮ (MainMenu.tscn)
# Путь: res://scripts/main_menu.gd
# ==========================================
#
# Установка:
#   В Project → Project Settings → Application → Run → Main Scene
#   укажи res://scenes/MainMenu.tscn

const MAIN_SCENE_PATH     := "res://scenes/Main.tscn"
const SETTINGS_MENU_SCENE := preload("res://scenes/SettingsMenu.tscn")

@onready var play_btn:     Button = $Panel/VBox/PlayBtn
@onready var settings_btn: Button = $Panel/VBox/SettingsBtn
@onready var quit_btn:     Button = $Panel/VBox/QuitBtn


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	play_btn.pressed.connect(_on_play_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)


func _on_play_pressed() -> void:
	# Main.tscn сам показывает lesson_select_screen в своём _ready()
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _on_settings_pressed() -> void:
	panel.visible = false
	var settings = SETTINGS_MENU_SCENE.instantiate()
	settings.closed.connect(func():
		settings.queue_free()
		panel.visible = true
	)
	add_child(settings)


func _on_quit_pressed() -> void:
	get_tree().quit()


@onready var panel: PanelContainer = $Panel
