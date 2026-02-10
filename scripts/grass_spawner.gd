extends Node2D

@export var grass_scene: PackedScene
@export var chunk_size: float = 400.0  # Size of each chunk
@export var render_distance: int = 3    # How many chunks to render around player
@export var grass_per_chunk: int = 8    # Grass count per chunk
@export var min_spacing: float = 60.0

var grass_data_list: Array[GrassData] = []
var loaded_chunks: Dictionary = {}  # Key: Vector2i (chunk coord), Value: Array of grass nodes
var player: Node2D = null

func _ready() -> void:
	load_grass_data()
	# Find player after scene is ready
	call_deferred("find_player")

func find_player() -> void:
	player = get_tree().get_first_node_in_group("player")
	if player:
		update_chunks()

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

	for i in grass_per_chunk:
		var pos = get_random_position_in_chunk(chunk_origin, spawned_positions, rng)
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

func get_random_position_in_chunk(chunk_origin: Vector2, existing: Array[Vector2], rng: RandomNumberGenerator) -> Vector2:
	var max_attempts = 20

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

func spawn_grass_at(pos: Vector2, rng: RandomNumberGenerator) -> Node:
	if not grass_scene:
		return null

	var grass = grass_scene.instantiate()
	grass.position = pos

	# Assign random grass type with weighted probability
	# Base rates: 70% normal, 25% tough, 5% golden
	# Level 18 (quality_level 17) = 100% golden
	var quality_level = GameManager.get_grass_quality_level()

	# Golden increases from 5% to 100% over 17 levels
	var golden_chance = min(0.05 + quality_level * (0.95 / 17.0), 1.0)

	# Remaining probability split between normal and tough (keeping original ratio)
	var remaining = 1.0 - golden_chance
	var normal_chance = remaining * 0.74  # 70/(70+25)
	var tough_chance = remaining * 0.26   # 25/(70+25)

	var roll = rng.randf()
	if roll < golden_chance:
		grass.grass_data = grass_data_list[2]  # Golden (check first for high levels)
	elif roll < golden_chance + tough_chance:
		grass.grass_data = grass_data_list[1]  # Tough
	else:
		grass.grass_data = grass_data_list[0]  # Normal

	add_child(grass)
	return grass

func load_grass_data() -> void:
	var normal_grass = GrassData.new()
	normal_grass.grass_name = "Normal Grass"
	normal_grass.max_health = 1
	normal_grass.regen_time = 5.0
	normal_grass.min_drop_value = 1
	normal_grass.max_drop_value = 1
	normal_grass.drop_chance = 1.0
	normal_grass.color = Color(0.3, 0.7, 0.3)  # 밝은 초록
	normal_grass.cut_color = Color(0.5, 0.4, 0.2)

	var tough_grass = GrassData.new()
	tough_grass.grass_name = "Tough Grass"
	tough_grass.max_health = 3
	tough_grass.regen_time = 8.0
	tough_grass.min_drop_value = 5
	tough_grass.max_drop_value = 5
	tough_grass.drop_chance = 1.0
	tough_grass.color = Color(0.15, 0.4, 0.35)  # 청록색 (구분용)
	tough_grass.cut_color = Color(0.3, 0.35, 0.25)

	var golden_grass = GrassData.new()
	golden_grass.grass_name = "Golden Grass"
	golden_grass.max_health = 2
	golden_grass.regen_time = 15.0
	golden_grass.min_drop_value = 10
	golden_grass.max_drop_value = 10
	golden_grass.drop_chance = 1.0
	golden_grass.color = Color(0.9, 0.8, 0.2)  # 황금색
	golden_grass.cut_color = Color(0.6, 0.5, 0.1)

	grass_data_list.append(normal_grass)
	grass_data_list.append(tough_grass)
	grass_data_list.append(golden_grass)
