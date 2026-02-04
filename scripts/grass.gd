extends Area2D

signal grass_cut(grass: Node2D, value: int)

@export var grass_data: GrassData

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var regen_timer: Timer = $RegenTimer
@onready var particles: GPUParticles2D = $CutParticles

var current_health: int = 1
var is_cut: bool = false
var camera: Camera2D = null

func _ready() -> void:
	add_to_group("grass")
	collision.disabled = false

	if grass_data:
		current_health = grass_data.max_health
		regen_timer.wait_time = grass_data.regen_time
		update_visual()
	else:
		# Default values if no data
		current_health = 1
		regen_timer.wait_time = 5.0

	regen_timer.timeout.connect(_on_regen_timeout)

	# Find camera for shake effect
	await get_tree().process_frame
	camera = get_tree().get_first_node_in_group("camera")

func take_damage(amount: int) -> void:
	if is_cut:
		return

	current_health -= amount

	if current_health <= 0:
		cut()
	else:
		# Visual feedback for damage
		flash_damage()

func cut() -> void:
	is_cut = true
	collision.set_deferred("disabled", true)

	# Visual feedback
	play_cut_effect()

	# Calculate drop value
	var drop_value = calculate_drop()
	if drop_value > 0:
		GameManager.add_money(drop_value)

	# Add combo
	GameManager.add_combo()

	# Time scale effect
	apply_hitstop()

	# Camera shake
	if camera and camera.has_method("shake"):
		camera.shake(0.3)

	# Change sprite to cut state
	if grass_data:
		sprite.modulate = grass_data.cut_color
	else:
		sprite.modulate = Color(0.5, 0.4, 0.2)

	sprite.scale = Vector2(0.8, 0.3)

	# Emit signal
	grass_cut.emit(self, drop_value)

	# Start regen timer
	regen_timer.start()

func calculate_drop() -> int:
	var drop_multiplier = GameManager.get_drop_multiplier()

	if grass_data:
		if randf() > grass_data.drop_chance:
			return 0
		var base_value = randi_range(grass_data.min_drop_value, grass_data.max_drop_value)
		return int(base_value * drop_multiplier)
	else:
		if randf() > 0.8:
			return 0
		return int(randi_range(1, 5) * drop_multiplier)

func play_cut_effect() -> void:
	if particles:
		particles.emitting = true

	# Quick scale animation
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.2, 0.5), 0.05)
	tween.tween_property(sprite, "scale", Vector2(0.8, 0.3), 0.1)

func apply_hitstop() -> void:
	Engine.time_scale = 0.7
	await get_tree().create_timer(0.03, true, false, true).timeout
	Engine.time_scale = 1.0

func flash_damage() -> void:
	sprite.modulate = Color.WHITE
	await get_tree().create_timer(0.05).timeout
	update_visual()

func _on_regen_timeout() -> void:
	regenerate()

func regenerate() -> void:
	is_cut = false
	collision.set_deferred("disabled", false)

	if grass_data:
		current_health = grass_data.max_health
	else:
		current_health = 1

	update_visual()

	# Grow animation
	sprite.scale = Vector2(0.1, 0.1)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(sprite, "scale", Vector2(1, 1), 0.4)

func update_visual() -> void:
	if grass_data:
		sprite.modulate = grass_data.color
	else:
		sprite.modulate = Color(0.3, 0.7, 0.3)
	sprite.scale = Vector2(1, 1)
