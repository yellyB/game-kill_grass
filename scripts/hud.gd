extends CanvasLayer

@onready var money_label: Label = $MoneyContainer/MoneyLabel
@onready var item_notif_container: VBoxContainer = $ItemNotifContainer

# Stats labels
@onready var weapon_label: Label = $StatsContainer/WeaponLabel
@onready var weapon_stats_label: Label = $StatsContainer/WeaponStatsLabel
@onready var grass_density_label: Label = $StatsContainer/GrassDensityLabel
@onready var grass_quality_label: Label = $StatsContainer/GrassQualityLabel

var displayed_money: int = 0
var target_money: int = 0
var buff_labels: Dictionary = {}  # type -> Label
var perm_buff_labels: Dictionary = {}  # type -> Label

func _ready() -> void:
  GameManager.session_money_changed.connect(_on_session_money_changed)
  GameManager.upgrade_purchased.connect(_on_upgrade_purchased)
  GameManager.item_added.connect(_on_item_added)
  GameManager.key_acquired.connect(_on_key_acquired)
  GameManager.powerup_acquired.connect(_on_powerup_acquired)
  GameManager.timed_buff_started.connect(_on_timed_buff_started)
  GameManager.timed_buff_ended.connect(_on_timed_buff_ended)
  WeaponManager.weapon_changed.connect(_on_weapon_changed)

  # Create buff timer container (below timer, centered)
  _create_buff_container()

  # Initialize display (session earnings)
  displayed_money = GameManager.session_money
  target_money = GameManager.session_money
  update_money_display()
  update_stats_display()

  # Connect player_hit signal (deferred to ensure player exists)
  call_deferred("_connect_player_hit")

func _process(delta: float) -> void:
  # Update timed buff countdowns
  _update_buff_timers()

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

  weapon_stats_label.text = "대미지: %d" % WeaponManager.get_weapon_damage()

  # Upgrade stats
  var grass_density = GameManager.get_grass_density_level()
  var grass_quality = GameManager.get_grass_quality_level()

  if grass_density >= GameManager.MAX_DENSITY_LEVEL:
    grass_density_label.text = "풀 밀도: Lv.%d (MAX)" % (grass_density + 1)
  else:
    grass_density_label.text = "풀 밀도: Lv.%d" % (grass_density + 1)
  grass_quality_label.text = "풀 등급: Lv.%d" % (grass_quality + 1)

const POWERUP_NAMES = {
  "attack_speed": "어택 부스트",
  "attack_range": "와이드 어택",
  "magnet_range": "메가 마그넷",
  "move_speed": "라이트닝 대시",
  "extra_time": "엑스트라 타임",
  "gold_rush": "골드 러시",
  "golden_bloom": "골든 블룸",
  "double_or_dust": "더블 오어 더스트",
  "beast_rush": "비스트 러시",
  "overdrive": "오버드라이브",
  "harvest_madness": "하베스트 매드니스",
  "field_clear": "필드 클리어",
  "blackhole": "블랙홀",
}
const POWERUP_COLORS = {
  "attack_speed": Color(1.0, 0.5, 0.2),
  "attack_range": Color(0.3, 0.6, 1.0),
  "magnet_range": Color(0.2, 1.0, 0.8),
  "move_speed": Color(1.0, 1.0, 0.3),
  "extra_time": Color(0.4, 1.0, 0.4),
  "gold_rush": Color(1.0, 0.85, 0.0),
  "golden_bloom": Color(1.0, 0.9, 0.2),
  "double_or_dust": Color(0.8, 0.2, 0.8),
  "beast_rush": Color(0.9, 0.2, 0.2),
  "overdrive": Color(1.0, 0.3, 0.5),
  "harvest_madness": Color(1.0, 0.5, 1.0),
  "field_clear": Color(0.3, 1.0, 0.3),
  "blackhole": Color(0.5, 0.2, 0.8),
}

const PERSISTENT_BUFFS = ["attack_speed", "attack_range", "magnet_range", "move_speed", "overdrive"]

func _on_powerup_acquired(type: String, level: int) -> void:
  var pname = POWERUP_NAMES.get(type, type)
  var pcolor = POWERUP_COLORS.get(type, Color.WHITE)
  var label = Label.new()

  # Special display for different powerup types
  if type == "double_or_dust":
    if level == 1:
      label.text = "DOUBLE! 코인 2배!"
      pcolor = Color(1.0, 0.85, 0.0)
    else:
      label.text = "DUST! 코인 증발..."
      pcolor = Color(0.5, 0.1, 0.1)
  elif level > 0 and type in ["attack_speed", "attack_range", "magnet_range", "move_speed"]:
    label.text = "%s Lv.%d!" % [pname, level]
  else:
    label.text = "%s!" % pname

  label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
  label.add_theme_font_size_override("font_size", 72)
  label.add_theme_color_override("font_color", pcolor)
  label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  label.add_theme_constant_override("outline_size", 3)
  item_notif_container.add_child(label)

  var tween = create_tween()
  tween.tween_interval(1.5)
  tween.tween_property(label, "modulate:a", 0.0, 0.5)
  tween.tween_callback(label.queue_free)

  # Update persistent buff display
  if type in PERSISTENT_BUFFS:
    _update_perm_buff(type, level)

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

func _connect_player_hit() -> void:
  var player = get_tree().get_first_node_in_group("player")
  if player and player.has_signal("player_hit"):
    player.player_hit.connect(_on_player_hit)

func _on_player_hit() -> void:
  var label = Label.new()
  label.text = "SLOW!"
  label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
  label.add_theme_font_size_override("font_size", 80)
  label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
  label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  label.add_theme_constant_override("outline_size", 4)
  item_notif_container.add_child(label)

  var tween = create_tween()
  tween.tween_interval(1.0)
  tween.tween_property(label, "modulate:a", 0.0, 0.5)
  tween.tween_callback(label.queue_free)


var buff_container: VBoxContainer

func _create_buff_container() -> void:
  buff_container = VBoxContainer.new()
  buff_container.anchors_preset = Control.PRESET_CENTER_TOP
  buff_container.anchor_left = 0.5
  buff_container.anchor_right = 0.5
  buff_container.offset_left = -120.0
  buff_container.offset_top = 120.0
  buff_container.offset_right = 120.0
  buff_container.offset_bottom = 300.0
  buff_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
  buff_container.add_theme_constant_override("separation", 4)
  add_child(buff_container)

const TIMED_BUFF_NAMES = {
  "gold_rush": "골드 러시",
  "beast_rush": "비스트 러시",
  "harvest_madness": "하베스트 매드니스",
}

func _on_timed_buff_started(type: String, _duration: float) -> void:
  if buff_labels.has(type):
    return
  var label = Label.new()
  label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  label.add_theme_font_size_override("font_size", 28)
  label.add_theme_color_override("font_color", POWERUP_COLORS.get(type, Color.WHITE))
  label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  label.add_theme_constant_override("outline_size", 3)
  buff_container.add_child(label)
  buff_labels[type] = label

func _on_timed_buff_ended(type: String) -> void:
  if buff_labels.has(type):
    buff_labels[type].queue_free()
    buff_labels.erase(type)

func _update_buff_timers() -> void:
  for type in buff_labels:
    var label = buff_labels[type]
    if not is_instance_valid(label):
      continue
    var remaining = GameManager.get_timed_buff_remaining(type)
    var buff_name = TIMED_BUFF_NAMES.get(type, type)
    label.text = "%s %.1fs" % [buff_name, remaining]

func _update_perm_buff(type: String, level: int) -> void:
  var pname = POWERUP_NAMES.get(type, type)
  var pcolor = POWERUP_COLORS.get(type, Color.WHITE)

  if perm_buff_labels.has(type) and is_instance_valid(perm_buff_labels[type]):
    # Update existing label
    if type == "overdrive":
      perm_buff_labels[type].text = pname
    else:
      perm_buff_labels[type].text = "%s Lv.%d" % [pname, level]
    return

  var label = Label.new()
  label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  label.add_theme_font_size_override("font_size", 28)
  label.add_theme_color_override("font_color", pcolor)
  label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  label.add_theme_constant_override("outline_size", 3)
  if type == "overdrive":
    label.text = pname
  else:
    label.text = "%s Lv.%d" % [pname, level]
  buff_container.add_child(label)
  perm_buff_labels[type] = label
