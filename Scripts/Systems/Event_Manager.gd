extends Node

signal random_event_triggered

const EVENT_CHANCE_DEFAULT = 0.05
const EVENT_WEIGHTS = {
	"combat": 45,
	"loot": 35,
	"trap": 15,
	"anomaly": 5
}

const TILE_MODIFIERS = {
	"forest": {"combat": 1.5, "loot": 1.2, "trap": 1.3, "anomaly": 1.0},
	"clearing": {"combat": 1.8, "loot": 0.7, "trap": 0.5, "anomaly": 0.3},
	"swamp": {"combat": 0.8, "loot": 1.1, "trap": 2.0, "anomaly": 2.0},
	"hill": {"combat": 1.2, "loot": 1.4, "trap": 1.1, "anomaly": 0.9},
	"mountain": {"combat": 0.6, "loot": 1.5, "trap": 1.4, "anomaly": 1.0},
	"road": {"combat": 2.0, "loot": 1.0, "trap": 1.6, "anomaly": 0.5}
}

const ENEMY_TYPE_CHANCES = {
	"forest": {
		"animal": 50,    # 50% шанс животных
		"human": 30,     # 30% шанс людей
		"mutant": 20     # 20% шанс мутантов
	},
	"clearing": {
		"animal": 20,
		"human": 70,
		"mutant": 10
	},
	"swamp": {
		"animal": 30,
		"human": 20,
		"mutant": 50
	},
	"hill": {
		"animal": 40,
		"human": 50,
		"mutant": 10
	},
	"mountain": {
		"animal": 60,
		"human": 30,
		"mutant": 10
	},
	"road": {
		"animal": 10,
		"human": 80,
		"mutant": 10
	}
}

# Значения по умолчанию для биомов, которых нет в таблице
const DEFAULT_ENEMY_CHANCES = {
	"animal": 33,
	"human": 34,
	"mutant": 33
}

var last_event_tile: Vector2i
var tiles_since_last_event: int = 0
const MIN_TILES_BETWEEN_EVENTS = 5

func _ready():
	randomize()
	
func check_for_random_event(tile_pos:Vector2i, tile_data: Dictionary) -> void:
	tiles_since_last_event += 1
	if tile_pos.distance_to(last_event_tile) <= MIN_TILES_BETWEEN_EVENTS:
		return
	var event_chance = EVENT_CHANCE_DEFAULT * (1.0 + tiles_since_last_event * 0.05)
	
	print("Шанс на ивент: ", event_chance)
	print("С последнего ивента прошло ", tiles_since_last_event, " тайлов")
	
	if randf() <= event_chance:
		var event_type = _get_weighted_event_type(tile_data.name)
		var event_data = _generate_event_data(event_type, tile_pos, tile_data.name)
		
		last_event_tile = tile_pos
		tiles_since_last_event = 0
		
		emit_signal("random_event_triggered",event_data)
		
		print("Дата ивента: ", event_data)
	
func _get_weighted_event_type(tile_type: String) -> String:
		
	var weights = EVENT_WEIGHTS.duplicate()
	
	if TILE_MODIFIERS.has(tile_type):
		var modifiers = TILE_MODIFIERS[tile_type]
		for event_type in modifiers:
			if weights.has(event_type):
				weights[event_type] *= modifiers[event_type]
	
	var total_weight = 0
	for weight in weights.values():
		total_weight += weight
	
	var random_value = randf() * total_weight
	var current_weight = 0
	
	print("Веса: ")
	print(weights)
	
	for event_type in weights:
		current_weight += weights[event_type]
		if random_value <= current_weight:
			return event_type
			
	return _get_max_weight_event_type(weights)

func _get_max_weight_event_type(weights: Dictionary) -> String:
	var max_weight = 0
	var max_type = ""
	
	for event_type in weights:
		if weights[event_type] > max_weight:
			max_weight = weights[event_type]
			max_type = event_type
	
	return max_type

func _generate_event_data(event_type: String, tile_position: Vector2i, tile_type: String) -> Dictionary:
	var event_data = {
		"type": event_type,
		"position": tile_position,
		"tile_type": tile_type,
		"difficulty": 1 + (randi() % 3)  # Базовая сложность от 1 до 3"
	}
	match event_type:
		"combat":
			var enemies = _generate_combat_enemies(event_data["difficulty"], tile_type)
			event_data["enemies"] = enemies
			event_data["ambush"] = randf() < 0.3  # 30% шанс засады
			
		"loot":
			event_data["loot_quality"] = _calculate_loot_quality(event_data["difficulty"])
			event_data["trapped"] = randf() < 0.2  # 20% шанс ловушки
			
		"trap":
			event_data["trap_type"] = _select_random_trap(tile_type)
			event_data["detection_difficulty"] = event_data["difficulty"] + randi() % 2
	
	return event_data

func _generate_combat_enemies(difficulty: int, tile_type: String) -> Array:
	var enemies = []
	var num_enemies = difficulty + randi() % 2  # Базовое кол-во врагов на основе сложности
	
	# Для простоты примера, выбираем из заранее определенных групп врагов
	# В реальной игре здесь должна быть более сложная логика
	var possible_enemies = _select_enemy_type_for_tile(tile_type)
	
	for i in range(num_enemies):
		var enemy_type = possible_enemies[randi() % possible_enemies.size()]
		enemies.append({
			"type": enemy_type,
			"level": difficulty + (randi() % 2) - 1  # Диапазон уровней
		})
	
	return enemies

func _select_enemy_type_for_tile(tile_type: String) -> String:
	# Получаем таблицу вероятностей для данного биома или используем значения по умолчанию
	var chances = DEFAULT_ENEMY_CHANCES
	if ENEMY_TYPE_CHANCES.has(tile_type):
		chances = ENEMY_TYPE_CHANCES[tile_type]
	
	# Выбираем случайное число от 1 до 100
	var roll = randi() % 100 + 1
	
	# Определяем, какому типу соответствует результат броска
	var accumulated = 0
	for enemy_type in chances:
		accumulated += chances[enemy_type]
		if roll <= accumulated:
			return enemy_type
	
	# На всякий случай, если что-то пошло не так
	return "human"

func _calculate_loot_quality(difficulty: int) -> float:
	return 1.0 + (difficulty - 1) * 0.25 + randf() * 0.5  # От 1.0 до ~2.5

func _select_random_trap(tile_type: String) -> String:
	var traps = []
	
	match tile_type:
		"forest":
			traps = ["snare", "pitfall", "tripwire"]
		"city":
			traps = ["alarm", "tripwire", "explosive"]
		"swamp":
			traps = ["quicksand", "poison_dart", "snare"]
		"mountain":
			traps = ["rockfall", "tripwire", "explosive"]
		_:
			traps = ["tripwire", "pitfall", "alarm"]
	
	return traps[randi() % traps.size()]
