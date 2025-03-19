extends CharacterBody2D

class_name PlayerCharacter

# Настройки персонажа
@export var max_move_distance: float = 200.0  # Максимальная дистанция перемещения за ход
@export var move_speed: float = 100.0  # Скорость анимации перемещения

# Переменные для отслеживания состояния
var remaining_distance: float  # Оставшаяся дистанция перемещения
var is_moving: bool = false
var move_path: PackedVector2Array = PackedVector2Array()  # Путь перемещения
var current_target: Vector2  # Текущая целевая точка
var move_line: Line2D  # Для визуализации маршрута

# Навигационные компоненты
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

# Сигналы
signal movement_completed
signal turn_ended

func _ready():
	# Инициализация в начале хода
	remaining_distance = max_move_distance
	
	# Настройка навигационного агента
	navigation_agent.path_desired_distance = 5.0
	navigation_agent.target_desired_distance = 5.0
	
	# Подключаем сигнал навигационного агента
	navigation_agent.path_changed.connect(_on_path_changed)
	navigation_agent.navigation_finished.connect(_on_navigation_finished)
	
	# Создаем визуализацию маршрута
	move_line = Line2D.new()
	move_line.width = 2.0
	move_line.default_color = Color(0, 0.7, 1, 0.5)
	add_child(move_line)

func _process(delta):
	# Обработка перемещения персонажа
	if is_moving:
		move_along_path(delta)
	
	# Обновление визуализации доступного радиуса перемещения
	queue_redraw()

func _unhandled_input(event):
	# Обрабатываем только если наш ход и мы не двигаемся
	if not is_moving and remaining_distance > 0:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Получаем координаты клика
			var click_position = get_global_mouse_position()
			
			# Проверяем, что клик в пределах доступного радиуса
			var max_path_distance = calculate_path_distance(click_position)
			
			if max_path_distance <= remaining_distance:
				# Начинаем движение
				start_movement(click_position)
			else:
				print("Слишком далеко! Расстояние по пути: " + str(max_path_distance))

func calculate_path_distance(target_position: Vector2) -> float:
	# Рассчитываем маршрут к целевой позиции
	navigation_agent.target_position = target_position
	
	# Получаем точки пути
	var path_points = navigation_agent.get_current_navigation_path()
	
	# Считаем общую длину пути
	var total_distance = 0.0
	for i in range(1, path_points.size()):
		total_distance += path_points[i-1].distance_to(path_points[i])
	
	return total_distance

func start_movement(target_position: Vector2):
	# Устанавливаем целевую позицию для навигационного агента
	navigation_agent.target_position = target_position
	
	# Начинаем движение
	is_moving = true
	current_target = navigation_agent.get_next_path_position()
	
	# Вычисляем дистанцию и обновляем remaining_distance
	var move_distance = calculate_path_distance(target_position)
	remaining_distance -= move_distance
	
	# Обновляем визуализацию пути
	update_path_visualization()

func _on_path_changed():
	# Обновляем путь и визуализацию при изменении пути
	update_path_visualization()

func _on_navigation_finished():
	# Обработка завершения навигации
	is_moving = false
	emit_signal("movement_completed")

func move_along_path(delta):
	if navigation_agent.is_navigation_finished():
		is_moving = false
		emit_signal("movement_completed")
		return
	
	# Получаем следующую позицию в пути
	var next_position = navigation_agent.get_next_path_position()
	
	# Вычисляем направление движения
	var direction = global_position.direction_to(next_position)
	
	# Устанавливаем скорость и перемещаемся
	velocity = direction * move_speed
	move_and_slide()
	
	# Обновляем визуализацию пути по мере движения
	update_path_visualization()

func update_path_visualization():
	# Обновляем визуализацию пути
	var path = navigation_agent.get_current_navigation_path()
	move_line.clear_points()
	
	for point in path:
		move_line.add_point(to_local(point))

func _draw():
	# Рисуем круг, показывающий доступный радиус перемещения
	if remaining_distance > 0:
		draw_circle(Vector2.ZERO, remaining_distance, Color(0, 0.5, 1, 0.2))

func end_turn():
	# Завершаем ход
	emit_signal("turn_ended")

func start_new_turn():
	# Сбрасываем доступное расстояние перемещения
	remaining_distance = max_move_distance
