extends TileMapLayer

enum BIOME {
	FOREST = 0,
	CLEARING = 1,
	SWAMP = 2,
	HILL = 3,
	MOUNTAIN = 4,
	RIVER = 5,
	ROAD = 6
}

var TERRAIN_COST = {
	BIOME.CLEARING: 2,
	BIOME.FOREST: 3,
	BIOME.SWAMP: 4,
	BIOME.HILL: 5,
	BIOME.MOUNTAIN: 6,
	BIOME.RIVER: 9999,
	BIOME.ROAD: 1
}

const TERRAIN_DATA = {
	BIOME.CLEARING: {
		"name":"Clearing",
		"description":"This isn’t a field. It’s shooting range. You’re the target.",
	},
	BIOME.FOREST: {
		"name":"Forest",
		"description":"If a branch snaps, assume 12 snipers now know your shoe size",
	},
	BIOME.SWAMP: {
		"name":"Swamp",
		"description":"Good news: The fog hides you. Bad news: It also hiding them",
	},
	BIOME.HILL: {
		"name":"Hill",
		"description":"High ground is power... until everyone sees you.",
	},
	BIOME.MOUNTAIN: {
		"name":"Mountain",
		"description":"If you’re not gasping for air, you’re not high enough... or already dead.",
	},
	BIOME.RIVER: {
		"name":"River",
		"description":"Fish here have seen more corpses than a coroner. Don’t make eye contact.",
	},
	BIOME.ROAD: {
		"name":"Road",
		"description":"Abandoned trucks: 10% loot, 90% ambush. Good luck!",
	}
}

enum POI_TYPE {
	NONE,
	SAWMILL,
	VILLAGE,
	CAMP,
	HUNTER,
	EXTR_A,
	EXTR_B
}

const POI_DATA = {
	POI_TYPE.SAWMILL: {
		"name": "Sawmill",
		"description": "Abandoned sawmill with remnants of equipment.\n[color=#aaff00]Tools+.[/color]",
		"biomes": [BIOME.FOREST], # Биомы для руин
		"tile_id": 20 # Координаты тайла руин в атласе
	},
	POI_TYPE.VILLAGE: {
		"name": "Village",
		"description": "People used to live here.\n[color=#aaff00]Food+[/color]",
		"biomes": [BIOME.CLEARING, BIOME.HILL], # Биомы для деревни
		"tile_id": 21  # Координаты тайла деревни в атласе
	},
	POI_TYPE.CAMP: {
		"name": "Camp",
		"description": "Someone hiding here...\n[color=#aaff00]Enemy+[/color]",
		"biomes": ["ANY"], # "ANY" - лагерь в любом биоме
		"tile_id": 22 # Координаты тайла лагеря в атласе
	},
	POI_TYPE.HUNTER: {
		"name": "Hunter House",
		"description": "Just house in forest, nothing suspicious.\n[color=#aaff00]Weapon+[/color]",
		"biomes": [BIOME.HILL, BIOME.FOREST], # Биомы для дома охотника
		"tile_id": 23 # Координаты тайла дома охотника в атласе
	},
	POI_TYPE.EXTR_A: {
		"name": "Extraction Point A",
		"description": "Alpha Extraction Point",
		"biomes": [BIOME.CLEARING, BIOME.FOREST],
		"tile_id": 30
	},
	POI_TYPE.EXTR_B: {
		"name": "Extraction Point B",
		"description": "Beta Extraction Point",
		"biomes": [BIOME.CLEARING, BIOME.FOREST],
		"tile_id": 31 
	}
}

const ROAD_TILE_ID = 40 

var road_cells: Array[Vector2i] = []
var poi_cells: Array[Vector2i] = []

var poi_map = []

var biome_map = []  # 2D-массив для хранения биомов
var elevation_noise: FastNoiseLite
var moisture_noise: FastNoiseLite

var prev_dir = 0

@export var Width: int = 25
@export var Height: int = 20

@onready var fog_of_war: TileMapLayer = $"../FogOfWarTilemap"

var navigation: CustomNavigation

var collected_poi_data

func _ready():
	# Инициализация шума для высот
	elevation_noise = FastNoiseLite.new()
	elevation_noise.seed = randi()
	elevation_noise.frequency = 0.05
	elevation_noise.fractal_octaves = 4
	elevation_noise.fractal_gain = 0.7

	# Шум для влажности
	moisture_noise = FastNoiseLite.new()
	moisture_noise.seed = randi() + 1
	moisture_noise.frequency = 0.05

	generate_world()
	smooth_biomes(2)  # 1 проход сглаживания
	update_tilemap()
	
	generate_rivers()
	generate_poi()
	
	# Инициализация навигации
	navigation = CustomNavigation.new() # Создаем экземпляр CustomNavigation
	navigation.init(self) # Инициализируем CustomNavigation, передавая карту
	
	generate_roads()
	
	

func generate_world():
	var map_size = Vector2i(Width, Height)
	biome_map = []
	poi_map = [] # **Инициализация poi_map**
	
	# Заполняем карту биомов
	for x in range(map_size.x):
		biome_map.append([])
		poi_map.append([])
		for y in range(map_size.y):
			var elevation = elevation_noise.get_noise_2d(x, y)
			var moisture = moisture_noise.get_noise_2d(x, y)
			biome_map[x].append(get_biome_id(elevation, moisture))
			poi_map[x].append(POI_TYPE.NONE)

func smooth_biomes(passes: int):
	for _pass in range(passes):
		var new_map = biome_map.duplicate(true)
		
		for x in range(biome_map.size()):
			for y in range(biome_map[0].size()):
				# Пропускаем реки и горы
				if biome_map[x][y] == BIOME.RIVER || biome_map[x][y] == BIOME.MOUNTAIN:
					continue
				
				var neighbors = get_neighbors(x, y)
				var biome_counts = {}
				
				# Считаем соседей
				for neighbor in neighbors:
					var bx = neighbor.x
					var by = neighbor.y
					if bx >= 0 && bx < biome_map.size() && by >= 0 && by < biome_map[0].size():
						var b = biome_map[bx][by]
						biome_counts[b] = biome_counts.get(b, 0) + 1
				
				# Выбираем самый частый биом
				var max_biome = biome_map[x][y]
				var max_count = 0
				for b in biome_counts:
					if biome_counts[b] > max_count:
						max_biome = b
						max_count = biome_counts[b]
				
				new_map[x][y] = max_biome
		
		biome_map = new_map

func get_neighbors(x: int, y: int) -> Array:
	# Возвращает 8 соседних клеток (включая диагонали)
	return [
		Vector2i(x-1, y-1), Vector2i(x, y-1), Vector2i(x+1, y-1),
		Vector2i(x-1, y),                     Vector2i(x+1, y),
		Vector2i(x-1, y+1), Vector2i(x, y+1), Vector2i(x+1, y+1)
	]

func update_tilemap():
	for x in range(biome_map.size()):
		for y in range(biome_map[0].size()):
			var cell = Vector2i(x, y)
			set_cell(cell, biome_map[x][y], Vector2i(0, 0))


func get_biome_id(elevation: float, moisture: float) -> int:
	var normalized_elevation = (elevation + 1) / 2.0
	var normalized_moisture = (moisture + 1) / 2.0

	if normalized_elevation > 0.7:
		return BIOME.MOUNTAIN
	elif normalized_elevation > 0.6:
		return BIOME.HILL
	elif normalized_elevation < 0.4:
		return BIOME.SWAMP if normalized_moisture > 0.55 else BIOME.CLEARING
	else:
		return BIOME.FOREST if normalized_moisture > 0.5 else BIOME.CLEARING

func generate_rivers():
	var num_rivers = 100
	for _i in num_rivers:
		var start_x = randi_range(1, Width-2)  # Карта 20x20
		var start_y = randi_range(1, 6)  # Верхняя часть карты
		
		# Получаем биом через шумы
		var elevation = elevation_noise.get_noise_2d(start_x, start_y)
		var moisture = moisture_noise.get_noise_2d(start_x, start_y)
		var biome_id = get_biome_id(elevation, moisture)
		
		if biome_id != 4:
			continue
		print("Generate river at x: ", start_x, " y: ", start_y, " at biome: ", biome_id)
		# Генерация реки
		biome_map[start_x][start_y] = BIOME.RIVER
		await generate_single_river(start_x, start_y+1)
		break

func generate_single_river(start_x: int, start_y: int):
	var x = start_x
	var y = start_y
	
	while y < Height:
		biome_map[x][y] = BIOME.RIVER
		set_cell(Vector2i(x,y),6,Vector2i(0,0))
		queue_redraw()
		
		#await get_tree().create_timer(0.5).timeout # Задержка генерации
		
		if prev_dir == 0:
			var dir = randi() % 3
			if x == 1 or x == Width-2:
				if dir == 1 and x == 1:
					dir = 2
				if dir == 2 and x == Width-2:
					dir = 1
			set_river_cell(x,y,dir)
			match dir:
				0: y += 1
				1: x = clamp(x - 1, 1, Width-2)
				2: x = clamp(x + 1, 1, Width-2)
			prev_dir = dir
		else:
			var dir = randi() % 2
			
			if dir == 0:
				set_river_cell(x,y,dir)
				y += 1
				prev_dir = 0
			else:
				if prev_dir == 1:
					set_river_cell(x,y,1)
					x = clamp(x - 1, 1, Width-2)
					prev_dir = 1
				else:
					set_river_cell(x,y,2)
					x = clamp(x + 1, 1, Width-2)
					prev_dir = 2
			
func set_river_cell(x,y,dir):
	if dir != prev_dir:
		match prev_dir:
			0: match dir:
				1: set_cell(Vector2i(x,y),8,Vector2i(0,0))
				2: set_cell(Vector2i(x,y),7,Vector2i(0,0))
			1: set_cell(Vector2i(x,y),9,Vector2i(0,0))
			2: set_cell(Vector2i(x,y),10,Vector2i(0,0))
				
	else:
		if dir != 0:
			set_cell(Vector2i(x,y),5,Vector2i(0,0))
		else:
			set_cell(Vector2i(x,y),6,Vector2i(0,0))
			
func generate_poi():
	var sawmill_count = 0
	var village_count = 0
	var extr_a_placed = false
	var extr_b_placed = false
	const MAX_SAWMILLS = 2
	const MAX_VILLAGES = 2
	const MIN_DISTANCE_BETWEEN_EXTR = 10 # Минимальное расстояние между точками эвакуации (в клетках)
	var placed_extr_a_cell: Vector2i

	# **Генерация Точек Эвакуации (EXTR_A и EXTR_B) на краю карты - ДЕЙСТВИТЕЛЬНО СЛУЧАЙНО**
	var edge_cells = get_edge_cells()
	edge_cells.shuffle() # **ПЕРЕМЕШИВАЕМ массив edge_cells для случайного выбора**

	# Попытка разместить EXTR_A на СЛУЧАЙНОЙ клетке края карты
	for cell in edge_cells:
		if !extr_a_placed && poi_map[cell.x][cell.y] == POI_TYPE.NONE && biome_map[cell.x][cell.y] in POI_DATA[POI_TYPE.EXTR_A].biomes && biome_map[cell.x][cell.y] != BIOME.RIVER:
			poi_map[cell.x][cell.y] = POI_TYPE.EXTR_A
			set_cell(cell, POI_DATA[POI_TYPE.EXTR_A].tile_id, Vector2i(0,0))
			queue_redraw()
			extr_a_placed = true
			placed_extr_a_cell = cell
			print("EXTR_A placed at random edge cell: ", cell)
			poi_cells.append(cell)
			print("PoiCellsWithA: ", poi_cells)
			edge_cells.erase(cell)
			break

	# Попытка разместить EXTR_B на СЛУЧАЙНОЙ клетке края карты (если EXTR_A размещена) - с проверкой расстояния
	if extr_a_placed:
		edge_cells.shuffle() # **ПЕРЕМЕШИВАЕМ массив edge_cells ПЕРЕД размещением EXTR_B**
		for cell in edge_cells:
			if !extr_b_placed && poi_map[cell.x][cell.y] == POI_TYPE.NONE && biome_map[cell.x][cell.y] in POI_DATA[POI_TYPE.EXTR_B].biomes && biome_map[cell.x][cell.y] != BIOME.RIVER && cell.distance_to(placed_extr_a_cell) >= MIN_DISTANCE_BETWEEN_EXTR:
				poi_map[cell.x][cell.y] = POI_TYPE.EXTR_B
				set_cell(cell, POI_DATA[POI_TYPE.EXTR_B].tile_id, Vector2i(0,0))
				queue_redraw()
				extr_b_placed = true
				print("EXTR_B placed at random edge cell: ", cell)
				poi_cells.append(cell)
				print("PoiCellsWithB: ", poi_cells)
				edge_cells.erase(cell)
				break

	# **Генерация остальных POI (RUINS, VILLAGE, CAMP, TOWER, SAWMILL) - без изменений**
	var num_poi_attempts = 15
	for _i in num_poi_attempts:
		var x = randi() % Width
		var y = randi() % Height
		var cell = Vector2i(x, y)

		if poi_map[x][y] != POI_TYPE.NONE:
			continue

		if biome_map[cell.x][cell.y] == BIOME.RIVER:
			continue

		var biome_id = biome_map[cell.x][cell.y]
		var possible_pois = []

		for poi_type in POI_DATA.keys():
			if poi_type == POI_TYPE.NONE or poi_type == POI_TYPE.EXTR_A or poi_type == POI_TYPE.EXTR_B:
				continue

			if poi_type == POI_TYPE.SAWMILL and sawmill_count >= MAX_SAWMILLS:
				continue
			if poi_type == POI_TYPE.VILLAGE and village_count >= MAX_VILLAGES:
				continue

			if "ANY" in POI_DATA[poi_type].biomes || biome_id in POI_DATA[poi_type].biomes:
				possible_pois.append(poi_type)

		if possible_pois.is_empty():
			continue

		var selected_poi_type = possible_pois.pick_random()

		if selected_poi_type == POI_TYPE.SAWMILL:
			sawmill_count += 1
		elif selected_poi_type == POI_TYPE.VILLAGE:
			village_count += 1

		poi_map[x][y] = selected_poi_type
		var tile_id = POI_DATA[selected_poi_type].tile_id
		set_cell(cell, tile_id, Vector2i(0,0))
		poi_cells.append(cell)
		
		queue_redraw()
	print("PoiCellsFinal: ", poi_cells)

func get_map_width_pixels():
	return Width * tile_set.tile_size.x

func get_map_height_pixels():
	return Height * tile_set.tile_size.y
	
func get_move_cost(cell: Vector2i) -> int:
	
		
	if fog_of_war.is_tile_visible(cell): # Проверяем видимость клетки через туман войны
		if cell in road_cells:  # Проверяем наличие дороги
			return 1
		if poi_map.size() > cell.x && poi_map[0].size() > cell.y && poi_map[cell.x][cell.y] != POI_TYPE.NONE: # **Проверяем, есть ли POI на видимой клетке**
			return 1 # **Если есть POI, стоимость перемещения всегда 1**
		else: # **Если на видимой клетке нет POI, определяем стоимость по биому**
			var biome = biome_map[cell.x][cell.y]
			return TERRAIN_COST.get(biome, 1)  # По умолчанию 1
	else: # **Если клетка не видна в тумане войны**
		return 999999 # Возвращаем очень высокую стоимость, чтобы сделать клетку недостижимой

func get_move_cost_no_fog(cell: Vector2i) -> int:
	
	if cell in road_cells:  # Проверяем наличие дороги
		return 1
	var biome = biome_map[cell.x][cell.y]
	return TERRAIN_COST.get(biome, 1)  # По умолчанию 1

func is_cell_passable(cell: Vector2i) -> bool:
	return get_move_cost(cell) != -1
	
func get_edge_cells() -> Array[Vector2i]:
	var edge_cells: Array[Vector2i] = []
	for x in range(Width):
		for y in range(Height):
			if x == 0 or x == Width - 1 or y == 0 or y == Height - 1:
				edge_cells.append(Vector2i(x, y))
	return edge_cells

func get_navigation():
	return navigation
	
func set_custom_biome(cell:Vector2i,id, tile_id):
	biome_map[cell.x][cell.y] = id
	set_cell(cell,tile_id,Vector2i(0,0))
	
func generate_roads():
	collected_poi_data = collect_poi_data()
	var poi_start_1 = get_random_poi_coordinates_and_remove_from_list(collected_poi_data)
	var poi_start_2 = get_random_poi_coordinates_and_remove_from_list(collected_poi_data)
	var poi1cell = Vector2i(poi_start_1["x"],poi_start_1["y"])
	var poi2cell = Vector2i(poi_start_2["x"],poi_start_2["y"])
	print("Старт: ", poi1cell)
	print("Финиш: ", poi2cell)
	var path = navigation.find_path_with_cost_no_fog(poi1cell,poi2cell)
	path.pop_front()
	path.pop_back()
	for cell in range(path.size()):
		if path[cell] in poi_cells:
			print("ТутPoi")
			continue
		#set_custom_biome(path[cell],6,41) #Временно потом поменять 41 на 40
		#await get_tree().create_timer(0.5).timeout #Временно потом убрать
		set_custom_biome(path[cell],6,40) #Временно потом убрать
		road_cells.append(path[cell])
	navigation.init(self)
	while not collected_poi_data.is_empty():
		var poi1
		var poi2
		if randi() % 2 == 0:
			poi1 = poi_start_1
		else:
			poi1 = poi_start_2
		poi2 = get_random_poi_coordinates_and_remove_from_list(collected_poi_data)
		poi1cell = Vector2i(poi1["x"],poi1["y"])
		poi2cell = Vector2i(poi2["x"],poi2["y"])
		print("Старт: ", poi1cell)
		print("Финиш: ", poi2cell)
		path = navigation.find_path_with_cost_no_fog(poi1cell,poi2cell)
		path.pop_front()
		path.pop_back()
		for cell in range(path.size()):
			if path[cell] in poi_cells:
				print("ТутPoi")
				continue
			#set_custom_biome(path[cell],6,41) #Временно потом поменять 41 на 40
			#await get_tree().create_timer(0.5).timeout #Временно потом убрать
			set_custom_biome(path[cell],6,40) #Временно потом убрать
			road_cells.append(path[cell])
		navigation.init(self)

func collect_poi_data() -> Array[Dictionary]:
	"""
	Собирает данные о всех не нулевых точках интереса (POI) из poi_map,
	включая их тип и координаты.

	Returns:
		Array[Dictionary]: Массив словарей, где каждый словарь представляет POI
		и содержит ключи: 'type', 'poi_type_enum', 'x', 'y'.
		Возвращает пустой массив, если не найдено ни одного POI, кроме NONE.
	"""
	var poi_list: Array[Dictionary] = []

	# Проходим по всей poi_map
	for x in range(poi_map.size()):
		for y in range(poi_map[0].size()):
			var poi_value = poi_map[x][y]

			# Проверяем, что значение POI не равно NONE (0)
			if poi_value == POI_TYPE.VILLAGE or poi_value == POI_TYPE.SAWMILL or poi_value == POI_TYPE.HUNTER or poi_value == POI_TYPE.EXTR_A or poi_value == POI_TYPE.EXTR_B:
				# Создаем словарь для хранения данных о POI
				var poi_data: Dictionary = {
					"poi_type_enum": POI_TYPE.values()[poi_value], # Получаем значение enum POI_TYPE (например, POI_TYPE.VILLAGE) -  более надежно и удобно для сравнений в коде
					"x": x, # Координата X
					"y": y  # Координата Y
				}
				poi_list.append(poi_data) # Добавляем словарь в список POI

	return poi_list

func get_random_poi_coordinates_and_remove_from_list(poi_array: Array[Dictionary]) -> Dictionary:
	"""
	Получает данные о случайной не нулевой точке интереса (POI) из poi_list
	и удаляет этот элемент из массива poi_list.

	Returns:
		Dictionary: Словарь с данными о случайно выбранной и удаленной POI (type, poi_type_enum, x, y).
		Возвращает пустой словарь, если не найдено ни одной POI, кроме NONE,
		или если произошла ошибка.
	"""

	if poi_array.is_empty(): # 2. Проверяем, пустой ли массив
		printerr("get_random_poi_coordinates_and_remove_from_list(): Не найдено POI, кроме NONE.")
		return {} # Возвращаем пустой словарь, если POI не найдены

	var random_index: int = randi() % poi_array.size() # 3. Получаем случайный индекс в пределах массива
	var random_poi_data: Dictionary = poi_array[random_index] # 4. Получаем данные POI по случайному индексу

	if random_poi_data == null: # Дополнительная проверка на null (для надежности)
		printerr("get_random_poi_coordinates_and_remove_from_list(): Ошибка при выборе случайной POI.")
		return {} # Возвращаем пустой словарь в случае ошибки

	# 5. Удаляем элемент из массива poi_array по случайному индексу
	poi_array.remove_at(random_index) # Удаляем элемент из массива poi_array

	# **Внимание:**  В этой версии функции мы НЕ меняем poi_map и не обновляем TileMap.
	# Удаление происходит ТОЛЬКО из локального массива poi_array, полученного от collect_poi_data().

	return random_poi_data # 6. Возвращаем данные об удаленной POI (словарь)

func get_tile_tooltip_data(cell: Vector2i) -> Dictionary:
	var data = {}
	if cell in poi_cells:
		data.type = "poi"
		data.poi_type = poi_map[cell.x][cell.y]
		data.name = POI_DATA[data.poi_type].name
		data.descr = POI_DATA[data.poi_type].description
	else:
		data.type = "biome"	
		data.biome_type = biome_map[cell.x][cell.y]
		data.name = TERRAIN_DATA[data.biome_type].name
		data.descr = TERRAIN_DATA[data.biome_type].description + "\n[color=#aaff00]Move cost: " + str(TERRAIN_COST[data.biome_type]) + "[/color]"
	return data
