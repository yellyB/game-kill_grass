extends Control

signal panel_opened
signal panel_closed

@onready var panel: Panel = $Panel
@onready var total_skill_label: Label = $Panel/TotalSkillLabel
@onready var description_panel: Panel = $Panel/DescriptionPanel
@onready var description_label: Label = $Panel/DescriptionPanel/DescriptionLabel
@onready var confirm_btn: Button = $Panel/ConfirmBtn
@onready var close_btn: Button = $Panel/CloseBtn
@onready var money_display = $Panel/MoneyDisplay
@onready var skill_tree_scroll: ScrollContainer = $Panel/SkillTreeScroll
@onready var skill_tree_container: Control = $Panel/SkillTreeScroll/SkillTreeContainer
@onready var weapon_section: PanelContainer = $Panel/WeaponSection
@onready var section_label: Label = $Panel/SectionLabel

# Weapon nodes
@onready var weapon_image: TextureRect = $Panel/WeaponSection/WeaponHBox/WeaponImage
@onready var weapon_info_vbox: VBoxContainer = $Panel/WeaponSection/WeaponHBox/WeaponInfo

var is_open: bool = false

# Selection: "weapon" or skill type ("grass_density" etc), "" = none
var selected_type: String = ""
var selected_level: int = -1

# Column order computed at runtime from GameManager.SKILL_DEFS + SKILL_PREREQS
var _skill_columns: Array = []    # skill types only (no "weapon")
var _display_columns: Array = []  # skill types + "weapon" inserted in the middle

# Computed at runtime from GameManager.SKILL_PREREQS
var _skill_connections: Array = []
var _skill_node_steps: Dictionary = {}  # type -> { level -> step }

# Node visual settings
const NODE_SIZE: int = 52
const NODE_GAP: int = 24
const COL_HEADER_HEIGHT: float = 45.0

# Colors
const COLOR_COMPLETED = Color(0.2, 0.55, 0.3)
const COLOR_PURCHASABLE = Color(0.85, 0.7, 0.15)
const COLOR_PURCHASABLE_BORDER = Color(1.0, 0.9, 0.3)
const COLOR_PREREQ_LOCKED = Color(0.55, 0.25, 0.15)
const COLOR_LOCKED = Color(0.25, 0.25, 0.3)
const COLOR_LABEL = Color(0.7, 0.75, 0.8)
const COLOR_LINE_MET = Color(0.3, 0.65, 0.4, 0.7)
const COLOR_LINE_UNMET = Color(0.4, 0.4, 0.5, 0.4)

# Stores center positions for connection line drawing
var _skill_card_centers: Dictionary = {}  # type -> Vector2
var _node_positions: Dictionary = {}      # type -> {level: Vector2}

func _ready() -> void:
  panel.visible = false
  close_btn.pressed.connect(_on_close_pressed)
  confirm_btn.pressed.connect(_on_confirm_pressed)

  GameManager.money_changed.connect(_on_money_changed)
  GameManager.upgrade_purchased.connect(_on_upgrade_purchased)
  WeaponManager.weapon_changed.connect(_on_weapon_changed)

  # Button styles
  close_btn.icon = preload("res://resources/images/icon/back.png")
  close_btn.expand_icon = true
  GameManager.style_button(close_btn, "muted")
  _position_close_btn()
  GameManager.style_button(confirm_btn)
  _position_bottom_section()
  _apply_side_padding()

  update_money_display()
  update_weapon_display()
  update_total_skill_label()
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
  update_total_skill_label()
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
  weapon_buy_btn.custom_minimum_size = Vector2(0, 60)
  weapon_buy_btn.add_theme_font_size_override("font_size", 26)
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
  return GameManager.get_upgrade_level(skill_type)

func _get_skill_chain(skill_type: String) -> Dictionary:
  return GameManager.get_skill_def(skill_type)

func _get_node_state(skill_type: String, level: int) -> String:
  var current_level = _get_current_level(skill_type)
  var chain = _get_skill_chain(skill_type)
  var max_level = chain.max_level
  var is_maxed = max_level >= 0 and current_level >= max_level

  if level <= current_level:
    return "completed"
  elif level == current_level + 1 and not is_maxed:
    # Check prereqs for this level
    var prereq = GameManager.check_skill_prereqs(skill_type, level)
    if prereq.met:
      return "purchasable"
    else:
      return "prereq_locked"
  else:
    # Check if any level between current+1 and this level has unmet prereqs
    # For locked nodes, check if they would be prereq_locked if they were next
    return "locked"

func _compute_column_order() -> void:
  # Build parent-children tree from :1 prereqs
  var children_map: Dictionary = {}  # parent_type -> [child_type]
  var has_parent: Dictionary = {}
  for key in GameManager.SKILL_PREREQS:
    var parts = key.split(":")
    if int(parts[1]) == 1:
      var parent = GameManager.SKILL_PREREQS[key][0].type
      if not children_map.has(parent):
        children_map[parent] = []
      if parts[0] not in children_map[parent]:
        children_map[parent].append(parts[0])
      has_parent[parts[0]] = true

  # Find root skills (no parent) in SKILL_DEFS order
  var roots: Array = []
  for def in GameManager.SKILL_DEFS:
    if not has_parent.has(def.type):
      roots.append(def.type)

  # Layout each root tree, then insert "weapon" in the middle
  var groups: Array = []
  for root in roots:
    groups.append(_layout_tree(root, children_map))

  _skill_columns = []
  _display_columns = []
  for i in range(groups.size()):
    _skill_columns += groups[i]
    _display_columns += groups[i]

func _layout_tree(root: String, children_map: Dictionary) -> Array:
  if not children_map.has(root):
    return [root]
  var children = children_map[root].duplicate()
  # Sort by subtree depth (deepest first → placed left)
  children.sort_custom(func(a, b):
    return _subtree_depth(a, children_map) > _subtree_depth(b, children_map))
  var left: Array = []
  var right: Array = []
  for i in range(children.size()):
    if i % 2 == 0:
      left.append(children[i])
    else:
      right.append(children[i])
  var left_layout: Array = []
  for child in left:
    left_layout = _layout_tree(child, children_map) + left_layout
  var right_layout: Array = []
  for child in right:
    right_layout += _layout_tree(child, children_map)
  return left_layout + [root] + right_layout

func _subtree_depth(node: String, children_map: Dictionary) -> int:
  if not children_map.has(node):
    return 0
  var max_d = 0
  for child in children_map[node]:
    max_d = max(max_d, 1 + _subtree_depth(child, children_map))
  return max_d

func _compute_prereq_data() -> void:
  _compute_column_order()
  _skill_connections.clear()
  _skill_node_steps.clear()

  # 1. SKILL_PREREQS → connection lines
  for key in GameManager.SKILL_PREREQS:
    var parts = key.split(":")
    var to_type = parts[0]
    var to_level = int(parts[1])
    for req in GameManager.SKILL_PREREQS[key]:
      _skill_connections.append({
        "from": req.type, "from_level": req.level,
        "to": to_type, "to_level": to_level,
      })

  # 2. Compute per-node step positions (each skill level gets its own row)
  _skill_node_steps.clear()

  # Identify dependency parent for each skill (from :1 prereq)
  var parent_map: Dictionary = {}  # child_type -> parent_type
  for key in GameManager.SKILL_PREREQS:
    var parts = key.split(":")
    var child_type = parts[0]
    var child_level = int(parts[1])
    if child_level == 1 and not parent_map.has(child_type):
      parent_map[child_type] = GameManager.SKILL_PREREQS[key][0].type

  # Root skills (no parent): level N → step N-1
  for skill_type in _skill_columns:
    if not parent_map.has(skill_type):
      _skill_node_steps[skill_type] = {}
      var chain = _get_skill_chain(skill_type)
      for lv in range(1, chain.max_level + 1):
        _skill_node_steps[skill_type][lv] = lv - 1

  # Resolve dependent skills iteratively (handles chains like 등급→보상→드롭)
  var max_iter = _skill_columns.size()
  var iter = 0
  while _skill_node_steps.size() < _skill_columns.size() and iter < max_iter:
    for skill_type in _skill_columns:
      if _skill_node_steps.has(skill_type):
        continue
      if not _skill_node_steps.has(parent_map[skill_type]):
        continue
      _skill_node_steps[skill_type] = {}
      var chain = _get_skill_chain(skill_type)
      var prev_step: int = -1
      for lv in range(1, chain.max_level + 1):
        var step = prev_step + 1
        var key = "%s:%d" % [skill_type, lv]
        if GameManager.SKILL_PREREQS.has(key):
          for req in GameManager.SKILL_PREREQS[key]:
            if _skill_node_steps.has(req.type) and _skill_node_steps[req.type].has(req.level):
              step = max(step, _skill_node_steps[req.type][req.level] + 1)
        _skill_node_steps[skill_type][lv] = step
        prev_step = step
    iter += 1

func build_skill_tree() -> void:
  _compute_prereq_data()
  for child in skill_tree_container.get_children():
    child.queue_free()
  _skill_card_centers.clear()
  _node_positions.clear()

  var container_width = skill_tree_container.size.x
  if container_width <= 0:
    container_width = skill_tree_container.get_parent().size.x
  if container_width <= 0:
    container_width = panel.size.x - 40

  var tree_margin: float = 50.0
  var usable_width = container_width - tree_margin * 2
  var col_count = _display_columns.size()
  var col_width = usable_width / float(col_count)
  var step_size = NODE_SIZE + NODE_GAP

  # Find total steps needed (max step across all skill nodes + 1)
  var max_steps: int = 0
  for skill_type in _skill_columns:
    var chain = _get_skill_chain(skill_type)
    var last_step = _skill_node_steps[skill_type][chain.max_level]
    max_steps = max(max_steps, last_step + 1)

  for col_idx in range(col_count):
    var skill_type = _display_columns[col_idx]
    var col_x = tree_margin + col_idx * col_width
    var chain = _get_skill_chain(skill_type)
    var current_level = _get_current_level(skill_type)
    var max_level = chain.max_level
    var first_step = _skill_node_steps[skill_type][1]
    var last_step = _skill_node_steps[skill_type][max_level]

    var center_x = col_x + col_width / 2.0
    var col_top_y = COL_HEADER_HEIGHT +first_step * step_size

    _node_positions[skill_type] = {}

    # Column background panel (spans first node to last node)
    var col_height = 45 + (last_step - first_step) * step_size + NODE_SIZE + 10
    var bg = Panel.new()
    var bg_style = StyleBoxFlat.new()
    bg_style.bg_color = Color(0.1, 0.1, 0.15, 0.5)
    bg_style.corner_radius_top_left = 8
    bg_style.corner_radius_top_right = 8
    bg_style.corner_radius_bottom_left = 8
    bg_style.corner_radius_bottom_right = 8
    bg.add_theme_stylebox_override("panel", bg_style)
    bg.position = Vector2(col_x + 1, col_top_y - 45)
    bg.size = Vector2(col_width - 2, col_height)
    skill_tree_container.add_child(bg)

    # Skill name (short)
    var name_label = Label.new()
    name_label.text = GameManager.get_skill_def(skill_type).short_name
    name_label.add_theme_font_size_override("font_size", 20)
    name_label.add_theme_color_override("font_color", Color.WHITE if current_level > 0 else Color(0.5, 0.55, 0.6))
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.position = Vector2(col_x, col_top_y - 43)
    name_label.size = Vector2(col_width, 22)
    skill_tree_container.add_child(name_label)

    # Level count
    var level_label = Label.new()
    level_label.text = "%d/%d" % [current_level, max_level]
    level_label.add_theme_font_size_override("font_size", 16)
    level_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.7) if current_level > 0 else Color(0.45, 0.45, 0.5))
    level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    level_label.position = Vector2(col_x, col_top_y - 22)
    level_label.size = Vector2(col_width, 18)
    skill_tree_container.add_child(level_label)

    # Level nodes (vertical column) + connecting lines between them
    for i in range(max_level):
      var level = i + 1
      var state = _get_node_state(skill_type, level)
      var node_step = _skill_node_steps[skill_type][level]
      var node_y = COL_HEADER_HEIGHT +node_step * step_size
      _node_positions[skill_type][level] = Vector2(center_x, node_y + NODE_SIZE / 2.0)

      # Vertical line from previous node to this node
      if i > 0:
        var prev_step = _skill_node_steps[skill_type][level - 1]
        var prev_bottom = COL_HEADER_HEIGHT +prev_step * step_size + NODE_SIZE
        var curr_top = node_y
        if curr_top > prev_bottom:
          var prev_state = _get_node_state(skill_type, level - 1)
          var line_met = prev_state == "completed"
          var vline = Line2D.new()
          vline.z_index = 1
          vline.width = 4.0
          vline.default_color = Color(0.3, 0.65, 0.4, 0.9) if line_met else Color(0.4, 0.4, 0.5, 0.6)
          vline.antialiased = true
          vline.add_point(Vector2(center_x, prev_bottom))
          vline.add_point(Vector2(center_x, curr_top))
          skill_tree_container.add_child(vline)

      var dot = _create_skill_node(skill_type, level, state)
      dot.position = Vector2(center_x - NODE_SIZE / 2.0, node_y)
      dot.size = Vector2(NODE_SIZE, NODE_SIZE)
      skill_tree_container.add_child(dot)

    _skill_card_centers[skill_type] = Vector2(center_x, col_top_y - 20)

  var total_height = COL_HEADER_HEIGHT + max_steps * step_size + 20
  skill_tree_container.custom_minimum_size = Vector2(0, total_height)

  _add_connection_lines()

func _create_skill_node(skill_type: String, level: int, state: String) -> Button:
  var btn = Button.new()
  btn.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)

  var style = StyleBoxFlat.new()
  var radius = int(NODE_SIZE / 2)
  style.corner_radius_top_left = radius
  style.corner_radius_top_right = radius
  style.corner_radius_bottom_left = radius
  style.corner_radius_bottom_right = radius
  style.content_margin_left = 2
  style.content_margin_right = 2
  style.content_margin_top = 2
  style.content_margin_bottom = 2

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
    "prereq_locked":
      style.bg_color = COLOR_PREREQ_LOCKED
      style.border_width_top = 2
      style.border_width_bottom = 2
      style.border_width_left = 2
      style.border_width_right = 2
      style.border_color = Color(0.7, 0.3, 0.2, 0.6)
      btn.text = str(level)
      btn.disabled = false
      btn.add_theme_color_override("font_color", Color(0.9, 0.7, 0.5))
      btn.pressed.connect(_on_skill_node_pressed.bind(skill_type, level))
    "locked":
      style.bg_color = COLOR_LOCKED
      btn.text = ""
      btn.disabled = true
      btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.55))

  btn.add_theme_stylebox_override("normal", style)
  btn.add_theme_stylebox_override("hover", style)
  btn.add_theme_stylebox_override("pressed", style)
  btn.add_theme_stylebox_override("disabled", style)
  btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
  btn.add_theme_font_size_override("font_size", 16)

  return btn

func _add_connection_lines() -> void:
  for conn in _skill_connections:
    var from_type: String = conn["from"]
    var to_type: String = conn["to"]
    var from_level: int = conn["from_level"]
    var to_level: int = conn["to_level"]

    if not _node_positions.has(from_type) or not _node_positions.has(to_type):
      continue
    if not _node_positions[from_type].has(from_level) or not _node_positions[to_type].has(to_level):
      continue

    var from_pos = _node_positions[from_type][from_level]
    var to_pos = _node_positions[to_type][to_level]

    var is_met = _get_current_level(from_type) >= from_level
    var color = Color(0.3, 0.65, 0.4, 0.9) if is_met else Color(0.4, 0.4, 0.5, 0.6)
    var width = 4.0 if is_met else 3.0

    if is_met:
      var line = Line2D.new()
      line.z_index = 1
      line.width = width
      line.default_color = color
      line.antialiased = true
      line.add_point(from_pos)
      line.add_point(to_pos)
      skill_tree_container.add_child(line)
    else:
      # Dashed line
      var length = from_pos.distance_to(to_pos)
      var dir = (to_pos - from_pos).normalized()
      var dash_len = 10.0
      var gap_len = 8.0
      var d = 0.0
      while d < length:
        var seg_start = from_pos + dir * d
        var seg_end = from_pos + dir * min(d + dash_len, length)
        var dash = Line2D.new()
        dash.z_index = 1
        dash.width = width
        dash.default_color = color
        dash.antialiased = true
        dash.add_point(seg_start)
        dash.add_point(seg_end)
        skill_tree_container.add_child(dash)
        d += dash_len + gap_len

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
  var chain_info = _get_skill_chain(selected_type)
  if chain_info.is_empty():
    return

  var current_level = _get_current_level(selected_type)
  var cost = GameManager.get_upgrade_cost(current_level, selected_type)

  var stat_text = ""
  match selected_type:
    "grass_density":
      var current_val = GameManager.get_grass_min_spacing()
      var temp = GameManager.upgrade_levels["grass_density"]
      GameManager.upgrade_levels["grass_density"] += 1
      var next_val = GameManager.get_grass_min_spacing()
      GameManager.upgrade_levels["grass_density"] = temp
      stat_text = "풀 간격: %.1f → %.1f" % [current_val, next_val]
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
      var req_name = GameManager.get_skill_def(m.type).get("name", m.type)
      prereq_text += "\n  %s Lv.%d (현재: Lv.%d)" % [req_name, m.level, m.current]

  description_label.text = "%s Lv.%d\n\n%s\n%s%s\n\n비용: $%s" % [chain_info.name, selected_level, chain_info.description, stat_text, prereq_text, format_number(cost)]

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
  money_display.update_display()

func update_total_skill_label() -> void:
  total_skill_label.text = "스킬: %d" % GameManager.get_total_skill_level()

func _apply_side_padding() -> void:
  var pad_h = GameManager.SCREEN_PADDING_H
  # WeaponSection
  weapon_section.offset_left = pad_h
  weapon_section.offset_right = -pad_h
  # SectionLabel
  section_label.offset_left = pad_h
  section_label.offset_right = -pad_h
  # SkillTreeScroll
  skill_tree_scroll.offset_left = pad_h
  skill_tree_scroll.offset_right = -pad_h

func _position_close_btn() -> void:
  var pad_h = GameManager.SCREEN_PADDING_H
  var pad_v = GameManager.SCREEN_PADDING_V
  var w = 160.0
  var h = 75.0
  close_btn.anchor_left = 0.0
  close_btn.anchor_right = 0.0
  close_btn.anchor_top = 0.0
  close_btn.anchor_bottom = 0.0
  close_btn.offset_left = pad_h
  close_btn.offset_top = pad_v
  close_btn.offset_right = pad_h + w
  close_btn.offset_bottom = pad_v + h

func _position_bottom_section() -> void:
  var vp_size = get_viewport_rect().size
  var pad_h = GameManager.SCREEN_PADDING_H
  var pad_v = GameManager.SCREEN_PADDING_V
  var btn_height = 120.0
  var gap = 20.0
  var desc_height = 280.0
  # ConfirmBtn at viewport bottom
  confirm_btn.anchor_left = 0.0
  confirm_btn.anchor_right = 1.0
  confirm_btn.anchor_top = 0.0
  confirm_btn.anchor_bottom = 0.0
  confirm_btn.offset_left = pad_h
  confirm_btn.offset_right = -pad_h
  confirm_btn.offset_bottom = vp_size.y - pad_v
  confirm_btn.offset_top = confirm_btn.offset_bottom - btn_height
  # DescriptionPanel above ConfirmBtn
  description_panel.anchor_left = 0.0
  description_panel.anchor_right = 1.0
  description_panel.anchor_top = 0.0
  description_panel.anchor_bottom = 0.0
  description_panel.offset_left = pad_h
  description_panel.offset_right = -pad_h
  description_panel.offset_bottom = confirm_btn.offset_top - gap
  description_panel.offset_top = description_panel.offset_bottom - desc_height
  # SkillTreeScroll ends before DescriptionPanel
  skill_tree_scroll.offset_bottom = description_panel.offset_top - gap

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
