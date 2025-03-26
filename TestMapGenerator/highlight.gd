class_name HighlightLayer
extends TileMapLayer

# Ссылка на MapGenerator
@export var map_generator: MapGenerator

# ID источника тайлов и координаты
@export var source_id: int = 0
@export var tile_coords: Vector2i = Vector2i(0, 0)

# Цвета для разных состояний
const WALKABLE_COLOR = Color(0, 1, 0, 0.7)      # Зеленый
const NON_WALKABLE_COLOR = Color(1, 0, 0, 0.7)  # Красный

# Текущая позиция выделения
var current_highlight_pos: Vector2i = Vector2i(-1, -1)

func _ready():
	# Убедимся, что у нас есть ссылка на MapGenerator
	if map_generator == null:
		map_generator = get_node("../MapGenerator")
		if map_generator == null:
			push_error("HighlightLayer: Не удалось найти ноду MapGenerator!")

func _process(_delta):
	# Преобразуем позицию мыши в координаты карты
	var mouse_pos = get_global_mouse_position()
	var tile_pos = local_to_map(to_local(mouse_pos))
	
	# Проверяем, изменилась ли позиция мыши
	if tile_pos != current_highlight_pos:
		# Очищаем предыдущее выделение
		clear()
		
		# Проверяем, что позиция тайла находится в пределах карты
		if tile_pos.x >= 0 and tile_pos.x < map_generator.map_width and \
		   tile_pos.y >= 0 and tile_pos.y < map_generator.map_height:
			
			# Обновляем текущую позицию выделения
			current_highlight_pos = tile_pos
			
			# Проверяем, проходима ли клетка
			var is_walkable = map_generator.is_tile_walkable(tile_pos.x, tile_pos.y)
			
			# Размещаем тайл выделения
			set_cell(tile_pos, source_id, tile_coords)
			
			# Устанавливаем цвет в зависимости от проходимости
			self.modulate = WALKABLE_COLOR if is_walkable else NON_WALKABLE_COLOR

# Метод для ручного выделения конкретного тайла
func highlight_tile(x: int, y: int, force_highlight: bool = false):
	var pos = Vector2i(x, y)
	
	# Проверяем, что позиция находится в пределах карты
	if x >= 0 and x < map_generator.map_width and y >= 0 and y < map_generator.map_height:
		var is_walkable = map_generator.is_tile_walkable(x, y)
		
		# Применяем выделение
		set_cell(pos, source_id, tile_coords)
		
		# Устанавливаем цвет в зависимости от проходимости
		self.modulate = WALKABLE_COLOR if is_walkable else NON_WALKABLE_COLOR
		
		# Обновляем текущую позицию только если не принудительное выделение
		if !force_highlight:
			current_highlight_pos = pos

# Очистить все выделения
func clear_highlights():
	clear()
	current_highlight_pos = Vector2i(-1, -1)
