class_name MapGenerator
extends Node

#region Экспортируемые настройки
# Сцены и спавн противников
@export var enemy_scene: PackedScene
@export var min_distance_between_enemies: int = 4
@export var min_distance_from_player: int = 5

# Размеры и плотность карты
@export var map_width: int = 25
@export var map_height: int = 25
@export var tree_density: float = 0.1
@export var rock_density: float = 0.01
@export var fallen_tree_density: float = 0.03
@export var water_chance: float = 0.1
@export var path_chance: float = 0.3
#endregion

#region Константы и перечисления
enum LandscapeType {
	GRASS = 0,
	DIRT = 1,
	WATER = 2,
	PATH = 3
}

enum ObstacleType {
	TREE = 10,
	ROCK = 11,
	FALLEN_TREE_LEFT = 12,
	FALLEN_TREE_RIGHT = 13,
	FENCE = 14
}
#endregion

#region Внутренние переменные
# Ссылки на слои
@onready var landscape_layer: TileMapLayer = $"../Landscape"
@onready var obstacles_layer: TileMapLayer = $"../Obstacles"

# Массивы для хранения данных о тайлах
var walkable_tiles: Array = []
var vision_blocking_tiles: Array = []
var no_obstacles_cells: Array = []
var spawned_enemies: Array = []

# Словари свойств тайлов
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

var visibility_blocking = {
	LandscapeType.GRASS: false,
	LandscapeType.DIRT: false,
	LandscapeType.WATER: false,
	LandscapeType.PATH: false,
	ObstacleType.TREE: true,
	ObstacleType.ROCK: true,
	ObstacleType.FALLEN_TREE_LEFT: false,
	ObstacleType.FALLEN_TREE_RIGHT: false,
	ObstacleType.FENCE: true
}
#endregion

#region Инициализация
func _ready():
	# Инициализация массивов
	walkable_tiles.resize(map_width * map_height)
	walkable_tiles.fill(true)
	
	vision_blocking_tiles.resize(map_width * map_height)
	vision_blocking_tiles.fill(false)
	
	no_obstacles_cells = []
	
	# Генерируем карту
	generate_map()
#endregion

#region Генерация карты
func generate_map():
	# Очищаем тайлмапы
	landscape_layer.clear()
	obstacles_layer.clear()
	no_obstacles_cells.clear()
	
	# Генерация карты поэтапно
	generate_base_landscape()
	generate_water_bodies()
	generate_paths()
	generate_obstacles()
	
	# Генерация противников
	call_deferred("generate_enemies", 3)
	
	print("Карта успешно сгенерирована!")
#endregion

#region Генерация ландшафта
func generate_base_landscape():
	for x in range(map_width):
		for y in range(map_height):
			# Основной тип - трава, иногда - грязь
			var tile_type = LandscapeType.GRASS
			if randf() < 0.1:
				tile_type = LandscapeType.DIRT
			
			landscape_layer.set_cell(Vector2i(x, y), tile_type, Vector2i(randi() % 10, 0))
			update_walkability(x, y, tile_type, true)

func generate_water_bodies():
	if randf() < water_chance:
		var noise = FastNoiseLite.new()
		noise.seed = randi()
		noise.frequency = 0.07
		
		for x in range(map_width):
			for y in range(map_height):
				var noise_val = noise.get_noise_2d(x, y)
				if noise_val > 0.3:
					landscape_layer.set_cell(Vector2i(x, y), 10, Vector2i(LandscapeType.WATER, 0))
					update_walkability(x, y, LandscapeType.WATER, true)

func generate_paths():
	if randf() < path_chance:
		# Начальная и конечная точки на краях карты
		var start_x = 0
		var end_x = map_width - 1
		var start_y = randi() % map_height
		var end_y = randi() % map_height
		
		# Генерируем путь
		var path_points = bresenham_line(start_x, start_y, end_x, end_y)
		
		for point in path_points:
			# Основная тропинка
			landscape_layer.set_cell(point, 10, Vector2i(LandscapeType.PATH, 0))
			update_walkability(point.x, point.y, LandscapeType.PATH, true)
			prepare_path_surroundings(point.x, point.y)
			
			# Вариации ширины дороги
			if randf() < 0.3:
				var offset = 1 if randf() < 0.5 else -1
				var wider_point = Vector2i(point.x, point.y + offset)
				
				if wider_point.y >= 0 and wider_point.y < map_height:
					landscape_layer.set_cell(wider_point, 10, Vector2i(LandscapeType.PATH, 0))
					update_walkability(wider_point.x, wider_point.y, LandscapeType.PATH, true)
					prepare_path_surroundings(wider_point.x, wider_point.y)

func prepare_path_surroundings(path_x: int, path_y: int):
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var x = path_x + dx
			var y = path_y + dy
			
			# Пропускаем саму дорогу и проверяем границы
			if (dx == 0 and dy == 0) or x < 0 or y < 0 or x >= map_width or y >= map_height:
				continue
				
			# Помечаем как клетку без препятствий
			mark_no_obstacles(x, y)
			
			# Получаем текущий тип тайла
			var current_cell_pos = Vector2i(x, y)
			var current_cell_atlas = landscape_layer.get_cell_atlas_coords(current_cell_pos)
			
			# Если не дорога, меняем на грязь
			if current_cell_atlas.x != LandscapeType.PATH:
				landscape_layer.set_cell(current_cell_pos, LandscapeType.DIRT, Vector2i(randi() % 10, 0))
				update_walkability(x, y, LandscapeType.DIRT, true)
#endregion

#region Генерация объектов
func generate_obstacles():
	# Сначала поваленные деревья (занимают 2 клетки)
	generate_fallen_trees()
	
	# Затем остальные препятствия
	for x in range(map_width):
		for y in range(map_height):
			var index = y * map_width + x
			
			# Проверяем возможность размещения
			if not is_tile_walkable(x, y) or index in no_obstacles_cells:
				continue
				
			# Генерируем препятствия по вероятности
			if randf() < tree_density:
				obstacles_layer.set_cell(Vector2i(x, y), ObstacleType.TREE, Vector2i(randi() % 5, 0))
				update_walkability(x, y, ObstacleType.TREE, false)
				continue
				
			if randf() < rock_density:
				obstacles_layer.set_cell(Vector2i(x, y), ObstacleType.ROCK, Vector2i(randi() % 5, 0))
				update_walkability(x, y, ObstacleType.ROCK, false)
				continue
			
			if randf() < 0.01:
				obstacles_layer.set_cell(Vector2i(x, y), 0, Vector2i(ObstacleType.FENCE - 10, 0))
				update_walkability(x, y, ObstacleType.FENCE, false)

func generate_fallen_trees():
	var attempts = int(map_width * map_height * fallen_tree_density)
	
	for _i in range(attempts):
		# Выбираем позицию для левого края поваленного дерева
		var x = randi() % (map_width - 1)
		var y = randi() % map_height
		
		var left_index = y * map_width + x
		var right_index = y * map_width + (x + 1)
		
		# Проверяем доступность обеих клеток
		if is_tile_walkable(x, y) and is_tile_walkable(x + 1, y) and \
		   not left_index in no_obstacles_cells and not right_index in no_obstacles_cells:
			var ran_index = randi() % 3
			
			# Размещаем обе части поваленного дерева
			obstacles_layer.set_cell(Vector2i(x, y), ObstacleType.FALLEN_TREE_LEFT, Vector2i(ran_index * 2, 0))
			update_walkability(x, y, ObstacleType.FALLEN_TREE_LEFT, false)
			
			obstacles_layer.set_cell(Vector2i(x + 1, y), ObstacleType.FALLEN_TREE_LEFT, Vector2i(ran_index * 2 + 1, 0))
			update_walkability(x + 1, y, ObstacleType.FALLEN_TREE_RIGHT, false)
#endregion

#region Спавн противников
func generate_enemies(count: int) -> Array:
	print("Генерация противников: " + str(count))
	
	# Очищаем существующих противников
	for enemy in spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	spawned_enemies.clear()
	
	# Находим игрока
	var player = get_node("../Character")
	if not player:
		push_error("Player character not found when spawning enemies!")
		return []
	
	var player_pos = player.current_cell
	
	# Создаём заданное количество противников
	for i in range(count):
		await get_tree().process_frame
		var enemy_instance = await create_enemy_at_position(player_pos)
		if enemy_instance:
			spawned_enemies.append(enemy_instance)
	
	print("Успешно создано противников: " + str(spawned_enemies.size()))
	return spawned_enemies

func create_enemy_at_position(player_pos: Vector2i) -> Enemy:
	if not enemy_scene:
		push_error("Enemy scene is not assigned!")
		return null
	
	# Поиск подходящей позиции
	var max_attempts = 100
	var attempts = 0
	var valid_position = null
	
	while attempts < max_attempts:
		var x = randi() % map_width
		var y = randi() % map_height
		var pos = Vector2i(x, y)
		
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
	
	if not valid_position:
		return null
	
	# Создание и размещение противника
	var enemy_instance = enemy_scene.instantiate() as Enemy
	get_parent().add_child(enemy_instance)
	
	await get_tree().process_frame
	
	if enemy_instance.has_method("force_position"):
		enemy_instance.force_position(valid_position)
		enemy_instance.visible = true
	
	return enemy_instance
#endregion

#region Вспомогательные методы
func update_walkability(x: int, y: int, tile_type, is_landscape: bool):
	var index = y * map_width + x
	
	if index >= walkable_tiles.size():
		return
	
	if is_landscape:
		walkable_tiles[index] = walkability[tile_type]
		vision_blocking_tiles[index] = visibility_blocking[tile_type]
	else:
		walkable_tiles[index] = false
		vision_blocking_tiles[index] = visibility_blocking[tile_type]

func is_tile_walkable(x: int, y: int) -> bool:
	var index = y * map_width + x
	
	if x < 0 or y < 0 or x >= map_width or y >= map_height or index >= walkable_tiles.size():
		return false
	
	return walkable_tiles[index]

func is_tile_blocking_vision(x: int, y: int) -> bool:
	var index = y * map_width + x
	
	if x < 0 or y < 0 or x >= map_width or y >= map_height or index >= vision_blocking_tiles.size():
		return true
	
	return vision_blocking_tiles[index]

func mark_no_obstacles(x: int, y: int):
	var index = y * map_width + x
	if index < walkable_tiles.size() and not index in no_obstacles_cells:
		no_obstacles_cells.append(index)

func get_walkable_map() -> Array:
	return walkable_tiles

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
#endregion
