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
@onready var weapon_name_label: Label = $Panel/WeaponSection/WeaponHBox/WeaponInfo/WeaponNameLabel
@onready var weapon_stats_label: Label = $Panel/WeaponSection/WeaponHBox/WeaponInfo/WeaponStatsLabel
@onready var weapon_upgrade_btn: Button = $Panel/WeaponSection/WeaponHBox/WeaponInfo/WeaponUpgradeBtn

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

  weapon_upgrade_btn.pressed.connect(_on_weapon_select_pressed)

  GameManager.money_changed.connect(_on_money_changed)
  GameManager.upgrade_purchased.connect(_on_upgrade_purchased)
  WeaponManager.weapon_changed.connect(_on_weapon_changed)

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

func _on_weapon_select_pressed() -> void:
  GameManager.play_button_click()
  selected_type = "weapon"
  selected_level = -1
  update_description()
  update_confirm_button()

func _on_weapon_changed(_level: int) -> void:
  update_weapon_display()
  if selected_type == "weapon":
    update_description()
    update_confirm_button()

func update_weapon_display() -> void:
  var current = WeaponManager.get_current_weapon()
  weapon_image.texture = WeaponManager.get_weapon_texture()
  weapon_name_label.text = current.name
  weapon_stats_label.text = "대미지: %d" % current.damage

  var next = WeaponManager.get_next_weapon()
  if next.is_empty():
    weapon_upgrade_btn.text = "최고 단계"
    weapon_upgrade_btn.disabled = true
  else:
    var skill_req = WeaponManager.get_next_weapon_skill_requirement()
    var total_skill = GameManager.get_total_skill_level()
    if not WeaponManager.has_enough_skill_points():
      weapon_upgrade_btn.text = "%s  $%s\n(스킬 %d/%d 필요)" % [next.name, format_number(next.price), total_skill, skill_req]
    else:
      weapon_upgrade_btn.text = "다음 무기: %s  $%s" % [next.name, format_number(next.price)]
    weapon_upgrade_btn.disabled = false

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
  confirm_btn.text = "구매"

func update_description() -> void:
  if selected_type.is_empty():
    description_label.text = "강화할 항목을 선택하세요"
    return

  if selected_type == "weapon":
    _update_weapon_description()
  else:
    _update_skill_description()

func _update_weapon_description() -> void:
  var next = WeaponManager.get_next_weapon()
  if next.is_empty():
    description_label.text = "무기\n\n최고 단계에 도달했습니다."
    return

  var current = WeaponManager.get_current_weapon()
  var skill_req = WeaponManager.get_next_weapon_skill_requirement()
  var total_skill = GameManager.get_total_skill_level()

  var text = "무기 업그레이드\n\n%s → %s\n대미지: %d → %d\n\n비용: $%s" % [
    current.name, next.name, current.damage, next.damage, format_number(next.price)
  ]
  if not WeaponManager.has_enough_skill_points():
    text += "\n\n스킬 부족 (%d/%d)" % [total_skill, skill_req]
  description_label.text = text

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

  description_label.text = "%s Lv.%d\n\n%s\n\n%s\n\n비용: $%s" % [chain_info.name, selected_level, chain_info.description, stat_text, format_number(cost)]

func update_confirm_button() -> void:
  if selected_type.is_empty():
    confirm_btn.disabled = true
    confirm_btn.text = "구매"
    return

  if selected_type == "weapon":
    _update_weapon_confirm()
  else:
    _update_skill_confirm()

func _update_weapon_confirm() -> void:
  var next = WeaponManager.get_next_weapon()
  if next.is_empty():
    confirm_btn.disabled = true
    confirm_btn.text = "최대 레벨"
    return

  if not WeaponManager.has_enough_skill_points():
    confirm_btn.disabled = true
    confirm_btn.text = "스킬 부족"
  elif not WeaponManager.can_upgrade():
    confirm_btn.disabled = true
    confirm_btn.text = "돈 부족 ($%s)" % format_number(next.price)
  else:
    confirm_btn.disabled = false
    confirm_btn.text = "구매 ($%s)" % format_number(next.price)

func _update_skill_confirm() -> void:
  var current_level = _get_current_level(selected_type)
  var cost = GameManager.get_upgrade_cost(current_level)

  if GameManager.money < cost:
    confirm_btn.disabled = true
    confirm_btn.text = "돈 부족 ($%s)" % format_number(cost)
  else:
    confirm_btn.disabled = false
    confirm_btn.text = "구매 ($%s)" % format_number(cost)

func _on_confirm_pressed() -> void:
  GameManager.play_confirm_click()
  if selected_type.is_empty():
    return

  if selected_type == "weapon":
    if WeaponManager.purchase_next_weapon():
      GameManager.play_weapon_upgrade_sound()
      SaveManager.save_game()
      update_weapon_display()
      update_money_display()
      var tween = create_tween()
      weapon_image.scale = Vector2(1.3, 1.3)
      tween.tween_property(weapon_image, "scale", Vector2(1.0, 1.0), 0.2)
      clear_selection()
  else:
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
    update_weapon_display()

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
