# Tooltip.gd
extends Control
## Всплывающая подсказка с адаптивным размером
## Использует NinePatchRect для красивого оформления

# Ссылки на дочерние ноды
@onready var nine_patch: NinePatchRect = $NinePatchRect
@onready var label: Label = $NinePatchRect/MarginContainer/Label

# Аниматор для плавного появления
var tween: Tween

func _ready() -> void:
	# Инициализация состояния
	visible = false      # Скрываем при старте
	modulate.a = 0       # Полная прозрачность
	z_index = 100        # Поверх всех элементов
	
	# Проверка ссылок (для отладки)
	assert(nine_patch != null, "NinePatchRect not found!")
	assert(label != null, "Label not found!")

func show_tooltip(text: String, global_pos: Vector2) -> void:
	""" Показать подсказку с текстом в указанной позиции """
	# Установка текста
	label.text = text
	
	# Обновление размера панели
	update_size()
	
	# Расчет позиции с учетом границ экрана
	position = calculate_screen_position(global_pos)
	
	# Остановка предыдущей анимации
	if tween:
		tween.kill()
	
	# Анимация появления
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 1.0, 0.15) # Плавное появление
	
	# Делаем видимым в начале анимации
	visible = true

func hide_tooltip() -> void:
	""" Скрыть подсказку с анимацией """
	if tween:
		tween.kill()
	
	tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "modulate:a", 0.0, 0.1) # Исчезновение
	tween.tween_callback(_finalize_hide) # Финализация после анимации

func _finalize_hide() -> void:
	""" Окончательное скрытие после анимации """
	visible = false
	label.text = "" # Очищаем текст

func update_size() -> void:
	""" Обновление размера панели по содержимому """
	# Ждем обновления текста в следующем кадре
	await get_tree().process_frame
	
	# Рассчитываем минимальный размер
	var text_size = label.size
	nine_patch.custom_minimum_size = Vector2(
		text_size.x + 20, # Ширина текста + отступы
		text_size.y + 16  # Высота текста + отступы
	)

func calculate_screen_position(global_pos: Vector2) -> Vector2:
	""" Рассчитать позицию с учетом границ экрана """
	var viewport_size := get_viewport_rect().size
	var result_pos := global_pos + Vector2(20, 20) # Смещение от курсора
	
	# Корректировка правой границы
	if result_pos.x + nine_patch.size.x > viewport_size.x:
		result_pos.x = viewport_size.x - nine_patch.size.x - 20
	
	# Корректировка нижней границы
	if result_pos.y + nine_patch.size.y > viewport_size.y:
		result_pos.y = viewport_size.y - nine_patch.size.y - 20
	
	return result_pos
