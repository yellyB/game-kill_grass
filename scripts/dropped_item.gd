extends Node2D

var item_id: String = ""
var item_texture: ImageTexture = null
var target: Node2D = null  # Player to fly toward

@onready var sprite: Sprite2D = $Sprite2D

# Arc flight state
var is_flying: bool = false
var fly_time: float = 0.0
var fly_duration: float = 0.45
var start_pos: Vector2 = Vector2.ZERO
var control_point: Vector2 = Vector2.ZERO

func setup(p_item_id: String, p_texture: ImageTexture, p_target: Node2D) -> void:
	item_id = p_item_id
	item_texture = p_texture
	target = p_target

func _ready() -> void:
	if sprite and item_texture:
		sprite.texture = item_texture
	_animate()

func _process(delta: float) -> void:
	if not is_flying:
		return

	fly_time += delta
	var t = clampf(fly_time / fly_duration, 0.0, 1.0)

	if not is_instance_valid(target):
		_collect()
		return

	# Ease-in (cubic) for "whoosh" acceleration toward player
	var eased_t = t * t * t
	var end_pos = target.global_position

	# Quadratic bezier: B(t) = (1-t)²·P0 + 2(1-t)t·P1 + t²·P2
	var inv_t = 1.0 - eased_t
	global_position = inv_t * inv_t * start_pos + 2 * inv_t * eased_t * control_point + eased_t * eased_t * end_pos

	# Scale: start big, shrink toward end
	var s = lerpf(1.8, 0.3, t * t)
	scale = Vector2(s, s)

	# Fade near end
	if t > 0.65:
		modulate.a = lerpf(1.0, 0.5, (t - 0.65) / 0.35)

	if t >= 1.0:
		is_flying = false
		_collect()

func _animate() -> void:
	scale = Vector2.ZERO

	# Pop out big with bounce
	var pop_tween = create_tween()
	pop_tween.set_ease(Tween.EASE_OUT)
	pop_tween.set_trans(Tween.TRANS_BACK)
	pop_tween.tween_property(self, "scale", Vector2(2.4, 2.4), 0.2)
	pop_tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.1)
	await pop_tween.finished

	# Brief pause
	await get_tree().create_timer(0.2).timeout

	if not is_instance_valid(target):
		_collect()
		return

	# Calculate bezier arc
	start_pos = global_position
	var end_pos = target.global_position
	var mid = (start_pos + end_pos) * 0.5
	var direction = end_pos - start_pos
	var perpendicular = Vector2(-direction.y, direction.x).normalized()

	# Arc height: goes upward, with slight random side offset
	var dist = start_pos.distance_to(end_pos)
	var arc_height = maxf(80.0, dist * 0.5)
	var side_offset = randf_range(-25, 25)
	control_point = mid + Vector2(0, -arc_height) + perpendicular * side_offset

	fly_time = 0.0
	is_flying = true

func _collect() -> void:
	GameManager.add_item(item_id)
	queue_free()
