class_name MoveManager
extends Node

# Сигналы для оповещения подписчиков
signal available_cells_updated
signal path_updated
signal path_cost_updated(cost)
signal path_split_updated(available_steps)

# Массив доступных клеток для перемещения
var available_cells: Array[Vector2i] = []

# Текущий путь, который будет отображаться
var current_path: Array[Vector2i] = []

# Количество шагов в пути, которые можно пройти с текущими AP
var available_path_steps: int = 0

# Текущая клетка персонажа
var character_cell: Vector2i = Vector2i.ZERO

# Клетка, выбранная для перемещения
var selected_cell: Vector2i = Vector2i(-1, -1)

# Ссылки на другие узлы
var map_generator: MapGenerator

# Очки действия персонажа и максимальное количество AP
var current_ap: int = 0
var max_ap: int = 50

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
				
			# Стоимость движения (для диагоналей делаем выше)
			var move_cost = 10
			if dir.x != 0 and dir.y != 0:
				move_cost = 15
			
				# Для диагонального движения проверяем, можно ли пройти
				var x_neighbor = Vector2i(current_pos.x + dir.x, current_pos.y)
				var y_neighbor = Vector2i(current_pos.x, current_pos.y + dir.y)

				if !(map_generator.is_tile_walkable(x_neighbor.x, x_neighbor.y) or map_generator.is_tile_walkable(y_neighbor.x, y_neighbor.y)):
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

# Проверка, проходима ли клетка (без учета AP)
func is_cell_walkable(cell: Vector2i) -> bool:
	return map_generator.is_tile_walkable(cell.x, cell.y)

# Обновление пути между текущей клеткой и выбранной целевой
func update_path_to_cell(target_cell: Vector2i):
	# Проверяем, проходима ли целевая клетка
	if !is_cell_walkable(target_cell):
		current_path.clear()
		available_path_steps = 0
		emit_signal("path_updated")
		emit_signal("path_split_updated", 0)
		return
	
	# Строим путь от клетки персонажа до целевой клетки, включая недоступные
	current_path = find_path_to_any_cell(character_cell, target_cell)
	
	# Определяем, сколько шагов пути доступно с текущими AP
	calculate_available_path_steps()
	
	emit_signal("path_updated")
	emit_signal("path_split_updated", available_path_steps)

# Рассчитываем, сколько шагов пути доступно с текущими AP
func calculate_available_path_steps():
	available_path_steps = 0
	var remaining_ap = current_ap
	
	for i in range(current_path.size()):
		var from = character_cell if i == 0 else current_path[i-1]
		var to = current_path[i]
		var dir = to - from
		
		# Стоимость шага
		var step_cost = 10
		if dir.x != 0 and dir.y != 0:
			step_cost = 15
		
		# Если не хватает AP, завершаем
		if remaining_ap < step_cost:
			break
		
		remaining_ap -= step_cost
		available_path_steps += 1

# Выбор клетки для перемещения
func select_cell(cell: Vector2i) -> bool:
	# Проверяем, проходима ли клетка (а не только доступна)
	if !is_cell_walkable(cell):
		return false
	
	selected_cell = cell
	update_path_to_cell(cell)
	
	# Рассчитываем и отправляем стоимость пути
	var path_cost = calculate_path_cost(current_path)
	emit_signal("path_cost_updated", path_cost)
	
	return true

# Очистка выбора клетки
func clear_selection():
	selected_cell = Vector2i(-1, -1)
	current_path.clear()
	available_path_steps = 0
	emit_signal("path_updated")
	emit_signal("path_split_updated", 0)
	# Отправляем сигнал с нулевой стоимостью при очистке выбора
	emit_signal("path_cost_updated", 0)

# Расчет стоимости пути
func calculate_path_cost(path: Array) -> int:
	var total_cost = 0
	
	# Если путь пустой, стоимость равна 0
	if path.size() == 0:
		return total_cost
	
	# Если путь состоит только из одной точки (первая клетка)
	if path.size() == 1:
		# Проверяем, не является ли эта точка текущей позицией персонажа
		if path[0] != character_cell:
			# Стоимость перемещения на соседнюю клетку
			var dir = path[0] - character_cell
			if dir.x != 0 and dir.y != 0:
				total_cost = 15  # Диагональное движение
			else:
				total_cost = 10  # Обычное движение
		return total_cost
	
	# Добавляем стоимость от текущей позиции персонажа до первой клетки пути
	var dir_to_first = path[0] - character_cell
	if dir_to_first.x != 0 and dir_to_first.y != 0:
		total_cost += 15  # Диагональное движение
	else:
		total_cost += 10  # Обычное движение
	
	# Считаем стоимость каждого шага пути
	for i in range(1, path.size()):
		var from = path[i-1]
		var to = path[i]
		var dir = to - from
		
		# Диагональное движение стоит 15, обычное - 10
		if dir.x != 0 and dir.y != 0:
			total_cost += 15  # Диагональное движение
		else:
			total_cost += 10  # Обычное движение
	
	return total_cost

# Перемещение персонажа в выбранную клетку
func move_to_selected_cell() -> Array[Vector2i]:
	if selected_cell == Vector2i(-1, -1) or current_path.size() == 0:
		return []
	
	var path_copy: Array[Vector2i] = []
	
	# Берем только доступную часть пути
	for i in range(min(available_path_steps, current_path.size())):
		path_copy.append(current_path[i])
	
	# Уменьшаем AP на длину пути с учетом стоимости
	for i in range(1, path_copy.size()):
		var dir = path_copy[i] - path_copy[i - 1]
		if dir.x != 0 and dir.y != 0:
			current_ap -= 15  # Диагональное движение
		else:
			current_ap -= 10  # Обычное движение
	
	# Если путь не пустой, обновляем текущую клетку персонажа
	if path_copy.size() > 0:
		character_cell = path_copy[path_copy.size() - 1]
	
	# Очищаем выбор
	clear_selection()
	
	# Обновляем доступные клетки
	update_available_cells()
	
	return path_copy

# Получение текущего пути
func get_current_path() -> Array[Vector2i]:
	return current_path

# Получение количества доступных шагов пути
func get_available_path_steps() -> int:
	return available_path_steps

# Восстановление AP
func restore_ap():
	current_ap = max_ap
	update_available_cells()

# Алгоритм A* для построения пути до любой клетки (без ограничения AP)
func find_path_to_any_cell(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	var result_path: Array[Vector2i] = []
	
	# Если начальная и конечная клетки совпадают, возвращаем пустой путь
	if start_cell == end_cell:
		return result_path
	
	# Создаем алгоритм A*
	var astar = AStar2D.new()
	
	# Словарь ID узлов
	var cell_to_id = {}
	var id_counter = 0
	
	# Подготовка к поиску пути - добавляем все проходимые клетки в области поиска
	var min_x = min(start_cell.x, end_cell.x) - 20
	var max_x = max(start_cell.x, end_cell.x) + 20
	var min_y = min(start_cell.y, end_cell.y) - 20
	var max_y = max(start_cell.y, end_cell.y) + 20
	
	# Добавляем все проходимые клетки в области поиска
	for x in range(min_x, max_x):
		for y in range(min_y, max_y):
			var cell = Vector2i(x, y)
			if is_cell_walkable(cell):
				var id = id_counter
				cell_to_id[cell] = id
				astar.add_point(id, Vector2(cell.x, cell.y))
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
				
				# Вес ребра (для диагоналей делаем больше)
				var weight = 10.0
				if dir.x != 0 and dir.y != 0:
					# Исправленная проверка для диагоналей
					var x_neighbor = Vector2i(cell.x + dir.x, cell.y)
					var y_neighbor = Vector2i(cell.x, cell.y + dir.y)

					# Для диагонального движения хотя бы одна из соседних клеток должна быть проходимой
					if is_cell_walkable(x_neighbor) or is_cell_walkable(y_neighbor):
						weight = 15.0
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

# Добавляем старый метод find_path для обратной совместимости
func find_path(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	return find_path_to_any_cell(start_cell, end_cell)
