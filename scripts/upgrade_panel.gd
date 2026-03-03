extends Control

signal panel_opened
signal panel_closed

@onready var panel: Panel = $Panel
@onready var padded_area: Control = $Panel/PaddedArea
@onready var description_panel: Panel = $Panel/PaddedArea/DescriptionPanel
@onready var description_label: Label = $Panel/PaddedArea/DescriptionPanel/DescriptionLabel
@onready var confirm_btn: Button = $Panel/PaddedArea/ConfirmBtn
@onready var close_btn: Button = $Panel/PaddedArea/CloseBtn
@onready var money_display = $Panel/PaddedArea/MoneyDisplay
@onready var skill_tree_scroll: ScrollContainer = $Panel/PaddedArea/SkillTreeScroll
@onready var skill_tree_container: Control = $Panel/PaddedArea/SkillTreeScroll/SkillTreeContainer
@onready var weapon_section: PanelContainer = $Panel/PaddedArea/WeaponSection
@onready var section_label: Label = $Panel/PaddedArea/SectionLabel

# Weapon nodes
@onready var weapon_image: TextureRect = $Panel/PaddedArea/WeaponSection/WeaponHBox/WeaponImage
@onready var weapon_info_vbox: VBoxContainer = $Panel/PaddedArea/WeaponSection/WeaponHBox/WeaponInfo

var is_open: bool = false

# Selection: "weapon" or skill type ("grass_density" etc), "" = none
var selected_type: String = ""
var selected_level: int = -1
var _selected_btn: Button = null  # Currently selected skill node button

var _desc_cost_node: HBoxContainer = null

# Grid layout constants
const NODE_MARGIN: float = 6.0
const NODE_INNER_PAD: float = 12.0
const NODE_CORNER_RADIUS: int = 8
const GROUP_GAP: float = 34.0
const GROUP_HEADER_H: float = 32.0
const PLACEHOLDER_ICON = preload("res://resources/images/skill/skill_temp.png")
const SKILL_ICONS = {
  "attack_speed": preload("res://resources/images/skill/attack_speed.png"),
  "crit_chance": preload("res://resources/images/skill/crit_chance.png"),
  "crit_damage": preload("res://resources/images/skill/crit_damage.png"),
  "monster_damage": preload("res://resources/images/skill/monster_damage.png"),
}
const LOCK_ICON = preload("res://resources/images/icon/lock.png")

# Group node colors [무기, 수집, 수확]
const GROUP_NODE_COLORS = [
  { # 무기 — 붉은 계열
    "completed": Color(0.55, 0.2, 0.2),
    "in_progress": Color(0.45, 0.2, 0.22),
    "in_progress_border": Color(0.7, 0.4, 0.35),
    "purchasable": Color(0.22, 0.15, 0.15),
    "purchasable_border": Color(0.45, 0.2, 0.18),
    "locked": Color(0.18, 0.13, 0.13),
    "locked_border": Color(0.4, 0.18, 0.16),
  },
  { # 수집 — 푸른 계열
    "completed": Color(0.2, 0.35, 0.55),
    "in_progress": Color(0.2, 0.32, 0.48),
    "in_progress_border": Color(0.4, 0.6, 0.8),
    "purchasable": Color(0.15, 0.17, 0.25),
    "purchasable_border": Color(0.18, 0.3, 0.45),
    "locked": Color(0.13, 0.14, 0.2),
    "locked_border": Color(0.16, 0.28, 0.42),
  },
  { # 수확 — 초록 계열
    "completed": Color(0.2, 0.5, 0.25),
    "in_progress": Color(0.2, 0.4, 0.25),
    "in_progress_border": Color(0.4, 0.65, 0.4),
    "purchasable": Color(0.15, 0.2, 0.15),
    "purchasable_border": Color(0.22, 0.4, 0.18),
    "locked": Color(0.13, 0.17, 0.13),
    "locked_border": Color(0.2, 0.38, 0.16),
  },
]
const GROUP_LINE_COLORS_MET = [
  Color(0.8, 0.35, 0.3, 0.8),     # 무기 — 밝은 붉은색
  Color(0.3, 0.55, 0.85, 0.8),    # 수집 — 밝은 푸른색
  Color(0.4, 0.75, 0.35, 0.8),    # 수확 — 밝은 초록색
]
const GROUP_LINE_COLORS_UNMET = [
  Color(0.65, 0.25, 0.25, 0.45),  # 무기 — 어두운 붉은색
  Color(0.25, 0.45, 0.65, 0.45),  # 수집 — 어두운 푸른색
  Color(0.35, 0.6, 0.25, 0.45),   # 수확 — 어두운 초록색
]

# Grid node positions for connection lines: skill_type -> Vector2 (center of node)
var _grid_node_centers: Dictionary = {}

func _ready() -> void:
  panel.visible = false
  close_btn.pressed.connect(_on_close_pressed)
  confirm_btn.pressed.connect(_on_confirm_pressed)

  GameManager.money_changed.connect(_on_money_changed)
  GameManager.upgrade_purchased.connect(_on_upgrade_purchased)
  WeaponManager.weapon_changed.connect(_on_weapon_changed)

  # Button styles
  close_btn.icon = preload("res://resources/images/icon/go_back.png")
  close_btn.expand_icon = true
  GameManager.style_button(close_btn, "muted")
  _position_close_btn()
  GameManager.style_button(confirm_btn)
  _position_bottom_section()
  _apply_side_padding()

  update_money_display()
  update_weapon_display()

  build_skill_tree()
  clear_selection()
func set_toggle_button_visible(_should_show: bool) -> void:
  pass

func open_panel() -> void:
  if is_open:
    return
  is_open = true
  panel.visible = true
  update_money_display()
  update_weapon_display()

  build_skill_tree()
  clear_selection()
  panel_opened.emit()

func _on_close_pressed() -> void:
  GameManager.play_button_click()
  is_open = false
  panel.visible = false
  panel_closed.emit()

func _on_other_panel_opened() -> void:
  pass

func _on_other_panel_closed() -> void:
  pass

# ── Weapon ──

func _on_weapon_changed(_level: int) -> void:
  update_weapon_display()
  if is_open:
    build_skill_tree()

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
  weapon_buy_btn.custom_minimum_size = Vector2(0, 80)
  weapon_buy_btn.add_theme_font_size_override("font_size", 34)
  weapon_buy_btn.pressed.connect(_on_weapon_buy_pressed)
  GameManager.style_button(weapon_buy_btn)
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

  weapon_buy_btn.text = "%s 구매" % next.name
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
  skill_label.add_theme_font_size_override("font_size", 34)
  skill_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.55) if has_skill else Color(0.9, 0.3, 0.3))
  skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  weapon_condition_vbox.add_child(skill_label)

  var money_color = Color(0.3, 0.8, 0.55) if has_money else Color(0.9, 0.3, 0.3)
  var money_cond_hbox = GameManager.create_coin_label(GameManager.format_number(price), 34, money_color, 0, true)
  weapon_condition_vbox.add_child(money_cond_hbox)

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

# ── Skill Tree (3-Group Grid) ──

func _get_current_level(skill_type: String) -> int:
  return GameManager.get_upgrade_level(skill_type)

func _get_skill_chain(skill_type: String) -> Dictionary:
  return GameManager.get_skill_def(skill_type)

func _get_node_state(skill_type: String) -> String:
  var current_level = _get_current_level(skill_type)
  var chain = _get_skill_chain(skill_type)
  var max_level = chain.max_level
  var is_maxed = max_level >= 0 and current_level >= max_level

  if is_maxed:
    return "completed"

  var has_started = current_level > 0 or GameManager.get_upgrade_sub_level(skill_type) > 0
  var next_level = current_level + 1
  var prereq = GameManager.check_skill_prereqs(skill_type, next_level)

  if not prereq.met:
    if has_started:
      return "in_progress"  # 찍은 적 있지만 조건 미충족 → 비활성화
    return "locked"  # 한 번도 안 찍음 → 잠금

  if has_started:
    return "in_progress"
  return "purchasable"

func build_skill_tree() -> void:
  for child in skill_tree_container.get_children():
    skill_tree_container.remove_child(child)
    child.queue_free()
  _grid_node_centers.clear()

  var container_width = skill_tree_container.size.x
  if container_width <= 0:
    container_width = skill_tree_container.get_parent().size.x
  if container_width <= 0:
    container_width = panel.size.x - 80

  var group_count = GameManager.SKILL_GROUPS.size()
  var group_width = (container_width - GROUP_GAP * (group_count - 1)) / float(group_count)
  var max_group_height: float = 0.0

  for group_idx in range(group_count):
    var group = GameManager.SKILL_GROUPS[group_idx]
    var group_name: String = group["name"]
    var skills: Array = group["skills"]
    var columns: int = group["columns"]
    var group_x = group_idx * (group_width + GROUP_GAP)

    # Group header
    var header = Label.new()
    header.text = group_name
    header.add_theme_font_size_override("font_size", 22)
    header.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
    header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header.position = Vector2(group_x, 0)
    header.size = Vector2(group_width, GROUP_HEADER_H)
    skill_tree_container.add_child(header)

    # Node size: fit 2 columns with padding, then shrink a bit
    var node_size = (group_width - NODE_MARGIN * (columns + 1)) / float(columns) - NODE_INNER_PAD
    # Row gap = same as horizontal gap between nodes
    var row_gap = NODE_MARGIN + NODE_INNER_PAD * 2

    # Row 0: first skill centered, row 1+: remaining skills in 2-column grid
    var root_type = skills[0]
    var root_x = group_x + (group_width - node_size) / 2.0
    var root_y = GROUP_HEADER_H

    var root_state = _get_node_state(root_type)
    var root_node = _create_skill_node(root_type, root_state, node_size, group_idx)
    root_node.position = Vector2(root_x, root_y)
    root_node.size = Vector2(node_size, node_size)
    root_node.z_index = 2
    skill_tree_container.add_child(root_node)
    _grid_node_centers[root_type] = Vector2(root_x + node_size / 2.0, root_y + node_size / 2.0)

    # Remaining skills in 2-column rows
    var remaining = skills.slice(1)
    var row_count = ceili(remaining.size() / float(columns))
    for row in range(row_count):
      var skills_in_row: int = mini(columns, remaining.size() - row * columns)
      for col in range(skills_in_row):
        var idx = row * columns + col
        var skill_type = remaining[idx]
        var x: float
        if skills_in_row == 1:
          x = group_x + (group_width - node_size) / 2.0
        else:
          x = group_x + NODE_MARGIN + col * (node_size + NODE_MARGIN + NODE_INNER_PAD * 2)
        var y = GROUP_HEADER_H + (row + 1) * (node_size + row_gap)

        var state = _get_node_state(skill_type)
        var node = _create_skill_node(skill_type, state, node_size, group_idx)
        node.position = Vector2(x, y)
        node.size = Vector2(node_size, node_size)
        node.z_index = 2
        skill_tree_container.add_child(node)
        _grid_node_centers[skill_type] = Vector2(x + node_size / 2.0, y + node_size / 2.0)

    # Connection lines based on SKILL_PREREQS (orthogonal L-shape)
    for skill_type in skills:
      var key = "%s:1" % skill_type
      if not GameManager.SKILL_PREREQS.has(key):
        continue
      var parent_type = GameManager.SKILL_PREREQS[key][0].type
      if not _grid_node_centers.has(parent_type) or not _grid_node_centers.has(skill_type):
        continue
      var from_center = _grid_node_centers[parent_type]
      var to_center = _grid_node_centers[skill_type]
      var is_met = _get_current_level(parent_type) >= 1 or GameManager.get_upgrade_sub_level(parent_type) > 0
      var line_color = GROUP_LINE_COLORS_MET[group_idx] if is_met else GROUP_LINE_COLORS_UNMET[group_idx]

      var dx = to_center.x - from_center.x
      var line = Line2D.new()
      line.z_index = 1
      line.width = 4.5
      line.antialiased = true
      line.default_color = line_color

      if abs(dx) < 2.0:
        # Vertically aligned — straight line bottom→top
        var start_pt = Vector2(from_center.x, from_center.y + node_size / 2.0)
        var end_pt = Vector2(to_center.x, to_center.y - node_size / 2.0)
        if end_pt.y <= start_pt.y:
          continue
        line.add_point(start_pt)
        line.add_point(end_pt)
      else:
        # L-shape: parent side → horizontal → 90° down → child top
        var start_pt: Vector2
        if dx < 0:
          start_pt = Vector2(from_center.x - node_size / 2.0, from_center.y)
        else:
          start_pt = Vector2(from_center.x + node_size / 2.0, from_center.y)
        var corner_pt = Vector2(to_center.x, start_pt.y)
        var end_pt = Vector2(to_center.x, to_center.y - node_size / 2.0)
        line.add_point(start_pt)
        line.add_point(corner_pt)
        line.add_point(end_pt)

      skill_tree_container.add_child(line)

    var total_rows = 1 + row_count
    var group_height = GROUP_HEADER_H + total_rows * (node_size + row_gap) - row_gap
    max_group_height = max(max_group_height, group_height)

  skill_tree_container.custom_minimum_size = Vector2(0, max_group_height + 20)

func _create_skill_node(skill_type: String, state: String, node_size: float, group_idx: int) -> Button:
  var btn = Button.new()
  btn.custom_minimum_size = Vector2(node_size, node_size)
  btn.clip_text = true

  var style = StyleBoxFlat.new()
  style.corner_radius_top_left = NODE_CORNER_RADIUS
  style.corner_radius_top_right = NODE_CORNER_RADIUS
  style.corner_radius_bottom_left = NODE_CORNER_RADIUS
  style.corner_radius_bottom_right = NODE_CORNER_RADIUS
  style.content_margin_left = 4
  style.content_margin_right = 4
  style.content_margin_top = 4
  style.content_margin_bottom = 4

  var current_level = _get_current_level(skill_type)
  var chain = _get_skill_chain(skill_type)
  var max_level = chain.max_level
  var sub_level = GameManager.get_upgrade_sub_level(skill_type)
  var sub_max = GameManager.get_skill_sub_max(skill_type)
  var next_level = current_level + 1

  # Apply style based on state (group-colored)
  var gc = GROUP_NODE_COLORS[group_idx]
  var is_sub_complete = sub_level > 0 and sub_level >= sub_max
  var is_blocked = not GameManager.check_skill_prereqs(skill_type, next_level).met
  var is_dim = is_sub_complete or is_blocked
  match state:
    "completed":
      style.bg_color = gc.completed
      btn.disabled = false
      btn.pressed.connect(_on_skill_node_pressed.bind(btn, skill_type, max_level))
    "in_progress":
      if is_dim:
        style.bg_color = gc.purchasable
        style.border_width_top = 2
        style.border_width_bottom = 2
        style.border_width_left = 2
        style.border_width_right = 2
        style.border_color = gc.purchasable_border
      else:
        style.bg_color = gc.in_progress
        style.border_width_top = 2
        style.border_width_bottom = 2
        style.border_width_left = 2
        style.border_width_right = 2
        style.border_color = gc.in_progress_border
      btn.disabled = false
      btn.pressed.connect(_on_skill_node_pressed.bind(btn, skill_type, next_level))
    "purchasable":
      style.bg_color = gc.in_progress
      style.border_width_top = 2
      style.border_width_bottom = 2
      style.border_width_left = 2
      style.border_width_right = 2
      style.border_color = gc.in_progress_border
      btn.disabled = false
      btn.pressed.connect(_on_skill_node_pressed.bind(btn, skill_type, next_level))
    "locked":
      style.bg_color = gc.locked
      style.border_width_top = 2
      style.border_width_bottom = 2
      style.border_width_left = 2
      style.border_width_right = 2
      style.border_color = gc.locked_border
      btn.disabled = true

  btn.add_theme_stylebox_override("normal", style)
  btn.add_theme_stylebox_override("hover", style)
  btn.add_theme_stylebox_override("pressed", style)
  btn.add_theme_stylebox_override("disabled", style)
  btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
  btn.set_meta("base_style", style)
  btn.set_meta("skill_type", skill_type)

  var is_locked = state == "locked"
  var is_active = (state == "completed" or state == "purchasable"
    or (state == "in_progress" and not is_dim))

  # Skill icon (center) — hidden for locked states
  if not is_locked:
    var icon_rect = TextureRect.new()
    icon_rect.texture = SKILL_ICONS.get(skill_type, PLACEHOLDER_ICON)
    icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon_rect.anchors_preset = Control.PRESET_FULL_RECT
    icon_rect.anchor_right = 1.0
    icon_rect.anchor_bottom = 1.0
    icon_rect.offset_left = 2
    icon_rect.offset_top = 2
    icon_rect.offset_right = -2
    icon_rect.offset_bottom = -2
    icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if not is_active:
      icon_rect.modulate = Color(0.5, 0.5, 0.5)
    btn.add_child(icon_rect)

  # Lock icon (center) — for locked/prereq_locked
  if is_locked:
    var lock_size = node_size * 1.35
    var center_container = CenterContainer.new()
    center_container.anchors_preset = Control.PRESET_FULL_RECT
    center_container.anchor_right = 1.0
    center_container.anchor_bottom = 1.0
    center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
    btn.add_child(center_container)
    var lock_rect = TextureRect.new()
    lock_rect.texture = LOCK_ICON
    lock_rect.expand_mode = TextureRect.EXPAND_FIT_HEIGHT
    lock_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    lock_rect.custom_minimum_size = Vector2(lock_size, lock_size)
    lock_rect.modulate = Color(0.45, 0.45, 0.5)
    lock_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    center_container.add_child(lock_rect)

  var label_color = Color(0.5, 0.5, 0.55) if not is_active else Color.WHITE

  # Skill name label (top)
  var name_label = Label.new()
  name_label.text = chain.short_name
  name_label.add_theme_font_size_override("font_size", 16)
  name_label.add_theme_color_override("font_color", label_color)
  name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  name_label.add_theme_constant_override("outline_size", 5)
  name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
  name_label.add_theme_constant_override("shadow_offset_x", 2)
  name_label.add_theme_constant_override("shadow_offset_y", 2)
  name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  name_label.anchors_preset = Control.PRESET_TOP_WIDE
  name_label.anchor_right = 1.0
  name_label.offset_top = 2
  name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  btn.add_child(name_label)

  # Bottom bar — level & progress info
  var bar_h: float = 28.0
  var bar = ColorRect.new()
  bar.color = Color(0, 0, 0, 0.4)
  bar.anchors_preset = Control.PRESET_BOTTOM_WIDE
  bar.anchor_top = 1.0
  bar.anchor_right = 1.0
  bar.anchor_bottom = 1.0
  bar.offset_top = -bar_h
  bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
  btn.add_child(bar)

  if is_locked:
    var req_label = Label.new()
    var required_total = GameManager.SKILL_REQUIRED_TOTAL.get(skill_type, 0)
    req_label.text = "스킬 %d 필요" % required_total if required_total > 0 else "잠김"
    req_label.add_theme_font_size_override("font_size", 14)
    req_label.add_theme_color_override("font_color", Color(0.55, 0.5, 0.5))
    req_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    req_label.add_theme_constant_override("outline_size", 3)
    req_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    req_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    req_label.anchors_preset = Control.PRESET_FULL_RECT
    req_label.anchor_right = 1.0
    req_label.anchor_bottom = 1.0
    req_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bar.add_child(req_label)
  else:
    # Level label (left side)
    var level_label = Label.new()
    level_label.text = "Lv.%d" % current_level
    level_label.add_theme_font_size_override("font_size", 16)
    level_label.add_theme_color_override("font_color", label_color)
    level_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    level_label.add_theme_constant_override("outline_size", 4)
    level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    level_label.anchors_preset = Control.PRESET_LEFT_WIDE
    level_label.anchor_bottom = 1.0
    level_label.offset_left = 6
    level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bar.add_child(level_label)

    # Sub-level / MAX (right side)
    var sub_label = Label.new()
    if state == "completed":
      sub_label.text = "MAX"
      sub_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
    elif sub_level > 0:
      sub_label.text = "%d/%d" % [sub_level, sub_max]
      sub_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
    else:
      sub_label.text = "0/%d" % sub_max
      sub_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
    sub_label.add_theme_font_size_override("font_size", 14)
    sub_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    sub_label.add_theme_constant_override("outline_size", 3)
    sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    sub_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    sub_label.anchors_preset = Control.PRESET_RIGHT_WIDE
    sub_label.anchor_left = 1.0
    sub_label.anchor_bottom = 1.0
    sub_label.offset_left = -50
    sub_label.offset_right = -6
    sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bar.add_child(sub_label)

  return btn

func _on_skill_node_pressed(btn: Button, skill_type: String, level: int) -> void:
  GameManager.play_button_click()
  _deselect_btn()
  selected_type = skill_type
  selected_level = level
  _selected_btn = btn
  _apply_select_border(btn)
  update_description()
  update_confirm_button()

func _reselect_current() -> void:
  # build_skill_tree() 후 선택된 스킬의 새 버튼을 찾아 선택 UI 복원
  _selected_btn = null
  if selected_type.is_empty():
    return
  for child in skill_tree_container.get_children():
    if child is Button and child.has_meta("skill_type") and child.get_meta("skill_type") == selected_type:
      _selected_btn = child
      _apply_select_border(child)
      break

func _apply_select_border(btn: Button) -> void:
  var base: StyleBoxFlat = btn.get_meta("base_style")
  var sel = base.duplicate()
  sel.border_width_top = 6
  sel.border_width_bottom = 6
  sel.border_width_left = 6
  sel.border_width_right = 6
  sel.border_color = Color(1.0, 1.0, 1.0)
  sel.bg_color = base.bg_color.lightened(0.35)
  btn.add_theme_stylebox_override("normal", sel)
  btn.add_theme_stylebox_override("hover", sel)
  btn.add_theme_stylebox_override("pressed", sel)

func _deselect_btn() -> void:
  if _selected_btn and is_instance_valid(_selected_btn):
    var base: StyleBoxFlat = _selected_btn.get_meta("base_style")
    _selected_btn.add_theme_stylebox_override("normal", base)
    _selected_btn.add_theme_stylebox_override("hover", base)
    _selected_btn.add_theme_stylebox_override("pressed", base)
  _selected_btn = null

# ── Selection / Confirm ──

func clear_selection() -> void:
  _deselect_btn()
  selected_type = ""
  selected_level = -1
  description_label.text = "강화할 항목을 선택하세요"
  _clear_description_cost()
  confirm_btn.disabled = true
  confirm_btn.text = "업그레이드 하기"

func update_description() -> void:
  if selected_type.is_empty():
    description_label.text = "강화할 항목을 선택하세요"
    return
  _update_skill_description()

func _update_skill_description() -> void:
  var chain_info = _get_skill_chain(selected_type)
  if chain_info.is_empty():
    return

  var current_level = _get_current_level(selected_type)
  var cost = GameManager.get_upgrade_cost(current_level, selected_type)

  var stat_text = ""
  match selected_type:
    "grass_density":
      var cur_grass = _calc_grass_per_chunk(current_level)
      var next_grass = _calc_grass_per_chunk(current_level + 1)
      stat_text = "청크당 풀: %d → %d" % [cur_grass, next_grass]
    "grass_quality":
      stat_text = "등급 레벨: %d → %d" % [current_level, current_level + 1]
    "grass_regen":
      var current_val = GameManager.get_grass_regen_time(22.0)
      var temp = GameManager.upgrade_levels["grass_regen"]
      GameManager.upgrade_levels["grass_regen"] += 1
      var next_val = GameManager.get_grass_regen_time(22.0)
      GameManager.upgrade_levels["grass_regen"] = temp
      stat_text = "재생 시간: %.1f초 → %.1f초" % [current_val, next_val]
    "grass_reward":
      var current_mult = GameManager.get_grass_reward_multiplier()
      var temp = GameManager.upgrade_levels["grass_reward"]
      GameManager.upgrade_levels["grass_reward"] += 1
      var next_mult = GameManager.get_grass_reward_multiplier()
      GameManager.upgrade_levels["grass_reward"] = temp
      stat_text = "보상 배율: x%.1f → x%.1f" % [current_mult, next_mult]
    "penalty_reduce":
      var current_pr = GameManager.get_part_penalty_mult() * 100
      var temp_pr = GameManager.upgrade_levels["penalty_reduce"]
      GameManager.upgrade_levels["penalty_reduce"] += 1
      var next_pr = GameManager.get_part_penalty_mult() * 100
      GameManager.upgrade_levels["penalty_reduce"] = temp_pr
      stat_text = "패널티: %.0f%% → %.0f%%" % [current_pr, next_pr]
    "grass_drop":
      var current_drop = GameManager.get_grass_drop_chance() * 100
      var temp_drop = GameManager.upgrade_levels["grass_drop"]
      GameManager.upgrade_levels["grass_drop"] += 1
      var next_drop = GameManager.get_grass_drop_chance() * 100
      GameManager.upgrade_levels["grass_drop"] = temp_drop
      stat_text = "드롭률: %.0f%% → %.0f%%" % [current_drop, next_drop]
    "golden_chance":
      var current_gc = GameManager.get_golden_grass_chance() * 100
      var temp_gc = GameManager.upgrade_levels["golden_chance"]
      GameManager.upgrade_levels["golden_chance"] += 1
      var next_gc = GameManager.get_golden_grass_chance() * 100
      GameManager.upgrade_levels["golden_chance"] = temp_gc
      stat_text = "황금풀 확률: %.2f%% → %.2f%%" % [current_gc, next_gc]

  # Build prereq text
  var prereq_text = ""
  var prereq_result = GameManager.check_skill_prereqs(selected_type, selected_level)
  if not prereq_result.met:
    prereq_text = "\n[필요 조건]"
    for m in prereq_result.missing:
      if m.type == "_total":
        prereq_text += "\n  전체 스킬 Lv.%d (현재: %d)" % [m.level, m.current]
      else:
        var req_name = GameManager.get_skill_def(m.type).get("name", m.type)
        prereq_text += "\n  %s Lv.%d (현재: Lv.%d)" % [req_name, m.level, m.current]

  var sub_level = GameManager.get_upgrade_sub_level(selected_type)
  var title_text = "%s Lv.%d → Lv.%d" % [chain_info.name, current_level, selected_level]
  if sub_level > 0:
    title_text += " (%d/%d)" % [sub_level, GameManager.get_skill_sub_max(selected_type)]
  description_label.text = "%s\n\n%s\n%s%s" % [title_text, chain_info.description, stat_text, prereq_text]

  # Add cost with coin icon below description
  _update_description_cost(cost)

func _update_description_cost(cost: int) -> void:
  if _desc_cost_node:
    _desc_cost_node.queue_free()
    _desc_cost_node = null

  var hbox = HBoxContainer.new()
  hbox.add_theme_constant_override("separation", 6)
  hbox.anchor_left = 0.0
  hbox.anchor_right = 0.0
  hbox.anchor_top = 1.0
  hbox.anchor_bottom = 1.0
  hbox.offset_left = 16
  hbox.offset_top = -52
  hbox.offset_right = 400
  hbox.offset_bottom = -10

  var cost_prefix = Label.new()
  cost_prefix.text = "비용: "
  cost_prefix.add_theme_font_size_override("font_size", 34)
  cost_prefix.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
  hbox.add_child(cost_prefix)

  var coin_hbox = GameManager.create_coin_label(GameManager.format_number(cost), 34, Color(1, 0.9, 0.3))
  hbox.add_child(coin_hbox)

  description_panel.add_child(hbox)
  _desc_cost_node = hbox

func _clear_description_cost() -> void:
  if _desc_cost_node:
    _desc_cost_node.queue_free()
    _desc_cost_node = null

func update_confirm_button() -> void:
  if selected_type.is_empty():
    confirm_btn.disabled = true
    confirm_btn.text = "업그레이드 하기"
    return

  var current_level = _get_current_level(selected_type)
  var next_level = current_level + 1
  var cost = GameManager.get_upgrade_cost(current_level, selected_type)

  # Check if this is the actual next level and prereqs are met
  if selected_level != next_level:
    confirm_btn.disabled = true
    if selected_level <= current_level:
      confirm_btn.text = "이미 습득함"
    else:
      confirm_btn.text = "이전 레벨 필요"
    return

  var prereq_result = GameManager.check_skill_prereqs(selected_type, next_level)
  if not prereq_result.met:
    confirm_btn.disabled = true
    confirm_btn.text = "조건 미충족"
    return

  if GameManager.money < cost:
    confirm_btn.disabled = true
    confirm_btn.text = "돈 부족"
  else:
    confirm_btn.disabled = false
    var c_sub = GameManager.get_upgrade_sub_level(selected_type)
    if c_sub > 0:
      confirm_btn.text = "업그레이드 (%d/%d)" % [c_sub, GameManager.get_skill_sub_max(selected_type)]
    else:
      confirm_btn.text = "업그레이드 하기"

func _on_confirm_pressed() -> void:
  GameManager.play_confirm_click()
  if selected_type.is_empty():
    return

  var prev_sub = GameManager.get_upgrade_sub_level(selected_type)
  if GameManager.purchase_upgrade(selected_type):
    GameManager.play_skill_upgrade_sound()
    SaveManager.save_game()

    build_skill_tree()
    _reselect_current()
    update_weapon_display()
    update_money_display()
    update_description()
    update_confirm_button()

func _on_money_changed(_amount: int) -> void:
  update_money_display()
  if is_open:
    update_confirm_button()
    _update_weapon_buy_button()

func _on_upgrade_purchased(_type: String, _level: int) -> void:
  build_skill_tree()
  _reselect_current()
  update_weapon_display()
  update_money_display()

func update_money_display() -> void:
  money_display.update_display()


func _apply_side_padding() -> void:
  pass  # PaddedArea handles padding

func _position_close_btn() -> void:
  pass  # Positioned in tscn within PaddedArea

func _position_bottom_section() -> void:
  var padded_height = padded_area.size.y
  var btn_height = 120.0
  var gap = 20.0
  var desc_height = 280.0
  # ConfirmBtn at bottom of PaddedArea
  confirm_btn.anchor_left = 0.0
  confirm_btn.anchor_right = 1.0
  confirm_btn.anchor_top = 0.0
  confirm_btn.anchor_bottom = 0.0
  confirm_btn.offset_bottom = padded_height
  confirm_btn.offset_top = padded_height - btn_height
  # DescriptionPanel above ConfirmBtn
  description_panel.anchor_left = 0.0
  description_panel.anchor_right = 1.0
  description_panel.anchor_top = 0.0
  description_panel.anchor_bottom = 0.0
  description_panel.offset_bottom = confirm_btn.offset_top - gap
  description_panel.offset_top = description_panel.offset_bottom - desc_height
  # SkillTreeScroll ends before DescriptionPanel
  skill_tree_scroll.offset_bottom = description_panel.offset_top - gap

func _calc_grass_per_chunk(density_level: int) -> int:
  var grass_spawner = get_tree().get_first_node_in_group("grass_spawner")
  var grid_cell = 115.0
  var chunk = 400.0
  if grass_spawner:
    grid_cell = grass_spawner.grid_cell_size
    chunk = grass_spawner.chunk_size
  var cell_size = grid_cell * 2.5 / (1.0 + density_level * 0.525)
  var cells_per_side = int(chunk / cell_size)
  return cells_per_side * cells_per_side
