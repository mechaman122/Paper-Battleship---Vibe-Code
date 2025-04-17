extends Object
class_name EnemyAI

enum AIState { HUNTING, TARGETING }

# --- Constants ---
const MISS: int = 0
const HIT: int = 1
const SINK: int = 2

# --- State Variables ---
var state: AIState = AIState.HUNTING
var target_queue: Array[Vector2i] = []
# Keep track of the initial hit(s) that triggered targeting mode
var _hit_origins: Array[Vector2i] = [] 
# Store grid dimensions - needed for bounds checks
var _grid_width: int = 10 
var _grid_height: int = 10

# Called to reset the AI to its initial state
func reset(grid_w: int = 10, grid_h: int = 10) -> void:
	state = AIState.HUNTING
	target_queue.clear()
	_hit_origins.clear()
	_grid_width = grid_w
	_grid_height = grid_h
	print("Enemy AI Reset. State: HUNTING")

# Determines the next coordinate for the enemy to attack
func get_next_target(attacked_coords: Array[Vector2i]) -> Vector2i:
	var target_coord: Vector2i

	# --- Targeting State Logic ---
	if state == AIState.TARGETING:
		while not target_queue.is_empty():
			target_coord = target_queue.pop_front() # Try the oldest target first
			if not attacked_coords.has(target_coord):
				# print("AI Targeting: Popped valid target ", target_coord)
				return target_coord
			# else: print("AI Targeting: Popped invalid target ", target_coord, " from queue")
		
		# If the queue is empty, targeting failed or finished for this origin
		# print("AI Targeting: Queue empty, switching back to HUNTING")
		state = AIState.HUNTING
		_hit_origins.clear() # Clear origins as we are giving up on this target area

	# --- Hunting State Logic (Parity Check or if Targeting queue became empty) ---
	# print("AI Hunting (Parity Check): Searching for target...")
	var found_valid_target: bool = false
	var parity_check_active: bool = true # Start with parity check
	var max_attempts: int = 100 # Safeguard against infinite loops
	var attempts: int = 0
	
	while not found_valid_target:
		attempts += 1
		if attempts > max_attempts:
			# print("AI Hunting: Parity check timed out, switching to random hunt.")
			parity_check_active = false # Fallback to random non-parity check
			
		target_coord = Vector2i(randi_range(0, _grid_width - 1), randi_range(0, _grid_height - 1))
		
		var is_valid_parity: bool = (target_coord.x + target_coord.y) % 2 == 0 # Check for even parity
		var is_attacked: bool = attacked_coords.has(target_coord)
		
		if not is_attacked:
			if parity_check_active:
				if is_valid_parity:
					found_valid_target = true
					# print("AI Hunting: Found valid parity target ", target_coord)
			else: # Parity check is no longer active (timed out or unnecessary)
				found_valid_target = true
				# print("AI Hunting: Found valid random target (fallback) ", target_coord)
		
		if found_valid_target:
			break # Exit the while loop once a target is found
			
	# If somehow the loop finishes without finding a target (shouldn't happen if attacked_coords < total cells)
	# This is an extra failsafe.
	if not found_valid_target:
		print("AI ERROR: Could not find any valid target coordinate!")
		# Default to (0,0) or handle error appropriately
		target_coord = Vector2i(0,0) 

	return target_coord

# Updates the AI's state based on the result of its last attack
func report_attack_result(attacked_coord: Vector2i, result: int, _sunk_ship: Array, attacked_coords: Array[Vector2i]) -> void:
	match result:
		HIT:
			# print("AI notified of HIT at ", attacked_coord)
			if state == AIState.HUNTING:
				# print("AI switching to TARGETING state")
				state = AIState.TARGETING
				_hit_origins.append(attacked_coord) # Store the first hit
				_add_adjacent_targets(attacked_coord, attacked_coords)
			elif state == AIState.TARGETING:
				# If already targeting, add new adjacent targets from the new hit
				# Avoid adding the same origin multiple times if we hit near it again
				if not _hit_origins.has(attacked_coord):
					_hit_origins.append(attacked_coord)
				# Ensure the hit coord itself isn't in the queue
				if target_queue.has(attacked_coord):
					target_queue.erase(attacked_coord) 
				_add_adjacent_targets(attacked_coord, attacked_coords)
				
		SINK:
			# print("AI notified of SINK")
			# print("AI switching back to HUNTING state")
			state = AIState.HUNTING
			target_queue.clear() # Clear queue, we found the whole ship
			_hit_origins.clear() # Clear origins
			# Optional: Could remove all coords related to the sunk ship from attacked_coords 
			# if needed elsewhere, but AI uses attacked_coords read-only.
			
		MISS:
			# print("AI notified of MISS at ", attacked_coord)
			# If miss while targeting, just continue. get_next_target handles empty queue.
			# Ensure the missed coord isn't in the queue (might happen if added from multiple origins)
			if target_queue.has(attacked_coord):
				target_queue.erase(attacked_coord)
			pass 

# Helper function to add valid adjacent cells to the target queue
func _add_adjacent_targets(coord: Vector2i, attacked_coords: Array[Vector2i]) -> void:
	# print("AI adding adjacent targets around ", coord)
	var neighbors: Array[Vector2i] = [
		coord + Vector2i.UP,
		coord + Vector2i.DOWN,
		coord + Vector2i.LEFT,
		coord + Vector2i.RIGHT
	]
	
	for neighbor in neighbors:
		# Check bounds
		if neighbor.x >= 0 and neighbor.x < _grid_width and neighbor.y >= 0 and neighbor.y < _grid_height:
			# Check if not already attacked
			if not attacked_coords.has(neighbor):
				# Check if not already in the queue
				if not target_queue.has(neighbor):
					# print("AI Adding valid neighbor: ", neighbor)
					target_queue.append(neighbor) # Add to the end

	# print("AI Target Queue after adding: ", target_queue) 