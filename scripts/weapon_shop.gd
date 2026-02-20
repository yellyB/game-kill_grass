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

func update_display() -> void:
	var next = WeaponManager.get_next_weapon()

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
		upgrade_btn.text = "업그레이드\n$%s" % format_number(next.price)
		upgrade_btn.disabled = not WeaponManager.can_upgrade()

	# Update toggle button with current weapon level
	toggle_btn.text = "무기\nLv.%d" % (WeaponManager.current_weapon_level + 1)

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
