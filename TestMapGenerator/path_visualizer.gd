class_name PathVisualizer
extends Node2D

# Ссылки на узлы
@export var character_path: NodePath = "../Character"
@export var landscape_layer_path: NodePath = "../Landscape"

# Цвета линии пути
@export var path_color: Color = Color(0, 1, 0, 0.5)
@export var preview_color: Color = Color(0.5, 0.5, 1, 0.3)
@export var selected_path_color: Color = Color(1, 1, 0, 0.5)
@export var unavailable_color: Color = Color(1, 0, 0, 0.3)

# Размер точек пути
@export var point_size: float = 5.0

# Текстуры для точек пути
@export var path_point_texture: Texture2D
@export var preview_point_texture: Texture2D
@export var selected_point_texture: Texture2D
@export var unavailable_point_texture: Texture2D

var character: Character
var landscape_layer: TileMapLayer
var move_manager = null
var available_path_steps: int = 0

func _ready():
	print("PathVisualizer._ready() started")
	
	# Получаем ссылки на объекты
	character = get_node(character_path)
	landscape_layer = get_node(landscape_layer_path)
	
	# Подписываемся на сигнал изменения пути персонажа
	character.connect("path_changed", _on_character_path_changed)
	
	# Проверяем ссылки
	if not character:
		push_error("Character not found at path: " + str(character_path))
	else:
		print("Character found")
	
	if not landscape_layer:
		push_error("Landscape layer not found at path: " + str(landscape_layer_path))
	else:
		print("Landscape layer found")
	
	# Проверка текстур
	if not path_point_texture:
		push_warning("Path point texture not assigned. Using default circle drawing.")
	if not preview_point_texture:
		preview_point_texture = path_point_texture
	if not selected_point_texture:
		selected_point_texture = path_point_texture
	if not unavailable_point_texture:
		unavailable_point_texture = path_point_texture
	
	# Ждем создания менеджера перемещений
	await get_tree().process_frame
	
	# Получаем ссылку на менеджер перемещений
	move_manager = character.move_manager
	if move_manager == null:
		push_error("PathVisualizer: Не удалось получить MoveManager!")
		return
	
	# Подписываемся на сигналы
	move_manager.connect("path_updated", _on_path_updated)
	move_manager.connect("path_split_updated", _on_path_split_updated)
	
	print("PathVisualizer initialized")

# Обработчик обновления пути
func _on_path_updated():
	queue_redraw()

# Обработчик обновления разделения пути
func _on_path_split_updated(steps: int):
	available_path_steps = steps
	queue_redraw()

func _process(_delta):
	# Обновляем отрисовку пути
	queue_redraw()

func _draw():
	if not character or not landscape_layer or not move_manager:
		return
	
	# Рисуем текущий путь (если персонаж движется)
	draw_path(character.path, path_color, path_point_texture)
	
	# Рисуем путь из менеджера
	var current_path = move_manager.get_current_path()
	if current_path.size() > 0:
		# Рисуем путь с разделением на доступную и недоступную части
		draw_split_path(current_path, available_path_steps)
		
		# Выделяем выбранную клетку
		if move_manager.selected_cell != Vector2i(-1, -1):
			var selected_cell_position = landscape_layer.map_to_local(move_manager.selected_cell)
			draw_selected_cell_highlight(selected_cell_position)

# Функция для отрисовки пути с разделением на доступную и недоступную части
# Функция для отрисовки пути с разделением на доступную и недоступную части
func draw_split_path(path_to_draw: Array, available_steps: int):
	if path_to_draw.size() == 0:
		return
	
	var available_points = []
	var unavailable_points = []
	
	# Добавляем текущую позицию персонажа
	available_points.append(character.global_position)
	
	# Добавляем точки доступной части пути
	for i in range(min(available_steps, path_to_draw.size())):
		available_points.append(landscape_layer.map_to_local(path_to_draw[i]))
	
	# Если есть недоступная часть, добавляем последнюю точку доступной части
	# как первую точку недоступной части для соединения
	if available_steps < path_to_draw.size() and available_points.size() > 0:
		unavailable_points.append(available_points[-1])
	
	# Добавляем точки недоступной части пути
	for i in range(available_steps, path_to_draw.size()):
		unavailable_points.append(landscape_layer.map_to_local(path_to_draw[i]))
	
	# ИЗМЕНЕНО: Сначала рисуем ВСЕ линии, затем ВСЕ точки
	
	# 1. Рисуем все линии доступной части пути
	for i in range(available_points.size() - 1):
		draw_line(to_local(available_points[i]), to_local(available_points[i + 1]), 
			path_color, 2.0)
	
	# 2. Рисуем все линии недоступной части пути
	for i in range(unavailable_points.size() - 1):
		draw_line(to_local(unavailable_points[i]), to_local(unavailable_points[i + 1]), 
			unavailable_color, 2.0)
	
	# 3. Рисуем все точки доступной части пути
	for i in range(1, available_points.size()):  # Начинаем с 1, чтобы пропустить точку персонажа
		if selected_point_texture:
			var texture_size = Vector2(selected_point_texture.get_size())
			var position = to_local(available_points[i]) - texture_size / 2
			draw_texture(selected_point_texture, position)
		else:
			draw_circle(to_local(available_points[i]), point_size, path_color)
	
	# 4. Рисуем все точки недоступной части пути, кроме первой (она совпадает с последней точкой доступной части)
	for i in range(1, unavailable_points.size()):
		if unavailable_point_texture:
			var texture_size = Vector2(unavailable_point_texture.get_size())
			var position = to_local(unavailable_points[i]) - texture_size / 2
			draw_texture(unavailable_point_texture, position)
		else:
			draw_circle(to_local(unavailable_points[i]), point_size, unavailable_color)

# Функция для отрисовки выделения выбранной клетки
func draw_selected_cell_highlight(position: Vector2):
	# Получаем размер клетки
	var cell_size = Vector2(landscape_layer.tile_set.tile_size)
	
	# Рисуем рамку
	var local_pos = to_local(position)
	var rect = Rect2(local_pos - cell_size/2, cell_size)
	draw_rect(rect, selected_path_color, false, 2.0)

# Функция отрисовки пути (используется для пути персонажа)
func draw_path(path_to_draw: Array, line_color: Color, point_texture: Texture2D = null):
	if path_to_draw.size() == 0:
		return
	
	var points = []
	
	# Добавляем текущую позицию персонажа
	points.append(character.global_position)
	
	# Добавляем остальные точки
	for cell in path_to_draw:
		points.append(landscape_layer.map_to_local(cell))
	
	# Рисуем линию
	for i in range(points.size() - 1):
		draw_line(to_local(points[i]), to_local(points[i + 1]), line_color, 2.0)
	
	# Рисуем точки
	for point in points:
		if point_texture:
			var texture_size = Vector2(point_texture.get_size())
			var position = to_local(point) - texture_size / 2
			draw_texture(point_texture, position)
		else:
			draw_circle(to_local(point), point_size, line_color)

func _on_character_path_changed(new_path):
	queue_redraw()  # Перерисовываем путь
