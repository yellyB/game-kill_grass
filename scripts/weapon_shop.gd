extends Control

signal panel_opened
signal panel_closed

@onready var panel: Panel = $Panel
@onready var toggle_btn: Button = $ToggleBtn
@onready var close_btn: Button = $Panel/CloseBtn
@onready var weapon_image: TextureRect = $Panel/WeaponImage
@onready var next_weapon_label: Label = $Panel/NextWeaponLabel
@onready var upgrade_btn: Button = $Panel/UpgradeBtn
@onready var stats_label: Label = $Panel/StatsLabel

var is_open: bool = false
var show_toggle_button: bool = true

func _ready() -> void:
  panel.visible = false
  toggle_btn.pressed.connect(_on_toggle_pressed)
  close_btn.pressed.connect(_on_close_pressed)
  upgrade_btn.pressed.connect(_on_upgrade_pressed)

  GameManager.money_changed.connect(_on_money_changed)
  GameManager.upgrade_purchased.connect(_on_upgrade_purchased)
  WeaponManager.weapon_changed.connect(_on_weapon_changed)

  update_display()
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
  update_display()
  panel_opened.emit()

func _on_toggle_pressed() -> void:
  GameManager.play_button_click()
  is_open = !is_open
  panel.visible = is_open
  if is_open:
    update_display()
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

func _on_upgrade_pressed() -> void:
  GameManager.play_confirm_click()
  if WeaponManager.purchase_next_weapon():
    GameManager.play_weapon_upgrade_sound()
    SaveManager.save_game()
    update_display()
    # Play upgrade effect
    var tween = create_tween()
    weapon_image.scale = Vector2(1.3, 1.3)
    tween.tween_property(weapon_image, "scale", Vector2(1.0, 1.0), 0.2)

func _on_money_changed(_amount: int) -> void:
  if is_open:
    update_display()

func _on_weapon_changed(_level: int) -> void:
  update_display()

func _on_upgrade_purchased(_type: String, _level: int) -> void:
  if is_open:
    update_display()

func update_display() -> void:
  var next = WeaponManager.get_next_weapon()

  # Remove previous coin children from button
  for child in upgrade_btn.get_children():
    child.queue_free()

  if next.is_empty():
    # Max level reached
    weapon_image.texture = WeaponManager.get_weapon_texture()
    next_weapon_label.text = "최고 단계 도달!"
    stats_label.text = ""
    upgrade_btn.text = "MAX"
    upgrade_btn.disabled = true
  else:
    var next_level = WeaponManager.current_weapon_level + 1
    # Show next weapon image
    if next_level < WeaponManager.weapon_textures.size():
      weapon_image.texture = WeaponManager.weapon_textures[next_level]

    next_weapon_label.text = next.name
    stats_label.text = "대미지: %d" % next.damage

    upgrade_btn.text = ""
    var vbox = VBoxContainer.new()
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_theme_constant_override("separation", 4)
    vbox.anchors_preset = Control.PRESET_CENTER
    vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
    vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
    vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var title_lbl = Label.new()
    title_lbl.text = "업그레이드"
    title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_lbl.add_theme_font_size_override("font_size", 35)
    title_lbl.add_theme_color_override("font_color", Color.WHITE)
    title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vbox.add_child(title_lbl)

    var coin_hbox = GameManager.create_coin_label(
      GameManager.format_number(next.price), 35, Color.WHITE, 0, true)
    vbox.add_child(coin_hbox)

    var skill_req = WeaponManager.get_next_weapon_skill_requirement()
    var total_skill = GameManager.get_total_skill_level()
    if not WeaponManager.has_enough_skill_points():
      var suffix_lbl = Label.new()
      suffix_lbl.text = "(스킬 %d/%d 필요)" % [total_skill, skill_req]
      suffix_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
      suffix_lbl.add_theme_font_size_override("font_size", 28)
      suffix_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
      suffix_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
      vbox.add_child(suffix_lbl)
      upgrade_btn.disabled = true
    else:
      upgrade_btn.disabled = not WeaponManager.can_upgrade()

    upgrade_btn.add_child(vbox)

  # Update toggle button with current weapon level
  toggle_btn.text = "무기\nLv.%d" % (WeaponManager.current_weapon_level + 1)
