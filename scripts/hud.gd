extends CanvasLayer

@onready var money_label: Label = $MoneyContainer/MoneyLabel
@onready var item_notif_container: VBoxContainer = $ItemNotifContainer

# Stats labels
@onready var weapon_label: Label = $StatsContainer/WeaponLabel
@onready var weapon_stats_label: Label = $StatsContainer/WeaponStatsLabel
@onready var grass_density_label: Label = $StatsContainer/GrassDensityLabel
@onready var magnet_range_label: Label = $StatsContainer/MagnetRangeLabel
@onready var grass_quality_label: Label = $StatsContainer/GrassQualityLabel

var displayed_money: int = 0
var target_money: int = 0

func _ready() -> void:
  GameManager.session_money_changed.connect(_on_session_money_changed)
  GameManager.upgrade_purchased.connect(_on_upgrade_purchased)
  GameManager.item_added.connect(_on_item_added)
  GameManager.key_acquired.connect(_on_key_acquired)
  WeaponManager.weapon_changed.connect(_on_weapon_changed)

  # Initialize display (session earnings)
  displayed_money = GameManager.session_money
  target_money = GameManager.session_money
  update_money_display()
  update_stats_display()

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

func _on_session_money_changed(_new_amount: int) -> void:
  target_money = GameManager.session_money
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

  # Weapon stats (speed and range come from weapon)
  var weapon_speed = WeaponManager.get_weapon_speed()
  var weapon_range = WeaponManager.get_weapon_range()
  weapon_stats_label.text = "속도 x%.1f | 범위 x%.1f" % [weapon_speed, weapon_range]

  # Upgrade stats
  var grass_density = GameManager.get_grass_density_level()
  var magnet_range = GameManager.get_magnet_range()
  var grass_quality = GameManager.get_grass_quality_level()

  if grass_density >= GameManager.MAX_DENSITY_LEVEL:
    grass_density_label.text = "풀 밀도: Lv.%d (MAX)" % (grass_density + 1)
  else:
    grass_density_label.text = "풀 밀도: Lv.%d" % (grass_density + 1)
  magnet_range_label.text = "수집 범위: %.0f" % magnet_range
  grass_quality_label.text = "풀 등급: Lv.%d" % (grass_quality + 1)

const WORLD_NAMES: Array = ["슬라임 늪", "들판", "마법의 숲", "용의 봉우리"]

func _on_key_acquired(world_index: int) -> void:
  var world_name = WORLD_NAMES[world_index] if world_index < WORLD_NAMES.size() else "월드 %d" % world_index
  var label = Label.new()
  label.text = "+ 열쇠 (%s)" % world_name
  label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
  label.add_theme_font_size_override("font_size", 72)
  label.add_theme_color_override("font_color", Color(0.3, 1.0, 1.0))
  label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  label.add_theme_constant_override("outline_size", 3)
  item_notif_container.add_child(label)

  var tween = create_tween()
  tween.tween_interval(1.5)
  tween.tween_property(label, "modulate:a", 0.0, 0.5)
  tween.tween_callback(label.queue_free)

func _on_item_added(item_id: String, _total_count: int) -> void:
  var label = Label.new()
  label.text = "+ %s" % item_id
  label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
  label.add_theme_font_size_override("font_size", 72)
  label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
  label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  label.add_theme_constant_override("outline_size", 3)
  item_notif_container.add_child(label)

  # Fade out and remove
  var tween = create_tween()
  tween.tween_interval(1.5)
  tween.tween_property(label, "modulate:a", 0.0, 0.5)
  tween.tween_callback(label.queue_free)
