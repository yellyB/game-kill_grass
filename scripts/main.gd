extends Node2D

@onready var world_root: Node2D = $WorldRoot
@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Player/GameCamera
@onready var upgrade_panel: Control = $UpgradePanel/Control
@onready var weapon_shop: Control = $WeaponShop/Control

func _ready() -> void:
	SessionManager.start_session()
	camera.add_to_group("camera")

	# Connect panel signals for mutual exclusion
	upgrade_panel.panel_opened.connect(weapon_shop._on_other_panel_opened)
	upgrade_panel.panel_closed.connect(weapon_shop._on_other_panel_closed)
	weapon_shop.panel_opened.connect(upgrade_panel._on_other_panel_opened)
	weapon_shop.panel_closed.connect(upgrade_panel._on_other_panel_closed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android back button
		SessionManager.quit_to_menu()
