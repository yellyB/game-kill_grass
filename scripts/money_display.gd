extends HBoxContainer

@onready var coin_icon: TextureRect = $CoinIcon
@onready var money_label: Label = $MoneyLabel

func _ready() -> void:
  GameManager.money_changed.connect(_on_money_changed)
  update_display()

func _on_money_changed(_amount: int) -> void:
  update_display()

func update_display() -> void:
  money_label.text = GameManager.format_number(GameManager.money)

