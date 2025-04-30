class_name DirectionIndicator
extends Node2D

# Ссылки на узлы
@export var character_path: NodePath = ".."
@onready var character: Character = get_node_or_null(character_path)

# Настройки визуализации
@export var triangle_size: float = 10.0  # Размер треугольника
@export var distance_from_center: float = 24.0  # Расстояние от центра персонажа
@export var indicator_color: Color = Color(0.2, 0.8, 1.0, 0.9)  # Голубой цвет
@export var outline_width: float = 1.5  # Ширина контура треугольника
@export var outline_color: Color = Color(0.1, 0.1, 0.1, 0.8)  # Цвет контура

# Настройки анимации
@export var transition_speed: float = 5.0  # Скорость перехода (выше = быстрее)
@export_range(0.0, 1.0) var smoothing: float = 0.9  # Плавность перехода

# Внутренние переменные
var current_direction: Vector2 = Vector2.RIGHT  # Текущее визуальное направление
var target_direction: Vector2 = Vector2.RIGHT  # Целевое направление
var highlight_time: float = 0.0
var animation_active: bool = false
var tween: Tween

func _ready():
	# Автоматическое получение ссылки на персонажа, если не указана
	if not character:
		var parent = get_parent()
		if parent is Character:
			character = parent
			print("DirectionIndicator: Автоматически найден Character в родительском узле")
		else:
			push_error("DirectionIndicator: Character not found! Please set character_path.")
			return
	
	# Подключаем сигналы
	if character:
		character.connect("direction_changed", _on_direction_changed)
		# Инициализация с текущим направлением персонажа
		current_direction = character.facing_direction
		target_direction = character.facing_direction

func _process(delta):
	# Обработка анимации перехода
	if current_direction != target_direction:
		animation_active = true
		
		# Используем slerp для плавного перехода по дуге
		current_direction = current_direction.slerp(target_direction, delta * transition_speed)
		
		# Если направления уже близки друг к другу, выравниваем их
		if current_direction.distance_to(target_direction) < 0.01:
			current_direction = target_direction
			animation_active = false
			
		queue_redraw()
	
	# Уменьшаем время подсветки
	if highlight_time > 0:
		highlight_time -= delta
		queue_redraw()

func _on_direction_changed(_direction_index):
	# Обновляем целевое направление и запускаем анимацию
	if character:
		target_direction = character.facing_direction
		highlight_time = 0.5
		
		# Если нужно мгновенно обновить положение (например, при первой установке)
		if current_direction.length() == 0:
			current_direction = target_direction

func _draw():
	if not character:
		return
	
	# Используем текущее анимированное направление для отрисовки
	var facing_dir = current_direction.normalized()
	
	# Рассчитываем позицию треугольника относительно персонажа
	var triangle_position = facing_dir * distance_from_center
	
	# Создаём точки треугольника
	var points = []
	
	# Острие треугольника смотрит в направлении обзора
	points.append(triangle_position + facing_dir * triangle_size)
	
	# Две другие вершины формируют основание треугольника (перпендикулярно направлению)
	var perpendicular = facing_dir.rotated(PI/2) * triangle_size * 0.6
	points.append(triangle_position - facing_dir * (triangle_size * 0.5) + perpendicular)
	points.append(triangle_position - facing_dir * (triangle_size * 0.5) - perpendicular)
	
	# Цвет с возможным усилением при подсветке или анимации
	var color = indicator_color
	
	if highlight_time > 0:
		color.a = min(1.0, color.a + (0.3 * highlight_time * 2))
	
	if animation_active:
		# Слегка увеличиваем яркость во время анимации
		color = color.lightened(0.2)
	
	# Рисуем контур треугольника
	if outline_width > 0:
		for i in range(3):
			draw_line(points[i], points[(i+1)%3], outline_color, outline_width)
	
	# Рисуем заполненный треугольник
	draw_colored_polygon(points, color)
	
	# Добавляем небольшой след при движении для дополнительного визуального эффекта
	if animation_active:
		var trail_color = indicator_color
		trail_color.a *= 0.3
		
		# Создаем точки для следа (чуть меньше основного треугольника)
		var trail_direction = facing_dir.rotated(PI).normalized()  # Противоположное направление
		var trail_position = triangle_position + trail_direction * (triangle_size * 0.2)
		var trail_points = []
		
		trail_points.append(trail_position + trail_direction * triangle_size * 0.7)
		perpendicular = trail_direction.rotated(PI/2) * triangle_size * 0.4
		trail_points.append(trail_position - trail_direction * (triangle_size * 0.3) + perpendicular)
		trail_points.append(trail_position - trail_direction * (triangle_size * 0.3) - perpendicular)
		
		draw_colored_polygon(trail_points, trail_color)
