extends Control

@onready var panel: Panel = $Panel
@onready var attack_speed_btn: Button = $Panel/VBoxContainer/AttackSpeedBtn
@onready var attack_range_btn: Button = $Panel/VBoxContainer/AttackRangeBtn
@onready var drop_rate_btn: Button = $Panel/VBoxContainer/DropRateBtn
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

	GameManager.money_changed.connect(_on_money_changed)
	GameManager.upgrade_purchased.connect(_on_upgrade_purchased)

	update_button_texts()

func _on_toggle_pressed() -> void:
	is_open = !is_open
	panel.visible = is_open
	if is_open:
		update_button_texts()

func _on_close_pressed() -> void:
	is_open = false
	panel.visible = false

func _on_attack_speed_pressed() -> void:
	GameManager.purchase_upgrade("attack_speed")

func _on_attack_range_pressed() -> void:
	GameManager.purchase_upgrade("attack_range")

func _on_drop_rate_pressed() -> void:
	GameManager.purchase_upgrade("drop_rate")

func _on_money_changed(_amount: int) -> void:
	if is_open:
		update_button_texts()

func _on_upgrade_purchased(_type: String, _level: int) -> void:
	update_button_texts()

func update_button_texts() -> void:
	var speed_cost = GameManager.get_upgrade_cost(GameManager.upgrade_attack_speed)
	var range_cost = GameManager.get_upgrade_cost(GameManager.upgrade_attack_range)
	var drop_cost = GameManager.get_upgrade_cost(GameManager.upgrade_drop_rate)

	attack_speed_btn.text = "Attack Speed Lv.%d\n$%d" % [GameManager.upgrade_attack_speed + 1, speed_cost]
	attack_range_btn.text = "Attack Range Lv.%d\n$%d" % [GameManager.upgrade_attack_range + 1, range_cost]
	drop_rate_btn.text = "Drop Rate Lv.%d\n$%d" % [GameManager.upgrade_drop_rate + 1, drop_cost]

	attack_speed_btn.disabled = GameManager.money < speed_cost
	attack_range_btn.disabled = GameManager.money < range_cost
	drop_rate_btn.disabled = GameManager.money < drop_cost
