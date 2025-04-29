class_name GameController
extends Node

#region Ссылки на узлы
@onready var map_generator: MapGenerator = get_node("../MapGenerator")
@onready var character: Character = get_node("../Character")
@onready var path_visualizer: PathVisualizer = get_node("../PathVisualizer") if has_node("../PathVisualizer") else null
@onready var landscape_layer: TileMapLayer = get_node("../Landscape")
@onready var obstacles_layer: TileMapLayer = get_node("../Obstacles")
@onready var enemy: Enemy = get_node("../Enemy") if has_node("../Enemy") else null
#endregion

#region Система ходов
var current_turn: int = 1
var is_player_turn: bool = true

# Статистика боя
var total_enemies_defeated: int = 0
var total_damage_dealt: int = 0

# Сигналы
signal turn_changed
#endregion

func _ready():
	print("GameController: Игра инициализирована")
	
	# Проверяем критически важные узлы
	if not map_generator or not character:
		push_error("GameController: Отсутствуют критические узлы!")
		return
	
	# Подключаем сигналы персонажа
	connect_character_signals()
	
	# Устанавливаем начальный ход
	is_player_turn = true
	print("GameController: Ход игрока (#" + str(current_turn) + ")")

#region Система управления ходами
func connect_character_signals():
	if character.has_signal("end_turn_requested"):
		character.connect("end_turn_requested", _on_character_turn_end_requested)
	
	if character.has_signal("attack_started"):
		character.connect("attack_started", _on_character_attack_started)

func _on_character_turn_end_requested():
	# Переключаем на ход врага
	is_player_turn = false
	
	# Обрабатываем ход противника
	if enemy:
		enemy.process_turn()
	
	# После завершения хода противника
	call_deferred("end_enemy_turn")

func end_enemy_turn():
	current_turn += 1
	is_player_turn = true
	print("GameController: Ход игрока (#" + str(current_turn) + ")")
	
	emit_signal("turn_changed")

func can_player_act() -> bool:
	return is_player_turn
#endregion

#region Боевая система
func _on_character_attack_started(enemy: Enemy):
	# Ожидаем завершения анимации атаки
	await character.tween.finished
	
	# Обновляем статистику только если враг побежден
	if enemy.current_health <= 0:
		total_enemies_defeated += 1
		print("GameController: Противник побежден (всего: " + str(total_enemies_defeated) + ")")
#endregion
