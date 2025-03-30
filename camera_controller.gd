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

# Кэширование для оптимизации
var half_viewport: Vector2
var edge_buffer: float
var adjusted_sensitivity: float

# Внутренние переменные
var target_zoom: Vector2 = Vector2.ONE
var is_dragging: bool = false
var velocity: Vector2 = Vector2.ZERO
var map_limits: Rect2
var delta_cache: float = 0.016  # Начальное значение (примерно 60 FPS)

func _ready():
	var map_width = tilemap_layer.get_map_width_pixels()
	var map_height = tilemap_layer.get_map_height_pixels()
	map_limits = Rect2(0, 0, map_width, map_height)
	target_zoom = zoom
	
	# Инициализация кэшированных значений
	update_cached_values()
	
	# Оптимизация: использовать процесс с фиксированной частотой
	set_process(true)
	set_physics_process(false)

func update_cached_values():
	half_viewport = get_viewport_rect().size / (2.0 * zoom)
	edge_buffer = edge_threshold / zoom.x
	adjusted_sensitivity = drag_sensitivity * (1.0 / zoom.x)

func _input(event):
	# Обработка зума
	if event is InputEventMouseButton:
		handle_zoom(event)
	
	# Обработка перетаскивания через относительное движение
	if event is InputEventMouseMotion and is_dragging:
		handle_drag(event)

	# Начинаем перетаскивание при нажатии правой кнопки
	if event.is_action_pressed("right_click"):
		# Проверяем, выбрана ли клетка у персонажа
		var character = get_node_or_null("../Character")
			
		is_dragging = true
		velocity = Vector2.ZERO
	
	# Заканчиваем перетаскивание при отпускании правой кнопки
	if event.is_action_released("right_click"):
		is_dragging = false

func _process(delta):
	delta_cache = delta  # Кэширование delta для других функций
	
	# Обновление кэшированных значений только при изменении зума
	if not is_equal_approx(zoom.x, target_zoom.x):
		update_cached_values()
		
	apply_inertia()
	apply_edge_pull()
	apply_zoom_bounds()
	clamp_camera_position()
	update_zoom()
	
func apply_zoom_bounds():
	# Сила притяжения к границам
	if target_zoom.x > max_zoom:
		var overflow = target_zoom.x - max_zoom
		target_zoom.x -= overflow * zoom_snap_back * delta_cache
	elif target_zoom.x < min_zoom:
		var underflow = min_zoom - target_zoom.x
		target_zoom.x += underflow * zoom_snap_back * delta_cache
	
	# Окончательный clamp для безопасности
	target_zoom.x = clamp(target_zoom.x, min_zoom * 0.8, max_zoom * 1.2)
	target_zoom.y = target_zoom.x

func apply_edge_pull():
	var delta = delta_cache
	
	# Оптимизация: используем кэшированный edge_buffer
	var edge_force_x = 0.0
	var edge_force_y = 0.0
	
	# Расчет сил для X
	if global_position.x < edge_buffer:
		edge_force_x = (edge_buffer - global_position.x) * edge_pull_strength
	elif global_position.x > map_limits.end.x - edge_buffer:
		edge_force_x = (map_limits.end.x - edge_buffer - global_position.x) * edge_pull_strength
		
	# Расчет сил для Y
	if global_position.y < edge_buffer:
		edge_force_y = (edge_buffer - global_position.y) * edge_pull_strength
	elif global_position.y > map_limits.end.y - edge_buffer:
		edge_force_y = (map_limits.end.y - edge_buffer - global_position.y) * edge_pull_strength
		
	# Применяем силы
	velocity.x += edge_force_x * delta
	velocity.y += edge_force_y * delta
	velocity *= edge_damping

func handle_zoom(event: InputEventMouseButton):
	var zoom_dir = 0
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP: zoom_dir = 1
		MOUSE_BUTTON_WHEEL_DOWN: zoom_dir = -1
	
	if zoom_dir == 0:
		return  # Оптимизация: ранний выход, если это не колесо мыши
	
	var zoom_change = zoom_speed * zoom_dir
	
	# Добавляем сопротивление у границ
	if zoom_dir > 0 and target_zoom.x > max_zoom - 0.2:
		zoom_change *= lerp(0.0, 1.0, (max_zoom - target_zoom.x) / 0.2)
	elif zoom_dir < 0 and target_zoom.x < min_zoom + 0.2:
		zoom_change *= lerp(0.0, 1.0, (target_zoom.x - min_zoom) / 0.2)
	
	target_zoom.x += zoom_change
	target_zoom.y += zoom_change

func handle_drag(event: InputEventMouseMotion):
	if is_dragging:
		# Используем кэшированную чувствительность
		velocity = event.relative * adjusted_sensitivity
		global_position -= velocity

func apply_inertia():
	if !is_dragging:
		var move_delta = velocity * delta_cache * -250
		global_position += move_delta
		velocity *= inertia_damping

func update_zoom():
	# Используем предварительно рассчитанный коэффициент для плавного зума
	var zoom_factor = 15.0 * delta_cache
	zoom.x = lerp(zoom.x, target_zoom.x, zoom_factor)
	zoom.y = lerp(zoom.y, target_zoom.y, zoom_factor)

func clamp_camera_position():
	# Используем кэшированные половинные размеры вьюпорта
	var target_x = clamp(global_position.x, half_viewport.x, map_limits.end.x - half_viewport.x)
	var target_y = clamp(global_position.y, half_viewport.y, map_limits.end.y - half_viewport.y)
	
	var lerp_factor = snap_back_speed * delta_cache
	global_position.x = lerp(global_position.x, target_x, lerp_factor)
	global_position.y = lerp(global_position.y, target_y, lerp_factor)
