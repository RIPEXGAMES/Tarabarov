extends CharacterBody2D

@onready var action_points_label: Label = $UIAnchor/ActionPointsLabel
@onready var highlight: TileMapLayer = $"../HighLitghter"
@onready var fog_of_war_tilemap: TileMapLayer = $"../FogOfWarTilemap"

@export var move_speed: float = 200.0  # Пикселей в секунду
@export var view_range: int = 3
var move_points: int = 1000  # Очки движения за ход
var current_path: Array[Vector2i] = []  # Текущий путь
var is_moving: bool = false  # В движении ли персонаж
var world_map: TileMapLayer
var many_times_moved = 0

@onready var timer: Control = $"../CanvasLayer/MarginContainer2/PanelContainer"

func _ready() -> void:
	update_action_points(move_points)
	timer.update(move_points)
	fog_of_war_tilemap.update_fog_of_war(world_map.local_to_map(position), view_range)
	
func _input(event):
	if event.is_action_pressed("space") and !current_path.is_empty() and is_moving:
		current_path = []
		

func setup_map_reference(map: TileMapLayer):
	world_map = map
	
# Вызывается для начала движения
func start_movement(path: Array[Vector2i]):
	if path.is_empty() || is_moving:
		return
	current_path = path
	is_moving = true # Используем calculate_path_cost (теперь правильно модифицированную)

	###move_points -= path_cost # Вычитаем затраты (теперь правильно рассчитанные)
	###update_action_points(move_points)
	move_to_next_point()
	

# Перемещение к следующей точке пути
func move_to_next_point():
	if current_path.is_empty():		
		is_moving = false
		many_times_moved = 0
		highlight.manual_update()
		return
	
	var next_cell = current_path.pop_front()
	var target_pos = world_map.map_to_local(next_cell)
	
	if many_times_moved > 0:
		var move_cost = world_map.get_move_cost(next_cell)
		move_points -= move_cost
		update_action_points(move_points)
		timer.update(move_points)
		
	fog_of_war_tilemap.update_fog_of_war(next_cell, view_range)
	
	var tween = create_tween()
	if many_times_moved > 0:
		tween.tween_property(self, "position", target_pos, 0.3)
	else:
		tween.tween_property(self, "position", target_pos, 0.1)
	tween.tween_callback(move_to_next_point)
	many_times_moved += 1
	highlight.manual_update()
	

func update_action_points(points: int):
	action_points_label.text = str(points)
	# Анимация для визуальной обратной связи
	var tween = create_tween().set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(action_points_label, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(action_points_label, "scale", Vector2.ONE, 0.3)
	
func calculate_path_cost(path: Array[Vector2i]) -> int: # Функция расчета стоимости пути
	var total_cost = 0
	# **Изменено: Начинаем цикл со ВТОРОЙ клетки пути (индекс 1), чтобы пропустить ПЕРВУЮ клетку**
	for i in range(1, path.size()): # Цикл начинается с 1, а не с 0
		var cell = path[i] # Получаем клетку по индексу i (начиная со 2-й клетки)
		var cell_cost = world_map.get_move_cost(cell)
		total_cost += cell_cost # Отладка общей стоимости (изменено название для ясности)
	return total_cost
