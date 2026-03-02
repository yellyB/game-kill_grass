extends Node

# UI constants
const SCREEN_PADDING_H: float = 40.0
const SCREEN_PADDING_V: float = 60.0

# Game state
var money: int = 0
var session_money: int = 0

# Inventory - {item_id: count}
var inventory: Dictionary = {}
# Items discovered at least once (for UI display)
var discovered_items: Array = []

# World selection
var selected_world: int = 0
var unlocked_worlds: Array = [0]
var owned_keys: Array = []  # 소유 열쇠 목록 (예: [1] = 월드1 열쇠 보유)
var truck_assembled: bool = false  # 이세계 트럭 조립 완료 여부
var prologue_seen: bool = false
const WORLD_UNLOCK_COSTS: Array = [0, 2000, 10000, 50000]

signal world_unlocked(index: int)
signal key_acquired(world_index: int)

# Skill definitions — single source of truth for all skills
const SKILL_DEFS: Array = [
  {"type": "grass_density", "name": "풀 밀도", "short_name": "밀도", "max_level": 10,
   "description": "맵에 풀이 더 빽빽하게 자랍니다."},
  {"type": "grass_quality", "name": "풀 등급", "short_name": "등급", "max_level": 10,
   "description": "더 높은 등급의 풀이 등장할 확률이 증가합니다."},
  {"type": "grass_regen", "name": "풀 재생", "short_name": "재생", "max_level": 2,
   "description": "베어진 풀이 더 빨리 다시 자랍니다."},
  {"type": "grass_reward", "name": "풀 보상", "short_name": "보상", "max_level": 6,
   "description": "풀에서 떨어지는 코인이 증가합니다."},
  {"type": "penalty_reduce", "name": "패널티 감소", "short_name": "패널티", "max_level": 3,
   "description": "몬스터에게 맞았을 때 코인 손실이 줄어듭니다."},
  {"type": "grass_drop", "name": "드롭률 증가", "short_name": "드롭", "max_level": 5,
   "description": "풀에서 코인이 떨어질 확률이 증가합니다."},
  {"type": "golden_chance", "name": "황금풀 확률", "short_name": "황금", "max_level": 5,
   "description": "황금풀이 등장할 확률이 증가합니다."},
]

# Upgrades — Dictionary-based level management
var upgrade_levels: Dictionary = {}  # {"grass_density": 0, "grass_quality": 0, ...}

# Session powerup buffs (reset each session)
var session_buff_attack_speed: int = 0
var session_buff_attack_range: int = 0
var session_buff_magnet_range: int = 0
var session_buff_move_speed: int = 0

# Timed buffs: { "gold_rush": remaining_seconds, ... }
var timed_buffs: Dictionary = {}

# Hit penalty (50% attack speed & move speed reduction)
var hit_penalty_active: bool = false

# Upgrade costs (increases each level)
const BASE_UPGRADE_COST: int = 100
const UPGRADE_COST_MULTIPLIER: float = 1.8

# Game settings
var base_magnet_range: float = 65.0

# Grass settings
const GRASS_DROP_CHANCE: float = 1.0

# Grass data
var grass_data_list: Array[GrassData] = []

# Signals
signal money_changed(new_amount: int)
signal session_money_changed(new_amount: int)
signal upgrade_purchased(upgrade_type: String, level: int)
signal item_added(item_id: String, count: int)
signal inventory_changed()
signal powerup_acquired(type: String, level: int)
signal timed_buff_started(type: String, duration: float)
signal timed_buff_ended(type: String)
signal extra_time_requested(seconds: float)
signal golden_bloom_requested()
signal field_clear_requested()
signal blackhole_requested()
signal beast_rush_requested()

var _sfx_click: AudioStreamPlayer
var _sfx_confirm: AudioStreamPlayer
var _sfx_craft: AudioStreamPlayer
var _sfx_weapon_upgrade: AudioStreamPlayer
var _sfx_skill_upgrade: AudioStreamPlayer
var _sfx_unlock: AudioStreamPlayer

func _ready() -> void:
  process_mode = Node.PROCESS_MODE_ALWAYS
  # Initialize upgrade_levels from SKILL_DEFS
  for def in SKILL_DEFS:
    if not upgrade_levels.has(def.type):
      upgrade_levels[def.type] = 0
  _init_grass_data()
  _sfx_click = AudioStreamPlayer.new()
  _sfx_click.stream = preload("res://resources/sounds/effect/button_click.wav")
  _sfx_click.volume_db = -5.0
  add_child(_sfx_click)
  _sfx_confirm = AudioStreamPlayer.new()
  _sfx_confirm.stream = preload("res://resources/sounds/effect/confirm_button_click.wav")
  _sfx_confirm.volume_db = -3.0
  add_child(_sfx_confirm)
  _sfx_craft = AudioStreamPlayer.new()
  _sfx_craft.stream = preload("res://resources/sounds/effect/item_craft_short_hammer.wav")
  _sfx_craft.volume_db = -3.0
  add_child(_sfx_craft)
  _sfx_weapon_upgrade = AudioStreamPlayer.new()
  _sfx_weapon_upgrade.stream = preload("res://resources/sounds/effect/weapon_upgrade_success.wav")
  _sfx_weapon_upgrade.volume_db = -3.0
  add_child(_sfx_weapon_upgrade)
  _sfx_skill_upgrade = AudioStreamPlayer.new()
  _sfx_skill_upgrade.stream = preload("res://resources/sounds/effect/skill_upgrade_success.wav")
  _sfx_skill_upgrade.volume_db = -3.0
  add_child(_sfx_skill_upgrade)
  _sfx_unlock = AudioStreamPlayer.new()
  _sfx_unlock.stream = preload("res://resources/sounds/effect/unlock_world.wav")
  _sfx_unlock.volume_db = -3.0
  add_child(_sfx_unlock)

func play_button_click() -> void:
  _sfx_click.play()

func play_confirm_click() -> void:
  _sfx_confirm.play()

func play_craft_sound() -> void:
  _sfx_craft.play()

func play_weapon_upgrade_sound() -> void:
  _sfx_weapon_upgrade.play()

func play_skill_upgrade_sound() -> void:
  _sfx_skill_upgrade.play()

func play_unlock_sound() -> void:
  _sfx_unlock.play()

# ── Shared Button Style ──

const BUTTON_COLORS = {
  "main": Color(0.3, 0.75, 0.45),
  "muted": Color(0.45, 0.45, 0.5),
  "sub": Color(0.45, 0.62, 0.78),
}

const COIN_TEXTURE = preload("res://resources/images/coin.png")

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

# 코인 아이콘 + 금액 텍스트를 담은 HBoxContainer 생성
func create_coin_label(amount_text: String, font_size: int = 30,
    font_color: Color = Color(1, 0.9, 0.3), outline_size: int = 0,
    center: bool = false) -> HBoxContainer:
  var icon_size = int(font_size * 0.85)
  var hbox = HBoxContainer.new()
  hbox.add_theme_constant_override("separation", int(font_size * 0.2))
  hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
  if center:
    hbox.alignment = BoxContainer.ALIGNMENT_CENTER

  var icon = TextureRect.new()
  icon.texture = COIN_TEXTURE
  icon.expand_mode = TextureRect.EXPAND_FIT_HEIGHT
  icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  icon.custom_minimum_size = Vector2(icon_size, icon_size)
  icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
  hbox.add_child(icon)

  var label = Label.new()
  label.text = amount_text
  label.add_theme_font_size_override("font_size", font_size)
  label.add_theme_color_override("font_color", font_color)
  label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  if outline_size > 0:
    label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    label.add_theme_constant_override("outline_size", outline_size)
  hbox.add_child(label)

  return hbox

func style_button(btn: Button, color_type: String = "main", btn_size: Vector2 = Vector2.ZERO) -> void:
  var main_color = BUTTON_COLORS.get(color_type, BUTTON_COLORS["main"])
  if btn_size != Vector2.ZERO:
    var font_size = int(btn_size.y * 35.0 / 75.0)
    btn.custom_minimum_size = btn_size
    btn.add_theme_font_size_override("font_size", font_size)
    if btn.icon:
      var aspect = float(btn.icon.get_width()) / float(btn.icon.get_height())
      btn.add_theme_constant_override("icon_max_width", int(font_size * aspect))
    else:
      btn.add_theme_constant_override("icon_max_width", font_size)
  var shadow_color = main_color.darkened(0.3)

  # Normal
  var style_n = StyleBoxFlat.new()
  style_n.bg_color = main_color
  style_n.corner_radius_top_left = 18
  style_n.corner_radius_top_right = 18
  style_n.corner_radius_bottom_left = 18
  style_n.corner_radius_bottom_right = 18
  style_n.border_width_bottom = 6
  style_n.border_color = shadow_color
  style_n.content_margin_left = 48
  style_n.content_margin_right = 48
  style_n.content_margin_top = 12
  style_n.content_margin_bottom = 14
  btn.add_theme_stylebox_override("normal", style_n)

  # Hover
  var style_h = style_n.duplicate()
  style_h.bg_color = main_color.lightened(0.1)
  btn.add_theme_stylebox_override("hover", style_h)

  # Pressed
  var style_p = StyleBoxFlat.new()
  style_p.bg_color = main_color.darkened(0.1)
  style_p.corner_radius_top_left = 18
  style_p.corner_radius_top_right = 18
  style_p.corner_radius_bottom_left = 18
  style_p.corner_radius_bottom_right = 18
  style_p.border_width_bottom = 2
  style_p.border_color = shadow_color
  style_p.content_margin_left = 48
  style_p.content_margin_right = 48
  style_p.content_margin_top = 16
  style_p.content_margin_bottom = 10
  btn.add_theme_stylebox_override("pressed", style_p)

  # Disabled
  var style_d = style_n.duplicate()
  style_d.bg_color = main_color.darkened(0.4)
  style_d.border_color = shadow_color.darkened(0.4)
  btn.add_theme_stylebox_override("disabled", style_d)

  # Focus (remove default outline)
  var style_f = StyleBoxEmpty.new()
  btn.add_theme_stylebox_override("focus", style_f)

  # Font colors
  btn.add_theme_color_override("font_color", Color.WHITE)
  btn.add_theme_color_override("font_hover_color", Color.WHITE)
  btn.add_theme_color_override("font_pressed_color", Color.WHITE)
  btn.add_theme_color_override("font_disabled_color", Color(0.65, 0.65, 0.7))

func _process(delta: float) -> void:
  # Don't tick timed buffs while game is paused
  if get_tree().paused:
    return
  var expired: Array = []
  for buff_type in timed_buffs:
    timed_buffs[buff_type] -= delta
    if timed_buffs[buff_type] <= 0:
      expired.append(buff_type)
  for buff_type in expired:
    timed_buffs.erase(buff_type)
    timed_buff_ended.emit(buff_type)

func _init_grass_data() -> void:
  # 0: 기본풀 - 체력 낮음, 보상 적음 (첫 무기로 4번 베기)
  var normal_grass = GrassData.new()
  normal_grass.grass_name = "기본풀"
  normal_grass.max_health = 4
  normal_grass.regen_time = 22.0
  normal_grass.min_drop_value = 1
  normal_grass.max_drop_value = 1
  normal_grass.drop_chance = GRASS_DROP_CHANCE
  normal_grass.color = Color(0.3, 0.7, 0.3)
  normal_grass.cut_color = Color(0.5, 0.4, 0.2)

  # 1: 강한풀 - 체력 중간, 보상 좋음
  var tough_grass = GrassData.new()
  tough_grass.grass_name = "강한풀"
  tough_grass.max_health = 12
  tough_grass.regen_time = 23.0
  tough_grass.min_drop_value = 5
  tough_grass.max_drop_value = 5
  tough_grass.drop_chance = GRASS_DROP_CHANCE
  tough_grass.color = Color(0.15, 0.5, 0.35)
  tough_grass.cut_color = Color(0.3, 0.35, 0.25)

  # 2: 완전 센풀 - 체력 높음, 보상 매우 좋음
  var strong_grass = GrassData.new()
  strong_grass.grass_name = "완전 센풀"
  strong_grass.max_health = 24
  strong_grass.regen_time = 24.0
  strong_grass.min_drop_value = 30
  strong_grass.max_drop_value = 30
  strong_grass.drop_chance = GRASS_DROP_CHANCE
  strong_grass.color = Color(0.1, 0.35, 0.5)
  strong_grass.cut_color = Color(0.2, 0.3, 0.35)

  # 3: 황금풀 - 예외적 존재, 모든 레벨에서 동일 확률로 등장
  var golden_grass = GrassData.new()
  golden_grass.grass_name = "황금풀"
  golden_grass.max_health = 160
  golden_grass.regen_time = 25.0
  golden_grass.min_drop_value = 300
  golden_grass.max_drop_value = 300
  golden_grass.guaranteed_drop = true
  golden_grass.color = Color(1.0, 0.85, 0.1)
  golden_grass.cut_color = Color(0.7, 0.6, 0.1)

  grass_data_list.append(normal_grass)
  grass_data_list.append(tough_grass)
  grass_data_list.append(strong_grass)
  grass_data_list.append(golden_grass)

# 등급 유효 레벨 매핑 (L1-2 소폭, L3-10 정상 증가)
const QUALITY_EFFECTIVE: Array = [0.0, 0.2, 0.5, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]

func get_random_grass_data() -> GrassData:
  var raw_level = upgrade_levels.get("grass_quality", 0)
  var quality_level = QUALITY_EFFECTIVE[clampi(raw_level, 0, QUALITY_EFFECTIVE.size() - 1)]

  var roll = randf()
  if roll < get_golden_grass_chance():
    return grass_data_list[3]  # 황금풀

  # 가중치 기반 3종 풀 분배
  # 기본풀: effective 0에서 100%, 7+ 등장 안 함
  # 완전 센풀: effective 2 이하 등장 안 함, 8에서 100%
  # 강한풀: 나머지
  var normal_w: float
  if quality_level >= 7.0:
    normal_w = 0.0
  else:
    normal_w = pow((7.0 - quality_level) / 7.0, 1.8)

  var strong_w: float
  if quality_level <= 2.0:
    strong_w = 0.0
  else:
    strong_w = pow((quality_level - 2.0) / 6.0, 1.8)

  var tough_w = max(0.0, 1.0 - normal_w - strong_w)

  var remaining_roll = randf()
  if remaining_roll < normal_w:
    return grass_data_list[0]  # 기본풀
  elif remaining_roll < normal_w + tough_w:
    return grass_data_list[1]  # 강한풀
  else:
    return grass_data_list[2]  # 완전 센풀

func add_money(amount: int) -> void:
  session_money = max(0, session_money + amount)
  session_money_changed.emit(session_money)

# Returns grass quality level for spawning calculations
# Higher level = more chance for rare grass
func get_grass_quality_level() -> int:
  return upgrade_levels.get("grass_quality", 0)

func get_grass_density_level() -> int:
  return upgrade_levels.get("grass_density", 0)

func get_magnet_range() -> float:
  var mult = 1.0 + session_buff_magnet_range * 0.5
  if timed_buffs.has("harvest_madness"):
    mult *= 2.0
  mult += get_part_count("강화 유리 모듈", 6) * 0.15  # 유리 모듈: 개당 +15%, 최대 +90%
  return base_magnet_range * mult

func get_session_attack_speed_mult() -> float:
  var mult = 1.0 + session_buff_attack_speed * 0.25
  mult += get_part_count("운전기사", 1) * 0.2  # 운전기사: +20%
  if timed_buffs.has("overdrive"):
    mult *= 2.0  # +100%
  if timed_buffs.has("harvest_madness"):
    mult *= 2.0
  if hit_penalty_active:
    mult *= 0.5
  return mult

func get_session_attack_range_mult() -> float:
  var mult = 1.0 + session_buff_attack_range * 0.25
  mult += get_part_count("폭발하는 엔진 코어", 10) * 0.1  # 엔진코어: 개당 +10%, 최대 +100%
  if timed_buffs.has("harvest_madness"):
    mult *= 1.5
  return mult

func get_session_move_speed_mult() -> float:
  var mult = 1.0 + session_buff_move_speed * 0.5
  mult += get_part_count("개념상 바퀴", 4) * 0.08  # 바퀴: 개당 +8%, 최대 +32%
  if timed_buffs.has("overdrive"):
    mult *= 0.5  # -50%
  if timed_buffs.has("harvest_madness"):
    mult *= 2.0
  if hit_penalty_active:
    mult *= 0.5
  return mult

func get_coin_multiplier() -> int:
  if timed_buffs.has("gold_rush"):
    return 2
  return 1

func get_timed_buff_remaining(type: String) -> float:
  return timed_buffs.get(type, 0.0)

func apply_powerup(type: String) -> void:
  match type:
    "attack_speed":
      session_buff_attack_speed += 1
      powerup_acquired.emit(type, session_buff_attack_speed)
    "attack_range":
      session_buff_attack_range += 1
      powerup_acquired.emit(type, session_buff_attack_range)
    "magnet_range":
      session_buff_magnet_range += 1
      powerup_acquired.emit(type, session_buff_magnet_range)
    "move_speed":
      session_buff_move_speed += 1
      powerup_acquired.emit(type, session_buff_move_speed)
    "overdrive":
      _start_timed_buff("overdrive", 10.0)
      powerup_acquired.emit(type, 1)
    "extra_time":
      extra_time_requested.emit(5.0)
      powerup_acquired.emit(type, 0)
    "gold_rush":
      _start_timed_buff("gold_rush", 10.0)
      powerup_acquired.emit(type, 0)
    "golden_bloom":
      golden_bloom_requested.emit()
      powerup_acquired.emit(type, 0)
    "double_or_dust":
      _apply_double_or_dust()
    "beast_rush":
      beast_rush_requested.emit()
      powerup_acquired.emit(type, 0)
    "harvest_madness":
      _start_timed_buff("harvest_madness", 5.0)
      powerup_acquired.emit(type, 0)
    "field_clear":
      field_clear_requested.emit()
      powerup_acquired.emit(type, 0)
    "blackhole":
      blackhole_requested.emit()
      powerup_acquired.emit(type, 0)

func _start_timed_buff(type: String, duration: float) -> void:
  timed_buffs[type] = duration
  timed_buff_started.emit(type, duration)

func _apply_double_or_dust() -> void:
  if randf() < 0.5:
    # Double!
    var bonus = session_money
    add_money(bonus)
    powerup_acquired.emit("double_or_dust", 1)  # 1 = success
  else:
    # Dust!
    var lost = session_money
    add_money(-lost)
    powerup_acquired.emit("double_or_dust", 0)  # 0 = fail

const BASE_KNOCKBACK: float = 120.0
const KNOCKBACK_PER_LEVEL: float = 120.0

func get_monster_knockback_strength() -> float:
  return BASE_KNOCKBACK + get_part_count("충격 무시 범퍼", 2) * KNOCKBACK_PER_LEVEL

func get_grass_drop_chance() -> float:
  # 레벨당 6% 증가 (Lv.5 = 50%)
  return GRASS_DROP_CHANCE + upgrade_levels.get("grass_drop", 0) * 0.06

func get_golden_grass_chance() -> float:
  var lvl = upgrade_levels.get("golden_chance", 0)
  if lvl == 0:
    return 0.0002  # 기본 0.02%
  return 0.002 * lvl  # Lv.1=0.2%, Lv.5=1.0%

func get_total_skill_level() -> int:
  var total = 0
  for level in upgrade_levels.values():
    total += level
  return total

func get_grass_reward_multiplier() -> float:
  # 레벨당 30% 증가 (Lv.10 = x4.0)
  return 1.0 + upgrade_levels.get("grass_reward", 0) * 0.4

# 무기 레벨별 필요 스킬 포인트 (수동 튜닝)
# Lv0 나뭇가지, Lv1 녹슨식칼, Lv2 피자커터, Lv3 전기파리채,
# Lv4 뜨거운다리미, Lv5 매우화난고양이, Lv6 체인소,
# Lv7 마법지팡이, Lv8 날개달린선풍기, Lv9 위성레이저제초기
const WEAPON_SKILL_REQUIREMENTS = [0, 0, 2, 4, 7, 11, 16, 21, 27, 34]

# Skill tree prerequisites: "type:level" -> Array of {type, level} (all AND)
const SKILL_PREREQS = {
  # 재생 ← 밀도
  "grass_regen:1": [{"type": "grass_density", "level": 4}],
  "grass_regen:2": [{"type": "grass_density", "level": 7}],
  # 보상 ← 등급 (구 L2,4,6,8 → 신 L4,6,8,10)
  "grass_reward:1": [{"type": "grass_quality", "level": 4}],
  "grass_reward:2": [{"type": "grass_quality", "level": 6}],
  "grass_reward:3": [{"type": "grass_quality", "level": 8}],
  "grass_reward:4": [{"type": "grass_quality", "level": 10}],
  # 패널티 감소 ← 보상
  "penalty_reduce:1": [{"type": "grass_reward", "level": 2}],
  # 황금풀 ← 밀도
  "golden_chance:1": [{"type": "grass_density", "level": 5}],
  "golden_chance:2": [{"type": "grass_density", "level": 7}],
  "golden_chance:3": [{"type": "grass_density", "level": 9}],
  # 드롭률 ← 등급 (구 L2,4,6,8 → 신 L4,6,8,10)
  "grass_drop:1": [{"type": "grass_quality", "level": 4}],
  "grass_drop:2": [{"type": "grass_quality", "level": 6}],
  "grass_drop:3": [{"type": "grass_quality", "level": 8}],
  "grass_drop:4": [{"type": "grass_quality", "level": 10}],
}

func check_skill_prereqs(type: String, level: int) -> Dictionary:
  var key = "%s:%d" % [type, level]
  if not SKILL_PREREQS.has(key):
    return {"met": true, "missing": []}
  var missing: Array = []
  for req in SKILL_PREREQS[key]:
    var current = get_upgrade_level(req.type)
    if current < req.level:
      missing.append({"type": req.type, "level": req.level, "current": current})
  return {"met": missing.is_empty(), "missing": missing}

func get_upgrade_level(type: String) -> int:
  return upgrade_levels.get(type, 0)

func get_skill_max_level(type: String) -> int:
  for def in SKILL_DEFS:
    if def.type == type:
      return def.max_level
  return -1

func get_skill_def(type: String) -> Dictionary:
  for def in SKILL_DEFS:
    if def.type == type:
      return def
  return {}

func get_weapon_skill_requirement(weapon_level: int) -> int:
  if weapon_level < 0 or weapon_level >= WEAPON_SKILL_REQUIREMENTS.size():
    return 0
  return WEAPON_SKILL_REQUIREMENTS[weapon_level]

func get_grass_regen_time(base_time: float) -> float:
  var level = upgrade_levels.get("grass_regen", 0)
  if level == 0:
    return base_time
  elif level == 1:
    return 13.0
  else:
    return 4.0

# Fixed costs for density and quality (level 0→1, 1→2, ..., 9→10)
const DENSITY_COSTS: Array = [15, 60, 150, 400, 900, 2000, 4500, 10000, 22000, 50000]
const QUALITY_COSTS: Array = [15, 60, 150, 400, 900, 2000, 4500, 10000, 22000, 50000]

func get_upgrade_cost(current_level: int, upgrade_type: String = "") -> int:
  # 밀도/등급: 고정 비용 테이블
  if upgrade_type == "grass_density" and current_level < DENSITY_COSTS.size():
    return DENSITY_COSTS[current_level]
  if upgrade_type == "grass_quality" and current_level < QUALITY_COSTS.size():
    return QUALITY_COSTS[current_level]
  var base = int(BASE_UPGRADE_COST * pow(UPGRADE_COST_MULTIPLIER, current_level))
  # 보상/드롭 (선행: 등급 L4,6,8,10)
  if upgrade_type in ["grass_reward", "grass_drop"]:
    return int(base * (3.0 + current_level * 14.0))
  # 재생 (선행: 밀도 L4, L7)
  if upgrade_type == "grass_regen":
    return int(base * (3.0 + current_level * 15.0))
  # 패널티 감소 (선행: 보상 L2)
  if upgrade_type == "penalty_reduce":
    return int(base * (33.0 + current_level * 15.0))
  # 황금풀 (선행: 밀도 L5, L7, L9)
  if upgrade_type == "golden_chance":
    return int(base * (30.0 + current_level * 65.0))
  # 기타
  if current_level > 0:
    return int(base * (1.0 + current_level * 0.4))
  return base

func purchase_upgrade(upgrade_type: String) -> bool:
  var current_level = upgrade_levels.get(upgrade_type, -1)
  if current_level < 0:
    return false  # Unknown skill type
  var max_level = get_skill_max_level(upgrade_type)
  if max_level >= 0 and current_level >= max_level:
    return false

  var next_level = current_level + 1
  var prereq_result = check_skill_prereqs(upgrade_type, next_level)
  if not prereq_result.met:
    return false

  var cost = get_upgrade_cost(current_level, upgrade_type)
  if money < cost:
    return false

  money -= cost
  money_changed.emit(money)
  upgrade_levels[upgrade_type] = next_level
  upgrade_purchased.emit(upgrade_type, next_level)
  return true

func add_item(item_id: String, count: int = 1) -> void:
  if item_id not in discovered_items:
    discovered_items.append(item_id)
  if inventory.has(item_id):
    inventory[item_id] += count
  else:
    inventory[item_id] = count
  item_added.emit(item_id, inventory[item_id])
  inventory_changed.emit()

func remove_item(item_id: String, count: int = 1) -> bool:
  var current = inventory.get(item_id, 0)
  if current < count:
    return false
  inventory[item_id] = current - count
  inventory_changed.emit()
  return true

func get_item_count(item_id: String) -> int:
  return inventory.get(item_id, 0)

# ── 부품 버프 ──
func get_part_count(part_id: String, max_count: int) -> int:
  return mini(get_item_count(part_id), max_count)

func get_part_penalty_mult() -> float:
  # 스킬트리 기반: Lv1 -25%, Lv2 -50%, Lv3 -75%
  return 1.0 - upgrade_levels.get("penalty_reduce", 0) * 0.25

func is_item_discovered(item_id: String) -> bool:
  return item_id in discovered_items

func add_key(world_index: int) -> void:
  if world_index not in owned_keys:
    owned_keys.append(world_index)
    key_acquired.emit(world_index)
    SaveManager.save_game()

func has_key(world_index: int) -> bool:
  return world_index in owned_keys

func unlock_world(index: int) -> bool:
  if index < 0 or index >= WORLD_UNLOCK_COSTS.size():
    return false
  if index in unlocked_worlds:
    return false
  var cost = WORLD_UNLOCK_COSTS[index]
  if money < cost:
    return false
  if not has_key(index):
    return false
  money -= cost
  owned_keys.erase(index)
  unlocked_worlds.append(index)
  money_changed.emit(money)
  world_unlocked.emit(index)
  SaveManager.save_game()
  return true

func get_save_data() -> Dictionary:
  return {
    "money": money,
    "upgrade_levels": upgrade_levels.duplicate(),
    "inventory": inventory,
    "discovered_items": discovered_items,
    "selected_world": selected_world,
    "unlocked_worlds": unlocked_worlds,
    "owned_keys": owned_keys,
    "truck_assembled": truck_assembled,
    "prologue_seen": prologue_seen,
  }

func load_save_data(data: Dictionary) -> void:
  money = data.get("money", 0)
  # New format: upgrade_levels dictionary
  if data.has("upgrade_levels"):
    for type in data.upgrade_levels:
      upgrade_levels[type] = int(data.upgrade_levels[type])
  else:
    # Legacy save migration: individual "upgrade_X" keys
    for def in SKILL_DEFS:
      upgrade_levels[def.type] = int(data.get("upgrade_%s" % def.type, 0))
  inventory = data.get("inventory", {})
  discovered_items = data.get("discovered_items", [])
  selected_world = data.get("selected_world", 0)
  var saved_worlds = data.get("unlocked_worlds", [0])
  unlocked_worlds = []
  for w in saved_worlds:
    unlocked_worlds.append(int(w))
  if 0 not in unlocked_worlds:
    unlocked_worlds.append(0)
  truck_assembled = data.get("truck_assembled", false)
  prologue_seen = data.get("prologue_seen", false)
  var saved_keys = data.get("owned_keys", [])
  owned_keys = []
  for k in saved_keys:
    owned_keys.append(int(k))
  money_changed.emit(money)
  inventory_changed.emit()

func finalize_session() -> void:
  money += session_money
  session_money = 0
  money_changed.emit(money)

func reset_session_data() -> void:
  session_money = 0
  session_buff_attack_speed = 0
  session_buff_attack_range = 0
  session_buff_magnet_range = 0
  session_buff_move_speed = 0
  timed_buffs.clear()
  hit_penalty_active = false
  session_money_changed.emit(0)
