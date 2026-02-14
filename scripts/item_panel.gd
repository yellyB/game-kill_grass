extends Control

signal panel_opened
signal panel_closed

@onready var panel: Panel = $Panel
@onready var toggle_btn: Button = $ToggleBtn
@onready var close_btn: Button = $Panel/CloseBtn
@onready var money_label: Label = $Panel/MoneyLabel

var is_open: bool = false
var show_toggle_button: bool = true

func _ready() -> void:
	panel.visible = false
	toggle_btn.pressed.connect(_on_toggle_pressed)
	close_btn.pressed.connect(_on_close_pressed)

	GameManager.money_changed.connect(_on_money_changed)
	update_money_display()
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
	update_money_display()
	panel_opened.emit()

func _on_toggle_pressed() -> void:
	is_open = !is_open
	panel.visible = is_open
	if is_open:
		update_money_display()
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

func _on_money_changed(_amount: int) -> void:
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
