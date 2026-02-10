extends CanvasLayer

@onready var money_label: Label = $MoneyContainer/MoneyLabel

# Stats labels
@onready var weapon_label: Label = $StatsContainer/WeaponLabel
@onready var attack_speed_label: Label = $StatsContainer/AttackSpeedLabel
@onready var attack_range_label: Label = $StatsContainer/AttackRangeLabel
@onready var drop_rate_label: Label = $StatsContainer/DropRateLabel
@onready var magnet_range_label: Label = $StatsContainer/MagnetRangeLabel
@onready var grass_quality_label: Label = $StatsContainer/GrassQualityLabel

# Debug UI (only in debug builds)
@onready var debug_container: Control = $DebugContainer

var displayed_money: int = 0
var target_money: int = 0

func _ready() -> void:
  GameManager.money_changed.connect(_on_money_changed)
  GameManager.upgrade_purchased.connect(_on_upgrade_purchased)
  WeaponManager.weapon_changed.connect(_on_weapon_changed)

  # Initialize display
  displayed_money = GameManager.money
  target_money = GameManager.money
  update_money_display()
  update_stats_display()

  # Show debug UI only in debug builds
  if debug_container:
    debug_container.visible = OS.is_debug_build()
    if OS.is_debug_build():
      var reset_btn = debug_container.get_node("ResetBtn")
      if reset_btn:
        reset_btn.pressed.connect(_on_reset_btn_pressed)
      var add_money_btn = debug_container.get_node("AddMoneyBtn")
      if add_money_btn:
        add_money_btn.pressed.connect(_on_add_money_btn_pressed)

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

func _on_upgrade_purchased(_type: String, _level: int) -> void:
  update_stats_display()

func _on_weapon_changed(_level: int) -> void:
  update_stats_display()

func update_stats_display() -> void:
  # Weapon info
  var weapon = WeaponManager.get_current_weapon()
  weapon_label.text = "무기: %s (Lv.%d)" % [weapon.name, WeaponManager.current_weapon_level + 1]

  # Final stats (base * weapon)
  var base_speed = GameManager.get_attack_speed()
  var base_range = GameManager.get_attack_range()
  var drop_mult = GameManager.get_drop_multiplier()
  var magnet_range = GameManager.get_magnet_range()
  var grass_quality = GameManager.get_grass_quality_level()

  var weapon_speed = WeaponManager.get_weapon_speed()
  var weapon_range = WeaponManager.get_weapon_range()

  var final_speed = base_speed * weapon_speed
  var final_range = base_range * weapon_range

  attack_speed_label.text = "공격 속도: x%.2f" % final_speed
  attack_range_label.text = "공격 범위: %.0f" % final_range
  drop_rate_label.text = "드롭률: x%.2f" % drop_mult
  magnet_range_label.text = "수집 범위: %.0f" % magnet_range
  grass_quality_label.text = "풀 등급: Lv.%d" % (grass_quality + 1)

func _on_reset_btn_pressed() -> void:
  SaveManager.reset_all_data()
  displayed_money = 0
  target_money = 0
  update_money_display()
  update_stats_display()

func _on_add_money_btn_pressed() -> void:
  GameManager.money += 100000
  GameManager.money_changed.emit(GameManager.money)
