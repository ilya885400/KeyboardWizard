extends Node

# ==========================================
# DifficultyAI — ИИ-режиссёр (полностью локальный, без внешних API)
# Подключи как Autoload: Project → Project Settings → Autoload → имя: DifficultyAI
# ==========================================

signal difficulty_changed(new_value: float)

# ══════════════════════════════════════════════════════════════════════════════
# DDA — НАСТРОЙКИ
# ══════════════════════════════════════════════════════════════════════════════

const EVAL_INTERVAL := 8.0

const TARGET_HIGH := 0.5
const TARGET_LOW  := 0.35
const MAX_STEP    := 0.12
const INERTIA     := 0.35

const DIFFICULTY_MIN := 0.0
const DIFFICULTY_MAX := 1.0

const SPAWN_INTERVAL_MIN := 0.6
const SPAWN_INTERVAL_MAX := 3.5
const SPEED_MULT_MIN     := 0.45
const SPEED_MULT_MAX     := 1.25
const MAX_ENEMIES_MIN    := 8
const MAX_ENEMIES_MAX    := 35
const WORD_LEN_MIN       := 3
const WORD_LEN_MAX       := 12

const W_ACC   := 0.35
const W_WPM   := 0.25
const W_HP    := 0.25
const W_KILLS := 0.15
const HISTORY_SIZE := 3

# ══════════════════════════════════════════════════════════════════════════════
# СЛОВАРЬ СЛОГОВ — АНГЛИЙСКИЙ
# ══════════════════════════════════════════════════════════════════════════════

const EN_ONSET_EASY   := ["f","j","d","k","s","l","a"]
const EN_ONSET_MED    := ["fl","fr","st","bl","cr","gr","tr","sl","sp","sk","dr","pr","gl","br","cl","sw"]
const EN_ONSET_HARD   := ["str","spr","scr","thr","shr","spl","sch","chr","squ","phr","nth"]

const EN_NUCLEUS      := ["a","e","i","o","u","ai","ea","oo","ou","ie","ue","au","ei","oa","ui","ae"]

const EN_CODA_EASY    := ["","d","l","n","r","s","t"]
const EN_CODA_MED     := ["nd","nt","st","ld","lk","sk","ng","nk","rd","rk","rm","rn","rs","rt"]
const EN_CODA_HARD    := ["nds","nts","sts","rds","rks","rms","rns","rts","ngs","mpt","ght","lth","nth"]

# ══════════════════════════════════════════════════════════════════════════════
# СЛОВАРЬ СЛОГОВ — РУССКИЙ
# ══════════════════════════════════════════════════════════════════════════════

const RU_ONSET_EASY   := ["а","о","в","л","д","н","е","к","г","у","с","т","м","и","р","п"]
const RU_ONSET_MED    := ["вл","вр","гл","гр","дл","др","зл","зн","кл","кр","мн","пл","пр","сл","см","сн","сп","ст","тв","тр","фл","фр","хл","чр","шл","шт"]
const RU_ONSET_HARD   := ["стр","здр","взр","взн","вств","зна","скр","смр","спр","схр","тво","тща","вдр","взб","взг"]

const RU_NUCLEUS      := ["а","е","и","о","у","ы","э","я","ё","ю","ай","ой","ей","ий","ый","уй","ав","ов","ев","ив"]

const RU_CODA_EASY    := ["","л","н","р","т","к","д","ч","с","м","в"]
const RU_CODA_MED     := ["ла","на","ра","та","да","ка","ма","ва","ло","но","ро","то","до","ко","мо","во"]
const RU_CODA_HARD    := ["сть","нье","лье","зна","вна","дна","тна","рна","мна","лна","ств","зть","дть","рть"]

# ══════════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЕ DDA
# ══════════════════════════════════════════════════════════════════════════════

var difficulty_value: float = 0.3
var active: bool = false

var _letters_correct:  int   = 0
var _letters_total:    int   = 0
var _words_per_window: int   = 0
var _kills_per_window: int   = 0
var _eval_timer:       float = 0.0
var _pi_history: Array[float] = []
var _last_pi:     float  = 0.5
var _last_reason: String = ""
var _player: Node = null

# ══════════════════════════════════════════════════════════════════════════════
# СОСТОЯНИЕ WORD DIRECTOR
# ══════════════════════════════════════════════════════════════════════════════

var _word_cache:    Array[String] = []
var _gen_lang:      String = "en"
var _gen_allowed:   Array  = []
var _gen_is_lesson: bool   = false

var _recent_words:  Array[String] = []
const RECENT_MAX   := 40
const CACHE_TARGET := 30


# ══════════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЙ API
# ══════════════════════════════════════════════════════════════════════════════

func start(player_node: Node, lang: String = "en") -> void:
	_player          = player_node
	active           = true
	difficulty_value = 0.3
	_reset_window()
	_eval_timer      = 0.0
	_pi_history.clear()
	_gen_lang        = lang
	_gen_allowed     = []
	_gen_is_lesson   = false
	_word_cache.clear()
	_recent_words.clear()
	print("[DDA] ══════════════════════════════════════════")
	print("[DDA] Режиссёр запущен — ОБЫЧНАЯ ИГРА  lang=%s" % lang)
	print("[DDA] Начальная сложность: %.2f" % difficulty_value)
	print("[DDA] Оценка каждые %d сек | PI цель: [%.2f .. %.2f]" % [EVAL_INTERVAL, TARGET_LOW, TARGET_HIGH])
	print("[DDA] ══════════════════════════════════════════")
	_fill_cache()
	print("[WordDir] Кэш заполнен: %d слов. Первые 5: %s" % [_word_cache.size(), _word_cache.slice(0, 5)])


func start_lesson(lang: String, lesson_index: int) -> void:
	active   = false
	_player  = null
	var lesson      := TypingLessonManager.get_lesson(lang, lesson_index)
	_gen_lang        = lang
	_gen_allowed     = lesson.get("allowed", [])
	_gen_is_lesson   = true
	_word_cache.clear()
	_recent_words.clear()
	#print("[DDA] ══════════════════════════════════════════")
	#print("[DDA] Режиссёр запущен — УРОК  %s · %s" % [lesson.get("title","?"), lesson.get("subtitle","?")])
	#print("[DDA] DDA выключен (параметры урока фиксированы)")
	#print("[WordDir] Разрешённые буквы: %s" % str(_gen_allowed))
	#print("[DDA] ══════════════════════════════════════════")
	#_fill_cache()
	#print("[WordDir] Кэш заполнен: %d слов. Первые 5: %s" % [_word_cache.size(), _word_cache.slice(0, 5)])


func stop() -> void:
	print("[DDA] Режиссёр остановлен.")
	active  = false
	_player = null


func get_next_word() -> String:
	if _word_cache.size() < 8:
		print("[WordDir] Кэш кончается (%d слов) — пополняю..." % _word_cache.size())
		_fill_cache()
	if _word_cache.is_empty():
		var w := _emergency_word()
		print("[WordDir] АВАРИЙНЫЙ фоллбэк → '%s'" % w)
		return w
	var word = _word_cache.pop_front()
	_recent_words.append(word)
	if _recent_words.size() > RECENT_MAX:
		_recent_words.pop_front()
	return word


func record_correct() -> void:
	if not active: return
	_letters_correct += 1
	_letters_total   += 1

func record_error() -> void:
	if not active: return
	_letters_total += 1

func record_kill() -> void:
	if not active: return
	_kills_per_window += 1

func record_word() -> void:
	if not active: return
	_words_per_window += 1


func get_spawn_interval() -> float:
	return lerp(SPAWN_INTERVAL_MAX, SPAWN_INTERVAL_MIN, difficulty_value)

func get_speed_mult() -> float:
	return lerp(SPEED_MULT_MIN, SPEED_MULT_MAX, difficulty_value)

func get_max_enemies() -> int:
	return int(lerp(float(MAX_ENEMIES_MIN), float(MAX_ENEMIES_MAX), difficulty_value))

func get_max_word_length() -> int:
	return int(lerp(float(WORD_LEN_MIN), float(WORD_LEN_MAX), difficulty_value))

func get_debug_info() -> String:
	return (
		"DDA active=%s  diff=%.2f\nPI=%.2f  %s\nspawn=%.1fs  spd=%.2fx  enemies=%d  wlen=%d\nWordCache=%d" % [
			str(active), difficulty_value,
			_last_pi, _last_reason,
			get_spawn_interval(), get_speed_mult(),
			get_max_enemies(), get_max_word_length(),
			_word_cache.size()
		]
	)


# ══════════════════════════════════════════════════════════════════════════════
# ВНУТРЕННЯЯ ЛОГИКА DDA
# ══════════════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	if not active:
		return
	_eval_timer += delta
	if _eval_timer >= EVAL_INTERVAL:
		_eval_timer = 0.0
		_evaluate()


func _evaluate() -> void:
	# ── Метрики окна ────────────────────────────────────────────────────────
	var acc: float = 1.0
	if _letters_total > 0:
		acc = float(_letters_correct) / float(_letters_total)

	var wpm_raw:  float = float(_words_per_window) / (EVAL_INTERVAL / 60.0)
	var wpm_norm: float = clamp(wpm_raw / 60.0, 0.0, 1.0)

	var hp_norm: float = 1.0
	if _player and is_instance_valid(_player) and _player.max_hp > 0:
		hp_norm = float(_player.current_hp) / float(_player.max_hp)

	var kill_norm: float = clamp(float(_kills_per_window) / 15.0, 0.0, 1.0)

	var pi: float = W_ACC * acc + W_WPM * wpm_norm + W_HP * hp_norm + W_KILLS * kill_norm

	# ── Скользящее среднее PI ────────────────────────────────────────────────
	_pi_history.append(pi)
	if _pi_history.size() > HISTORY_SIZE:
		_pi_history.pop_front()
	var smooth_pi: float = 0.0
	for v in _pi_history:
		smooth_pi += v
	smooth_pi /= float(_pi_history.size())
	_last_pi = smooth_pi

	# ── Решение режиссёра ────────────────────────────────────────────────────
	var old_diff := difficulty_value
	var target_diff := difficulty_value
	var decision := ""

	if smooth_pi > TARGET_HIGH:
		var push := (smooth_pi - TARGET_HIGH) / (1.0 - TARGET_HIGH)
		target_diff = difficulty_value + push * MAX_STEP
		_last_reason = "▲ легко (PI=%.2f)" % smooth_pi
		decision = "УСЛОЖНЯЮ"
	elif smooth_pi < TARGET_LOW:
		var push := (TARGET_LOW - smooth_pi) / TARGET_LOW
		target_diff = difficulty_value - push * MAX_STEP
		_last_reason = "▼ тяжело (PI=%.2f)" % smooth_pi
		decision = "УПРОЩАЮ"
	else:
		_last_reason = "— норма (PI=%.2f)" % smooth_pi
		decision = "держу"

	var new_diff = clamp(lerp(difficulty_value, target_diff, INERTIA), DIFFICULTY_MIN, DIFFICULTY_MAX)

	# ── Подробный лог оценки ─────────────────────────────────────────────────
	print("[DDA] ─── Оценка ─────────────────────────────────")
	print("[DDA]   Буквы: %d/%d  Точность: %.0f%%" % [_letters_correct, _letters_total, acc * 100.0])
	print("[DDA]   Слов за окно: %d  WPM_raw: %.1f  WPM_norm: %.2f" % [_words_per_window, wpm_raw, wpm_norm])
	print("[DDA]   HP: %.0f%%  Kill_norm: %.2f" % [hp_norm * 100.0, kill_norm])
	print("[DDA]   PI = acc(%.2f)×%.2f + wpm(%.2f)×%.2f + hp(%.2f)×%.2f + kill(%.2f)×%.2f = %.3f" % [
		acc, W_ACC, wpm_norm, W_WPM, hp_norm, W_HP, kill_norm, W_KILLS, pi
	])
	print("[DDA]   smooth_PI = %.3f  (история: %s)" % [smooth_pi, str(_pi_history)])
	print("[DDA]   Решение: %s  %.2f → %.2f  (цель %.2f, инерция %.2f)" % [
		decision, old_diff, new_diff, target_diff, INERTIA
	])

	if abs(new_diff - old_diff) > 0.005:
		difficulty_value = new_diff
		print("[DDA]   ✓ Сложность изменена: %.3f → %.3f" % [old_diff, difficulty_value])
		print("[DDA]   spawn=%.2fs  speed=%.2fx  max_enemies=%d  word_len=%d" % [
			get_spawn_interval(), get_speed_mult(), get_max_enemies(), get_max_word_length()
		])
		emit_signal("difficulty_changed", difficulty_value)
		_apply_to_enemy_manager()
	else:
		print("[DDA]   — Сложность без изменений (delta=%.4f < 0.005)" % abs(new_diff - old_diff))

	print("[DDA] ─────────────────────────────────────────────")

	_reset_window()
	_word_cache.clear()
	_fill_cache()
	print("[WordDir] Кэш пересобран под diff=%.2f: %d слов. Образцы: %s" % [
		difficulty_value, _word_cache.size(), _word_cache.slice(0, 5)
	])


func _apply_to_enemy_manager() -> void:
	var em := _get_enemy_manager()
	if em == null:
		print("[DDA] ПРЕДУПРЕЖДЕНИЕ: EnemyManager не найден!")
		return
	em.spawn_interval = get_spawn_interval()
	em.spawn_timer.wait_time = em.spawn_interval
	if not em.spawn_timer.is_stopped():
		em.spawn_timer.start()
	em.max_enemies = get_max_enemies()
	var new_len := get_max_word_length()
	if new_len != em.max_word_length:
		em.max_word_length = new_len
		em._rebuild_word_pool()
	print("[DDA] → EnemyManager обновлён: spawn=%.2fs  enemies=%d  word_len=%d" % [
		em.spawn_interval, em.max_enemies, em.max_word_length
	])


func _reset_window() -> void:
	_letters_correct  = 0
	_letters_total    = 0
	_words_per_window = 0
	_kills_per_window = 0


func _get_enemy_manager() -> Node:
	var tree := get_tree()
	if tree == null: return null
	var nodes := tree.get_nodes_in_group("enemy_manager")
	return nodes[0] if not nodes.is_empty() else null


# ══════════════════════════════════════════════════════════════════════════════
# WORD DIRECTOR — ПРОЦЕДУРНАЯ ГЕНЕРАЦИЯ СЛОВ
# ══════════════════════════════════════════════════════════════════════════════

func _fill_cache() -> void:
	var before    := _word_cache.size()
	var attempts  := 0
	var max_att   := CACHE_TARGET * 8
	var rejected_dup  := 0
	var rejected_inv  := 0

	while _word_cache.size() < CACHE_TARGET and attempts < max_att:
		attempts += 1
		var word := _generate_word()
		if word == "":
			rejected_inv += 1
			continue
		if _word_cache.has(word) or _recent_words.has(word):
			rejected_dup += 1
			continue
		_word_cache.append(word)

	print("[WordDir] _fill_cache: было %d → стало %d  (попыток: %d, дубли: %d, невалид: %d)" % [
		before, _word_cache.size(), attempts, rejected_dup, rejected_inv
	])


func _generate_word() -> String:
	var target_len: int
	var complexity: float

	if _gen_is_lesson:
		target_len = randi_range(3, 6)
		complexity = 0.0
	else:
		target_len = randi_range(max(2, get_max_word_length() - 2), get_max_word_length())
		complexity = difficulty_value

	var word   := ""
	var safety := 0

	while word.length() < target_len and safety < 12:
		safety += 1
		var syllable := _make_syllable(complexity)
		if syllable == "":
			continue
		var candidate := word + syllable
		if candidate.length() > target_len + 2:
			break
		word = candidate

	if word.length() < 2:
		return ""

	if word.length() > target_len + 1:
		word = word.substr(0, target_len)

	if _gen_allowed.size() > 0:
		for i in range(word.length()):
			var ch := String.chr(word.unicode_at(i))
			if not _gen_allowed.has(ch):
				return ""

	if not _is_valid_lang(word):
		return ""

	return word


func _make_syllable(complexity: float) -> String:
	var onset   := _pick_onset(complexity)
	var nucleus := _pick_nucleus()
	var coda    := _pick_coda(complexity)
	if _gen_allowed.size() > 0:
		onset   = _filter_to_allowed(onset)
		nucleus = _filter_to_allowed(nucleus)
		coda    = _filter_to_allowed(coda)
	return onset + nucleus + coda


func _pick_onset(complexity: float) -> String:
	var roll := randf()
	if _gen_lang == "ru":
		if complexity < 0.33 or roll < 0.5:  return RU_ONSET_EASY.pick_random()
		elif complexity < 0.66 or roll < 0.8: return RU_ONSET_MED.pick_random()
		else:                                  return RU_ONSET_HARD.pick_random()
	else:
		if complexity < 0.33 or roll < 0.5:  return EN_ONSET_EASY.pick_random()
		elif complexity < 0.66 or roll < 0.8: return EN_ONSET_MED.pick_random()
		else:                                  return EN_ONSET_HARD.pick_random()


func _pick_nucleus() -> String:
	return RU_NUCLEUS.pick_random() if _gen_lang == "ru" else EN_NUCLEUS.pick_random()


func _pick_coda(complexity: float) -> String:
	var roll := randf()
	if _gen_lang == "ru":
		if complexity < 0.33 or roll < 0.4:  return RU_CODA_EASY.pick_random()
		elif complexity < 0.66 or roll < 0.75: return RU_CODA_MED.pick_random()
		else:                                   return RU_CODA_HARD.pick_random()
	else:
		if complexity < 0.33 or roll < 0.4:  return EN_CODA_EASY.pick_random()
		elif complexity < 0.66 or roll < 0.75: return EN_CODA_MED.pick_random()
		else:                                   return EN_CODA_HARD.pick_random()


func _filter_to_allowed(s: String) -> String:
	var result := ""
	for i in range(s.length()):
		var ch := String.chr(s.unicode_at(i))
		if _gen_allowed.has(ch):
			result += ch
	return result


func _is_valid_lang(word: String) -> bool:
	for i in range(word.length()):
		var cp := word.unicode_at(i)
		var is_latin    := (cp >= 97 and cp <= 122)
		var is_cyrillic := (cp >= 0x430 and cp <= 0x44F) or cp == 0x451
		if not (is_latin or is_cyrillic):
			return false
	return true


func _emergency_word() -> String:
	var em := _get_enemy_manager()
	if em != null and em.word_pool.size() > 0:
		return em.word_pool.pick_random()
	if _gen_lang == "ru":
		return ["маг","огнь","лёд","тьма","свет"].pick_random()
	return ["fire","ice","bolt","mana","dark"].pick_random()
