extends Camera2D

@export var shake_decay: float = 5.0
@export var max_shake_offset: float = 10.0

var shake_intensity: float = 0.0
var original_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	original_offset = offset

func _process(delta: float) -> void:
	if shake_intensity > 0:
		shake_intensity = max(shake_intensity - shake_decay * delta, 0)
		offset = original_offset + Vector2(
			randf_range(-1, 1) * shake_intensity * max_shake_offset,
			randf_range(-1, 1) * shake_intensity * max_shake_offset
		)
	else:
		offset = original_offset

func shake(intensity: float = 1.0) -> void:
	shake_intensity = clamp(intensity, 0, 1)
