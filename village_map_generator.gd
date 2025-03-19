extends Node2D

class_name VillageMapGenerator

# Настройки генерации
@export var map_width: int = 1000
@export var map_height: int = 1000
@export var min_buildings: int = 8
@export var max_buildings: int = 15
@export var min_building_size: Vector2 = Vector2(50, 50)
@export var max_building_size: Vector2 = Vector2(150, 100)
@export var min_building_distance: float = 30.0
@export var road_width: float = 15.0
@export var vegetation_density: float = 0.02

# Ссылки на сцены
@export var building_scenes: Array[PackedScene] = []
@export var vegetation_scenes: Array[PackedScene] = []
@export var road_scene: PackedScene

# Основные узлы
var buildings_container: Node2D
var roads_container: Node2D
var vegetation_container: Node2D
var navigation_region: NavigationRegion2D
var pathfinding_points: Array[Vector2] = []

# Навигационные данные
var nav_map: RID

func _ready():
	randomize()
	initialize_containers()
	generate_village()

func initialize_containers():
	buildings_container = Node2D.new()
	buildings_container.name = "Buildings"
	add_child(buildings_container)
	
	roads_container = Node2D.new()
	roads_container.name = "Roads"
	add_child(roads_container)
	
	vegetation_container = Node2D.new()
	vegetation_container.name = "Vegetation"
	add_child(vegetation_container)
	
	# Создаём навигационную область
	navigation_region = NavigationRegion2D.new()
	navigation_region.name = "NavigationRegion"
	add_child(navigation_region)

func generate_village():
	# 1. Генерируем здания
	var buildings = generate_buildings()
	
	# 2. Генерируем дороги между зданиями
	generate_roads(buildings)
	
	# 3. Генерируем растительность
	generate_vegetation(buildings)
	
	# 4. Настраиваем навигационную сетку
	setup_navigation()

func generate_buildings() -> Array[Dictionary]:
	var buildings: Array[Dictionary] = []
	var num_buildings = randi_range(min_buildings, max_buildings)
	
	# Генерируем центральное здание (например, таверну)
	var center_building = {
		"position": Vector2(map_width / 2, map_height / 2),
		"size": Vector2(100, 80),
		"type": "tavern",
		"rotation": 0.0
	}
	buildings.append(center_building)
	
	# Генерируем остальные здания
	for i in range(num_buildings - 1):
		var attempts = 0
		var valid_position = false
		var new_building = {}
		
		while !valid_position and attempts < 50:
			var size = Vector2(
				randf_range(min_building_size.x, max_building_size.x),
				randf_range(min_building_size.y, max_building_size.y)
			)
			
			var position = Vector2(
				randf_range(size.x/2, map_width - size.x/2),
				randf_range(size.y/2, map_height - size.y/2)
			)
			
			var rotation = randf_range(0, PI/2) if randf() > 0.5 else 0.0
			
			if is_valid_building_position(position, size, rotation, buildings):
				new_building = {
					"position": position,
					"size": size,
					"type": get_random_building_type(),
					"rotation": rotation
				}
				valid_position = true
			
			attempts += 1
		
		if valid_position:
			buildings.append(new_building)
	
	# Создаём спрайты зданий
	for building in buildings:
		create_building_instance(building)
	
	return buildings

func is_valid_building_position(position: Vector2, size: Vector2, rotation: float, buildings: Array) -> bool:
	# Проверяем, не выходит ли здание за границы карты
	var half_diag = sqrt(pow(size.x/2, 2) + pow(size.y/2, 2))
	if position.x - half_diag < 0 or position.x + half_diag > map_width:
		return false
	if position.y - half_diag < 0 or position.y + half_diag > map_height:
		return false
	
	# Проверяем расстояние до других зданий
	for other in buildings:
		var distance = position.distance_to(other["position"])
		var min_distance_needed = half_diag + sqrt(pow(other["size"].x/2, 2) + pow(other["size"].y/2, 2)) + min_building_distance
		if distance < min_distance_needed:
			return false
	
	return true

func get_random_building_type() -> String:
	var types = ["house", "shop", "barn", "well", "smithy", "temple"]
	return types[randi() % types.size()]

func create_building_instance(building_data: Dictionary) -> void:
	var building_scene: PackedScene
	
	# Выбираем подходящую сцену в зависимости от типа здания
	if building_scenes.size() > 0:
		building_scene = building_scenes[randi() % building_scenes.size()]
	else:
		# Если сцены не предоставлены, создаём простой прямоугольник
		var placeholder = ColorRect.new()
		placeholder.color = Color(0.8, 0.6, 0.4)
		placeholder.size = building_data["size"]
		placeholder.position = -building_data["size"] / 2
		
		var building_instance = Node2D.new()
		building_instance.add_child(placeholder)
		building_instance.position = building_data["position"]
		building_instance.rotation = building_data["rotation"]
		buildings_container.add_child(building_instance)
		
		# Добавляем точку для pathfinding
		pathfinding_points.append(building_data["position"])
		return
	
	var building_instance = building_scene.instantiate()
	building_instance.position = building_data["position"]
	building_instance.rotation = building_data["rotation"]
	buildings_container.add_child(building_instance)
	
	# Добавляем точку для pathfinding
	pathfinding_points.append(building_data["position"])

func generate_roads(buildings: Array) -> void:
	# Используем алгоритм минимального остовного дерева для соединения зданий
	var mst_edges = calculate_minimum_spanning_tree(buildings)
	
	# Создаём дороги для каждого ребра MST
	for edge in mst_edges:
		var start_pos = buildings[edge.start]["position"]
		var end_pos = buildings[edge.end]["position"]
		create_road(start_pos, end_pos)

func calculate_minimum_spanning_tree(buildings: Array) -> Array:
	var edges = []
	var num_buildings = buildings.size()
	
	# Создаём список рёбер с весами (расстояниями)
	for i in range(num_buildings):
		for j in range(i + 1, num_buildings):
			var distance = buildings[i]["position"].distance_to(buildings[j]["position"])
			edges.append({"start": i, "end": j, "weight": distance})
	
	# Сортируем рёбра по весу
	edges.sort_custom(func(a, b): return a["weight"] < b["weight"])
	
	# Алгоритм Крускала для построения MST
	var parent = []
	for i in range(num_buildings):
		parent.append(i)
	
	var mst_edges = []
	
	for edge in edges:
		var start_root = find_root(parent, edge["start"])
		var end_root = find_root(parent, edge["end"])
		
		if start_root != end_root:
			mst_edges.append(edge)
			union(parent, start_root, end_root)
	
	return mst_edges

func find_root(parent: Array, i: int) -> int:
	if parent[i] != i:
		parent[i] = find_root(parent, parent[i])
	return parent[i]

func union(parent: Array, x: int, y: int) -> void:
	parent[find_root(parent, x)] = find_root(parent, y)

func create_road(start: Vector2, end: Vector2) -> void:
	if road_scene:
		var road_instance = road_scene.instantiate()
		road_instance.create_road(start, end, road_width)
		roads_container.add_child(road_instance)
	else:
		# Создаём простую линию
		var road = Line2D.new()
		road.width = road_width
		road.default_color = Color(0.5, 0.5, 0.5)
		road.add_point(start)
		road.add_point(end)
		roads_container.add_child(road)

func generate_vegetation(buildings: Array) -> void:
	# Вычисляем общую площадь карты
	var total_area = map_width * map_height
	var num_vegetation = 20
	
	for i in range(num_vegetation):
		var attempts = 0
		var valid_position = false
		var position = Vector2.ZERO
		
		while !valid_position and attempts < 10:
			position = Vector2(
				randf_range(0, map_width),
				randf_range(0, map_height)
			)
			
			valid_position = is_valid_vegetation_position(position, buildings)
			attempts += 1
		
		if valid_position:
			create_vegetation_instance(position)

func is_valid_vegetation_position(position: Vector2, buildings: Array) -> bool:
	# Проверяем, не слишком ли близко к зданиям
	for building in buildings:
		var distance = position.distance_to(building["position"])
		var min_distance = sqrt(pow(building["size"].x/2, 2) + pow(building["size"].y/2, 2)) + 10.0
		if distance < min_distance:
			return false
	
	# Проверяем, не слишком ли близко к дорогам
	for road in roads_container.get_children():
		if road is Line2D:
			var min_distance_to_road = calculate_min_distance_to_line(position, road.points[0], road.points[1])
			if min_distance_to_road < road_width + 5.0:
				return false
	
	return true

func calculate_min_distance_to_line(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line_vec = line_end - line_start
	var point_vec = point - line_start
	var line_length = line_vec.length()
	var projection = point_vec.dot(line_vec) / line_length
	
	if projection < 0:
		return point.distance_to(line_start)
	elif projection > line_length:
		return point.distance_to(line_end)
	else:
		var projected_point = line_start + line_vec.normalized() * projection
		return point.distance_to(projected_point)

func create_vegetation_instance(position: Vector2) -> void:
	var vegetation_instance
	
	if vegetation_scenes.size() > 0:
		var scene = vegetation_scenes[randi() % vegetation_scenes.size()]
		vegetation_instance = scene.instantiate()
	else:
		# Создаём простой спрайт для растительности
		vegetation_instance = Sprite2D.new()
		var texture = load("res://icon.svg")  # Используем стандартную иконку Godot
		if texture:
			vegetation_instance.texture = texture
			vegetation_instance.scale = Vector2(0.3, 0.3)
	
	vegetation_instance.position = position
	vegetation_instance.rotation = randf() * 2 * PI  # Случайный поворот
	vegetation_container.add_child(vegetation_instance)

func setup_navigation() -> void:
	# Создаём навигационную сетку
	var nav_poly = NavigationPolygon.new()
	
	# Добавляем всю карту как проходимую область
	var outline = PackedVector2Array([
		Vector2(0, 0),
		Vector2(map_width, 0),
		Vector2(map_width, map_height),
		Vector2(0, map_height)
	])
	nav_poly.add_outline(outline)
	
	# Добавляем здания как непроходимые области
	for building in buildings_container.get_children():
		if building is Node2D:
			var building_polygon = get_building_polygon(building)
			if building_polygon.size() > 2:
				nav_poly.add_outline(building_polygon)
	
	nav_poly.make_polygons_from_outlines()
	navigation_region.navigation_polygon = nav_poly

func get_building_polygon(building: Node2D) -> PackedVector2Array:
	var polygon = PackedVector2Array()
	
	# Получаем прямоугольник здания
	var rect = Rect2()
	
	# Проверяем, есть ли у здания компонент CollisionShape2D
	var collision_shape = building.get_node_or_null("CollisionShape2D")
	if collision_shape:
		if collision_shape.shape is RectangleShape2D:
			rect = Rect2(-collision_shape.shape.extents, collision_shape.shape.extents * 2)
		elif collision_shape.shape is CircleShape2D:
			var radius = collision_shape.shape.radius
			rect = Rect2(-Vector2(radius, radius), Vector2(radius * 2, radius * 2))
	# Если нет, ищем ColorRect
	else:
		var color_rect = building.get_node_or_null("ColorRect")
		if color_rect:
			rect = Rect2(color_rect.position, color_rect.size)
		else:
			rect = Rect2(-Vector2(25, 25), Vector2(50, 50))  # Значение по умолчанию
	
	# Преобразуем прямоугольник в полигон с учётом позиции и поворота здания
	var transform = building.global_transform
	# Используем умножение вместо xform
	polygon.append(transform * rect.position)
	polygon.append(transform * (rect.position + Vector2(rect.size.x, 0)))
	polygon.append(transform * (rect.position + rect.size))
	polygon.append(transform * (rect.position + Vector2(0, rect.size.y)))
	
	return polygon

# Вспомогательные функции для пошагового движения
func get_available_movement_points(position: Vector2, movement_range: float) -> Array[Vector2]:
	var available_points: Array[Vector2] = []
	
	# Проверяем, находится ли точка в пределах движения
	for x in range(int(position.x - movement_range), int(position.x + movement_range) + 1, 10):
		for y in range(int(position.y - movement_range), int(position.y + movement_range) + 1, 10):
			var test_point = Vector2(x, y)
			if position.distance_to(test_point) <= movement_range:
				# Проверяем, не преграждает ли что-то путь
				var space_state = get_world_2d().direct_space_state
				var query = PhysicsRayQueryParameters2D.create(position, test_point)
				var result = space_state.intersect_ray(query)
				
				if !result:
					available_points.append(test_point)
	
	return available_points

func can_move_to(from: Vector2, to: Vector2, movement_range: float) -> bool:
	# Проверяем расстояние
	if from.distance_to(to) > movement_range:
		return false
	
	# Проверяем, не преграждает ли что-то путь
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	return !result

# Класс для хранения информации о дороге
class RoadBuilder extends Node2D:
	var road_width: float = 15.0
	
	func create_road(start: Vector2, end: Vector2, width: float) -> void:
		road_width = width
		
		var road = Line2D.new()
		road.width = road_width
		road.default_color = Color(0.5, 0.5, 0.5)
		road.add_point(start)
		road.add_point(end)
		add_child(road)
		
		# Добавляем коллизию для дороги
		var collision_shape = CollisionShape2D.new()
		var shape = SegmentShape2D.new()
		shape.a = start
		shape.b = end
		collision_shape.shape = shape
		
		var static_body = StaticBody2D.new()
		static_body.collision_layer = 2  # Используем отдельный слой для дорог
		static_body.collision_mask = 0   # Дороги не реагируют на коллизии
		static_body.add_child(collision_shape)
		add_child(static_body)

# Визуализация доступных точек для движения
func visualize_movement_range(position: Vector2, movement_range: float) -> void:
	var points = get_available_movement_points(position, movement_range)
	
	# Очищаем предыдущую визуализацию
	for child in get_children():
		if child.name == "MovementRangeVisualization":
			child.queue_free()
	
	var visualization = Node2D.new()
	visualization.name = "MovementRangeVisualization"
	add_child(visualization)
	
	for point in points:
		var dot = ColorRect.new()
		dot.color = Color(0.0, 1.0, 0.0, 0.5)
		dot.size = Vector2(5, 5)
		dot.position = point - Vector2(2.5, 2.5)
		visualization.add_child(dot)
