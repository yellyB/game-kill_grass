extends Area2D

signal grass_cut(grass: Node2D, value: int)

@export var grass_data: GrassData

const CoinScene = preload("res://scenes/world/coin.tscn")

@onready var grass_visual: Node2D = $GrassVisual
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var regen_timer: Timer = $RegenTimer

var current_health: int = 1
var is_cut: bool = false

func _ready() -> void:
	add_to_group("grass")
	collision.disabled = false

	# Random initial rotation for variety (static, no animation)
	grass_visual.rotation = randf_range(-0.08, 0.08)

	if grass_data:
		current_health = grass_data.max_health
		regen_timer.wait_time = grass_data.regen_time
		apply_grass_color()
	else:
		current_health = 1
		regen_timer.wait_time = 5.0

	regen_timer.timeout.connect(_on_regen_timeout)

func take_damage(amount: int) -> void:
	if is_cut:
		return

	current_health -= amount

	if current_health <= 0:
		cut()

func cut() -> void:
	is_cut = true
	collision.set_deferred("disabled", true)

	# Instant cut visual - no tween
	var cut_color = grass_data.cut_color if grass_data else Color(0.5, 0.4, 0.2)
	for blade in grass_visual.get_children():
		if blade is Polygon2D:
			blade.color = cut_color

	grass_visual.scale = Vector2(1.2, 0.3)
	grass_visual.rotation = randf_range(-0.3, 0.3)

	# Spawn coin
	var drop_value = calculate_drop()
	if drop_value > 0:
		spawn_coin(drop_value)

	grass_cut.emit(self, drop_value)
	regen_timer.start()

func calculate_drop() -> int:
	if grass_data:
		if randf() > grass_data.drop_chance:
			return 0
		return randi_range(grass_data.min_drop_value, grass_data.max_drop_value)
	else:
		if randf() > 0.8:
			return 0
		return randi_range(1, 5)

func spawn_coin(value: int) -> void:
	var coin = CoinScene.instantiate()
	var spawn_pos = position + get_parent().position
	coin.position = spawn_pos
	coin.set_value(value)
	var world_root = get_parent().get_parent()
	world_root.add_child(coin)

func _on_regen_timeout() -> void:
	regenerate()

func regenerate() -> void:
	is_cut = false
	collision.set_deferred("disabled", false)

	# Get new random grass type
	grass_data = GameManager.get_random_grass_data()

	if grass_data:
		current_health = grass_data.max_health
		regen_timer.wait_time = grass_data.regen_time
	else:
		current_health = 1

	# Instant restore - no animation
	grass_visual.scale = Vector2.ONE
	grass_visual.rotation = randf_range(-0.08, 0.08)
	apply_grass_color()

func apply_grass_color() -> void:
	if not grass_data:
		return
	for blade in grass_visual.get_children():
		if blade is Polygon2D:
			blade.color = grass_data.color
