extends Node

func _minutesToHHMM(minutes: int):
	# Рассчитываем часы и оставшиеся минуты
	var hours: int = minutes / 60
	var mins: int = minutes % 60
	
	# Форматируем с автоматическим добавлением ведущих нулей
	return "%02d:%02d" % [hours, mins]

func _playSound(sound, min_tone: float, max_tone: float, volume: int):
	var sound_player = AudioStreamPlayer.new()
	add_child(sound_player)
	
	# Выбираем случайный звук
	sound_player.stream = sound
	
	# Случайная небольшая вариация высоты звука
	sound_player.pitch_scale = randf_range(min_tone, max_tone)
	sound_player.volume_db = volume
	sound_player.play()
	
	# Автоматическое удаление проигрывателя после завершения
	sound_player.connect("finished", func(): sound_player.queue_free())
