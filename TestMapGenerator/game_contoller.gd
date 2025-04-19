class_name GameController
extends Node

# Ссылки на узлы
@onready var map_generator: MapGenerator = get_node("../MapGenerator")
@onready var character: Character = get_node("../Character")
@onready var path_visualizer: PathVisualizer = get_node("../PathVisualizer") if has_node("../PathVisualizer") else null
@onready var landscape_layer: TileMapLayer = get_node("../Landscape")
@onready var obstacles_layer: TileMapLayer = get_node("../Obstacles")

# Добавим ссылку на противника
@onready var enemy: Enemy = get_node("../Enemy") if has_node("../Enemy") else null

# Система ходов
var current_turn: int = 1
var is_player_turn: bool = true

# Добавьте статистику боя
var total_enemies_defeated: int = 0
var total_damage_dealt: int = 0

# Сигнал изменения хода
signal turn_changed

func _ready():
	print("GameController._ready() started")
	
	# Проверка наличия нужных узлов
	if not map_generator:
		push_error("MapGenerator not found!")
	else:
		print("MapGenerator found")
	
	if not character:
		push_error("Character not found!")
	else:
		print("Character found")
		
		# Подключаем только сигнал запроса на завершение хода
		if character.has_signal("end_turn_requested"):
			character.connect("end_turn_requested", _on_character_turn_end_requested)
			print("Connected to character's end_turn_requested signal")
		
		# Сигнал move_finished используем только для дебага, но не для смены хода
		if character.has_signal("move_finished"):
			character.connect("move_finished", _on_move_finished_debug)
			print("Connected to character's move_finished signal (debug only)")
	
	# Подключаем сигнал атаки
	if character.has_signal("attack_started"):
		character.connect("attack_started", _on_character_attack_started)
		print("Connected to character's attack_started signal")
	
	# Принудительно устанавливаем ход игрока
	is_player_turn = true
	print("Player's turn is set to: ", is_player_turn)
	
	# Инициализация
	print("Игра началась. Ход: ", current_turn)

# Обработчик только для дебага, не меняет ход
func _on_move_finished_debug():
	print("Character move finished - debug notification only")

# Обработка запроса на завершение хода - ОСНОВНОЙ метод для смены хода
# Обновленный обработчик завершения хода игрока
func _on_character_turn_end_requested():
	print("End turn requested by character")
	
	# Переключаем ход
	is_player_turn = false
	print("Player's turn set to false")
	
	# Логика ИИ - теперь с обработкой противника
	if enemy:
		print("Processing enemy turn")
		enemy.process_turn()
	else:
		print("No enemy found in the scene")
	
	# После выполнения действий переключаем ход обратно
	call_deferred("end_enemy_turn")

# Обработчик начала атаки персонажа
func _on_character_attack_started(enemy: Enemy):
	print("Character attack started on enemy")
	
	# Дождитесь завершения анимации, прежде чем наносить урон
	await character.tween.finished
	
	# Урон от атаки берем из настроек персонажа
	var damage = character.attack_damage
	
	# Применяем урон противнику
	var enemy_died = enemy.take_damage(damage)
	
	# Обновляем статистику
	total_damage_dealt += damage
	
	if enemy_died:
		total_enemies_defeated += 1
		print("Enemy defeated! Total enemies defeated: ", total_enemies_defeated)

# Завершение хода противников
func end_enemy_turn():
	current_turn += 1
	is_player_turn = true
	print("Turn changed to: ", current_turn, ", Player's turn: ", is_player_turn)
	
	# Сигнал для уведомления
	emit_signal("turn_changed")

# Проверка хода игрока
func can_player_act() -> bool:
	return is_player_turn



# Обработка атаки с учетом вероятности попадания
func handle_attack(attacker: Character, target: Enemy, cell: Vector2i):
	# Получаем шанс попадания
	var hit_chance = 0
	if attacker.hit_chance_map.has(cell):
		hit_chance = attacker.hit_chance_map[cell]
	else:
		# Если по какой-то причине шанс не рассчитан, вычисляем его
		var distance = attacker.current_cell.distance_to(cell)
		hit_chance = attacker.calculate_hit_chance(distance)
	
	# Определяем попадание
	var hit_roll = randi() % 100 + 1  # Случайное число от 1 до 100
	var hit_successful = hit_roll <= hit_chance
	
	print("Attack roll: " + str(hit_roll) + " vs hit chance: " + str(hit_chance))
	print("Result: " + ("Hit" if hit_successful else "Miss"))
	
	# Применяем урон с учетом попадания
	target.take_damage_with_chance(attacker.attack_damage, hit_successful)
