extends Node2D

const ShipScene = preload("res://scenes/ship.tscn") # Preload the ship scene
const ShipPartTexture = preload("res://assets/placeholders/ship_part.png") # Load the texture

# Grid dimensions
const GRID_WIDTH: int = 10
const GRID_HEIGHT: int = 10

# Tile definitions
const MISS_SOURCE_ID: int = 2
const MISS_ATLAS_COORDS: Vector2i = Vector2i(0, 0)
const HIT_SOURCE_ID: int = 3
const HIT_ATLAS_COORDS: Vector2i = Vector2i(0, 0)
const SHIP_SOURCE_ID: int = 0 # Player ship tile
const SHIP_ATLAS_COORDS: Vector2i = Vector2i(0, 0)
const SEA_SOURCE_ID: int = 1
const SEA_ATLAS_COORDS: Vector2i = Vector2i(0, 0)
const WRECK_SOURCE_ID: int = 4 # Sunk ship part tile
const WRECK_ATLAS_COORDS: Vector2i = Vector2i(0, 0)

# Standard ship sizes
const SHIP_SIZES: Array[int] = [5, 4, 3, 3, 2]

# Hardcoded enemy ship locations (replace with actual placement logic later)
# var enemy_ship_locations: Array[Vector2i] = [Vector2i(3, 3), Vector2i(3, 4), Vector2i(6, 7)]
# Hardcoded player ship locations (replace with actual placement logic later)
# var player_ship_locations: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(5, 5)]

# Ship locations generated at runtime - Structure: Array[Array[Vector2i]] (Array of ships, each ship is an Array of coords)
var player_ship_locations: Array = []
var enemy_ship_locations: Array = []

# Tracks coordinates the enemy has already attacked
var enemy_attacked_coords: Array[Vector2i] = []
# Tracks which specific ship parts have been hit
var player_hit_locations: Array[Vector2i] = []
var enemy_hit_locations: Array[Vector2i] = []

# Tracks which entire ships have been sunk
var player_sunk_ships: Array = []
var enemy_sunk_ships: Array = []

# Game state flag
var game_over: bool = false

# Enemy AI instance
var enemy_ai: EnemyAI

# References to the tilemap layers
@onready var player_grid_base: TileMapLayer = $PlayerGrid_Base # Renamed
@onready var player_grid_overlay: TileMapLayer = $PlayerGrid_Overlay # Added
@onready var enemy_grid: TileMapLayer = $EnemyGrid
@onready var ships_container: Node2D = $ShipsContainer # Reference to the container

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Generate random ship placements for both players
	player_ship_locations = _generate_ship_placements(SHIP_SIZES)
	enemy_ship_locations = _generate_ship_placements(SHIP_SIZES)
	
	# Initialize the Enemy AI
	enemy_ai = EnemyAI.new()
	# Pass grid dimensions to AI if needed, using default for now
	enemy_ai.reset(GRID_WIDTH, GRID_HEIGHT) 
	
	print("Player Ships: ", player_ship_locations)
	# print("Enemy Ships: ", enemy_ship_locations) # Keep enemy ships hidden for now
	
	reset_game_board()
	print("Game board ready.")
	# Draw player ships onto the player grid -- MOVED TO reset_game_board
	# Initialization logic will go here
	pass

# Resets the game board to its initial state
func reset_game_board() -> void:
	# Reset game state flag
	game_over = false
	# Ensure input is enabled for the new game -- Redundant now
	# set_process_input(true) 

	# Reset UI Labels
	%TurnStatusLabel.text = "Player's Turn"
	%MessageLabel.text = ""
	# Initialize ship count labels
	var initial_ship_count = SHIP_SIZES.size()
	%PlayerShipLabel.text = "Player Ships Left: %d" % initial_ship_count
	%EnemyShipLabel.text = "Enemy Ships Left: %d" % initial_ship_count

	# Generate new ship placements for both players
	player_ship_locations = _generate_ship_placements(SHIP_SIZES)
	enemy_ship_locations = _generate_ship_placements(SHIP_SIZES)
	print("New Player Ships: ", player_ship_locations)
	# print("New Enemy Ships: ", enemy_ship_locations) # Keep enemy ships hidden

	enemy_attacked_coords.clear() # Clear enemy attack history
	player_hit_locations.clear()
	enemy_hit_locations.clear()
	player_sunk_ships.clear()
	enemy_sunk_ships.clear()
	
	# Reset the Enemy AI state
	if enemy_ai != null:
		enemy_ai.reset(GRID_WIDTH, GRID_HEIGHT)
	else:
		# Initialize if it wasn't ready yet (e.g., called before _ready)
		enemy_ai = EnemyAI.new()
		enemy_ai.reset(GRID_WIDTH, GRID_HEIGHT)

	# Re-add sea tiles to base player grid and enemy grid
	# Clear the player overlay grid
	player_grid_overlay.clear() # Clear previous hits/misses
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			player_grid_base.set_cell(Vector2i(x, y), SEA_SOURCE_ID, SEA_ATLAS_COORDS) # Use base grid
			enemy_grid.set_cell(Vector2i(x, y), SEA_SOURCE_ID, SEA_ATLAS_COORDS)
	
	# Clear any existing ship instances from the container
	for ship_node in ships_container.get_children():
		ship_node.queue_free()

	# Instantiate and place ship instances based on generated locations
	for ship_coords_array in player_ship_locations:
		if ship_coords_array.is_empty(): # Skip if something went wrong in generation
			continue 
			
		# Instantiate a ship scene
		var ship_instance = ShipScene.instantiate()

		# Get the first coordinate to determine the ship instance's main position
		var first_coord: Vector2i = ship_coords_array[0]
		# Calculate the absolute screen position for the ship instance
		# Use base grid for positioning reference
		var absolute_pos: Vector2 = player_grid_base.position + player_grid_base.map_to_local(first_coord) 
		ship_instance.position = absolute_pos

		# Get the tile size from the base grid's TileSet
		var tile_size: Vector2 = player_grid_base.tile_set.tile_size 
		
		# Call the ship's setup function to create its parts
		ship_instance.setup(ship_coords_array, ShipPartTexture, tile_size)
		
		# Add the configured ship instance to the container
		ships_container.add_child(ship_instance)

	# Make sure input is enabled at the start
	set_process_input(true)


# Called every frame. 'delta' is the elapsed time since the previous frame.
# func _process(delta: float) -> void:
# 	pass


# Called when an input event occurs
func _input(event: InputEvent) -> void:
	# Handle game restart input if the game is over
	if game_over and event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_R:
			print("Restarting game...")
			reset_game_board()
			return # Prevent further input processing this frame

	# Only process mouse clicks if the game is not over
	if not game_over and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Get global mouse position and convert it to the enemy_grid's local coordinates
		var global_mouse_pos: Vector2 = get_global_mouse_position()
		var enemy_grid_local_pos: Vector2 = enemy_grid.to_local(global_mouse_pos)
		
		# Convert the grid-local position to map coordinates
		var map_coords: Vector2i = enemy_grid.local_to_map(enemy_grid_local_pos)
		
		# Check if the map coordinates are within the grid boundaries
		if map_coords.x >= 0 and map_coords.x < GRID_WIDTH and map_coords.y >= 0 and map_coords.y < GRID_HEIGHT:
			# print("Clicked on Enemy Grid at map coordinates: ", map_coords)
			# Call the attack handler
			handle_attack_on_enemy(map_coords)
			pass
	pass

# Handles an attack initiated by the player on the enemy grid
func handle_attack_on_enemy(map_coords: Vector2i) -> void:
	# Check if the cell has already been marked as hit or miss
	var curr_source_id: int = enemy_grid.get_cell_source_id(map_coords)
	if curr_source_id == HIT_SOURCE_ID or curr_source_id == MISS_SOURCE_ID : 
		print("Cell already attacked at: ", map_coords)
		return # Do nothing if already attacked

	# Process the attack
	var _game_ended: bool = _process_attack(map_coords, enemy_grid, enemy_ship_locations, enemy_hit_locations, enemy_sunk_ships, "Player", "Enemy")

	# Only let enemy take a turn if the game isn't over
	if not game_over: # Check game_over flag directly, as it's set within _process_attack
		# Update turn status before enemy turn
		%TurnStatusLabel.text = "Enemy's Turn"
		# After player attacks, enemy takes a turn (simple random attack for now)
		# Add a small delay so the player sees the result before the enemy moves
		await get_tree().create_timer(0.1).timeout # Small delay
		execute_enemy_turn()
	else:
		set_process_input(true)

# Enemy AI takes its turn (currently random attack)
func execute_enemy_turn() -> void:
	set_process_input(false)
	# Prevent infinite loop if somehow all cells are attacked
	if enemy_attacked_coords.size() >= GRID_WIDTH * GRID_HEIGHT:
		print("Enemy has no valid moves left.")
		# Re-enable input even if enemy can't move
		set_process_input(true) 
		# Update turn status back to player if game isn't over
		if not game_over:
			%TurnStatusLabel.text = "Player's Turn" 
		return
	
	# Get the target coordinate from the AI
	var target_coord: Vector2i = enemy_ai.get_next_target(enemy_attacked_coords)
	
	# Delay for 0.5 seconds to simulate enemy thinking
	await get_tree().create_timer(0.5).timeout

	# Add to attacked list - IMPORTANT: Do this *before* processing the attack
	# Otherwise, the AI might try to target this square again immediately
	enemy_attacked_coords.append(target_coord)
	
	print("Enemy attacks player at: ", target_coord)
	
	# Process the attack
	var _game_ended: bool = _process_attack(target_coord, player_grid_overlay, player_ship_locations, player_hit_locations, player_sunk_ships, "Enemy", "Player")

	# Re-enable input after attack processing is complete
	set_process_input(true)

	# Update turn status back to player only if game isn't over
	if not game_over:
		%TurnStatusLabel.text = "Player's Turn"

# Centralized function to process an attack on a coordinate
# Returns true if the attack resulted in game over, false otherwise
# The 'grid' parameter now refers to the grid where hits/misses should be drawn
# For the player, this is the overlay grid. For the enemy, it's their main grid.
func _process_attack(coord: Vector2i, grid: TileMapLayer, ship_locations: Array, hit_locations: Array, sunk_ships: Array, attacker_name: String, defender_name: String) -> bool:
	var hit_ship_flag: bool = false
	var hit_ship_index: int = -1
	var sunk_ship_flag: bool = false # Track if a sink occurred this turn
	var sunk_ship_coords: Array = [] # Store coords of the ship sunk this turn
	
	for i in range(ship_locations.size()):
		if ship_locations[i].has(coord):
			hit_ship_flag = true
			hit_ship_index = i
			break

	var attack_result: int # Use integers matching EnemyAI constants

	if hit_ship_flag:
		print(attacker_name, " Hit!")
		grid.set_cell(coord, HIT_SOURCE_ID, HIT_ATLAS_COORDS)
		hit_locations.append(coord)
		attack_result = EnemyAI.HIT # Use constant from AI class

		# Check if this hit sunk a ship
		var target_ship = ship_locations[hit_ship_index]
		if _check_ship_sunk(target_ship, hit_locations) and not sunk_ships.has(target_ship):
			sunk_ships.append(target_ship)
			sunk_ship_flag = true
			sunk_ship_coords = target_ship # Store coords for AI report
			attack_result = EnemyAI.SINK # Upgrade result to SINK
			print(defender_name, " ship sunk!")
			%MessageLabel.text = defender_name + " ship sunk!"
			# Change hit tiles to wreck tiles for the sunk ship
			for wreck_coord in target_ship:
				grid.set_cell(wreck_coord, WRECK_SOURCE_ID, WRECK_ATLAS_COORDS)
			# Consider how this message interacts with the win message

			# --- Update Ship Count UI ---
			if defender_name == "Player":
				var player_ships_left = player_ship_locations.size() - player_sunk_ships.size()
				%PlayerShipLabel.text = "Player Ships Left: %d" % player_ships_left
			elif defender_name == "Enemy":
				var enemy_ships_left = enemy_ship_locations.size() - enemy_sunk_ships.size()
				%EnemyShipLabel.text = "Enemy Ships Left: %d" % enemy_ships_left
			# --------------------------
	else:
		# It's a miss
		print(attacker_name, " Miss.")
		grid.set_cell(coord, MISS_SOURCE_ID, MISS_ATLAS_COORDS)
		attack_result = EnemyAI.MISS # Use constant from AI class

	# --- AI Reporting --- 
	# If the enemy just attacked, report the result to the AI
	if attacker_name == "Enemy":
		enemy_ai.report_attack_result(coord, attack_result, sunk_ship_coords, enemy_attacked_coords)
		# Note: We pass enemy_attacked_coords which now includes the current 'coord'
		# This is important so the AI knows not to target it again immediately.

	# --- Check Game Over AFTER processing hit/miss/sink --- 
	# Check for game over (This check should happen regardless of who attacked)
	var game_over_status = check_game_over()
	if game_over_status != 0:
		game_over = true
		set_process_input(false) # Disable input immediately on game over
		%TurnStatusLabel.text = "Game Over!"
		if game_over_status == 1: # Player wins
			print("Player Wins!")
			%MessageLabel.text = "Player Wins! Press R to Restart"
		else: # Enemy wins
			print("Enemy Wins!")
			%MessageLabel.text = "Enemy Wins! Press R to Restart"
		return true # Game ended

	# Return false if game did not end this turn
	return false

# Checks if the game has ended
# Returns: 0 = Ongoing, 1 = Player Wins, 2 = Enemy Wins
func check_game_over() -> int:
	if enemy_sunk_ships.size() >= enemy_ship_locations.size(): # Check against total number of ships
		return 1 # All enemy ships sunk, player wins
	if player_sunk_ships.size() >= player_ship_locations.size(): # Check against total number of ships
		return 2 # All player ships sunk, enemy wins
	return 0 # Game is ongoing

# Checks if all coordinates of a specific ship are present in the list of hits
func _check_ship_sunk(ship_coords: Array[Vector2i], hit_locations: Array[Vector2i]) -> bool:
	for coord in ship_coords:
		if not hit_locations.has(coord):
			return false # Found a part of the ship that hasn't been hit
	return true # All parts of the ship have been hit

# Generates valid, non-overlapping ship placements for a given set of ship sizes
# Returns an Array of Arrays: Array[Array[Vector2i]]
func _generate_ship_placements(sizes: Array[int]) -> Array:
	var all_placed_ships: Array = [] # Holds the final list of ships (each an array of coords)
	var occupied_coords: Array[Vector2i] = [] # Tracks all occupied cells during generation
	
	for ship_size in sizes:
		var placed_successfully: bool = false
		while not placed_successfully:
			var start_coord: Vector2i = Vector2i(randi_range(0, GRID_WIDTH - 1), randi_range(0, GRID_HEIGHT - 1))
			var direction: int = randi_range(0, 1) # 0 = horizontal, 1 = vertical
			
			var fits: bool = true
			var current_ship_coords: Array[Vector2i] = [] # Coords for this attempt
			
			for i in range(ship_size):
				var cell_coord: Vector2i
				if direction == 0: # Horizontal
					cell_coord = start_coord + Vector2i(i, 0)
				else: # Vertical
					cell_coord = start_coord + Vector2i(0, i)
				
				# Check boundaries
				if cell_coord.x < 0 or cell_coord.x >= GRID_WIDTH or cell_coord.y < 0 or cell_coord.y >= GRID_HEIGHT:
					fits = false
					break
					
				# Check overlap with already placed ships IN THIS GENERATION
				if occupied_coords.has(cell_coord):
					fits = false
					break
					
				current_ship_coords.append(cell_coord)
			
			# If the ship fits and doesn't overlap after checking all its cells
			if fits:
				# Add this ship's coords to the list of placed ships
				all_placed_ships.append(current_ship_coords)
				# Add its coords to the overall occupied list for collision checking
				for coord in current_ship_coords:
					occupied_coords.append(coord)
				placed_successfully = true # Move to the next ship size
			# If not fits, the loop continues to try a new random spot/direction
	
	# Once all ships are placed, return the list of ships
	# all_ship_coords = current_placement_coords.duplicate() # Old flat list
	return all_placed_ships
