extends Node

# ==========================================
# МЕНЕДЖЕР УРОКОВ СЛЕПОЙ ПЕЧАТИ
# Singleton — добавь в Project → Autoload как "TypingLessonManager"
#
# Поддерживает два языка:
#   "en" — английская раскладка QWERTY
#   "ru" — русская раскладка ЙЦУКЕН
#
# Прогресс хранится отдельно для каждого языка.
# ==========================================

signal lesson_changed(lang: String, lesson_index: int, lesson_data: Dictionary)

# Активный язык: "en" или "ru"
var active_lang: String = "en"

# Текущий урок для каждого языка (0-based)
var current_lesson_en: int = 0
var current_lesson_ru: int = 0

const SAVE_PATH := "user://typing_progress.json"

# ─────────────────────────────────────────────────────────────────────────────
# АНГЛИЙСКИЕ УРОКИ (QWERTY, home-row first)
#
# Раскладка физических клавиш:
#   Home row:  A S D F [space] J K L ;
#   Top row:   Q W E R T  Y U I O P
#   Bot row:   Z X C V B  N M , . /
#
# Стратегия: каждый урок добавляет по 1-2 клавиши, слова только из
#            уже освоенных. Сложность растёт плавно.
# ─────────────────────────────────────────────────────────────────────────────
const LESSONS_EN := [
	# Урок 1 ── F J (указательные home row) ──────────────────────────────────
	{
		"title": "EN 1", "subtitle": "Home row: F J",
		"keys": "F · J",
		"lang": "en",
		"allowed": ["f","j"],
		"description": "Указательные пальцы. Левый на F, правый на J. Не смотри на клавиатуру!",
		"words": [
			"ff","jj","fj","jf","fjf","jfj","ffj","jjf",
			"fjj","jff","ffjj","jjff","fjfj","jfjf","fffj","jjjf","fjff","jfjj",
			"fjfjf","jfjfj","ffjjf","jjffj","ffffjj","jjjjff"
		],
		"spawn_interval": 3.8, "max_enemies": 7, "enemy_speed_mult": 0.50,
		"duration": 90.0, "hp_mult": 0.7,
	},
	# Урок 2 ── + D K (средние пальцы home row) ───────────────────────────────
	{
		"title": "EN 2", "subtitle": "Home row: F J D K",
		"keys": "D · F · J · K",
		"lang": "en",
		"allowed": ["f","j","d","k"],
		"description": "Средние пальцы: D — левый, K — правый. Руки не двигаются!",
		"words": [
			"df","kj","dk","fk","jd","dkf","fjk","jkd","fdk","jdf",
			"dfk","kjf","dfjk","jkfd","fdkj","jkdf","dkfj","fjdk",
			"ffjd","kkdj","dfjj","kffd","jkdk","fdfd","kjkj",
			"dkdkf","fjkjd","kdfkj","jdfjk"
		],
		"spawn_interval": 3.5, "max_enemies": 9, "enemy_speed_mult": 0.55,
		"duration": 95.0, "hp_mult": 0.75,
	},
	# Урок 3 ── + S L (безымянные home row) ──────────────────────────────────
	{
		"title": "EN 3", "subtitle": "Home row: S D F J K L",
		"keys": "S · D · F · J · K · L",
		"lang": "en",
		"allowed": ["f","j","d","k","s","l"],
		"description": "Безымянные пальцы: S — левый, L — правый. Держи остальные на месте!",
		"words": [
			"sl","ls","sf","lj","sdf","lkj","slk","fls","dsl","kjl",
			"sdfl","lkjs","fsdl","jlks","sldf","lkjf","dsfl","jkls",
			"sfdk","ljkd","fsdkl","jlkds","sdlkf","lkjfs","dslkj",
			"sfjkl","lkdsf","djkls","fsdlk"
		],
		"spawn_interval": 3.2, "max_enemies": 11, "enemy_speed_mult": 0.58,
		"duration": 100.0, "hp_mult": 0.8,
	},
	# Урок 4 ── + A (мизинец левой, полный home row) ──────────────────────────
	{
		"title": "EN 4", "subtitle": "Full home row: A S D F J K L",
		"keys": "A · S · D · F · J · K · L",
		"lang": "en",
		"allowed": ["a","s","d","f","j","k","l"],
		"description": "Мизинец левой — A. Полный домашний ряд освоен. Теперь настоящие слова!",
		"words": [
			"as","ask","fad","lad","sad","lass","fall","flask","salad",
			"flak","flags","alsk","dfall","asdfl","jklsa","fdask","ljksa",
			"salfl","klasd","fadsl","lads","dals","slaf","kalds",
			"flask","daffs","jaskl","salads","flasks","kafkals"
		],
		"spawn_interval": 3.0, "max_enemies": 13, "enemy_speed_mult": 0.62,
		"duration": 105.0, "hp_mult": 0.85,
	},
	# Урок 5 ── + E I (средние пальцы top row) ───────────────────────────────
	{
		"title": "EN 5", "subtitle": "Top row: E I",
		"keys": "A S D F J K L  +  E · I",
		"lang": "en",
		"allowed": ["a","s","d","f","j","k","l","e","i"],
		"description": "Средние пальцы вверх: E над D (левый), I над K (правый).",
		"words": [
			"idea","side","file","aide","said","sail","fail","deal","dial",
			"isle","slid","deli","idle","field","ideal","slide","aside",
			"fails","deals","filed","aided","alias","diesel","inside",
			"ladies","detail","ideals","fileds","easied","skilled","afield"
		],
		"spawn_interval": 2.8, "max_enemies": 13, "enemy_speed_mult": 0.65,
		"duration": 110.0, "hp_mult": 0.88,
	},
	# Урок 6 ── + R U (указательные top row) ─────────────────────────────────
	{
		"title": "EN 6", "subtitle": "Top row: R U",
		"keys": "... E I  +  R · U",
		"lang": "en",
		"allowed": ["a","s","d","f","j","k","l","e","i","r","u"],
		"description": "Указательные вверх: R над F (левый), U над J (правый).",
		"words": [
			"rule","rude","sure","lure","duel","fuel","ruse","ride","rife",
			"furl","slur","druid","ruler","raise","rural","fluid","fired",
			"rueful","feudal","lurid","figure","desire","flurry",
			"allured","redrail","residual","failure","uredials"
		],
		"spawn_interval": 2.6, "max_enemies": 14, "enemy_speed_mult": 0.68,
		"duration": 115.0, "hp_mult": 0.9,
	},
	# Урок 7 ── + T Y (центр top row, указательные растяжка) ─────────────────
	{
		"title": "EN 7", "subtitle": "Top row: T Y",
		"keys": "... R U  +  T · Y",
		"lang": "en",
		"allowed": ["a","s","d","f","j","k","l","e","i","r","u","t","y"],
		"description": "Растяжка указательных: T — левый (рядом с R), Y — правый (рядом с U).",
		"words": [
			"try","yet","stay","tray","year","style","truly","layer","ready",
			"study","dirty","rusty","dusty","trend","stead","daily","trial",
			"tired","tears","stray","ultra","trust","yeast","tasty",
			"starry","yearly","steady","sturdy","reality","auditory"
		],
		"spawn_interval": 2.5, "max_enemies": 15, "enemy_speed_mult": 0.70,
		"duration": 120.0, "hp_mult": 0.92,
	},
	# Урок 8 ── + W O (средние пальцы top row) ───────────────────────────────
	{
		"title": "EN 8", "subtitle": "Top row: W O",
		"keys": "... T Y  +  W · O",
		"lang": "en",
		"allowed": ["a","s","d","f","j","k","l","e","i","r","u","t","y","w","o"],
		"description": "Средние пальцы вверх: W над S (левый), O над L (правый).",
		"words": [
			"word","work","world","row","flow","glow","slow","tower","lower",
			"power","sword","storm","story","worry","worth","wrist","wrote",
			"toward","worker","forest","effort","roster","trowel",
			"software","workout","outward","desktop","storeward"
		],
		"spawn_interval": 2.4, "max_enemies": 16, "enemy_speed_mult": 0.72,
		"duration": 120.0, "hp_mult": 0.95,
	},
	# Урок 9 ── + Q P (мизинцы top row) ──────────────────────────────────────
	{
		"title": "EN 9", "subtitle": "Top row: Q P",
		"keys": "... W O  +  Q · P",
		"lang": "en",
		"allowed": ["a","s","d","f","j","k","l","e","i","r","u","t","y","w","o","q","p"],
		"description": "Мизинцы вверх: Q над A (левый), P над ; (правый). Максимальная растяжка!",
		"words": [
			"stop","sport","drip","trip","strip","quip","prowl","optic",
			"tulip","pilot","depot","squat","quart","equity","potion",
			"poetry","report","expert","output","laptop","support",
			"deposit","quality","quartet","property","purposely"
		],
		"spawn_interval": 2.3, "max_enemies": 17, "enemy_speed_mult": 0.75,
		"duration": 125.0, "hp_mult": 1.0,
	},
	# Урок 10 ── + V M (указательные bottom row) ─────────────────────────────
	{
		"title": "EN 10", "subtitle": "Bottom row: V M",
		"keys": "... Q P  +  V · M",
		"lang": "en",
		"allowed": ["a","s","d","f","j","k","l","e","i","r","u","t","y","w","o","q","p","v","m"],
		"description": "Указательные вниз: V под F (левый), M под J (правый).",
		"words": [
			"move","mover","value","vital","vivid","marvel","mortal","volume",
			"market","mature","vertex","movies","remote","victim","system",
			"master","timber","memory","summer","mirror","vampire","mixture",
			"improve","primary","symptom","viewpoint","memorize"
		],
		"spawn_interval": 2.2, "max_enemies": 18, "enemy_speed_mult": 0.78,
		"duration": 130.0, "hp_mult": 1.0,
	},
	# Урок 11 ── + C N (средние пальцы bottom row) ───────────────────────────
	{
		"title": "EN 11", "subtitle": "Bottom row: C N",
		"keys": "... V M  +  C · N",
		"lang": "en",
		"allowed": ["a","s","d","f","j","k","l","e","i","r","u","t","y","w","o","q","p","v","m","c","n"],
		"description": "Средние пальцы вниз: C под D (левый), N под J (правый).",
		"words": [
			"can","scan","nice","mice","since","fence","clinic","cosmic","iconic",
			"mentor","nation","concert","concern","control","contact","content",
			"central","science","opinion","concept","contract","medicine",
			"currency","function","incident","conscious","convenient"
		],
		"spawn_interval": 2.1, "max_enemies": 19, "enemy_speed_mult": 0.80,
		"duration": 130.0, "hp_mult": 1.05,
	},
	# Урок 12 ── + X B (безымянный + указательный bottom row) ────────────────
	{
		"title": "EN 12", "subtitle": "Bottom row: X B",
		"keys": "... C N  +  X · B",
		"lang": "en",
		"allowed": ["a","s","d","f","j","k","l","e","i","r","u","t","y","w","o","q","p","v","m","c","n","x","b"],
		"description": "X под S (безымянный левый), B между V и N (указательный правый).",
		"words": [
			"box","fox","flex","text","next","exit","extra","boxer","toxic",
			"exact","excel","exert","combat","submit","object","subject",
			"combine","exhibit","explore","express","extreme","exciting",
			"exchange","excellent","existence","substrate","expedition"
		],
		"spawn_interval": 2.0, "max_enemies": 20, "enemy_speed_mult": 0.83,
		"duration": 135.0, "hp_mult": 1.1,
	},
	# Урок 13 ── + Z G H (мизинец bottom + центр home расширение) ────────────
	{
		"title": "EN 13", "subtitle": "Bottom row: Z  +  G H",
		"keys": "... X B  +  Z · G · H",
		"lang": "en",
		"allowed": ["a","s","d","f","j","k","l","e","i","r","u","t","y","w","o","q","p","v","m","c","n","x","b","z","g","h"],
		"description": "Z под A (мизинец). G рядом с F, H рядом с J — расширение указательных.",
		"words": [
			"zone","zero","gaze","haze","graze","glaze","ghost","zoning",
			"hazard","zenith","bizarre","height","growth","gather","health",
			"breath","hunger","garden","handle","grizzly","weather",
			"together","although","strengthen","astonishing"
		],
		"spawn_interval": 1.9, "max_enemies": 21, "enemy_speed_mult": 0.86,
		"duration": 140.0, "hp_mult": 1.15,
	},
	# Урок 14 ── ФИНАЛ: весь алфавит ──────────────────────────────────────────
	{
		"title": "EN 14", "subtitle": "ФИНАЛ: Все буквы",
		"keys": "Весь алфавит",
		"lang": "en",
		"allowed": ["a","b","c","d","e","f","g","h","i","j","k","l","m",
					"n","o","p","q","r","s","t","u","v","w","x","y","z"],
		"description": "Все клавиши освоены. Докажи мастерство слепой печати!",
		"words": [
			"quick","brown","jumps","sphinx","waltz","fjord","blitz","proxy",
			"glyph","jinx","quiz","complex","quantum","wizard","zombie",
			"oxygen","python","jungle","whiskey","triumph","boycott",
			"symptom","develop","example","kingdom","mixture","network",
			"obscure","perfect","require","station","thunder","uniform",
			"venture","warning","extreme","younger","zealous","absolute",
			"boundary","champion","frequency","objectives"
		],
		"spawn_interval": 1.6, "max_enemies": 24, "enemy_speed_mult": 0.95,
		"duration": 180.0, "hp_mult": 1.25,
	},
]

# ─────────────────────────────────────────────────────────────────────────────
# РУССКИЕ УРОКИ (ЙЦУКЕН, home-row first)
#
# Физическая карта ЙЦУКЕН:
#   Home row:  Ф Ы В А [пробел] О Л Д Ж Э
#   Top row:   Й Ц У К Е  Н Г Ш Щ З Х
#   Bot row:   Я Ч С М И  Т Ь Б Ю .
#
# Позиции пальцев (левая рука → правая рука):
#   Мизинец:    Ф / Ж
#   Безымянный: Ы / Д  (top: Ц / Г)
#   Средний:    В / Л  (top: У / Ш)
#   Указательный: А Е / О Н  (top: К Е / Н Г)  (bot: М И / Т Ь)
#   Указательный расширение: home Е / Н → top Е / Н
#
# Внимание: для Godot 4 кириллица приходит через event.unicode,
# поэтому allowed содержит Unicode-символы кириллицы в нижнем регистре.
# ─────────────────────────────────────────────────────────────────────────────
const LESSONS_RU := [
	# Урок 1 ── А О (указательные home row) ──────────────────────────────────
	{
		"title": "RU 1", "subtitle": "Домашний ряд: А О",
		"keys": "А · О",
		"lang": "ru",
		"allowed": ["а","о"],
		"description": "Указательные пальцы: А — левый (как F), О — правый (как J). База всего!",
		"words": [
			"аа","оо","ао","оа","аоа","оао","ааo","ооа",
			"аоо","оаа","ааоо","ооаа","аоао","оаоа",
			"аааo","оооа","аоаа","оаоо","ааоао","оооаа"
		],
		"spawn_interval": 3.8, "max_enemies": 7, "enemy_speed_mult": 0.50,
		"duration": 90.0, "hp_mult": 0.7,
	},
	# Урок 2 ── + В Л (средние пальцы home row) ──────────────────────────────
	{
		"title": "RU 2", "subtitle": "Домашний ряд: А В О Л",
		"keys": "В · А · О · Л",
		"lang": "ru",
		"allowed": ["а","о","в","л"],
		"description": "Средние пальцы: В — левый (как D), Л — правый (как K).",
		"words": [
			"во","ов","ал","ла","вал","лов","вол","ала",
			"овал","лава","вола","авол","лаво","волна",
			"влаво","лавол","авола","воавл","лавол",
			"волал","аволл","лвова","авлол"
		],
		"spawn_interval": 3.5, "max_enemies": 9, "enemy_speed_mult": 0.55,
		"duration": 95.0, "hp_mult": 0.75,
	},
	# Урок 3 ── + Ы Д (безымянные home row) ──────────────────────────────────
	{
		"title": "RU 3", "subtitle": "Домашний ряд: Ы В А О Л Д",
		"keys": "Ы · В · А · О · Л · Д",
		"lang": "ru",
		"allowed": ["а","о","в","л","ы","д"],
		"description": "Безымянные: Ы — левый (как S), Д — правый (как L).",
		"words": [
			"ды","ыл","вды","лыд","одыл","выда","лоды",
			"давол","ловды","выдал","долов","ладов","лодыд",
			"водыл","давол","ловды","авдол","лыдва",
			"выдол","доавл","лывод","давыл"
		],
		"spawn_interval": 3.2, "max_enemies": 11, "enemy_speed_mult": 0.58,
		"duration": 100.0, "hp_mult": 0.8,
	},
	# Урок 4 ── + Ф (мизинец левой, полный home row) ──────────────────────────
	{
		"title": "RU 4", "subtitle": "Полный домашний ряд: Ф Ы В А О Л Д",
		"keys": "Ф · Ы · В · А · О · Л · Д",
		"lang": "ru",
		"allowed": ["а","о","в","л","ы","д","ф"],
		"description": "Мизинец левой — Ф. Весь домашний ряд под рукой! Настоящие слова.",
		"words": [
			"фол","фала","флаг","дыфо","влодф",
			"вода","лада","фада","довыл","флода",
			"довод","давал","водал","ловда","фавол",
			"вдоль","давол","флодыв","водолы","далофы"
		],
		"spawn_interval": 3.0, "max_enemies": 13, "enemy_speed_mult": 0.62,
		"duration": 105.0, "hp_mult": 0.85,
	},
	# Урок 5 ── + Е Н (указательные top row) ─────────────────────────────────
	{
		"title": "RU 5", "subtitle": "Верхний ряд: Е Н",
		"keys": "Ф Ы В А О Л Д  +  Е · Н",
		"lang": "ru",
		"allowed": ["а","о","в","л","ы","д","ф","е","н"],
		"description": "Указательные вверх: Е над А (левый), Н над О (правый).",
		"words": [
			"не","он","она","дно","вне","лень","нова",
			"вода","долен","ловен","наволок","длина",
			"новела","надол","ловена","долена","водяне",
			"навело","деловой","новелла","воевода","доноване"
		],
		"spawn_interval": 2.8, "max_enemies": 13, "enemy_speed_mult": 0.65,
		"duration": 110.0, "hp_mult": 0.88,
	},
	# Урок 6 ── + К Г (указательные top row расширение) ──────────────────────
	{
		"title": "RU 6", "subtitle": "Верхний ряд: К Г",
		"keys": "... Е Н  +  К · Г",
		"lang": "ru",
		"allowed": ["а","о","в","л","ы","д","ф","е","н","к","г"],
		"description": "Указательные дальше вверх: К (как R), Г (как U).",
		"words": [
			"кол","год","кого","гол","нога","лёгок",
			"конек","дорога","голода","волков","кладов",
			"навыков","дольник","голодный","надолго",
			"колодка","гвоздок","воеводка","надолбок"
		],
		"spawn_interval": 2.6, "max_enemies": 14, "enemy_speed_mult": 0.68,
		"duration": 115.0, "hp_mult": 0.9,
	},
	# Урок 7 ── + У Ш (средние пальцы top row) ───────────────────────────────
	{
		"title": "RU 7", "subtitle": "Верхний ряд: У Ш",
		"keys": "... К Г  +  У · Ш",
		"lang": "ru",
		"allowed": ["а","о","в","л","ы","д","ф","е","н","к","г","у","ш"],
		"description": "Средние пальцы вверх: У (как E), Ш (как I).",
		"words": [
			"шум","душа","куль","шнур","нужно","кушать",
			"нашего","дышать","кулаком","гулянка","надолго",
			"душевный","дальнего","клушавых","душегубке",
			"надлежащего","нудноватый","холодновато"
		],
		"spawn_interval": 2.5, "max_enemies": 15, "enemy_speed_mult": 0.70,
		"duration": 120.0, "hp_mult": 0.92,
	},
	# Урок 8 ── + Ц Х (безымянные + мизинец top row) ─────────────────────────
	{
		"title": "RU 8", "subtitle": "Верхний ряд: Ц Й Х",
		"keys": "... У Ш  +  Ц · Й · Х",
		"lang": "ru",
		"allowed": ["а","о","в","л","ы","д","ф","е","н","к","г","у","ш","ц","й","х"],
		"description": "Ц — безымянный (как W). Й — мизинец левой (как Q). Х — мизинец правой (как P).",
		"words": [
			"цех","цель","цыган","цунами","йод","хол",
			"хлеб","цикл","цокот","доход","сухой","лихой",
			"цифра","конъюнктура","хохочет","цыплячий",
			"нахождение","колосьях","доходность"
		],
		"spawn_interval": 2.4, "max_enemies": 16, "enemy_speed_mult": 0.72,
		"duration": 120.0, "hp_mult": 0.95,
	},
	# Урок 9 ── + И Т (указательные bottom row) ──────────────────────────────
	{
		"title": "RU 9", "subtitle": "Нижний ряд: И Т",
		"keys": "... + И · Т",
		"lang": "ru",
		"allowed": ["а","о","в","л","ы","д","ф","е","н","к","г","у","ш","ц","й","х","и","т"],
		"description": "Указательные вниз: И (как V), Т (как M). Первые клавиши нижнего ряда.",
		"words": [
			"кит","тихо","нити","одни","итог","часть",
			"тишина","водить","нитки","хитрость","выгодить",
			"кинутый","достичь","атланты","хитиновый",
			"активности","логическое","интуитивное"
		],
		"spawn_interval": 2.3, "max_enemies": 17, "enemy_speed_mult": 0.75,
		"duration": 125.0, "hp_mult": 1.0,
	},
	# Урок 10 ── + М Ь (средние bottom row) ──────────────────────────────────
	{
		"title": "RU 10", "subtitle": "Нижний ряд: М Ь",
		"keys": "... И Т  +  М · Ь",
		"lang": "ru",
		"allowed": ["а","о","в","л","ы","д","ф","е","н","к","г","у","ш","ц","й","х","и","т","м","ь"],
		"description": "М — средний левой вниз (как C), Ь — средний правой вниз (как N).",
		"words": [
			"мать","миль","мить","темь","мышь","мотив",
			"только","вымыть","мягкий","тихонько","думаешь",
			"молодой","дымоход","кинотеатр","достоинство",
			"вымотанный","выходные","молниеносно"
		],
		"spawn_interval": 2.2, "max_enemies": 18, "enemy_speed_mult": 0.78,
		"duration": 130.0, "hp_mult": 1.0,
	},
	# Урок 11 ── + С Б (безымянные bottom row) ───────────────────────────────
	{
		"title": "RU 11", "subtitle": "Нижний ряд: С Б",
		"keys": "... М Ь  +  С · Б",
		"lang": "ru",
		"allowed": ["а","о","в","л","ы","д","ф","е","н","к","г","у","ш","ц","й","х","и","т","м","ь","с","б"],
		"description": "С — безымянный левой вниз (как X), Б — безымянный правой (как M-right area).",
		"words": [
			"бас","смог","слой","биос","косить","смотри",
			"быстро","сигнал","небось","добиться","сомнение",
			"состояние","обоснование","осмысленное","беспокойство",
			"самостоятельно","достопримечательность"
		],
		"spawn_interval": 2.1, "max_enemies": 19, "enemy_speed_mult": 0.80,
		"duration": 130.0, "hp_mult": 1.05,
	},
	# Урок 12 ── + Я Ч (мизинец + первый bottom row) ─────────────────────────
	{
		"title": "RU 12", "subtitle": "Нижний ряд: Я Ч",
		"keys": "... С Б  +  Я · Ч",
		"lang": "ru",
		"allowed": ["а","о","в","л","ы","д","ф","е","н","к","г","у","ш","ц","й","х","и","т","м","ь","с","б","я","ч"],
		"description": "Я — мизинец левой вниз (как Z). Ч — между С и М (как X-area).",
		"words": [
			"яма","чаша","ячмень","чистый","являться",
			"ячейка","чугунный","начать","обычный","сочный",
			"значительный","человечность","неначатый",
			"случайность","нечаянность","бесконечность"
		],
		"spawn_interval": 2.0, "max_enemies": 20, "enemy_speed_mult": 0.83,
		"duration": 135.0, "hp_mult": 1.1,
	},
	# Урок 13 ── + З Щ Ж Э Ю (правый край + остатки) ─────────────────────────
	{
		"title": "RU 13", "subtitle": "Края: З Щ Ж Э Ю",
		"keys": "... Я Ч  +  З · Щ · Ж · Э · Ю",
		"lang": "ru",
		"allowed": ["а","о","в","л","ы","д","ф","е","н","к","г","у","ш","ц","й","х","и","т","м","ь","с","б","я","ч","з","щ","ж","э","ю"],
		"description": "Правый край и редкие буквы: З (top left), Щ (top right), Ж Э (home right), Ю (bottom right).",
		"words": [
			"зима","щука","жест","этот","южный","зонт",
			"щётка","жадный","эффект","южное","зубной",
			"жёсткость","эклектика","ежегодный","южнобережный",
			"захватывающий","эффективность","южнославянский"
		],
		"spawn_interval": 1.9, "max_enemies": 21, "enemy_speed_mult": 0.86,
		"duration": 140.0, "hp_mult": 1.15,
	},
	# Урок 14 ── + П Р (верхний ряд, остатки) ────────────────────────────────
	{
		"title": "RU 14", "subtitle": "Верхний ряд: П Р",
		"keys": "... З Щ  +  П · Р",
		"lang": "ru",
		"allowed": ["а","о","в","л","ы","д","ф","е","н","к","г","у","ш","ц","й","х","и","т","м","ь","с","б","я","ч","з","щ","ж","э","ю","п","р"],
		"description": "П (как O, правый безымянный вверх), Р (как H, правый указательный home расширение).",
		"words": [
			"пар","рот","прут","порт","репа","простой",
			"природа","реформа","простор","преграда",
			"программа","предметный","реставрация",
			"представительство","практически"
		],
		"spawn_interval": 1.8, "max_enemies": 22, "enemy_speed_mult": 0.88,
		"duration": 145.0, "hp_mult": 1.2,
	},
	# Урок 15 ── ФИНАЛ: весь русский алфавит ──────────────────────────────────
	{
		"title": "RU 15", "subtitle": "ФИНАЛ: Все буквы",
		"keys": "Вся раскладка ЙЦУКЕН",
		"lang": "ru",
		"allowed": ["а","б","в","г","д","е","ё","ж","з","и","й","к","л","м",
					"н","о","п","р","с","т","у","ф","х","ц","ч","ш","щ","ъ",
					"ы","ь","э","ю","я"],
		"description": "Весь русский алфавит. Ты прошёл все уроки — теперь докажи мастерство!",
		"words": [
			"программа","клавиатура","скорость","точность","упражнение",
			"безупречный","фотография","экономика","ювелирный","щедрость",
			"объяснение","чувствовать","неожиданный","достижение",
			"пространство","взаимодействие","международный","производительность",
			"преобразование","удовлетворение","сосредоточиться",
			"последовательность","непосредственный","замечательный"
		],
		"spawn_interval": 1.6, "max_enemies": 24, "enemy_speed_mult": 0.95,
		"duration": 180.0, "hp_mult": 1.3,
	},
]

# ─────────────────────────────────────────────────────────────────────────────
# МЕТОДЫ API
# ─────────────────────────────────────────────────────────────────────────────

func get_lessons(lang: String) -> Array:
	match lang:
		"en": return LESSONS_EN
		"ru": return LESSONS_RU
	return LESSONS_EN


func get_lesson_count(lang: String) -> int:
	return get_lessons(lang).size()


func get_lesson(lang: String, index: int) -> Dictionary:
	var arr := get_lessons(lang)
	return arr[clamp(index, 0, arr.size() - 1)]


func get_current_index(lang: String) -> int:
	match lang:
		"en": return current_lesson_en
		"ru": return current_lesson_ru
	return 0


func get_current_lesson(lang: String) -> Dictionary:
	return get_lesson(lang, get_current_index(lang))


func set_lesson(lang: String, index: int) -> void:
	var max_i := get_lesson_count(lang) - 1
	match lang:
		"en": current_lesson_en = clamp(index, 0, max_i)
		"ru": current_lesson_ru = clamp(index, 0, max_i)
	emit_signal("lesson_changed", lang, get_current_index(lang), get_current_lesson(lang))


func get_word_for_lesson(lang: String, lesson_index: int) -> String:
	var words: Array = get_lesson(lang, lesson_index)["words"]
	return words.pick_random()


func get_allowed_letters(lang: String, lesson_index: int) -> Array:
	return get_lesson(lang, lesson_index)["allowed"]


func advance_lesson(lang: String) -> void:
	var idx := get_current_index(lang)
	var max_i := get_lesson_count(lang) - 1
	if idx < max_i:
		set_lesson(lang, idx + 1)
		save_progress()


# ─────────────────────────────────────────────────────────────────────────────
# СОХРАНЕНИЕ ПРОГРЕССА
# ─────────────────────────────────────────────────────────────────────────────

func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if data is Dictionary:
		if data.has("en"):
			current_lesson_en = clamp(int(data["en"]), 0, LESSONS_EN.size() - 1)
		if data.has("ru"):
			current_lesson_ru = clamp(int(data["ru"]), 0, LESSONS_RU.size() - 1)


func save_progress() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"en": current_lesson_en, "ru": current_lesson_ru}))
		f.close()
