extends Control

@onready var panel: Panel = $Panel
@onready var toggle_btn: Button = $ToggleBtn
@onready var close_btn: Button = $Panel/CloseBtn

# Weapon info
@onready var weapon_name_label: Label = $Panel/WeaponSection/WeaponContainer/WeaponInfo/WeaponNameLabel
@onready var weapon_icon: ColorRect = $Panel/WeaponSection/WeaponContainer/WeaponIcon
@onready var weapon_type_label: Label = $Panel/WeaponSection/WeaponContainer/WeaponInfo/WeaponTypeLabel

# Stats
@onready var attack_speed_label: Label = $Panel/StatsSection/AttackSpeedLabel
@onready var attack_range_label: Label = $Panel/StatsSection/AttackRangeLabel
@onready var drop_rate_label: Label = $Panel/StatsSection/DropRateLabel
@onready var final_speed_label: Label = $Panel/StatsSection/FinalSpeedLabel
@onready var final_range_label: Label = $Panel/StatsSection/FinalRangeLabel

# Progress
@onready var total_money_label: Label = $Panel/ProgressSection/TotalMoneyLabel
@onready var combo_label: Label = $Panel/ProgressSection/ComboLabel

var is_open: bool = false

func _ready() -> void:
	panel.visible = false
	toggle_btn.pressed.connect(_on_toggle_pressed)
	close_btn.pressed.connect(_on_close_pressed)

	GameManager.money_changed.connect(_on_stats_changed)
	GameManager.combo_changed.connect(_on_stats_changed)
	GameManager.upgrade_purchased.connect(_on_stats_changed_upgrade)
	WeaponManager.weapon_changed.connect(_on_weapon_changed)

func _on_toggle_pressed() -> void:
	is_open = !is_open
	panel.visible = is_open
	if is_open:
		update_display()

func _on_close_pressed() -> void:
	is_open = false
	panel.visible = false

func _on_stats_changed(_value = null) -> void:
	if is_open:
		update_display()

func _on_stats_changed_upgrade(_type: String, _level: int) -> void:
	if is_open:
		update_display()

func _on_weapon_changed(_level: int) -> void:
	if is_open:
		update_display()

func update_display() -> void:
	# Weapon info
	var weapon = WeaponManager.get_current_weapon()
	weapon_name_label.text = "%s (Lv.%d)" % [weapon.name, WeaponManager.current_weapon_level + 1]
	weapon_icon.color = weapon.color
	weapon_type_label.text = get_attack_type_text(weapon.attack_type)

	# Base stats from upgrades
	var base_speed = GameManager.get_attack_speed()
	var base_range = GameManager.get_attack_range()
	var drop_mult = GameManager.get_drop_multiplier()

	attack_speed_label.text = "공격 속도: x%.2f (Lv.%d)" % [base_speed, GameManager.upgrade_attack_speed + 1]
	attack_range_label.text = "공격 범위: %.0f (Lv.%d)" % [base_range, GameManager.upgrade_attack_range + 1]
	drop_rate_label.text = "드롭률: x%.2f (Lv.%d)" % [drop_mult, GameManager.upgrade_drop_rate + 1]

	# Final stats (base * weapon)
	var weapon_speed = WeaponManager.get_weapon_speed()
	var weapon_range = WeaponManager.get_weapon_range()
	var final_speed = base_speed * weapon_speed
	var final_range = base_range * weapon_range

	final_speed_label.text = "최종 속도: x%.2f" % final_speed
	final_range_label.text = "최종 범위: %.0f" % final_range

	# Progress
	total_money_label.text = "보유 골드: $%s" % format_number(GameManager.money)
	combo_label.text = "현재 콤보: x%d" % GameManager.combo

func get_attack_type_text(attack_type: String) -> String:
	match attack_type:
		"single":
			return "단일 공격"
		"double":
			return "이중 공격"
		"spin":
			return "회전 공격"
		"aura":
			return "범위 공격"
		"flame":
			return "화염 공격"
		"screen":
			return "화면 공격"
		"world":
			return "전체 공격"
		_:
			return "기본 공격"

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
