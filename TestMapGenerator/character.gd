class_name Character
extends Node2D

# Сигналы
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

# Настройки персонажа
@export var move_speed: float = 4.0
@export var action_points: int = 50
@export var allow_diagonal: bool = true
@export var debug_mode: bool = true
@export var attack_cost: int = 20   # Стоимость атаки
@export var attack_damage: int = 25  # Базовый урон от атаки

# Текущее оружие
@export var current_weapon: Weapon

# Параметры поля зрения и атаки
@export var field_of_view_angle: float = 120.0  # Угол поля зрения в градусах
@export var max_view_distance: int = 100  # Максимальная дальность обзора
@export var effective_attack_range: int = 30   # Эффективный радиус атаки (шанс 80%)
@export_range(0, 100) var base_hit_chance: int = 80  # Базовый шанс попадания в эффективном радиусе
@export_range(0, 100) var medium_distance_hit_chance: int = 40  # Шанс попадания на средней дистанции

# Текущее направление персонажа (для поля зрения)
var facing_direction: Vector2 = Vector2.RIGHT  # По умолчанию смотрит вправо

# Массивы для хранения видимых клеток и вероятностей попадания
var visible_cells: Array = []  # Все клетки в поле зрения
var hit_chance_map: Dictionary = {}  # Словарь вероятностей попадания {клетка: шанс}
var available_attack_cells: Array = [] # Клетки с противниками в поле зрения

# Состояние персонажа
var current_cell: Vector2i = Vector2i.ZERO
var is_moving: bool = false
var remaining_ap: int = action_points
var attack_mode: bool = false
var is_attacking: bool = false

# Переменные для пути
var path: Array = []
var movement_queue: Array = []

# Ссылки на узлы
@onready var map_generator: MapGenerator = get_node("../MapGenerator")
@onready var sprite: Sprite2D = $Sprite2D
@onready var landscape_layer: TileMapLayer = get_node("../Landscape") 
@onready var game_controller: Node = get_node("../GameContoller")

# Ссылка на менеджер перемещений
var move_manager = null

# Движение и анимация
var tween: Tween = null
var movement_in_progress: bool = false

func _ready():
	debug_print("Character._ready() started")
	
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
	
	debug_print("Character._ready() completed, AP: " + str(remaining_ap))

func validate_dependencies():
	if not map_generator:
		push_error("MapGenerator not found!")
	else:
		debug_print("MapGenerator found")
	
	if not landscape_layer:
		push_error("Landscape layer not found!")
	else:
		debug_print("Landscape layer found")
	
	if not game_controller:
		push_error("GameController not found!")
	else:
		debug_print("GameController found, can_player_act() returns: " + str(game_controller.can_player_act()))

func initialize_move_manager():
	move_manager = MoveManager.new()
	add_child(move_manager)
	move_manager.initialize(map_generator, current_cell, remaining_ap, action_points)
	move_manager.connect("path_cost_updated", _on_path_cost_updated)
	debug_print("MoveManager initialized")

func _input(event):
	if not can_process_input():
		return
	
	# Переключение режима атаки по нажатию на кнопку "A"
	if event is InputEventKey and event.pressed and event.keycode == KEY_A:
		toggle_attack_mode()
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
	elif event.is_action_pressed("ui_select") or event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		debug_print("End turn triggered via keyboard")
		request_end_turn()

func _process(delta):
	# Обновление направления взгляда при движении мыши в режиме атаки
	if attack_mode:
		update_facing_direction_to_mouse()

# Передвижение персонажа ------------------------------------

func handle_left_click(event):
	debug_print("Left click detected")
	var mouse_pos = get_global_mouse_position()
	var clicked_cell = landscape_layer.local_to_map(landscape_layer.to_local(mouse_pos))
	
	debug_print("Clicked cell: " + str(clicked_cell))
	
	if move_manager.is_cell_walkable(clicked_cell):
		debug_print("Cell is walkable")
		
		if clicked_cell == move_manager.selected_cell:
			start_movement(clicked_cell)
		else:
			select_cell(clicked_cell)
	else:
		debug_print("Cell is not walkable")

func handle_right_click():
	debug_print("Right click detected - clearing selection")
	move_manager.clear_selection()
	set_path([])
	emit_signal("path_cost_changed", 0)
	get_viewport().set_input_as_handled()

func select_cell(cell: Vector2i):
	if move_manager.select_cell(cell):
		debug_print("Selected cell: " + str(cell))
		set_path([])
	else:
		debug_print("Could not select cell: " + str(cell))
		set_path([])

func set_path(new_path: Array):
	path = new_path
	emit_signal("path_changed", path)

func start_movement(target_cell: Vector2i):
	debug_print("Starting movement to selected cell: " + str(target_cell))
	
	var calculated_path = move_manager.move_to_selected_cell()
	
	if calculated_path.size() == 0:
		debug_print("No valid path found!")
		set_path([])
		return
	
	set_path(calculated_path)
	movement_queue = calculated_path.duplicate()
	is_moving = true
	
	emit_signal("movement_started")
	debug_print("Path calculated: " + str(path))
	
	process_movement_queue()

func process_movement_queue():
	if movement_queue.size() == 0 or movement_in_progress:
		complete_movement()
		return
	
	var next_cell = movement_queue[0]
	debug_print("Moving to next cell: " + str(next_cell))
	
	movement_in_progress = true
	animate_move_to_cell(next_cell)

func animate_move_to_cell(target_cell: Vector2i):
	var target_position = landscape_layer.map_to_local(target_cell)
	var direction = global_position.direction_to(target_position)
	update_sprite_direction(direction)
	
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
	
	debug_print("Moved to cell: " + str(target_cell) + ", AP left: " + str(remaining_ap))
	
	process_movement_queue()

func complete_movement():
	if is_moving:
		is_moving = false
		debug_print("Movement completed")
		set_path([])
		emit_signal("move_finished")

# Система поля зрения и атаки ------------------------------------

func update_sprite_direction(direction: Vector2):
	facing_direction = direction.normalized()
	
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			sprite.flip_h = false
		else:
			sprite.flip_h = true
	
	debug_print("Updated facing direction: " + str(facing_direction))

func update_facing_direction_to_mouse():
	var mouse_pos = get_global_mouse_position()
	var direction_to_mouse = global_position.direction_to(mouse_pos)
	
	facing_direction = direction_to_mouse
	update_sprite_direction(direction_to_mouse)
	update_field_of_view()

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
		
		update_facing_direction_to_mouse()
		
		debug_print("Field of view angle: " + str(field_of_view_angle))
		debug_print("Max view distance: " + str(max_view_distance))
	else:
		debug_print("Attack mode disabled")
		visible_cells.clear()
		hit_chance_map.clear()
		available_attack_cells.clear()
		emit_signal("field_of_view_changed", [], {})
	
	queue_redraw() # Для отображения отладочной информации

func exit_attack_mode():
	if attack_mode:
		attack_mode = false
		visible_cells.clear()
		hit_chance_map.clear()
		available_attack_cells.clear()
		emit_signal("field_of_view_changed", [], {})
		debug_print("Exited attack mode")

# Обновленная функция для расчета поля зрения
func update_field_of_view():
	visible_cells.clear()
	hit_chance_map.clear()
	available_attack_cells.clear()
	
	# Получаем все клетки в максимальном радиусе обзора
	var cells_to_check = []
	var max_dist = max_view_distance
	
	for x in range(-max_dist, max_dist + 1):
		for y in range(-max_dist, max_dist + 1):
			var cell = current_cell + Vector2i(x, y)
			if cell != current_cell and current_cell.distance_to(cell) <= max_dist:
				cells_to_check.append(cell)
	
	# Для каждой клетки проверяем, находится ли она в поле зрения
	for cell in cells_to_check:
		if is_cell_visible(cell):
			visible_cells.append(cell)
			
			# Рассчитываем шанс попадания на основе расстояния
			var distance = current_cell.distance_to(cell)
			hit_chance_map[cell] = calculate_hit_chance(distance)
			
			# Проверяем, есть ли на клетке противник
			var enemy = find_enemy_at_cell(cell)
			if enemy:
				available_attack_cells.append(cell)
	
	# Отправляем сигнал для обновления визуализации
	emit_signal("field_of_view_changed", visible_cells, hit_chance_map)
	
	debug_print("Field of view updated: " + str(visible_cells.size()) + " visible cells, " + 
				str(available_attack_cells.size()) + " targetable enemies")

# Проверка видимости клетки
func is_cell_visible(target_cell: Vector2i) -> bool:
	# Проверка границ карты
	if target_cell.x < 0 or target_cell.y < 0 or target_cell.x >= map_generator.map_width or target_cell.y >= map_generator.map_height:
		return false
	
	# Получаем разницу координат
	var delta = target_cell - current_cell
	
	# Проверяем расстояние
	var distance = current_cell.distance_to(target_cell)
	if distance > max_view_distance:
		return false
	
	# Получаем направление к клетке в виде вектора
	var direction_to_cell = Vector2(delta.x, delta.y).normalized()
	
	# Угол между направлением взгляда и клеткой в градусах
	var angle_to_cell = rad_to_deg(facing_direction.angle_to(direction_to_cell))
	
	# Проверяем, находится ли в пределах угла обзора
	if abs(angle_to_cell) > field_of_view_angle / 2:
		return false
		
	# Проверка препятствий с помощью алгоритма Брезенхема
	return is_line_of_sight_clear(current_cell, target_cell)

# Проверка линии видимости с помощью алгоритма Брезенхема
func is_line_of_sight_clear(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	var line = get_line_between_cells(from_cell, to_cell)
	
	# Проверяем каждую клетку на пути (кроме начальной и конечной)
	for i in range(1, line.size() - 1):
		var cell = line[i]
		
		# Если клетка не проходима (стена или препятствие)
		if not map_generator.is_tile_walkable(cell.x, cell.y):
			return false
	
	return true

# Алгоритм Брезенхема для построения линии между клетками
func get_line_between_cells(from_cell: Vector2i, to_cell: Vector2i) -> Array:
	var line = []
	
	var x0 = from_cell.x
	var y0 = from_cell.y
	var x1 = to_cell.x
	var y1 = to_cell.y
	
	var dx = abs(x1 - x0)
	var dy = abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx - dy
	
	while true:
		line.append(Vector2i(x0, y0))
		
		if x0 == x1 and y0 == y1:
			break
			
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy
	
	return line

# Расчет шанса попадания на основе расстояния
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

# Поиск противника на указанной клетке
func find_enemy_at_cell(cell: Vector2i) -> Enemy:
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if enemy is Enemy and enemy.current_cell == cell:
			return enemy
	
	return null

# Обработка клика в режиме атаки
func handle_attack_click(event):
	debug_print("Attack click detected")
	var mouse_pos = get_global_mouse_position()
	var clicked_cell = landscape_layer.local_to_map(landscape_layer.to_local(mouse_pos))
	
	debug_print("Clicked cell for attack: " + str(clicked_cell))
	
	# Проверяем, есть ли на клетке противник и в поле зрения ли он
	var target_enemy = find_enemy_at_cell(clicked_cell)
	
	if target_enemy and clicked_cell in available_attack_cells:
		debug_print("Valid enemy target found, executing attack")
		execute_attack(target_enemy, clicked_cell)
	else:
		debug_print("No valid target at clicked cell or not in field of view")

# Выполнение атаки с учетом шанса попадания
func execute_attack(enemy: Enemy, target_cell: Vector2i):
	if remaining_ap < attack_cost:
		debug_print("Not enough AP to attack")
		return
	
	debug_print("Executing attack on enemy at " + str(target_cell))
	
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
	
	debug_print("Attack roll: " + str(hit_roll) + ", Hit successful: " + str(hit_successful))
	
	# Анимация атаки
	is_attacking = true
	animate_attack(enemy, hit_successful)
	
	# Отправляем сигналы
	emit_signal("attack_started", enemy)
	emit_signal("attack_executed", target_cell)
	
	# Выходим из режима атаки
	exit_attack_mode()

# Анимация атаки с учетом попадания или промаха
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
		debug_print("Enemy doesn't have take_damage_with_chance method")
		if hit_successful:
			enemy.take_damage(attack_damage)
	
	is_attacking = false

# Прочие функции ------------------------------------

func place_at_valid_starting_position():
	debug_print("Finding valid starting position...")
	
	for x in range(map_generator.map_width):
		for y in range(map_generator.map_height):
			if map_generator.is_tile_walkable(x, y):
				current_cell = Vector2i(x, y)
				global_position = landscape_layer.map_to_local(current_cell)
				
				debug_print("Starting position found at cell: " + str(current_cell) + 
					" world pos: " + str(global_position))
				return
	
	push_error("Не найдено ни одной проходимой клетки для размещения персонажа")

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

func can_process_input() -> bool:
	return game_controller and game_controller.can_player_act() and not is_moving and not is_attacking

func _on_path_cost_updated(cost: int):
	emit_signal("path_cost_changed", cost)
	debug_print("Path cost updated: " + str(cost))

func debug_print(message: String):
	if debug_mode:
		print(message)

# Обновление параметров атаки на основе оружия
func update_weapon_parameters():
	if current_weapon:
		attack_damage = current_weapon.damage
		effective_attack_range = current_weapon.effective_range
		base_hit_chance = current_weapon.base_hit_chance
		medium_distance_hit_chance = current_weapon.medium_hit_chance
		attack_cost = current_weapon.attack_cost
		
		debug_print("Weapon parameters updated: " + current_weapon.name)
		emit_signal("weapon_changed", current_weapon)

# Метод для экипировки нового оружия
func equip_weapon(weapon: Weapon):
	current_weapon = weapon
	update_weapon_parameters()
	debug_print("Equipped weapon: " + weapon.name)
