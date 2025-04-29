class_name HighlightLayer
extends TileMapLayer

#region Экспортируемые параметры
# Ссылки на необходимые узлы
@export var character_path: NodePath = "../Character"

# Настройки тайлов
@export var source_id: int = 0
@export var tile_coords: Vector2i = Vector2i(0, 0)
#endregion

#region Константы и переменные
# Цвета для разных режимов
const REACHABLE_COLOR = Color(1, 1, 1, 0.7)

# Ссылки на объекты
var character: Character
var move_manager = null

# Состояние
var character_is_moving: bool = false
var is_attack_mode: bool = false
#endregion

func _ready():
	# Получаем ссылку на персонажа
	character = get_node_or_null(character_path)
	if not character:
		push_error("HighlightLayer: Не удалось найти ноду Character!")
		return
	
	# Ждем создания менеджера перемещений
	await get_tree().process_frame
	
	# Получаем ссылку на менеджер перемещений
	move_manager = character.move_manager
	if not move_manager:
		push_error("HighlightLayer: Не удалось получить MoveManager!")
		return
	
	# Устанавливаем цвет для слоя
	self.modulate = REACHABLE_COLOR
	
	# Подключаем сигналы
	connect_signals()
	
	# Инициализация отображения
	call_deferred("highlight_available_cells")

#region Подключение сигналов
func connect_signals():
	# Сигналы менеджера перемещений
	move_manager.connect("available_cells_updated", _on_available_cells_updated)
	
	# Сигналы персонажа
	character.connect("move_finished", _on_character_move_finished)
	character.connect("movement_started", _on_character_movement_start)
	
	# Сигналы для атаки
	if character.has_signal("field_of_view_changed"):
		character.connect("field_of_view_changed", _on_field_of_view_changed)
	if character.has_signal("attack_executed"):
		character.connect("attack_executed", _on_attack_executed)
#endregion

#region Обработчики сигналов
func _on_available_cells_updated():
	if not character_is_moving and not is_attack_mode:
		highlight_available_cells()

func _on_character_movement_start():
	character_is_moving = true
	clear()

func _on_character_move_finished():
	character_is_moving = false
	if not is_attack_mode:
		highlight_available_cells()

func _on_field_of_view_changed(visible_cells: Array, _hit_chances: Dictionary):
	# Когда поле зрения меняется, переключаемся в режим атаки если есть видимые клетки
	is_attack_mode = visible_cells.size() > 0
	
	if is_attack_mode:
		clear()
	else:
		highlight_available_cells()

func _on_attack_executed(_target_cell):
	is_attack_mode = false
	highlight_available_cells()
#endregion

#region Методы подсветки
func highlight_available_cells():
	if not move_manager or is_attack_mode:
		return
	
	clear()
	self.modulate = REACHABLE_COLOR
	
	for cell in move_manager.available_cells:
		set_cell(cell, source_id, tile_coords)
#endregion
