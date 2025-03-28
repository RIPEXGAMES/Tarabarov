class_name Character
extends Node2D

# Сигнал, сообщающий о завершении движения
signal move_finished
signal end_turn_requested

# Скорость передвижения персонажа (клеток в секунду)
@export var move_speed: float = 4.0
# Очки действий (сколько клеток может пройти за ход)
@export var action_points: int = 5
# Можно ли двигаться по диагонали (опционально)
@export var allow_diagonal: bool = true

# Текущая позиция на сетке
var current_cell: Vector2i = Vector2i.ZERO
# Целевая позиция
var target_cell: Vector2i = Vector2i.ZERO
# Путь, по которому движется персонаж
var path: Array[Vector2i] = []
# Находится ли персонаж в движении
var is_moving: bool = false
# Оставшиеся очки действия в текущем ходу
var remaining_ap: int = action_points
# Индикатор текущего маршрута (опционально)
var path_preview: Array[Vector2i] = []
# Выбранная клетка
var selected_cell: Vector2i = Vector2i(-1, -1)
# Флаг, указывающий на то, выбрана ли клетка
var is_cell_selected: bool = false

# Связь с генератором карты для получения информации о проходимости
@onready var map_generator: MapGenerator = get_node("../MapGenerator")
# Ссылка на спрайт персонажа
@onready var sprite: Sprite2D = $Sprite2D
# Опционально: ссылки на слои тайлмапа
@onready var landscape_layer: TileMapLayer = get_node("../Landscape")
@onready var obstacles_layer: TileMapLayer = get_node("../Obstacles")
# Ссылка на контроллер игры
@onready var game_controller: Node = $"../GameContoller"

func _ready():
	print("Character._ready() started")
	
	# Проверяем наличие необходимых узлов
	if not map_generator:
		push_error("MapGenerator not found!")
	else:
		print("MapGenerator found")
	
	if not landscape_layer:
		push_error("Landscape layer not found!")
	else:
		print("Landscape layer found")
	
	# Проверка наличия GameController
	if not game_controller:
		push_error("GameController not found!")
	else:
		print("GameController found, can_player_act() returns: ", game_controller.can_player_act())
	
	# Начальное положение персонажа
	place_at_valid_starting_position()
	
	# Подключаем обработку ввода
	set_process_input(true)
	
	# Инициализация очков действия
	remaining_ap = action_points
	
	print("Character._ready() completed, AP: ", remaining_ap)

func _input(event):
	# Обрабатываем только если сейчас ход игрока
	if not game_controller or not game_controller.can_player_act():
		return
	
	# Обработка левого клика
	if event.is_action_pressed("left_click") and not is_moving:
		print("Left click detected")
		var mouse_pos = get_global_mouse_position()
		var clicked_cell = landscape_layer.local_to_map(landscape_layer.to_local(mouse_pos))
		
		print("Clicked cell: ", clicked_cell)
		
		# Проверяем, можно ли пройти в эту клетку
		if map_generator.is_tile_walkable(clicked_cell.x, clicked_cell.y):
			print("Cell is walkable")
			
			# Находим путь к этой клетке
			var potential_path = find_path(current_cell, clicked_cell)
			print("Path found, length: ", potential_path.size())
			
			# Проверяем, хватает ли AP для движения
			if potential_path.size() <= remaining_ap:
				# Если клетка уже выбрана и это та же самая клетка - начинаем движение
				if is_cell_selected and clicked_cell == selected_cell:
					path = potential_path
					if path.size() > 0:
						is_moving = true
						print("Starting movement, path: ", path)
						is_cell_selected = false
				# Если клетка еще не выбрана - выбираем её
				elif not is_cell_selected:
					selected_cell = clicked_cell
					is_cell_selected = true
					print("Cell selected: ", selected_cell)
				# Если выбрана другая клетка - меняем выбор
				elif is_cell_selected and clicked_cell != selected_cell:
					selected_cell = clicked_cell
					print("New cell selected: ", selected_cell)
				# Иначе (хотя этот случай не должен происходить) - сбрасываем выбор
				else:
					selected_cell = Vector2i(-1, -1)
					is_cell_selected = false
					print("Cell selection reset")
			else:
				print("Недостаточно очков действия. Требуется: ", potential_path.size(), ", Доступно: ", remaining_ap)
		else:
			print("Cell is not walkable")
	
	# Обработка правого клика - сброс выбранной клетки
	if event.is_action_pressed("right_click") and not is_moving:
		print("Character: Right click detected")
		if is_cell_selected:
			print("Character: Clearing selected cell: ", selected_cell)
			selected_cell = Vector2i(-1, -1)
			is_cell_selected = false
			path_preview.clear()
			# Помечаем событие как обработанное, чтобы камера не реагировала
			get_viewport().set_input_as_handled()
	
	# Обновляем предварительный просмотр пути при движении мыши
	if event is InputEventMouseMotion:
		var mouse_pos = get_global_mouse_position()
		var hovered_cell = landscape_layer.local_to_map(landscape_layer.to_local(mouse_pos))
		
		if map_generator.is_tile_walkable(hovered_cell.x, hovered_cell.y):
			path_preview = find_path(current_cell, hovered_cell)
		else:
			path_preview.clear()
	
	# Кнопка для завершения хода (например, пробел)
	if event.is_action_pressed("ui_select") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		print("End turn triggered")
		end_turn()

func _process(delta):
	# Обработка движения персонажа
	if is_moving and path.size() > 0:
		move_along_path(delta)

# Поиск начальной свободной позиции
func place_at_valid_starting_position():
	print("Finding valid starting position...")
	# Ищем первую проходимую клетку
	for x in range(map_generator.map_width):
		for y in range(map_generator.map_height):
			if map_generator.is_tile_walkable(x, y):
				current_cell = Vector2i(x, y)
				# Преобразуем координаты клетки в мировые координаты
				global_position = landscape_layer.map_to_local(current_cell)
				print("Starting position found at cell: ", current_cell, " world pos: ", global_position)
				return
	
	# Если не нашли проходимую клетку, выводим ошибку
	push_error("Не найдено ни одной проходимой клетки для размещения персонажа")

# Поиск пути от начальной клетки до конечной с использованием A*
func find_path(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	var result_path: Array[Vector2i] = []
	
	# Если начальная и конечная клетка совпадают, ничего не делаем
	if start_cell == end_cell:
		return result_path
	
	# Создаем A* алгоритм
	var astar = AStar2D.new()
	
	# Словарь для хранения ID узлов
	var cell_to_id = {}
	var id_counter = 0
	
	# Добавляем все проходимые клетки в A*
	for x in range(map_generator.map_width):
		for y in range(map_generator.map_height):
			if map_generator.is_tile_walkable(x, y):
				var cell = Vector2i(x, y)
				var id = id_counter
				cell_to_id[cell] = id
				astar.add_point(id, Vector2(cell.x, cell.y))
				id_counter += 1
	
	# Соединяем соседние проходимые клетки
	for cell_vec in cell_to_id:
		var cell = Vector2i(cell_vec.x, cell_vec.y)
		var cell_id = cell_to_id[cell]
		
		# Получаем соседей используя функцию из MapGenerator
		var neighbors = map_generator.get_walkable_neighbors(cell.x, cell.y)
		
		# Если разрешены диагональные перемещения, добавляем их
		if allow_diagonal:
			# Добавляем диагональных соседей
			var diag_directions = [
				Vector2i(1, 1),   # Вправо-вниз
				Vector2i(-1, 1),  # Влево-вниз
				Vector2i(1, -1),  # Вправо-вверх
				Vector2i(-1, -1)  # Влево-вверх
			]
			
			for dir in diag_directions:
				var nx = cell.x + dir.x
				var ny = cell.y + dir.y
				
				# ИЗМЕНЕНО: Разрешаем диагональное движение, если диагональная клетка проходима,
				# независимо от того, проходимы ли соседние клетки
				if map_generator.is_tile_walkable(nx, ny):
					# Проверяем только, чтобы не было "прохождения сквозь стену"
					# Для этого достаточно, чтобы хотя бы одна из соседних клеток была проходима
					if map_generator.is_tile_walkable(cell.x, ny) or map_generator.is_tile_walkable(nx, cell.y):
						neighbors.append(Vector2i(nx, ny))
		
		# Соединяем со всеми проходимыми соседями
		for neighbor in neighbors:
			if neighbor in cell_to_id:
				var neighbor_id = cell_to_id[neighbor]
				
				# Диагональное движение должно иметь больший вес (опционально)
				var distance = 1.0
				if allow_diagonal and abs(cell.x - neighbor.x) + abs(cell.y - neighbor.y) > 1:
					distance = 1.4  # Примерный вес для диагонального движения (sqrt(2))
				
				if not astar.are_points_connected(cell_id, neighbor_id):
					astar.connect_points(cell_id, neighbor_id, distance)
	
	# Проверяем, существуют ли точки начала и конца в нашем графе
	if not (start_cell in cell_to_id) or not (end_cell in cell_to_id):
		print("Невозможно найти путь: начальная или конечная точка непроходима")
		return result_path
	
	# Находим путь
	var start_id = cell_to_id[start_cell]
	var end_id = cell_to_id[end_cell]
	var id_path = astar.get_id_path(start_id, end_id)
	
	# Конвертируем ID обратно в координаты клеток
	for id in id_path:
		var point = astar.get_point_position(id)
		result_path.append(Vector2i(point.x, point.y))
	
	# Удаляем первую точку (текущее положение)
	if result_path.size() > 0:
		result_path.remove_at(0)
	
	return result_path

# Движение по найденному пути
func move_along_path(delta):
	if path.is_empty():
		is_moving = false
		print("Path completed")
		
		# Проверяем, закончился ли ход
		if remaining_ap <= 0:
			print("No AP left, ending turn")
			end_turn()
			
		return
	
	# Получаем следующую точку пути
	var next_cell = path[0]
	var next_position = landscape_layer.map_to_local(next_cell)
	
	# Отладка
	print("Moving to next cell: ", next_cell, ", position: ", next_position)
	
	# Вычисляем направление движения
	var direction = global_position.direction_to(next_position)
	
	# Анимируем поворот спрайта (опционально)
	update_sprite_direction(direction)
	
	# Вычисляем дистанцию, которую нужно пройти за этот кадр
	var distance_to_move = move_speed * delta * landscape_layer.tile_set.tile_size.x
	
	# Вычисляем расстояние до следующей точки
	var distance_to_next = global_position.distance_to(next_position)
	
	# Отладка
	print("Distance to next: ", distance_to_next, ", will move: ", distance_to_move)
	
	# Если мы достаточно близко к следующей точке, переходим к ней напрямую
	if distance_to_next <= distance_to_move:
		global_position = next_position
		current_cell = next_cell
		path.remove_at(0)
		
		# Уменьшаем очки действия
		remaining_ap -= 1
		print("Reached cell, AP left: ", remaining_ap)
		# Обновляем выделение доступных тайлов
		var highlight_layer = get_node_or_null("../HighlightLayer")
		if highlight_layer:
			highlight_layer.update_reachable_tiles()
	else:
		# Иначе продолжаем двигаться в направлении следующей точки
		global_position += direction * distance_to_move
		print("Moving towards cell, new position: ", global_position)

# Обновление направления спрайта
func update_sprite_direction(direction: Vector2):
	# Пример логики изменения направления спрайта
	if abs(direction.x) > abs(direction.y):
		# Горизонтальное движение
		if direction.x > 0:
			# Поворот вправо
			sprite.flip_h = false
		else:
			# Поворот влево
			sprite.flip_h = true

# Завершение хода персонажа
func end_turn():
	# Останавливаем все текущие действия
	is_moving = false
	path.clear()
	
	# Сбрасываем выбранную клетку при завершении хода
	selected_cell = Vector2i(-1, -1)
	is_cell_selected = false
	
	# Сбрасываем очки действия
	remaining_ap = action_points
	
	 # Обновляем выделение доступных тайлов
	var highlight_layer = get_node_or_null("../HighlightLayer")
	if highlight_layer:
		highlight_layer.update_reachable_tiles()
	
	
	# Уведомляем контроллер игры о завершении хода
	emit_signal("move_finished")

# Получение текущего пути (для визуализации)
func get_current_path() -> Array:
	return path

# Получение предварительного пути (для визуализации при наведении)
func get_preview_path() -> Array:
	return path_preview

# Получение выбранной клетки (для визуализации)
func get_selected_cell() -> Vector2i:
	return selected_cell

# Проверка, выбрана ли клетка
func has_cell_selected() -> bool:
	return is_cell_selected

# Метод для завершения хода, вызываемый из внешних источников (например, кнопка UI)
func request_end_turn():
	print("End turn requested")
	# Уведомляем, что игрок хочет завершить ход
	emit_signal("end_turn_requested")
	# Завершаем ход
	end_turn()
