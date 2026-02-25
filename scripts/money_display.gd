extends HBoxContainer

@onready var coin_icon: TextureRect = $CoinIcon
@onready var money_label: Label = $MoneyLabel

func _ready() -> void:
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
