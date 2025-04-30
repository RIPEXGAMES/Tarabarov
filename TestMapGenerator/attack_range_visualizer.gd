class_name AttackRangeVisualizer
extends Node2D

#region Экспортируемые настройки
# Ссылки на узлы
@export var character_path: NodePath = "../Character"

# Цвета для визуализации разных зон
@export var fov_color: Color = Color(0.7, 0.7, 1, 0.05)        # Базовое поле зрения (голубой)
@export var effective_range_color: Color = Color(0, 1, 0, 0.2)  # Эффективный радиус (зеленый)
@export var mid_range_color: Color = Color(1, 1, 0, 0.2)        # Средний радиус (желтый)
@export var long_range_color: Color = Color(1, 0.5, 0, 0.15)    # Дальний радиус (оранжевый)
@export var target_color: Color = Color(1, 0, 0, 0.4)           # Цель (красный)
@export var line_color: Color = Color(0.9, 0.9, 0.9, 0.3)       # Цвет сетки

# Настройки визуализации
@export var show_percent_text: bool = true
@export var show_range_circles: bool = true
@export_range(0, 10) var cell_border_thickness: float = 2.0
@export var cell_border_radius: float = 4.0
@export var target_animation: bool = true
#endregion

#region Внутренние переменные
# Ссылки на узлы
@onready var character: Character = get_node_or_null(character_path)
@onready var landscape_layer: TileMapLayer = $"../Landscape"

# Данные для отрисовки
var visible_cells: Array = []
var target_cells: Array = []
var hit_chances: Dictionary = {}
var tile_size: Vector2
var animation_time: float = 0.0
var active: bool = false

# Константы для отрисовки
const FONT_SIZE: int = 16
const OUTLINE_SIZE: int = 2
const TAU: float = 6.28318530718  # 2 * PI

# Шрифт для отображения процентов
var font: Font
#endregion

#region Инициализация
func _ready():
	if not character:
		push_error("AttackRangeVisualizer: Character not found!")
		return
		
	if not landscape_layer:
		push_error("AttackRangeVisualizer: Landscape layer not found!")
		return
	
	# Подключаем сигналы
	character.connect("field_of_view_changed", _on_field_of_view_changed)
	if character.has_signal("attack_executed"):
		character.connect("attack_executed", _on_attack_executed)
	
	character.connect("direction_changed", _on_direction_changed)
	
	# Получаем размер тайла и шрифт
	tile_size = landscape_layer.tile_set.tile_size
	font = ThemeDB.fallback_font
	
	# По умолчанию невидимый
	modulate.a = 0.0
#endregion

#region Обработка сигналов и процессы
func _on_field_of_view_changed(fov_cells: Array, chances: Dictionary):
	visible_cells = fov_cells.duplicate()
	hit_chances = chances.duplicate()
	
	# Находим клетки с целями
	target_cells.clear()
	for cell in visible_cells:
		if character.find_enemy_at_cell(cell):
			target_cells.append(cell)
	
	# Управляем видимостью
	active = visible_cells.size() > 0
	modulate.a = 1.0 if active else 0.0
	
	# Запускаем анимацию
	if active and target_animation:
		animation_time = 0.0
	
	queue_redraw()

func _on_attack_executed(_target_cell):
	# Очищаем данные и скрываем визуализатор
	visible_cells.clear()
	target_cells.clear()
	hit_chances.clear()
	active = false
	modulate.a = 0.0
	queue_redraw()

func _process(delta):
	if active and target_animation:
		animation_time += delta
		queue_redraw()
#endregion

#region Методы отрисовки
func _draw():
	if modulate.a <= 0.0 or not active:
		return
	
	# Рисуем основные элементы
	if show_range_circles:
		draw_range_circles()
	
	draw_field_of_view()
	draw_targets()
	
	# Проверяем наличие цели под мышью
	var mouse_target = get_target_under_mouse()
	if mouse_target != Vector2i(-1, -1):
		draw_targeting_line(mouse_target)

func draw_field_of_view():
	# Безопасная проверка
	if visible_cells.size() == 0:
		return
		
	for cell in visible_cells:
		if cell in target_cells:
			continue
		
		if not is_valid_cell(cell):
			continue
			
		var cell_center = landscape_layer.map_to_local(cell)
		var hit_chance = hit_chances.get(cell, 0)
		
		# Определяем цвет в зависимости от шанса попадания
		var cell_color = get_cell_color_by_hit_chance(hit_chance)
		
		# Рисуем клетку и рамку
		var rect = Rect2(cell_center - tile_size/2, tile_size)
		draw_rect(rect, cell_color, true)
		
		if cell_border_thickness > 0:
			var border_color = cell_color
			border_color.a = min(border_color.a + 0.2, 1.0)
			draw_rect(rect, border_color, false, cell_border_thickness, false)

func draw_targets():
	for cell in target_cells:
		if not is_valid_cell(cell):
			continue
			
		var cell_center = landscape_layer.map_to_local(cell)
		var hit_chance = hit_chances.get(cell, 0)
		
		# Рисуем цель
		var rect = Rect2(cell_center - tile_size/2, tile_size)
		draw_rect(rect, target_color, true)
		
		# Анимированная рамка
		var pulse = 0.5 + 0.5 * sin(animation_time * 5.0)
		var border_width = cell_border_thickness * (1.0 + pulse * 0.5)
		var border_color = target_color
		border_color.a = 0.7 + 0.3 * pulse
		draw_rect(rect, border_color, false, border_width, false)
		
		# Отображаем шанс попадания
		if show_percent_text and hit_chance > 0:
			var text = str(hit_chance) + "%"
			var text_position = cell_center + Vector2(0, 2)
			draw_string_with_outline(text, text_position, hit_chance)

func draw_range_circles():
	var player_pos = landscape_layer.map_to_local(character.current_cell)
	var eff_radius = character.effective_attack_range * tile_size.x
	var med_radius = character.effective_attack_range * 2 * tile_size.x
	var center_pos = player_pos - global_position
	
	# Рисуем круги радиусов
	var eff_color = effective_range_color
	eff_color.a = 0.3
	draw_arc(center_pos, eff_radius, 0, TAU, 64, eff_color, 2.0)
	
	var med_color = mid_range_color
	med_color.a = 0.3
	draw_arc(center_pos, med_radius, 0, TAU, 64, med_color, 2.0)

func draw_targeting_line(target_cell: Vector2i):
	var start_pos = landscape_layer.map_to_local(character.current_cell) - global_position
	var end_pos = landscape_layer.map_to_local(target_cell) - global_position
	
	# Рисуем пунктирную линию
	var dash_length = 5
	var gap_length = 3
	var distance = start_pos.distance_to(end_pos)
	var direction = (end_pos - start_pos).normalized()
	var total_segments = int(distance / (dash_length + gap_length))
	
	var line_color = Color(1, 0, 0, 0.8)
	var current_pos = start_pos
	
	for i in range(total_segments):
		var dash_start = current_pos
		var dash_end = current_pos + direction * dash_length
		
		draw_line(dash_start, dash_end, line_color, 2.0)
		current_pos = dash_end + direction * gap_length
	
	# Дорисовываем оставшийся кусок
	if current_pos.distance_to(end_pos) > 0:
		draw_line(current_pos, end_pos, line_color, 2.0)
		
	# Рисуем анимированную дугу вокруг цели
	var target_radius = tile_size.x * 0.6
	var arc_width = 3.0
	var arc_color = line_color
	
	var animation_phase = fmod(animation_time * 2.0, TAU)
	var arc_length = PI * 0.5
	draw_arc(end_pos, target_radius, animation_phase, animation_phase + arc_length, 16, arc_color, arc_width)
	draw_arc(end_pos, target_radius, animation_phase + PI, animation_phase + PI + arc_length, 16, arc_color, arc_width)
#endregion

#region Вспомогательные методы
func get_target_under_mouse() -> Vector2i:
	var mouse_pos = get_global_mouse_position()
	var mouse_cell = landscape_layer.local_to_map(landscape_layer.to_local(mouse_pos))
	
	if mouse_cell in target_cells:
		return mouse_cell
	
	return Vector2i(-1, -1)

func get_cell_color_by_hit_chance(hit_chance: int) -> Color:
	if hit_chance >= character.base_hit_chance:
		return effective_range_color
	elif hit_chance >= character.medium_distance_hit_chance:
		return mid_range_color
	elif hit_chance > 0:
		return long_range_color
	return fov_color

func get_text_color_by_hit_chance(hit_chance: int) -> Color:
	if hit_chance >= 80:
		return Color(0.2, 1, 0.2)
	elif hit_chance >= 40:
		return Color(1, 1, 0.2)
	return Color(1, 0.5, 0.2)

func draw_string_with_outline(text: String, position: Vector2, hit_chance: int):
	var text_color = get_text_color_by_hit_chance(hit_chance)
	var outline_color = Color.BLACK
	
	# Создаем позиции для контура
	var outline_positions = [
		Vector2(-OUTLINE_SIZE, -OUTLINE_SIZE),
		Vector2(OUTLINE_SIZE, -OUTLINE_SIZE),
		Vector2(-OUTLINE_SIZE, OUTLINE_SIZE),
		Vector2(OUTLINE_SIZE, OUTLINE_SIZE),
		Vector2(-OUTLINE_SIZE, 0),
		Vector2(OUTLINE_SIZE, 0),
		Vector2(0, -OUTLINE_SIZE),
		Vector2(0, OUTLINE_SIZE)
	]
	
	# Рисуем контур
	for offset in outline_positions:
		draw_string(font, position + offset, text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, FONT_SIZE, outline_color)
	
	# Рисуем основной текст
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, FONT_SIZE, text_color)

# Проверка валидности клетки для предотвращения ошибок
func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < landscape_layer.get_used_rect().size.x and cell.y < landscape_layer.get_used_rect().size.y
#endregion

# Вызываем эту функцию при изменении направления персонажа
func _on_direction_changed(_direction_index):
	if character.attack_mode:
		update_display()

func update_display():
	# Делаем визуализатор видимым только в режиме атаки
	active = character.attack_mode
	modulate.a = 1.0 if active else 0.0
	
	if active:
		# Обновляем поле зрения на основе текущего направления персонажа
		visible_cells = character.visible_cells.duplicate()
		hit_chances = character.hit_chance_map.duplicate()
		
		# Находим клетки с целями
		target_cells.clear()
		for cell in visible_cells:
			if character.find_enemy_at_cell(cell):
				target_cells.append(cell)
				
		# Запускаем анимацию
		if target_animation:
			animation_time = 0.0
			
		queue_redraw()
