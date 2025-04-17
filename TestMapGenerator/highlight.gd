class_name HighlightLayer
extends TileMapLayer

# Ссылки на необходимые узлы
@export var character_path: NodePath = "../Character"

# ID источника тайлов и координаты
@export var source_id: int = 0
@export var tile_coords: Vector2i = Vector2i(0, 0)
@export var attack_tile_coords: Vector2i = Vector2i(1, 0)  # Координаты тайла для атаки

# Цвет для доступных клеток
const REACHABLE_COLOR = Color(1, 1, 1, 0.7)
const ATTACK_COLOR = Color(1, 0.3, 0.3, 0.7)  # Красноватый цвет для режима атаки

var character: Character
var move_manager = null

# Флаг для отслеживания движения
var character_is_moving: bool = false

var is_attack_mode: bool = false
var attack_cells: Array = []

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
	
	 # Добавьте новые подписки
	if character.has_signal("attack_range_changed"):
		character.connect("attack_range_changed", _on_attack_range_changed)
	if character.has_signal("attack_executed"):
		character.connect("attack_executed", _on_attack_executed)
	
	# Инициализация отображения
	call_deferred("highlight_available_cells")

# Обработчик обновления доступных клеток
# Обработчик изменения доступных целей для атаки
func _on_attack_range_changed(cells: Array):
	attack_cells = cells
	is_attack_mode = cells.size() > 0
	
	if is_attack_mode:
		# Если в режиме атаки, используем атакующую подсветку
		highlight_attack_cells()
	else:
		# Если вышли из режима атаки, возвращаемся к обычной подсветке перемещения
		highlight_available_cells()

# Обработчик выполненной атаки
func _on_attack_executed(_target_cell):
	# После атаки выключаем режим атаки и возвращаемся к обычной подсветке
	is_attack_mode = false
	highlight_available_cells()

# Обновите метод _on_available_cells_updated
func _on_available_cells_updated():
	# Обновляем доступные клетки только если персонаж не движется и не в режиме атаки
	if not character_is_moving and not is_attack_mode:
		highlight_available_cells()

# Обновите метод highlight_available_cells
func highlight_available_cells():
	if not move_manager or is_attack_mode:
		return
	
	clear()
	
	# Устанавливаем цвет для перемещения
	self.modulate = REACHABLE_COLOR
	
	# Выделяем все доступные клетки
	for cell in move_manager.available_cells:
		set_cell(cell, source_id, tile_coords)

# Выделение доступных клеток для атаки
func highlight_attack_cells():
	if attack_cells.size() == 0:
		return
		
	clear()
	
	# Отладка
	print("Highlighting attack cells: ", attack_cells.size(), " cells")
	print("Using attack color: ", ATTACK_COLOR)
	
	# Устанавливаем цвет для атаки
	self.modulate = ATTACK_COLOR
	
	# Выделяем все клетки для атаки - используем тот же тайл, но другой цвет
	for cell in attack_cells:
		# Используем те же координаты тайла, что и для движения
		set_cell(cell, source_id, tile_coords)
		print("Set attack cell at: ", cell)

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
