extends HBoxContainer

@onready var coin_icon: TextureRect = $CoinIcon
@onready var money_label: Label = $MoneyLabel

func _ready() -> void:
  # Force top-right anchor (Godot editor sometimes overrides in parent scenes)
  anchor_left = 1.0
  anchor_right = 1.0
  anchor_top = 0.0
  anchor_bottom = 0.0
  offset_left = -280.0
  offset_top = 20.0
  offset_right = -20.0
  offset_bottom = 70.0
  grow_horizontal = GROW_DIRECTION_BEGIN
  GameManager.money_changed.connect(_on_money_changed)
  update_display()

func _on_money_changed(_amount: int) -> void:
  update_display()

func update_display() -> void:
  money_label.text = format_number(GameManager.money)

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
