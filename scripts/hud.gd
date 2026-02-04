extends CanvasLayer

@onready var money_label: Label = $MoneyContainer/MoneyLabel
@onready var combo_label: Label = $ComboContainer/ComboLabel
@onready var combo_container: Control = $ComboContainer

var displayed_money: int = 0
var target_money: int = 0

func _ready() -> void:
	GameManager.money_changed.connect(_on_money_changed)
	GameManager.combo_changed.connect(_on_combo_changed)
	GameManager.combo_ended.connect(_on_combo_ended)

	# Initialize display
	displayed_money = GameManager.money
	target_money = GameManager.money
	update_money_display()
	combo_container.visible = false

func _process(delta: float) -> void:
	# Smooth money counter
	if displayed_money != target_money:
		var diff = target_money - displayed_money
		var change = int(max(abs(diff) * delta * 10, 1))
		if diff > 0:
			displayed_money = min(displayed_money + change, target_money)
		else:
			displayed_money = max(displayed_money - change, target_money)
		update_money_display()

func _on_money_changed(new_amount: int) -> void:
	target_money = new_amount
	# Pop effect on money label
	var tween = create_tween()
	tween.tween_property(money_label, "scale", Vector2(1.2, 1.2), 0.05)
	tween.tween_property(money_label, "scale", Vector2(1.0, 1.0), 0.1)

func _on_combo_changed(new_combo: int) -> void:
	combo_container.visible = true
	combo_label.text = "x" + str(new_combo)

	# Pop effect
	var tween = create_tween()
	combo_label.scale = Vector2(1.5, 1.5)
	tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.15)

	# Color based on combo
	if new_combo >= 50:
		combo_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	elif new_combo >= 20:
		combo_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
	elif new_combo >= 10:
		combo_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	else:
		combo_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))

func _on_combo_ended() -> void:
	# Fade out combo
	var tween = create_tween()
	tween.tween_property(combo_container, "modulate:a", 0.0, 0.3)
	await tween.finished
	combo_container.visible = false
	combo_container.modulate.a = 1.0

func update_money_display() -> void:
	money_label.text = "$" + format_number(displayed_money)

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
