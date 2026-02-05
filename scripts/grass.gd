extends Area2D

signal grass_cut(grass: Node2D, value: int)

@export var grass_data: GrassData

@onready var grass_visual: Node2D = $GrassVisual
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var regen_timer: Timer = $RegenTimer
@onready var particles: GPUParticles2D = $CutParticles

var current_health: int = 1
var is_cut: bool = false
var camera: Camera2D = null
var sway_offset: float = 0.0
var base_colors: Array[Color] = []

func _ready() -> void:
	add_to_group("grass")
	collision.disabled = false

	# Random sway offset for variety
	sway_offset = randf() * TAU

	# Store base colors
	for blade in grass_visual.get_children():
		if blade is Polygon2D:
			base_colors.append(blade.color)

	if grass_data:
		current_health = grass_data.max_health
		regen_timer.wait_time = grass_data.regen_time
		update_visual()
	else:
		current_health = 1
		regen_timer.wait_time = 5.0

	regen_timer.timeout.connect(_on_regen_timeout)

	# Find camera for shake effect
	await get_tree().process_frame
	camera = get_tree().get_first_node_in_group("camera")

func _process(delta: float) -> void:
	if is_cut:
		return

	# Gentle swaying animation
	sway_offset += delta * 2.0
	var sway = sin(sway_offset) * 0.05
	grass_visual.rotation = sway

func take_damage(amount: int) -> void:
	if is_cut:
		return

	current_health -= amount

	if current_health <= 0:
		cut()
	else:
		flash_damage()

func cut() -> void:
	is_cut = true
	collision.set_deferred("disabled", true)

	play_cut_effect()

	var drop_value = calculate_drop()
	if drop_value > 0:
		GameManager.add_money(drop_value)

	GameManager.add_combo()
	apply_hitstop()

	if camera and camera.has_method("shake"):
		camera.shake(0.3)

	# Change to cut state - flatten and brown
	var cut_color = Color(0.5, 0.4, 0.2)
	if grass_data:
		cut_color = grass_data.cut_color

	for blade in grass_visual.get_children():
		if blade is Polygon2D:
			blade.color = cut_color

	grass_visual.scale = Vector2(1.2, 0.3)
	grass_visual.rotation = randf_range(-0.3, 0.3)

	grass_cut.emit(self, drop_value)
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

	var tween = create_tween()
	tween.tween_property(grass_visual, "scale", Vector2(1.4, 0.2), 0.05)
	tween.tween_property(grass_visual, "scale", Vector2(1.2, 0.3), 0.1)

func apply_hitstop() -> void:
	Engine.time_scale = 0.7
	await get_tree().create_timer(0.03, true, false, true).timeout
	Engine.time_scale = 1.0

func flash_damage() -> void:
	for blade in grass_visual.get_children():
		if blade is Polygon2D:
			blade.color = Color.WHITE
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
	grass_visual.scale = Vector2(0.1, 0.1)
	grass_visual.rotation = 0
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(grass_visual, "scale", Vector2(1, 1), 0.4)

func update_visual() -> void:
	grass_visual.scale = Vector2(1, 1)
	grass_visual.rotation = 0

	var i = 0
	for blade in grass_visual.get_children():
		if blade is Polygon2D:
			if grass_data:
				# Tint based on grass_data color
				var base = base_colors[i] if i < base_colors.size() else Color(0.3, 0.6, 0.25)
				blade.color = base.lerp(grass_data.color, 0.5)
			else:
				if i < base_colors.size():
					blade.color = base_colors[i]
			i += 1
