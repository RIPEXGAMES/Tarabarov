extends PanelContainer

@onready var world_map = get_node("../WorldMap")  # Путь к вашей TileMap ноде
@export var animation_duration: float = 0.3
@export var max_scale: float = 0.4  # Максимальный масштаб

var tween: Tween

func show_context_pos(cell: Vector2i):
	# Останавливаем предыдущий tween, если он еще активен
	if tween and tween.is_valid():
		tween.kill()
	
	# Устанавливаем начальную позицию
	position = world_map.map_to_local(cell)
	position.y -= size.y/2 * max_scale  # Учитываем новый масштаб
	if cell.x >= world_map.Width - 2:
		position.x -= 25
	else:
		position.x += 6
	
	# Устанавливаем начальные значения для анимации
	modulate.a = 0  # Прозрачность
	scale = Vector2(0.2, 0.2)  # Начальный масштаб (половина от максимального)
	visible = true  # Делаем видимым перед началом анимации
	
	# Создаем новый tween
	tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Анимируем свойства
	tween.parallel().tween_property(self, "modulate:a", 1.0, animation_duration)
	tween.parallel().tween_property(self, "scale", Vector2(max_scale, max_scale), animation_duration)

func hide_context_pos():
	# Останавливаем предыдущий tween, если он еще активен
	if tween and tween.is_valid():
		tween.kill()
	
	# Создаем новый tween
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Анимируем свойства
	tween.parallel().tween_property(self, "modulate:a", 0.0, animation_duration)
	tween.parallel().tween_property(self, "scale", Vector2(0.2, 0.2), animation_duration)
	
	# После завершения анимации скрываем элемент
	tween.tween_callback(func(): visible = false)
