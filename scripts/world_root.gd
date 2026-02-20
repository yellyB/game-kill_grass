extends Node2D

@export var move_speed: float = 300.0

var player: CharacterBody2D = null
var background: ColorRect = null

const WORLD_BG_COLORS: Array = [
	Color(0.2, 0.4, 0.2, 1),    # 0: 슬라임 늪 - 어두운 초록 늪지
	Color(0.4, 0.35, 0.2, 1),   # 1: 들판 - 따뜻한 갈색 초원
	Color(0.15, 0.18, 0.35, 1), # 2: 마법의 숲 - 어두운 남보라 숲
	Color(0.3, 0.18, 0.15, 1),  # 3: 용의 봉우리 - 어두운 적갈색 화산
]

func _ready() -> void:
	# Find player in the scene
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	background = $Background
	# 월드별 배경색 적용
	if background:
		var world = GameManager.selected_world
		if world < WORLD_BG_COLORS.size():
			background.color = WORLD_BG_COLORS[world]
	if player:
		player.input_direction_changed.connect(_on_player_input_changed)

var current_direction: Vector2 = Vector2.ZERO

func _on_player_input_changed(direction: Vector2) -> void:
	current_direction = direction

func _process(delta: float) -> void:
	if current_direction != Vector2.ZERO:
		# Move world in opposite direction of input
		var effective_speed = move_speed * GameManager.get_session_move_speed_mult()
		position -= current_direction * effective_speed * delta

	# Keep background always centered under camera view
	if background:
		# Background needs to stay at camera position in local space
		# Since camera follows player at (0,0), we offset by -position to cancel world movement
		background.global_position = Vector2(-3000, -3000)
