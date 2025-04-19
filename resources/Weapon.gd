class_name Weapon
extends Resource

# Характеристики оружия
@export var name: String = "Default"
@export var damage: int = 25
@export var effective_range: int = 30
@export var base_hit_chance: int = 80
@export var medium_hit_chance: int = 40
@export var attack_cost: int = 20
@export_enum("Pistol", "Rifle", "Shotgun", "Sniper Rifle") var type: int = 0

# Дополнительные параметры
@export var icon: Texture2D

# Возвращает описание оружия
func get_description() -> String:
	var desc = name + "\n"
	desc += "Урон: " + str(damage) + "\n"
	desc += "Эффективная дальность: " + str(effective_range) + "\n"
	desc += "Шанс попадания: " + str(base_hit_chance) + "%\n"
	desc += "Стоимость атаки: " + str(attack_cost) + " AP"
	return desc
