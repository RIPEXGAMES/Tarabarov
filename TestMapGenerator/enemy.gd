class_name Enemy
extends Node2D

#region Экспортируемые параметры
# Настройки противника
@export var debug_mode: bool = true
@export var min_distance_from_player: int = 5
@export var max_health: int = 100
#endregion

#region Внутренние переменные
var current_health: int = 0
var current_cell: Vector2i = Vector2i.ZERO
var was_hit: bool = false

# Сигналы
signal health_changed(new_health)
signal enemy_died
#endregion

#region Ссылки на узлы
@onready var map_generator: MapGenerator = get_node("../MapGenerator")
@onready var landscape_layer: TileMapLayer = get_node("../Landscape")
@onready var sprite: Sprite2D = $Sprite2D
#endregion

func _ready():
	# Проверка необходимых узлов
	if not map_generator or not landscape_layer or not sprite:
		push_error("Enemy: Missing required node references!")
		return
	
	debug_print("Enemy initialized")
	
	# Установка начальных параметров
	visible = true
	sprite.visible = true
	current_health = max_health
	add_to_group("enemies")
	
	# Размещение противника на карте
	if current_cell == Vector2i.ZERO:
		place_at_valid_position()

#region Позиционирование на карте
func place_at_valid_position():
	# Получаем позицию игрока
	var player = get_node("../Character")
	var player_pos = Vector2i.ZERO
	if player:
		player_pos = player.current_cell
	
	# Ищем подходящую позицию вдали от игрока
	var max_attempts = 100
	var attempts = 0
	
	while attempts < max_attempts:
		var x = randi() % map_generator.map_width
		var y = randi() % map_generator.map_height
		var pos = Vector2i(x, y)
		
		if map_generator.is_tile_walkable(x, y) and pos.distance_to(player_pos) >= min_distance_from_player:
			current_cell = pos
			global_position = landscape_layer.map_to_local(current_cell)
			debug_print("Enemy placed at position: " + str(current_cell))
			return
		
		attempts += 1
	
	# Запасной вариант: найти любую проходимую клетку
	for x in range(map_generator.map_width):
		for y in range(map_generator.map_height):
			if map_generator.is_tile_walkable(x, y) and Vector2i(x, y) != player_pos:
				current_cell = Vector2i(x, y)
				global_position = landscape_layer.map_to_local(current_cell)
				return
	
	push_error("Could not find any valid position for enemy!")

func force_position(pos: Vector2i):
	current_cell = pos
	
	if landscape_layer:
		global_position = landscape_layer.map_to_local(current_cell)
		
	visible = true
	if sprite:
		sprite.visible = true
#endregion

#region Система боя и здоровья
func process_turn():
	# Заглушка для будущей реализации AI противника
	pass

func take_damage(damage: int) -> bool:
	current_health = max(0, current_health - damage)
	emit_signal("health_changed", current_health)
	
	debug_print("Enemy took " + str(damage) + " damage, health: " + str(current_health))
	
	if current_health <= 0:
		emit_signal("enemy_died")
		die()
		return true
	
	return false

func take_damage_with_chance(damage: int, hit_successful: bool) -> bool:
	was_hit = hit_successful
	
	if !hit_successful:
		show_miss_effect()
		return false
	
	return take_damage(damage)

func die():
	debug_print("Enemy defeated")
	
	var death_tween = create_tween()
	death_tween.tween_property(self, "modulate:a", 0.0, 0.5)
	death_tween.tween_callback(queue_free)
#endregion

#region Визуальные эффекты
func show_miss_effect():
	# Анимация уклонения
	var miss_tween = create_tween()
	miss_tween.tween_property(self, "modulate", Color(1.5, 1.5, 1.5), 0.1)
	miss_tween.tween_property(self, "modulate", Color(1, 1, 1), 0.2)
	
	# Метка "MISS"
	var miss_label = Label.new()
	miss_label.text = "MISS!"
	miss_label.add_theme_font_size_override("font_size", 16)
	miss_label.add_theme_color_override("font_color", Color.RED)
	miss_label.position = Vector2(-20, -40)
	add_child(miss_label)
	
	# Анимация метки
	var label_tween = create_tween()
	label_tween.tween_property(miss_label, "position:y", -60, 0.5)
	label_tween.tween_property(miss_label, "modulate:a", 0.0, 0.2)
	label_tween.tween_callback(miss_label.queue_free)
#endregion

#region Вспомогательные функции
func debug_print(message: String):
	if debug_mode:
		print("Enemy: " + message)
#endregion
