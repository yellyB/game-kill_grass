extends Node2D

const SESSION_TIME: float = 60.0

const BGM_PATHS: Array = [
	"res://resources/sounds/bgm_world_1.wav",
	"res://resources/sounds/bgm_world_2.wav",
	"res://resources/sounds/bgm_world_3.wav",
	"res://resources/sounds/bgm_world_4.wav",
]

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
@onready var session_earnings_label: Label = $BackToMenuUI/SessionEndOverlay/SessionEarningsLabel
@onready var bonus_label: Label = $BackToMenuUI/SessionEndOverlay/BonusLabel
@onready var tap_to_return_label: Label = $BackToMenuUI/SessionEndOverlay/TapToReturnLabel
@onready var timer_label: Label = $HUD/TimerLabel

var session_time_remaining: float = SESSION_TIME
var session_ended: bool = false
var bgm_player: AudioStreamPlayer

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

	# Button styles
	GameManager.style_button(back_to_menu_btn, "muted")
	GameManager.style_button(confirm_btn)
	GameManager.style_button(cancel_btn, "muted")

	# Setup session end overlay
	touch_button.pressed.connect(_on_session_end_touch)

	# Extra time powerup
	GameManager.extra_time_requested.connect(_on_extra_time)

	# Initialize timer display
	update_timer_display()

	# Start BGM
	_start_bgm()

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

func _start_bgm() -> void:
	var world = GameManager.selected_world
	var path = BGM_PATHS[world] if world < BGM_PATHS.size() else BGM_PATHS[0]
	bgm_player = AudioStreamPlayer.new()
	bgm_player.stream = load(path)
	bgm_player.volume_db = -10.0
	bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	bgm_player.finished.connect(bgm_player.play)
	add_child(bgm_player)
	await get_tree().create_timer(1.0).timeout
	bgm_player.play()

func end_session() -> void:
	session_ended = true
	get_tree().paused = true
	back_to_menu_btn.visible = false

	# Remove player hit overlay so it doesn't block session end touch
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("_remove_hit_overlay"):
		player._remove_hit_overlay()

	# Fade out BGM
	if bgm_player:
		var bgm_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		bgm_tween.tween_property(bgm_player, "volume_db", -40.0, 1.5)
		bgm_tween.tween_callback(bgm_player.stop)

	var earnings = GameManager.session_money

	# Phase 1: Coins pop and disappear
	await animate_coins_disappear()

	# Phase 2: Show overlay with animations
	show_session_end_overlay(earnings)

func animate_coins_disappear() -> void:
	var coins = get_tree().get_nodes_in_group("coins")

	if coins.is_empty():
		await get_tree().create_timer(0.3).timeout
		return

	coins.shuffle()
	var total_duration = min(2.0, coins.size() * 0.05)
	var pop_interval = total_duration / coins.size()

	for i in coins.size():
		var coin = coins[i]
		if not is_instance_valid(coin):
			continue

		var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_interval(i * pop_interval)
		tween.tween_property(coin, "scale", Vector2(1.8, 1.8), 0.08)
		tween.tween_property(coin, "scale", Vector2(0, 0), 0.12)
		tween.tween_callback(coin.queue_free)

	await get_tree().create_timer(total_duration + 0.3).timeout

func show_session_end_overlay(earnings: int) -> void:
	# Play fanfare
	var sfx = AudioStreamPlayer.new()
	sfx.stream = preload("res://resources/sounds/effect/end_session_fanfare.wav")
	sfx.volume_db = -3.0
	sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

	# Hide elements initially
	session_earnings_label.modulate = Color(1, 1, 1, 0)
	bonus_label.visible = false
	tap_to_return_label.modulate = Color(1, 1, 1, 0)
	touch_button.disabled = true

	# Set texts
	session_earnings_label.text = "획득: $%s" % format_number(earnings)

	# Show overlay
	session_end_overlay.visible = true

	# Fade in earnings
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(session_earnings_label, "modulate:a", 1.0, 0.4)

	# Show tap to return
	tween.tween_interval(0.6)
	tween.tween_property(tap_to_return_label, "modulate:a", 1.0, 0.3)
	tween.tween_callback(func():
		touch_button.disabled = false
		animate_tap_label()
	)

func animate_tap_label() -> void:
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_loops()
	tween.tween_property(tap_to_return_label, "modulate:a", 0.3, 0.7)
	tween.tween_property(tap_to_return_label, "modulate:a", 1.0, 0.7)

func _on_session_end_touch() -> void:
	GameManager.play_confirm_click()
	get_tree().paused = false
	# Normal session end - finalize and save
	GameManager.finalize_session()
	SaveManager.save_game()
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
	GameManager.play_button_click()
	confirm_dialog.visible = true
	get_tree().paused = true

func _on_confirm_back_to_menu() -> void:
	GameManager.play_confirm_click()
	get_tree().paused = false
	SessionManager.quit_to_menu()

func _on_cancel_back_to_menu() -> void:
	GameManager.play_button_click()
	confirm_dialog.visible = false
	get_tree().paused = false

func _on_extra_time(seconds: float) -> void:
	session_time_remaining += seconds

func format_number(num: int) -> String:
	var str_num = str(num)
	var result = ""
	var count = 0
	for i in range(str_num.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = str_num[i] + result
		count += 1
	return result
