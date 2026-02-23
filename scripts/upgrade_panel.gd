extends Control

signal panel_opened
signal panel_closed

@onready var panel: Panel = $Panel
@onready var total_skill_label: Label = $Panel/TotalSkillLabel
@onready var description_label: Label = $Panel/DescriptionPanel/DescriptionLabel
@onready var confirm_btn: Button = $Panel/ConfirmBtn
@onready var close_btn: Button = $Panel/CloseBtn
@onready var toggle_btn: Button = $ToggleBtn
@onready var money_label: Label = $Panel/MoneyLabel
@onready var skill_tree_hbox: HBoxContainer = $Panel/SkillTreeScroll/SkillTreeHBox

# Weapon nodes
@onready var weapon_image: TextureRect = $Panel/WeaponSection/WeaponHBox/WeaponImage
@onready var weapon_info_vbox: VBoxContainer = $Panel/WeaponSection/WeaponHBox/WeaponInfo

var is_open: bool = false
var show_toggle_button: bool = true

# Selection: "weapon" or skill type ("grass_density" etc), "" = none
var selected_type: String = ""
var selected_level: int = -1

# Skill tree definitions
const SKILL_CHAINS = [
  {
    "type": "grass_density",
    "name": "풀 밀도",
    "description": "맵에 풀이 더 빽빽하게 자랍니다.",
    "max_level": 10
  },
  {
    "type": "grass_quality",
    "name": "풀 등급",
    "description": "더 높은 등급의 풀이 등장할 확률이 증가합니다.",
    "max_level": 10
  },
  {
    "type": "grass_regen",
    "name": "풀 재생",
    "description": "베어진 풀이 더 빨리 다시 자랍니다.",
    "max_level": 10
  },
  {
    "type": "grass_reward",
    "name": "풀 보상",
    "description": "풀에서 떨어지는 코인이 증가합니다.",
    "max_level": 10
  },
  {
    "type": "monster_knockback",
    "name": "넉백 증가",
    "description": "몬스터를 더 멀리 밀어냅니다.",
    "max_level": 5
  },
  {
    "type": "grass_drop",
    "name": "드롭률 증가",
    "description": "풀에서 코인이 떨어질 확률이 증가합니다.",
    "max_level": 5
  }
]

# Node visual settings
const NODE_SIZE: int = 55
const CONNECTOR_HEIGHT: int = 16

# Colors
const COLOR_COMPLETED = Color(0.2, 0.55, 0.3)
const COLOR_PURCHASABLE = Color(0.85, 0.7, 0.15)
const COLOR_PURCHASABLE_BORDER = Color(1.0, 0.9, 0.3)
const COLOR_LOCKED = Color(0.25, 0.25, 0.3)
const COLOR_LABEL = Color(0.7, 0.75, 0.8)

func _ready() -> void:
  panel.visible = false
  toggle_btn.pressed.connect(_on_toggle_pressed)
  close_btn.pressed.connect(_on_close_pressed)
  confirm_btn.pressed.connect(_on_confirm_pressed)

  GameManager.money_changed.connect(_on_money_changed)
  GameManager.upgrade_purchased.connect(_on_upgrade_purchased)
  WeaponManager.weapon_changed.connect(_on_weapon_changed)

  # Button styles
  GameManager.style_button(toggle_btn, Color(0.35, 0.55, 0.85))
  GameManager.style_button(close_btn, Color(0.45, 0.45, 0.5))
  GameManager.style_button(confirm_btn, Color(0.3, 0.75, 0.45))

  update_money_display()
  update_weapon_display()
  update_total_skill_label()
  build_skill_tree()
  clear_selection()
  toggle_btn.visible = show_toggle_button

func set_toggle_button_visible(should_show: bool) -> void:
  show_toggle_button = should_show
  if toggle_btn:
    toggle_btn.visible = should_show

func open_panel() -> void:
  if is_open:
    return
  is_open = true
  panel.visible = true
  update_money_display()
  update_weapon_display()
  update_total_skill_label()
  build_skill_tree()
  clear_selection()
  panel_opened.emit()

func _on_toggle_pressed() -> void:
  GameManager.play_button_click()
  is_open = !is_open
  panel.visible = is_open
  if is_open:
    update_money_display()
    update_weapon_display()
    update_total_skill_label()
    build_skill_tree()
    clear_selection()
    panel_opened.emit()
  else:
    panel_closed.emit()

func _on_close_pressed() -> void:
  GameManager.play_button_click()
  is_open = false
  panel.visible = false
  panel_closed.emit()

func _on_other_panel_opened() -> void:
  toggle_btn.disabled = true

func _on_other_panel_closed() -> void:
  toggle_btn.disabled = false

# ── Weapon ──

func _on_weapon_changed(_level: int) -> void:
  update_weapon_display()

var current_weapon_title: Label = null
var current_weapon_label: Label = null
var next_weapon_arrow: Label = null
var next_weapon_panel: PanelContainer = null
var next_weapon_image: TextureRect = null
var next_weapon_title: Label = null
var next_weapon_label: Label = null
var next_weapon_vbox: VBoxContainer = null
var weapon_buy_btn: Button = null
var weapon_condition_vbox: VBoxContainer = null
var weapon_right_vbox: VBoxContainer = null
var weapon_hbox: HBoxContainer = null

func _ensure_next_weapon_nodes() -> void:
  if next_weapon_arrow:
    return
  weapon_hbox = weapon_image.get_parent()
  var img_index = weapon_image.get_index()

  # Remove original WeaponInfo (replaced by image labels)
  weapon_info_vbox.queue_free()

  # Wrap current weapon image in PanelContainer with border
  var current_panel = PanelContainer.new()
  var current_style = StyleBoxFlat.new()
  current_style.bg_color = Color(0.12, 0.12, 0.18)
  current_style.corner_radius_top_left = 10
  current_style.corner_radius_top_right = 10
  current_style.corner_radius_bottom_left = 10
  current_style.corner_radius_bottom_right = 10
  current_style.border_width_top = 2
  current_style.border_width_bottom = 2
  current_style.border_width_left = 2
  current_style.border_width_right = 2
  current_style.border_color = Color(0.3, 0.5, 0.7)
  current_style.content_margin_left = 8
  current_style.content_margin_right = 8
  current_style.content_margin_top = 8
  current_style.content_margin_bottom = 8
  current_panel.add_theme_stylebox_override("panel", current_style)
  weapon_hbox.add_child(current_panel)
  weapon_hbox.move_child(current_panel, img_index)
  var current_vbox = VBoxContainer.new()
  current_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
  current_vbox.add_theme_constant_override("separation", 2)
  current_panel.add_child(current_vbox)
  current_weapon_title = Label.new()
  current_weapon_title.text = "현재 무기"
  current_weapon_title.add_theme_font_size_override("font_size", 22)
  current_weapon_title.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
  current_weapon_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  current_vbox.add_child(current_weapon_title)
  weapon_image.reparent(current_vbox)
  current_weapon_label = Label.new()
  current_weapon_label.add_theme_font_size_override("font_size", 20)
  current_weapon_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
  current_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  current_vbox.add_child(current_weapon_label)

  # Arrow
  next_weapon_arrow = Label.new()
  next_weapon_arrow.text = "→"
  next_weapon_arrow.add_theme_font_size_override("font_size", 40)
  next_weapon_arrow.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
  next_weapon_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  weapon_hbox.add_child(next_weapon_arrow)
  weapon_hbox.move_child(next_weapon_arrow, current_panel.get_index() + 1)

  # Next weapon card with border
  var next_panel = PanelContainer.new()
  var next_style = StyleBoxFlat.new()
  next_style.bg_color = Color(0.15, 0.13, 0.1)
  next_style.corner_radius_top_left = 10
  next_style.corner_radius_top_right = 10
  next_style.corner_radius_bottom_left = 10
  next_style.corner_radius_bottom_right = 10
  next_style.border_width_top = 2
  next_style.border_width_bottom = 2
  next_style.border_width_left = 2
  next_style.border_width_right = 2
  next_style.border_color = Color(0.7, 0.55, 0.15)
  next_style.content_margin_left = 8
  next_style.content_margin_right = 8
  next_style.content_margin_top = 8
  next_style.content_margin_bottom = 8
  next_panel.add_theme_stylebox_override("panel", next_style)
  next_weapon_panel = next_panel
  weapon_hbox.add_child(next_panel)
  weapon_hbox.move_child(next_panel, next_weapon_arrow.get_index() + 1)

  next_weapon_vbox = VBoxContainer.new()
  next_weapon_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
  next_weapon_vbox.add_theme_constant_override("separation", 2)
  next_panel.add_child(next_weapon_vbox)

  next_weapon_title = Label.new()
  next_weapon_title.text = "다음 무기"
  next_weapon_title.add_theme_font_size_override("font_size", 22)
  next_weapon_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
  next_weapon_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  next_weapon_vbox.add_child(next_weapon_title)

  next_weapon_image = TextureRect.new()
  next_weapon_image.custom_minimum_size = Vector2(150, 150)
  next_weapon_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
  next_weapon_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  next_weapon_vbox.add_child(next_weapon_image)

  next_weapon_label = Label.new()
  next_weapon_label.add_theme_font_size_override("font_size", 20)
  next_weapon_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
  next_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  next_weapon_vbox.add_child(next_weapon_label)

  # Right side: conditions + buy button
  weapon_right_vbox = VBoxContainer.new()
  weapon_right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
  weapon_right_vbox.add_theme_constant_override("separation", 8)
  weapon_right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  weapon_hbox.add_child(weapon_right_vbox)

  weapon_condition_vbox = VBoxContainer.new()
  weapon_condition_vbox.add_theme_constant_override("separation", 4)
  weapon_right_vbox.add_child(weapon_condition_vbox)

  weapon_buy_btn = Button.new()
  weapon_buy_btn.text = "다음 무기 구매"
  weapon_buy_btn.custom_minimum_size = Vector2(0, 60)
  weapon_buy_btn.add_theme_font_size_override("font_size", 26)
  weapon_buy_btn.pressed.connect(_on_weapon_buy_pressed)
  GameManager.style_button(weapon_buy_btn, Color(0.3, 0.75, 0.45))
  weapon_right_vbox.add_child(weapon_buy_btn)

func _on_weapon_buy_pressed() -> void:
  GameManager.play_confirm_click()
  if WeaponManager.purchase_next_weapon():
    GameManager.play_weapon_upgrade_sound()
    SaveManager.save_game()
    _animate_weapon_upgrade()
    update_money_display()

func _animate_weapon_upgrade() -> void:
  # Current weapon already updated in WeaponManager
  var current = WeaponManager.get_current_weapon()
  var next = WeaponManager.get_next_weapon()

  # Update current weapon card immediately
  weapon_image.texture = WeaponManager.get_weapon_texture()
  current_weapon_label.text = "%s\n대미지 %d" % [current.name, current.damage]

  # Slide current card: slight scale pop
  var tween = create_tween()
  weapon_image.scale = Vector2(1.3, 1.3)
  tween.tween_property(weapon_image, "scale", Vector2(1.0, 1.0), 0.2)

  # Update and animate next weapon card sliding in from right
  if not next.is_empty():
    var next_level = WeaponManager.current_weapon_level + 1
    if next_level < WeaponManager.weapon_textures.size():
      next_weapon_image.texture = WeaponManager.weapon_textures[next_level]
    next_weapon_label.text = "%s\n대미지 %d" % [next.name, next.damage]
    # Slide in from right
    next_weapon_panel.modulate = Color(1, 1, 1, 0)
    var slide_tween = create_tween()
    slide_tween.tween_property(next_weapon_panel, "modulate:a", 1.0, 0.3).set_delay(0.15)
  else:
    next_weapon_arrow.visible = false
    next_weapon_panel.visible = false

  _update_weapon_buy_button()

func update_weapon_display() -> void:
  _ensure_next_weapon_nodes()
  var current = WeaponManager.get_current_weapon()
  weapon_image.texture = WeaponManager.get_weapon_texture()
  current_weapon_label.text = "%s\n대미지 %d" % [current.name, current.damage]

  var next = WeaponManager.get_next_weapon()
  if next.is_empty():
    next_weapon_arrow.visible = false
    next_weapon_panel.visible = false
    weapon_right_vbox.visible = false
  else:
    next_weapon_arrow.visible = true
    next_weapon_panel.visible = true
    weapon_right_vbox.visible = true
    var next_level = WeaponManager.current_weapon_level + 1
    if next_level < WeaponManager.weapon_textures.size():
      next_weapon_image.texture = WeaponManager.weapon_textures[next_level]
    next_weapon_label.text = "%s\n대미지 %d" % [next.name, next.damage]
  _update_weapon_buy_button()

func _update_weapon_buy_button() -> void:
  var next = WeaponManager.get_next_weapon()
  if next.is_empty():
    weapon_right_vbox.visible = false
    _update_next_weapon_card_style(false)
    return
  var skill_req = WeaponManager.get_next_weapon_skill_requirement()
  var total_skill = GameManager.get_total_skill_level()
  var has_skill = WeaponManager.has_enough_skill_points()
  var has_money = GameManager.money >= next.price

  # Update condition indicators
  _update_weapon_conditions(has_skill, total_skill, skill_req, has_money, next.price)

  var btn_label = "%s 구매\n$%s" % [next.name, format_number(next.price)]
  weapon_buy_btn.text = btn_label
  if has_skill and has_money:
    weapon_buy_btn.disabled = false
    _update_next_weapon_card_style(true)
  else:
    weapon_buy_btn.disabled = true
    _update_next_weapon_card_style(false)

func _update_weapon_conditions(has_skill: bool, total_skill: int, skill_req: int, has_money: bool, price: int) -> void:
  for child in weapon_condition_vbox.get_children():
    child.queue_free()

  var skill_label = Label.new()
  skill_label.text = "스킬 %d/%d" % [total_skill, skill_req]
  skill_label.add_theme_font_size_override("font_size", 22)
  skill_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.55) if has_skill else Color(0.9, 0.3, 0.3))
  skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  weapon_condition_vbox.add_child(skill_label)

  var money_label_cond = Label.new()
  money_label_cond.text = "$%s" % format_number(price)
  money_label_cond.add_theme_font_size_override("font_size", 22)
  money_label_cond.add_theme_color_override("font_color", Color(0.3, 0.8, 0.55) if has_money else Color(0.9, 0.3, 0.3))
  money_label_cond.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  weapon_condition_vbox.add_child(money_label_cond)

func _update_next_weapon_card_style(can_buy: bool) -> void:
  if not next_weapon_panel:
    return
  var style = StyleBoxFlat.new()
  style.corner_radius_top_left = 10
  style.corner_radius_top_right = 10
  style.corner_radius_bottom_left = 10
  style.corner_radius_bottom_right = 10
  style.border_width_top = 2
  style.border_width_bottom = 2
  style.border_width_left = 2
  style.border_width_right = 2
  style.content_margin_left = 8
  style.content_margin_right = 8
  style.content_margin_top = 8
  style.content_margin_bottom = 8
  if can_buy:
    style.bg_color = Color(0.1, 0.18, 0.12)
    style.border_color = Color(0.25, 0.6, 0.35)
  else:
    style.bg_color = Color(0.15, 0.13, 0.1)
    style.border_color = Color(0.7, 0.55, 0.15)
  next_weapon_panel.add_theme_stylebox_override("panel", style)

# ── Skill Tree ──

func _get_current_level(skill_type: String) -> int:
  match skill_type:
    "grass_density":
      return GameManager.upgrade_grass_density
    "grass_quality":
      return GameManager.upgrade_grass_quality
    "grass_regen":
      return GameManager.upgrade_grass_regen
    "grass_reward":
      return GameManager.upgrade_grass_reward
    "monster_knockback":
      return GameManager.upgrade_monster_knockback
    "grass_drop":
      return GameManager.upgrade_grass_drop
  return 0

func build_skill_tree() -> void:
  for child in skill_tree_hbox.get_children():
    child.queue_free()

  for chain in SKILL_CHAINS:
    var col = _create_chain_column(chain)
    skill_tree_hbox.add_child(col)

func _create_chain_column(chain: Dictionary) -> VBoxContainer:
  var current_level = _get_current_level(chain.type)
  var max_level = chain.max_level
  var is_maxed = max_level >= 0 and current_level >= max_level
  var total_nodes = max_level if max_level >= 0 else current_level + 1

  var col = VBoxContainer.new()
  col.add_theme_constant_override("separation", 0)
  col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

  # Chain label
  var label = Label.new()
  label.text = chain.name
  label.add_theme_font_size_override("font_size", 22)
  label.add_theme_color_override("font_color", COLOR_LABEL)
  label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  col.add_child(label)

  # Nodes going downward
  for i in range(total_nodes):
    var level = i + 1
    var state: String

    if i < current_level:
      state = "completed"
    elif i == current_level and not is_maxed:
      state = "purchasable"
    else:
      state = "locked"

    # Connector line between nodes
    if i > 0:
      var connector = Label.new()
      connector.text = "|"
      connector.custom_minimum_size = Vector2(0, CONNECTOR_HEIGHT)
      connector.add_theme_font_size_override("font_size", 14)
      connector.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
      connector.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
      connector.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
      col.add_child(connector)

    # Center the node button
    var center = CenterContainer.new()
    var node_btn = _create_skill_node(chain.type, level, state)
    center.add_child(node_btn)
    col.add_child(center)

  return col

func _create_skill_node(skill_type: String, level: int, state: String) -> Button:
  var btn = Button.new()
  btn.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)

  # Create round StyleBoxFlat
  var style = StyleBoxFlat.new()
  style.corner_radius_top_left = int(NODE_SIZE / 2)
  style.corner_radius_top_right = int(NODE_SIZE / 2)
  style.corner_radius_bottom_left = int(NODE_SIZE / 2)
  style.corner_radius_bottom_right = int(NODE_SIZE / 2)
  style.content_margin_left = 4
  style.content_margin_right = 4
  style.content_margin_top = 4
  style.content_margin_bottom = 4

  match state:
    "completed":
      style.bg_color = COLOR_COMPLETED
      btn.text = str(level)
      btn.disabled = true
      btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.9))
    "purchasable":
      style.bg_color = COLOR_PURCHASABLE
      style.border_width_top = 3
      style.border_width_bottom = 3
      style.border_width_left = 3
      style.border_width_right = 3
      style.border_color = COLOR_PURCHASABLE_BORDER
      btn.text = str(level)
      btn.disabled = false
      btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
      btn.pressed.connect(_on_skill_node_pressed.bind(skill_type, level))
    "locked":
      style.bg_color = COLOR_LOCKED
      btn.text = "?"
      btn.disabled = true
      btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.55))

  btn.add_theme_stylebox_override("normal", style)
  btn.add_theme_stylebox_override("hover", style)
  btn.add_theme_stylebox_override("pressed", style)
  btn.add_theme_stylebox_override("disabled", style)
  btn.add_theme_font_size_override("font_size", 20)

  return btn

func _on_skill_node_pressed(skill_type: String, level: int) -> void:
  GameManager.play_button_click()
  selected_type = skill_type
  selected_level = level
  update_description()
  update_confirm_button()

# ── Selection / Confirm ──

func clear_selection() -> void:
  selected_type = ""
  selected_level = -1
  description_label.text = "강화할 항목을 선택하세요"
  confirm_btn.disabled = true
  confirm_btn.text = "업그레이드 하기"

func update_description() -> void:
  if selected_type.is_empty():
    description_label.text = "강화할 항목을 선택하세요"
    return
  _update_skill_description()

func _update_skill_description() -> void:
  var chain_info: Dictionary
  for chain in SKILL_CHAINS:
    if chain.type == selected_type:
      chain_info = chain
      break

  var current_level = _get_current_level(selected_type)
  var cost = GameManager.get_upgrade_cost(current_level)

  var stat_text = ""
  match selected_type:
    "grass_density":
      var current_val = GameManager.get_grass_min_spacing()
      var temp = GameManager.upgrade_grass_density
      GameManager.upgrade_grass_density += 1
      var next_val = GameManager.get_grass_min_spacing()
      GameManager.upgrade_grass_density = temp
      stat_text = "풀 간격: %.1f → %.1f" % [current_val, next_val]
    "grass_quality":
      stat_text = "등급 레벨: %d → %d" % [current_level, current_level + 1]
    "grass_regen":
      var current_val = GameManager.get_grass_regen_time(22.0)
      var temp = GameManager.upgrade_grass_regen
      GameManager.upgrade_grass_regen += 1
      var next_val = GameManager.get_grass_regen_time(22.0)
      GameManager.upgrade_grass_regen = temp
      stat_text = "재생 시간: %.1f초 → %.1f초" % [current_val, next_val]
    "grass_reward":
      var current_mult = GameManager.get_grass_reward_multiplier()
      var temp = GameManager.upgrade_grass_reward
      GameManager.upgrade_grass_reward += 1
      var next_mult = GameManager.get_grass_reward_multiplier()
      GameManager.upgrade_grass_reward = temp
      stat_text = "보상 배율: x%.1f → x%.1f" % [current_mult, next_mult]
    "monster_knockback":
      var current_kb = GameManager.get_monster_knockback_strength()
      var temp_kb = GameManager.upgrade_monster_knockback
      GameManager.upgrade_monster_knockback += 1
      var next_kb = GameManager.get_monster_knockback_strength()
      GameManager.upgrade_monster_knockback = temp_kb
      stat_text = "넉백: %.0f → %.0f" % [current_kb, next_kb]
    "grass_drop":
      var current_drop = GameManager.get_grass_drop_chance() * 100
      var temp_drop = GameManager.upgrade_grass_drop
      GameManager.upgrade_grass_drop += 1
      var next_drop = GameManager.get_grass_drop_chance() * 100
      GameManager.upgrade_grass_drop = temp_drop
      stat_text = "드롭률: %.0f%% → %.0f%%" % [current_drop, next_drop]

  description_label.text = "%s Lv.%d\n\n%s\n\n%s\n\n비용: $%s" % [chain_info.name, selected_level, chain_info.description, stat_text, format_number(cost)]

func update_confirm_button() -> void:
  if selected_type.is_empty():
    confirm_btn.disabled = true
    confirm_btn.text = "업그레이드 하기"
    return

  var current_level = _get_current_level(selected_type)
  var cost = GameManager.get_upgrade_cost(current_level)

  if GameManager.money < cost:
    confirm_btn.disabled = true
    confirm_btn.text = "돈 부족 ($%s)" % format_number(cost)
  else:
    confirm_btn.disabled = false
    confirm_btn.text = "업그레이드 하기 ($%s)" % format_number(cost)

func _on_confirm_pressed() -> void:
  GameManager.play_confirm_click()
  if selected_type.is_empty():
    return

  if GameManager.purchase_upgrade(selected_type):
    GameManager.play_skill_upgrade_sound()
    SaveManager.save_game()
    update_total_skill_label()
    build_skill_tree()
    update_weapon_display()
    update_money_display()
    clear_selection()

func _on_money_changed(_amount: int) -> void:
  update_money_display()
  if is_open:
    update_confirm_button()
    _update_weapon_buy_button()

func _on_upgrade_purchased(_type: String, _level: int) -> void:
  update_total_skill_label()
  build_skill_tree()
  update_weapon_display()
  update_money_display()

func update_money_display() -> void:
  money_label.text = "$%s" % format_number(GameManager.money)

func update_total_skill_label() -> void:
  total_skill_label.text = "스킬: %d" % GameManager.get_total_skill_level()

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
