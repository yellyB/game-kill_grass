extends CanvasLayer

@onready var money_display = $MoneyDisplay
@onready var money_label: Label = $MoneyDisplay/MoneyLabel
@onready var item_notif_container: VBoxContainer = $ItemNotifContainer
@onready var stats_container: VBoxContainer = $StatsContainer

# Stats labels
@onready var weapon_label: Label = $StatsContainer/WeaponLabel
@onready var weapon_stats_label: Label = $StatsContainer/WeaponStatsLabel
@onready var grass_density_label: Label = $StatsContainer/GrassDensityLabel
@onready var grass_quality_label: Label = $StatsContainer/GrassQualityLabel

var displayed_money: int = 0
var target_money: int = 0
var buff_labels: Dictionary = {}  # type -> Label
var perm_buff_labels: Dictionary = {}  # type -> Label

# Monster arrow indicators (내비게이션 부품)
const ARROW_SIZE: float = 14.0
const ARROW_COLOR: Color = Color(1, 0.2, 0.2, 0.85)
const ARROW_MARGIN: float = 50.0
const MAX_ARROWS: int = 20
var arrow_pool: Array = []
var arrow_container: Node2D = null

func _ready() -> void:
  GameManager.session_money_changed.connect(_on_session_money_changed)
  GameManager.upgrade_purchased.connect(_on_upgrade_purchased)
  GameManager.item_added.connect(_on_item_added)
  GameManager.key_acquired.connect(_on_key_acquired)
  GameManager.powerup_acquired.connect(_on_powerup_acquired)
  GameManager.timed_buff_started.connect(_on_timed_buff_started)
  GameManager.timed_buff_ended.connect(_on_timed_buff_ended)
  WeaponManager.weapon_changed.connect(_on_weapon_changed)

  # Position UI elements with unified screen padding
  _position_stats_container()
  _position_notif_container()

  # Create buff timer container (below timer, centered)
  _create_buff_container()
  _setup_monster_arrows()

  # 세션 금액 표시: 초록색으로 변경, total money 자동 업데이트 해제
  money_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5, 1.0))
  if GameManager.money_changed.is_connected(money_display._on_money_changed):
    GameManager.money_changed.disconnect(money_display._on_money_changed)

  # Initialize display (session earnings)
  displayed_money = GameManager.session_money
  target_money = GameManager.session_money
  update_money_display()
  update_stats_display()

  # Connect player_hit signal (deferred to ensure player exists)
  call_deferred("_connect_player_hit")

func _position_stats_container() -> void:
  var pad_h = GameManager.SCREEN_PADDING_H
  var pad_v = GameManager.SCREEN_PADDING_V
  stats_container.offset_left = pad_h
  stats_container.offset_top = pad_v
  stats_container.offset_right = 400.0
  stats_container.offset_bottom = 200.0

func _position_notif_container() -> void:
  var pad_h = GameManager.SCREEN_PADDING_H
  var pad_v = GameManager.SCREEN_PADDING_V
  item_notif_container.anchor_left = 1.0
  item_notif_container.anchor_right = 1.0
  item_notif_container.offset_left = -350.0
  item_notif_container.offset_top = pad_v + 120.0
  item_notif_container.offset_right = -pad_h
  item_notif_container.offset_bottom = 400.0

func _process(delta: float) -> void:
  # Update timed buff countdowns
  _update_buff_timers()
  _update_monster_arrows()

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
  tween.tween_property(money_display, "scale", Vector2(1.2, 1.2), 0.05)
  tween.tween_property(money_display, "scale", Vector2(1.0, 1.0), 0.1)

func update_money_display() -> void:
  money_label.text = GameManager.format_number(displayed_money)


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

  if grass_density >= GameManager.get_skill_max_level("grass_density"):
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

const PERSISTENT_BUFFS = ["attack_speed", "attack_range", "magnet_range", "move_speed"]

func _on_powerup_acquired(type: String, level: int) -> void:
  var pname = POWERUP_NAMES.get(type, type)
  var pcolor = POWERUP_COLORS.get(type, Color.WHITE)
  var text: String

  # Special display for different powerup types
  if type == "double_or_dust":
    if level == 1:
      text = "DOUBLE! 코인 2배!"
      pcolor = Color(1.0, 0.85, 0.0)
    else:
      text = "DUST! 코인 증발..."
      pcolor = Color(0.5, 0.1, 0.1)
  elif level > 0 and type in ["attack_speed", "attack_range", "magnet_range", "move_speed"]:
    text = "%s Lv.%d!" % [pname, level]
  else:
    text = "%s!" % pname

  _show_notif(text, pcolor)

  # Update persistent buff display
  if type in PERSISTENT_BUFFS:
    _update_perm_buff(type, level)

const WORLD_NAMES: Array = ["슬라임 늪", "들판", "마법의 숲", "용의 봉우리"]

func _on_key_acquired(world_index: int) -> void:
  var world_name = WORLD_NAMES[world_index] if world_index < WORLD_NAMES.size() else "월드 %d" % world_index
  _show_notif("+ 열쇠 (%s)" % world_name, Color(0.3, 1.0, 1.0))

func _on_item_added(item_id: String, _total_count: int) -> void:
  _show_notif("+ %s" % item_id, Color(1, 0.9, 0.4))

func _show_notif(text: String, color: Color = Color.WHITE, font_size: int = 50, display_time: float = 1.5) -> void:
  var label = Label.new()
  label.text = text
  label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
  label.add_theme_font_size_override("font_size", font_size)
  label.add_theme_color_override("font_color", color)
  label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  label.add_theme_constant_override("outline_size", 3)
  var bg = StyleBoxFlat.new()
  bg.bg_color = Color(0.2, 0.2, 0.2, 0.4)
  bg.set_corner_radius_all(6)
  bg.content_margin_left = 8
  bg.content_margin_right = 8
  bg.content_margin_top = 3
  bg.content_margin_bottom = 3
  label.add_theme_stylebox_override("normal", bg)
  item_notif_container.add_child(label)

  var tween = create_tween()
  tween.tween_interval(display_time)
  tween.tween_property(label, "modulate:a", 0.0, 0.5)
  tween.tween_callback(label.queue_free)

func _connect_player_hit() -> void:
  var player = get_tree().get_first_node_in_group("player")
  if player and player.has_signal("player_hit"):
    player.player_hit.connect(_on_player_hit)

func _on_player_hit() -> void:
  pass


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
  "harvest_madness": "하베스트 매드니스",
  "overdrive": "오버드라이브",
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

# ── Monster Arrow Indicators (내비게이션) ──

func _setup_monster_arrows() -> void:
  arrow_container = Node2D.new()
  add_child(arrow_container)
  for i in MAX_ARROWS:
    var arrow = Polygon2D.new()
    arrow.polygon = PackedVector2Array([
      Vector2(ARROW_SIZE, 0),
      Vector2(-ARROW_SIZE * 0.6, -ARROW_SIZE * 0.7),
      Vector2(-ARROW_SIZE * 0.6, ARROW_SIZE * 0.7),
    ])
    arrow.color = ARROW_COLOR
    arrow.visible = false
    arrow_container.add_child(arrow)
    arrow_pool.append(arrow)

func _update_monster_arrows() -> void:
  var has_navi = GameManager.get_item_count("이세계 내비게이션") >= 1
  if not has_navi:
    for arrow in arrow_pool:
      arrow.visible = false
    return

  var viewport_size = get_viewport().get_visible_rect().size
  var screen_center = viewport_size / 2.0
  var canvas_xform = get_viewport().get_canvas_transform()
  var monsters = get_tree().get_nodes_in_group("monsters")

  var arrow_idx = 0
  for monster in monsters:
    if arrow_idx >= MAX_ARROWS:
      break
    if not is_instance_valid(monster):
      continue
    if monster.has_method("take_damage") and monster.get("is_dead") == true:
      continue

    var screen_pos = canvas_xform * monster.global_position
    # Skip if on screen
    if screen_pos.x >= 0 and screen_pos.x <= viewport_size.x and screen_pos.y >= 0 and screen_pos.y <= viewport_size.y:
      continue

    var dir = (screen_pos - screen_center).normalized()
    var edge_pos = _get_arrow_edge_position(screen_center, dir, viewport_size)

    var arrow = arrow_pool[arrow_idx]
    arrow.position = edge_pos
    arrow.rotation = dir.angle()
    arrow.visible = true
    arrow_idx += 1

  for i in range(arrow_idx, MAX_ARROWS):
    arrow_pool[i].visible = false

func _get_arrow_edge_position(center: Vector2, dir: Vector2, vp_size: Vector2) -> Vector2:
  var half_w = vp_size.x / 2.0 - ARROW_MARGIN
  var half_h = vp_size.y / 2.0 - ARROW_MARGIN
  var t_x = INF
  var t_y = INF
  if dir.x != 0:
    t_x = abs(half_w / dir.x)
  if dir.y != 0:
    t_y = abs(half_h / dir.y)
  var t = min(t_x, t_y)
  return center + dir * t
