class_name AttackRangeVisualizer
extends Node2D

# Ссылки на другие узлы
@export var character_path: NodePath = "../Character"
@onready var character: Character = get_node_or_null(character_path)
@onready var landscape_layer: TileMapLayer = $"../Landscape"

# Цвета для визуализации разных зон
@export var fov_color: Color = Color(0.7, 0.7, 1, 0.05)        # Базовое поле зрения (голубой полупрозрачный)
@export var effective_range_color: Color = Color(0, 1, 0, 0.2)  # Эффективный радиус (зеленый)
@export var mid_range_color: Color = Color(1, 1, 0, 0.2)        # Средний радиус (желтый)
@export var long_range_color: Color = Color(1, 0.5, 0, 0.15)    # Дальний радиус (оранжевый)
@export var target_color: Color = Color(1, 0, 0, 0.4)           # Цель (красный)
@export var line_color: Color = Color(0.9, 0.9, 0.9, 0.3)       # Цвет сетки

# Настройки визуализации
@export var show_grid_lines: bool = true
@export var show_percent_text: bool = true
@export var show_range_circles: bool = true
@export_range(0, 10) var cell_border_thickness: float = 2.0
@export var cell_border_radius: float = 4.0
@export var target_animation: bool = true

# Данные для отрисовки
var visible_cells: Array = []
var target_cells: Array = []
var hit_chances: Dictionary = {}
var tile_size: Vector2
var animation_time: float = 0.0
var active: bool = false

# Шрифт для отображения процентов
var font: Font

func _ready():
	if not character:
		push_error("AttackRangeVisualizer: Character not found!")
		return
		
	if not landscape_layer:
		push_error("AttackRangeVisualizer: Landscape layer not found!")
		return
	
	# Подключаем сигналы для обновления поля зрения
	character.connect("field_of_view_changed", _on_field_of_view_changed)
	
	# Получаем размер тайла
	tile_size = landscape_layer.tile_set.tile_size
	
	# Инициализируем шрифт для отображения шансов попадания
	font = ThemeDB.fallback_font
	
	# Добавляем подписку на сигнал атаки
	if character.has_signal("attack_executed"):
		character.connect("attack_executed", _on_attack_executed)
	
	# По умолчанию невидимый
	modulate.a = 0.0

# Обработчик изменения поля зрения и целей
func _on_field_of_view_changed(fov_cells: Array, chances: Dictionary):
	visible_cells = fov_cells.duplicate()
	hit_chances = chances.duplicate()
	
	# Найдем клетки-цели среди видимых
	target_cells.clear()
	for cell in visible_cells:
		var enemy = character.find_enemy_at_cell(cell)
		if enemy:
			target_cells.append(cell)
	
	# Если есть видимые клетки, показываем визуализатор
	active = visible_cells.size() > 0
	modulate.a = 1.0 if active else 0.0
	
	# Запускаем анимацию
	if active and target_animation:
		animation_time = 0.0
	
	# Перерисовываем
	queue_redraw()

# Обработчик выполненной атаки - очищает визуализацию
func _on_attack_executed(_target_cell):
	# Очищаем данные
	visible_cells.clear()
	target_cells.clear()
	hit_chances.clear()
	active = false
	
	# Скрываем визуализатор
	modulate.a = 0.0
	
	# Перерисовываем
	queue_redraw()

func _process(delta):
	# Обновляем таймер анимации
	if active and target_animation:
		animation_time += delta
		queue_redraw()

# Отрисовка поля зрения и целей с разными шансами попадания
func _draw():
	if modulate.a <= 0.0 or not active:
		return
	
	# Рисуем круги диапазонов атаки если включено
	if show_range_circles:
		draw_range_circles()
	
	# Отрисовка линий сетки
	if show_grid_lines:
		draw_grid()
	
	# Отрисовка базового поля зрения
	draw_field_of_view()
	
	# Отрисовка целей атаки
	draw_targets()
	
	# Рисуем линию к цели если мышь над одной из них
	var mouse_target = get_target_under_mouse()
	if mouse_target != Vector2i(-1, -1):
		draw_targeting_line(mouse_target)

# Рисование всех клеток поля зрения
func draw_field_of_view():
	for cell in visible_cells:
		if cell in target_cells:
			continue
		
		var cell_center = landscape_layer.map_to_local(cell)
		var hit_chance = hit_chances[cell] if cell in hit_chances else 0
		
		# Определяем цвет в зависимости от шанса попадания
		var cell_color = fov_color
		if hit_chance >= character.base_hit_chance:
			cell_color = effective_range_color
		elif hit_chance >= character.medium_distance_hit_chance:
			cell_color = mid_range_color
		elif hit_chance > 0:
			cell_color = long_range_color
		
		# Рисуем стилизованный прямоугольник с закругленными углами
		var rect = Rect2(cell_center - tile_size/2, tile_size)
		draw_rect(rect, cell_color, true)
		
		# Рисуем рамку ячейки
		if cell_border_thickness > 0:
			var border_color = cell_color
			border_color.a = min(border_color.a + 0.2, 1.0)
			draw_rect(rect, border_color, false, cell_border_thickness, false)
		
		# Отображаем шанс попадания, если он есть и включено отображение
		if show_percent_text and hit_chance > 0:
			var text = str(hit_chance) + "%"
			var text_position = cell_center + Vector2(0, 2)
			draw_string_with_shadow(text, text_position, hit_chance)

# Рисование целей
func draw_targets():
	for cell in target_cells:
		var cell_center = landscape_layer.map_to_local(cell)
		var hit_chance = hit_chances[cell] if cell in hit_chances else 0
		
		# Рисуем пульсирующую рамку для цели
		var rect = Rect2(cell_center - tile_size/2, tile_size)
		draw_rect(rect, target_color, true)
		
		# Рисуем пульсирующую рамку
		var pulse = 0.5 + 0.5 * sin(animation_time * 5.0)
		var border_width = cell_border_thickness * (1.0 + pulse * 0.5)
		var border_color = target_color
		border_color.a = 0.7 + 0.3 * pulse
		draw_rect(rect, border_color, false, border_width, false)
		
		# Отображаем шанс попадания для цели
		if show_percent_text and hit_chance > 0:
			var text = str(hit_chance) + "%"
			var text_position = cell_center + Vector2(0, 2)
			draw_string_with_outline(text, text_position, hit_chance)

# Рисуем сетку для визуального разделения клеток
func draw_grid():
	var viewport_rect = get_viewport_rect()
	var start_cell = landscape_layer.local_to_map(to_local(viewport_rect.position - Vector2(100, 100)))
	var end_cell = landscape_layer.local_to_map(to_local(viewport_rect.end + Vector2(100, 100)))
	
	# Рисуем вертикальные линии
	for x in range(start_cell.x, end_cell.x + 1):
		var start = landscape_layer.map_to_local(Vector2i(x, start_cell.y))
		var end = landscape_layer.map_to_local(Vector2i(x, end_cell.y))
		draw_line(start, end, line_color, 1.0)
	
	# Рисуем горизонтальные линии
	for y in range(start_cell.y, end_cell.y + 1):
		var start = landscape_layer.map_to_local(Vector2i(start_cell.x, y))
		var end = landscape_layer.map_to_local(Vector2i(end_cell.x, y))
		draw_line(start, end, line_color, 1.0)

# Рисуем круги эффективного и среднего радиуса атаки
func draw_range_circles():
	var player_pos = landscape_layer.map_to_local(character.current_cell)
	var eff_radius = character.effective_attack_range * tile_size.x
	var med_radius = character.effective_attack_range * 2 * tile_size.x
	
	# Рисуем круг эффективного радиуса
	var eff_color = effective_range_color
	eff_color.a = 0.3
	draw_arc(player_pos - global_position, eff_radius, 0, TAU, 64, eff_color, 2.0)
	
	# Рисуем круг среднего радиуса
	var med_color = mid_range_color
	med_color.a = 0.3
	draw_arc(player_pos - global_position, med_radius, 0, TAU, 64, med_color, 2.0)

# Получаем цель под курсором мыши
func get_target_under_mouse() -> Vector2i:
	var mouse_pos = get_global_mouse_position()
	var mouse_cell = landscape_layer.local_to_map(landscape_layer.to_local(mouse_pos))
	
	if mouse_cell in target_cells:
		return mouse_cell
	
	# Возвращаем недопустимую позицию вместо null
	return Vector2i(-1, -1)

# Рисуем линию прицеливания к цели
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
		
	# Рисуем дугу вокруг цели
	var target_radius = tile_size.x * 0.6
	var arc_width = 3.0
	var arc_color = line_color
	
	var animation_phase = fmod(animation_time * 2.0, TAU)
	var arc_length = PI * 0.5
	draw_arc(end_pos, target_radius, animation_phase, animation_phase + arc_length, 16, arc_color, arc_width)
	draw_arc(end_pos, target_radius, animation_phase + PI, animation_phase + PI + arc_length, 16, arc_color, arc_width)

# Рисует текст с тенью для лучшей видимости
func draw_string_with_shadow(text: String, position: Vector2, hit_chance: int):
	var shadow_offset = Vector2(1, 1)
	var shadow_color = Color(0, 0, 0, 0.5)
	var text_color = Color.WHITE
	
	# Изменяем цвет в зависимости от шанса попадания
	if hit_chance >= 80:
		text_color = Color(0.2, 1, 0.2)
	elif hit_chance >= 40:
		text_color = Color(1, 1, 0.2)
	else:
		text_color = Color(1, 0.5, 0.2)
		
	# Рисуем тень
	draw_string(font, position + shadow_offset, text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, 14, shadow_color)
	
	# Рисуем текст
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, 14, text_color)

# Рисует текст с контуром для целей
func draw_string_with_outline(text: String, position: Vector2, hit_chance: int):
	var outline_size = 2
	var font_size = 16
	var text_color = Color.WHITE
	var outline_color = Color.BLACK
	
	# Изменяем цвет в зависимости от шанса попадания
	if hit_chance >= 80:
		text_color = Color(0.2, 1, 0.2)
	elif hit_chance >= 40:
		text_color = Color(1, 1, 0.2)
	else:
		text_color = Color(1, 0.5, 0.2)
	
	# Рисуем контур
	var outline_positions = [
		Vector2(-outline_size, -outline_size),
		Vector2(outline_size, -outline_size),
		Vector2(-outline_size, outline_size),
		Vector2(outline_size, outline_size),
		Vector2(-outline_size, 0),
		Vector2(outline_size, 0),
		Vector2(0, -outline_size),
		Vector2(0, outline_size)
	]
	
	# Рисуем контур
	for offset in outline_positions:
		draw_string(font, position + offset, text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size, outline_color)
	
	# Рисуем основной текст
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size, text_color)
