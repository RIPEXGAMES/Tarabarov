class_name MapGenerator
extends Node

# Добавляем предзагрузку сцены противника
@export var enemy_scene: PackedScene # Ссылка на сцену противника через инспектор

# Добавляем настройки для спавна противников
@export var min_distance_between_enemies: int = 4
@export var min_distance_from_player: int = 5

# Массив созданных противников
var spawned_enemies: Array = []

# Настройки генерации карты
@export var map_width: int = 25
@export var map_height: int = 25
@export var tree_density: float = 0.1  # Плотность деревьев (0-1)
@export var rock_density: float = 0.01  # Плотность камней (0-1)
@export var fallen_tree_density: float = 0.03  # Плотность поваленных деревьев
@export var water_chance: float = 0.1   # Шанс генерации водоемов
@export var path_chance: float = 0.3    # Шанс генерации дорог/тропинок

# Ссылки на слои тайлмапа
@onready var landscape_layer: TileMapLayer = $"../Landscape"
@onready var obstacles_layer: TileMapLayer = $"../Obstacles"

# Добавьте этот словарь после словаря walkability
var visibility_blocking = {
	LandscapeType.GRASS: false,
	LandscapeType.DIRT: false,
	LandscapeType.WATER: false, # Вода не блокирует видимость
	LandscapeType.PATH: false,
	ObstacleType.TREE: true,    # Деревья блокируют видимость
	ObstacleType.ROCK: true,    # Камни блокируют видимость
	ObstacleType.FALLEN_TREE_LEFT: false,  # Поваленные деревья не блокируют видимость
	ObstacleType.FALLEN_TREE_RIGHT: false, # Поваленные деревья не блокируют видимость
	ObstacleType.FENCE: true    # Забор блокирует видимость
}

# Добавьте массив для хранения информации о блокировке видимости
var vision_blocking_tiles = []

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
	
	# Добавьте инициализацию массива блокировки видимости
	vision_blocking_tiles.resize(map_width * map_height)
	vision_blocking_tiles.fill(false)
	
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
	
	# 5. Генерация противников (например, 3 противника)
	# Теперь используем call_deferred, чтобы выполнить это позже
	# когда все другие узлы уже будут настроены
	call_deferred("generate_enemies_deferred", 3)
	
	
	print("Карта успешно сгенерирована!")

# Отложенная генерация противников
func generate_enemies_deferred(count):
	# Ждем один кадр, чтобы убедиться что Character инициализирован
	await get_tree().process_frame
	generate_enemies(count)

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
			landscape_layer.set_cell(Vector2i(x, y), tile_type, Vector2i(randi() % 10, 0))
			
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
					landscape_layer.set_cell(Vector2i(x, y), 10, Vector2i(LandscapeType.WATER, 0))
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
			landscape_layer.set_cell(point, 10, Vector2i(LandscapeType.PATH, 0))
			update_walkability(point.x, point.y, LandscapeType.PATH, true)
			
			# Обрабатываем область вокруг дороги
			prepare_path_surroundings(point.x, point.y)
			
			# Иногда делаем тропинку шире
			if randf() < 0.3:
				var offset = 1 if randf() < 0.5 else -1
				var wider_point = Vector2i(point.x, point.y + offset)
				
				# Проверяем границы
				if wider_point.y >= 0 and wider_point.y < map_height:
					landscape_layer.set_cell(wider_point, 10, Vector2i(LandscapeType.PATH, 0))
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
				landscape_layer.set_cell(current_cell_pos, LandscapeType.DIRT, Vector2i(randi() % 10, 0))
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
				obstacles_layer.set_cell(Vector2i(x, y), ObstacleType.ROCK, Vector2i(randi() % 5, 0))
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
			var ran_index = randi() % 3
			# Размещаем левую часть
			obstacles_layer.set_cell(Vector2i(x, y), ObstacleType.FALLEN_TREE_LEFT, Vector2i(ran_index * 2, 0))
			update_walkability(x, y, ObstacleType.FALLEN_TREE_LEFT, false)
			
			# Размещаем правую часть
			obstacles_layer.set_cell(Vector2i(x + 1, y), ObstacleType.FALLEN_TREE_LEFT, Vector2i(ran_index * 2 + 1, 0))
			update_walkability(x + 1, y, ObstacleType.FALLEN_TREE_RIGHT, false)


func update_walkability(x: int, y: int, tile_type, is_landscape: bool):
	var index = y * map_width + x
	
	# Проверка выхода за границы
	if index >= walkable_tiles.size():
		return
	
	# Если это ландшафт, обновляем напрямую
	if is_landscape:
		walkable_tiles[index] = walkability[tile_type]
		vision_blocking_tiles[index] = visibility_blocking[tile_type]
	else:
		# Если это препятствие, обновляем оба массива
		walkable_tiles[index] = false
		vision_blocking_tiles[index] = visibility_blocking[tile_type]

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

# Новая функция для генерации противников

# Новая функция для генерации противников
func generate_enemies(count: int) -> Array:
	print("Generating " + str(count) + " enemies...")
	
	# Очищаем список противников, если они уже существуют
	for enemy in spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	spawned_enemies.clear()
	
	# Находим игрока для проверки дистанции
	var player = get_node("../Character")
	if not player:
		push_error("Player character not found when spawning enemies!")
		return []
	
	var player_pos = player.current_cell
	
	# Создаём заданное количество противников
	for i in range(count):
		# ИСПРАВЛЕНО: Теперь правильно используем await
		var enemy_instance = await create_enemy_at_position(player_pos)
		if enemy_instance:
			spawned_enemies.append(enemy_instance)
	
	print("Successfully spawned " + str(spawned_enemies.size()) + " enemies")
	return spawned_enemies

# ИСПРАВЛЕНО: Переименованный метод для лучшей читаемости
func create_enemy_at_position(player_pos: Vector2i) -> Enemy:
	# Проверяем, загружена ли сцена противника
	if not enemy_scene:
		push_error("Enemy scene is not assigned!")
		return null
	
	# Пытаемся найти подходящую позицию
	var max_attempts = 100
	var attempts = 0
	var valid_position = null
	
	# Сначала находим валидную позицию
	while attempts < max_attempts:
		# Выбираем случайную позицию
		var x = randi() % map_width
		var y = randi() % map_height
		var pos = Vector2i(x, y)
		
		# Проверяем условия размещения
		if is_tile_walkable(x, y) and pos.distance_to(player_pos) >= min_distance_from_player:
			var too_close_to_other_enemy = false
			
			for enemy in spawned_enemies:
				if pos.distance_to(enemy.current_cell) < min_distance_between_enemies:
					too_close_to_other_enemy = true
					break
			
			if not too_close_to_other_enemy:
				valid_position = pos
				break
		
		attempts += 1
	
	# Если мы не смогли найти позицию, выходим
	if not valid_position:
		print("Failed to find valid position for enemy after " + str(max_attempts) + " attempts")
		return null
	
	# Создаем экземпляр противника
	var enemy_instance = enemy_scene.instantiate() as Enemy
	get_parent().add_child(enemy_instance)
	
	# Даем время для обработки _ready
	await get_tree().process_frame
	
	# Устанавливаем позицию
	if enemy_instance.has_method("force_position"):
		enemy_instance.force_position(valid_position)
		print("Enemy spawned at cell: " + str(valid_position))
		
		# Еще раз убеждаемся, что противник виден
		enemy_instance.visible = true
		if enemy_instance.sprite:
			enemy_instance.sprite.visible = true
	
	return enemy_instance


# Проверяет, блокирует ли клетка линию видимости
func is_tile_blocking_vision(x: int, y: int) -> bool:
	var index = y * map_width + x
	
	# Проверка выхода за границы
	if x < 0 or y < 0 or x >= map_width or y >= map_height or index >= vision_blocking_tiles.size():
		return true  # За границами всегда считаем, что видимость блокируется
	
	return vision_blocking_tiles[index]
