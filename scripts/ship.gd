extends Node2D

# Function to set up the ship's visual parts based on coordinates
func setup(coords: Array[Vector2i], part_texture: Texture2D, tile_size: Vector2) -> void:
	# Clear any existing sprites first
	for child in get_children():
		if child is Sprite2D: # Ensure we only remove sprites, in case other nodes are added later
			child.queue_free()
			
	# Check if coordinates are provided
	if coords.is_empty():
		print("Warning: Ship received empty coordinates.")
		return

	# Use the first coordinate as the origin point for relative positioning
	var origin_coord: Vector2i = coords[0]

	# Create a sprite for each coordinate
	for coord in coords:
		# Calculate the position relative to the ship's origin grid cell
		var relative_coord: Vector2i = coord - origin_coord
		# Convert relative grid coordinates to relative pixel position
		var relative_pixel_pos: Vector2 = Vector2(relative_coord) * tile_size
		
		# Create the sprite
		var sprite = Sprite2D.new()
		sprite.texture = part_texture
		sprite.position = relative_pixel_pos
		
		# Add the sprite as a child of this Ship node
		add_child(sprite)
