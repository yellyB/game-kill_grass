extends CharacterBody2D

signal input_direction_changed(direction: Vector2)

@export var move_speed: float = 300.0

@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_timer: Timer = $AttackTimer

var input_direction: Vector2 = Vector2.ZERO
var can_attack: bool = true
var grasses_in_range: Array[Node2D] = []

func _ready() -> void:
	attack_area.area_entered.connect(_on_grass_entered)
	attack_area.area_exited.connect(_on_grass_exited)
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	update_attack_range()
	GameManager.upgrade_purchased.connect(_on_upgrade_purchased)

func _process(_delta: float) -> void:
	input_direction = get_input_direction()
	input_direction_changed.emit(input_direction)

	if input_direction != Vector2.ZERO:
		update_sprite_direction()
		try_attack()

func _physics_process(_delta: float) -> void:
	pass

func get_input_direction() -> Vector2:
	var direction = Vector2.ZERO

	# Keyboard input
	direction.x = Input.get_axis("move_left", "move_right")
	direction.y = Input.get_axis("move_up", "move_down")

	return direction.normalized()

func update_sprite_direction() -> void:
	if input_direction.x < 0:
		sprite.flip_h = true
	elif input_direction.x > 0:
		sprite.flip_h = false

func try_attack() -> void:
	if not can_attack:
		return
	if grasses_in_range.is_empty():
		return

	can_attack = false
	var attack_speed = GameManager.get_attack_speed()
	attack_timer.wait_time = 0.2 / attack_speed
	attack_timer.start()

	# Attack the closest grass
	var closest_grass: Node2D = null
	var closest_distance: float = INF

	for grass in grasses_in_range:
		if is_instance_valid(grass) and grass.has_method("take_damage"):
			var distance = global_position.distance_to(grass.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_grass = grass

	if closest_grass:
		closest_grass.take_damage(1)

func update_attack_range() -> void:
	var range_size = GameManager.get_attack_range()
	if attack_shape and attack_shape.shape is CircleShape2D:
		attack_shape.shape.radius = range_size

func _on_grass_entered(area: Area2D) -> void:
	if area.is_in_group("grass"):
		grasses_in_range.append(area)

func _on_grass_exited(area: Area2D) -> void:
	grasses_in_range.erase(area)

func _on_attack_timer_timeout() -> void:
	can_attack = true

func _on_upgrade_purchased(upgrade_type: String, _level: int) -> void:
	if upgrade_type == "attack_range":
		update_attack_range()

# Mobile touch input support
var touch_start_pos: Vector2 = Vector2.ZERO
var is_touching: bool = false

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			is_touching = true
			touch_start_pos = event.position
		else:
			is_touching = false
			input_direction = Vector2.ZERO

	elif event is InputEventScreenDrag:
		if is_touching:
			var drag_vector = event.position - touch_start_pos
			if drag_vector.length() > 20:  # Dead zone
				input_direction = drag_vector.normalized()
