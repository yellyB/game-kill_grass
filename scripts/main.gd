extends Node2D

const SESSION_TIME: float = 10.0  # TODO: 출시 시 60.0으로 변경
const BONUS_COINS: int = 100

@onready var world_root: Node2D = $WorldRoot
@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Player/GameCamera
@onready var upgrade_panel: Control = $UpgradePanel/Control
@onready var weapon_shop: Control = $WeaponShop/Control
@onready var back_to_menu_btn: Button = $BackToMenuUI/BackToMenuBtn
@onready var confirm_dialog: Control = $BackToMenuUI/ConfirmDialog
@onready var confirm_btn: Button = $BackToMenuUI/ConfirmDialog/DialogPanel/ConfirmBtn
@onready var cancel_btn: Button = $BackToMenuUI/ConfirmDialog/DialogPanel/CancelBtn
@onready var session_end_overlay: Control = $BackToMenuUI/SessionEndOverlay
@onready var touch_button: Button = $BackToMenuUI/SessionEndOverlay/TouchButton
@onready var bonus_label: Label = $BackToMenuUI/SessionEndOverlay/BonusLabel
@onready var timer_label: Label = $HUD/TimerLabel

var session_time_remaining: float = SESSION_TIME
var session_ended: bool = false

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

	# Setup session end overlay
	touch_button.pressed.connect(_on_session_end_touch)

	# Initialize timer display
	update_timer_display()

func _process(delta: float) -> void:
	if session_ended:
		return

	session_time_remaining -= delta
	if session_time_remaining <= 0:
		session_time_remaining = 0
		end_session()

	update_timer_display()

func update_timer_display() -> void:
	var seconds = int(ceil(session_time_remaining))
	timer_label.text = str(seconds)

	# Change color when time is low
	if seconds <= 10:
		timer_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		timer_label.add_theme_color_override("font_color", Color(1, 1, 1))

func end_session() -> void:
	session_ended = true
	get_tree().paused = true
	session_end_overlay.visible = true
	back_to_menu_btn.visible = false

	# Add bonus coins
	GameManager.add_money(BONUS_COINS)
	bonus_label.text = "세션 완료 보너스 +$%d" % BONUS_COINS

func _on_session_end_touch() -> void:
	get_tree().paused = false
	SessionManager.quit_to_menu()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android back button
		if session_ended:
			_on_session_end_touch()
		elif confirm_dialog.visible:
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
