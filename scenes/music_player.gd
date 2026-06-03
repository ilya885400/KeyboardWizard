extends AudioStreamPlayer

var fade_tween: Tween

func play_music():
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
		
	play()
	fade_tween = create_tween()
	
	fade_tween.set_trans(Tween.TRANS_EXPO)
	fade_tween.set_ease(Tween.EASE_OUT)
	# Плавно поднимаем громкость от текущей (или от -80) до 0 дБ за 1.5 секунды
	fade_tween.tween_property(self, "volume_db", 0.0, 32).from(-80.0)

func fade_out():
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
		
	fade_tween = create_tween()
	fade_tween.set_trans(Tween.TRANS_EXPO)
	fade_tween.set_ease(Tween.EASE_OUT)
	
	fade_tween.tween_property(self, "volume_db", -80, 8.0)
	
	await fade_tween.finished
	stop()
