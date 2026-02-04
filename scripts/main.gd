extends Node2D

@onready var world_root: Node2D = $WorldRoot
@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Player/GameCamera

func _ready() -> void:
	SessionManager.start_session()
	camera.add_to_group("camera")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android back button
		SessionManager.quit_to_menu()
