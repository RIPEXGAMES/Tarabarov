class_name Character
extends Node2D

#region Сигналы
signal move_finished
signal end_turn_requested
signal cell_changed(old_cell, new_cell)
signal path_changed(new_path)
signal movement_started
signal path_cost_changed(cost)
signal attack_executed(target_cell)
signal attack_started(target_enemy)
signal field_of_view_changed(visible_cells_array, hit_chances)
signal weapon_changed(weapon)
signal direction_changed(new_direction_index) # Новый сигнал для обновления интерфейса
#endregion

#region Экспортируемые настройки
# Базовые характеристики
@export var move_speed: float = 4.0
@export var action_points: int = 50
@export var allow_diagonal: bool = true
@export var debug_mode: bool = true

# Настройки атаки
@export var attack_cost: int = 20
@export var attack_damage: int = 25
@export var current_weapon: Weapon

# Параметры поля зрения и атаки
@export var field_of_view_angle: float = 110.0
@export var max_view_distance: int = 100
@export var effective_attack_range: int = 30
@export_range(0, 100) var base_hit_chance: int = 80
@export_range(0, 100) var medium_distance_hit_chance: int = 40

# Настройки поворота
@export var rotation_cost: int = 5 # Стоимость поворота на 45 градусов
#endregion

#region Внутренние переменные
# Состояние персонажа
var current_cell: Vector2i = Vector2i.ZERO
var remaining_ap: int = 0
var facing_direction: Vector2 = Vector2.RIGHT
var is_moving: bool = false
var attack_mode: bool = false
var is_attacking: bool = false

# Направления поворота
enum Direction { N, NE, E, SE, S, SW, W, NW }
var current_direction: int = Direction.E  # По умолчанию смотрит вправо
var direction_vectors: Array = [
	Vector2(0, -1),   # N
	Vector2(1, -1),   # NE
	Vector2(1, 0),    # E
	Vector2(1, 1),    # SE
	Vector2(0, 1),    # S
	Vector2(-1, 1),   # SW
	Vector2(-1, 0),   # W
	Vector2(-1, -1)   # NW
]

# Системные переменные
var path: Array = []
var movement_queue: Array = []
var movement_in_progress: bool = false
var tween: Tween = null

# Поле зрения
var visible_cells: Array = []
var hit_chance_map: Dictionary = {}
var available_attack_cells: Array = []
var last_fov_update_time: float = 0.0
var fov_update_interval: float = 0.1
var last_facing_direction: Vector2 = Vector2.RIGHT
var facing_direction_threshold: float = 0.01
#endregion

#region Ссылки на узлы
@onready var map_generator: MapGenerator = get_node("../MapGenerator")
@onready var sprite: Sprite2D = $Sprite2D
@onready var landscape_layer: TileMapLayer = get_node("../Landscape")
@onready var game_controller: Node = get_node("../GameContoller")
var move_manager = null
#endregion

#region Debug
# Обновите переменные в #region Debug для хранения смещенных лучей
var debug_show_los_rays: bool = false  # Переключатель визуализации лучей
var debug_hovered_cell: Vector2i = Vector2i(-1, -1)  # Клетка под курсором
var debug_ray_cells: Array = []  # Клетки на луче
var debug_blocked_cell: Vector2i = Vector2i(-1, -1)  # Клетка, блокирующая обзор
var debug_offset_start1: Vector2i = Vector2i(-1, -1)  # Начальная точка смещенного луча 1
var debug_offset_start2: Vector2i = Vector2i(-1, -1)  # Начальная точка смещенного луча 2
#endregion

#region Инициализация
func _ready():
	debug_print("Character initialized")
	
	# Проверка необходимых узлов
	validate_dependencies()
	
	# Инициализация очков действия
	remaining_ap = action_points
	
	# Начальное положение персонажа
	place_at_valid_starting_position()
	
	# Создаем и инициализируем менеджер перемещений
	initialize_move_manager()
	
	# Подключаем обработку ввода
	set_process_input(true)
	
	# Инициализируем оружие, если оно установлено
	update_weapon_parameters()

func validate_dependencies():
	if not map_generator:
		push_error("MapGenerator not found!")
	if not landscape_layer:
		push_error("Landscape layer not found!")
	if not game_controller:
		push_error("GameController not found!")

func initialize_move_manager():
	move_manager = MoveManager.new()
	add_child(move_manager)
	move_manager.initialize(map_generator, current_cell, remaining_ap, action_points)
	move_manager.connect("path_cost_updated", _on_path_cost_updated)

func place_at_valid_starting_position():
	for x in range(map_generator.map_width):
		for y in range(map_generator.map_height):
			if map_generator.is_tile_walkable(x, y):
				current_cell = Vector2i(x, y)
				global_position = landscape_layer.map_to_local(current_cell)
				debug_print("Starting position: " + str(current_cell))
				return
	
	push_error("Не найдено ни одной проходимой клетки для размещения персонажа")
#endregion

#region draw
# Обновленная функция отрисовки для двух лучей
func _draw():
	if not debug_show_los_rays or debug_hovered_cell == Vector2i(-1, -1):
		return
		
	# Цвета для отладочной информации
	var ray1_color = Color(0, 1, 0, 0.7)      # Зеленый для первого луча
	var ray2_color = Color(0, 0.7, 1, 0.7)    # Синий для второго луча
	var cell_color = Color(0.5, 0.5, 0.8, 0.2) # Светло-голубой для клеток на пути
	var target_color = Color(0, 0.8, 0, 0.5)  # Ярко-зеленый для целевой клетки
	var blocked_color = Color(1, 0, 0, 0.5)   # Красный для блокирующей клетки
	
	# Получаем размер тайла
	var tile_size = landscape_layer.tile_set.tile_size
	
	# Рисуем клетки вдоль луча
	for cell in debug_ray_cells:
		var cell_pos:Vector2i = landscape_layer.map_to_local(cell) - global_position
		var rect = Rect2(cell_pos - tile_size/2, tile_size)
		draw_rect(rect, cell_color, true)
	
	# Получаем конечную точку
	var end_pos = landscape_layer.map_to_local(debug_hovered_cell) - global_position
	
	# Рассчитываем смещения для лучей
	var dir = Vector2(debug_hovered_cell.x - current_cell.x, debug_hovered_cell.y - current_cell.y).normalized()
	var perpendicular = Vector2(-dir.y, dir.x)
	var offset_amount = tile_size.y * 0.25
	
	# Точки начала для лучей (в локальных координатах относительно персонажа)
	var start_pos = Vector2.ZERO
	var upper_start = start_pos + perpendicular * offset_amount
	var lower_start = start_pos - perpendicular * offset_amount
	
	# Рисуем два луча разными цветами
	draw_line(upper_start, end_pos, ray1_color, 1.5, true)
	draw_line(lower_start, end_pos, ray2_color, 1.5, true)
	
	# Рисуем маленькие кружки для обозначения точек начала лучей
	draw_circle(upper_start, 3.0, ray1_color)
	draw_circle(lower_start, 3.0, ray2_color)
	
	# Выделяем целевую клетку
	var target_pos:Vector2i = landscape_layer.map_to_local(debug_hovered_cell) - global_position
	var target_rect = Rect2(target_pos - tile_size/2, tile_size)
	draw_rect(target_rect, target_color, true)
	draw_rect(target_rect, target_color.lightened(0.3), false, 2)
	
	# Если есть блокирующая клетка, выделяем её
	if debug_blocked_cell != Vector2i(-1, -1):
		var blocked_pos:Vector2i = landscape_layer.map_to_local(debug_blocked_cell) - global_position
		var blocked_rect = Rect2(blocked_pos - tile_size/2, tile_size)
		draw_rect(blocked_rect, blocked_color, true)
		draw_rect(blocked_rect, blocked_color.darkened(0.3), false, 2)
		
		# Рисуем крестик на блокирующей клетке
		var half_size = tile_size / 2
		var center = blocked_pos
		draw_line(center - half_size/2, center + half_size/2, Color(1,0,0,0.8), 3)
		draw_line(Vector2(center.x + half_size.x/2, center.y - half_size.y/2), Vector2(center.x - half_size.x/2, center.y + half_size.y/2), Color(1,0,0,0.8), 3)
#endregion

#region Обработка ввода и основной процесс
func _input(event):
	if not can_process_input():
		return
	
	# Переключение режима атаки по нажатию на кнопку "A"
	if event is InputEventKey and event.pressed and event.keycode == KEY_A:
		toggle_attack_mode()
		return
	
	# Поворот по часовой стрелке - клавиша E
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		rotate_character(1)
		return
		
	# Поворот против часовой стрелки - клавиша Q
	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		rotate_character(-1)
		return
		
	if event is InputEventKey and event.pressed and event.keycode == KEY_D:
		toggle_debug_rays()
		return
		
	
	# Обработка левого клика
	if event.is_action_pressed("left_click"):
		if attack_mode:
			handle_attack_click(event)
		else:
			handle_left_click(event)
	
	# Обработка правого клика
	elif event.is_action_pressed("right_click"):
		if attack_mode:
			exit_attack_mode()
		else:
			handle_right_click()
	
	# Завершение хода по нажатию пробела
	elif event.is_action_pressed("ui_select") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		debug_print("End turn triggered")
		request_end_turn()

func _process(_delta):
	 # Добавьте это в конец метода _process
	if debug_show_los_rays:
		update_debug_ray()

func can_process_input() -> bool:
	return game_controller and game_controller.can_player_act() and not is_moving and not is_attacking

func request_end_turn():
	debug_print("End turn requested")
	emit_signal("end_turn_requested")
	end_turn()

func end_turn():
	is_moving = false
	movement_queue.clear()
	set_path([])
	
	if tween and tween.is_running():
		tween.kill()
	
	remaining_ap = action_points
	move_manager.restore_ap()
	
	emit_signal("move_finished")
	debug_print("Turn ended, AP restored: " + str(remaining_ap))
#endregion

#region Система поворота персонажа
func rotate_character(direction_step: int):
	# Проверяем достаточно ли AP для поворота
	if remaining_ap < rotation_cost:
		debug_print("Недостаточно AP для поворота! Необходимо: " + str(rotation_cost) + ", имеется: " + str(remaining_ap))
		return
	
	# Вычисляем новое направление
	var new_direction = (current_direction + direction_step) % 8
	if new_direction < 0:
		new_direction += 8
	
	# Если направление не изменилось, прекращаем выполнение
	if new_direction == current_direction:
		return
		
	# Списываем очки действия
	remaining_ap -= rotation_cost
	
	# Обновляем направление
	set_character_direction(new_direction)
	
	# Обновляем доступные клетки для перемещения
	move_manager.current_ap = remaining_ap
	move_manager.update_available_cells()
	
	debug_print("Character rotated to direction: " + get_direction_name(current_direction))

func set_character_direction(direction_index: int):
	var old_direction = current_direction
	current_direction = direction_index
	facing_direction = direction_vectors[direction_index]
	
	# Обновляем спрайт персонажа
	update_sprite_direction(facing_direction)
	
	# Обновляем поле зрения, если в режиме атаки
	if attack_mode:
		update_field_of_view()
	
	# Отправляем сигнал для обновления UI
	emit_signal("direction_changed", current_direction)
	
	# Если это движение (а не ручной поворот), можно отобразить визуальный эффект
	if is_moving:
		var direction_indicator = get_node_or_null("DirectionIndicator")
		if direction_indicator and direction_indicator.has_method("show_movement_direction_change"):
			direction_indicator.show_movement_direction_change(old_direction, current_direction)

func get_direction_name(direction_index: int) -> String:
	match direction_index:
		Direction.N: return "Север"
		Direction.NE: return "Северо-восток"
		Direction.E: return "Восток"
		Direction.SE: return "Юго-восток"
		Direction.S: return "Юг"
		Direction.SW: return "Юго-запад"
		Direction.W: return "Запад" 
		Direction.NW: return "Северо-запад"
		_: return "Неизвестно"
#endregion

#region Система перемещения
func handle_left_click(event):
	var mouse_pos = get_global_mouse_position()
	var clicked_cell = landscape_layer.local_to_map(landscape_layer.to_local(mouse_pos))
	
	if move_manager.is_cell_walkable(clicked_cell):
		if clicked_cell == move_manager.selected_cell:
			start_movement(clicked_cell)
		else:
			select_cell(clicked_cell)

func handle_right_click():
	move_manager.clear_selection()
	set_path([])
	emit_signal("path_cost_changed", 0)
	get_viewport().set_input_as_handled()

func select_cell(cell: Vector2i):
	if move_manager.select_cell(cell):
		set_path([])
	else:
		set_path([])

func set_path(new_path: Array):
	path = new_path
	emit_signal("path_changed", path)

func start_movement(target_cell: Vector2i):
	debug_print("Starting movement to: " + str(target_cell))
	
	var calculated_path = move_manager.move_to_selected_cell()
	
	if calculated_path.size() == 0:
		set_path([])
		return
	
	# Если путь содержит больше одной клетки, вычисляем направление движения
	if calculated_path.size() > 1:
		var first_step = calculated_path[0]
		var movement_direction = landscape_layer.map_to_local(first_step) - global_position
		var movement_direction_index = get_closest_direction_index(movement_direction)
		
		# Проверяем, нужно ли поворачивать персонажа отдельно перед движением
		# Если персонаж уже смотрит в нужном направлении или в соседнем секторе (±45°),
		# то дополнительный поворот не требуется и AP не тратятся
		if movement_direction_index != current_direction:
			var dir_diff = abs(movement_direction_index - current_direction)
			dir_diff = min(dir_diff, 8 - dir_diff)  # Учитываем кратчайший поворот
			
			# Только если разница больше 1 (больше 45°), считаем это значительным поворотом
			if dir_diff > 1:
				# Если у игрока достаточно AP для поворота, поворачиваемся перед движением
				if remaining_ap >= rotation_cost:
					remaining_ap -= rotation_cost
					move_manager.current_ap = remaining_ap
					move_manager.update_available_cells()
					set_character_direction(movement_direction_index)
					debug_print("Character turned before moving. AP left: " + str(remaining_ap))
	
	set_path(calculated_path)
	movement_queue = calculated_path.duplicate()
	is_moving = true
	
	emit_signal("movement_started")
	process_movement_queue()

func process_movement_queue():
	if movement_queue.size() == 0 or movement_in_progress:
		complete_movement()
		return
	
	var next_cell = movement_queue[0]
	movement_in_progress = true
	animate_move_to_cell(next_cell)

func animate_move_to_cell(target_cell: Vector2i):
	var target_position = landscape_layer.map_to_local(target_cell)
	var direction = global_position.direction_to(target_position)
	
	# Определяем направление движения и поворачиваем персонажа
	var movement_direction_index = get_closest_direction_index(direction)
	set_character_direction(movement_direction_index)
	
	# Остальной код анимации движения остается без изменений
	var distance = global_position.distance_to(target_position)
	var duration = distance / (move_speed * landscape_layer.tile_set.tile_size.x)
	
	if tween and tween.is_running():
		tween.kill()
	
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "global_position", target_position, duration)
	
	await tween.finished
	
	var old_cell = current_cell
	current_cell = target_cell
	
	# Рассчитываем стоимость перемещения (прямо/по диагонали)
	var move_cost = 10
	if abs(direction.x) > 0 and abs(direction.y) > 0:
		move_cost = 15
	
	remaining_ap -= move_cost
	
	move_manager.character_cell = current_cell
	move_manager.current_ap = remaining_ap
	move_manager.update_available_cells()
	
	emit_signal("cell_changed", old_cell, current_cell)
	
	movement_queue.remove_at(0)
	
	var new_path = movement_queue.duplicate()
	set_path(new_path)
	
	movement_in_progress = false
	process_movement_queue()
	
# Новый метод для определения ближайшего фиксированного направления
func get_closest_direction_index(direction_vector: Vector2) -> int:
	var normalized_vector = direction_vector.normalized()
	var closest_direction = 0
	var smallest_angle = 999.0
	
	for i in range(direction_vectors.size()):
		var angle_diff = abs(direction_vectors[i].angle_to(normalized_vector))
		if angle_diff < smallest_angle:
			smallest_angle = angle_diff
			closest_direction = i
			
	return closest_direction

func complete_movement():
	if is_moving:
		is_moving = false
		debug_print("Movement completed, AP left: " + str(remaining_ap))
		set_path([])
		emit_signal("move_finished")

func _on_path_cost_updated(cost: int):
	emit_signal("path_cost_changed", cost)
#endregion

#region Система поля зрения и атаки
func toggle_attack_mode():
	if !attack_mode:
		if remaining_ap < attack_cost:
			debug_print("Недостаточно AP для атаки! Необходимо: " + str(attack_cost) + ", имеется: " + str(remaining_ap))
			return
	
	attack_mode = !attack_mode
	
	if attack_mode:
		debug_print("Attack mode enabled")
		move_manager.clear_selection()
		set_path([])
		# Используем текущее направление для обновления поля зрения
		update_field_of_view()
	else:
		visible_cells.clear()
		hit_chance_map.clear()
		available_attack_cells.clear()
		emit_signal("field_of_view_changed", [], {})
	
	queue_redraw()

func exit_attack_mode():
	if attack_mode:
		attack_mode = false
		visible_cells.clear()
		hit_chance_map.clear()
		available_attack_cells.clear()
		emit_signal("field_of_view_changed", [], {})

# Модифицируем update_sprite_direction, чтобы он учитывал фиксированное направление
func update_sprite_direction(direction: Vector2):
	if abs(direction.x) > abs(direction.y):
		sprite.flip_h = direction.x < 0
	# Можно добавить анимации для разных направлений

# Изменим метод update_field_of_view для сбора отладочной информации
func update_field_of_view():
	visible_cells.clear()
	hit_chance_map.clear()
	available_attack_cells.clear()
	
	# Базовый угол направления взгляда в радианах
	var face_angle = facing_direction.angle()
	
	# Половина угла обзора в радианах
	var half_fov = deg_to_rad(field_of_view_angle) / 2.0
	
	# Проверяем все клетки в квадрате с центром в персонаже
	for y in range(-max_view_distance, max_view_distance + 1):
		for x in range(-max_view_distance, max_view_distance + 1):
			var cell = current_cell + Vector2i(x, y)
			
			# Проверяем границы карты
			if not is_cell_valid(cell):
				continue
				
			# Пропускаем текущую клетку персонажа
			if cell == current_cell:
				continue
				
			# Проверяем расстояние до клетки (убираем клетки вне радиуса обзора)
			var distance = current_cell.distance_to(cell)
			if distance > max_view_distance:
				continue
				
			# Проверяем, находится ли клетка в угле обзора
			var dir_vector = Vector2(cell.x - current_cell.x, cell.y - current_cell.y).normalized()
			var angle_diff = abs(facing_direction.angle_to(dir_vector))
			
			if angle_diff > half_fov:
				continue
			
			# Проверка видимости с использованием метода с двумя смещёнными лучами
			if is_cell_visible_with_offset_rays(cell):
				visible_cells.append(cell)
				hit_chance_map[cell] = calculate_hit_chance(distance)
				
				# Проверяем наличие противника в клетке
				var enemy = find_enemy_at_cell(cell)
				if enemy:
					available_attack_cells.append(cell)
	
	# Отправляем сигнал об изменении поля зрения
	emit_signal("field_of_view_changed", visible_cells, hit_chance_map)

func is_cell_visible_with_offset_rays(target_cell: Vector2i) -> bool:
	# Если это текущая клетка, она всегда видна
	if target_cell == current_cell:
		return true
		
	# Определяем направление и перпендикулярный вектор для смещения
	var dir = Vector2(target_cell.x - current_cell.x, target_cell.y - current_cell.y).normalized()
	var perpendicular = Vector2(-dir.y, dir.x)  # Перпендикулярный вектор
	
	# Получаем координаты центра текущей клетки
	var center_pos = landscape_layer.map_to_local(current_cell)
	
	# Смещение для верхнего и нижнего лучей (в мировых координатах)
	var offset_amount = landscape_layer.tile_set.tile_size.y * 0.25  # 25% от размера тайла
	
	# Точки для смещенных лучей
	var upper_point = center_pos + perpendicular * offset_amount
	var lower_point = center_pos - perpendicular * offset_amount
	
	# Конечная точка (центр целевой клетки)
	var target_pos = landscape_layer.map_to_local(target_cell)
	
	# Для отладки сохраняем точки начала лучей в клеточных координатах
	if debug_show_los_rays:
		debug_offset_start1 = landscape_layer.local_to_map(upper_point)
		debug_offset_start2 = landscape_layer.local_to_map(lower_point)
		# Если точки находятся в той же клетке, смещаем их немного для визуализации
		if debug_offset_start1 == current_cell:
			debug_offset_start1 = Vector2i(-100, -100)  # Специальное значение
		if debug_offset_start2 == current_cell:
			debug_offset_start2 = Vector2i(-100, -100)  # Специальное значение
	
	# Проверяем оба луча - клетка видима только если ОБА луча видят цель
	var upper_ray_visible = is_point_to_point_visible(upper_point, target_pos)
	var lower_ray_visible = is_point_to_point_visible(lower_point, target_pos)
	
	return upper_ray_visible && lower_ray_visible

func is_point_to_point_visible(from_point: Vector2, to_point: Vector2) -> bool:
	var total_distance = from_point.distance_to(to_point)
	var direction = (to_point - from_point).normalized()
	
	# Количество шагов проверки (минимум 10, или больше для дальних клеток)
	var steps = max(10, int(total_distance / (landscape_layer.tile_set.tile_size.x * 0.25)))
	var step_size = total_distance / steps
	
	# Проверяем каждую точку на пути (кроме начальной и конечной)
	for i in range(1, steps):
		var check_position = from_point + direction * (step_size * i)
		var check_cell = landscape_layer.local_to_map(check_position)
		
		# Не проверяем начальную и конечную клетки
		if check_cell == current_cell or check_cell == landscape_layer.local_to_map(to_point):
			continue
		
		# Если клетка блокирует обзор, луч не проходит
		if is_cell_valid(check_cell) and map_generator.is_tile_blocking_vision(check_cell.x, check_cell.y):
			return false
	
	return true

# Вспомогательная функция для проверки пути без препятствий
func is_path_clear(path_cells: Array) -> bool:
	# Проверяем все клетки на пути, кроме начальной и конечной
	for i in range(1, path_cells.size() - 1):
		var cell = path_cells[i]
		if not is_cell_valid(cell) or map_generator.is_tile_blocking_vision(cell.x, cell.y):
			return false
	return true

# Проверяем видимость клетки с помощью алгоритма Брезенхема
func is_cell_visible_bresenham(target_cell: Vector2i) -> bool:
	# Если это текущая клетка, она всегда видна
	if target_cell == current_cell:
		return true
		
	# Получаем все клетки на линии между персонажем и целью
	var line_cells = get_line_cells(current_cell, target_cell)
	
	# Проверяем все клетки на пути, кроме начальной и конечной
	for i in range(1, line_cells.size() - 1):
		var cell = line_cells[i]
		
		# Если клетка за пределами карты, считаем линию прерванной
		if not is_cell_valid(cell):
			return false
			
		# Если клетка блокирует обзор, клетка не видна
		if map_generator.is_tile_blocking_vision(cell.x, cell.y):
			return false
	
	# Если не встретили препятствий, клетка видна
	return true

# Получаем все клетки на линии между двумя точками
func get_line_cells(from_cell: Vector2i, to_cell: Vector2i) -> Array:
	var line = []
	
	# Реализация алгоритма Брезенхема для получения всех клеток на линии
	var x0 = from_cell.x
	var y0 = from_cell.y
	var x1 = to_cell.x
	var y1 = to_cell.y
	
	var dx = abs(x1 - x0)
	var dy = -abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx + dy
	
	while true:
		line.append(Vector2i(x0, y0))
		
		if x0 == x1 and y0 == y1:
			break
			
		var e2 = 2 * err
		if e2 >= dy:
			if x0 == x1:
				break
			err += dy
			x0 += sx
		
		if e2 <= dx:
			if y0 == y1:
				break
			err += dx
			y0 += sy
	
	return line

# Проверка валидности клетки (в пределах карты)
func is_cell_valid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < map_generator.map_width and cell.y < map_generator.map_height

func calculate_hit_chance(distance: float) -> int:
	# В пределах эффективного радиуса
	if distance <= effective_attack_range:
		return base_hit_chance
	# В пределах двух эффективных радиусов
	elif distance <= effective_attack_range * 2:
		return medium_distance_hit_chance
	# За пределами двух эффективных радиусов
	else:
		# Линейное уменьшение шанса, вплоть до минимума 5%
		var min_chance = 5
		var max_distance_factor = float(max_view_distance - effective_attack_range * 2)
		var distance_beyond_medium = distance - effective_attack_range * 2
		var factor = 1.0 - distance_beyond_medium / max_distance_factor
		return max(min_chance, int(medium_distance_hit_chance * factor))

func find_enemy_at_cell(cell: Vector2i) -> Enemy:
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if enemy is Enemy and enemy.current_cell == cell:
			return enemy
	
	return null

func handle_attack_click(event):
	var mouse_pos = get_global_mouse_position()
	var clicked_cell = landscape_layer.local_to_map(landscape_layer.to_local(mouse_pos))
	
	# Проверяем, есть ли на клетке противник и в поле зрения ли он
	var target_enemy = find_enemy_at_cell(clicked_cell)
	
	if target_enemy and clicked_cell in available_attack_cells:
		debug_print("Executing attack on: " + str(clicked_cell))
		execute_attack(target_enemy, clicked_cell)

func execute_attack(enemy: Enemy, target_cell: Vector2i):
	if remaining_ap < attack_cost:
		debug_print("Not enough AP to attack")
		return
	
	# Уменьшаем очки действия
	remaining_ap -= attack_cost
	
	# Обновляем AP в менеджере перемещений
	move_manager.current_ap = remaining_ap
	move_manager.update_available_cells()
	
	# Поворачиваем персонажа в сторону противника
	var direction = global_position.direction_to(landscape_layer.map_to_local(target_cell))
	update_sprite_direction(direction)
	
	# Определяем шанс попадания
	var hit_chance = 0
	if hit_chance_map.has(target_cell):
		hit_chance = hit_chance_map[target_cell]
	else:
		var distance = current_cell.distance_to(target_cell)
		hit_chance = calculate_hit_chance(distance)
	
	debug_print("Attack hit chance: " + str(hit_chance) + "%")
	
	# Определяем попадание
	var hit_roll = randi() % 100 + 1  # Случайное число от 1 до 100
	var hit_successful = hit_roll <= hit_chance
	
	# Анимация атаки
	is_attacking = true
	animate_attack(enemy, hit_successful)
	
	# Отправляем сигналы
	emit_signal("attack_started", enemy)
	emit_signal("attack_executed", target_cell)
	
	# Выходим из режима атаки
	exit_attack_mode()

func animate_attack(enemy: Enemy, hit_successful: bool):
	var original_pos = global_position
	var enemy_pos = enemy.global_position
	var direction = original_pos.direction_to(enemy_pos)
	
	# Рывок на 1/3 расстояния к цели
	var dash_pos = original_pos + direction * original_pos.distance_to(enemy_pos) * 0.3
	
	if tween and tween.is_running():
		tween.kill()
	
	tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	
	tween.tween_property(self, "global_position", dash_pos, 0.15)
	tween.tween_property(self, "global_position", original_pos, 0.3)
	
	await tween.finished
	
	# Применение урона через enemy.take_damage_with_chance
	if enemy.has_method("take_damage_with_chance"):
		enemy.take_damage_with_chance(attack_damage, hit_successful)
	else:
		if hit_successful:
			enemy.take_damage(attack_damage)
	
	is_attacking = false
	
func toggle_debug_rays():
	debug_show_los_rays = !debug_show_los_rays
	if not debug_show_los_rays:
		# Если выключена, очистим данные для визуализации
		debug_hovered_cell = Vector2i(-1, -1)
		debug_ray_cells.clear()
		debug_blocked_cell = Vector2i(-1, -1)
	queue_redraw()
#endregion

#region Вспомогательные методы
func debug_print(message: String):
	if debug_mode:
		print(message)

func update_weapon_parameters():
	if current_weapon:
		attack_damage = current_weapon.damage
		effective_attack_range = current_weapon.effective_range
		base_hit_chance = current_weapon.base_hit_chance
		medium_distance_hit_chance = current_weapon.medium_hit_chance
		attack_cost = current_weapon.attack_cost
		
		debug_print("Weapon parameters updated: " + current_weapon.name)
		emit_signal("weapon_changed", current_weapon)

func equip_weapon(weapon: Weapon):
	current_weapon = weapon
	update_weapon_parameters()
	debug_print("Equipped weapon: " + weapon.name)
#endregion

func update_debug_ray():
	if not debug_show_los_rays:
		return
	
	# Получаем клетку под курсором
	var mouse_pos = get_global_mouse_position()
	var cell = landscape_layer.local_to_map(landscape_layer.to_local(mouse_pos))
	
	# Проверяем валидность клетки
	if not is_cell_valid(cell) or cell == current_cell:
		debug_hovered_cell = Vector2i(-1, -1)
		debug_ray_cells.clear()
		debug_blocked_cell = Vector2i(-1, -1)
		debug_offset_start1 = Vector2i(-100, -100)  # Специальное значение
		debug_offset_start2 = Vector2i(-100, -100)  # Специальное значение
		queue_redraw()
		return
	
	# Сохраняем клетку под курсором
	debug_hovered_cell = cell
	
	# Основной луч через алгоритм Брезенхема для визуализации клеток на пути
	var main_path = get_line_cells(current_cell, cell)
	debug_ray_cells = main_path
	
	# Проверяем основной луч на блокировку (для отображения точки блокировки)
	debug_blocked_cell = Vector2i(-1, -1)
	for i in range(1, main_path.size() - 1):
		var check_cell = main_path[i]
		if map_generator.is_tile_blocking_vision(check_cell.x, check_cell.y):
			debug_blocked_cell = check_cell
			break
	
	# Рассчитываем позиции для смещенных лучей
	var dir = Vector2(cell.x - current_cell.x, cell.y - current_cell.y).normalized()
	var perpendicular = Vector2(-dir.y, dir.x)
	
	var center_pos = landscape_layer.map_to_local(current_cell)
	var offset_amount = landscape_layer.tile_set.tile_size.y * 0.25
	
	# Точки для лучей - специальное значение для отображения
	debug_offset_start1 = Vector2i(-100, -100)  # Верхний луч
	debug_offset_start2 = Vector2i(-100, -100)  # Нижний луч
	
	# Вызываем проверку видимости, которая заполнит debug_offset_start1/2
	is_cell_visible_with_offset_rays(cell)
	
	# Обновляем отображение
	queue_redraw()
