# HighlightTileMap.gd
extends TileMapLayer

@export var highlight_atlas_coord: Vector2i = Vector2i(0, 0)
@export var highlight_animation_speed: float = 0.15

@onready var world_map: TileMapLayer = get_node("../WorldMap")
@onready var path_cost_label: Label = $PathCostLabel
@onready var fog_of_war: TileMapLayer = $"../FogOfWarTilemap"

@onready var tooltip_panel: PanelContainer = $"../CanvasLayer/MarginContainer/Tooltip"
@onready var tooltip_text_name: Label = $"../CanvasLayer/MarginContainer/Tooltip/MarginContainer/VBoxContainer/Name"
@onready var tooltip_text_descr: RichTextLabel = $"../CanvasLayer/MarginContainer/Tooltip/MarginContainer/VBoxContainer/Description"

var main
var player

var tween: Tween

var path_highlighted_cells = [] # Список клеток, подсвеченных как путь

var last_cell: Vector2i = Vector2i(-1, -1)

func _ready():
	modulate = Color(1, 1, 1, 1) # Белый цвет по умолчанию
	z_index = 10
	tween = create_tween()
	tween.set_parallel(true) # Разрешить параллельные анимации
	
func set_player(player_object):
	player = player_object # Сохраняем переданный объект персонажа в переменной player

func set_main(main_object):
	main = main_object # Сохраняем переданный объект Main.gd в переменной main
	
func _input(event: InputEvent):
	if event is InputEventMouseMotion:
		var mouse_pos: Vector2 = get_global_mouse_position()
		var tile_pos: Vector2i = world_map.local_to_map(mouse_pos)

		if is_out_of_bounds(tile_pos):
			clear_highlight()
			return
		if tile_pos != last_cell:
			#--------------------------------Реализуем tooltip----------------------------------
			if tween.is_running():
				tween.kill()
			if fog_of_war.is_tile_visible(tile_pos):
				create_tween().tween_property(tooltip_panel,"modulate:a",1,0.1)
				var data = world_map.get_tile_tooltip_data(tile_pos)
				tooltip_text_name.text = data.name
				tooltip_text_descr.text = "[center]" + data.descr + "[/center]"
				
				update_highlight(tile_pos)
				last_cell = tile_pos
			else:
				create_tween().tween_property(tooltip_panel,"modulate:a",0,0.1)
				
				clear_path_highlight()
				clear_target_highlight()
				modulate = Color(1, 0, 0, 1) # Красный цвет
				if world_map.is_cell_passable(tile_pos): # Подсвечиваем красным только проходимые клетки
					set_cell(tile_pos, 0, highlight_atlas_coord)
					path_cost_label.visible = false
				else:
					clear_highlight()
					path_cost_label.visible = false # Если клетка непроходима, просто убираем подсветку
			#-----------------------------------------------------------------------------------
			

func is_out_of_bounds(pos: Vector2i) -> bool:
	return pos.x < 0 || pos.y < 0 || pos.x >= world_map.Width || pos.y >= world_map.Height

func update_highlight(cell_pos: Vector2i):
	clear_path_highlight()
	clear_target_highlight()
	
	var start_cell = world_map.local_to_map(player.position) # Теперь player точно не null 
	var path = world_map.navigation.find_path_with_cost(start_cell, cell_pos) # Ищем путь через CustomNavigation
	var path_cost = main.calculate_path_cost(path) # Рассчитываем стоимость пути

	if !path.is_empty() && path_cost <= player.move_points:
		# Клетка досягаема - белая обводка
		modulate = Color(1, 1, 1, 1) # Белый цвет
		set_cell(cell_pos, 0, highlight_atlas_coord)
		
		path_cost_label.text = str(path_cost)
		path_cost_label.visible = true
		
		# Позиционируем Label в центре клетки
		var cell_center_pos = world_map.map_to_local(cell_pos)
		path_cost_label.position = cell_center_pos - path_cost_label.size / 2 # Центрируем Label относительно клетки
		
		highlight_path(path)
		
	else:
		# Клетка не досягаема - красная обводка
		modulate = Color(1, 0, 0, 1) # Красный цвет
		if world_map.is_cell_passable(cell_pos): # Подсвечиваем красным только проходимые клетки
			set_cell(cell_pos, 0, highlight_atlas_coord)
			path_cost_label.visible = false
		else:
			clear_highlight()
			path_cost_label.visible = false # Если клетка непроходима, просто убираем подсветку

func clear_highlight_cells():
	for cell in get_used_cells():
		erase_cell(cell)

func clear_highlight():
	clear_highlight_cells()
	last_cell = Vector2i(-1, -1)
	modulate = Color(1, 1, 1, 1) # Возвращаем белый цвет по умолчанию (хотя это не обязательно)
	
func manual_update():
	var mouse_pos: Vector2 = get_global_mouse_position()
	var tile_pos: Vector2i = world_map.local_to_map(mouse_pos)
	
	if is_out_of_bounds(tile_pos):
		clear_highlight()
		return
		
	update_highlight(tile_pos)
	last_cell = tile_pos

func highlight_path(path: Array[Vector2i]):
	# Подсвечиваем все клетки ПУТИ, кроме первой (позиции игрока) и последней (целевой)
	for i in range(1, path.size() - 1): # Исключаем первую и последнюю клетки
		var path_cell = path[i]
		set_cell(path_cell, 1, Vector2i(0,0)) # Используем тайл подсветки ПУТИ
		path_highlighted_cells.append(path_cell) # Добавляем в список подсвеченных клеток пути

func clear_target_highlight():
	# Очищаем подсветку ТОЛЬКО ЦЕЛЕВОЙ клетки (белую/красную обводку и текст стоимости)
	for cell in get_used_cells():
		if cell not in path_highlighted_cells: # Убеждаемся, что не стираем подсветку пути
			erase_cell(cell)
	path_cost_label.visible = false # Скрываем label стоимости
	
func clear_path_highlight():
	# Очищаем подсветку ПУТИ
	for cell in path_highlighted_cells:
		erase_cell(cell)
	path_highlighted_cells.clear() # Очищаем список подсвеченных клеток пути
	
	
