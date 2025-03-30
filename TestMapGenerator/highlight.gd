class_name HighlightLayer
extends TileMapLayer

# Ссылки на необходимые узлы
@export var character_path: NodePath = "../Character"

# ID источника тайлов и координаты
@export var source_id: int = 0
@export var tile_coords: Vector2i = Vector2i(0, 0)

# Цвета для разных состояний
const REACHABLE_COLOR = Color(0.5, 0.8, 0.2, 0.4) # Светло-зеленый (доступные клетки)
const HOVER_COLOR = Color(0, 1, 1, 0.7)           # Бирюзовый (клетка под курсором)

# Текущая позиция выделения
var current_highlight_pos: Vector2i = Vector2i(-1, -1)
var character: Character
var move_manager = null

func _ready():
	# Получаем ссылку на персонажа
	character = get_node(character_path)
	if character == null:
		push_error("HighlightLayer: Не удалось найти ноду Character!")
		return
	
	# Ждем создания менеджера перемещений
	await get_tree().process_frame
	
	# Получаем ссылку на менеджер перемещений
	move_manager = character.move_manager
	if move_manager == null:
		push_error("HighlightLayer: Не удалось получить MoveManager!")
		return
	
	# Подписываемся на сигналы
	move_manager.connect("available_cells_updated", _on_available_cells_updated)
	
	# Инициализация отображения
	call_deferred("highlight_available_cells")

func _process(_delta):
	if not move_manager:
		return
	
	# Преобразуем позицию мыши в координаты карты
	var mouse_pos = get_global_mouse_position()
	var tile_pos = local_to_map(to_local(mouse_pos))
	
	# Проверяем, изменилась ли позиция мыши
	if tile_pos != current_highlight_pos:
		# Сохраняем предыдущие выделения
		var saved_cells = get_used_cells()
		
		# Очищаем выделение
		clear()
		
		# Восстанавливаем выделение доступных клеток
		highlight_available_cells()
		
		# Проверяем границы карты
		if is_valid_map_position(tile_pos):
			# Обновляем текущую позицию выделения
			current_highlight_pos = tile_pos
			
			# Размещаем тайл выделения и устанавливаем цвет
			set_cell(tile_pos, source_id, tile_coords)
			self.modulate = HOVER_COLOR

# Проверка валидности позиции
func is_valid_map_position(pos: Vector2i) -> bool:
	if not move_manager or not move_manager.map_generator:
		return false
	
	return (pos.x >= 0 and pos.x < move_manager.map_generator.map_width and 
			pos.y >= 0 and pos.y < move_manager.map_generator.map_height)

# Обработчик обновления доступных клеток
func _on_available_cells_updated():
	highlight_available_cells()

# Выделение доступных клеток
func highlight_available_cells():
	if not move_manager:
		return
	
	clear()
	self.modulate = REACHABLE_COLOR
	
	# Выделяем все доступные клетки
	for cell in move_manager.available_cells:
		set_cell(cell, source_id, tile_coords)
	
