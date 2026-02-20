extends Control

signal panel_opened
signal panel_closed

@onready var panel: Panel = $Panel
@onready var grass_density_btn: Button = $Panel/VBoxContainer/GrassDensityBtn
@onready var grass_quality_btn: Button = $Panel/VBoxContainer/GrassQualityBtn
@onready var grass_regen_btn: Button = $Panel/VBoxContainer/GrassRegenBtn
@onready var description_label: Label = $Panel/DescriptionPanel/DescriptionLabel
@onready var confirm_btn: Button = $Panel/ConfirmBtn
@onready var close_btn: Button = $Panel/CloseBtn
@onready var toggle_btn: Button = $ToggleBtn
@onready var money_label: Label = $Panel/MoneyLabel

var is_open: bool = false
var selected_upgrade: String = ""
var show_toggle_button: bool = true

# Upgrade descriptions
const UPGRADE_INFO = {
  "grass_density": {
    "name": "풀 밀도",
    "description": "맵에 풀이 더 빽빽하게 자랍니다.",
    "stat_format": "풀 간격: %.1f → %.1f",
    "max_level": 10
  },
  "grass_quality": {
    "name": "풀 등급",
    "description": "더 높은 등급의 풀이 등장할 확률이 증가합니다.",
    "stat_format": "등급 레벨: %d → %d",
    "max_level": -1
  },
  "grass_regen": {
    "name": "풀 재생 속도",
    "description": "베어진 풀이 더 빨리 다시 자랍니다.",
    "stat_format": "재생 시간: %.1f초 → %.1f초",
    "max_level": 10
  }
}

func _ready() -> void:
  panel.visible = false
  toggle_btn.pressed.connect(_on_toggle_pressed)
  close_btn.pressed.connect(_on_close_pressed)
  confirm_btn.pressed.connect(_on_confirm_pressed)

  grass_density_btn.pressed.connect(_on_grass_density_selected)
  grass_quality_btn.pressed.connect(_on_grass_quality_selected)
  grass_regen_btn.pressed.connect(_on_grass_regen_selected)

  GameManager.money_changed.connect(_on_money_changed)
  GameManager.upgrade_purchased.connect(_on_upgrade_purchased)

  update_button_texts()
  update_money_display()
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
  update_button_texts()
  update_money_display()
  clear_selection()
  panel_opened.emit()

func _on_toggle_pressed() -> void:
  GameManager.play_button_click()
  is_open = !is_open
  panel.visible = is_open
  if is_open:
    update_button_texts()
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

func _on_grass_density_selected() -> void:
  GameManager.play_button_click()
  select_upgrade("grass_density")

func _on_grass_quality_selected() -> void:
  GameManager.play_button_click()
  select_upgrade("grass_quality")

func _on_grass_regen_selected() -> void:
  GameManager.play_button_click()
  select_upgrade("grass_regen")

func select_upgrade(upgrade_type: String) -> void:
  selected_upgrade = upgrade_type
  update_description()
  update_confirm_button()
  update_button_selection()

func clear_selection() -> void:
  selected_upgrade = ""
  description_label.text = "강화할 항목을 선택하세요"
  confirm_btn.disabled = true
  confirm_btn.text = "강화하기"
  update_button_selection()

func update_button_selection() -> void:
  # Visual feedback for selected button
  grass_density_btn.modulate = Color(1.0, 1.0, 0.5) if selected_upgrade == "grass_density" else Color(1, 1, 1)
  grass_quality_btn.modulate = Color(1.0, 1.0, 0.5) if selected_upgrade == "grass_quality" else Color(1, 1, 1)
  grass_regen_btn.modulate = Color(1.0, 1.0, 0.5) if selected_upgrade == "grass_regen" else Color(1, 1, 1)

func update_description() -> void:
  if selected_upgrade.is_empty():
    description_label.text = "강화할 항목을 선택하세요"
    return

  var info = UPGRADE_INFO[selected_upgrade]
  var current_level: int
  var cost: int
  var current_value: float
  var next_value: float

  match selected_upgrade:
    "grass_density":
      current_level = GameManager.upgrade_grass_density
      cost = GameManager.get_upgrade_cost(current_level)
      current_value = GameManager.get_grass_min_spacing()
      # Calculate next value
      var temp_level = GameManager.upgrade_grass_density
      GameManager.upgrade_grass_density += 1
      next_value = GameManager.get_grass_min_spacing()
      GameManager.upgrade_grass_density = temp_level
    "grass_quality":
      current_level = GameManager.upgrade_grass_quality
      cost = GameManager.get_upgrade_cost(current_level)
      current_value = current_level
      next_value = current_level + 1
    "grass_regen":
      current_level = GameManager.upgrade_grass_regen
      cost = GameManager.get_upgrade_cost(current_level)
      current_value = GameManager.get_grass_regen_time(22.0)
      var temp_level = GameManager.upgrade_grass_regen
      GameManager.upgrade_grass_regen += 1
      next_value = GameManager.get_grass_regen_time(22.0)
      GameManager.upgrade_grass_regen = temp_level

  # Check max level
  if info.max_level >= 0 and current_level >= info.max_level:
    description_label.text = "%s\n\n%s\n\n[최대 레벨 도달]" % [info.name, info.description]
    return

  var stat_change: String
  if selected_upgrade == "grass_quality":
    stat_change = info.stat_format % [int(current_value), int(next_value)]
  else:
    stat_change = info.stat_format % [current_value, next_value]

  description_label.text = "%s\n\n%s\n\n%s\n\n비용: $%s" % [info.name, info.description, stat_change, format_number(cost)]

func update_confirm_button() -> void:
  if selected_upgrade.is_empty():
    confirm_btn.disabled = true
    confirm_btn.text = "강화하기"
    return

  var current_level: int
  var max_level: int = -1
  var cost: int

  match selected_upgrade:
    "grass_density":
      current_level = GameManager.upgrade_grass_density
      max_level = GameManager.MAX_DENSITY_LEVEL
      cost = GameManager.get_upgrade_cost(current_level)
    "grass_quality":
      current_level = GameManager.upgrade_grass_quality
      cost = GameManager.get_upgrade_cost(current_level)
    "grass_regen":
      current_level = GameManager.upgrade_grass_regen
      max_level = GameManager.MAX_REGEN_LEVEL
      cost = GameManager.get_upgrade_cost(current_level)

  # Check max level
  if max_level >= 0 and current_level >= max_level:
    confirm_btn.disabled = true
    confirm_btn.text = "최대 레벨"
    return

  # Check money
  if GameManager.money < cost:
    confirm_btn.disabled = true
    confirm_btn.text = "돈 부족 ($%s)" % format_number(cost)
  else:
    confirm_btn.disabled = false
    confirm_btn.text = "강화하기 ($%s)" % format_number(cost)

func _on_confirm_pressed() -> void:
  GameManager.play_confirm_click()
  if selected_upgrade.is_empty():
    return

  if GameManager.purchase_upgrade(selected_upgrade):
    GameManager.play_skill_upgrade_sound()
    SaveManager.save_game()
    update_button_texts()
    update_description()
    update_confirm_button()

func _on_money_changed(_amount: int) -> void:
  update_money_display()
  if is_open:
    update_button_texts()
    update_confirm_button()

func _on_upgrade_purchased(_type: String, _level: int) -> void:
  update_button_texts()
  update_description()
  update_confirm_button()
  update_money_display()

func update_money_display() -> void:
  money_label.text = "$%s" % format_number(GameManager.money)

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

func update_button_texts() -> void:
  var density_level = GameManager.upgrade_grass_density
  var regen_level = GameManager.upgrade_grass_regen

  # Grass density has max level of 10
  if density_level >= GameManager.MAX_DENSITY_LEVEL:
    grass_density_btn.text = "풀 밀도 Lv.%d (MAX)" % density_level
  else:
    grass_density_btn.text = "풀 밀도 Lv.%d → Lv.%d" % [density_level, density_level + 1]

  grass_quality_btn.text = "풀 등급 Lv.%d → Lv.%d" % [GameManager.upgrade_grass_quality, GameManager.upgrade_grass_quality + 1]

  # Grass regen has max level of 10
  if regen_level >= GameManager.MAX_REGEN_LEVEL:
    grass_regen_btn.text = "풀 재생 Lv.%d (MAX)" % regen_level
  else:
    grass_regen_btn.text = "풀 재생 Lv.%d → Lv.%d" % [regen_level, regen_level + 1]
