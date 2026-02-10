extends Control

signal panel_opened
signal panel_closed

@onready var panel: Panel = $Panel
@onready var toggle_btn: Button = $ToggleBtn
@onready var close_btn: Button = $Panel/CloseBtn
@onready var weapon_name_label: Label = $Panel/WeaponNameLabel
@onready var weapon_desc_label: Label = $Panel/WeaponDescLabel
@onready var weapon_icon: ColorRect = $Panel/WeaponIcon
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
	is_open = !is_open
	panel.visible = is_open
	if is_open:
		update_display()
		panel_opened.emit()
	else:
		panel_closed.emit()

func _on_close_pressed() -> void:
	is_open = false
	panel.visible = false
	panel_closed.emit()

func _on_other_panel_opened() -> void:
	toggle_btn.disabled = true

func _on_other_panel_closed() -> void:
	toggle_btn.disabled = false

func _on_upgrade_pressed() -> void:
	if WeaponManager.purchase_next_weapon():
		update_display()
		# Play upgrade effect
		var tween = create_tween()
		weapon_icon.scale = Vector2(1.3, 1.3)
		tween.tween_property(weapon_icon, "scale", Vector2(1.0, 1.0), 0.2)

func _on_money_changed(_amount: int) -> void:
	if is_open:
		update_display()

func _on_weapon_changed(_level: int) -> void:
	update_display()

func update_display() -> void:
	var current = WeaponManager.get_current_weapon()
	var next = WeaponManager.get_next_weapon()

	# Current weapon info
	weapon_name_label.text = current.name
	weapon_desc_label.text = current.description
	weapon_icon.color = current.color

	# Stats
	stats_label.text = "범위: x%.1f | 속도: x%.1f" % [current.range_mult, current.speed_mult]

	# Next weapon info
	if next.is_empty():
		next_weapon_label.text = "최고 단계 도달!"
		upgrade_btn.text = "MAX"
		upgrade_btn.disabled = true
	else:
		next_weapon_label.text = "다음: %s" % next.name
		upgrade_btn.text = "업그레이드\n$%d" % next.price
		upgrade_btn.disabled = not WeaponManager.can_upgrade()

	# Update toggle button with current weapon level
	toggle_btn.text = "무기\nLv.%d" % (WeaponManager.current_weapon_level + 1)
