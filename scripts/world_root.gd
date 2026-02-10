extends Node2D

@export var move_speed: float = 300.0

var player: CharacterBody2D = null
var background: ColorRect = null

func _ready() -> void:
	# Find player in the scene
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	background = $Background
	if player:
		player.input_direction_changed.connect(_on_player_input_changed)

var current_direction: Vector2 = Vector2.ZERO

func _on_player_input_changed(direction: Vector2) -> void:
	current_direction = direction

func _process(delta: float) -> void:
	if current_direction != Vector2.ZERO:
		# Move world in opposite direction of input
		position -= current_direction * move_speed * delta

	# Keep background always centered under camera view
	if background:
		# Background needs to stay at camera position in local space
		# Since camera follows player at (0,0), we offset by -position to cancel world movement
		background.global_position = Vector2(-3000, -3000)
