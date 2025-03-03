class_name CustomNavigation
extends RefCounted

var world_map: TileMapLayer

func init(map: TileMapLayer):
	world_map = map

func find_path_with_cost(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	if !is_valid_cell(start_cell) || !is_valid_cell(end_cell) || !world_map.is_cell_passable(start_cell) || !world_map.is_cell_passable(end_cell):
		return []  # Возвращаем пустой путь, если начальная или конечная клетка недопустима

	# Эвристика для A* - манхэттенское расстояние
	var heuristic = func(cell): return abs(cell.x - end_cell.x) + abs(cell.y - end_cell.y)

	var cost_grid = {} # Словарь для хранения накопленной стоимости для каждой клетки
	var came_from = {} # Словарь для хранения "родительской" клетки для каждой клетки
	var frontier = BinaryHeap.new() # Оптимизированная приоритетная очередь (бинарная куча)

	cost_grid[start_cell] = 0
	frontier.push(start_cell, 0 + heuristic.call(start_cell)) # A* с эвристикой
	came_from[start_cell] = null

	while !frontier.is_empty():
		var current_cell = frontier.pop()

		if current_cell == end_cell:
			break # Путь найден

		for neighbor_cell in get_neighbors(current_cell):
			if !is_valid_cell(neighbor_cell) || !world_map.is_cell_passable(neighbor_cell):
				continue # Пропускаем недопустимые клетки
			
			var new_cost = cost_grid[current_cell] + world_map.get_move_cost(neighbor_cell)

			if !cost_grid.has(neighbor_cell) || new_cost < cost_grid[neighbor_cell]:
				cost_grid[neighbor_cell] = new_cost
				came_from[neighbor_cell] = current_cell
				# Используем A* с эвристикой для более направленного поиска
				frontier.push(neighbor_cell, new_cost + heuristic.call(neighbor_cell))

	if !cost_grid.has(end_cell):
		return [] # Путь не найден

	# Восстановление пути от цели к началу
	var path: Array[Vector2i] = []
	var current = end_cell
	while current != start_cell:
		path.push_front(current)
		current = came_from[current]
		if current == null: # Более безопасная проверка
			return [] # Ошибка в восстановлении пути
	path.push_front(start_cell)
	return path

func find_path_with_cost_no_fog(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	if !is_valid_cell(start_cell) || !is_valid_cell(end_cell) || !world_map.is_cell_passable(start_cell) || !world_map.is_cell_passable(end_cell):
		return []  # Возвращаем пустой путь, если начальная или конечная клетка недопустима

	# Эвристика для A* - манхэттенское расстояние
	var heuristic = func(cell): return abs(cell.x - end_cell.x) + abs(cell.y - end_cell.y)

	var cost_grid = {} # Словарь для хранения накопленной стоимости для каждой клетки
	var came_from = {} # Словарь для хранения "родительской" клетки для каждой клетки
	var frontier = BinaryHeap.new() # Оптимизированная приоритетная очередь

	cost_grid[start_cell] = 0
	frontier.push(start_cell, 0 + heuristic.call(start_cell))
	came_from[start_cell] = null

	while !frontier.is_empty():
		var current_cell = frontier.pop()

		if current_cell == end_cell:
			break # Путь найден

		for neighbor_cell in get_neighbors(current_cell):
			if !is_valid_cell(neighbor_cell) || !world_map.is_cell_passable(neighbor_cell):
				continue # Пропускаем недопустимые клетки

			var new_cost = cost_grid[current_cell] + world_map.get_move_cost_no_fog(neighbor_cell)

			if !cost_grid.has(neighbor_cell) || new_cost < cost_grid[neighbor_cell]:
				cost_grid[neighbor_cell] = new_cost
				came_from[neighbor_cell] = current_cell
				frontier.push(neighbor_cell, new_cost + heuristic.call(neighbor_cell))

	if !cost_grid.has(end_cell):
		return [] # Путь не найден

	# Восстановление пути от цели к началу
	var path: Array[Vector2i] = []
	var current = end_cell
	while current != start_cell:
		path.push_front(current)
		current = came_from[current]
		if current == null: # Более безопасная проверка
			return [] # Ошибка в восстановлении пути
	path.push_front(start_cell)
	return path

func get_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var directions = [
		Vector2i(0, 1),  # Вверх
		Vector2i(0, -1), # Вниз
		Vector2i(1, 0),  # Вправо
		Vector2i(-1, 0)  # Влево
	]
	for dir in directions:
		var neighbor_cell = cell + dir
		if is_valid_cell(neighbor_cell):
			neighbors.append(neighbor_cell)
	return neighbors

func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 && cell.x < world_map.Width && cell.y >= 0 && cell.y < world_map.Height

# Оптимизированная приоритетная очередь, реализованная через бинарную кучу
class BinaryHeap:
	var elements = []
	var cell_indices = {} # Словарь для быстрого доступа к индексу элемента

	func push(element, priority):
		var item = {"element": element, "priority": priority}
		elements.append(item)
		var idx = elements.size() - 1
		cell_indices[element] = idx
		_sift_up(idx)

	func pop():
		if elements.is_empty():
			return null
			
		var top_element = elements[0].element
		var last_item = elements.pop_back()
		cell_indices.erase(top_element)
		
		if !elements.is_empty():
			elements[0] = last_item
			cell_indices[last_item.element] = 0
			_sift_down(0)
			
		return top_element

	func is_empty():
		return elements.is_empty()

	# Восстановление свойств кучи при добавлении элемента
	func _sift_up(idx):
		var parent = (idx - 1) / 2
		
		while idx > 0 && elements[parent].priority > elements[idx].priority:
			# Обмен элементами
			var temp = elements[idx]
			elements[idx] = elements[parent]
			elements[parent] = temp
			
			# Обновление индексов
			cell_indices[elements[idx].element] = idx
			cell_indices[elements[parent].element] = parent
			
			idx = parent
			parent = (idx - 1) / 2

	# Восстановление свойств кучи при удалении элемента
	func _sift_down(idx):
		var size = elements.size()
		var smallest = idx
		
		while true:
			var left = 2 * idx + 1
			var right = 2 * idx + 2
			
			if left < size && elements[left].priority < elements[smallest].priority:
				smallest = left
				
			if right < size && elements[right].priority < elements[smallest].priority:
				smallest = right
				
			if smallest == idx:
				break
				
			# Обмен элементами
			var temp = elements[idx]
			elements[idx] = elements[smallest]
			elements[smallest] = temp
			
			# Обновление индексов
			cell_indices[elements[idx].element] = idx
			cell_indices[elements[smallest].element] = smallest
			
			idx = smallest
