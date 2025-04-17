class_name Character
extends Node2D

# Сигналы
signal move_finished
signal end_turn_requested
signal cell_changed(old_cell, new_cell)
signal path_changed(new_path)
signal movement_started
signal path_cost_changed(cost)
signal attack_range_changed(cells)
signal attack_executed(target_cell)
signal attack_started(target_enemy)


# Настройки персонажа
@export var move_speed: float = 4.0
@export var action_points: int = 50
@export var allow_diagonal: bool = true
@export var debug_mode: bool = true
@export var attack_range: int = 30  # Максимальная дальность атаки в AP
@export var attack_cost: int = 20   # Стоимость атаки
@export var attack_damage: int = 25  # Базовый урон от атаки

# Состояние персонажа
var current_cell: Vector2i = Vector2i.ZERO
var is_moving: bool = false
var remaining_ap: int = action_points
var attack_mode: bool = false
var available_attack_cells: Array = []
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
	
	debug_print("Character._ready() completed, AP: " + str(remaining_ap))

# Проверка зависимостей
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

# Инициализация менеджера движения
func initialize_move_manager():
	move_manager = MoveManager.new()
	add_child(move_manager)
	move_manager.initialize(map_generator, current_cell, remaining_ap, action_points)
	
	# Подключаем сигнал о стоимости пути
	move_manager.connect("path_cost_updated", _on_path_cost_updated)
	
	debug_print("MoveManager initialized")

# Обработка ввода
# Обновите метод _input
func _input(event):
	# Обрабатываем только если сейчас ход игрока и персонаж не двигается
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

# Обработка левого клика
func handle_left_click(event):
	debug_print("Left click detected")
	var mouse_pos = get_global_mouse_position()
	var clicked_cell = landscape_layer.local_to_map(landscape_layer.to_local(mouse_pos))
	
	debug_print("Clicked cell: " + str(clicked_cell))
	
	# Проверяем, проходима ли выбранная клетка (не обязательно доступна)
	if move_manager.is_cell_walkable(clicked_cell):
		debug_print("Cell is walkable")
		
		# Если клетка уже выбрана и это та же самая клетка - начинаем движение
		if clicked_cell == move_manager.selected_cell:
			start_movement(clicked_cell)
		else:
			# Выбираем клетку
			select_cell(clicked_cell)
	else:
		debug_print("Cell is not walkable")

# Обработка правого клика
func handle_right_click():
	debug_print("Right click detected - clearing selection")
	move_manager.clear_selection()
	# Очищаем текущий путь и стоимость
	set_path([])
	emit_signal("path_cost_changed", 0)
	get_viewport().set_input_as_handled()

# Выбор клетки
func select_cell(cell: Vector2i):
	if move_manager.select_cell(cell):
		debug_print("Selected cell: " + str(cell))
		# Примечание: Мы не можем предварительно рассчитать путь здесь,
		# так как у MoveManager нет метода calculate_path
		# Просто очищаем текущий путь
		set_path([])
	else:
		debug_print("Could not select cell: " + str(cell))
		set_path([])

# Установка пути и оповещение подписчиков
func set_path(new_path: Array):
	path = new_path
	emit_signal("path_changed", path)

# Начало движения к клетке
func start_movement(target_cell: Vector2i):
	debug_print("Starting movement to selected cell: " + str(target_cell))
	
	# Получаем путь к целевой клетке
	var calculated_path = move_manager.move_to_selected_cell()
	
	# Проверяем, что путь существует
	if calculated_path.size() == 0:
		debug_print("No valid path found!")
		set_path([])  # Очищаем путь
		return
	
	# Сохраняем путь и начинаем движение
	set_path(calculated_path)
	movement_queue = calculated_path.duplicate()
	is_moving = true
	
	# Отправляем сигнал о начале движения
	emit_signal("movement_started")
	
	debug_print("Path calculated: " + str(path))
	
	# Запускаем процесс перемещения
	process_movement_queue()

# Обработка очереди движения
func process_movement_queue():
	# Если очередь пуста или персонаж уже двигается, выходим
	if movement_queue.size() == 0 or movement_in_progress:
		complete_movement()
		return
	
	# Получаем следующую клетку
	var next_cell = movement_queue[0]
	debug_print("Moving to next cell: " + str(next_cell))
	
	# Отмечаем, что движение в процессе
	movement_in_progress = true
	
	# Анимируем перемещение к клетке
	animate_move_to_cell(next_cell)

# Анимация перемещения к клетке
# Анимация перемещения к клетке
func animate_move_to_cell(target_cell: Vector2i):
	# Получаем позицию целевой клетки в мировых координатах
	var target_position = landscape_layer.map_to_local(target_cell)
	
	# Рассчитываем направление движения
	var direction = global_position.direction_to(target_position)
	update_sprite_direction(direction)
	
	# Рассчитываем расстояние
	var distance = global_position.distance_to(target_position)
	
	# Рассчитываем продолжительность анимации (постоянная скорость)
	var duration = distance / (move_speed * landscape_layer.tile_set.tile_size.x)
	
	# Останавливаем предыдущий tween, если он активен
	if tween and tween.is_running():
		tween.kill()
	
	# Создаем новый tween для анимации движения
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "global_position", target_position, duration)
	
	# Ждем завершения анимации
	await tween.finished
	
	# Обновляем текущую клетку и уменьшаем очки действия
	var old_cell = current_cell
	current_cell = target_cell
	
	# Рассчитываем стоимость перемещения
	var move_cost = 10
	if abs(direction.x) > 0 and abs(direction.y) > 0:
		move_cost = 15
	
	remaining_ap -= move_cost
	
	# Обновляем менеджер
	move_manager.character_cell = current_cell
	move_manager.current_ap = remaining_ap
	move_manager.update_available_cells()
	
	# Уведомляем о смене клетки
	emit_signal("cell_changed", old_cell, current_cell)
	
	# Удаляем обработанную клетку из очереди и из отображаемого пути
	movement_queue.remove_at(0)
	
	# Обновляем отображаемый путь
	var new_path = movement_queue.duplicate()
	set_path(new_path)
	
	# Отмечаем, что текущий шаг движения завершен
	movement_in_progress = false
	
	debug_print("Moved to cell: " + str(target_cell) + ", AP left: " + str(remaining_ap))
	
	# Продолжаем обработку очереди
	process_movement_queue()

# Обновление направления спрайта
func update_sprite_direction(direction: Vector2):
	if abs(direction.x) > abs(direction.y):
		# Горизонтальное движение
		if direction.x > 0:
			# Поворот вправо
			sprite.flip_h = false
		else:
			# Поворот влево
			sprite.flip_h = true

# Завершение всего движения
func complete_movement():
	if is_moving:
		is_moving = false
		debug_print("Movement completed")
		# Очищаем путь
		set_path([])
		emit_signal("move_finished")

# Размещение на начальной позиции
func place_at_valid_starting_position():
	debug_print("Finding valid starting position...")
	
	# Ищем первую проходимую клетку
	for x in range(map_generator.map_width):
		for y in range(map_generator.map_height):
			if map_generator.is_tile_walkable(x, y):
				current_cell = Vector2i(x, y)
				
				# Преобразуем координаты клетки в мировые координаты
				global_position = landscape_layer.map_to_local(current_cell)
				
				debug_print("Starting position found at cell: " + str(current_cell) + 
					" world pos: " + str(global_position))
				return
	
	# Если не нашли проходимую клетку, выводим ошибку
	push_error("Не найдено ни одной проходимой клетки для размещения персонажа")

# Запрос на завершение хода
func request_end_turn():
	debug_print("End turn requested")
	emit_signal("end_turn_requested")
	end_turn()

# Завершение хода
func end_turn():
	# Останавливаем текущие действия
	is_moving = false
	movement_queue.clear()
	set_path([])  # Очищаем путь
	
	if tween and tween.is_running():
		tween.kill()
	
	# Восстанавливаем очки действия
	remaining_ap = action_points
	
	# Обновляем данные в менеджере
	move_manager.restore_ap()
	
	# Сигнал о завершении хода
	emit_signal("move_finished")
	debug_print("Turn ended, AP restored: " + str(remaining_ap))

# Функция для отладочного вывода
func debug_print(message: String):
	if debug_mode:
		print(message)

# Для поддержки _process
func _process(delta):
	# Здесь ничего не делаем, потому что мы используем tween для движения
	pass

# Добавим обработчик для передачи стоимости пути
func _on_path_cost_updated(cost: int):
	emit_signal("path_cost_changed", cost)
	debug_print("Path cost updated: " + str(cost))

# Переключение режима атаки
func toggle_attack_mode():
	# Если режим атаки выключен и мы хотим его включить, проверяем AP
	if !attack_mode:
		# Проверяем, хватает ли AP для атаки
		if remaining_ap < attack_cost:
			debug_print("Недостаточно AP для атаки! Необходимо: " + str(attack_cost) + ", имеется: " + str(remaining_ap))
			# Можно добавить всплывающее сообщение для игрока
			# show_message("Недостаточно энергии для атаки!")
			return
	
	attack_mode = !attack_mode
	
	if attack_mode:
		debug_print("Attack mode enabled")
		move_manager.clear_selection()
		set_path([]) # Очищаем путь перемещения
		
		# Рассчитываем доступные клетки для атаки
		available_attack_cells = calculate_attack_cells()
		emit_signal("attack_range_changed", available_attack_cells)
	else:
		debug_print("Attack mode disabled")
		available_attack_cells.clear()
		emit_signal("attack_range_changed", [])

# Выход из режима атаки
func exit_attack_mode():
	if attack_mode:
		attack_mode = false
		available_attack_cells.clear()
		emit_signal("attack_range_changed", [])
		debug_print("Exited attack mode")

# Расчет доступных клеток для атаки
func calculate_attack_cells() -> Array:
	var attack_cells = []
	
	# Находим всех противников в сцене
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if enemy is Enemy:
			# Рассчитываем стоимость пути до противника
			var path_to_enemy = move_manager.find_path_to_any_cell(current_cell, enemy.current_cell)
			var path_cost = move_manager.calculate_path_cost(path_to_enemy)
			
			# Если стоимость пути меньше или равна радиусу атаки и у нас достаточно AP
			if path_cost <= attack_range and remaining_ap >= attack_cost:
				attack_cells.append(enemy.current_cell)
	
	return attack_cells

# Обработка клика в режиме атаки
func handle_attack_click(event):
	debug_print("Attack click detected")
	var mouse_pos = get_global_mouse_position()
	var clicked_cell = landscape_layer.local_to_map(landscape_layer.to_local(mouse_pos))
	
	debug_print("Clicked cell for attack: " + str(clicked_cell))
	
	# Проверяем, есть ли на клетке противник и в радиусе атаки ли он
	var target_enemy = find_enemy_at_cell(clicked_cell)
	
	if target_enemy and is_cell_in_attack_range(clicked_cell):
		debug_print("Valid enemy target found, executing attack")
		execute_attack(target_enemy, clicked_cell)
	else:
		debug_print("No valid target at clicked cell or out of attack range")

# Поиск противника на указанной клетке
func find_enemy_at_cell(cell: Vector2i) -> Enemy:
	# Находим всех противников в сцене
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if enemy is Enemy and enemy.current_cell == cell:
			return enemy
	
	return null

# Проверка, находится ли клетка в радиусе атаки
func is_cell_in_attack_range(cell: Vector2i) -> bool:
	return cell in available_attack_cells

# Выполнение атаки
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
	
	# Анимация атаки
	is_attacking = true
	animate_attack(enemy)
	
	# Отправляем сигналы
	emit_signal("attack_started", enemy)
	emit_signal("attack_executed", target_cell)
	
	# Выходим из режима атаки
	exit_attack_mode()

# Анимация атаки
# Исправьте метод animate_attack в Character.gd
func animate_attack(enemy: Enemy):
	# Здесь можно добавить анимацию атаки
	var original_pos = global_position
	var enemy_pos = enemy.global_position
	var direction = original_pos.direction_to(enemy_pos)
	
	# Рывок на 1/3 расстояния к цели
	var dash_pos = original_pos + direction * original_pos.distance_to(enemy_pos) * 0.3
	
	# Создаем твин для анимации
	if tween and tween.is_running():
		tween.kill()
	
	tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	
	# Рывок вперед
	tween.tween_property(self, "global_position", dash_pos, 0.15)
	
	# Возврат назад
	tween.tween_property(self, "global_position", original_pos, 0.3)
	
	# Применение урона после анимации
	await tween.finished
	
	# ВАЖНО: Перенесите урон в GameController
	# НЕ применяйте урон здесь!
	# enemy.take_damage(attack_damage) - УДАЛИТЕ ЭТУ СТРОКУ
	
	debug_print("Attack animation completed")
	
	# Убираем флаг атаки
	is_attacking = false

# Обновите метод can_process_input
func can_process_input() -> bool:
	return game_controller and game_controller.can_player_act() and not is_moving and not is_attacking
