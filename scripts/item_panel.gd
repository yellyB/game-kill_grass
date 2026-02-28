extends Control

signal panel_opened
signal panel_closed

@onready var panel: Panel = $Panel
@onready var close_btn: Button = $Panel/CloseBtn
@onready var money_display = $Panel/MoneyDisplay
@onready var scroll_container: ScrollContainer = $Panel/ScrollContainer

var is_open: bool = false
var _crafting: bool = false

# Content containers (built dynamically)
var content_vbox: VBoxContainer
var material_center: CenterContainer
var material_grid: GridContainer
var parts_center: CenterContainer
var parts_grid: GridContainer
var final_center: CenterContainer
var detail_container: Control  # Overlay for recipe detail (no layout push)

# ── Base materials (fixed order, 16 items) ──
const ALL_ITEMS: Array = [
  {"id": "질긴 슬라임 조각", "image": "res://resources/images/items/질긴 슬라임 조각.png"},
  {"id": "번개 먹은 배터리 껍질", "image": "res://resources/images/items/번개 먹은 배터리 껍질.png"},
  {"id": "차축 뼈대", "image": "res://resources/images/items/차축 뼈대.png"},
  {"id": "굴러다니는 바퀴 잔해", "image": "res://resources/images/items/굴러다니는 바퀴 잔해.png"},
  {"id": "과성장 생체 응축체", "image": "res://resources/images/items/과성장 생체 응축체.png"},
  {"id": "왜곡된 볼트 조각", "image": "res://resources/images/items/왜곡된 볼트 조각.png"},
  {"id": "압축된 이세계 철편", "image": "res://resources/images/items/압축된 이세계 철편.png"},
  {"id": "생체 연료 포자", "image": "res://resources/images/items/생체 연료 포자.png"},
  {"id": "뒤틀린 시간 포자", "image": "res://resources/images/items/뒤틀린 시간 포자.png"},
  {"id": "바람 머금은 잔디 섬유", "image": "res://resources/images/items/바람 머금은 잔디 섬유.png"},
  {"id": "몬스터 핵", "image": "res://resources/images/items/몬스터 핵.png"},
  {"id": "침식된 백골 프레임", "image": "res://resources/images/items/침식된 백골 프레임.png"},
  {"id": "투명 수정 파편", "image": "res://resources/images/items/투명 수정 파편.png"},
  {"id": "강화 유리 결정핵", "image": "res://resources/images/items/강화 유리 결정핵.png"},
  {"id": "과열된 엔진 심장", "image": "res://resources/images/items/과열된 엔진 심장.png"},
  {"id": "드래곤 배기가스 결정", "image": "res://resources/images/items/드래곤 배기가스 결정.png"},
]

# ── Crafting recipes ──
const RECIPES: Array = [
  {
    "id": "개념상 바퀴",
    "ingredients": [
      {"item_id": "굴러다니는 바퀴 잔해", "count": 2},
      {"item_id": "차축 뼈대", "count": 1},
      {"item_id": "왜곡된 볼트 조각", "count": 8},
      {"item_id": "질긴 슬라임 조각", "count": 4},
    ]
  },
  {
    "id": "폭발하는 엔진 코어",
    "ingredients": [
      {"item_id": "과열된 엔진 심장", "count": 1},
      {"item_id": "드래곤 배기가스 결정", "count": 2},
      {"item_id": "번개 먹은 배터리 껍질", "count": 4},
    ]
  },
  {
    "id": "충격 무시 범퍼",
    "ingredients": [
      {"item_id": "압축된 이세계 철편", "count": 5},
      {"item_id": "생체 연료 포자", "count": 1},
      {"item_id": "몬스터 핵", "count": 1},
    ]
  },
  {
    "id": "이세계 내비게이션",
    "ingredients": [
      {"item_id": "뒤틀린 시간 포자", "count": 4},
      {"item_id": "몬스터 핵", "count": 1},
    ]
  },
  {
    "id": "강화 유리 모듈",
    "ingredients": [
      {"item_id": "투명 수정 파편", "count": 8},
      {"item_id": "강화 유리 결정핵", "count": 1},
      {"item_id": "압축된 이세계 철편", "count": 1},
    ]
  },
  {
    "id": "운전기사",
    "ingredients": [
      {"item_id": "바람 머금은 잔디 섬유", "count": 20},
      {"item_id": "과성장 생체 응축체", "count": 4},
      {"item_id": "침식된 백골 프레임", "count": 12},
    ]
  },
]

const PART_BUFFS: Dictionary = {
  "개념상 바퀴": {"label": "이동 속도", "per": "+8%", "max": "+32%"},
  "폭발하는 엔진 코어": {"label": "공격 범위", "per": "+10%", "max": "+100%"},
  "충격 무시 범퍼": {"label": "넉백 증가", "per": "+120", "max": "+240"},
  "이세계 내비게이션": {"label": "몬스터 탐지", "per": "", "max": ""},
  "강화 유리 모듈": {"label": "수집 범위", "per": "+15%", "max": "+90%"},
  "운전기사": {"label": "공격 속도", "per": "+20%", "max": "+20%"},
}

# ── Crafted items (parts) ──
const CRAFTED_ITEMS: Array = [
  {"id": "개념상 바퀴", "image": "res://resources/images/product/개념상 바퀴.png"},
  {"id": "폭발하는 엔진 코어", "image": "res://resources/images/product/폭발하는 엔진 코어.png"},
  {"id": "충격 무시 범퍼", "image": "res://resources/images/product/충격 무시 범퍼.png"},
  {"id": "이세계 내비게이션", "image": "res://resources/images/product/이세계 내비게이션.png"},
  {"id": "강화 유리 모듈", "image": "res://resources/images/product/강화 유리 모듈.png"},
  {"id": "운전기사", "image": "res://resources/images/product/운전기사.png"},
]

# ── Final assembly recipe ──
const FINAL_RECIPE: Dictionary = {
  "id": "이세계 트럭",
  "image": "res://resources/images/product/이세계 트럭.png",
  "ingredients": [
    {"item_id": "개념상 바퀴", "count": 4},
    {"item_id": "폭발하는 엔진 코어", "count": 10},
    {"item_id": "충격 무시 범퍼", "count": 2},
    {"item_id": "이세계 내비게이션", "count": 1},
    {"item_id": "강화 유리 모듈", "count": 6},
    {"item_id": "운전기사", "count": 1},
    {"item_id": "졸음 약", "count": 1},
  ]
}

func _ready() -> void:
  panel.visible = false
  close_btn.pressed.connect(_on_close_pressed)

  GameManager.money_changed.connect(_on_money_changed)
  GameManager.inventory_changed.connect(_on_inventory_changed)

  update_money_display()

  # Button styles
  close_btn.icon = preload("res://resources/images/icon/back.png")
  close_btn.expand_icon = true
  GameManager.style_button(close_btn, "muted")
  _position_close_btn()

  _build_layout()

func set_toggle_button_visible(_should_show: bool) -> void:
  pass

func open_panel() -> void:
  if is_open:
    return
  is_open = true
  panel.visible = true
  update_money_display()
  _refresh_all()
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

func _on_money_changed(_amount: int) -> void:
  update_money_display()

func _on_inventory_changed() -> void:
  if is_open and not _crafting:
    _refresh_all()

func update_money_display() -> void:
  money_display.update_display()

# ── Layout building ──

func _build_layout() -> void:
  var pad_h = GameManager.SCREEN_PADDING_H
  var pad_v = GameManager.SCREEN_PADDING_V

  # Hide the tscn ScrollContainer — we use a direct VBoxContainer instead
  scroll_container.visible = false

  content_vbox = VBoxContainer.new()
  content_vbox.anchor_right = 1.0
  content_vbox.anchor_bottom = 1.0
  content_vbox.offset_left = pad_h
  content_vbox.offset_top = 190.0
  content_vbox.offset_right = -pad_h
  content_vbox.offset_bottom = -pad_v
  content_vbox.add_theme_constant_override("separation", 10)
  panel.add_child(content_vbox)

  # Materials section header (centered)
  var mat_header = _create_section_header("재료")
  mat_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  content_vbox.add_child(mat_header)

  # Materials grid (4 columns, centered)
  material_center = CenterContainer.new()
  material_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  content_vbox.add_child(material_center)

  material_grid = GridContainer.new()
  material_grid.columns = 4
  material_grid.add_theme_constant_override("h_separation", 12)
  material_grid.add_theme_constant_override("v_separation", 12)
  material_center.add_child(material_grid)

  # Spacer (expand to fill, min 30)
  var spacer1 = Control.new()
  spacer1.size_flags_vertical = Control.SIZE_EXPAND_FILL
  spacer1.custom_minimum_size = Vector2(0, 30)
  content_vbox.add_child(spacer1)

  # Parts section header (centered)
  var parts_header = _create_section_header("부품")
  parts_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  content_vbox.add_child(parts_header)

  # Parts grid (2 columns, centered)
  parts_center = CenterContainer.new()
  parts_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  content_vbox.add_child(parts_center)

  parts_grid = GridContainer.new()
  parts_grid.columns = 2
  parts_grid.add_theme_constant_override("h_separation", 16)
  parts_grid.add_theme_constant_override("v_separation", 16)
  parts_center.add_child(parts_grid)

  # Spacer (expand to fill, min 30)
  var spacer2 = Control.new()
  spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
  spacer2.custom_minimum_size = Vector2(0, 30)
  content_vbox.add_child(spacer2)

  # Final assembly section header (centered)
  var final_header = _create_section_header("최종 조립")
  final_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  content_vbox.add_child(final_header)

  # Final assembly card container (centered)
  final_center = CenterContainer.new()
  final_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  content_vbox.add_child(final_center)

  # Recipe detail overlay (floats over content, no layout push)
  detail_container = Control.new()
  detail_container.visible = false
  detail_container.set_anchors_preset(Control.PRESET_FULL_RECT)
  detail_container.offset_top = 190.0
  detail_container.mouse_filter = Control.MOUSE_FILTER_STOP
  panel.add_child(detail_container)

func _create_section_header(text: String) -> Label:
  var label = Label.new()
  label.text = text
  label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
  label.add_theme_font_size_override("font_size", 32)
  label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
  label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  label.add_theme_constant_override("outline_size", 2)
  return label

# ── Refresh all ──

func _refresh_all() -> void:
  _refresh_materials()
  _refresh_parts()
  _refresh_final_assembly()

func _refresh_materials() -> void:
  for child in material_grid.get_children():
    child.queue_free()

  for item_data in ALL_ITEMS:
    var item_id: String = item_data.id
    var image_path: String = item_data.image
    var count = GameManager.get_item_count(item_id)
    var discovered = GameManager.is_item_discovered(item_id)

    var slot: PanelContainer
    if not discovered:
      slot = _create_undiscovered_slot()
    elif count <= 0:
      slot = _create_inactive_slot(item_id, image_path)
    else:
      slot = _create_active_slot(item_id, image_path, count)
    material_grid.add_child(slot)

func _refresh_parts() -> void:
  for child in parts_grid.get_children():
    parts_grid.remove_child(child)
    child.queue_free()

  for recipe in RECIPES:
    var slot = _create_part_slot(recipe)
    parts_grid.add_child(slot)

func _refresh_final_assembly() -> void:
  for child in final_center.get_children():
    child.queue_free()

  var card = _create_final_assembly_card()
  final_center.add_child(card)

# ── Material slot creation ──

func _create_undiscovered_slot() -> PanelContainer:
  var slot = PanelContainer.new()
  slot.custom_minimum_size = Vector2(200, 120)

  var style = StyleBoxFlat.new()
  style.bg_color = Color(0.08, 0.08, 0.12)
  style.corner_radius_top_left = 10
  style.corner_radius_top_right = 10
  style.corner_radius_bottom_left = 10
  style.corner_radius_bottom_right = 10
  style.border_width_top = 1
  style.border_width_bottom = 1
  style.border_width_left = 1
  style.border_width_right = 1
  style.border_color = Color(0.2, 0.2, 0.3)
  slot.add_theme_stylebox_override("panel", style)

  var center = CenterContainer.new()
  center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  center.size_flags_vertical = Control.SIZE_EXPAND_FILL
  slot.add_child(center)

  var question = Label.new()
  question.text = "?"
  question.add_theme_font_size_override("font_size", 48)
  question.add_theme_color_override("font_color", Color(0.3, 0.3, 0.4))
  center.add_child(question)

  return slot

func _create_inactive_slot(item_id: String, image_path: String) -> PanelContainer:
  var slot = _create_base_material_slot(item_id, image_path, -1)
  slot.modulate = Color(1, 1, 1, 0.35)
  return slot

func _create_active_slot(item_id: String, image_path: String, count: int) -> PanelContainer:
  return _create_base_material_slot(item_id, image_path, count)

func _create_base_material_slot(item_id: String, image_path: String, count: int) -> PanelContainer:
  var slot = PanelContainer.new()
  slot.custom_minimum_size = Vector2(200, 120)

  var style = StyleBoxFlat.new()
  style.bg_color = Color(0.15, 0.15, 0.22)
  style.corner_radius_top_left = 10
  style.corner_radius_top_right = 10
  style.corner_radius_bottom_left = 10
  style.corner_radius_bottom_right = 10
  style.border_width_top = 1
  style.border_width_bottom = 1
  style.border_width_left = 1
  style.border_width_right = 1
  style.border_color = Color(0.3, 0.3, 0.4)
  slot.add_theme_stylebox_override("panel", style)

  var vbox = VBoxContainer.new()
  vbox.alignment = BoxContainer.ALIGNMENT_CENTER
  vbox.add_theme_constant_override("separation", 2)
  vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
  slot.add_child(vbox)

  # Item image
  var tex_rect = TextureRect.new()
  tex_rect.custom_minimum_size = Vector2(56, 56)
  tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
  var tex = _load_texture(image_path)
  if tex:
    tex_rect.texture = tex
  vbox.add_child(tex_rect)

  # Item name
  var name_label = Label.new()
  name_label.text = item_id
  name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  name_label.add_theme_font_size_override("font_size", 13)
  name_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
  name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  vbox.add_child(name_label)

  # Item count (only if active)
  if count >= 0:
    var count_label = Label.new()
    count_label.text = "x%d" % count
    count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    count_label.add_theme_font_size_override("font_size", 20)
    count_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
    vbox.add_child(count_label)

  return slot

# ── Final assembly card creation ──

func _count_parts_fulfilled() -> int:
  # 부품 6종만 카운트 (졸음 약 제외)
  var count = 0
  for recipe in RECIPES:
    var needed = _get_final_recipe_required(recipe.id)
    if GameManager.get_item_count(recipe.id) >= needed:
      count += 1
  return count

func _create_final_assembly_card() -> PanelContainer:
  var parts_fulfilled = _count_parts_fulfilled()
  var parts_total = RECIPES.size()  # 6
  var all_parts_ready = parts_fulfilled >= parts_total
  var can_craft = _can_craft(FINAL_RECIPE)

  var card = PanelContainer.new()
  card.custom_minimum_size = Vector2(816, 121)

  var style = StyleBoxFlat.new()
  if can_craft:
    # 청록 (조립 가능 - 부품 + 졸음 약 모두 충족)
    style.bg_color = Color(0.1, 0.17, 0.15)
    style.border_color = Color(0.25, 0.55, 0.42)
  else:
    # 주황 (재료 부족)
    style.bg_color = Color(0.12, 0.12, 0.08)
    style.border_color = Color(0.5, 0.4, 0.15)
  style.corner_radius_top_left = 14
  style.corner_radius_top_right = 14
  style.corner_radius_bottom_left = 14
  style.corner_radius_bottom_right = 14
  style.border_width_top = 2
  style.border_width_bottom = 2
  style.border_width_left = 2
  style.border_width_right = 2
  style.content_margin_left = 16
  style.content_margin_right = 16
  style.content_margin_top = 12
  style.content_margin_bottom = 12
  card.add_theme_stylebox_override("panel", style)

  if not all_parts_ready:
    card.modulate = Color(1, 1, 1, 0.5)

  # [이미지] [이름 + 수량] - 부품 카드와 동일 구조
  var row_hbox = HBoxContainer.new()
  row_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
  row_hbox.add_theme_constant_override("separation", 12)
  card.add_child(row_hbox)

  # 이미지 컬럼
  if not all_parts_ready:
    var icon_label = Label.new()
    icon_label.text = "?"
    icon_label.add_theme_font_size_override("font_size", 56)
    icon_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.4))
    icon_label.custom_minimum_size = Vector2(80, 80)
    icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    row_hbox.add_child(icon_label)
  else:
    var truck_tex_rect = TextureRect.new()
    truck_tex_rect.custom_minimum_size = Vector2(80, 80)
    truck_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    truck_tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    var truck_tex = _load_texture(FINAL_RECIPE.image)
    if truck_tex:
      truck_tex_rect.texture = truck_tex
    row_hbox.add_child(truck_tex_rect)

  # 이름 + 수량 컬럼 (세로 가운데 정렬)
  var info_vbox = VBoxContainer.new()
  info_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
  info_vbox.add_theme_constant_override("separation", 4)
  row_hbox.add_child(info_vbox)

  var name_label = Label.new()
  name_label.text = "???" if not all_parts_ready else FINAL_RECIPE.id
  name_label.add_theme_font_size_override("font_size", 28)
  if not all_parts_ready:
    name_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.4))
  else:
    name_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
  info_vbox.add_child(name_label)

  var summary = Label.new()
  if not all_parts_ready:
    summary.text = "부품을 모두 모으면 해금"
    summary.add_theme_color_override("font_color", Color(0.3, 0.3, 0.35))
  else:
    summary.text = "부품 %d/%d" % [parts_fulfilled, parts_total]
    summary.add_theme_color_override("font_color", Color(0.5, 0.4, 0.3))
  summary.add_theme_font_size_override("font_size", 22)
  info_vbox.add_child(summary)

  # Clickable overlay (only when all parts ready)
  if all_parts_ready:
    var btn = Button.new()
    btn.flat = true
    btn.anchors_preset = Control.PRESET_FULL_RECT
    btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    btn.pressed.connect(_show_recipe_detail.bind(FINAL_RECIPE))
    card.add_child(btn)

  return card

# ── Part slot creation (merged parts + crafting) ──

func _create_part_slot(recipe: Dictionary) -> PanelContainer:
  var item_id: String = recipe.id
  var count: int = GameManager.get_item_count(item_id)
  var needed: int = _get_final_recipe_required(item_id)
  var can_craft: bool = _can_craft(recipe)
  var complete: bool = count >= needed

  var slot = PanelContainer.new()
  slot.custom_minimum_size = Vector2(400, 200)

  var style = StyleBoxFlat.new()
  if complete or can_craft:
    # 청록 (재료 충족 / 제작 완료)
    style.bg_color = Color(0.1, 0.17, 0.15)
    style.border_color = Color(0.25, 0.55, 0.42)
  else:
    # 주황 (재료 미충족)
    style.bg_color = Color(0.12, 0.12, 0.08)
    style.border_color = Color(0.5, 0.4, 0.15)
  style.corner_radius_top_left = 14
  style.corner_radius_top_right = 14
  style.corner_radius_bottom_left = 14
  style.corner_radius_bottom_right = 14
  style.border_width_top = 2
  style.border_width_bottom = 2
  style.border_width_left = 2
  style.border_width_right = 2
  style.content_margin_left = 32
  style.content_margin_right = 32
  style.content_margin_top = 24
  style.content_margin_bottom = 24
  slot.add_theme_stylebox_override("panel", style)

  if complete:
    slot.modulate = Color(1, 1, 1, 0.5)

  # Main vertical layout: [row] + [progress bar]
  var main_vbox = VBoxContainer.new()
  main_vbox.add_theme_constant_override("separation", 15)
  main_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
  slot.add_child(main_vbox)

  # [이미지] [이름 + 수량]
  var row_hbox = HBoxContainer.new()
  row_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
  row_hbox.add_theme_constant_override("separation", 12)
  main_vbox.add_child(row_hbox)

  # 이미지 컬럼
  var part_image_path = _get_crafted_item_image(item_id)
  var tex_rect = TextureRect.new()
  tex_rect.custom_minimum_size = Vector2(90, 90)
  tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
  var tex = _load_texture(part_image_path)
  if tex:
    tex_rect.texture = tex
  row_hbox.add_child(tex_rect)

  # 이름 + 수량 컬럼 (세로 가운데 정렬)
  var info_vbox = VBoxContainer.new()
  info_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
  info_vbox.add_theme_constant_override("separation", 4)
  row_hbox.add_child(info_vbox)

  var name_label = Label.new()
  name_label.text = item_id
  name_label.add_theme_font_size_override("font_size", 28)
  if complete:
    name_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.3))
  else:
    name_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
  info_vbox.add_child(name_label)

  var count_label = Label.new()
  count_label.text = "%d/%d" % [count, needed]
  count_label.add_theme_font_size_override("font_size", 22)
  if complete:
    count_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.2))
  elif can_craft:
    count_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.55))
  else:
    count_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
  info_vbox.add_child(count_label)

  # Divider + progress section with tighter spacing
  var bottom_vbox = VBoxContainer.new()
  bottom_vbox.add_theme_constant_override("separation", 15)
  main_vbox.add_child(bottom_vbox)

  var divider = ColorRect.new()
  divider.custom_minimum_size = Vector2(0, 1)
  divider.color = Color(0.45, 0.45, 0.55, 0.8)
  bottom_vbox.add_child(divider)

  # Buff progress bar
  var buff_info = PART_BUFFS.get(item_id, {})
  if not buff_info.is_empty():
    var capped = mini(count, needed)
    var progress = float(capped) / float(needed) if needed > 0 else 0.0

    # Bar container (label left, bar center, label right)
    var bar_hbox = HBoxContainer.new()
    bar_hbox.add_theme_constant_override("separation", 8)
    bottom_vbox.add_child(bar_hbox)

    # Buff name label (left)
    var buff_name = Label.new()
    buff_name.text = buff_info.label
    buff_name.add_theme_font_size_override("font_size", 21)
    buff_name.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
    buff_name.custom_minimum_size = Vector2(90, 0)
    bar_hbox.add_child(buff_name)

    # Progress bar
    var bar_bg = PanelContainer.new()
    bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bar_bg.custom_minimum_size = Vector2(0, 21)
    var bg_style = StyleBoxFlat.new()
    bg_style.bg_color = Color(0.1, 0.1, 0.15)
    bg_style.corner_radius_top_left = 4
    bg_style.corner_radius_top_right = 4
    bg_style.corner_radius_bottom_left = 4
    bg_style.corner_radius_bottom_right = 4
    bar_bg.add_theme_stylebox_override("panel", bg_style)
    bar_hbox.add_child(bar_bg)

    var bar_fill = Panel.new()
    bar_fill.anchor_right = progress
    bar_fill.anchor_bottom = 1.0
    var fill_style = StyleBoxFlat.new()
    if count > 0:
      fill_style.bg_color = Color(0.25, 0.7, 0.9, 0.9)
    else:
      fill_style.bg_color = Color(0.25, 0.25, 0.35, 0.5)
    fill_style.corner_radius_top_left = 4
    fill_style.corner_radius_top_right = 4
    fill_style.corner_radius_bottom_left = 4
    fill_style.corner_radius_bottom_right = 4
    bar_fill.add_theme_stylebox_override("panel", fill_style)
    bar_bg.add_child(bar_fill)

    # Max value label (right)
    if buff_info.max != "":
      var max_label = Label.new()
      max_label.text = buff_info.max
      max_label.add_theme_font_size_override("font_size", 21)
      if complete:
        max_label.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
      else:
        max_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
      bar_hbox.add_child(max_label)

  # Clickable only if not complete
  if not complete:
    var btn = Button.new()
    btn.flat = true
    btn.anchors_preset = Control.PRESET_FULL_RECT
    btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    btn.pressed.connect(_show_recipe_detail.bind(recipe))
    slot.add_child(btn)

  return slot

# ── Recipe detail modal ──

func _show_recipe_detail(recipe: Dictionary) -> void:
  GameManager.play_button_click()
  # Clear previous detail
  for child in detail_container.get_children():
    child.queue_free()

  # Show container
  detail_container.visible = true

  # Dim background (fills entire overlay area)
  var bg = ColorRect.new()
  bg.color = Color(0.08, 0.08, 0.12, 0.95)
  bg.set_anchors_preset(Control.PRESET_FULL_RECT)
  detail_container.add_child(bg)

  # ScrollContainer for detail content (in case ingredients overflow)
  var detail_scroll = ScrollContainer.new()
  detail_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
  detail_scroll.offset_left = 30
  detail_scroll.offset_right = -30
  detail_scroll.offset_top = 20
  detail_scroll.offset_bottom = -20
  detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
  detail_container.add_child(detail_scroll)

  # Detail card
  var card = PanelContainer.new()
  card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  var card_style = StyleBoxFlat.new()
  card_style.bg_color = Color(0.12, 0.12, 0.18)
  card_style.corner_radius_top_left = 20
  card_style.corner_radius_top_right = 20
  card_style.corner_radius_bottom_left = 20
  card_style.corner_radius_bottom_right = 20
  card_style.border_width_top = 2
  card_style.border_width_bottom = 2
  card_style.border_width_left = 2
  card_style.border_width_right = 2
  card_style.border_color = Color(0.4, 0.4, 0.55)
  card_style.content_margin_left = 40
  card_style.content_margin_right = 40
  card_style.content_margin_top = 32
  card_style.content_margin_bottom = 32
  card.add_theme_stylebox_override("panel", card_style)
  detail_scroll.add_child(card)

  var vbox = VBoxContainer.new()
  vbox.add_theme_constant_override("separation", 24)
  card.add_child(vbox)

  # Title row
  var title_hbox = HBoxContainer.new()
  title_hbox.add_theme_constant_override("separation", 16)
  title_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
  vbox.add_child(title_hbox)

  var detail_image_path = _get_crafted_item_image(recipe.id)
  if detail_image_path != "":
    var detail_tex_rect = TextureRect.new()
    detail_tex_rect.custom_minimum_size = Vector2(56, 56)
    detail_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    detail_tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    var detail_tex = _load_texture(detail_image_path)
    if detail_tex:
      detail_tex_rect.texture = detail_tex
    title_hbox.add_child(detail_tex_rect)
  else:
    var final_tex_rect = TextureRect.new()
    final_tex_rect.custom_minimum_size = Vector2(56, 56)
    final_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    final_tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    var final_tex = _load_texture(FINAL_RECIPE.image)
    if final_tex:
      final_tex_rect.texture = final_tex
    title_hbox.add_child(final_tex_rect)

  var title_label = Label.new()
  title_label.text = recipe.id
  title_label.add_theme_font_size_override("font_size", 42)
  title_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
  title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  title_label.add_theme_constant_override("outline_size", 3)
  title_hbox.add_child(title_label)

  # Separator
  var sep = HSeparator.new()
  sep.add_theme_constant_override("separation", 12)
  vbox.add_child(sep)

  # "필요 재료" header
  var req_label = Label.new()
  req_label.text = "필요 재료"
  req_label.add_theme_font_size_override("font_size", 28)
  req_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
  vbox.add_child(req_label)

  # Ingredients list
  var can_craft = true
  for ingredient in recipe.ingredients:
    var ing_id: String = ingredient.item_id
    var needed: int = ingredient.count
    var have: int = GameManager.get_item_count(ing_id)
    var discovered: bool = GameManager.is_item_discovered(ing_id)
    var enough = have >= needed

    if not enough:
      can_craft = false

    var row = HBoxContainer.new()
    row.add_theme_constant_override("separation", 16)
    vbox.add_child(row)

    # Ingredient image or emoji
    var img_container = PanelContainer.new()
    img_container.custom_minimum_size = Vector2(80, 80)
    var img_style = StyleBoxFlat.new()
    img_style.bg_color = Color(0.1, 0.1, 0.15)
    img_style.corner_radius_top_left = 10
    img_style.corner_radius_top_right = 10
    img_style.corner_radius_bottom_left = 10
    img_style.corner_radius_bottom_right = 10
    img_container.add_theme_stylebox_override("panel", img_style)
    row.add_child(img_container)

    if not discovered:
      # Undiscovered — show "?"
      var q_center = CenterContainer.new()
      q_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
      q_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
      img_container.add_child(q_center)
      var q_label = Label.new()
      q_label.text = "?"
      q_label.add_theme_font_size_override("font_size", 40)
      q_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.4))
      q_center.add_child(q_label)
    else:
      var img_path = _get_item_image_path(ing_id)
      if img_path != "":
        var tex_rect = TextureRect.new()
        tex_rect.custom_minimum_size = Vector2(68, 68)
        tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
        var tex = _load_texture(img_path)
        if tex:
          tex_rect.texture = tex
        img_container.add_child(tex_rect)
      else:
        # Crafted item — show image
        var part_img_path = _get_crafted_item_image(ing_id)
        var part_tex_rect = TextureRect.new()
        part_tex_rect.custom_minimum_size = Vector2(68, 68)
        part_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        part_tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
        var part_tex = _load_texture(part_img_path)
        if part_tex:
          part_tex_rect.texture = part_tex
        img_container.add_child(part_tex_rect)

    # Name + count
    var info = VBoxContainer.new()
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    info.add_theme_constant_override("separation", 4)
    row.add_child(info)

    var ing_name = Label.new()
    ing_name.text = "???" if not discovered else ing_id
    ing_name.add_theme_font_size_override("font_size", 24)
    ing_name.add_theme_color_override("font_color", Color(0.3, 0.3, 0.4) if not discovered else Color(0.9, 0.9, 0.9))
    info.add_child(ing_name)

    var count_label = Label.new()
    count_label.text = "0 / %d" % needed if not discovered else "%d / %d" % [have, needed]
    count_label.add_theme_font_size_override("font_size", 22)
    if not discovered:
      count_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.4))
    else:
      count_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.55) if enough else Color(0.9, 0.3, 0.3))
    info.add_child(count_label)

    # Check/cross indicator
    var indicator = Label.new()
    if not discovered:
      indicator.text = "?"
      indicator.add_theme_color_override("font_color", Color(0.3, 0.3, 0.4))
    else:
      indicator.text = "v" if enough else "x"
      indicator.add_theme_color_override("font_color", Color(0.3, 0.8, 0.55) if enough else Color(0.9, 0.3, 0.3))
    indicator.add_theme_font_size_override("font_size", 32)
    row.add_child(indicator)

  # Separator before buttons
  var sep2 = HSeparator.new()
  sep2.add_theme_constant_override("separation", 8)
  vbox.add_child(sep2)

  # Button row
  var btn_hbox = HBoxContainer.new()
  btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
  btn_hbox.add_theme_constant_override("separation", 20)
  vbox.add_child(btn_hbox)

  # 최종 조립에서 졸음 약만 부족한 경우 힌트 표시
  var is_final = recipe.id == FINAL_RECIPE.id
  if is_final and not can_craft:
    var hint = Label.new()
    hint.text = "한가지 재료가 부족한 것 같다.."
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_font_size_override("font_size", 22)
    hint.add_theme_color_override("font_color", Color(0.7, 0.5, 0.8))
    hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    hint.add_theme_constant_override("outline_size", 2)
    vbox.add_child(hint)

  # Craft button
  var craft_btn = Button.new()
  craft_btn.text = "조합" if can_craft else "재료 부족"
  craft_btn.custom_minimum_size = Vector2(220, 70)
  craft_btn.add_theme_font_size_override("font_size", 28)
  craft_btn.disabled = not can_craft
  if can_craft:
    craft_btn.pressed.connect(_on_craft_pressed.bind(recipe))
  GameManager.style_button(craft_btn)
  btn_hbox.add_child(craft_btn)

  # Close button
  var close_btn_detail = Button.new()
  close_btn_detail.text = "닫기"
  close_btn_detail.custom_minimum_size = Vector2(160, 70)
  close_btn_detail.add_theme_font_size_override("font_size", 28)
  close_btn_detail.pressed.connect(_close_recipe_detail)
  GameManager.style_button(close_btn_detail, "muted")
  btn_hbox.add_child(close_btn_detail)

func _close_recipe_detail() -> void:
  GameManager.play_button_click()
  detail_container.visible = false
  for child in detail_container.get_children():
    child.queue_free()

func _on_craft_pressed(recipe: Dictionary) -> void:
  # Verify all ingredients available
  if not _can_craft(recipe):
    return
  GameManager.play_craft_sound()

  # Suppress inventory_changed refreshes during batch operations
  _crafting = true

  # Consume ingredients
  for ingredient in recipe.ingredients:
    GameManager.remove_item(ingredient.item_id, ingredient.count)

  # Add crafted item
  GameManager.add_item(recipe.id)

  # 최종 조립(이세계 트럭) 완료 시 플래그 저장
  if recipe.id == FINAL_RECIPE.id:
    GameManager.truck_assembled = true

  _crafting = false

  # Save immediately
  SaveManager.save_game()

  # Close detail and refresh
  _close_recipe_detail()
  _refresh_all()

# ── Helpers ──

func _can_craft(recipe: Dictionary) -> bool:
  for ingredient in recipe.ingredients:
    if GameManager.get_item_count(ingredient.item_id) < ingredient.count:
      return false
  return true

func _count_fulfilled_ingredients(recipe: Dictionary) -> int:
  var count = 0
  for ingredient in recipe.ingredients:
    if GameManager.get_item_count(ingredient.item_id) >= ingredient.count:
      count += 1
  return count

func _get_item_image_path(item_id: String) -> String:
  for item in ALL_ITEMS:
    if item.id == item_id:
      return item.image
  return ""

func _get_final_recipe_required(item_id: String) -> int:
  for ingredient in FINAL_RECIPE.ingredients:
    if ingredient.item_id == item_id:
      return ingredient.count
  return 0

func _get_crafted_item_image(item_id: String) -> String:
  for item in CRAFTED_ITEMS:
    if item.id == item_id:
      return item.get("image", "")
  return ""

func _load_texture(res_path: String) -> Texture2D:
  if not ResourceLoader.exists(res_path):
    return null
  return load(res_path)

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
