extends Node

class_name TurnManager

# Сигналы
signal player_turn_started
signal player_turn_ended
signal enemy_turn_started
signal enemy_turn_ended

# Переменные
var current_turn: String = "player"  # Кто сейчас ходит: "player" или "enemy"
var player: PlayerCharacter
var enemies: Array = []

func _ready():
	# Находим игрока и врагов на сцене
	player = get_tree().get_first_node_in_group("player")
	
	# Подключаем сигналы
	if player:
		player.connect("turn_ended", _on_player_turn_ended)
	
	# Получаем список всех врагов
	enemies = get_tree().get_nodes_in_group("enemies")
	
	# Запускаем первый ход
	start_player_turn()

func start_player_turn():
	current_turn = "player"
	player.start_new_turn()
	emit_signal("player_turn_started")
	print("Ход игрока начался")

func _on_player_turn_ended():
	emit_signal("player_turn_ended")
	print("Ход игрока закончился")
	start_enemy_turn()

func start_enemy_turn():
	current_turn = "enemy"
	emit_signal("enemy_turn_started")
	print("Ход врагов начался")
	
	# Здесь будет логика для ходов врагов
	# Пока просто эмулируем ход врагов
	await get_tree().create_timer(1.0).timeout
	
	end_enemy_turn()

func end_enemy_turn():
	emit_signal("enemy_turn_ended")
	print("Ход врагов закончился")
	start_player_turn()

func is_player_turn() -> bool:
	return current_turn == "player"
