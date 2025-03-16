# В главной сцене
extends Node2D

@export var world_map: TileMapLayer

@onready var player_scene = preload("res://Character_GlobalMap.tscn")  # Загрузка сцены
@onready var highlight_tilemap: TileMapLayer = $HighLitghter
@onready var fog_of_war: TileMapLayer = $FogOfWarTilemap
@onready var camera: Camera2D = $Camera2D
@onready var context_menu: PanelContainer = $"ContextMenu"


var player

var is_cell_selected: bool = false
var selected_cell

var select_sound = preload("res://SoundDesign/Guitar_Pedal_B_6.wav")
var unselect_sound = preload("res://SoundDesign/Guitar_Pedal_B_5.wav")

func _ready():
	
	
	
	
	# 1. Выбираем стартовую позицию на карте (например, клетка 0,0)
	var start_cell = Vector2i(0, 0) # **Запасная стартовая клетка по умолчанию (на случай, если не найдем клетку с весом 1)**
	var possible_start_cells = [] # **Новый массив для хранения всех подходящих стартовых клеток**
	var found_start_cell = false

	# Перебираем все используемые клетки на карте
	for cell in world_map.get_used_cells():
		if world_map.get_move_cost_no_fog(cell) <= 10: # Проверяем вес клетки
			possible_start_cells.append(cell) # **Добавляем клетку в массив possible_start_cells**
			found_start_cell = true # Можно оставить, но по факту, если массив не пуст, значит клетки найдены

	if !possible_start_cells.is_empty(): # **Проверяем, не пуст ли массив possible_start_cells**
		start_cell = possible_start_cells.pick_random() # **Выбираем случайную клетку из массива**
	else:
		printerr("Warning: No tile with move cost 1 found! Using default start position (0,0).")
		# Можно добавить логику выбора другой запасной клетки, если нужно


	if !found_start_cell:
		printerr("Warning: No tile with move cost 1 found! Using default start position (0,0).")
		# Можно добавить логику выбора другой запасной клетки, если нужно
	
	# 2. Конвертируем координаты клетки в мировые координаты
	var world_position = world_map.map_to_local(start_cell)
	
	# 3. Создаём экземпляр персонажа
	player = player_scene.instantiate()
		
	# 4. Устанавливаем позицию
	player.position = world_position
	
	camera.global_position = player.position
	
	player.setup_map_reference(world_map)
	
	# 5. Добавляем персонажа как дочерний элемент
	add_child(player)
	
	highlight_tilemap.set_player(player)
	highlight_tilemap.set_main(self)
	
func _input(event):
	if event.is_action_pressed("left_click") and !player.is_moving and !context_menu.selected:
		var navigation = world_map.get_navigation()
		var mouse_pos = get_global_mouse_position()
		var target_cell = world_map.local_to_map(mouse_pos)
		if world_map.is_cell_passable(target_cell):
			var start_cell = world_map.local_to_map(player.position)
			var path = navigation.find_path_with_cost(start_cell, target_cell)
			if !path.is_empty():
				var path_cost = calculate_path_cost(path) # Используем calculate_path_cost из Main.gd (и теперь идентичную в character_global.gd)
				if path_cost <= player.move_points:
					if is_cell_selected and target_cell == selected_cell:
						player.start_movement(path)
						is_cell_selected = false
					elif !is_cell_selected:
						Utils._playSound(select_sound,0.8,1.2,-15)
						selected_cell = target_cell
						is_cell_selected = true
					elif is_cell_selected and target_cell != selected_cell:
						Utils._playSound(select_sound,0.8,1.2,-15)
						selected_cell = target_cell
						highlight_tilemap.manual_update()
					else:
						selected_cell = null
						is_cell_selected = false
						Utils._playSound(unselect_sound,0.8,1.2,-15)
	if event.is_action("right_click") and !player.is_moving:
		if is_cell_selected:
			Utils._playSound(unselect_sound,0.8,1.2,-15)
			is_cell_selected = false

func calculate_path_cost(path: Array[Vector2i]) -> int: # Функция расчета стоимости пути
	var total_cost = 0
	# **Изменено: Начинаем цикл со ВТОРОЙ клетки пути (индекс 1), чтобы пропустить ПЕРВУЮ клетку**
	for i in range(1, path.size()): # Цикл начинается с 1, а не с 0
		var cell = path[i] # Получаем клетку по индексу i (начиная со 2-й клетки)
		var cell_cost = world_map.get_move_cost(cell)
		total_cost += cell_cost
	return total_cost
