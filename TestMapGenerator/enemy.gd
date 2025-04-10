class_name Enemy
extends Node2D

# Настройки отладки
@export var debug_mode: bool = true

# Минимальное расстояние от игрока для спавна
@export var min_distance_from_player: int = 5

# Текущая позиция на карте
var current_cell: Vector2i = Vector2i.ZERO

# Ссылки на узлы
@onready var map_generator: MapGenerator = get_node("../MapGenerator")
@onready var landscape_layer: TileMapLayer = get_node("../Landscape")
@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	debug_print("Enemy._ready() started")
	
	# Проверка необходимых узлов
	validate_dependencies()
	
	# Устанавливаем видимость
	visible = true
	if sprite:
		sprite.visible = true
	
	# Размещаем врага только если он еще не размещен
	# Это позволит MapGenerator управлять расположением
	if current_cell == Vector2i.ZERO:
		place_at_valid_position()
	else:
		debug_print("Using pre-assigned position: " + str(current_cell) + 
			" world pos: " + str(global_position))
	
	debug_print("Enemy._ready() completed")

# Проверка зависимостей
func validate_dependencies():
	if not map_generator:
		push_error("MapGenerator not found!")
	else:
		debug_print("MapGenerator found")
	
	if not landscape_layer:
		push_error("Landscape layer not found!")
	else:
		debug_print("Landscape layer found")
	
	if not sprite:
		push_error("Sprite2D not found!")
	else:
		debug_print("Sprite2D found")

# Размещение на валидной позиции
func place_at_valid_position():
	debug_print("Finding valid position for enemy...")
	
	# Получаем позицию игрока
	var player = get_node("../Character")
	var player_pos = Vector2i.ZERO
	if player:
		player_pos = player.current_cell
		debug_print("Player position: " + str(player_pos))
	
	# Ищем подходящую позицию вдали от игрока
	var max_attempts = 100  # Предотвращаем бесконечный цикл
	var attempts = 0
	
	while attempts < max_attempts:
		# Выбираем случайную позицию на карте
		var x = randi() % map_generator.map_width
		var y = randi() % map_generator.map_height
		var pos = Vector2i(x, y)
		
		# Проверяем, что позиция проходима и достаточно далеко от игрока
		if map_generator.is_tile_walkable(x, y) and pos.distance_to(player_pos) >= min_distance_from_player:
			current_cell = pos
			global_position = landscape_layer.map_to_local(current_cell)
			debug_print("Enemy placed at cell: " + str(current_cell) + 
				" world pos: " + str(global_position))
			return
		
		attempts += 1
	
	# Запасной вариант: найти любую проходимую клетку
	debug_print("Could not find position far from player, using any walkable cell")
	for x in range(map_generator.map_width):
		for y in range(map_generator.map_height):
			if map_generator.is_tile_walkable(x, y) and Vector2i(x, y) != player_pos:
				current_cell = Vector2i(x, y)
				global_position = landscape_layer.map_to_local(current_cell)
				debug_print("Enemy placed at cell: " + str(current_cell) + 
					" world pos: " + str(global_position))
				return
	
	push_error("Could not find any valid position for enemy!")

# Обработка хода противника (пока ничего не делает)
func process_turn():
	debug_print("Enemy turn processed (currently doing nothing)")

# Функция для отладочного вывода
func debug_print(message: String):
	if debug_mode:
		print("Enemy: " + message)

# Метод для принудительной установки позиции противника
func force_position(pos: Vector2i):
	debug_print("Forcing enemy position to: " + str(pos))
	current_cell = pos
	
	# Устанавливаем мировую позицию
	if landscape_layer:
		global_position = landscape_layer.map_to_local(current_cell)
		debug_print("Set world position: " + str(global_position))
	else:
		debug_print("Warning: landscape_layer not found when forcing position")
		
	# Устанавливаем видимость, чтобы убедиться, что противник виден
	visible = true
	
	# Если есть спрайт, убедимся, что он тоже видимый
	if sprite:
		sprite.visible = true
		debug_print("Sprite visibility set to true")
