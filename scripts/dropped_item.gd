extends Node2D

var item_id: String = ""
var item_texture: ImageTexture = null
var target: Node2D = null  # Player to fly toward

@onready var sprite: Sprite2D = $Sprite2D

func setup(p_item_id: String, p_texture: ImageTexture, p_target: Node2D) -> void:
	item_id = p_item_id
	item_texture = p_texture
	target = p_target

func _ready() -> void:
	if sprite and item_texture:
		sprite.texture = item_texture
	# Pop up animation, then fly to player
	_animate()

func _animate() -> void:
	# Start small
	scale = Vector2.ZERO

	# Pop out with bounce
	var pop_tween = create_tween()
	pop_tween.set_ease(Tween.EASE_OUT)
	pop_tween.set_trans(Tween.TRANS_BACK)
	pop_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.25)
	pop_tween.tween_property(self, "scale", Vector2.ONE, 0.1)
	await pop_tween.finished

	# Brief pause
	await get_tree().create_timer(0.15).timeout

	# Fly to player
	if not is_instance_valid(target):
		_collect()
		return

	var fly_tween = create_tween()
	fly_tween.set_ease(Tween.EASE_IN)
	fly_tween.set_trans(Tween.TRANS_QUAD)

	fly_tween.set_parallel(true)
	fly_tween.tween_property(self, "global_position", target.global_position, 0.3)
	fly_tween.tween_property(self, "scale", Vector2(0.5, 0.5), 0.3)
	fly_tween.tween_property(self, "modulate:a", 0.5, 0.25).set_delay(0.15)
	await fly_tween.finished

	_collect()

func _collect() -> void:
	GameManager.add_item(item_id)
	queue_free()
