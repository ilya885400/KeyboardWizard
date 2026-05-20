# ИНСТРУКЦИЯ ПО ИНТЕГРАЦИИ — Режим обучения слепой печати (RU + EN)
# ==========================================================================

## 1. AUTOLOAD (Синглтон)

Project → Project Settings → Autoload → добавь:
  Path:  res://scripts/typing_lesson_manager.gd
  Name:  TypingLessonManager

После этого он доступен глобально как TypingLessonManager.


## 2. ЗАМЕНИ СКРИПТЫ

Замени следующие файлы в папке res://scripts/:
  • main.gd              — главная сцена
  • player.gd            — игрок (кириллица + сигналы статистики)
  • enemy_manager.gd     — менеджер врагов (поддержка режима обучения)
  • typing_lesson_manager.gd  — НОВЫЙ файл (синглтон)


## 3. ДОБАВЬ УЗЛЫ В Main.tscn

Открой Main.tscn и добавь следующие узлы прямо в корень сцены
(на том же уровне что WinScreen, GameOverScreen и т.д.):

─────────────────────────────────────────────────────────────────────
### A) LessonHUD : CanvasLayer
   Отображает текущий урок и статистику во время игры.

   LessonHUD  (CanvasLayer, layer = 5)
   └─ LessonPanel  (PanelContainer, anchor = top-center)
      └─ LessonLabel  (Label)  — "EN 3 · Home row: S D F J K L"
   └─ KeysPanel  (PanelContainer, anchor = top-center, ниже LessonPanel)
      └─ KeysLabel  (Label)  — "[ S · D · F · J · K · L ]"
   └─ StatsPanel  (PanelContainer, anchor = top-right)
      └─ VBox  (VBoxContainer)
         └─ AccLabel  (Label)  — "Точность: 100%"
         └─ WpmLabel  (Label)  — "Слов: 0"

─────────────────────────────────────────────────────────────────────
### B) LessonSelectScreen : CanvasLayer
   Экран выбора урока, появляется при старте игры.

   LessonSelectScreen  (CanvasLayer, layer = 10)
   └─ Panel  (Panel, по центру экрана, ~900×700)
      └─ VBox  (VBoxContainer)
         └─ TitleLabel  (Label)  — "Режим обучения"
         └─ LangRow  (HBoxContainer)
            └─ EnBtn  (Button)  — "🇬🇧 English (QWERTY)"
            └─ RuBtn  (Button)  — "🇷🇺 Русский (ЙЦУКЕН)"
         └─ LessonScroll  (ScrollContainer, min_size_y = 400)
            └─ LessonList  (VBoxContainer)  ← заполняется кодом
         └─ NormalBtn  (Button)  — "⚔ Обычная игра"

─────────────────────────────────────────────────────────────────────
### C) LessonResultScreen : CanvasLayer
   Экран результата по окончании урока.

   LessonResultScreen  (CanvasLayer, layer = 10)
   └─ Panel  (Panel, по центру экрана, ~600×500)
      └─ VBox  (VBoxContainer)
         └─ TitleLabel  (Label)  — текст ставится кодом
         └─ ResultLabel  (Label, autowrap = true)
         └─ HBoxBtns  (HBoxContainer)
            └─ NextBtn   (Button)  — "→ Следующий урок"
            └─ RetryBtn  (Button)  — "↺ Повторить"
            └─ MenuBtn   (Button)  — "↩ В меню"


## 4. ПОДДЕРЖКА КИРИЛЛИЦЫ В GODOT 4

Godot 4 передаёт Юникод через event.unicode.
Для русской раскладки СИСТЕМНАЯ РАСКЛАДКА должна быть переключена на RU
на уровне ОС — игра сама не переключает раскладку.

Игрок видит подсказку в HUD: "[ А · О ]", нажимает физические клавиши
с учётом активной системной раскладки.

ВАЖНО: при уроке "ru" игра принимает ТОЛЬКО кириллицу (а-я, ё).
При уроке "en" — только латиницу (a-z).
Это сделано намеренно, чтобы игрок тренировал нужную раскладку.


## 5. ПРОГРЕСС

Прогресс по урокам сохраняется в user://typing_progress.json:
  {"en": 3, "ru": 1}

Сбросить прогресс: удали файл или выбери урок вручную в меню.


## 6. ПОДСКАЗКА ПО РАСКЛАДКЕ ЙЦУКЕН

Домашний ряд (home row) ЙЦУКЕН:
  Левая рука:   Ф Ы В А   (мизинец → указательный)
  Правая рука:  О Л Д Ж   (указательный → мизинец)

Верхний ряд:
  Левая:  Й Ц У К Е
  Правая: Н Г Ш Щ З Х

Нижний ряд:
  Левая:  Я Ч С М
  Правая: И Т Ь Б Ю
