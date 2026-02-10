extends Node2D

@export var grass_scene: PackedScene
@export var chunk_size: float = 400.0  # Size of each chunk
@export var render_distance: int = 3    # How many chunks to render around player

var loaded_chunks: Dictionary = {}  # Key: Vector2i (chunk coord), Value: Array of grass nodes
var player: Node2D = null
var current_density_level: int = -1  # Track density level to reload chunks on change

func _ready() -> void:
	# Find player after scene is ready
	call_deferred("find_player")
	GameManager.upgrade_purchased.connect(_on_upgrade_purchased)

func find_player() -> void:
	player = get_tree().get_first_node_in_group("player")
	if player:
		current_density_level = GameManager.get_grass_density_level()
		update_chunks()

func _on_upgrade_purchased(upgrade_type: String, _level: int) -> void:
	if upgrade_type == "grass_density":
		# Reload all chunks with new density
		reload_all_chunks()

func _process(_delta: float) -> void:
	if player:
		update_chunks()

func get_chunk_coord(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / chunk_size),
		floori(world_pos.y / chunk_size)
	)

func update_chunks() -> void:
	if not player:
		return

	# Calculate player position relative to world (since world moves, not player)
	var relative_player_pos = player.global_position - global_position
	var player_chunk = get_chunk_coord(relative_player_pos)
	var chunks_to_load: Array[Vector2i] = []
	var chunks_to_keep: Dictionary = {}

	# Determine which chunks should be loaded
	for x in range(-render_distance, render_distance + 1):
		for y in range(-render_distance, render_distance + 1):
			var chunk_coord = Vector2i(player_chunk.x + x, player_chunk.y + y)
			chunks_to_keep[chunk_coord] = true
			if not loaded_chunks.has(chunk_coord):
				chunks_to_load.append(chunk_coord)

	# Unload distant chunks
	var chunks_to_unload: Array[Vector2i] = []
	for chunk_coord in loaded_chunks.keys():
		if not chunks_to_keep.has(chunk_coord):
			chunks_to_unload.append(chunk_coord)

	for chunk_coord in chunks_to_unload:
		unload_chunk(chunk_coord)

	# Load new chunks
	for chunk_coord in chunks_to_load:
		load_chunk(chunk_coord)

func load_chunk(chunk_coord: Vector2i) -> void:
	if loaded_chunks.has(chunk_coord):
		return

	var grass_list: Array[Node] = []
	var chunk_origin = Vector2(chunk_coord.x * chunk_size, chunk_coord.y * chunk_size)
	var spawned_positions: Array[Vector2] = []

	# Use chunk coordinate as seed for consistent generation
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(chunk_coord)

	# Get density settings from GameManager
	var grass_count = GameManager.get_grass_per_chunk()
	var min_spacing = GameManager.get_grass_min_spacing()

	for i in grass_count:
		var pos = get_random_position_in_chunk(chunk_origin, spawned_positions, rng, min_spacing)
		if pos != Vector2.INF:
			var grass = spawn_grass_at(pos, rng)
			if grass:
				grass_list.append(grass)
				spawned_positions.append(pos)

	loaded_chunks[chunk_coord] = grass_list

func unload_chunk(chunk_coord: Vector2i) -> void:
	if not loaded_chunks.has(chunk_coord):
		return

	var grass_list = loaded_chunks[chunk_coord]
	for grass in grass_list:
		if is_instance_valid(grass):
			grass.queue_free()

	loaded_chunks.erase(chunk_coord)

func get_random_position_in_chunk(chunk_origin: Vector2, existing: Array[Vector2], rng: RandomNumberGenerator, min_spacing: float) -> Vector2:
	var max_attempts = 30  # More attempts for denser grass

	for _attempt in max_attempts:
		var pos = Vector2(
			chunk_origin.x + rng.randf() * chunk_size,
			chunk_origin.y + rng.randf() * chunk_size
		)

		var valid = true
		for existing_pos in existing:
			if pos.distance_to(existing_pos) < min_spacing:
				valid = false
				break

		if valid:
			return pos

	return Vector2.INF

func reload_all_chunks() -> void:
	# Unload all chunks
	var all_coords = loaded_chunks.keys().duplicate()
	for chunk_coord in all_coords:
		unload_chunk(chunk_coord)

	# Update density level
	current_density_level = GameManager.get_grass_density_level()

	# Reload chunks around player
	update_chunks()

func spawn_grass_at(pos: Vector2, _rng: RandomNumberGenerator) -> Node:
	if not grass_scene:
		return null

	var grass = grass_scene.instantiate()
	grass.position = pos

	# Assign random grass type based on current quality level
	grass.grass_data = GameManager.get_random_grass_data()

	add_child(grass)
	return grass
