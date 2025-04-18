class_name AttackRangeVisualizer
extends Node2D

# Ссылки на другие узлы
@export var character_path: NodePath = "../Character"
@onready var character: Character = get_node_or_null(character_path)
@onready var landscape_layer: TileMapLayer = $"../Landscape"

# Цвета для визуализации
@export var radius_color: Color = Color(1, 0.7, 0.3, 0.2)  # Оранжевый полупрозрачный
@export var target_color: Color = Color(1, 0, 0, 0.4)      # Красный полупрозрачный

# Данные для отрисовки
var radius_cells: Array = []
var target_cells: Array = []
var tile_size: Vector2

func _ready():
	if not character:
		push_error("AttackRangeVisualizer: Character not found!")
		return
		
	if not landscape_layer:
		push_error("AttackRangeVisualizer: Landscape layer not found!")
		return
	
	# Подключаем сигнал для обновления радиуса атаки
	character.connect("attack_radius_changed", _on_attack_radius_changed)
	
	# Получаем размер тайла
	tile_size = landscape_layer.tile_set.tile_size
	
	# Добавьте подписку на сигнал атаки
	if character.has_signal("attack_executed"):
		character.connect("attack_executed", _on_attack_executed)
	
	# По умолчанию невидимый
	modulate.a = 0.0

# Обработчик изменения радиуса атаки
# Обработчик изменения радиуса атаки
func _on_attack_radius_changed(radius: Array, targets: Array):
	radius_cells = radius
	target_cells = targets
	
	# Если оба массива пустые, скрываем визуализатор
	var should_show = radius.size() > 0 || targets.size() > 0
	modulate.a = 1.0 if should_show else 0.0
	
	# Запрашиваем перерисовку даже если массивы пустые!
	queue_redraw()

# Отрисовка радиуса и целей
func _draw():
	if modulate.a <= 0.0:
		return
		
	# Отрисовка радиуса атаки
	for cell in radius_cells:
		var cell_center = landscape_layer.map_to_local(cell)
		var rect = Rect2(cell_center - tile_size/2, tile_size)
		draw_rect(rect, radius_color)
	
	# Отрисовка целей атаки поверх радиуса
	for cell in target_cells:
		var cell_center = landscape_layer.map_to_local(cell)
		var rect = Rect2(cell_center - tile_size/2, tile_size)
		draw_rect(rect, target_color)


# Обработчик выполненной атаки - очищает визуализацию
func _on_attack_executed(_target_cell):
	
	# Явно очищаем данные
	radius_cells = []
	target_cells = []
	
	# Скрываем визуализатор
	modulate.a = 0.0
	
	# Перерисовываем
	queue_redraw()
