@tool
extends SceneTree

func _init():
	print("Generating tileset texture...")
	var image = Image.create(128, 64, false, Image.FORMAT_RGBA8)
	
	# Draw Grass (Green)
	for x in range(64):
		for y in range(64):
			image.set_pixel(x, y, Color(0.3, 0.7, 0.3))
			# Add a subtle grid border to grass
			if x % 64 == 0 or y % 64 == 0 or x % 64 == 63 or y % 64 == 63:
				image.set_pixel(x, y, Color(0.2, 0.6, 0.2))
				
	# Draw Wall (Gray)
	for x in range(64, 128):
		for y in range(64):
			image.set_pixel(x, y, Color(0.5, 0.5, 0.5))
			# Add a subtle grid border to wall
			if x % 64 == 0 or y % 64 == 0 or x % 64 == 63 or y % 64 == 63:
				image.set_pixel(x, y, Color(0.4, 0.4, 0.4))
	
	var tex = ImageTexture.create_from_image(image)
	
	print("Configuring TileSet...")
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(64, 64)
	tileset.add_physics_layer()
	
	var source = TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(64, 64)
	source.create_tile(Vector2i(0, 0)) # Grass
	source.create_tile(Vector2i(1, 0)) # Wall
	
	tileset.add_source(source, 0)
	
	var wall_data = source.get_tile_data(Vector2i(1, 0), 0)
	wall_data.add_collision_polygon(0)
	# Polygon covering the full 64x64 tile (from -32 to 32)
	wall_data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-32, -32), Vector2(32, -32), Vector2(32, 32), Vector2(-32, 32)]))
	
	var ground_layer = TileMapLayer.new()
	ground_layer.name = "GroundLayer"
	ground_layer.z_index = -3
	ground_layer.y_sort_enabled = true
	ground_layer.tile_set = tileset
	
	# Fill map area (60x40 tiles)
	var map_width = 60
	var map_height = 40
	for x in range(-5, map_width + 5):
		for y in range(-5, map_height + 5):
			var is_border = x < 0 or x >= map_width or y < 0 or y >= map_height
			if is_border:
				ground_layer.set_cell(Vector2i(x, y), 0, Vector2i(1, 0)) # Wall
			else:
				ground_layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0)) # Grass
				
	# Add some random wall obstacles inside
	for i in range(15):
		var rx = randi_range(5, map_width - 5)
		var ry = randi_range(5, map_height - 5)
		if rx > 10 and ry > 10:
			ground_layer.set_cell(Vector2i(rx, ry), 0, Vector2i(1, 0))
			
	print("Saving ground_layer.tscn...")
	var new_packed = PackedScene.new()
	new_packed.pack(ground_layer)
	ResourceSaver.save(new_packed, "res://Scence/ground_layer.tscn")
	
	print("Setup complete.")
	quit()
