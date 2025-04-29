class_name MoveManager
extends Node

#region Сигналы
signal available_cells_updated
signal path_updated
signal path_cost_updated(cost)
signal path_split_updated(available_steps)
#endregion

#region Переменные перемещения
# Массив доступных клеток для перемещения
var available_cells: Array[Vector2i] = []

# Данные о пути
var current_path: Array[Vector2i] = []
var available_path_steps: int = 0

# Позиции персонажа
var character_cell: Vector2i = Vector2i.ZERO
var selected_cell: Vector2i = Vector2i(-1, -1)

# Ссылка на генератор карты
var map_generator: MapGenerator

# Очки действия
var current_ap: int = 0
var max_ap: int = 50
#endregion

#region Инициализация
func initialize(mapGen: MapGenerator, startCell: Vector2i, actionPoints: int, maxActionPoints: int):
	map_generator = mapGen
	character_cell = startCell
	current_ap = actionPoints
	max_ap = maxActionPoints
	
	update_available_cells()
#endregion

#region Управление доступными клетками
func update_available_cells():
	available_cells.clear()
	
	# Если нет AP, то перемещаться некуда
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
		
		# Получаем направления движения
		var directions = get_movement_directions()
		
		for dir in directions:
			var next_pos = current_pos + dir
			
			# Проверяем проходимость
			if !map_generator.is_tile_walkable(next_pos.x, next_pos.y):
				continue
				
			# Определяем стоимость движения
			var move_cost = get_movement_cost(dir)
			
			# Проверяем диагональное движение
			if dir.x != 0 and dir.y != 0:
				if !is_diagonal_move_valid(current_pos, dir):
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
	
	emit_signal("available_cells_updated")

func is_cell_available(cell: Vector2i) -> bool:
	return available_cells.has(cell)

func is_cell_walkable(cell: Vector2i) -> bool:
	return map_generator.is_tile_walkable(cell.x, cell.y)

func is_diagonal_move_valid(current_pos: Vector2i, dir: Vector2i) -> bool:
	var x_neighbor = Vector2i(current_pos.x + dir.x, current_pos.y)
	var y_neighbor = Vector2i(current_pos.x, current_pos.y + dir.y)
	
	return map_generator.is_tile_walkable(x_neighbor.x, x_neighbor.y) or \
		   map_generator.is_tile_walkable(y_neighbor.x, y_neighbor.y)
#endregion

#region Управление путем
func update_path_to_cell(target_cell: Vector2i):
	if !is_cell_walkable(target_cell):
		clear_path()
		return
	
	# Строим путь от клетки персонажа до целевой клетки
	current_path = find_path_to_any_cell(character_cell, target_cell)
	
	# Определяем доступную часть пути
	calculate_available_path_steps()
	
	emit_signal("path_updated")
	emit_signal("path_split_updated", available_path_steps)

func calculate_available_path_steps():
	available_path_steps = 0
	var remaining_ap = current_ap
	
	for i in range(current_path.size()):
		var from = character_cell if i == 0 else current_path[i-1]
		var to = current_path[i]
		var dir = to - from
		
		var step_cost = get_movement_cost(dir)
		
		if remaining_ap < step_cost:
			break
		
		remaining_ap -= step_cost
		available_path_steps += 1

func clear_path():
	current_path.clear()
	available_path_steps = 0
	emit_signal("path_updated")
	emit_signal("path_split_updated", 0)
#endregion

#region Выбор и перемещение
func select_cell(cell: Vector2i) -> bool:
	if !is_cell_walkable(cell):
		return false
	
	selected_cell = cell
	update_path_to_cell(cell)
	
	var path_cost = calculate_path_cost(current_path)
	emit_signal("path_cost_updated", path_cost)
	
	return true

func clear_selection():
	selected_cell = Vector2i(-1, -1)
	clear_path()
	emit_signal("path_cost_updated", 0)

func move_to_selected_cell() -> Array[Vector2i]:
	if selected_cell == Vector2i(-1, -1) or current_path.size() == 0:
		return []
	
	var path_copy: Array[Vector2i] = []
	
	# Берем только доступную часть пути
	for i in range(min(available_path_steps, current_path.size())):
		path_copy.append(current_path[i])
	
	# Уменьшаем AP на длину пути
	for i in range(1, path_copy.size()):
		var from = path_copy[i-2] if i > 1 else character_cell  # Правильный синтаксис для GDScript
		var to = path_copy[i-1]
		var dir = to - from
		current_ap -= get_movement_cost(dir)
	
	# Обновляем текущую клетку персонажа
	if path_copy.size() > 0:
		character_cell = path_copy[path_copy.size() - 1]
	
	# Очищаем выбор
	clear_selection()
	
	# Обновляем доступные клетки
	update_available_cells()
	
	return path_copy
#endregion

#region Расчет стоимости
func calculate_path_cost(path: Array) -> int:
	var total_cost = 0
	
	if path.size() == 0:
		return 0
	
	# Стоимость первого шага
	if path.size() >= 1:
		var dir = path[0] - character_cell
		total_cost += get_movement_cost(dir)
	
	# Стоимость последующих шагов
	for i in range(1, path.size()):
		var dir = path[i] - path[i-1]
		total_cost += get_movement_cost(dir)
	
	return total_cost

func get_movement_cost(dir: Vector2i) -> int:
	return 15 if (dir.x != 0 and dir.y != 0) else 10

func get_movement_directions() -> Array:
	return [
		Vector2i(0, -1),  # Вверх
		Vector2i(1, 0),   # Вправо
		Vector2i(0, 1),   # Вниз
		Vector2i(-1, 0),  # Влево
		Vector2i(1, -1),  # Вправо-вверх
		Vector2i(1, 1),   # Вправо-вниз
		Vector2i(-1, 1),  # Влево-вниз
		Vector2i(-1, -1)  # Влево-вверх
	]
#endregion

#region Поиск пути
func find_path_to_any_cell(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	var result_path: Array[Vector2i] = []
	
	if start_cell == end_cell:
		return result_path
	
	# Создаем алгоритм A*
	var astar = AStar2D.new()
	
	# Словарь ID узлов
	var cell_to_id = {}
	var id_counter = 0
	
	# Определяем область поиска
	var search_margin = 20
	var min_x = min(start_cell.x, end_cell.x) - search_margin
	var max_x = max(start_cell.x, end_cell.x) + search_margin
	var min_y = min(start_cell.y, end_cell.y) - search_margin
	var max_y = max(start_cell.y, end_cell.y) + search_margin
	
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
		
		for dir in get_movement_directions():
			var neighbor = cell + dir
			
			if neighbor in cell_to_id:
				var neighbor_id = cell_to_id[neighbor]
				
				# Вес ребра (для диагоналей больше)
				var weight = get_movement_cost(dir)
				
				# Проверка для диагональных движений
				if dir.x != 0 and dir.y != 0:
					if !is_diagonal_move_valid(cell, dir):
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
#endregion

#region Вспомогательные функции
func restore_ap():
	current_ap = max_ap
	update_available_cells()

func get_current_path() -> Array[Vector2i]:
	return current_path

func get_available_path_steps() -> int:
	return available_path_steps

# Для совместимости
func find_path(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	return find_path_to_any_cell(start_cell, end_cell)
#endregion
