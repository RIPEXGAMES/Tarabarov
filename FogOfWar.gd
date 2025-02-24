# FogOfWar.gd
extends TileMapLayer

@export var world_map:TileMapLayer

enum FOG_STATE {
	FOGGED,     # В тумане, не исследована
	EXPLORED,   # Исследована, но не в прямой видимости
	VISIBLE     # В прямой видимости
}

var fog_state_map = {} # Словарь для хранения состояния тумана для каждой клетки
var fog_tile_index_fogged = 0 # Индекс тайла для "туман"
var fog_tile_index_explored = 1 # Индекс тайла для "исследовано"
var fog_tile_index_clear = -1 # Индекс "пустого" тайла, чтобы убрать туман (или -1, если используете erase_cell)

func _ready():
	z_index = 5 # Устанавливаем z_index, чтобы туман был над картой, но под персонажем и подсветкой
	initialize_fog()

func initialize_fog():
	# Инициализируем карту тумана состоянием "в тумане" для всех клеток
	for x in range(world_map.Width):
		for y in range(world_map.Height):
			var cell = Vector2i(x, y)
			fog_state_map[cell] = FOG_STATE.FOGGED
			set_fog_tile(cell, FOG_STATE.FOGGED) # Отображаем начальный туман

func set_fog_tile(cell: Vector2i, state: FOG_STATE):
	match state:
		FOG_STATE.FOGGED:
			set_cell(cell, fog_tile_index_fogged, Vector2i(0, 0))
		FOG_STATE.EXPLORED:
			set_cell(cell, fog_tile_index_explored, Vector2i(0, 0))
		FOG_STATE.VISIBLE:
			erase_cell(cell) # Убираем тайл тумана, чтобы клетка стала видимой
		_:
			erase_cell(cell) # По умолчанию убираем тайл

func update_fog_of_war(player_cell: Vector2i, visibility_radius: int):
	# 1. Сначала делаем все "видимые" клетки "исследованными" или "в тумане", если они больше не в прямой видимости
	for cell in fog_state_map.keys():
		if fog_state_map[cell] == FOG_STATE.VISIBLE:
			fog_state_map[cell] = FOG_STATE.EXPLORED # Или FOG_STATE.FOGGED, если хотите полный туман вне видимости
			set_fog_tile(cell, FOG_STATE.EXPLORED) # Отображаем "исследовано"

	# 2. Определяем новые "видимые" клетки ВОКРУГ игрока В ФОРМЕ ОКРУЖНОСТИ
	for x_offset in range(-visibility_radius, visibility_radius + 1):
		for y_offset in range(-visibility_radius, visibility_radius + 1):
			var cell_to_explore = player_cell + Vector2i(x_offset, y_offset)

			if is_valid_cell(cell_to_explore): # Проверяем, что клетка в пределах карты
				# **Новый код: Проверка расстояния для круглой видимости**
				# Получаем позицию клетки в мировых координатах (центр клетки)
				# Исправлено: Явное преобразование Vector2i в Vector2
				var cell_world_pos = world_map.map_to_local(cell_to_explore) + Vector2(world_map.tile_set.tile_size) / 2.0
				# Исправлено: Явное преобразование Vector2i в Vector2
				var player_world_pos = world_map.map_to_local(player_cell) + Vector2(world_map.tile_set.tile_size) / 2.0

				# Вычисляем расстояние между клеткой и игроком
				var distance = player_world_pos.distance_to(cell_world_pos)

				# Если расстояние меньше или равно радиусу видимости, делаем клетку видимой
				if distance <= visibility_radius * world_map.tile_set.tile_size.x : # Умножаем радиус на размер тайла
					set_cell_visible(cell_to_explore)

func set_cell_visible(cell: Vector2i):
	if fog_state_map.has(cell):
		if fog_state_map[cell] == FOG_STATE.FOGGED:
			fog_state_map[cell] = FOG_STATE.EXPLORED # Клетка была в тумане, теперь исследована
			set_fog_tile(cell, FOG_STATE.EXPLORED)
		elif fog_state_map[cell] == FOG_STATE.EXPLORED:
			fog_state_map[cell] = FOG_STATE.EXPLORED # Уже исследована, ничего не меняем в состоянии
			set_fog_tile(cell, FOG_STATE.EXPLORED) # Но можно обновить визуал "исследованной" клетки, если нужно
		# Теперь делаем клетку ВИДИМОЙ
		fog_state_map[cell] = FOG_STATE.VISIBLE
		set_fog_tile(cell, FOG_STATE.VISIBLE) # Убираем туман, клетка становится видимой


func is_valid_cell(cell: Vector2i) -> bool:
	
	return cell.x >= 0 && cell.y >= 0 && cell.x < world_map.Width && cell.y < world_map.Height

func is_tile_visible(cell: Vector2i) -> bool:
	if !is_valid_cell(cell): # Сначала проверяем, что клетка валидная
		return false # Невалидные клетки невидимы

	if fog_state_map.has(cell): # Проверяем, есть ли клетка в карте тумана
		# **ИЗМЕНЕНО: Возвращаем true, если состояние НЕ FOGGED (то есть EXPLORED или VISIBLE)**
		return fog_state_map[cell] != FOG_STATE.FOGGED
	else:
		return false # Если клетки нет в fog_state_map, считаем ее невидимой
