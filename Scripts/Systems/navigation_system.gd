# CustomNavigation.gd
class_name CustomNavigation
extends RefCounted

var world_map: TileMapLayer

func init(map: TileMapLayer):
	world_map = map

func find_path_with_cost(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	if !is_valid_cell(start_cell) || !is_valid_cell(end_cell) || !world_map.is_cell_passable(start_cell) || !world_map.is_cell_passable(end_cell):
		return []  # Возвращаем пустой путь, если начальная или конечная клетка недопустима

	@warning_ignore("unused_variable")
	var map_size = Vector2i(world_map.Width, world_map.Height)
	var cost_grid = {} # Словарь для хранения накопленной стоимости для каждой клетки
	var came_from = {} # Словарь для хранения "родительской" клетки для каждой клетки
	var frontier = PriorityQueue.new() # Приоритетная очередь для клеток на рассмотрение

	cost_grid[start_cell] = 0
	frontier.push(start_cell, 0) # Начинаем с начальной клетки с нулевой стоимостью
	came_from[start_cell] = null

	while !frontier.is_empty():
		var current_cell = frontier.pop()

		if current_cell == end_cell:
			break # Путь найден

		for neighbor_cell in get_neighbors(current_cell):
			if !is_valid_cell(neighbor_cell) || !world_map.is_cell_passable(neighbor_cell): # Используем исправленную функцию is_valid_cell
				continue # Пропускаем недопустимые клетки

			var new_cost = cost_grid[current_cell] + world_map.get_move_cost(neighbor_cell)

			if !cost_grid.has(neighbor_cell) || new_cost < cost_grid[neighbor_cell]:
				cost_grid[neighbor_cell] = new_cost
				came_from[neighbor_cell] = current_cell
				frontier.push(neighbor_cell, new_cost)

	if !cost_grid.has(end_cell):
		return [] # Путь не найден

	# Восстановление пути от цели к началу
	var path: Array[Vector2i] = []
	var current = end_cell
	while current != start_cell:
		path.push_front(current)
		current = came_from[current]
		if came_from[current] == null:
			break # Безопасность на случай ошибки в came_from
	path.push_front(start_cell)
	return path

func find_path_with_cost_no_fog(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	if !is_valid_cell(start_cell) || !is_valid_cell(end_cell) || !world_map.is_cell_passable(start_cell) || !world_map.is_cell_passable(end_cell):
		return []  # Возвращаем пустой путь, если начальная или конечная клетка недопустима

	@warning_ignore("unused_variable")
	var map_size = Vector2i(world_map.Width, world_map.Height)
	var cost_grid = {} # Словарь для хранения накопленной стоимости для каждой клетки
	var came_from = {} # Словарь для хранения "родительской" клетки для каждой клетки
	var frontier = PriorityQueue.new() # Приоритетная очередь для клеток на рассмотрение

	cost_grid[start_cell] = 0
	frontier.push(start_cell, 0) # Начинаем с начальной клетки с нулевой стоимостью
	came_from[start_cell] = null

	while !frontier.is_empty():
		var current_cell = frontier.pop()

		if current_cell == end_cell:
			break # Путь найден

		for neighbor_cell in get_neighbors(current_cell):
			if !is_valid_cell(neighbor_cell) || !world_map.is_cell_passable(neighbor_cell): # Используем исправленную функцию is_valid_cell
				continue # Пропускаем недопустимые клетки

			var new_cost = cost_grid[current_cell] + world_map.get_move_cost_no_fog(neighbor_cell)

			if !cost_grid.has(neighbor_cell) || new_cost < cost_grid[neighbor_cell]:
				cost_grid[neighbor_cell] = new_cost
				came_from[neighbor_cell] = current_cell
				frontier.push(neighbor_cell, new_cost)

	if !cost_grid.has(end_cell):
		return [] # Путь не найден

	# Восстановление пути от цели к началу
	var path: Array[Vector2i] = []
	var current = end_cell
	while current != start_cell:
		path.push_front(current)
		current = came_from[current]
		if came_from[current] == null:
			break # Безопасность на случай ошибки в came_from
	path.push_front(start_cell)
	return path

func get_neighbors(cell: Vector2i) -> Array[Vector2i]:
	# **Явно указываем тип массива neighbors как Array[Vector2i]**:
	var neighbors: Array[Vector2i] = []
	# **Убрали диагональные направления, оставили только 4 ортогональных:**
	var directions = [
		Vector2i(0, 1),  # Вверх
		Vector2i(0, -1), # Вниз
		Vector2i(1, 0),  # Вправо
		Vector2i(-1, 0)  # Влево
	]
	for dir in directions:
		var neighbor_cell = cell + dir
		if is_valid_cell(neighbor_cell) : # Используем исправленную функцию is_valid_cell
			neighbors.append(neighbor_cell)
	return neighbors
	

# **Новая функция `is_valid_cell` добавлена здесь:**
func is_valid_cell(cell: Vector2i) -> bool:
	if cell.x >= 0 && cell.x < world_map.Width && cell.y >= 0 && cell.y < world_map.Height:
		return true
	return false


class PriorityQueue: # Вспомогательный класс приоритетной очереди (простая реализация)
	var elements = []

	func push(element, priority):
		elements.append({"element": element, "priority": priority})
		elements.sort_custom(func(a, b): return a.priority < b.priority) # Сортировка по приоритету

	func pop():
		if elements.is_empty():
			return null
		var element = elements[0].element
		elements.pop_front()
		return element

	func is_empty():
		return elements.is_empty()
