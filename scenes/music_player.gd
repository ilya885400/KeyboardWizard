extends AudioStreamPlayer

func fade_out():
	# Вариант 2: Плавное затухание (более профессионально)
	var tween = create_tween()
	tween.tween_property(self, "volume_db", -80, 16.0) # За 2 секунды до -80 дБ
	await tween.finished
	stop()
