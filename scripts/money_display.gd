extends HBoxContainer

@onready var coin_icon: TextureRect = $CoinIcon
@onready var money_label: Label = $MoneyLabel

func _ready() -> void:
  var vp_size = get_viewport_rect().size
  var pad_h = GameManager.SCREEN_PADDING_H
  var pad_v = GameManager.SCREEN_PADDING_V
  var w = 260.0
  var h = 50.0
  anchor_left = 0.0
  anchor_right = 0.0
  anchor_top = 0.0
  anchor_bottom = 0.0
  offset_left = vp_size.x - w - pad_h
  offset_top = pad_v
  offset_right = vp_size.x - pad_h
  offset_bottom = pad_v + h
  grow_horizontal = GROW_DIRECTION_BEGIN
  GameManager.money_changed.connect(_on_money_changed)
  update_display()

func _on_money_changed(_amount: int) -> void:
  update_display()

func update_display() -> void:
  money_label.text = GameManager.format_number(GameManager.money)

