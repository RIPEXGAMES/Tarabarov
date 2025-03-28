class_name HighlightLayer
extends TileMapLayer

# Ссылка на MapGenerator и Character
@export var map_generator: MapGenerator
@export var character_path: NodePath = "../Character"

# ID источника тайлов и координаты
@export var source_id: int = 0
@export var tile_coords: Vector2i = Vector2i(0, 0)

# Цвета для разных состояний
const WALKABLE_COLOR = Color(0, 1, 0, 0.3)        # Зеленый (доступные тайлы)
const NON_WALKABLE_COLOR = Color(1, 0, 0, 0.3)    # Красный (недоступные тайлы)
const HOVER_COLOR = Color(0, 1, 1, 0.7)           # Бирюзовый (тайл под курсором)
const REACHABLE_COLOR = Color(0.5, 0.8, 0.2, 0.4) # Светло-зеленый (тайлы в радиусе действия)

# Текущая позиция выделения
var current_highlight_pos: Vector2i = Vector2i(-1, -1)
var character: Character
var reachable_tiles: Dictionary = {}  # Хранит тайлы, доступные для перемещения и стоимость пути
var show_reachable_area: bool = true  # Флаг для включения/отключения выделения доступных тайлов
var last_character_pos: Vector2i = Vector2i(-1, -1)  # Для отслеживания перемещения персонажа
var last_ap_value: int = -1  # Для отслеживания изменения AP

func _ready():
	# Убедимся, что у нас есть ссылка на MapGenerator
	if map_generator == null:
		map_generator = get_node("../MapGenerator")
		if map_generator == null:
			push_error("HighlightLayer: Не удалось найти ноду MapGenerator!")
			
	# Получаем ссылку на персонажа
	character = get_node(character_path)
	if character == null:
		push_error("HighlightLayer: Не удалось найти ноду Character!")
	
	# Инициализация отображения доступных тайлов
	if character and show_reachable_area:
		call_deferred("update_reachable_tiles")

func _process(_delta):
	if not character:
		return
		
	# Проверяем, изменилась ли позиция персонажа или количество AP
	var current_char_pos = character.current_cell
	var current_ap = character.remaining_ap
	
	# Если позиция персонажа или AP изменились, обновляем выделение
	if (current_char_pos != last_character_pos or current_ap != last_ap_value) and show_reachable_area:
		print("HighlightLayer: Character position changed from ", last_character_pos, " to ", current_char_pos, " or AP changed from ", last_ap_value, " to ", current_ap)
		update_reachable_tiles()
		last_character_pos = current_char_pos
		last_ap_value = current_ap
	
	# Преобразуем позицию мыши в координаты карты
	var mouse_pos = get_global_mouse_position()
	var tile_pos = local_to_map(to_local(mouse_pos))
	
	# Проверяем, изменилась ли позиция мыши
	if tile_pos != current_highlight_pos:
		# Сохраняем текущую область выделения, если она есть
		var saved_cells = get_used_cells()
		
		# Очищаем предыдущее выделение
		clear()
		
		# Восстанавливаем выделение доступных тайлов
		if show_reachable_area:
			highlight_reachable_area()
		
		# Проверяем, что позиция тайла находится в пределах карты
		if tile_pos.x >= 0 and tile_pos.x < map_generator.map_width and \
		   tile_pos.y >= 0 and tile_pos.y < map_generator.map_height:
			
			# Обновляем текущую позицию выделения
			current_highlight_pos = tile_pos
			
			# Проверяем, доступен ли тайл для перемещения
			var is_reachable = reachable_tiles.has(tile_pos)
			
			# Размещаем тайл выделения
			set_cell(tile_pos, source_id, tile_coords)
			
			# Устанавливаем цвет для тайла под курсором
			self.modulate = HOVER_COLOR

# Метод для ручного выделения конкретного тайла
func highlight_tile(x: int, y: int, color: Color = WALKABLE_COLOR, force_highlight: bool = false):
	var pos = Vector2i(x, y)
	
	# Проверяем, что позиция находится в пределах карты
	if x >= 0 and x < map_generator.map_width and y >= 0 and y < map_generator.map_height:
		# Применяем выделение
		set_cell(pos, source_id, tile_coords)
		
		# Устанавливаем цвет
		self.modulate = color
		
		# Обновляем текущую позицию только если не принудительное выделение
		if !force_highlight:
			current_highlight_pos = pos

# Очистить все выделения
func clear_highlights():
	clear()
	current_highlight_pos = Vector2i(-1, -1)

# НОВЫЙ АЛГОРИТМ: Обход всех возможных путей с использованием Dijkstra
func update_reachable_tiles():
	if not character:
		push_error("HighlightLayer: Character is null in update_reachable_tiles!")
		return
		
	print("HighlightLayer.update_reachable_tiles() - Starting from cell: ", character.current_cell, " with AP: ", character.remaining_ap)
	
	reachable_tiles.clear()
	
	# Получаем текущую позицию персонажа и доступные AP
	var start_pos = character.current_cell
	var total_ap = character.remaining_ap
	
	# Алгоритм Dijkstra для нахождения кратчайших путей до всех доступных клеток
	var queue = []         # Очередь с приоритетом
	var costs = {}         # Стоимость пути до каждой клетки
	var visited = {}       # Посещенные клетки
	
	# Добавляем начальную клетку
	queue.append({"pos": start_pos, "cost": 0})
	costs[start_pos] = 0
	
	while queue.size() > 0:
		# Сортируем очередь по стоимости
		queue.sort_custom(func(a, b): return a.cost < b.cost)
		
		# Берем клетку с наименьшей стоимостью
		var current = queue.pop_front()
		var current_pos = current.pos
		var current_cost = current.cost
		
		# Если мы уже посетили эту клетку, пропускаем
		if visited.has(current_pos):
			continue
			
		# Отмечаем как посещенную
		visited[current_pos] = true
		
		# Добавляем в список доступных клеток
		reachable_tiles[current_pos] = current_cost
		
		# Если достигли максимального количества AP, не проверяем соседей
		if current_cost >= total_ap:
			continue
		
		# Получаем все соседние клетки
		var neighbors = []
		
		# Ортогональные направления
		var directions = [
			Vector2i(0, -1),  # Вверх
			Vector2i(1, 0),   # Вправо
			Vector2i(0, 1),   # Вниз
			Vector2i(-1, 0)   # Влево
		]
		
		# Диагональные направления
		if character.allow_diagonal:
			directions.append_array([
				Vector2i(1, -1),   # Вправо-вверх
				Vector2i(1, 1),    # Вправо-вниз
				Vector2i(-1, 1),   # Влево-вниз
				Vector2i(-1, -1)   # Влево-вверх
			])
		
		# Проверяем каждое направление
		for dir in directions:
			var next_pos = current_pos + dir
			
			# Проверяем границы карты
			if next_pos.x < 0 or next_pos.x >= map_generator.map_width or \
			   next_pos.y < 0 or next_pos.y >= map_generator.map_height:
				continue
			
			# Проверяем проходимость
			if not map_generator.is_tile_walkable(next_pos.x, next_pos.y):
				continue
				
			# Определяем стоимость перемещения
			var move_cost = 1  # Базовая стоимость для ортогональных направлений
			
			# Для диагонального движения
			if dir.x != 0 and dir.y != 0:
				# Проверка для диагонального перемещения (нужно, чтобы хотя бы одна смежная клетка была проходима)
				var x_neighbor = Vector2i(current_pos.x + dir.x, current_pos.y)
				var y_neighbor = Vector2i(current_pos.x, current_pos.y + dir.y)
				
				var x_walkable = map_generator.is_tile_walkable(x_neighbor.x, x_neighbor.y)
				var y_walkable = map_generator.is_tile_walkable(y_neighbor.x, y_neighbor.y)
				
				# Если ни одна из смежных клеток не проходима, нельзя пройти по диагонали
				if not (x_walkable or y_walkable):
					continue
					
				move_cost = 1  # Используем ту же стоимость для диагоналей
			
			# Вычисляем новую стоимость
			var new_cost = current_cost + move_cost
			
			# Если уже посещено с меньшей стоимостью, пропускаем
			if costs.has(next_pos) and costs[next_pos] <= new_cost:
				continue
				
			# Если новая стоимость в пределах AP
			if new_cost <= total_ap:
				# Обновляем стоимость
				costs[next_pos] = new_cost
				
				# Добавляем в очередь для проверки
				queue.append({"pos": next_pos, "cost": new_cost})
	
	# Отображаем доступные тайлы, если нужно
	if show_reachable_area:
		highlight_reachable_area()
		
	print("HighlightLayer: Обновлены доступные тайлы, найдено: ", reachable_tiles.size())
	
	# Отладочный вывод для первых 10 тайлов
	var count = 0
	for pos in reachable_tiles:
		print("Reachable tile: ", pos, " Cost: ", reachable_tiles[pos])
		count += 1
		if count >= 10:
			print("... и ещё ", reachable_tiles.size() - 10, " тайлов")
			break

# Выделяем все доступные тайлы
func highlight_reachable_area():
	clear()
	self.modulate = REACHABLE_COLOR
	
	# Выделяем все доступные тайлы
	for pos in reachable_tiles:
		set_cell(pos, source_id, tile_coords)
		
	print("HighlightLayer: Highlighted reachable tiles: ", reachable_tiles.size())

# Включить/выключить отображение доступных тайлов
func toggle_reachable_area():
	show_reachable_area = !show_reachable_area
	
	if show_reachable_area:
		update_reachable_tiles()
	else:
		clear()

# Получение соседних клеток (для совместимости со старым кодом)
func get_walkable_neighbors(pos: Vector2i) -> Array:
	var neighbors = []
	
	# Базовые направления: вверх, вправо, вниз, влево
	var directions = [
		Vector2i(0, -1),  # Вверх
		Vector2i(1, 0),   # Вправо
		Vector2i(0, 1),   # Вниз
		Vector2i(-1, 0)   # Влево
	]
	
	# Добавляем диагональные направления, если разрешено
	if character.allow_diagonal:
		directions.append_array([
			Vector2i(1, -1),   # Вправо-вверх
			Vector2i(1, 1),    # Вправо-вниз
			Vector2i(-1, 1),   # Влево-вниз
			Vector2i(-1, -1)   # Влево-вверх
		])
		
	for dir in directions:
		var next_pos = pos + dir
		var nx = next_pos.x
		var ny = next_pos.y
		
		# Проверяем, что позиция находится в пределах карты и проходима
		if nx >= 0 and nx < map_generator.map_width and \
		   ny >= 0 and ny < map_generator.map_height and \
		   map_generator.is_tile_walkable(nx, ny):
			
			# Дополнительная проверка для диагональных направлений
			if dir.x != 0 and dir.y != 0:
				# Для диагонального движения нужно, чтобы хотя бы одна из соседних клеток была проходима
				var x_neighbor = Vector2i(pos.x + dir.x, pos.y)
				var y_neighbor = Vector2i(pos.x, pos.y + dir.y)
				
				if map_generator.is_tile_walkable(x_neighbor.x, x_neighbor.y) or map_generator.is_tile_walkable(y_neighbor.x, y_neighbor.y):
					neighbors.append(next_pos)
			else:
				neighbors.append(next_pos)
				
	return neighbors
