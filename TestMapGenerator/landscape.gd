extends TileMapLayer
@onready var map_generator: Node = $"../MapGenerator"

func get_map_width_pixels():
	return map_generator.map_width * tile_set.tile_size.x

func get_map_height_pixels():
	return map_generator.map_height * tile_set.tile_size.y
