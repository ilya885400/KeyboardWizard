extends Node

# ==========================================
# КНИГА ЗАКЛИНАНИЙ И МАГИЧЕСКИХ РИТУАЛОВ
# Singleton — добавь в Project → Autoload как "TypingLessonManager"
#
# Древние свитки поддерживают два наречия:
#   "en" — Эльфийские руны Эльдарии (QWERTY)
#   "ru" — Руны Древних Хранителей (ЙЦУКЕН)
#
# Магический опыт и прогресс волшебника хранятся отдельно для каждого языка.
# ==========================================

signal lesson_changed(lang: String, lesson_index: int, lesson_data: Dictionary)

# Активное наречие: "en" или "ru"
var active_lang: String = "en"

# Текущая ступень мастерства для каждого языка (0-based)
var current_lesson_en: int = 0
var current_lesson_ru: int = 0

const SAVE_PATH := "user://typing_progress.json"

# ─────────────────────────────────────────────────────────────────────────────
# СВИТКИ ЭЛЬФИЙСКИХ РУН (QWERTY, с центрального ряда)
#
# Ключ "new_letters" указывает, какие именно руны пробуждаются в данном испытании.
# ─────────────────────────────────────────────────────────────────────────────
const LESSONS_EN := [
	# Испытание 1 ── F J ──────────────────────────────────────────────────────
	{
		"title": "EN 1", "subtitle": "Home row: F J",
		"keys": "F · J",
		"lang": "en",
		"new_letters": ["f", "j"],
		"allowed": ["f","j"],
		"description": "Первые искры магии. Положи указательные пальцы на F и J. Сконцентрируй внутренний взор, не смотри на клавиатуру!",
		"words": [
			"ff","jj","fj","jf","fjf","jfj","ffj","jjf",
			"fjj","jff","ffjj","jjff","fjfj","jfjf","fffj","jjjf","fjff","jfjj",
			"fjfjf","jfjfj","ffjjf","jjffj","ffffjj","jjjjff"
		],
		"spawn_interval": 3.8, "max_enemies": 7, "enemy_speed_mult": 0.50,
		"duration": 90.0, "hp_mult": 0.7,
	},
	# Испытание 2 ── + D K ────────────────────────────────────────────────────
	{
		"title": "EN 2", "subtitle": "Home row: F J D K",
		"keys": "D · F · J · K",
		"lang": "en",
		"new_letters": ["d", "k"],
		"allowed": ["f","j","d","k"],
		"description": "Усиление потока. Подключи средние пальцы: D для левой руки, K — для правой. Удерживай ладони неподвижно, как при ковке артефакта.",
		"words": [
			"df","kj","dk","fk","jd","dkf","fjk","jkd","fdk","jdf",
			"dfk","kjf","dfjk","jkfd","fdkj","jkdf","dkfj","fjdk",
			"ffjd","kkdj","dfjj","kffd","jkdk","fdfd","kjkj",
			"dkdkf","fjkjd","kdfkj","jdfjk"
		],
		"spawn_interval": 3.5, "max_enemies": 9, "enemy_speed_mult": 0.55,
		"duration": 95.0, "hp_mult": 0.75,
	},
	# Испытание 3 ── + S L ────────────────────────────────────────────────────
	{
		"title": "EN 3", "subtitle": "Home row: S D F J K L",
		"keys": "S · D · F · J · K · L",
		"lang": "en",
		"new_letters": ["s", "l"],
		"allowed": ["f","j","d","k","s","l"],
		"description": "Плетение защитного круга. Пробуди безымянные пальцы: S слева и L справа. Пускай остальные руны остаются на своих местах.",
		"words": [
			"sl","ls","sf","lj","sdf","lkj","slk","fls","dsl","kjl",
			"sdfl","lkjs","fsdl","jlks","sldf","lkjf","dsfl","jkls",
			"sfdk","ljkd","fsdkl","jlkds","sdlkf","lkjfs","dslkj",
			"sfjkl","lkdsf","djkls","fsdlk"
		],
		"spawn_interval": 3.2, "max_enemies": 11, "enemy_speed_mult": 0.58,
		"duration": 100.0, "hp_mult": 0.8,
	},
	# Испытание 4 ── + A ──────────────────────────────────────────────────────
	{
		"title": "EN 4", "subtitle": "Full home row: A S D F J K L",
		"keys": "A · S · D · F · J · K · L",
		"lang": "en",
		"new_letters": ["a"],
		"allowed": ["a","s","d","f","j","k","l"],
		"description": "Замыкание контура. Левый мизинец касается руны A. Центральный барьер полностью активирован. Пора сокрушать монстров первыми истинными заклинаниями!",
		"words": [
			"as","ask","fad","lad","sad","lass","fall","flask","salad",
			"flak","flags","alsk","dfall","asdfl","jklsa","fdask","ljksa",
			"salfl","klasd","fadsl","lads","dals","slaf","kalds",
			"flask","daffs","jaskl","salads","flasks","kafkals"
		],
		"spawn_interval": 3.0, "max_enemies": 13, "enemy_speed_mult": 0.62,
		"duration": 105.0, "hp_mult": 0.85,
	},
	# Испытание 5 ── + E I ────────────────────────────────────────────────────
	{
		"title": "EN 5", "subtitle": "Top row: E I",
		"keys": "A S D F J K L  +  E · I",
		"lang": "en",
		"new_letters": ["e", "i"],
		"allowed": ["a","s","d","f","j","k","l","e","i"],
		"description": "Восхождение к Верхнему Миру. Направь средние пальцы вверх: E возвышается над D, а I — над K.",
		"words": [
			"idea","side","file","aide","said","sail","fail","deal","dial",
			"isle","slid","deli","idle","field","ideal","slide","aside",
			"fails","deals","filed","aided","alias","diesel","inside",
			"ladies","detail","ideals","fileds","easied","skilled","afield"
		],
		"spawn_interval": 2.8, "max_enemies": 13, "enemy_speed_mult": 0.65,
		"duration": 110.0, "hp_mult": 0.88,
	},
	# Испытание 6 ── + R U ────────────────────────────────────────────────────
	{
		"title": "EN 6", "subtitle": "Top row: R U",
		"keys": "... E I  +  R · U",
		"lang": "en",
		"new_letters": ["r", "u"],
		"allowed": ["a","s","d","f","j","k","l","e","i","r","u"],
		"description": "Руны Небесного Огня. Указательные пальцы тянутся ввысь: левый призывает R над F, правый — U над J.",
		"words": [
			"rule","rude","sure","lure","duel","fuel","ruse","ride","rife",
			"furl","slur","druid","ruler","raise","rural","fluid","fired",
			"rueful","feudal","lurid","figure","desire","flurry",
			"allured","redrail","residual","failure","uredials"
		],
		"spawn_interval": 2.6, "max_enemies": 14, "enemy_speed_mult": 0.68,
		"duration": 115.0, "hp_mult": 0.9,
	},
	# Испытание 7 ── + T Y ────────────────────────────────────────────────────
	{
		"title": "EN 7", "subtitle": "Top row: T Y",
		"keys": "... R U  +  T · Y",
		"lang": "en",
		"new_letters": ["t", "y"],
		"allowed": ["a","s","d","f","j","k","l","e","i","r","u","t","y"],
		"description": "Энергетическая растяжка. Дотянись указательными пальцами до центра верхнего ряда: T ждет слева от R, Y — справа от U.",
		"words": [
			"try","yet","stay","tray","year","style","truly","layer","ready",
			"study","dirty","rusty","dusty","trend","stead","daily","trial",
			"tired","tears","stray","ultra","trust","yeast","tasty",
			"starry","yearly","steady","sturdy","reality","auditory"
		],
		"spawn_interval": 2.5, "max_enemies": 15, "enemy_speed_mult": 0.70,
		"duration": 120.0, "hp_mult": 0.92,
	},
	# Испытание 8 ── + W O ────────────────────────────────────────────────────
	{
		"title": "EN 8", "subtitle": "Top row: W O",
		"keys": "... T Y  +  W · O",
		"lang": "en",
		"new_letters": ["w", "o"],
		"allowed": ["a","s","d","f","j","k","l","e","i","r","u","t","y","w","o"],
		"description": "Тайные чертоги мудрости. Средние пальцы делают шаг вверх: W над S, O — над L.",
		"words": [
			"word","work","world","row","flow","glow","slow","tower","lower",
			"power","sword","storm","story","worry","worth","wrist","wrote",
			"toward","worker","forest","effort","roster","trowel",
			"software","workout","outward","desktop","storeward"
		],
		"spawn_interval": 2.4, "max_enemies": 16, "enemy_speed_mult": 0.72,
		"duration": 120.0, "hp_mult": 0.95,
	},
	# Испытание 9 ── + Q P ────────────────────────────────────────────────────
	{
		"title": "EN 9", "subtitle": "Top row: Q P",
		"keys": "... W O  +  Q · P",
		"lang": "en",
		"new_letters": ["q", "p"],
		"allowed": ["a","s","d","f","j","k","l","e","i","r","u","t","y","w","o","q","p"],
		"description": "Предел ментального напряжения. Раскрой силу мизинцев на верхней границе: призови коварную Q над A и дальнюю P справа. Преодолей эту растяжку!",
		"words": [
			"stop","sport","drip","trip","strip","quip","prowl","optic",
			"tulip","pilot","depot","squat","quart","equity","potion",
			"poetry","report","expert","output","laptop","support",
			"deposit","quality","quartet","property","purposely"
		],
		"spawn_interval": 2.3, "max_enemies": 17, "enemy_speed_mult": 0.75,
		"duration": 125.0, "hp_mult": 1.0,
	},
	# Испытание 10 ── + V M ───────────────────────────────────────────────────
	{
		"title": "EN 10", "subtitle": "Bottom row: V M",
		"keys": "... Q P  +  V · M",
		"lang": "en",
		"new_letters": ["v", "m"],
		"allowed": ["a","s","d","f","j","k","l","e","i","r","u","t","y","w","o","q","p","v","m"],
		"description": "Схождение в Подземные Копи. Опусти указательные пальцы к нижней границе свитков: левый находит V под F, правый — M под J.",
		"words": [
			"move","mover","value","vital","vivid","marvel","mortal","volume",
			"market","mature","vertex","movies","remote","victim","system",
			"master","timber","memory","summer","mirror","vampire","mixture",
			"improve","primary","symptom","viewpoint","memorize"
		],
		"spawn_interval": 2.2, "max_enemies": 18, "enemy_speed_mult": 0.78,
		"duration": 130.0, "hp_mult": 1.0,
	},
	# Испытание 11 ── + C N ───────────────────────────────────────────────────
	{
		"title": "EN 11", "subtitle": "Bottom row: C N",
		"keys": "... V M  +  C · N",
		"lang": "en",
		"new_letters": ["c", "n"],
		"allowed": ["a","s","d","f","j","k","l","e","i","r","u","t","y","w","o","q","p","v","m","c","n"],
		"description": "Нижние обереги. Средние пальцы скользят во тьму нижнего ряда: C пробуждается под D, а N крепится под J.",
		"words": [
			"can","scan","nice","mice","since","fence","clinic","cosmic","iconic",
			"mentor","nation","concert","concern","control","contact","content",
			"central","science","opinion","concept","contract","medicine",
			"currency","function","incident","conscious","convenient"
		],
		"spawn_interval": 2.1, "max_enemies": 19, "enemy_speed_mult": 0.80,
		"duration": 130.0, "hp_mult": 1.05,
	},
	# Испытание 12 ── + X B ───────────────────────────────────────────────────
	{
		"title": "EN 12", "subtitle": "Bottom row: X B",
		"keys": "... C N  +  X · B",
		"lang": "en",
		"new_letters": ["x", "b"],
		"allowed": ["a","s","d","f","j","k","l","e","i","r","u","t","y","w","o","q","p","v","m","c","n","x","b"],
		"description": "Сложное переплетение. Левый безымянный опускается на X под S, а правый указательный совершает маневр к древней руне B между V и N.",
		"words": [
			"box","fox","flex","text","next","exit","extra","boxer","toxic",
			"exact","excel","exert","combat","submit","object","subject",
			"combine","exhibit","explore","express","extreme","exciting",
			"exchange","excellent","existence","substrate","expedition"
		],
		"spawn_interval": 2.0, "max_enemies": 20, "enemy_speed_mult": 0.83,
		"duration": 135.0, "hp_mult": 1.1,
	},
	# Испытание 13 ── + Z G H ─────────────────────────────────────────────────
	{
		"title": "EN 13", "subtitle": "Bottom row: Z  +  G H",
		"keys": "... X B  +  Z · G · H",
		"lang": "en",
		"new_letters": ["z", "g", "h"],
		"allowed": ["a","s","d","f","j","k","l","e","i","r","u","t","y","w","o","q","p","v","m","c","n","x","b","z","g","h"],
		"description": "Потайные узлы магии. Открой редкую руну Z левым мизинцем. Разрушь барьеры центрального ряда, дотянувшись до скрытых знаков G и H.",
		"words": [
			"zone","zero","gaze","haze","graze","glaze","ghost","zoning",
			"hazard","zenith","bizarre","height","growth","gather","health",
			"breath","hunger","garden","handle","grizzly","weather",
			"together","although","strengthen","astonishing"
		],
		"spawn_interval": 1.9, "max_enemies": 21, "enemy_speed_mult": 0.86,
		"duration": 140.0, "hp_mult": 1.15,
	},
	# Испытание 14 ── ВЕЛИКИЙ ФИНАЛ АЛФАВИТА ──────────────────────────────────
	{
		"title": "EN 14", "subtitle": "ФИНАЛ: Все буквы",
		"keys": "Весь алфавит",
		"lang": "en",
		"new_letters": [], # Все буквы уже открыты ранее
		"allowed": ["a","b","c","d","e","f","g","h","i","j","k","l","m",
					"n","o","p","q","r","s","t","u","v","w","x","y","z"],
		"description": "Древняя Книга Заклинаний полностью открыта! Твои пальцы сотканы из чистой магии. Уничтожь орду Тьмы безупречным шквалом символов!",
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
# РУНЫ ДРЕВНИХ ХРАНИТЕЛЕЙ (ЙЦУКЕН, с центрального ряда)
# ─────────────────────────────────────────────────────────────────────────────
const LESSONS_RU := [
	# Испытание 1 ── А О ──────────────────────────────────────────────────────
	{
		"title": "RU 1", "subtitle": "Домашний ряд: А О",
		"keys": "А · О",
		"lang": "ru",
		"new_letters": ["а", "о"],
		"allowed": ["а","о"],
		"description": "Первые руны сотворения. Указательные пальцы ложатся на знаки А (слева) и О (справа). Это фундамент твоего боевого посоха!",
		"words": [
			"аа","оо","ао","оа","аоа","оао","аао","ооа",
			"аоо","оаа","ааоо","ооаа","аоао","оаоа",
			"ааао","оооа","аоаа","оаоо","ааоао","оооаа"
		],
		"spawn_interval": 3.8, "max_enemies": 7, "enemy_speed_mult": 0.50,
		"duration": 90.0, "hp_mult": 0.7,
	},
	# Испытание 2 ── + В Л ────────────────────────────────────────────────────
	{
		"title": "RU 2", "subtitle": "Домашний ряд: А В О Л",
		"keys": "В · А · О · Л",
		"lang": "ru",
		"new_letters": ["в", "л"],
		"allowed": ["а","о","в","л"],
		"description": "Плетение стихийных потоков. Твои средние пальцы призывают новые силы: В пробуждается слева, Л — встает на защиту справа.",
		"words": [
			"во","ов","ал","ла","вал","лов","вол","ала",
			"овал","lava","вола","авол","лаво","волна",
			"влаво","лавол","авола","воавл","лавол",
			"волал","аволл","лвова","авлол"
		],
		"spawn_interval": 3.5, "max_enemies": 9, "enemy_speed_mult": 0.55,
		"duration": 95.0, "hp_mult": 0.75,
	},
	# Испытание 3 ── + Ы Д ────────────────────────────────────────────────────
	{
		"title": "RU 3", "subtitle": "Домашний ряд: Ы В А О Л Д",
		"keys": "Ы · В · А · О · Л · Д",
		"lang": "ru",
		"new_letters": ["ы", "д"],
		"allowed": ["а","о","в","л","ы","д"],
		"description": "Древние ментальные оковы. Активируй безымянные пальцы: призови стойкую руну Ы слева и сокрушительную Д справа.",
		"words": [
			"ды","ыл","вды","лыд","одыл","выда","лоды",
			"давол","ловды","выдал","долов","ладов","лодыд",
			"водыл","давол","ловды","авдол","лыдва",
			"выдол","доавл","лывод","давыл"
		],
		"spawn_interval": 3.2, "max_enemies": 11, "enemy_speed_mult": 0.58,
		"duration": 100.0, "hp_mult": 0.8,
	},
	# Испытание 4 ── + Ф ──────────────────────────────────────────────────────
	{
		"title": "RU 4", "subtitle": "Полный домашний ряд: Ф Ы В А О Л Д",
		"keys": "Ф · Ы · В · А · О · Л · Д",
		"lang": "ru",
		"new_letters": ["ф"],
		"allowed": ["а","о","в","л","ы","д","ф"],
		"description": "Стена Иллюзий. Левый мизинец касается редкой руны Ф. Весь срединный круг магии замкнулся. Отражай набеги монстров!",
		"words": [
			"фол","фала","флаг","дыфо","влодф",
			"вода","лада","фада","довыл","флода",
			"довод","давал","водал","ловда","фавол",
			"вдоль","давол","флодыв","водолы","далофы"
		],
		"spawn_interval": 3.0, "max_enemies": 13, "enemy_speed_mult": 0.62,
		"duration": 105.0, "hp_mult": 0.85,
	},
	# Испытание 5 ── + Е Н ────────────────────────────────────────────────────
	{
		"title": "RU 5", "subtitle": "Верхний ряд: Е Н",
		"keys": "Ф Ы В А О Л Д  +  Е · Н",
		"lang": "ru",
		"new_letters": ["е", "н"],
		"allowed": ["а","о","в","л","ы","д","ф","е","н"],
		"description": "Врата Верхнего Измерения. Подними указательные пальцы к звездам: Е вспыхивает над А, Н материализуется над О.",
		"words": [
			"не","он","она","дно","вне","лень","нова",
			"вода","долен","ловен","наволок","длина",
			"новела","надол","ловена","долена","водяне",
			"навело","деловой","новелла","воевода","доноване"
		],
		"spawn_interval": 2.8, "max_enemies": 13, "enemy_speed_mult": 0.65,
		"duration": 110.0, "hp_mult": 0.88,
	},
	# Испытание 6 ── + К Г ────────────────────────────────────────────────────
	{
		"title": "RU 6", "subtitle": "Верхний ряд: К Г",
		"keys": "... Е Н  +  К · Г",
		"lang": "ru",
		"new_letters": ["к", "г"],
		"allowed": ["а","о","в","л","ы","д","ф","е","н","к","г"],
		"description": "Дальняя атака. Расширяй зону контроля указательных пальцев в верхнем ряду: подчини руны К и Г для усиления мощи.",
		"words": [
			"col","год","кого","гол","нога","легок",
			"конек","дорога","голода","волков","кладов",
			"навыков","дольник","голодный","надолго",
			"колодка","гвоздок","воеводка","надолбок"
		],
		"spawn_interval": 2.6, "max_enemies": 14, "enemy_speed_mult": 0.68,
		"duration": 115.0, "hp_mult": 0.9,
	},
	# Испытание 7 ── + У Ш ────────────────────────────────────────────────────
	{
		"title": "RU 7", "subtitle": "Верхний ряд: У Ш",
		"keys": "... К Г  +  У · Ш",
		"lang": "ru",
		"new_letters": ["у", "ш"],
		"allowed": ["а","о","в","л","ы","д","ф","е","н","к","г","у","ш"],
		"description": "Магия Высшего Эфира. Перемести средние пальцы в верхний сектор: У готова извергнуть пламя, а Ш — сотворить ледяной щит.",
		"words": [
			"шум","душа","куль","шнур","нужно","кушать",
			"нашего","дышать","кулаком","гулянка","надолго",
			"душевный","дальнего","клушавых","душегубке",
			"надлежащего","нудноватый","холодновато"
		],
		"spawn_interval": 2.5, "max_enemies": 15, "enemy_speed_mult": 0.70,
		"duration": 120.0, "hp_mult": 0.92,
	},
	# Испытание 8 ── + Ц Х ────────────────────────────────────────────────────
	{
		"title": "RU 8", "subtitle": "Верхний ряд: Ц Й Х",
		"keys": "... У Ш  +  Ц · Й · Х",
		"lang": "ru",
		"new_letters": ["ц", "й", "х"],
		"allowed": ["а","о","в","л","ы","д","ф","е","н","к","г","у","ш","ц","й","х"],
		"description": "Сложные формулы краев. Окутай врагов проклятием Ц (безымянный), призови первородный хаос руной Й и сожги их знаком Х с помощью мизинцев.",
		"words": [
			"цех","цель","цыган","цунами","йод","хол",
			"хлеб","цикл","цокот","доход","сухой","лихой",
			"цифра","хохочет","цыплячий",
			"нахождение","колосьях","доходность"
		],
		"spawn_interval": 2.4, "max_enemies": 16, "enemy_speed_mult": 0.72,
		"duration": 120.0, "hp_mult": 0.95,
	},
	# Испытание 9 ── + И Т ────────────────────────────────────────────────────
	{
		"title": "RU 9", "subtitle": "Нижний ряд: И Т",
		"keys": "... + И · Т",
		"lang": "ru",
		"new_letters": ["и", "т"],
		"allowed": ["а","о","в","л","ы","д","ф","е","н","к","г","у","ш","ц","й","х","и","т"],
		"description": "Погружение в Тайные Катакомбы. Опусти указательные пальцы в нижний астрал: высвободи чистую энергию И и несокрушимый молот руны Т.",
		"words": [
			"кит","тихо","нити","одни","итог","часть",
			"тишина","водить","нитки","хитрость","выгодить",
			"кинутый","достичь","атланты","хитиновый",
			"активности","логическое","интуитивное"
		],
		"spawn_interval": 2.3, "max_enemies": 17, "enemy_speed_mult": 0.75,
		"duration": 125.0, "hp_mult": 1.0,
	},
	# Испытание 10 ── + М Ь ───────────────────────────────────────────────────
	{
		"title": "RU 10", "subtitle": "Нижний ряд: М Ь",
		"keys": "... И Т  +  М · Ь",
		"lang": "ru",
		"new_letters": ["м", "ь"],
		"allowed": ["а","о","в","л","ы","д","ф","е","н","к","г","у","ш","ц","й","х","и","т","м","ь"],
		"description": "Руны Смирения и Силы. Опусти средние пальцы вниз: М призовет древнюю магию земли, а Мягкий Знак (Ь) запечатает раны твоего чародея.",
		"words": [
			"мать","миль","мить","темь","мышь","мотив",
			"только","вымыть","мягкий","тихонько","думаешь",
			"молодой","дымоход","кинотеатр","достоинство",
			"вымотанный","выходные","молниеносно"
		],
		"spawn_interval": 2.2, "max_enemies": 18, "enemy_speed_mult": 0.78,
		"duration": 130.0, "hp_mult": 1.0,
	},
	# Испытание 11 ── + С Б ───────────────────────────────────────────────────
	{
		"title": "RU 11", "subtitle": "Нижний ряд: С Б",
		"keys": "... М Ь  +  С · Б",
		"lang": "ru",
		"new_letters": ["с", "б"],
		"allowed": ["а","о","в","л","ы","д","ф","е","н","к","г","у","ш","ц","й","х","и","т","м","ь","с","б"],
		"description": "Темные бездны нижнего ряда. Безымянные пальцы скользят вниз, нащупывая руну С слева для сотворения смерча и Б справа для призыва бури.",
		"words": [
			"бас","смог","слой","биос","косить","смотри",
			"быстро","сигнал","небось","добиться","сомнение",
			"состояние","обоснование","осмысленное","беспокойство",
			"самостоятельно","достопримечательность"
		],
		"spawn_interval": 2.1, "max_enemies": 19, "enemy_speed_mult": 0.80,
		"duration": 130.0, "hp_mult": 1.05,
	},
	# Испытание 12 ── + Я Ч ───────────────────────────────────────────────────
	{
		"title": "RU 12", "subtitle": "Нижний ряд: Я Ч",
		"keys": "... С Б  +  Я · Ч",
		"lang": "ru",
		"new_letters": ["я", "ч"],
		"allowed": ["а","о","в","л","ы","д","ф","е","н","к","г","у","ш","ц","й","х","и","т","м","ь","с","б","я","ч"],
		"description": "Вспышки Сверхновой. Левый мизинец резко уходит вниз к руне Я. Указательный находит Ч. Твои чары становятся невероятно хаотичными!",
		"words": [
			"ма","чаша","ячмень","чистый","являться",
			"ячейка","чугунный","начать","обычный","сочный",
			"значительный","человечность","неначатый",
			"случайность","нечаянность","бесконечность"
		],
		"spawn_interval": 2.0, "max_enemies": 20, "enemy_speed_mult": 0.83,
		"duration": 135.0, "hp_mult": 1.1,
	},
	# Испытание 13 ── + З Щ Ж Э Ю ─────────────────────────────────────────────
	{
		"title": "RU 13", "subtitle": "Края: З Щ Ж Э Ю",
		"keys": "... Я Ч  +  З · Щ · Ж · Э · Ю",
		"lang": "ru",
		"new_letters": ["з", "щ", "ж", "э", "ю"],
		"allowed": ["а","о","в","л","ы","д","ф","е","н","к","г","у","ш","ц","й","х","и","т","м","ь","с","б","я","ч","з","щ","ж","э","ю"],
		"description": "Пограничная Магия. Подчини самые непокорные руны на краях свитков: З, Щ, Ж, Э и Ю. Полная концентрация на границах миров!",
		"words": [
			"зима","щука","жест","этот","южный","зонт",
			"щетка","жадный","эффект","южное","зубной",
			"жесткость","эклектика","ежегодный","южнобережный",
			"захватывающий","эффективность","южнославянский"
		],
		"spawn_interval": 1.9, "max_enemies": 21, "enemy_speed_mult": 0.86,
		"duration": 140.0, "hp_mult": 1.15,
	},
	# Испытание 14 ── + П Р ───────────────────────────────────────────────────
	{
		"title": "RU 14", "subtitle": "Верхний ряд: П Р",
		"keys": "... З Щ  +  П · Р",
		"lang": "ru",
		"new_letters": ["п", "р"],
		"allowed": ["а","о","в","л","ы","д","ф","е","н","к","г","у","ш","ц","й","х","и","т","м","ь","с","б","я","ч","з","щ","ж","э","ю","п","р"],
		"description": "Последние искры творения. Освой священные знаки П и Р в верхнем эшелоне, чтобы завершить плетение боевых заклинаний.",
		"words": [
			"пар","рот","прут","порт","репа","простой",
			"природа","реформа","простор","преграда",
			"программа","предметный","реставрация",
			"представительство","практически"
		],
		"spawn_interval": 1.8, "max_enemies": 22, "enemy_speed_mult": 0.88,
		"duration": 145.0, "hp_mult": 1.2,
	},
	# Испытание 15 ── ВЕЛИКИЙ ФИНАЛ ЙЦУКЕН ────────────────────────────────────
	{
		"title": "RU 15", "subtitle": "ВЕЛИКИЙ ФИНАЛ ЙЦУКЕН",
		"keys": "Вся раскладка ЙЦУКЕН",
		"lang": "ru",
		"new_letters": ["ё", "ъ"], # Добираем оставшиеся редкие буквы алфавита
		"allowed": ["а","б","в","г","д","е","ё","ж","з","и","й","к","л","м",
					"н","о","п","р","с","т","у","ф","х","ц","ч","ш","щ","ъ",
					"ы","ь","э","ю","я"],
		"description": "Ты познал все тайны Рун Древних Хранителей! Архимаг, обрушь всю ярость Книги Заклинаний на полчища Тьмы и защити королевство Keyboard Wizard!",
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
# МАГИЧЕСКИЕ МЕТОДЫ И РИТУАЛЫ (API)
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


# Дополнительный магический метод для интерфейса (получить только новые буквы)
func get_new_letters(lang: String, lesson_index: int) -> Array:
	return get_lesson(lang, lesson_index)["new_letters"]


func advance_lesson(lang: String) -> void:
	var idx := get_current_index(lang)
	var max_i := get_lesson_count(lang) - 1
	if idx < max_i:
		set_lesson(lang, idx + 1)
		save_progress()


# ─────────────────────────────────────────────────────────────────────────────
# СОХРАНЕНИЕ МАГИЧЕСКИХ ХРОНИК
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
