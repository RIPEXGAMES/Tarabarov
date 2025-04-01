class_name HighlightLayer
extends TileMapLayer

# Ссылки на необходимые узлы
@export var character_path: NodePath = "../Character"

# ID источника тайлов и координаты
@export var source_id: int = 0
@export var tile_coords: Vector2i = Vector2i(0, 0)

# Цвет для доступных клеток
const REACHABLE_COLOR = Color(1, 1, 1, 0.7) # Светло-зеленый (доступные клетки)

var character: Character
var move_manager = null

# Флаг для отслеживания движения
var character_is_moving: bool = false

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
	
	# Устанавливаем цвет для слоя
	self.modulate = REACHABLE_COLOR
	
	# Подписываемся на сигналы
	move_manager.connect("available_cells_updated", _on_available_cells_updated)
	
	# Подписываемся на сигналы персонажа
	character.connect("move_finished", _on_character_move_finished)
	character.connect("movement_started", _on_character_movement_start)
	
	# Инициализация отображения
	call_deferred("highlight_available_cells")

# Обработчик обновления доступных клеток
func _on_available_cells_updated():
	# Обновляем доступные клетки только если персонаж не движется
	if not character_is_moving:
		highlight_available_cells()

# Выделение доступных клеток
func highlight_available_cells():
	if not move_manager:
		return
	
	clear()
	
	# Выделяем все доступные клетки
	for cell in move_manager.available_cells:
		set_cell(cell, source_id, tile_coords)

# Обработчик начала движения персонажа
func _on_character_movement_start():
	character_is_moving = true
	# Временно скрываем подсветку доступных клеток
	clear()

# Обработчик завершения движения персонажа
func _on_character_move_finished():
	character_is_moving = false
	# Обновляем подсветку после завершения движения
	highlight_available_cells()
