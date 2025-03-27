class_name PathVisualizer
extends Node2D

# Ссылка на персонажа
@export var character_path: NodePath = "../Character"
# Ссылка на слой тайлмапа
@export var landscape_layer_path: NodePath = "../Landscape"

# Цвет линии пути
@export var path_color: Color = Color(0, 1, 0, 0.5)
# Цвет предварительного пути
@export var preview_color: Color = Color(0.5, 0.5, 1, 0.3)
# Цвет недоступного пути (когда не хватает AP)
@export var unavailable_color: Color = Color(1, 0, 0, 0.3)
# Размер точек пути
@export var point_size: float = 5.0

# Текстуры для точек пути
@export var path_point_texture: Texture2D
@export var preview_point_texture: Texture2D
@export var unavailable_point_texture: Texture2D

var character: Character
var landscape_layer: TileMapLayer

func _ready():
	print("PathVisualizer._ready() started")
	
	# Получаем ссылки на объекты, используя пути
	character = get_node(character_path)
	landscape_layer = get_node(landscape_layer_path)
	
	# Проверяем, что ссылки действительны
	if not character:
		push_error("Character not found at path: " + str(character_path))
	else:
		print("Character found")
	
	if not landscape_layer:
		push_error("Landscape layer not found at path: " + str(landscape_layer_path))
	else:
		print("Landscape layer found")
	
	# Если текстуры не назначены, можно использовать дефолтные
	if not path_point_texture:
		push_warning("Path point texture not assigned. Using default circle drawing.")
	if not preview_point_texture:
		preview_point_texture = path_point_texture
	if not unavailable_point_texture:
		unavailable_point_texture = path_point_texture
	
	print("PathVisualizer initialized")

func _draw():
	if not character or not landscape_layer:
		return
		
	# Рисуем текущий путь
	draw_path(character.get_current_path(), path_color, path_point_texture)
	
	# Рисуем предварительный путь при наведении мыши
	var preview_path = character.get_preview_path()
	var color = preview_color
	var texture = preview_point_texture
	
	# Если путь слишком длинный (не хватает AP), меняем цвет и текстуру
	if preview_path.size() > character.remaining_ap:
		color = unavailable_color
		texture = unavailable_point_texture
		
	draw_path(preview_path, color, texture)

# Обновленная функция для отрисовки пути с текстурами
# Обновленная функция для отрисовки пути с текстурами
# Обновленная функция для отрисовки пути с текстурами без модуляции цвета
func draw_path(path_to_draw: Array, line_color: Color, point_texture: Texture2D = null):
	if path_to_draw.size() > 0:
		var points = []
		
		# Добавляем текущую позицию персонажа как первую точку
		points.append(character.global_position)
		
		# Добавляем остальные точки из пути
		for cell in path_to_draw:
			points.append(landscape_layer.map_to_local(cell))
		
		# Рисуем линию пути
		for i in range(points.size() - 1):
			draw_line(to_local(points[i]), to_local(points[i + 1]), line_color, 2.0)
		
		# Рисуем точки на пути
		for point in points:
			if point_texture:
				# Используем текстуру вместо круга без модуляции цветом
				var texture_size = point_texture.get_size()
				var position = to_local(point) - texture_size / 2  # Центрируем текстуру
				draw_texture(point_texture, position)  # Не передаем цвет, чтобы текстура отображалась как есть
			else:
				# Если текстура не назначена, используем круг
				draw_circle(to_local(point), point_size, line_color)

func _process(_delta):
	# Обновляем отрисовку пути
	queue_redraw()
