extends Node2D

const SESSION_TIME: float = 60.0

const BGM_PATHS: Array = [
  "res://resources/sounds/bgm_world_1.ogg",  # 0: 슬라임 늪
  "res://resources/sounds/bgm_world_2.ogg",  # 1: 들판
  "res://resources/sounds/bgm_world_2.ogg",  # 2: 기사의 성벽
  "res://resources/sounds/bgm_world_3.ogg",  # 3: 마법의 숲
  "res://resources/sounds/bgm_world_3.ogg",  # 4: 수정 호수
  "res://resources/sounds/bgm_world_4.ogg",  # 5: 고대 유적
  "res://resources/sounds/bgm_world_4.ogg",  # 6: 용의 봉우리
]

@onready var world_root: Node2D = $WorldRoot
@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Player/GameCamera
@onready var upgrade_panel: Control = $UpgradePanel/Control
@onready var weapon_shop: Control = $WeaponShop/Control
@onready var back_to_menu_btn: Button = $BackToMenuUI/BackToMenuBtn
@onready var confirm_dialog: Control = $BackToMenuUI/ConfirmDialog
@onready var session_end_overlay: Control = $BackToMenuUI/SessionEndOverlay
@onready var touch_button: Button = $BackToMenuUI/SessionEndOverlay/TouchButton
@onready var session_earnings_label: Label = $BackToMenuUI/SessionEndOverlay/SessionEarningsLabel
@onready var bonus_label: Label = $BackToMenuUI/SessionEndOverlay/BonusLabel
@onready var tap_to_return_label: Label = $BackToMenuUI/SessionEndOverlay/TapToReturnLabel
@onready var timer_label: Label = $HUD/PaddedArea/TimerHBox/TimerLabel
@onready var timer_progress: ProgressBar = $HUD/PaddedArea/TimerHBox/TimerProgressBar

var session_time_remaining: float = SESSION_TIME
var session_ended: bool = false
var session_ready: bool = false
var bgm_player: AudioStreamPlayer

func _ready() -> void:
  camera.add_to_group("camera")

  # Hide the toggle buttons on panels (moved to main menu)
  upgrade_panel.set_toggle_button_visible(false)
  weapon_shop.set_toggle_button_visible(false)

  # Setup back to menu button and dialog
  back_to_menu_btn.pressed.connect(_on_back_to_menu_pressed)
  confirm_dialog.dialog_confirmed.connect(_on_confirm_back_to_menu)
  confirm_dialog.dialog_cancelled.connect(_on_cancel_back_to_menu)

  # Button styles
  back_to_menu_btn.text = ""
  back_to_menu_btn.icon = preload("res://resources/images/icon/go_home.png")
  back_to_menu_btn.expand_icon = true
  back_to_menu_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
  GameManager.style_button(back_to_menu_btn, "muted")

  # Setup session end overlay
  touch_button.pressed.connect(_on_session_end_touch)

  # Extra time powerup
  GameManager.extra_time_requested.connect(_on_extra_time)

  # Boss key → session end
  GameManager.boss_key_collected.connect(_on_boss_key_collected)

  # Style progress bar
  var bg_style = StyleBoxFlat.new()
  bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.5)
  bg_style.set_corner_radius_all(6)
  timer_progress.add_theme_stylebox_override("background", bg_style)
  var fill_style = StyleBoxFlat.new()
  fill_style.bg_color = Color(0.4, 0.8, 1.0)
  fill_style.set_corner_radius_all(6)
  timer_progress.add_theme_stylebox_override("fill", fill_style)

  # Initialize timer display
  update_timer_display()

  SessionManager.start_session()

  # 1초 후 세션 시작
  get_tree().create_timer(1.0).timeout.connect(_on_session_ready)

  # Start BGM
  _start_bgm()

func _process(delta: float) -> void:
  if session_ended or not session_ready:
    return

  session_time_remaining -= delta
  if session_time_remaining <= 0:
    session_time_remaining = 0
    end_session()

  # 종료 3초 전부터 화면 흔들림
  if session_time_remaining <= 3.0 and session_time_remaining > 0:
    var intensity = (3.0 - session_time_remaining) / 3.0 * 0.4
    camera.shake(intensity)

  update_timer_display()

func update_timer_display() -> void:
  var seconds = int(ceil(session_time_remaining))
  timer_label.text = str(seconds)

  # Update progress bar
  timer_progress.value = clampf((session_time_remaining / SESSION_TIME) * 100.0, 0.0, 100.0)

  # Change color when time is low
  if seconds <= 10:
    timer_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
    var fill_style = StyleBoxFlat.new()
    fill_style.bg_color = Color(1, 0.3, 0.3)
    fill_style.set_corner_radius_all(6)
    timer_progress.add_theme_stylebox_override("fill", fill_style)
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
  session_earnings_label.visible = false
  bonus_label.visible = false
  tap_to_return_label.modulate = Color(1, 1, 1, 0)
  touch_button.disabled = true

  # Results container (vertical stack)
  var results_vbox = VBoxContainer.new()
  results_vbox.name = "ResultsVBox"
  results_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
  results_vbox.add_theme_constant_override("separation", 12)
  results_vbox.layout_mode = 1
  results_vbox.anchor_left = session_earnings_label.anchor_left
  results_vbox.anchor_right = session_earnings_label.anchor_right
  results_vbox.anchor_top = session_earnings_label.anchor_top
  results_vbox.anchor_bottom = session_earnings_label.anchor_bottom
  results_vbox.offset_left = session_earnings_label.offset_left
  results_vbox.offset_right = session_earnings_label.offset_right
  results_vbox.offset_top = session_earnings_label.offset_top
  results_vbox.offset_bottom = session_earnings_label.offset_bottom
  results_vbox.grow_horizontal = session_earnings_label.grow_horizontal
  results_vbox.grow_vertical = session_earnings_label.grow_vertical
  results_vbox.modulate = Color(1, 1, 1, 0)

  # Earnings row
  var earnings_container = HBoxContainer.new()
  earnings_container.alignment = BoxContainer.ALIGNMENT_CENTER
  earnings_container.add_theme_constant_override("separation", 8)

  var prefix_label = Label.new()
  prefix_label.text = "획득: "
  prefix_label.add_theme_font_size_override("font_size", 36)
  prefix_label.add_theme_color_override("font_color", Color.WHITE)
  prefix_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  prefix_label.add_theme_constant_override("outline_size", 3)
  earnings_container.add_child(prefix_label)

  var coin_hbox = GameManager.create_coin_label(
    GameManager.format_number(earnings), 36, Color(1, 1, 1), 3)
  earnings_container.add_child(coin_hbox)
  results_vbox.add_child(earnings_container)

  # Key row (if boss key acquired this session)
  var key_world = GameManager.session_key_acquired
  if key_world >= 0:
    var world_names = ["슬라임 늪", "들판", "기사의 성벽", "마법의 숲", "수정 호수", "고대 유적", "용의 봉우리"]
    var world_name = world_names[key_world] if key_world < world_names.size() else "월드 %d" % key_world
    var key_label = Label.new()
    key_label.text = "+ 열쇠 (%s)" % world_name
    key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    key_label.add_theme_font_size_override("font_size", 34)
    key_label.add_theme_color_override("font_color", Color(0.3, 1.0, 1.0))
    key_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    key_label.add_theme_constant_override("outline_size", 3)
    results_vbox.add_child(key_label)

  session_end_overlay.add_child(results_vbox)

  # Show overlay
  session_end_overlay.visible = true

  # Fade in results
  var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
  tween.tween_property(results_vbox, "modulate:a", 1.0, 0.4)

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

func _on_session_ready() -> void:
  session_ready = true

func _on_back_to_menu_pressed() -> void:
  GameManager.play_button_click()
  confirm_dialog.show_dialog("첫 화면으로 돌아갈까요?", "처음으로", "게임 계속하기")
  get_tree().paused = true

func _on_confirm_back_to_menu() -> void:
  get_tree().paused = false
  var p = get_tree().get_first_node_in_group("player")
  if p and p.has_method("_remove_hit_overlay"):
    p._remove_hit_overlay()
  SessionManager.quit_to_menu()

func _on_cancel_back_to_menu() -> void:
  get_tree().paused = false

func _on_boss_key_collected(_world_index: int) -> void:
  if session_ended:
    return
  _boss_end_session()

func _boss_end_session() -> void:
  session_ended = true
  get_tree().paused = true
  back_to_menu_btn.visible = false

  var player = get_tree().get_first_node_in_group("player")
  if player and player.has_method("_remove_hit_overlay"):
    player._remove_hit_overlay()

  # 1초 정지 연출 (보스 처치 여운)
  await get_tree().create_timer(1.0).timeout

  if bgm_player:
    var bgm_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    bgm_tween.tween_property(bgm_player, "volume_db", -40.0, 1.5)
    bgm_tween.tween_callback(bgm_player.stop)

  var earnings = GameManager.session_money
  await animate_coins_disappear()
  show_session_end_overlay(earnings)

func _on_extra_time(seconds: float) -> void:
  session_time_remaining += seconds
