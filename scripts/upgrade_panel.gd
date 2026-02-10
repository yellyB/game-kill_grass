extends Control

signal panel_opened
signal panel_closed

@onready var panel: Panel = $Panel
@onready var attack_speed_btn: Button = $Panel/VBoxContainer/AttackSpeedBtn
@onready var attack_range_btn: Button = $Panel/VBoxContainer/AttackRangeBtn
@onready var drop_rate_btn: Button = $Panel/VBoxContainer/DropRateBtn
@onready var magnet_range_btn: Button = $Panel/VBoxContainer/MagnetRangeBtn
@onready var grass_quality_btn: Button = $Panel/VBoxContainer/GrassQualityBtn
@onready var close_btn: Button = $Panel/CloseBtn
@onready var toggle_btn: Button = $ToggleBtn

var is_open: bool = false

func _ready() -> void:
	panel.visible = false
	toggle_btn.pressed.connect(_on_toggle_pressed)
	close_btn.pressed.connect(_on_close_pressed)
	attack_speed_btn.pressed.connect(_on_attack_speed_pressed)
	attack_range_btn.pressed.connect(_on_attack_range_pressed)
	drop_rate_btn.pressed.connect(_on_drop_rate_pressed)
	magnet_range_btn.pressed.connect(_on_magnet_range_pressed)
	grass_quality_btn.pressed.connect(_on_grass_quality_pressed)

	GameManager.money_changed.connect(_on_money_changed)
	GameManager.upgrade_purchased.connect(_on_upgrade_purchased)

	update_button_texts()

func _on_toggle_pressed() -> void:
	is_open = !is_open
	panel.visible = is_open
	if is_open:
		update_button_texts()
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

func _on_attack_speed_pressed() -> void:
	GameManager.purchase_upgrade("attack_speed")

func _on_attack_range_pressed() -> void:
	GameManager.purchase_upgrade("attack_range")

func _on_drop_rate_pressed() -> void:
	GameManager.purchase_upgrade("drop_rate")

func _on_magnet_range_pressed() -> void:
	GameManager.purchase_upgrade("magnet_range")

func _on_grass_quality_pressed() -> void:
	GameManager.purchase_upgrade("grass_quality")

func _on_money_changed(_amount: int) -> void:
	if is_open:
		update_button_texts()

func _on_upgrade_purchased(_type: String, _level: int) -> void:
	update_button_texts()

func update_button_texts() -> void:
	var speed_cost = GameManager.get_upgrade_cost(GameManager.upgrade_attack_speed)
	var range_cost = GameManager.get_upgrade_cost(GameManager.upgrade_attack_range)
	var drop_cost = GameManager.get_upgrade_cost(GameManager.upgrade_drop_rate)
	var magnet_cost = GameManager.get_upgrade_cost(GameManager.upgrade_magnet_range)
	var quality_cost = GameManager.get_upgrade_cost(GameManager.upgrade_grass_quality)

	attack_speed_btn.text = "공격 속도 Lv.%d\n$%d" % [GameManager.upgrade_attack_speed + 1, speed_cost]
	attack_range_btn.text = "공격 범위 Lv.%d\n$%d" % [GameManager.upgrade_attack_range + 1, range_cost]
	drop_rate_btn.text = "드롭률 Lv.%d\n$%d" % [GameManager.upgrade_drop_rate + 1, drop_cost]
	magnet_range_btn.text = "수집 범위 Lv.%d\n$%d" % [GameManager.upgrade_magnet_range + 1, magnet_cost]
	grass_quality_btn.text = "풀 등급 Lv.%d\n$%d" % [GameManager.upgrade_grass_quality + 1, quality_cost]

	attack_speed_btn.disabled = GameManager.money < speed_cost
	attack_range_btn.disabled = GameManager.money < range_cost
	drop_rate_btn.disabled = GameManager.money < drop_cost
	magnet_range_btn.disabled = GameManager.money < magnet_cost
	grass_quality_btn.disabled = GameManager.money < quality_cost
