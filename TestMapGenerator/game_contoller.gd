class_name GameController
extends Node

# Ссылка на генератор карты
@onready var map_generator: MapGenerator = get_node("../MapGenerator")
# Ссылка на персонажа
@onready var character: Character = get_node("../Character")
# Ссылка на визуализатор пути (опционально) 
@onready var path_visualizer: PathVisualizer = get_node("../PathVisualizer") if has_node("../PathVisualizer") else null
# Ссылки на слои тайлмапа
@onready var landscape_layer: TileMapLayer = get_node("../Landscape")
@onready var obstacles_layer: TileMapLayer = get_node("../Obstacles")

# Система ходов
var current_turn: int = 1
var is_player_turn: bool = true

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
		# Соединяем сигналы (если они определены)
		if character.has_signal("move_finished"):
			# Используем Callable для подключения сигнала в Godot 4.x
			character.connect("move_finished", _on_character_move_finished)
			print("Connected to character's move_finished signal")
	
	if character:
		# Подключаем сигнал завершения хода
		if character.has_signal("move_finished"):
			character.connect("move_finished", _on_character_move_finished)
			print("Connected to character's move_finished signal")
		
		# Подключаем сигнал запроса на завершение хода
		if character.has_signal("end_turn_requested"):
			character.connect("end_turn_requested", _on_character_turn_end_requested)
			print("Connected to character's end_turn_requested signal")
	
	# Принудительно устанавливаем ход игрока
	is_player_turn = true
	print("Player's turn is set to: ", is_player_turn)
	
	# Инициализация игры
	print("Игра началась. Ход: ", current_turn)

# Обработчик завершения хода игрока
func _on_character_move_finished():
	print("Character move finished signal received")
	# Переключаем ход
	is_player_turn = false
	print("Player's turn set to false")
	
	# Здесь будет логика ИИ или других действий после хода игрока
	print("AI turn would happen here")
	
	# После выполнения действий переключаем ход обратно на игрока
	call_deferred("end_enemy_turn")

# Завершение хода противников
func end_enemy_turn():
	current_turn += 1
	is_player_turn = true
	print("Turn changed to: ", current_turn, ", Player's turn: ", is_player_turn)
	# Испускаем сигнал для уведомления других объектов
	emit_signal("turn_changed")

# Функция для проверки, является ли текущий ход ходом игрока
func can_player_act() -> bool:
	return is_player_turn

# Новый метод для обработки запроса на завершение хода
func _on_character_turn_end_requested():
	print("End turn requested by character")
	# Здесь можно добавить проверки или другую логику перед завершением хода
