extends Node2D

signal grass_cut(position: Vector2, value: int)

@export var chunk_size: float = 400.0
@export var render_distance: int = 2  # Reduced for performance

# Visual rendering with MultiMesh (ONE draw call for all grass!)
var multimesh_instance: MultiMeshInstance2D
var multimesh: MultiMesh

# Grass data storage (no nodes, just data)
var grass_data: Dictionary = {}  # Key: Vector2i (grid pos), Value: {cut: bool, type: int, regen_time: float}
var loaded_chunks: Dictionary = {}  # Key: Vector2i, Value: Array of grid positions

# Grid-based positioning (no spacing calculation needed)
var grid_cell_size: float = 40.0  # Base spacing between grass

var player: Node2D = null
var player_attack_area: Area2D = null

func _ready() -> void:
	setup_multimesh()
	call_deferred("find_player")
	GameManager.upgrade_purchased.connect(_on_upgrade_purchased)

func setup_multimesh() -> void:
	# Create MultiMesh for efficient grass rendering
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.mesh = create_grass_mesh()
	multimesh.instance_count = 0

	multimesh_instance = MultiMeshInstance2D.new()
	multimesh_instance.multimesh = multimesh

	# Apply grass sway shader (GPU-based animation - zero CPU cost!)
	var grass_shader = load("res://resources/shaders/grass_sway.gdshader")
	if grass_shader:
		var shader_mat = ShaderMaterial.new()
		shader_mat.shader = grass_shader
		multimesh_instance.material = shader_mat

	add_child(multimesh_instance)

func create_grass_mesh() -> ArrayMesh:
	# Simple triangle mesh for grass blade
	var mesh = ArrayMesh.new()
	var vertices = PackedVector2Array([
		Vector2(-6, 0),
		Vector2(6, 0),
		Vector2(0, -50)
	])
	var colors = PackedColorArray([
		Color(0.3, 0.7, 0.3),
		Color(0.3, 0.7, 0.3),
		Color(0.2, 0.5, 0.2)
	])
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func find_player() -> void:
	player = get_tree().get_first_node_in_group("player")
	if player:
		player_attack_area = player.get_node_or_null("AttackArea")
		update_chunks()

func _on_upgrade_purchased(upgrade_type: String, _level: int) -> void:
	if upgrade_type == "grass_density":
		# Clear and rebuild all
		grass_data.clear()
		loaded_chunks.clear()
		update_chunks()

func _process(delta: float) -> void:
	if not player:
		return

	update_chunks()
	process_regen(delta)
	update_multimesh()

func get_chunk_coord(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / chunk_size), floori(world_pos.y / chunk_size))

func update_chunks() -> void:
	var relative_player_pos = player.global_position - global_position
	var player_chunk = get_chunk_coord(relative_player_pos)
	var chunks_to_keep: Dictionary = {}

	for x in range(-render_distance, render_distance + 1):
		for y in range(-render_distance, render_distance + 1):
			var chunk_coord = Vector2i(player_chunk.x + x, player_chunk.y + y)
			chunks_to_keep[chunk_coord] = true
			if not loaded_chunks.has(chunk_coord):
				load_chunk(chunk_coord)

	# Unload distant chunks
	for chunk_coord in loaded_chunks.keys():
		if not chunks_to_keep.has(chunk_coord):
			unload_chunk(chunk_coord)

func load_chunk(chunk_coord: Vector2i) -> void:
	if loaded_chunks.has(chunk_coord):
		return

	var positions: Array[Vector2i] = []
	var chunk_origin = Vector2(chunk_coord.x * chunk_size, chunk_coord.y * chunk_size)

	# Get density - affects grid spacing
	var density_level = GameManager.get_grass_density_level()
	var cell_size = grid_cell_size / (1.0 + density_level * 0.15)  # Denser grid at higher levels

	var rng = RandomNumberGenerator.new()
	rng.seed = hash(chunk_coord)

	# Grid-based spawning - O(1) per grass, no spacing checks!
	var cells_per_side = int(chunk_size / cell_size)
	for gx in cells_per_side:
		for gy in cells_per_side:
			# Small random offset within cell
			var world_x = chunk_origin.x + gx * cell_size + rng.randf_range(0, cell_size * 0.7)
			var world_y = chunk_origin.y + gy * cell_size + rng.randf_range(0, cell_size * 0.7)
			var grid_pos = Vector2i(int(world_x), int(world_y))

			if not grass_data.has(grid_pos):
				var gd = GameManager.get_random_grass_data()
				grass_data[grid_pos] = {
					"cut": false,
					"type": get_grass_type_index(gd),
					"health": gd.max_health if gd else 1,
					"max_health": gd.max_health if gd else 1,
					"regen_time": gd.regen_time if gd else 5.0,
					"regen_timer": 0.0,
					"value": randi_range(gd.min_drop_value, gd.max_drop_value) if gd else 1
				}
				positions.append(grid_pos)

	loaded_chunks[chunk_coord] = positions

func unload_chunk(chunk_coord: Vector2i) -> void:
	if not loaded_chunks.has(chunk_coord):
		return

	var positions = loaded_chunks[chunk_coord]
	for grid_pos in positions:
		grass_data.erase(grid_pos)

	loaded_chunks.erase(chunk_coord)

func get_grass_type_index(gd: GrassData) -> int:
	if not gd:
		return 0
	for i in GameManager.grass_data_list.size():
		if GameManager.grass_data_list[i] == gd:
			return i
	return 0

func process_regen(delta: float) -> void:
	for grid_pos in grass_data:
		var data = grass_data[grid_pos]
		if data.cut:
			data.regen_timer += delta
			if data.regen_timer >= data.regen_time:
				# Regenerate with new random type
				var gd = GameManager.get_random_grass_data()
				data.cut = false
				data.type = get_grass_type_index(gd)
				data.health = gd.max_health if gd else 1
				data.max_health = gd.max_health if gd else 1
				data.regen_time = gd.regen_time if gd else 5.0
				data.regen_timer = 0.0
				data.value = randi_range(gd.min_drop_value, gd.max_drop_value) if gd else 1

func update_multimesh() -> void:
	var visible_grass: Array = []
	var colors_list: Array = []

	for grid_pos in grass_data:
		var data = grass_data[grid_pos]
		# Skip cut grass - don't render it
		if data.cut:
			continue

		var world_pos = Vector2(grid_pos.x, grid_pos.y)
		visible_grass.append(world_pos)

		var gd = GameManager.grass_data_list[data.type] if data.type < GameManager.grass_data_list.size() else null
		colors_list.append(gd.color if gd else Color(0.3, 0.7, 0.3, 1))

	multimesh.instance_count = visible_grass.size()

	for i in visible_grass.size():
		var t = Transform2D()
		t.origin = visible_grass[i]
		multimesh.set_instance_transform_2d(i, t)
		multimesh.set_instance_color(i, colors_list[i])

# Called by player to attack grass in range
func attack_grass_in_area(center: Vector2, radius: float) -> int:
	var total_value = 0
	var attacked_positions: Array = []

	for grid_pos in grass_data:
		var data = grass_data[grid_pos]
		if data.cut:
			continue

		var world_pos = Vector2(grid_pos.x, grid_pos.y)
		var distance = center.distance_to(world_pos)

		if distance <= radius:
			data.health -= 1
			if data.health <= 0:
				data.cut = true
				data.regen_timer = 0.0
				total_value += data.value
				attacked_positions.append(world_pos)

	# Spawn coins for cut grass
	for pos in attacked_positions:
		var grid_pos = Vector2i(int(pos.x), int(pos.y))
		if grass_data.has(grid_pos):
			spawn_coin(pos, grass_data[grid_pos].value)

	return total_value

func spawn_coin(pos: Vector2, value: int) -> void:
	var CoinScene = preload("res://scenes/world/coin.tscn")
	var coin = CoinScene.instantiate()
	coin.position = pos
	coin.set_value(value)
	get_parent().add_child(coin)
