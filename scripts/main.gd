extends Node2D

@onready var world_root: Node2D = $WorldRoot
@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Player/GameCamera
@onready var upgrade_panel: Control = $UpgradePanel/Control
@onready var weapon_shop: Control = $WeaponShop/Control
@onready var back_to_menu_btn: Button = $BackToMenuUI/BackToMenuBtn
@onready var confirm_dialog: Control = $BackToMenuUI/ConfirmDialog
@onready var confirm_btn: Button = $BackToMenuUI/ConfirmDialog/DialogPanel/ConfirmBtn
@onready var cancel_btn: Button = $BackToMenuUI/ConfirmDialog/DialogPanel/CancelBtn

func _ready() -> void:
	SessionManager.start_session()
	camera.add_to_group("camera")

	# Hide the toggle buttons on panels (moved to main menu)
	upgrade_panel.set_toggle_button_visible(false)
	weapon_shop.set_toggle_button_visible(false)

	# Setup back to menu button and dialog
	back_to_menu_btn.pressed.connect(_on_back_to_menu_pressed)
	confirm_btn.pressed.connect(_on_confirm_back_to_menu)
	cancel_btn.pressed.connect(_on_cancel_back_to_menu)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android back button
		if confirm_dialog.visible:
			_on_cancel_back_to_menu()
		else:
			_on_back_to_menu_pressed()

func _on_back_to_menu_pressed() -> void:
	confirm_dialog.visible = true
	get_tree().paused = true

func _on_confirm_back_to_menu() -> void:
	get_tree().paused = false
	SessionManager.quit_to_menu()

func _on_cancel_back_to_menu() -> void:
	confirm_dialog.visible = false
	get_tree().paused = false
