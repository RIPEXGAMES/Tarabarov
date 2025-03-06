extends Node

func _minutesToHHMM(minutes: int):
	# Рассчитываем часы и оставшиеся минуты
	var hours: int = minutes / 60
	var mins: int = minutes % 60
	
	# Форматируем с автоматическим добавлением ведущих нулей
	return "%02d:%02d" % [hours, mins]
