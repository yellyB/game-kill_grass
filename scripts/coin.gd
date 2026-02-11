extends Area2D

@export var value: int = 1
@export var magnet_speed: float = 600.0
@export var pickup_delay: float = 0.3

var player: Node2D = null
var can_pickup: bool = false
var is_being_collected: bool = false
var is_collected: bool = false
var velocity: Vector2 = Vector2.ZERO

@onready var visual: Node2D = $Visual
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("coins")

	# Find player
	player = get_tree().get_first_node_in_group("player")

	# Spawn animation - pop out
	spawn_animation()

	# Enable pickup after delay
	await get_tree().create_timer(pickup_delay).timeout
	can_pickup = true

func _process(delta: float) -> void:
	if not can_pickup or not player:
		return

	# Convert player position to local coordinate space (WorldRoot)
	var player_local_pos = get_parent().to_local(player.global_position)
	var distance_to_player = position.distance_to(player_local_pos)
	var magnet_range = GameManager.get_magnet_range()

	if distance_to_player < magnet_range or is_being_collected:
		is_being_collected = true
		# Move towards player
		var direction = (player_local_pos - position).normalized()
		var speed = magnet_speed * (1.0 + (magnet_range - min(distance_to_player, magnet_range)) / magnet_range)
		position += direction * speed * delta

		# Pickup when close enough
		if distance_to_player < 30.0:
			collect()

	# Bobbing animation
	if visual:
		visual.position.y = sin(Time.get_ticks_msec() * 0.008) * 3.0

func spawn_animation() -> void:
	# Random pop direction
	var pop_direction = Vector2(randf_range(-1, 1), randf_range(-1, -0.5)).normalized()
	var pop_distance = randf_range(30, 60)

	var start_pos = position
	var peak_pos = start_pos + pop_direction * pop_distance

	# Scale pop
	if visual:
		visual.scale = Vector2(0.3, 0.3)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", peak_pos, 0.15).set_ease(Tween.EASE_OUT)
	if visual:
		tween.tween_property(visual, "scale", Vector2(1.2, 1.2), 0.1).set_ease(Tween.EASE_OUT)

	await tween.finished

	if visual:
		var tween2 = create_tween()
		tween2.tween_property(visual, "scale", Vector2(1.0, 1.0), 0.1)

func collect() -> void:
	# Prevent multiple collections
	if is_collected:
		return
	is_collected = true

	# Add money
	GameManager.add_money(value)

	# Accumulate floating text on player
	if player and player.has_method("accumulate_coin_text"):
		player.accumulate_coin_text(value)

	# Collect effect
	if visual:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(visual, "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(visual, "modulate:a", 0.0, 0.1)
		await tween.finished

	queue_free()

func set_value(new_value: int) -> void:
	value = new_value
	update_visual()

func update_visual() -> void:
	if not visual:
		return

	# Color based on value
	var coin_color: Color
	if value >= 15:
		coin_color = Color(1.0, 0.85, 0.0) # Gold
	elif value >= 5:
		coin_color = Color(0.75, 0.75, 0.8) # Silver
	else:
		coin_color = Color(0.8, 0.5, 0.2) # Bronze

	for child in visual.get_children():
		if child is Polygon2D:
			child.color = coin_color
