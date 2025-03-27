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
	
	print("PathVisualizer initialized")

func _draw():
	if not character or not landscape_layer:
		return
		
	# Рисуем текущий путь
	draw_path(character.get_current_path(), path_color)
	
	# Рисуем предварительный путь при наведении мыши
	var preview_path = character.get_preview_path()
	var color = preview_color
	
	# Если путь слишком длинный (не хватает AP), меняем цвет
	if preview_path.size() > character.remaining_ap:
		color = unavailable_color
		
	draw_path(preview_path, color)

# Вспомогательная функция для отрисовки пути
func draw_path(path_to_draw: Array, color: Color):
	if path_to_draw.size() > 0:
		var points = []
		
		# Добавляем текущую позицию персонажа как первую точку
		points.append(character.global_position)
		
		# Добавляем остальные точки из пути
		for cell in path_to_draw:
			points.append(landscape_layer.map_to_local(cell))
		
		# Рисуем линию пути
		for i in range(points.size() - 1):
			draw_line(to_local(points[i]), to_local(points[i + 1]), color, 2.0)
		
		# Рисуем точки на пути
		for point in points:
			draw_circle(to_local(point), point_size, color)

func _process(_delta):
	# Обновляем отрисовку пути
	queue_redraw()
