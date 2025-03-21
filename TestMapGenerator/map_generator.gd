class_name MapGenerator
extends Node

# Настройки генерации карты
@export var map_width: int = 30
@export var map_height: int = 30
@export var tree_density: float = 0.1  # Плотность деревьев (0-1)
@export var rock_density: float = 0.01  # Плотность камней (0-1)
@export var fallen_tree_density: float = 0.03  # Плотность поваленных деревьев
@export var water_chance: float = 0.1   # Шанс генерации водоемов
@export var path_chance: float = 0.3    # Шанс генерации дорог/тропинок

# Ссылки на слои тайлмапа
@onready var landscape_layer: TileMapLayer = $"../Landscape"
@onready var obstacles_layer: TileMapLayer = $"../Obstacles"

# Константы для типов тайлов (ID нужно заменить на ваши)
enum LandscapeType {
	GRASS = 0,
	DIRT = 1,
	WATER = 2,
	PATH = 3
}

enum ObstacleType {
	TREE = 10,  # Начинаем с 10, чтобы избежать конфликта с LandscapeType
	ROCK = 11,
	FALLEN_TREE_LEFT = 12,  # Левая часть поваленного дерева
	FALLEN_TREE_RIGHT = 13, # Правая часть поваленного дерева
	FENCE = 14
}

# Массив проходимости: true - можно ходить, false - нельзя
var walkable_tiles = []

# Словарь проходимости по типам тайлов
var walkability = {
	LandscapeType.GRASS: true,
	LandscapeType.DIRT: true,
	LandscapeType.WATER: false,
	LandscapeType.PATH: true,
	ObstacleType.TREE: false,
	ObstacleType.ROCK: false,
	ObstacleType.FALLEN_TREE_LEFT: false,
	ObstacleType.FALLEN_TREE_RIGHT: false,
	ObstacleType.FENCE: false
}

func _ready():
	# Инициализация массива проходимости
	walkable_tiles.resize(map_width * map_height)
	walkable_tiles.fill(true)
	
	no_obstacles_cells = []
	
	# Генерируем карту при запуске
	generate_map()

func generate_map():
	# Очищаем тайлмапы перед генерацией
	landscape_layer.clear()
	obstacles_layer.clear()
	
	no_obstacles_cells.clear()
	
	# 1. Генерация базового ландшафта
	generate_base_landscape()
	
	# 2. Генерация водоемов
	generate_water_bodies()
	
	# 3. Генерация дорог/тропинок
	generate_paths()
	
	# 4. Генерация препятствий
	generate_obstacles()
	
	print("Карта успешно сгенерирована!")

func generate_base_landscape():
	# Заполняем базовый слой травой
	for x in range(map_width):
		for y in range(map_height):
			# Основной тип - трава
			var tile_type = LandscapeType.GRASS
			
			# Иногда добавляем грязь для разнообразия
			if randf() < 0.1:
				tile_type = LandscapeType.DIRT
				
			# Размещаем тайл
			landscape_layer.set_cell(Vector2i(x, y), 0, Vector2i(tile_type, 0))
			
			# Обновляем проходимость
			update_walkability(x, y, tile_type, true)

func generate_water_bodies():
	if randf() < water_chance:
		# Создаем водоемы с помощью шума Перлина
		var noise = FastNoiseLite.new()
		noise.seed = randi()
		noise.frequency = 0.07
		
		for x in range(map_width):
			for y in range(map_height):
				var noise_val = noise.get_noise_2d(x, y)
				if noise_val > 0.3:  # Порог для водных участков
					landscape_layer.set_cell(Vector2i(x, y), 0, Vector2i(LandscapeType.WATER, 0))
					update_walkability(x, y, LandscapeType.WATER, true)

func generate_paths():
	if randf() < path_chance:
		# Начальная и конечная точки теперь всегда на краях карты
		var start_x = 0
		var end_x = map_width - 1
		
		# Случайная высота для начальной и конечной точек (могут отличаться)
		var start_y = randi() % map_height
		var end_y = randi() % map_height
		
		# Используем алгоритм Брезенхема для рисования линии между точками
		var path_points = bresenham_line(start_x, start_y, end_x, end_y)
		
		# Рисуем тропинку и подготавливаем область вокруг нее
		for point in path_points:
			# Основная тропинка
			landscape_layer.set_cell(point, 0, Vector2i(LandscapeType.PATH, 0))
			update_walkability(point.x, point.y, LandscapeType.PATH, true)
			
			# Обрабатываем область вокруг дороги
			prepare_path_surroundings(point.x, point.y)
			
			# Иногда делаем тропинку шире
			if randf() < 0.3:
				var offset = 1 if randf() < 0.5 else -1
				var wider_point = Vector2i(point.x, point.y + offset)
				
				# Проверяем границы
				if wider_point.y >= 0 and wider_point.y < map_height:
					landscape_layer.set_cell(wider_point, 0, Vector2i(LandscapeType.PATH, 0))
					update_walkability(wider_point.x, wider_point.y, LandscapeType.PATH, true)
					
					# Обрабатываем область вокруг расширенной дороги
					prepare_path_surroundings(wider_point.x, wider_point.y)

# Подготавливает область вокруг дороги: делает грязь и убирает препятствия
func prepare_path_surroundings(path_x: int, path_y: int):
	# Проверяем клетки вокруг дороги (радиус 1)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var x = path_x + dx
			var y = path_y + dy
			
			# Пропускаем саму дорогу и проверяем границы
			if (dx == 0 and dy == 0) or x < 0 or y < 0 or x >= map_width or y >= map_height:
				continue
				
			# Помечаем как клетку, где нельзя размещать препятствия
			mark_no_obstacles(x, y)
			
			# Получаем текущий тип тайла
			var current_cell_pos = Vector2i(x, y)
			var current_cell_atlas = landscape_layer.get_cell_atlas_coords(current_cell_pos)
			
			# Если текущий тайл не является дорогой, меняем его на грязь
			if current_cell_atlas.x != LandscapeType.PATH:
				landscape_layer.set_cell(current_cell_pos, 0, Vector2i(LandscapeType.DIRT, 0))
				update_walkability(x, y, LandscapeType.DIRT, true)

# Алгоритм Брезенхема для рисования линии между двумя точками
func bresenham_line(x0: int, y0: int, x1: int, y1: int) -> Array:
	var points = []
	
	var dx = abs(x1 - x0)
	var dy = -abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx + dy
	
	while true:
		points.append(Vector2i(x0, y0))
		
		if x0 == x1 and y0 == y1:
			break
			
		var e2 = 2 * err
		if e2 >= dy:
			if x0 == x1:
				break
			err += dy
			x0 += sx
			
		if e2 <= dx:
			if y0 == y1:
				break
			err += dx
			y0 += sy
			
	return points

# Отмечает клетку, где нельзя размещать препятствия
var no_obstacles_cells = []

func mark_no_obstacles(x: int, y: int):
	var index = y * map_width + x
	if index < walkable_tiles.size():
		# Добавляем индекс в список клеток без препятствий
		if not index in no_obstacles_cells:
			no_obstacles_cells.append(index)

func generate_obstacles():
	# Сначала генерируем поваленные деревья (они занимают 2 клетки)
	generate_fallen_trees()
	
	# Затем генерируем остальные препятствия
	for x in range(map_width):
		for y in range(map_height):
			var index = y * map_width + x
			
			# Проверяем, что на этом месте можно разместить препятствие и это не около дороги
			if not is_tile_walkable(x, y) or index in no_obstacles_cells:
				continue
				
			# Генерируем деревья с заданной плотностью
			if randf() < tree_density:
				obstacles_layer.set_cell(Vector2i(x, y), ObstacleType.TREE, Vector2i(randi() % 5, 0))
				update_walkability(x, y, ObstacleType.TREE, false)
				continue
				
			# Генерируем камни с заданной плотностью
			if randf() < rock_density:
				obstacles_layer.set_cell(Vector2i(x, y), 0, Vector2i(ObstacleType.ROCK - 10, 0))
				update_walkability(x, y, ObstacleType.ROCK, false)
				continue
			
			# Изредка добавляем забор
			if randf() < 0.01:
				obstacles_layer.set_cell(Vector2i(x, y), 0, Vector2i(ObstacleType.FENCE - 10, 0))
				update_walkability(x, y, ObstacleType.FENCE, false)

# Отдельная функция для генерации поваленных деревьев (2 тайла)
func generate_fallen_trees():
	var attempts = int(map_width * map_height * fallen_tree_density)
	
	for _i in range(attempts):
		# Выбираем случайную позицию для левого края поваленного дерева
		var x = randi() % (map_width - 1)  # -1 чтобы оставить место для правой части
		var y = randi() % map_height
		
		var left_index = y * map_width + x
		var right_index = y * map_width + (x + 1)
		
		# Проверяем, что обе клетки свободны для размещения и не около дороги
		if is_tile_walkable(x, y) and is_tile_walkable(x + 1, y) and \
		   not left_index in no_obstacles_cells and not right_index in no_obstacles_cells:
			# Размещаем левую часть
			obstacles_layer.set_cell(Vector2i(x, y), 0, Vector2i(ObstacleType.FALLEN_TREE_LEFT - 10, 0))
			update_walkability(x, y, ObstacleType.FALLEN_TREE_LEFT, false)
			
			# Размещаем правую часть
			obstacles_layer.set_cell(Vector2i(x + 1, y), 0, Vector2i(ObstacleType.FALLEN_TREE_RIGHT - 10, 0))
			update_walkability(x + 1, y, ObstacleType.FALLEN_TREE_RIGHT, false)

func update_walkability(x: int, y: int, tile_type, is_landscape: bool):
	var index = y * map_width + x
	
	# Проверка выхода за границы
	if index >= walkable_tiles.size():
		return
	
	# Если это ландшафт, обновляем напрямую
	if is_landscape:
		walkable_tiles[index] = walkability[tile_type]
	else:
		# Если это препятствие, то клетка становится непроходимой, независимо от типа ландшафта
		walkable_tiles[index] = false

func is_tile_walkable(x: int, y: int) -> bool:
	var index = y * map_width + x
	
	# Проверка выхода за границы
	if x < 0 or y < 0 or x >= map_width or y >= map_height or index >= walkable_tiles.size():
		return false
	
	return walkable_tiles[index]

# Метод для получения массива проходимости (можно использовать для навигации)
func get_walkable_map() -> Array:
	return walkable_tiles

# Метод для получения соседних проходимых клеток (полезно для навигации)
func get_walkable_neighbors(x: int, y: int) -> Array:
	var neighbors = []
	var directions = [
		Vector2i(1, 0),   # Право
		Vector2i(-1, 0),  # Лево
		Vector2i(0, 1),   # Вниз
		Vector2i(0, -1)   # Вверх
	]
	
	for dir in directions:
		var nx = x + dir.x
		var ny = y + dir.y
		
		if is_tile_walkable(nx, ny):
			neighbors.append(Vector2i(nx, ny))
	
	return neighbors
