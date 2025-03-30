class_name MoveManager
extends Node

# Сигналы для оповещения подписчиков
signal available_cells_updated
signal path_updated

# Массив доступных клеток для перемещения
var available_cells: Array[Vector2i] = []

# Текущий путь, который будет отображаться
var current_path: Array[Vector2i] = []

# Текущая клетка персонажа
var character_cell: Vector2i = Vector2i.ZERO

# Клетка, выбранная для перемещения
var selected_cell: Vector2i = Vector2i(-1, -1)

# Ссылки на другие узлы
var map_generator: MapGenerator

# Очки действия персонажа и максимальное количество AP
var current_ap: int = 0
var max_ap: int = 5

# Инициализация
func initialize(mapGen: MapGenerator, startCell: Vector2i, actionPoints: int, maxActionPoints: int):
	map_generator = mapGen
	character_cell = startCell
	current_ap = actionPoints
	max_ap = maxActionPoints
	
	# Сразу обновляем доступные клетки
	update_available_cells()

# Обновление доступных клеток на основе текущей позиции и оставшихся AP
func update_available_cells():
	available_cells.clear()
	
	# Если нет AP, то и перемещаться некуда
	if current_ap <= 0:
		emit_signal("available_cells_updated")
		return
	
	# Алгоритм Dijkstra для поиска доступных клеток
	var queue = []
	var costs = {}
	var visited = {}
	
	# Начинаем с текущей клетки
	queue.append({"pos": character_cell, "cost": 0})
	costs[character_cell] = 0
	
	while queue.size() > 0:
		# Сортируем по стоимости
		queue.sort_custom(func(a, b): return a.cost < b.cost)
		
		# Берем клетку с наименьшей стоимостью
		var current = queue.pop_front()
		var current_pos = current.pos
		var current_cost = current.cost
		
		# Пропускаем уже посещенные
		if visited.has(current_pos):
			continue
			
		# Отмечаем как посещенную
		visited[current_pos] = true
		
		# Добавляем в доступные клетки
		if current_pos != character_cell:
			available_cells.append(current_pos)
		
		# Если достигли максимального AP, останавливаемся
		if current_cost >= current_ap:
			continue
		
		# Обрабатываем соседей в 4 направлениях (можно расширить до 8 для диагоналей)
		var directions = [
			Vector2i(0, -1),  # Вверх
			Vector2i(1, 0),   # Вправо
			Vector2i(0, 1),   # Вниз
			Vector2i(-1, 0)   # Влево
		]
		
		# Добавляем диагональные направления, если разрешено
		directions.append_array([
			Vector2i(1, -1),   # Вправо-вверх
			Vector2i(1, 1),    # Вправо-вниз
			Vector2i(-1, 1),   # Влево-вниз
			Vector2i(-1, -1)   # Влево-вверх
		])
		
		for dir in directions:
			var next_pos = current_pos + dir
			
			# Проверяем, проходима ли клетка
			if !map_generator.is_tile_walkable(next_pos.x, next_pos.y):
				continue
				
			# Стоимость движения (для диагоналей можно сделать выше)
			var move_cost = 1
			
			# Для диагонального движения проверяем, можно ли пройти
			if dir.x != 0 and dir.y != 0:
				var x_neighbor = Vector2i(current_pos.x + dir.x, current_pos.y)
				var y_neighbor = Vector2i(current_pos.x, current_pos.y + dir.y)
				
				if !(map_generator.is_tile_walkable(x_neighbor.x, x_neighbor.y) or 
					 map_generator.is_tile_walkable(y_neighbor.x, y_neighbor.y)):
					continue
			
			# Вычисляем новую стоимость
			var new_cost = current_cost + move_cost
			
			# Проверяем, нашли ли мы лучший путь
			if costs.has(next_pos) and costs[next_pos] <= new_cost:
				continue
				
			# Если стоимость в пределах AP
			if new_cost <= current_ap:
				costs[next_pos] = new_cost
				queue.append({"pos": next_pos, "cost": new_cost})
	
	# Оповещаем о том, что доступные клетки обновились
	emit_signal("available_cells_updated")

# Проверка, доступна ли клетка для перемещения
func is_cell_available(cell: Vector2i) -> bool:
	return available_cells.has(cell)

# Обновление пути между текущей клеткой и выбранной целевой
func update_path_to_cell(target_cell: Vector2i):
	if !is_cell_available(target_cell):
		current_path.clear()
		emit_signal("path_updated")
		return
	
	# Строим путь от клетки персонажа до целевой клетки
	current_path = find_path(character_cell, target_cell)
	emit_signal("path_updated")

# Выбор клетки для перемещения
func select_cell(cell: Vector2i) -> bool:
	if !is_cell_available(cell):
		return false
	
	selected_cell = cell
	update_path_to_cell(cell)
	return true

# Очистка выбора клетки
func clear_selection():
	selected_cell = Vector2i(-1, -1)
	current_path.clear()
	emit_signal("path_updated")

# Перемещение персонажа в выбранную клетку
func move_to_selected_cell() -> Array[Vector2i]:
	if selected_cell == Vector2i(-1, -1) or current_path.size() == 0:
		return []
	
	var path_copy = current_path.duplicate()
	
	# Уменьшаем AP на длину пути
	current_ap -= current_path.size()
	
	# Обновляем текущую клетку персонажа
	character_cell = selected_cell
	
	# Очищаем выбор
	clear_selection()
	
	# Обновляем доступные клетки
	update_available_cells()
	
	return path_copy

# Получение текущего пути
func get_current_path() -> Array[Vector2i]:
	return current_path

# Восстановление AP
func restore_ap():
	current_ap = max_ap
	update_available_cells()

# Алгоритм A* для построения пути
func find_path(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	var result_path: Array[Vector2i] = []
	
	# Если начальная и конечная клетки совпадают, возвращаем пустой путь
	if start_cell == end_cell:
		return result_path
	
	# Создаем алгоритм A*
	var astar = AStar2D.new()
	
	# Словарь ID узлов
	var cell_to_id = {}
	var id_counter = 0
	
	# Добавляем все проходимые клетки
	for cell in available_cells:
		var id = id_counter
		cell_to_id[cell] = id
		astar.add_point(id, Vector2(cell.x, cell.y))
		id_counter += 1
	
	# Добавляем также начальную клетку
	if !cell_to_id.has(start_cell):
		var id = id_counter
		cell_to_id[start_cell] = id
		astar.add_point(id, Vector2(start_cell.x, start_cell.y))
		id_counter += 1
	
	# Соединяем соседние клетки
	for cell_vec in cell_to_id:
		var cell = Vector2i(cell_vec.x, cell_vec.y)
		var cell_id = cell_to_id[cell]
		
		# Направления для соседей
		var directions = [
			Vector2i(0, -1),  # Вверх
			Vector2i(1, 0),   # Вправо
			Vector2i(0, 1),   # Вниз
			Vector2i(-1, 0),  # Влево
			Vector2i(1, -1),  # Вправо-вверх
			Vector2i(1, 1),   # Вправо-вниз
			Vector2i(-1, 1),  # Влево-вниз
			Vector2i(-1, -1)  # Влево-вверх
		]
		
		for dir in directions:
			var neighbor = cell + dir
			
			if neighbor in cell_to_id:
				var neighbor_id = cell_to_id[neighbor]
				
				# Вес ребра (для диагоналей можно сделать больше)
				var weight = 1.0
				if dir.x != 0 and dir.y != 0:
					# Проверка для диагоналей
					var x_neighbor = Vector2i(cell.x + dir.x, cell.y)
					var y_neighbor = Vector2i(cell.x, cell.y + dir.y)
					
					if map_generator.is_tile_walkable(x_neighbor.x, x_neighbor.y) or map_generator.is_tile_walkable(y_neighbor.x, y_neighbor.y):
						weight = 1.0
					else:
						continue
				
				if !astar.are_points_connected(cell_id, neighbor_id):
					astar.connect_points(cell_id, neighbor_id, weight)
	
	# Проверяем существование начальной и целевой клеток
	if !(start_cell in cell_to_id) or !(end_cell in cell_to_id):
		return result_path
	
	# Получаем путь
	var start_id = cell_to_id[start_cell]
	var end_id = cell_to_id[end_cell]
	var id_path = astar.get_id_path(start_id, end_id)
	
	# Преобразуем в массив координат
	for id in id_path:
		var point = astar.get_point_position(id)
		result_path.append(Vector2i(point.x, point.y))
	
	# Удаляем первую точку (текущее положение)
	if result_path.size() > 0:
		result_path.remove_at(0)
	
	return result_path
