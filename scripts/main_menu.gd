extends Control

@onready var play_btn: Button = $VBoxContainer/PlayBtn
@onready var upgrade_btn: Button = $VBoxContainer/UpgradeBtn
@onready var item_btn: Button = $VBoxContainer/ItemBtn
@onready var quit_btn: Button = $VBoxContainer/QuitBtn
@onready var quit_confirm_dialog: Control = $QuitConfirmDialog
@onready var title_image: TextureRect = $TitleImage
@onready var padded_area: Control = $PaddedArea
@onready var money_display = $PaddedArea/MoneyDisplay
@onready var upgrade_panel: Control = $UpgradePanel/Control
@onready var item_panel: Control = $ItemPanel/Control

# World selection overlay (built dynamically)
var world_overlay: Control = null
var _ws_selected: int = -1  # Currently highlighted world index in panel
var _ws_cards_container: VBoxContainer = null
var _ws_action_btn: Button = null
var _item_badge: Label = null
var _debug_container: HBoxContainer = null
var _debug_tap_count: int = 0
var _debug_last_tap_time: float = 0.0

const WORLD_DATA: Array = [
  {"name": "슬라임 늪", "monsters": "슬라임"},
  {"name": "들판", "monsters": "멧돼지"},
  {"name": "기사의 성벽", "monsters": "잔디 기사"},
  {"name": "마법의 숲", "monsters": "마도사"},
  {"name": "수정 호수", "monsters": "수정 사슴"},
  {"name": "고대 유적", "monsters": "잔디 골렘"},
  {"name": "용의 봉우리", "monsters": "드래곤"},
]

func _ready() -> void:
  play_btn.pressed.connect(_on_play_pressed)
  upgrade_btn.pressed.connect(_on_upgrade_pressed)
  item_btn.pressed.connect(_on_item_pressed)
  quit_btn.pressed.connect(_on_quit_pressed)
  quit_confirm_dialog.dialog_confirmed.connect(func(): get_tree().quit())

  # Hide the toggle buttons on panels (we use menu buttons instead)
  upgrade_panel.call_deferred("set_toggle_button_visible", false)
  item_panel.call_deferred("set_toggle_button_visible", false)

  # Connect panel signals for mutual exclusion
  upgrade_panel.panel_opened.connect(_on_panel_opened)
  upgrade_panel.panel_closed.connect(_on_panel_closed)
  item_panel.panel_opened.connect(_on_panel_opened)
  item_panel.panel_closed.connect(_on_panel_closed)

  # Money display is handled by MoneyDisplay scene

  # Debug buttons (hidden, activated by tapping money display 5 times)
  _build_debug_buttons()
  _debug_container.visible = false
  money_display.mouse_filter = Control.MOUSE_FILTER_STOP
  money_display.gui_input.connect(_on_money_display_input)

  # 버튼 스타일 적용 (btn_size로 크기+폰트 자동 비례)
  var viewport_w = get_viewport_rect().size.x

  play_btn.text = ""
  play_btn.icon = preload("res://resources/images/icon/start.png")
  play_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
  play_btn.expand_icon = true
  play_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
  GameManager.style_button(play_btn, "main", Vector2(460, 288))


  upgrade_btn.text = "강화"
  upgrade_btn.icon = preload("res://resources/images/icon/icon_upgrade.png")
  upgrade_btn.expand_icon = true
  upgrade_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
  GameManager.style_button(upgrade_btn, "sub", Vector2(460, 112))


  item_btn.text = "아이템"
  item_btn.icon = preload("res://resources/images/icon/icon_inventory.png")
  item_btn.expand_icon = true
  item_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
  GameManager.style_button(item_btn, "sub", Vector2(460, 112))
  _setup_item_badge()
  GameManager.inventory_changed.connect(_update_item_badge)


  quit_btn.text = "종료"
  quit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
  GameManager.style_button(quit_btn, "muted", Vector2(460, 112))

  # Title animation
  animate_title()

  # Main menu BGM
  _start_menu_bgm()

  # Show prologue on first launch (temporarily disabled)
  #if not GameManager.prologue_seen:
  #  _show_prologue()


var _menu_bgm: AudioStreamPlayer

func _start_menu_bgm() -> void:
  _menu_bgm = AudioStreamPlayer.new()
  _menu_bgm.stream = load("res://resources/sounds/bgm_main.ogg")
  _menu_bgm.volume_db = -10.0
  _menu_bgm.finished.connect(_menu_bgm.play)
  add_child(_menu_bgm)
  _menu_bgm.play()


func animate_title() -> void:
  title_image.pivot_offset = title_image.size / 2.0
  var tween = create_tween()
  tween.set_loops()
  tween.tween_property(title_image, "scale", Vector2(1.05, 1.05), 1.0)
  tween.tween_property(title_image, "scale", Vector2(1.0, 1.0), 1.0)

func _on_play_pressed() -> void:
  GameManager.play_button_click()
  _open_world_select()

func _start_game() -> void:
  if _menu_bgm:
    _menu_bgm.stop()
  get_tree().change_scene_to_file("res://scenes/core/main.tscn")

func _notification(what: int) -> void:
  if what == NOTIFICATION_WM_GO_BACK_REQUEST:
    if quit_confirm_dialog.visible:
      quit_confirm_dialog.hide_dialog()
    elif upgrade_panel.is_open:
      upgrade_panel._on_close_pressed()
    elif item_panel.is_open:
      item_panel._on_close_pressed()
    elif world_overlay != null:
      _close_world_select()

func _on_upgrade_pressed() -> void:
  GameManager.play_button_click()
  upgrade_panel.open_panel()

func _on_item_pressed() -> void:
  GameManager.play_button_click()
  item_panel.open_panel()

func _on_quit_pressed() -> void:
  GameManager.play_button_click()
  quit_confirm_dialog.show_dialog("게임을 종료할까요?")

func _show_prologue() -> void:
  var prologue = preload("res://scripts/prologue.gd").new()
  add_child(prologue)
  prologue.finished.connect(_on_prologue_finished)
  _on_panel_opened()

func _on_prologue_finished() -> void:
  GameManager.prologue_seen = true
  SaveManager.save_game()
  _on_panel_closed()

func _setup_item_badge() -> void:
  _item_badge = Label.new()
  _item_badge.text = "!"
  _item_badge.add_theme_font_size_override("font_size", 28)
  _item_badge.add_theme_color_override("font_color", Color.WHITE)
  _item_badge.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  _item_badge.add_theme_constant_override("outline_size", 4)
  _item_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
  _item_badge.offset_left = -60
  _item_badge.offset_right = -20
  _item_badge.offset_top = 4
  _item_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  _item_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
  # Red circle background
  var bg = StyleBoxFlat.new()
  bg.bg_color = Color(0.9, 0.15, 0.15)
  bg.corner_radius_top_left = 16
  bg.corner_radius_top_right = 16
  bg.corner_radius_bottom_left = 16
  bg.corner_radius_bottom_right = 16
  bg.content_margin_left = 6
  bg.content_margin_right = 6
  bg.content_margin_top = 2
  bg.content_margin_bottom = 2
  _item_badge.add_theme_stylebox_override("normal", bg)
  item_btn.add_child(_item_badge)
  _update_item_badge()

func _update_item_badge() -> void:
  var has_craftable = false
  for recipe in item_panel.RECIPES:
    # Skip if already at max needed for final assembly
    var needed = item_panel._get_final_recipe_required(recipe.id)
    if GameManager.get_item_count(recipe.id) >= needed:
      continue
    var can_craft = true
    for ingredient in recipe.ingredients:
      if GameManager.get_item_count(ingredient.item_id) < ingredient.count:
        can_craft = false
        break
    if can_craft:
      has_craftable = true
      break
  _item_badge.visible = has_craftable

func _on_panel_opened() -> void:
  play_btn.disabled = true
  upgrade_btn.disabled = true
  item_btn.disabled = true
  quit_btn.disabled = true

func _on_panel_closed() -> void:
  play_btn.disabled = false
  upgrade_btn.disabled = false
  item_btn.disabled = false
  quit_btn.disabled = false
  _update_item_badge()

func update_money_display() -> void:
  money_display.update_display()

# ── World Selection Panel ──

func _open_world_select() -> void:
  if world_overlay != null:
    return
  _on_panel_opened()
  _ws_selected = GameManager.selected_world

  world_overlay = Control.new()
  world_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
  world_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
  add_child(world_overlay)

  # Dim background
  var bg = ColorRect.new()
  bg.color = Color(0.04, 0.07, 0.08, 0.8)
  bg.set_anchors_preset(Control.PRESET_FULL_RECT)
  world_overlay.add_child(bg)

  # Center panel — fill 30% more of remaining space on each side
  var viewport_size = get_viewport().get_visible_rect().size
  var base_w = 700.0
  var base_h = 0.0  # auto height
  var margin_x = (viewport_size.x - base_w) / 2.0
  var extra_x = margin_x * 0.3
  var panel_w = base_w + extra_x * 2.0
  # Vertical: estimate base panel height ~70% of viewport, expand 30% of remaining
  var base_h_ratio = 0.7
  var margin_y = viewport_size.y * (1.0 - base_h_ratio) / 2.0
  var extra_y = margin_y * 0.3

  var center = CenterContainer.new()
  center.set_anchors_preset(Control.PRESET_FULL_RECT)
  world_overlay.add_child(center)

  var panel = PanelContainer.new()
  panel.custom_minimum_size = Vector2(panel_w, viewport_size.y - (margin_y - extra_y) * 2.0)
  var panel_style = StyleBoxFlat.new()
  panel_style.bg_color = Color(0.09, 0.12, 0.12)
  panel_style.corner_radius_top_left = 20
  panel_style.corner_radius_top_right = 20
  panel_style.corner_radius_bottom_left = 20
  panel_style.corner_radius_bottom_right = 20
  panel_style.border_width_top = 3
  panel_style.border_width_bottom = 3
  panel_style.border_width_left = 3
  panel_style.border_width_right = 3
  panel_style.border_color = Color(0.25, 0.47, 0.4)
  panel_style.content_margin_left = 30
  panel_style.content_margin_right = 30
  panel_style.content_margin_top = 44
  panel_style.content_margin_bottom = 0
  panel.add_theme_stylebox_override("panel", panel_style)
  center.add_child(panel)

  var vbox = VBoxContainer.new()
  vbox.add_theme_constant_override("separation", 7)
  panel.add_child(vbox)

  # Header
  var header = Label.new()
  header.text = "월드 선택"
  header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  header.add_theme_font_size_override("font_size", 50)
  header.add_theme_color_override("font_color", Color.WHITE)
  header.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  header.add_theme_constant_override("outline_size", 3)
  vbox.add_child(header)

  # Separator (with 12px top/bottom margin via MarginContainer)
  var sep_margin = MarginContainer.new()
  sep_margin.add_theme_constant_override("margin_top", 16)
  sep_margin.add_theme_constant_override("margin_bottom", 16)
  vbox.add_child(sep_margin)
  var sep = ColorRect.new()
  sep.color = Color(0.24, 0.24, 0.32)
  sep.custom_minimum_size = Vector2(0, 2)
  sep_margin.add_child(sep)

  # World cards container (for rebuilding cards on selection change)
  _ws_cards_container = VBoxContainer.new()
  _ws_cards_container.add_theme_constant_override("separation", 20)
  vbox.add_child(_ws_cards_container)

  _ws_rebuild_cards()

  # Spacer between cards and buttons
  var spacer = Control.new()
  spacer.custom_minimum_size = Vector2(0, 40)
  vbox.add_child(spacer)

  # Action button (게임 입장 / 해금)
  var action_center = CenterContainer.new()
  action_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  vbox.add_child(action_center)

  _ws_action_btn = Button.new()
  _ws_action_btn.custom_minimum_size = Vector2(420, 90)
  _ws_action_btn.add_theme_font_size_override("font_size", 38)
  _ws_action_btn.pressed.connect(_on_action_btn_pressed)
  GameManager.style_button(_ws_action_btn)
  action_center.add_child(_ws_action_btn)
  _ws_update_action_btn()

  # Close button
  var close_center = CenterContainer.new()
  close_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  vbox.add_child(close_center)

  var close_btn = Button.new()
  close_btn.text = "닫기"
  close_btn.custom_minimum_size = Vector2(200, 52)
  close_btn.add_theme_font_size_override("font_size", 26)
  close_btn.pressed.connect(_close_world_select)
  GameManager.style_button(close_btn, "muted")
  close_center.add_child(close_btn)

func _ws_rebuild_cards() -> void:
  for child in _ws_cards_container.get_children():
    child.queue_free()
  for i in range(WORLD_DATA.size()):
    var card = _create_world_card(i)
    _ws_cards_container.add_child(card)

func _create_world_card(index: int) -> PanelContainer:
  var world = WORLD_DATA[index]
  var unlocked = index in GameManager.unlocked_worlds
  var cost = GameManager.WORLD_UNLOCK_COSTS[index]
  var selected = index == _ws_selected

  var card = PanelContainer.new()
  card.custom_minimum_size = Vector2(0, 143)

  var style = StyleBoxFlat.new()
  if selected:
    if unlocked:
      style.bg_color = Color(0.12, 0.24, 0.2)
      style.border_color = Color(0.35, 0.85, 0.62)
    else:
      style.bg_color = Color(0.15, 0.15, 0.22)
      style.border_color = Color(0.45, 0.45, 0.7)
    style.border_width_top = 3
    style.border_width_bottom = 3
    style.border_width_left = 3
    style.border_width_right = 3
  else:
    if unlocked:
      style.bg_color = Color(0.1, 0.17, 0.15)
      style.border_color = Color(0.25, 0.55, 0.42)
    else:
      style.bg_color = Color(0.09, 0.1, 0.14)
      style.border_color = Color(0.22, 0.26, 0.35)
    style.border_width_top = 2
    style.border_width_bottom = 2
    style.border_width_left = 2
    style.border_width_right = 2
  style.corner_radius_top_left = 14
  style.corner_radius_top_right = 14
  style.corner_radius_bottom_left = 14
  style.corner_radius_bottom_right = 14
  style.content_margin_left = 26
  style.content_margin_right = 26
  style.content_margin_top = 18
  style.content_margin_bottom = 18
  card.add_theme_stylebox_override("panel", style)

  var has_key = GameManager.has_key(index)
  var fully_locked = not unlocked and not has_key

  if fully_locked:
    # Locked without key: show only lock icon centered
    var lock_container = CenterContainer.new()
    lock_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    lock_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    card.add_child(lock_container)
    var lock_icon = TextureRect.new()
    lock_icon.texture = preload("res://resources/images/icon/lock.png")
    lock_icon.custom_minimum_size = Vector2(108, 108)
    lock_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    lock_icon.modulate = Color(0.4, 0.4, 0.5)
    lock_container.add_child(lock_icon)
  else:
    var hbox = HBoxContainer.new()
    hbox.add_theme_constant_override("separation", 14)
    hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card.add_child(hbox)

    # Status icon
    var icon_label = Label.new()
    icon_label.add_theme_font_size_override("font_size", 43)
    icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if unlocked:
      icon_label.text = "O"
      icon_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.55))
    else:
      icon_label.text = "X"
      icon_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
    hbox.add_child(icon_label)

    # Info column
    var info_vbox = VBoxContainer.new()
    info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    info_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    info_vbox.add_theme_constant_override("separation", 8)
    info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hbox.add_child(info_vbox)

    var name_label = Label.new()
    name_label.text = world.name
    name_label.add_theme_font_size_override("font_size", 38)
    name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if unlocked:
      name_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
    else:
      name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
    name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    name_label.add_theme_constant_override("outline_size", 2)
    info_vbox.add_child(name_label)

    var monster_label = Label.new()
    monster_label.text = world.monsters
    monster_label.add_theme_font_size_override("font_size", 26)
    monster_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if unlocked:
      monster_label.add_theme_color_override("font_color", Color(0.62, 0.7, 0.66))
    else:
      monster_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
    info_vbox.add_child(monster_label)

    var strength = GameManager.get_world_strength_level(index)

    # 초월 UI (클리어된 월드만)
    if unlocked and GameManager.is_world_cleared(index):
      var str_hbox = HBoxContainer.new()
      str_hbox.add_theme_constant_override("separation", 10)
      str_hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
      str_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
      hbox.add_child(str_hbox)

      # 텍스트 두줄: 초월 레벨 + 효과
      var str_info = VBoxContainer.new()
      str_info.add_theme_constant_override("separation", 1)
      str_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
      str_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
      str_hbox.add_child(str_info)

      var str_label = Label.new()
      str_label.text = "초월 Lv.%d" % strength
      str_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
      str_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
      str_label.add_theme_font_size_override("font_size", 28)
      str_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
      str_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
      str_label.add_theme_constant_override("outline_size", 2)
      str_info.add_child(str_label)

      if strength > 0:
        var str_spacer = Control.new()
        str_spacer.custom_minimum_size = Vector2(0, 8)
        str_info.add_child(str_spacer)
        var hp_bonus = int(strength * 30)
        var rw_bonus = int(strength * 50)
        var hp_label = Label.new()
        hp_label.text = "체력+%d%%" % hp_bonus
        hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        hp_label.add_theme_font_size_override("font_size", 23)
        hp_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.4))
        str_info.add_child(hp_label)
        var rw_label = Label.new()
        rw_label.text = "보상+%d%%" % rw_bonus
        rw_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        rw_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        rw_label.add_theme_font_size_override("font_size", 23)
        rw_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.4))
        str_info.add_child(rw_label)

      var str_btn = Button.new()
      str_btn.text = "초월"
      str_btn.add_theme_font_size_override("font_size", 36)
      str_btn.custom_minimum_size = Vector2(150, 108)
      str_btn.pressed.connect(_on_strengthen_pressed.bind(index))
      GameManager.style_button(str_btn, "main")
      str_hbox.add_child(str_btn)

    # Cost / key status (locked with key)
    if not unlocked:
      var status_vbox = VBoxContainer.new()
      status_vbox.add_theme_constant_override("separation", 8)
      status_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
      status_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
      hbox.add_child(status_vbox)

      var cost_color = Color(1, 0.9, 0.3) if GameManager.money >= cost else Color(0.5, 0.4, 0.4)
      var cost_hbox = GameManager.create_coin_label(GameManager.format_number(cost), 38, cost_color)
      cost_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
      status_vbox.add_child(cost_hbox)

      var key_label = Label.new()
      key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
      key_label.add_theme_font_size_override("font_size", 26)
      key_label.text = "열쇠 보유"
      key_label.add_theme_color_override("font_color", Color(0.3, 1.0, 1.0))
      key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
      status_vbox.add_child(key_label)

  # Clickable overlay button (disabled for fully locked worlds)
  # 초월 버튼보다 먼저 추가하여, 초월 버튼이 위에 오도록 함
  if not fully_locked:
    var btn = Button.new()
    btn.flat = true
    btn.anchors_preset = Control.PRESET_FULL_RECT
    btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    btn.pressed.connect(_on_world_card_pressed.bind(index))
    card.add_child(btn)
    card.move_child(btn, 0)

  return card

func _on_world_card_pressed(index: int) -> void:
  GameManager.play_button_click()
  _ws_selected = index
  _ws_rebuild_cards()
  _ws_update_action_btn()

var _strengthen_dialog: Control = null

func _on_strengthen_pressed(index: int) -> void:
  GameManager.play_button_click()
  _show_strengthen_dialog(index)

func _show_strengthen_dialog(world: int) -> void:
  if _strengthen_dialog:
    _strengthen_dialog.queue_free()

  var level = GameManager.get_world_strength_level(world)
  var cost = GameManager.get_strengthen_cost(world)
  var can_afford = GameManager.money >= cost

  var base_hp = GameManager.WORLD_GRASS_HP_MULT[world] if world < GameManager.WORLD_GRASS_HP_MULT.size() else 1.0
  var base_rw = GameManager.WORLD_GRASS_REWARD_MULT[world] if world < GameManager.WORLD_GRASS_REWARD_MULT.size() else 1.0
  var cur_hp = base_hp * (1.0 + level * 0.3)
  var cur_rw = base_rw * (1.0 + level * 0.5)
  var next_hp = base_hp * (1.0 + (level + 1) * 0.3)
  var next_rw = base_rw * (1.0 + (level + 1) * 0.5)

  # Root overlay
  var root = Control.new()
  root.set_anchors_preset(Control.PRESET_FULL_RECT)
  root.mouse_filter = Control.MOUSE_FILTER_STOP

  var overlay = ColorRect.new()
  overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
  overlay.color = Color(0, 0, 0, 0.6)
  root.add_child(overlay)

  # Dialog panel
  var panel_style = StyleBoxFlat.new()
  panel_style.bg_color = Color(0.15, 0.15, 0.2, 0.98)
  panel_style.corner_radius_top_left = 15
  panel_style.corner_radius_top_right = 15
  panel_style.corner_radius_bottom_right = 15
  panel_style.corner_radius_bottom_left = 15

  var panel = Panel.new()
  panel.set_anchors_preset(Control.PRESET_CENTER)
  panel.offset_left = -300
  panel.offset_top = -185
  panel.offset_right = 300
  panel.offset_bottom = 185
  panel.add_theme_stylebox_override("panel", panel_style)
  root.add_child(panel)

  var vbox = VBoxContainer.new()
  vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
  vbox.offset_left = 28
  vbox.offset_top = 24
  vbox.offset_right = -28
  vbox.offset_bottom = -24
  vbox.add_theme_constant_override("separation", 14)
  panel.add_child(vbox)

  # Title
  var title = Label.new()
  title.text = "초월 Lv.%d → Lv.%d" % [level, level + 1]
  title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  title.add_theme_font_size_override("font_size", 32)
  title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
  title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  title.add_theme_constant_override("outline_size", 3)
  vbox.add_child(title)

  # Cost row
  var cost_row = HBoxContainer.new()
  cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
  cost_row.add_theme_constant_override("separation", 8)
  var cost_label = Label.new()
  cost_label.text = "비용  "
  cost_label.add_theme_font_size_override("font_size", 28)
  cost_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
  cost_row.add_child(cost_label)
  var cost_color = Color(1, 0.9, 0.3) if can_afford else Color(0.8, 0.3, 0.3)
  var coin_label = GameManager.create_coin_label(GameManager.format_number(cost), 28, cost_color)
  cost_row.add_child(coin_label)
  vbox.add_child(cost_row)

  # Separator
  var sep = ColorRect.new()
  sep.color = Color(0.24, 0.24, 0.32)
  sep.custom_minimum_size = Vector2(0, 2)
  vbox.add_child(sep)

  # Effects
  var effects_vbox = VBoxContainer.new()
  effects_vbox.add_theme_constant_override("separation", 6)

  var hp_rt = RichTextLabel.new()
  hp_rt.bbcode_enabled = true
  hp_rt.fit_content = true
  hp_rt.scroll_active = false
  hp_rt.text = "[center]풀 체력   x%.1f → [color=#ff6655]x%.1f[/color][/center]" % [cur_hp, next_hp]
  hp_rt.add_theme_font_size_override("normal_font_size", 25)
  hp_rt.add_theme_color_override("default_color", Color(0.85, 0.85, 0.9))
  effects_vbox.add_child(hp_rt)

  var rw_rt = RichTextLabel.new()
  rw_rt.bbcode_enabled = true
  rw_rt.fit_content = true
  rw_rt.scroll_active = false
  rw_rt.text = "[center]풀 보상   x%.1f → [color=#ff6655]x%.1f[/color][/center]" % [cur_rw, next_rw]
  rw_rt.add_theme_font_size_override("normal_font_size", 25)
  rw_rt.add_theme_color_override("default_color", Color(0.85, 0.85, 0.9))
  effects_vbox.add_child(rw_rt)

  vbox.add_child(effects_vbox)

  # Not enough money warning
  if not can_afford:
    var warn = Label.new()
    warn.text = "돈이 부족합니다"
    warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    warn.add_theme_font_size_override("font_size", 22)
    warn.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
    vbox.add_child(warn)

  # Spacer
  var spacer = Control.new()
  spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
  vbox.add_child(spacer)

  # Buttons
  var btn_row = HBoxContainer.new()
  btn_row.add_theme_constant_override("separation", 20)
  var confirm_btn = Button.new()
  confirm_btn.text = "초월하기"
  confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  confirm_btn.custom_minimum_size = Vector2(0, 80)
  confirm_btn.add_theme_font_size_override("font_size", 28)
  confirm_btn.disabled = not can_afford
  GameManager.style_button(confirm_btn, "main" if can_afford else "muted")
  confirm_btn.pressed.connect(_on_strengthen_confirmed.bind(world))
  btn_row.add_child(confirm_btn)

  var cancel_btn = Button.new()
  cancel_btn.text = "취소"
  cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  cancel_btn.custom_minimum_size = Vector2(0, 80)
  cancel_btn.add_theme_font_size_override("font_size", 28)
  GameManager.style_button(cancel_btn, "muted")
  cancel_btn.pressed.connect(_on_strengthen_cancelled)
  btn_row.add_child(cancel_btn)

  vbox.add_child(btn_row)

  _strengthen_dialog = root
  add_child(root)

func _on_strengthen_confirmed(world: int) -> void:
  if _strengthen_dialog:
    _strengthen_dialog.queue_free()
    _strengthen_dialog = null
  if GameManager.strengthen_world(world):
    GameManager.play_skill_upgrade_sound()
    update_money_display()
    _ws_rebuild_cards()

func _on_strengthen_cancelled() -> void:
  GameManager.play_button_click()
  if _strengthen_dialog:
    _strengthen_dialog.queue_free()
    _strengthen_dialog = null

func _ws_update_action_btn() -> void:
  if _ws_action_btn == null:
    return

  var unlocked = _ws_selected in GameManager.unlocked_worlds
  if unlocked:
    _ws_action_btn.text = "게임 입장"
    _ws_action_btn.disabled = false
  else:
    var cost = GameManager.WORLD_UNLOCK_COSTS[_ws_selected]
    var has_key = GameManager.has_key(_ws_selected)
    if has_key:
      _ws_action_btn.text = "해금"
      _ws_action_btn.disabled = GameManager.money < cost
    else:
      _ws_action_btn.text = "열쇠 필요"
      _ws_action_btn.disabled = true

func _on_action_btn_pressed() -> void:
  GameManager.play_confirm_click()
  if _ws_selected < 0:
    return
  var unlocked = _ws_selected in GameManager.unlocked_worlds
  if unlocked:
    GameManager.selected_world = _ws_selected
    _close_world_select()
    _start_game()
  else:
    if GameManager.unlock_world(_ws_selected):
      GameManager.play_unlock_sound()
      update_money_display()
      _ws_rebuild_cards()
      _ws_update_action_btn()

func _close_world_select() -> void:
  GameManager.play_button_click()
  if world_overlay != null:
    world_overlay.queue_free()
    world_overlay = null
  _ws_cards_container = null
  _ws_action_btn = null
  _on_panel_closed()

# ── Debug Buttons ──

const DEBUG_ALL_ITEMS: Array = [
  "질긴 슬라임 조각", "번개 먹은 배터리 껍질", "차축 뼈대",
  "굴러다니는 바퀴 잔해", "과성장 생체 응축체", "왜곡된 볼트 조각",
  "압축된 이세계 철편", "생체 연료 포자", "뒤틀린 시간 포자",
  "바람 머금은 잔디 섬유", "몬스터 핵", "침식된 백골 프레임",
  "투명 수정 파편", "강화 유리 결정핵", "과열된 엔진 심장",
  "드래곤 배기가스 결정",
]

func _on_money_display_input(event: InputEvent) -> void:
  if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
    var now = Time.get_ticks_msec() / 1000.0
    if now - _debug_last_tap_time > 3.0:
      _debug_tap_count = 0
    _debug_last_tap_time = now
    _debug_tap_count += 1
    if _debug_tap_count >= 5:
      _debug_container.visible = !_debug_container.visible
      _debug_tap_count = 0

func _build_debug_buttons() -> void:
  _debug_container = HBoxContainer.new()
  _debug_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
  _debug_container.offset_top = -50.0
  _debug_container.alignment = BoxContainer.ALIGNMENT_CENTER
  _debug_container.add_theme_constant_override("separation", 12)
  padded_area.add_child(_debug_container)

  var reset_btn = Button.new()
  reset_btn.text = "초기화"
  reset_btn.add_theme_font_size_override("font_size", 18)
  reset_btn.pressed.connect(_on_debug_reset)
  GameManager.style_button(reset_btn, "sub")
  _debug_container.add_child(reset_btn)

  var money_btn = Button.new()
  money_btn.text = "+$100000"
  money_btn.add_theme_font_size_override("font_size", 18)
  money_btn.pressed.connect(_on_debug_add_money)
  GameManager.style_button(money_btn, "sub")
  _debug_container.add_child(money_btn)

  var items_btn = Button.new()
  items_btn.text = "아이템+10"
  items_btn.add_theme_font_size_override("font_size", 18)
  items_btn.pressed.connect(_on_debug_add_items)
  GameManager.style_button(items_btn)
  _debug_container.add_child(items_btn)

  var unlock_btn = Button.new()
  unlock_btn.text = "월드 전체해금"
  unlock_btn.add_theme_font_size_override("font_size", 18)
  unlock_btn.pressed.connect(_on_debug_unlock_all)
  GameManager.style_button(unlock_btn, "sub")
  _debug_container.add_child(unlock_btn)

func _on_debug_reset() -> void:
  SaveManager.reset_all_data()
  update_money_display()

func _on_debug_add_money() -> void:
  GameManager.money += 100000
  GameManager.money_changed.emit(GameManager.money)
  SaveManager.save_game()

func _on_debug_add_items() -> void:
  for item_id in DEBUG_ALL_ITEMS:
    GameManager.add_item(item_id, 10)
  SaveManager.save_game()

func _on_debug_unlock_all() -> void:
  for i in range(GameManager.WORLD_UNLOCK_COSTS.size()):
    if i not in GameManager.unlocked_worlds:
      GameManager.unlocked_worlds.append(i)
  SaveManager.save_game()
