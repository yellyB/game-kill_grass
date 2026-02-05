extends CharacterBody2D

signal input_direction_changed(direction: Vector2)

@export var move_speed: float = 300.0

@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var player_visual: Node2D = $PlayerVisual
@onready var attack_timer: Timer = $AttackTimer
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var blade: Sprite2D = $WeaponPivot/Blade

# Body parts for animation
@onready var left_leg: Polygon2D = $PlayerVisual/LeftLeg
@onready var right_leg: Polygon2D = $PlayerVisual/RightLeg
@onready var left_arm: Polygon2D = $PlayerVisual/LeftArm
@onready var right_arm: Polygon2D = $PlayerVisual/RightArm
@onready var body: Polygon2D = $PlayerVisual/Body

var input_direction: Vector2 = Vector2.ZERO
var can_attack: bool = true
var grasses_in_range: Array[Node2D] = []
var target_weapon_angle: float = 0.0
var is_swinging: bool = false
var walk_time: float = 0.0

func _ready() -> void:
	attack_area.area_entered.connect(_on_grass_entered)
	attack_area.area_exited.connect(_on_grass_exited)
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	update_attack_range()
	update_weapon_visuals()
	GameManager.upgrade_purchased.connect(_on_upgrade_purchased)
	WeaponManager.weapon_changed.connect(_on_weapon_changed)

func _process(delta: float) -> void:
	input_direction = get_input_direction()
	input_direction_changed.emit(input_direction)

	if input_direction != Vector2.ZERO:
		update_sprite_direction()
		update_weapon_direction(delta)
		update_walk_animation(delta)
		try_attack()
	else:
		reset_walk_animation(delta)

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
		player_visual.scale.x = -1
	elif input_direction.x > 0:
		player_visual.scale.x = 1

func update_walk_animation(delta: float) -> void:
	walk_time += delta * 12.0  # Speed of animation

	var leg_swing = sin(walk_time) * 0.4
	var arm_swing = sin(walk_time) * 0.3
	var body_bob = abs(sin(walk_time * 2)) * 2.0

	# Legs swing opposite to each other
	left_leg.rotation = leg_swing
	right_leg.rotation = -leg_swing

	# Arms swing opposite to legs
	left_arm.rotation = -arm_swing
	right_arm.rotation = arm_swing

	# Slight body bob
	body.position.y = -body_bob

func reset_walk_animation(delta: float) -> void:
	# Smoothly return to idle pose
	var lerp_speed = delta * 8.0

	left_leg.rotation = lerp(left_leg.rotation, 0.0, lerp_speed)
	right_leg.rotation = lerp(right_leg.rotation, 0.0, lerp_speed)
	left_arm.rotation = lerp(left_arm.rotation, 0.0, lerp_speed)
	right_arm.rotation = lerp(right_arm.rotation, 0.0, lerp_speed)
	body.position.y = lerp(body.position.y, 0.0, lerp_speed)

func update_weapon_direction(delta: float) -> void:
	if is_swinging:
		return
	# Point weapon in movement direction
	target_weapon_angle = input_direction.angle() + PI / 2
	weapon_pivot.rotation = lerp_angle(weapon_pivot.rotation, target_weapon_angle, delta * 15.0)

func try_attack() -> void:
	if not can_attack:
		return
	if grasses_in_range.is_empty():
		return

	can_attack = false
	var base_speed = GameManager.get_attack_speed()
	var weapon_speed = WeaponManager.get_weapon_speed()
	attack_timer.wait_time = 0.2 / (base_speed * weapon_speed)
	attack_timer.start()

	var attack_type = WeaponManager.get_attack_type()

	match attack_type:
		"double":
			# Attack two closest grasses
			attack_multiple_grass(2)
		"spin", "aura", "flame", "world":
			# Attack all grass in range
			attack_all_grass()
		"screen":
			# Attack all grass in range with screen effect
			attack_all_grass()
		_:
			# Single target attack
			attack_closest_grass()

func attack_closest_grass() -> void:
	var closest_grass: Node2D = null
	var closest_distance: float = INF

	for grass in grasses_in_range:
		if is_instance_valid(grass) and grass.has_method("take_damage"):
			var distance = global_position.distance_to(grass.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_grass = grass

	if closest_grass:
		swing_weapon(closest_grass.global_position)
		closest_grass.take_damage(1)

func attack_multiple_grass(count: int) -> void:
	var valid_grasses: Array = []

	for grass in grasses_in_range:
		if is_instance_valid(grass) and grass.has_method("take_damage"):
			valid_grasses.append(grass)

	# Sort by distance
	valid_grasses.sort_custom(func(a, b):
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)

	# Attack up to 'count' grasses
	for i in min(count, valid_grasses.size()):
		if i == 0:
			swing_weapon(valid_grasses[i].global_position)
		valid_grasses[i].take_damage(1)

func attack_all_grass() -> void:
	var attacked = false
	for grass in grasses_in_range:
		if is_instance_valid(grass) and grass.has_method("take_damage"):
			if not attacked:
				swing_weapon(grass.global_position)
				attacked = true
			grass.take_damage(1)

func swing_weapon(target_pos: Vector2) -> void:
	is_swinging = true

	# Calculate angle to target
	var direction_to_target = (target_pos - global_position).normalized()
	var target_angle = direction_to_target.angle() + PI / 2

	# Swing animation: quick arc motion
	var swing_start = target_angle - PI / 3  # Start 60 degrees before
	var swing_end = target_angle + PI / 3    # End 60 degrees after

	weapon_pivot.rotation = swing_start

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	tween.tween_property(weapon_pivot, "rotation", swing_end, 0.1)

	# Scale effect on blade
	blade.scale = Vector2(1.3, 1.1)
	tween.parallel().tween_property(blade, "scale", Vector2(1.0, 1.0), 0.1)

	await tween.finished
	is_swinging = false

func update_attack_range() -> void:
	var base_range = GameManager.get_attack_range()
	var weapon_range = WeaponManager.get_weapon_range()
	var final_range = base_range * weapon_range
	if attack_shape and attack_shape.shape is CircleShape2D:
		attack_shape.shape.radius = final_range

func update_weapon_visuals() -> void:
	var weapon_color = WeaponManager.get_weapon_color()
	blade.modulate = weapon_color

	# Scale blade based on weapon level
	var weapon_range = WeaponManager.get_weapon_range()
	blade.scale = Vector2(1.0, weapon_range)

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

func _on_weapon_changed(_level: int) -> void:
	update_attack_range()
	update_weapon_visuals()

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
