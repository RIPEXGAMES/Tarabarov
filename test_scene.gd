extends Node2D

# Ссылки на узлы
@onready var navigation_region = $NavigationRegion2D
@onready var turn_manager = $TurnManager
@onready var player = $PlayerCharacter
@onready var obstacles = $Obstacles
@onready var ui = $UI

func _ready():
	# Создаем навигационную сетку
	setup_navigation()
	
	# Настраиваем интерфейс
	setup_ui()

func setup_navigation():
	# Обновляем навигационную сетку
	# Это нужно делать, если вы динамически изменяете препятствия
	navigation_region.navigation_polygon = generate_navigation_polygon()

func generate_navigation_polygon() -> NavigationPolygon:
	# Эта функция может быть более сложной в зависимости от вашей сцены
	# Для простоты мы создаем базовый навигационный полигон
	var nav_poly = NavigationPolygon.new()
	
	# Определяем границы уровня
	var map_size = Vector2(1024, 768)  # Замените на размер вашей карты
	
	# Создаем внешний контур
	var outline = PackedVector2Array([
		Vector2(0, 0),
		Vector2(map_size.x, 0),
		Vector2(map_size.x, map_size.y),
		Vector2(0, map_size.y)
	])
	
	nav_poly.add_outline(outline)
	
	# Добавляем "дыры" для препятствий
	# Это можно сделать программно, проходя по всем препятствиям
	for obstacle in obstacles.get_children():
		if obstacle is StaticBody2D and obstacle.has_node("CollisionShape2D"):
			var collision = obstacle.get_node("CollisionShape2D")
			var shape = collision.shape
			
			# Обработка разных типов форм коллизии
			if shape is RectangleShape2D:
				var pos = obstacle.global_position
				var size = shape.size
				var hole = PackedVector2Array([
					pos + Vector2(-size.x/2, -size.y/2),
					pos + Vector2(size.x/2, -size.y/2),
					pos + Vector2(size.x/2, size.y/2),
					pos + Vector2(-size.x/2, size.y/2)
				])
				nav_poly.add_outline(hole)
			elif shape is CircleShape2D:
				# Для круга создаем многоугольник
				var pos = obstacle.global_position
				var radius = shape.radius
				var hole = PackedVector2Array()
				
				# Создаем 8-угольник для аппроксимации круга
				var segments = 8
				for i in range(segments):
					var angle = i * 2 * PI / segments
					var point = pos + Vector2(cos(angle), sin(angle)) * radius
					hole.append(point)
				
				nav_poly.add_outline(hole)
	
	# Создаем полигон из внешнего контура и дыр
	nav_poly.make_polygons_from_outlines()
	
	return nav_poly

func setup_ui():
	# Добавляем кнопку "Закончить ход"
	var end_turn_button = Button.new()
	end_turn_button.text = "Закончить ход"
	end_turn_button.position = Vector2(800, 50)
	end_turn_button.connect("pressed", _on_end_turn_pressed)
	ui.add_child(end_turn_button)
	
	# Добавляем метку для отображения оставшегося расстояния
	var distance_label = Label.new()
	distance_label.name = "DistanceLabel"
	distance_label.position = Vector2(10, 10)
	ui.add_child(distance_label)
	
	# Обновляем информацию об оставшемся расстоянии
	update_distance_display()

func _process(_delta):
	# Обновляем отображение расстояния
	update_distance_display()

func update_distance_display():
	var distance_label = ui.get_node("DistanceLabel")
	if distance_label:
		distance_label.text = "Осталось перемещения: %.1f" % player.remaining_distance

func _on_end_turn_pressed():
	# Завершаем ход игрока
	if turn_manager.is_player_turn():
		player.end_turn()
