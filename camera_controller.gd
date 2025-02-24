extends Camera2D

# Настройки экспорта
@export var tilemap_layer: TileMapLayer
@export var zoom_speed: float = 0.08
@export var min_zoom: float = 1.2
@export var max_zoom: float = 3.0
@export var drag_sensitivity: float = 1     # Базовый множитель
@export var inertia_damping: float = 0.94     # Меньше = быстрее остановка
@export var zoom_resistance: float = 0.5    # Сила сопротивления у границ
@export var zoom_snap_back: float = 4.0     # Сила возврата к границам

@export var edge_pull_strength: float = 0.1    # Сила притяжения к краям
@export var edge_damping: float = 0.1        # Замедление у краев
@export var edge_threshold: float = 10.0     # Расстояние до края для эффекта
@export var snap_back_speed: float = 5      # Скорость возврата в границы

@export var zoom_snap_back_force: float = 0.5  # Сила возврата к допустимому зуму



var is_zoom_out_of_bounds: bool = false

var edge_force: Vector2 = Vector2.ZERO

# Внутренние переменные
var target_zoom: Vector2 = Vector2.ONE
var is_dragging: bool = false
var velocity: Vector2 = Vector2.ZERO
var map_limits: Rect2

func _ready():
	var map_width = tilemap_layer.get_map_width_pixels()
	var map_height = tilemap_layer.get_map_height_pixels()
	map_limits = Rect2(0, 0, map_width, map_height)
	target_zoom = zoom

func _input(event):
	# Обработка зума
	if event is InputEventMouseButton:
		handle_zoom(event)
	
	# Обработка перетаскивания через относительное движение
	if event is InputEventMouseMotion and is_dragging:
		handle_drag(event)

	if event.is_action_pressed("right_click"):
		start_drag(event)
	
	if event.is_action_released("right_click"):
		end_drag()

func _process(delta):
	apply_inertia(delta)
	apply_edge_pull(delta)
	apply_zoom_bounds(delta)
	clamp_camera_position()
	update_zoom(delta)
	
	
func apply_zoom_bounds(delta: float):
	# Сила притяжения к границам
	if target_zoom.x > max_zoom:
		var overflow = target_zoom.x - max_zoom
		target_zoom.x -= overflow * zoom_snap_back * delta
	elif target_zoom.x < min_zoom:
		var underflow = min_zoom - target_zoom.x
		target_zoom.x += underflow * zoom_snap_back * delta
	
	# Окончательный clamp для безопасности
	target_zoom.x = clamp(target_zoom.x, min_zoom * 0.8, max_zoom * 1.2)
	target_zoom.y = target_zoom.x

func apply_edge_pull(delta: float):
	var edge_buffer = edge_threshold / zoom.x
	edge_force = Vector2.ZERO
	
	# Расчет сил для X
	if global_position.x < edge_buffer:
		edge_force.x = (edge_buffer - global_position.x) * edge_pull_strength
	elif global_position.x > map_limits.end.x - edge_buffer:
		edge_force.x = (map_limits.end.x - edge_buffer - global_position.x) * edge_pull_strength
		
	# Расчет сил для Y
	if global_position.y < edge_buffer:
		edge_force.y = (edge_buffer - global_position.y) * edge_pull_strength
	elif global_position.y > map_limits.end.y - edge_buffer:
		edge_force.y = (map_limits.end.y - edge_buffer - global_position.y) * edge_pull_strength
		
	# Применяем силы
	velocity += edge_force * delta
	velocity *= edge_damping

func handle_zoom(event: InputEventMouseButton):
	var zoom_dir = 0
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP: zoom_dir = 1
		MOUSE_BUTTON_WHEEL_DOWN: zoom_dir = -1
	
	var zoom_change = zoom_speed * zoom_dir
	
	# Добавляем сопротивление у границ
	if zoom_dir > 0 and target_zoom.x > max_zoom - 0.2:
		zoom_change *= lerp(0.0, 1.0, (max_zoom - target_zoom.x) / 0.2)
	elif zoom_dir < 0 and target_zoom.x < min_zoom + 0.2:
		zoom_change *= lerp(0.0, 1.0, (target_zoom.x - min_zoom) / 0.2)
	
	target_zoom += Vector2.ONE * zoom_change

func start_drag(_event: InputEventMouse):
	is_dragging = true
	velocity = Vector2.ZERO
	get_viewport().set_input_as_handled()

func end_drag():
	is_dragging = false

func handle_drag(event: InputEventMouseMotion):
	# Используем относительное движение мыши
	var adjusted_sensitivity = drag_sensitivity * (1.0 / zoom.x)
	velocity = event.relative * adjusted_sensitivity
	global_position -= velocity

func apply_inertia(delta: float):
	if !is_dragging:
		global_position += velocity * delta * -250
		velocity *= inertia_damping

func update_zoom(delta: float):
	zoom = zoom.lerp(target_zoom, 15.0 * delta)

func clamp_camera_position():
	var effective_zoom = zoom
	var viewport = get_viewport_rect().size / effective_zoom
	var half_view = viewport / 2.0

	var target_x = clamp(global_position.x, half_view.x, map_limits.end.x - half_view.x)
	var target_y = clamp(global_position.y, half_view.y, map_limits.end.y - half_view.y)
	global_position = global_position.lerp(Vector2(target_x, target_y), snap_back_speed * get_process_delta_time())
