extends Node2D

@export var grass_scene: PackedScene
@export var spawn_radius: float = 1500.0
@export var grass_count: int = 100
@export var min_spacing: float = 80.0

var grass_data_list: Array[GrassData] = []

func _ready() -> void:
	load_grass_data()
	spawn_initial_grass()

func load_grass_data() -> void:
	# Create grass types programmatically for MVP
	var normal_grass = GrassData.new()
	normal_grass.grass_name = "Normal Grass"
	normal_grass.max_health = 1
	normal_grass.regen_time = 5.0
	normal_grass.min_drop_value = 1
	normal_grass.max_drop_value = 3
	normal_grass.drop_chance = 0.9
	normal_grass.color = Color(0.3, 0.7, 0.3)
	normal_grass.cut_color = Color(0.5, 0.4, 0.2)

	var tough_grass = GrassData.new()
	tough_grass.grass_name = "Tough Grass"
	tough_grass.max_health = 3
	tough_grass.regen_time = 8.0
	tough_grass.min_drop_value = 5
	tough_grass.max_drop_value = 10
	tough_grass.drop_chance = 0.95
	tough_grass.color = Color(0.2, 0.5, 0.2)
	tough_grass.cut_color = Color(0.4, 0.35, 0.15)

	var golden_grass = GrassData.new()
	golden_grass.grass_name = "Golden Grass"
	golden_grass.max_health = 2
	golden_grass.regen_time = 15.0
	golden_grass.min_drop_value = 15
	golden_grass.max_drop_value = 30
	golden_grass.drop_chance = 1.0
	golden_grass.color = Color(0.9, 0.8, 0.2)
	golden_grass.cut_color = Color(0.6, 0.5, 0.1)

	grass_data_list.append(normal_grass)
	grass_data_list.append(tough_grass)
	grass_data_list.append(golden_grass)

func spawn_initial_grass() -> void:
	if not grass_scene:
		push_error("Grass scene not assigned!")
		return

	var spawned_positions: Array[Vector2] = []

	for i in grass_count:
		var pos = get_random_position(spawned_positions)
		if pos != Vector2.INF:
			spawn_grass_at(pos)
			spawned_positions.append(pos)

func get_random_position(existing: Array[Vector2]) -> Vector2:
	var max_attempts = 30

	for _attempt in max_attempts:
		var angle = randf() * TAU
		var distance = randf_range(100, spawn_radius)
		var pos = Vector2(cos(angle), sin(angle)) * distance

		var valid = true
		for existing_pos in existing:
			if pos.distance_to(existing_pos) < min_spacing:
				valid = false
				break

		if valid:
			return pos

	return Vector2.INF

func spawn_grass_at(pos: Vector2) -> void:
	var grass = grass_scene.instantiate()
	grass.position = pos

	# Assign random grass type with weighted probability
	var roll = randf()
	if roll < 0.7:  # 70% normal
		grass.grass_data = grass_data_list[0]
	elif roll < 0.95:  # 25% tough
		grass.grass_data = grass_data_list[1]
	else:  # 5% golden
		grass.grass_data = grass_data_list[2]

	add_child(grass)
