extends Node

# UI constants
const SCREEN_PADDING_H: float = 40.0
const SCREEN_PADDING_V: float = 60.0

# Game state
var money: int = 0
var session_money: int = 0
var session_boss_reward: int = 0

# World selection
var selected_world: int = 0
var unlocked_worlds: Array = [0]
var owned_keys: Array = []  # 소유 열쇠 목록 (예: [1] = 월드1 열쇠 보유)
var has_potion: bool = false  # 졸음 약 획득 여부
const WORLD_UNLOCK_COSTS: Array = [0, 100, 1000, 10000, 25000, 50000, 100000]

# 월드별 풀 체력/보상 기본 배율 (매 월드 x1.3 균일 증가, 황금풀 제외)
const WORLD_GRASS_HP_MULT: Array = [1.0, 1.3, 1.69, 2.2, 2.86, 3.71, 4.83]
const WORLD_GRASS_REWARD_MULT: Array = [1.0, 1.3, 1.69, 2.2, 2.86, 3.71, 4.83]

# 월드 초월 시스템
var world_strength_levels: Dictionary = {}  # {world_index: level}
func is_world_cleared(world: int) -> bool:
  var next = world + 1
  var is_last = next >= WORLD_UNLOCK_COSTS.size()
  if is_last:
    return has_potion
  return next in unlocked_worlds or has_key(next)

func get_world_strength_level(world: int) -> int:
  return world_strength_levels.get(world, 0)

func get_strengthen_cost(world: int) -> int:
  var next = world + 1
  var base: int
  if next < WORLD_UNLOCK_COSTS.size():
    base = int(WORLD_UNLOCK_COSTS[next] * 1.2)
  else:
    base = int(WORLD_UNLOCK_COSTS[world] * 2.0)
  var level = get_world_strength_level(world)
  return int(base * pow(3, level))

func strengthen_world(world: int) -> bool:
  if not is_world_cleared(world):
    return false
  var cost = get_strengthen_cost(world)
  if money < cost:
    return false
  money -= cost
  world_strength_levels[world] = get_world_strength_level(world) + 1
  money_changed.emit(money)
  SaveManager.save_game()
  return true

func get_world_grass_hp_mult() -> float:
  var w = selected_world
  var base = WORLD_GRASS_HP_MULT[w] if w < WORLD_GRASS_HP_MULT.size() else 1.0
  var strength = get_world_strength_level(w)
  return base * (1.0 + strength * 0.3)

func get_world_grass_reward_mult() -> float:
  var w = selected_world
  var base = WORLD_GRASS_REWARD_MULT[w] if w < WORLD_GRASS_REWARD_MULT.size() else 1.0
  var strength = get_world_strength_level(w)
  return base * (1.0 + strength * 0.5)

signal world_unlocked(index: int)
signal key_acquired(world_index: int)

# Skill definitions — single source of truth for all skills
const SKILL_DEFS: Array = [
  {"type": "attack_speed", "name": "공격 속도", "short_name": "공속", "sub_max": 5, "max_level": 12,
   "description": "다음 공격까지의 대기 시간이 짧아집니다.\n공격 간격: 0.70초 → 0.10초 (틱당 -0.01초)\n단계 5 | 최대 Lv.12"},
  {"type": "attack_range", "name": "공격 범위", "short_name": "범위", "sub_max": 5, "max_level": 10,
   "description": "공격 범위가 넓어집니다.\n범위: 60 → 260 (틱당 +4)\n단계 5 | 최대 Lv.10"},
  {"type": "attack_count", "name": "공격 개수", "short_name": "개수", "sub_max": 3, "max_level": 5,
   "description": "한 번에 베는 풀의 개수가 증가합니다.\n횟수: 1 → 46 (레벨별 +1/+2/+3/+4/+5)\n단계 3 | 최대 Lv.5"},
  {"type": "magnet_range", "name": "수집 범위", "short_name": "수집", "sub_max": 5, "max_level": 8,
   "description": "코인을 끌어당기는 범위가 넓어집니다.\n범위: 40 → 200 (틱당 +4)\n단계 5 | 최대 Lv.8"},
  {"type": "grass_density", "name": "풀 밀도", "short_name": "밀도", "sub_max": 5, "max_level": 8,
   "description": "맵 구획당 자라는 풀의 수가 증가합니다.\n구획당 풀: 1개 → 181개 (Lv별 틱당 +1/+2/.../+8)\n단계 5 | 최대 Lv.8"},
  {"type": "grass_quality", "name": "풀 등급", "short_name": "등급", "sub_max": 8, "max_level": 8,
   "description": "높은 등급의 풀로 자라날 확률이 높아집니다.\n홀수 레벨: 다음 등급 50%까지\n짝수 레벨: 다음 등급 100%까지\n단계 8 | 최대 Lv.8"},
  {"type": "chest_chance", "name": "상자 확률", "short_name": "상자", "sub_max": 5, "max_level": 5,
   "description": "맵 구획당 상자 등장 확률이 높아집니다.\n확률: 0% → 5% (틱당 +0.2%)\n단계 5 | 최대 Lv.5"},
  {"type": "crit_chance", "name": "치명타 확률", "short_name": "치확", "sub_max": 5, "max_level": 8,
   "description": "치명타 발생 확률이 높아집니다.\n확률: 0% → 80% (틱당 +2%)\n단계 5 | 최대 Lv.8"},
  {"type": "crit_damage", "name": "치명타 피해", "short_name": "치피", "sub_max": 5, "max_level": 6,
   "description": "치명타 피해량이 증가합니다.\n배율: 120% → 300% (틱당 +6%)\n단계 5 | 최대 Lv.6"},
  {"type": "attack_power", "name": "공격력", "short_name": "공격력", "sub_max": 5, "max_level": 9,
   "description": "공격력이 증가합니다.\nLv.1~3: +1/틱, Lv.4~5: +2/틱\nLv.6~7: +3/틱, Lv.8~9: +4/틱\n단계 5 | 최대 Lv.9"},
  {"type": "monster_damage", "name": "몬스터 피해", "short_name": "몬피", "sub_max": 5, "max_level": 7,
   "description": "몬스터에게 주는 피해가 증가합니다.\n배율: 100% → 450% (틱당 +10%) (미정)\n단계 5 | 최대 Lv.7"},
  {"type": "fury_rate", "name": "분노 속도", "short_name": "분노", "sub_max": 4, "max_level": 4,
   "description": "몬스터 분노 게이지가 더 빨리 찹니다.\n배율: 100% → 340% (틱당 +15%) (미정)\n단계 4 | 최대 Lv.4"},
  {"type": "golden_chance", "name": "황금풀 확률", "short_name": "황금", "sub_max": 2, "max_level": 5,
   "description": "풀이 황금풀로 자라날 확률이 높아집니다.\n확률: 0% → 1.0% (틱당 +0.1%)\n단계 2 | 최대 Lv.5"},
  {"type": "golden_reward", "name": "황금풀 보상", "short_name": "황보", "sub_max": 5, "max_level": 5,
   "description": "황금풀에서 떨어지는 코인이 증가합니다.\n보상: 100원 → ~1,696원 (단계별 10~14% 복리)\n단계 5 | 최대 Lv.5"},
  {"type": "move_speed", "name": "이동 속도", "short_name": "이속", "sub_max": 6, "max_level": 5,
   "description": "플레이어의 이동 속도가 빨라집니다.\n속도: 300 → 600 (틱당 +10)\n단계 6 | 최대 Lv.5"},
  {"type": "session_time", "name": "세션 시간", "short_name": "시간", "sub_max": 3, "max_level": 5,
   "description": "세션 시간이 증가합니다.\n+3초\n단계 3 | 최대 Lv.5"},
]

const SKILL_GROUPS: Array = [
  {
    "name": "무기",
    "skills": ["attack_power", "attack_speed", "attack_range", "crit_chance", "monster_damage", "crit_damage"],
    "columns": 2,
  },
  {
    "name": "수확",
    "skills": ["grass_density", "grass_quality", "attack_count", "golden_chance", "magnet_range", "golden_reward"],
    "columns": 2,
  },
  {
    "name": "탐험",
    "skills": ["move_speed", "session_time", "chest_chance", "fury_rate"],
    "columns": 2,
  },
]

# Upgrades — Dictionary-based level management
var upgrade_levels: Dictionary = {}  # {"grass_density": 0, "grass_quality": 0, ...}
var upgrade_sub_levels: Dictionary = {}  # {"grass_density": 0, ...}  값 범위 0~4
func get_skill_sub_max(type: String) -> int:
  var def = get_skill_def(type)
  return def.get("sub_max", 5)

# Session powerup buffs (reset each session)
var session_buff_attack_speed: int = 0
var session_buff_attack_range: int = 0
var session_buff_magnet_range: int = 0
var session_buff_move_speed: int = 0
var session_buff_critical_surge: bool = false
var session_buff_critical_reaper: int = 0
var session_buff_golden_luck: bool = false

# Timed buffs: { "gold_rush": remaining_seconds, ... }
var timed_buffs: Dictionary = {}

# Hit penalty (50% attack speed & move speed reduction)
var hit_penalty_active: bool = false

# Upgrade costs (increases each level)

# Game settings
var base_magnet_range: float = 40.0

# Grass settings
const GRASS_DROP_CHANCE: float = 1.0

# Grass data
var grass_data_list: Array[GrassData] = []

# Signals
signal money_changed(new_amount: int)
signal session_money_changed(new_amount: int)
signal upgrade_purchased(upgrade_type: String, level: int)
signal powerup_acquired(type: String, level: int)
signal timed_buff_started(type: String, duration: float)
signal timed_buff_ended(type: String)
signal extra_time_requested(seconds: float)
signal golden_bloom_requested()
signal golden_grass_cut()
signal field_clear_requested()
signal blackhole_requested()

signal fury_changed(value: float)
signal fury_boss_requested()
signal fury_gauge_dismissed()
signal boss_key_collected(world_index: int)

# 몬스터 분노 시스템
var fury: float = 0.0
var fury_boss_alive: bool = false
var session_key_acquired: int = -1  # 세션 중 보스 드롭 열쇠 (-1 = 없음)
# 월드별 분노 필요 수치
const FURY_THRESHOLDS: Array = [300.0, 1200.0, 3000.0, 7500.0, 16000.0, 22500.0, 33000.0]

func get_fury_max() -> float:
  var idx = clampi(selected_world, 0, FURY_THRESHOLDS.size() - 1)
  var base = FURY_THRESHOLDS[idx]
  var strength = get_world_strength_level(selected_world)
  return base * (1.0 + strength * 0.3)

var _sfx_click: AudioStreamPlayer
var _sfx_confirm: AudioStreamPlayer
var _sfx_skill_upgrade: AudioStreamPlayer
var _sfx_unlock: AudioStreamPlayer
var _sfx_skill_click: AudioStreamPlayer

func _ready() -> void:
  process_mode = Node.PROCESS_MODE_ALWAYS
  # Initialize upgrade_levels and sub_levels from SKILL_DEFS
  for def in SKILL_DEFS:
    if not upgrade_levels.has(def.type):
      upgrade_levels[def.type] = 0
    if not upgrade_sub_levels.has(def.type):
      upgrade_sub_levels[def.type] = 0
  # Sync WeaponManager visual from weapon skill level
  WeaponManager.current_weapon_level = upgrade_levels.get("attack_power", 0)
  _init_grass_data()
  _sfx_click = AudioStreamPlayer.new()
  _sfx_click.stream = preload("res://resources/sounds/effect/button_click.wav")
  _sfx_click.volume_db = -5.0
  add_child(_sfx_click)
  _sfx_confirm = AudioStreamPlayer.new()
  _sfx_confirm.stream = preload("res://resources/sounds/effect/confirm_button_click.wav")
  _sfx_confirm.volume_db = -3.0
  add_child(_sfx_confirm)
  _sfx_skill_upgrade = AudioStreamPlayer.new()
  _sfx_skill_upgrade.stream = preload("res://resources/sounds/effect/skill_upgrade_success.wav")
  _sfx_skill_upgrade.volume_db = -3.0
  add_child(_sfx_skill_upgrade)
  _sfx_unlock = AudioStreamPlayer.new()
  _sfx_unlock.stream = preload("res://resources/sounds/effect/unlock_world.wav")
  _sfx_unlock.volume_db = -3.0
  add_child(_sfx_unlock)
  _sfx_skill_click = AudioStreamPlayer.new()
  _sfx_skill_click.stream = preload("res://resources/sounds/effect/skill_click.wav")
  _sfx_skill_click.volume_db = -5.0
  add_child(_sfx_skill_click)
  golden_grass_cut.connect(_on_golden_grass_cut)

# 골든 럭: 황금풀 절단 시 랜덤 파워업 자동 적용
const GOLDEN_LUCK_POOL: Array = [
  {"type": "attack_speed", "weight": 20},
  {"type": "attack_range", "weight": 20},
  {"type": "magnet_range", "weight": 20},
  {"type": "move_speed", "weight": 20},
  {"type": "critical_surge", "weight": 20},
  {"type": "critical_reaper", "weight": 10},
  {"type": "extra_time", "weight": 10},
  {"type": "gold_rush", "weight": 10},
]

func _on_golden_grass_cut() -> void:
  var total_weight = 0
  for item in GOLDEN_LUCK_POOL:
    total_weight += item.weight
  var roll = randi() % total_weight
  var cumulative = 0
  for item in GOLDEN_LUCK_POOL:
    cumulative += item.weight
    if roll < cumulative:
      apply_powerup(item.type)
      return

func play_skill_click() -> void:
  _sfx_skill_click.play()

func play_button_click() -> void:
  _sfx_click.play()

func play_confirm_click() -> void:
  _sfx_confirm.play()

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
  # 0: 새싹 - 체력 낮음, 보상 적음
  var g0 = GrassData.new()
  g0.grass_name = "새싹"
  g0.max_health = 4
  g0.regen_time = 22.0
  g0.min_drop_value = 1
  g0.max_drop_value = 1
  g0.drop_chance = GRASS_DROP_CHANCE
  g0.color = Color(0.3, 0.7, 0.3)
  g0.cut_color = Color(0.5, 0.4, 0.2)

  # 1: 잔디 - 체력 중간, 보상 보통
  var g1 = GrassData.new()
  g1.grass_name = "잔디"
  g1.max_health = 18
  g1.regen_time = 23.0
  g1.min_drop_value = 5
  g1.max_drop_value = 5
  g1.drop_chance = GRASS_DROP_CHANCE
  g1.color = Color(0.15, 0.5, 0.35)
  g1.cut_color = Color(0.3, 0.35, 0.25)

  # 2: 여린풀 - 체력 높음, 보상 좋음
  var g2 = GrassData.new()
  g2.grass_name = "여린풀"
  g2.max_health = 38
  g2.regen_time = 24.0
  g2.min_drop_value = 30
  g2.max_drop_value = 30
  g2.drop_chance = GRASS_DROP_CHANCE
  g2.color = Color(0.1, 0.35, 0.5)
  g2.cut_color = Color(0.2, 0.3, 0.35)

  # 3: 강한풀 - 체력 매우 높음, 보상 매우 좋음
  var g3 = GrassData.new()
  g3.grass_name = "강한풀"
  g3.max_health = 75
  g3.regen_time = 25.0
  g3.min_drop_value = 80
  g3.max_drop_value = 80
  g3.drop_chance = GRASS_DROP_CHANCE
  g3.color = Color(0.1, 0.25, 0.55)
  g3.cut_color = Color(0.15, 0.25, 0.4)

  # 4: 초강풀 - 최고 등급, 보상 최고
  var g4 = GrassData.new()
  g4.grass_name = "초강풀"
  g4.max_health = 130
  g4.regen_time = 26.0
  g4.min_drop_value = 200
  g4.max_drop_value = 200
  g4.drop_chance = GRASS_DROP_CHANCE
  g4.color = Color(0.15, 0.2, 0.55)
  g4.cut_color = Color(0.12, 0.2, 0.4)

  # 5: 황금풀 - 예외적 존재, 황금풀 확률 스킬로만 등장
  var g5 = GrassData.new()
  g5.grass_name = "황금풀"
  g5.max_health = 80
  g5.regen_time = 25.0
  g5.min_drop_value = 100
  g5.max_drop_value = 100
  g5.guaranteed_drop = true
  g5.color = Color(1.0, 0.85, 0.1)
  g5.cut_color = Color(0.7, 0.6, 0.1)

  grass_data_list.append(g0)
  grass_data_list.append(g1)
  grass_data_list.append(g2)
  grass_data_list.append(g3)
  grass_data_list.append(g4)
  grass_data_list.append(g5)

# 풀 등급 이름 (UI 표시용)
const GRASS_TYPE_NAMES: Array = ["새싹", "잔디", "여린풀", "강한풀", "초강풀"]

func get_random_grass_data() -> GrassData:
  if randf() < get_golden_grass_chance():
    return grass_data_list[5]  # 황금풀

  # 레벨별 풀 등급 전환 (8레벨, 2레벨당 1등급 전환)
  # 짝수 코드레벨(유저 홀수): 현재 100% → 현재 50% + 다음 50%
  # 홀수 코드레벨(유저 짝수): 현재 50% + 다음 50% → 다음 100%
  var level = upgrade_levels.get("grass_quality", 0)
  var sub = upgrade_sub_levels.get("grass_quality", 0)

  # 현재 기본 등급 (2레벨마다 1등급씩 올라감)
  var base_type = mini(level / 2, 4)

  if level >= 8:
    return grass_data_list[4]  # 초강풀 100%

  var is_first_half = (level % 2 == 0)  # 코드 짝수 = 유저 홀수 = 0→50%
  var half_transition = float(sub) / 8.0 * 0.5

  if is_first_half:
    # 현재 등급 100% → 현재 50% + 다음 50%
    var next_chance = half_transition  # 0% → 50%
    if randf() < next_chance:
      return grass_data_list[mini(base_type + 1, 4)]
    return grass_data_list[base_type]
  else:
    # 현재 50% + 다음 50% → 다음 100%
    var next_chance = 0.5 + half_transition  # 50% → 100%
    if randf() < next_chance:
      return grass_data_list[mini(base_type + 1, 4)]
    return grass_data_list[base_type]

func add_fury(amount: float) -> void:
  if fury_boss_alive:
    return
  var fury_max = get_fury_max()
  fury = minf(fury + amount * get_fury_rate_mult(), fury_max)
  fury_changed.emit(fury)
  if fury >= fury_max:
    fury_boss_requested.emit()
    fury = 0.0
    fury_changed.emit(fury)

func add_money(amount: int) -> void:
  session_money = max(0, session_money + amount)
  session_money_changed.emit(session_money)

# ── Skill total progress helper ──
# Combines level and sub_level into a single progress value
func get_skill_total_progress(type: String) -> int:
  var level = upgrade_levels.get(type, 0)
  var sub = upgrade_sub_levels.get(type, 0)
  var def = get_skill_def(type)
  var sub_max = def.get("sub_max", 5)
  return level * sub_max + sub

# ── Permanent upgrade getters ──

# 공격 속도: 0.7s → 0.1s, 틱당 -0.01s (총 60틱)
func get_attack_interval() -> float:
  var ticks = get_skill_total_progress("attack_speed")
  return maxf(0.1, 0.7 - ticks * 0.01)

# 공격 범위: 60 → 260, 틱당 +4 (총 50틱)
func get_attack_range() -> float:
  var ticks = get_skill_total_progress("attack_range")
  return 60.0 + ticks * 4.0

# 공격 횟수: 1 → 46, 레벨별 틱당 +1/+2/+3/+4/+5 (총 15틱)
func get_attack_count() -> int:
  var level = upgrade_levels.get("attack_count", 0)
  var sub = upgrade_sub_levels.get("attack_count", 0)
  var sub_max = 3
  var count = 1
  for lv in range(level):
    count += (lv + 1) * sub_max
  if level < 5:
    count += (level + 1) * sub
  return count

# 수집 범위: 40 → 200, 틱당 +4 (총 40틱)
func get_base_magnet_range() -> float:
  var ticks = get_skill_total_progress("magnet_range")
  return 40.0 + ticks * 4.0

# 풀 밀도: 1 → 181, 레벨별 틱당 +Lv (총 40틱, 5틱×8레벨)
func get_grass_density_value() -> int:
  var ticks = get_skill_total_progress("grass_density")
  if ticks <= 0:
    return 1
  var value = 0
  var remaining = ticks
  for lv in range(1, 9):
    var t = mini(remaining, 5)
    value += t * lv
    remaining -= t
    if remaining <= 0:
      break
  return 1 + value

# 상자 출현률: 0% → 5%, 틱당 +0.2% (총 25틱)
func get_chest_spawn_chance() -> float:
  var ticks = get_skill_total_progress("chest_chance")
  return ticks * 0.002

# 치명타 확률: 0% → 80%, 틱당 +2% (총 40틱)
func get_crit_chance() -> float:
  if session_buff_critical_surge:
    return 1.0
  var ticks = get_skill_total_progress("crit_chance")
  return minf(ticks * 0.02, 0.8)

# 치명타 데미지: 1.2x → 3.0x, 틱당 +0.06 (총 30틱)
func get_crit_damage_mult() -> float:
  var ticks = get_skill_total_progress("crit_damage")
  var mult = 1.2 + ticks * 0.06
  if session_buff_critical_surge:
    mult *= 2.0
  return mult

# 몬스터 피해 배율 (미정 — 임시: 틱당 +0.1, 총 35틱)
func get_monster_damage_mult() -> float:
  var ticks = get_skill_total_progress("monster_damage")
  return 1.0 + ticks * 0.1

# 분노 증가 배율 (미정 — 임시: 틱당 +0.15, 총 16틱)
func get_fury_rate_mult() -> float:
  var ticks = get_skill_total_progress("fury_rate")
  return 1.0 + ticks * 0.15

# 황금풀 확률: 0% → (미정), 틱당 +0.1% (총 10틱 = 최대 1%)
func get_golden_grass_chance() -> float:
  var ticks = get_skill_total_progress("golden_chance")
  if ticks <= 0:
    return 0.0
  return ticks * 0.001

# 황금풀 보상 배율: 단계별 10%/11%/12%/13%/14% 복리 증가 (총 25틱, 최대 ~1,696원)
func get_golden_reward_mult() -> float:
  var level = upgrade_levels.get("golden_reward", 0)
  var sub = upgrade_sub_levels.get("golden_reward", 0)
  var sub_max = 5
  var mult = 1.0
  for lv in range(level):
    mult *= pow(1.0 + 0.10 + lv * 0.01, sub_max)
  if level < 5:
    mult *= pow(1.0 + 0.10 + level * 0.01, sub)
  return mult

# 이동 속도: 300 → 600, 틱당 +10 (총 30틱)
func get_base_move_speed() -> float:
  var ticks = get_skill_total_progress("move_speed")
  return 300.0 + ticks * 10.0

func get_grass_density_level() -> int:
  return upgrade_levels.get("grass_density", 0)

func get_magnet_range() -> float:
  var base = get_base_magnet_range()
  var mult = 1.0 + session_buff_magnet_range * 0.5
  if timed_buffs.has("harvest_madness"):
    mult *= 2.0
  return base * mult

func get_session_attack_speed_mult() -> float:
  var mult = 1.0 + session_buff_attack_speed * 0.25
  if timed_buffs.has("overdrive"):
    mult *= 2.0  # +100%
  if timed_buffs.has("harvest_madness"):
    mult *= 2.0
  if hit_penalty_active:
    mult *= 0.5
  return mult

func get_session_attack_range_mult() -> float:
  var mult = 1.0 + session_buff_attack_range * 0.25
  if timed_buffs.has("harvest_madness"):
    mult *= 1.5
  return mult

func get_session_move_speed_mult() -> float:
  var mult = 1.0 + session_buff_move_speed * 0.5
  if timed_buffs.has("overdrive"):
    mult *= 0.5  # -50%
  if timed_buffs.has("harvest_madness"):
    mult *= 2.0
  if hit_penalty_active:
    mult *= 0.5
  return mult

func get_session_time_bonus() -> float:
  return get_skill_total_progress("session_time") * 3.0

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
    "critical_surge":
      session_buff_critical_surge = true
      powerup_acquired.emit(type, 1)
    "critical_reaper":
      session_buff_critical_reaper += 3
      powerup_acquired.emit(type, session_buff_critical_reaper)
    "golden_luck":
      session_buff_golden_luck = true
      powerup_acquired.emit(type, 1)
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
    "monster_fury":
      add_fury(get_fury_max() * 0.2 / get_fury_rate_mult())
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

func get_monster_knockback_strength() -> float:
  return BASE_KNOCKBACK

func get_grass_drop_chance() -> float:
  # 레벨당 6% 증가 (Lv.5 = 50%)
  return GRASS_DROP_CHANCE + upgrade_levels.get("grass_drop", 0) * 0.06

# get_golden_grass_chance() is defined above in permanent upgrade getters

func get_total_skill_level() -> int:
  var total = 0
  for type in upgrade_levels:
    if type == "attack_power":
      continue
    total += upgrade_levels[type]
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
# Row 0 = root (centered, no prereq). Row 1+ = 2-col grid, prereq = skill above in same column
const SKILL_PREREQS = {
  # 무기: row1 ← root(attack_power)
  "attack_speed:1": [{"type": "attack_power", "level": 1}],
  "attack_range:1": [{"type": "attack_power", "level": 1}],
  # 무기: row2 ← row1 (각 열 직선)
  "crit_chance:1": [{"type": "attack_speed", "level": 1}],
  "monster_damage:1": [{"type": "attack_range", "level": 1}],
  # 무기: row3 ← crit_chance
  "crit_damage:1": [{"type": "crit_chance", "level": 1}],
  # 수확: row1 ← root(grass_density)
  "grass_quality:1": [{"type": "grass_density", "level": 1}],
  "attack_count:1": [{"type": "grass_density", "level": 1}],
  # 수확: row2 ← row1 (각 열 직선)
  "golden_chance:1": [{"type": "grass_quality", "level": 1}],
  "magnet_range:1": [{"type": "attack_count", "level": 1}],
  # 수확: row3 ← golden_chance
  "golden_reward:1": [{"type": "golden_chance", "level": 1}],
  # 탐험: row1 ← root(move_speed)
  "session_time:1": [{"type": "move_speed", "level": 1}],
  "chest_chance:1": [{"type": "move_speed", "level": 1}],
  # 탐험: row2 ← row1 (OR)
  "fury_rate:1": [{"type": "session_time_or_chest_chance", "level": 1}],
}

# Required total skill levels to unlock (해금 게이트)
const SKILL_REQUIRED_TOTAL = {
  # 수확: row2 (Lv.2+)
  "attack_count:2": 3,
  # 무기: row2 (Lv.2+)
  "crit_damage:2": 3,
  # 무기: row2 (Lv.1+)
  "monster_damage:1": 30,
  # 무기: row2 (Lv.2+)
  "monster_damage:2": 3,
  # 수확: row3 (Lv.2+)
  "golden_reward:2": 3,
  # 수확: row3 (Lv.1+)
  "golden_chance:1": 8,
  # 탐험: root (Lv.2+)
  "move_speed:2": 2,
  # 탐험: row1 (Lv.1+)
  "chest_chance:1": 12,
  # 탐험: row2 (Lv.1+)
  "fury_rate:1": 30,
  # 탐험: row2 (Lv.2+)
  "fury_rate:2": 3,
}

func check_skill_prereqs(type: String, level: int) -> Dictionary:
  var missing: Array = []
  # Check required_total gate (level-specific key first, then type-wide)
  var total_key = "%s:%d" % [type, level]
  var required = -1
  if SKILL_REQUIRED_TOTAL.has(total_key):
    required = SKILL_REQUIRED_TOTAL[total_key]
  elif SKILL_REQUIRED_TOTAL.has(type):
    required = SKILL_REQUIRED_TOTAL[type]
  if required >= 0:
    var total = get_total_skill_level()
    if total < required:
      missing.append({"type": "_total", "level": required, "current": total})
  # Check skill prereqs
  var key = "%s:%d" % [type, level]
  if SKILL_PREREQS.has(key):
    for req in SKILL_PREREQS[key]:
      if "_or_" in req.type:
        # OR condition: any one of the types meeting the level is enough
        var or_types = req.type.split("_or_")
        var any_met = false
        for ot in or_types:
          if get_upgrade_level(ot) >= req.level:
            any_met = true
            break
        if not any_met:
          var names = []
          for ot in or_types:
            names.append(get_skill_def(ot).get("short_name", ot))
          missing.append({"type": req.type, "level": req.level, "current": 0, "or_names": names})
      else:
        var current = get_upgrade_level(req.type)
        if current < req.level:
          missing.append({"type": req.type, "level": req.level, "current": current})
  return {"met": missing.is_empty(), "missing": missing}

func has_any_purchasable_skill() -> bool:
  for def in SKILL_DEFS:
    var type = def.type
    var current_level = upgrade_levels.get(type, 0)
    var max_level = def.max_level
    if max_level >= 0 and current_level >= max_level:
      continue
    var next_level = current_level + 1
    var prereq = check_skill_prereqs(type, next_level)
    if not prereq.met:
      continue
    var cost = get_upgrade_cost(current_level, type)
    if money >= cost:
      return true
  return false

func get_upgrade_level(type: String) -> int:
  return upgrade_levels.get(type, 0)

func get_upgrade_sub_level(type: String) -> int:
  return upgrade_sub_levels.get(type, 0)

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

# ── 틱 비용 테이블: [시작가, 틱당증가] (인덱스 = 코드 레벨) ──

# ━━ 무기 그룹 ━━
# root: 공격력 (5t×9L)
const ATTACK_POWER_TICK_COSTS: Array = [
  [1, 1],           # Lv.1: 1,2,3,4,5 = 15
  [15, 3],          # Lv.2: 15,18,21,24,27 = 105
  [300, 20],        # Lv.3: 300,320,340,360,380 = 1,700
  [1000, 100],      # Lv.4: 1000,1100,1200,1300,1400 = 6,000
  [5000, 500],      # Lv.5: 5000,5500,6000,6500,7000 = 30,000
  [30000, 3000],    # Lv.6: 30000,33000,36000,39000,42000 = 180,000
  [100000, 10000],  # Lv.7: 100000,110000,120000,130000,140000 = 600,000
  [300000, 30000],  # Lv.8: 300000,330000,360000,390000,420000 = 1,800,000
  [800000, 80000],  # Lv.9: 800000,880000,960000,1040000,1120000 = 4,800,000
]
# row1: 공격 속도 (5t×12L)
const ATTACK_SPEED_TICK_COSTS: Array = [
  [15, 2],          # Lv.1: 15,17,19,21,23 = 95
  [40, 5],          # Lv.2: 40,45,50,55,60 = 250
  [120, 10],        # Lv.3: 120,130,140,150,160 = 700
  [1500, 150],      # Lv.4: 1500,1650,1800,1950,2100 = 9,000
  [4500, 450],      # Lv.5: 4500,4950,5400,5850,6300 = 27,000
  [12000, 1200],    # Lv.6: 12000,13200,14400,15600,16800 = 72,000
  [30000, 3000],    # Lv.7: 30000,33000,36000,39000,42000 = 180,000
  [75000, 7500],    # Lv.8: 75000,82500,90000,97500,105000 = 450,000
  [180000, 15000],  # Lv.9: 180000,195000,210000,225000,240000 = 1,050,000
  [420000, 37500],  # Lv.10: 420000,457500,495000,532500,570000 = 2,475,000
  [975000, 82500],  # Lv.11: 975000,1057500,1140000,1222500,1305000 = 5,700,000
  [2250000, 180000], # Lv.12: 2250000,2430000,2610000,2790000,2970000 = 13,050,000
]
# row1: 공격 범위 (5t×10L)
const ATTACK_RANGE_TICK_COSTS: Array = [
  [10, 1],          # Lv.1: 10,11,12,13,14 = 60
  [25, 2],          # Lv.2: 25,27,29,31,33 = 145
  [60, 3],          # Lv.3: 60,63,66,69,72 = 330
  [1000, 100],      # Lv.4: 1000,1100,1200,1300,1400 = 6,000
  [3000, 300],      # Lv.5: 3000,3300,3600,3900,4200 = 18,000
  [8000, 800],      # Lv.6: 8000,8800,9600,10400,11200 = 48,000
  [20000, 2000],    # Lv.7: 20000,22000,24000,26000,28000 = 120,000
  [50000, 5000],    # Lv.8: 50000,55000,60000,65000,70000 = 300,000
  [120000, 10000],  # Lv.9: 120000,130000,140000,150000,160000 = 700,000
  [280000, 25000],  # Lv.10: 280000,305000,330000,355000,380000 = 1,650,000
]
# row2: 치명타 확률 (5t×8L)
const CRIT_CHANCE_TICK_COSTS: Array = [
  [20, 2],          # Lv.1: 20,22,24,26,28 = 120
  [120, 10],        # Lv.2: 120,130,140,150,160 = 700
  [220, 18],        # Lv.3: 220,238,256,274,292 = 1,280
  [400, 30],        # Lv.4: 400,430,460,490,520 = 2,300
  [40000, 4000],    # Lv.5: 40000,44000,48000,52000,56000 = 240,000
  [40000, 4000],    # Lv.6: 40000,44000,48000,52000,56000 = 240,000
  [95000, 9500],    # Lv.7: 95000,104500,114000,123500,133000 = 570,000
  [150000, 15000],  # Lv.8: 150000,165000,180000,195000,210000 = 900,000
]
# row2: 몬스터 피해 (5t×7L)
const MONSTER_DAMAGE_TICK_COSTS: Array = [
  [50, 6],          # Lv.1: 50,56,62,68,74 = 310
  [120, 10],        # Lv.2: 120,130,140,150,160 = 700
  [500, 50],        # Lv.3: 500,550,600,650,700 = 3,000
  [12000, 1200],    # Lv.4: 12000,13200,14400,15600,16800 = 72,000
  [45000, 4500],    # Lv.5: 45000,49500,54000,58500,63000 = 270,000
  [100000, 10000],  # Lv.6: 100000,110000,120000,130000,140000 = 600,000
  [170000, 17000],  # Lv.7: 170000,187000,204000,221000,238000 = 1,020,000
]
# row3: 치명타 피해 (5t×6L)
const CRIT_DAMAGE_TICK_COSTS: Array = [
  [50, 5],          # Lv.1: 50,55,60,65,70 = 300
  [100, 8],         # Lv.2: 100,108,116,124,132 = 580
  [180, 14],        # Lv.3: 180,194,208,222,236 = 1,040
  [400, 40],        # Lv.4: 400,440,480,520,560 = 2,400
  [2800, 280],      # Lv.5: 2800,3080,3360,3640,3920 = 16,800
  [10000, 1000],    # Lv.6: 10000,11000,12000,13000,14000 = 60,000
]

# ━━ 수확 그룹 ━━
# root: 풀 밀도 (5t×8L)
const DENSITY_TICK_COSTS: Array = [
  [1, 1],           # Lv.1: 1,2,3,4,5 = 15
  [15, 2],          # Lv.2: 15,17,19,21,23 = 95
  [80, 10],         # Lv.3: 80,90,100,110,120 = 500
  [1000, 200],      # Lv.4: 1000,1200,1400,1600,1800 = 7,000
  [8000, 800],      # Lv.5: 8000,8800,9600,10400,11200 = 48,000
  [40000, 4000],    # Lv.6: 40000,44000,48000,52000,56000 = 240,000
  [120000, 10000],  # Lv.7: 120000,130000,140000,150000,160000 = 700,000
  [350000, 30000],  # Lv.8: 350000,380000,410000,440000,470000 = 2,050,000
]
# row1: 풀 등급 (8t×8L)
const QUALITY_TICK_COSTS: Array = [
  [15, 1],          # Lv.1: 15,16,17,18,19,20,21,22 = 148
  [20, 1],          # Lv.2: 20,21,22,23,24,25,26,27 = 188
  [80, 5],          # Lv.3: 80,85,90,95,100,105,110,115 = 780
  [400, 30],        # Lv.4: 400,430,460,490,520,550,580,610 = 4,040
  [1000, 80],       # Lv.5: 1000,1080,1160,1240,1320,1400,1480,1560 = 10,240
  [2500, 200],      # Lv.6: 2500,2700,2900,3100,3300,3500,3700,3900 = 25,600
  [6000, 500],      # Lv.7: 6000,6500,7000,7500,8000,8500,9000,9500 = 62,000
  [15000, 1200],    # Lv.8: 15000,16200,17400,18600,19800,21000,22200,23400 = 153,600
]
# row1: 공격 개수 (3t×5L)
const ATTACK_COUNT_TICK_COSTS: Array = [
  [20, 5],          # Lv.1: 20,25,30 = 75
  [300, 30],        # Lv.2: 300,330,360 = 990
  [1000, 500],      # Lv.3: 1000,1500,2000 = 4,500
  [30000, 3000],    # Lv.4: 30000,33000,36000 = 99,000
  [100000, 20000],  # Lv.5: 100000,120000,140000 = 360,000
]
# row2: 황금풀 확률 (2t×5L)
const GOLDEN_CHANCE_TICK_COSTS: Array = [
  [20, 2],          # Lv.1: 20,22 = 42
  [150, 30],        # Lv.2: 150,180 = 330
  [500, 60],        # Lv.3: 500,560 = 1,060
  [900, 120],       # Lv.4: 900,1020 = 1,920
  [2000, 250],      # Lv.5: 2000,2250 = 4,250
]
# row2: 수집 범위 (5t×8L)
const MAGNET_TICK_COSTS: Array = [
  [20, 2],          # Lv.1: 20,22,24,26,28 = 120
  [40, 4],          # Lv.2: 40,44,48,52,56 = 240
  [80, 8],          # Lv.3: 80,88,96,104,112 = 480
  [200, 15],        # Lv.4: 200,215,230,245,260 = 1,150
  [500, 35],        # Lv.5: 500,535,570,605,640 = 2,850
  [2000, 200],      # Lv.6: 2000,2200,2400,2600,2800 = 12,000
  [10000, 1000],    # Lv.7: 10000,11000,12000,13000,14000 = 60,000
  [50000, 5000],    # Lv.8: 50000,55000,60000,65000,70000 = 300,000
]
# row3: 황금풀 보상 (5t×5L)
const GOLDEN_REWARD_TICK_COSTS: Array = [
  [50, 5],          # Lv.1: 50,55,60,65,70 = 300
  [100, 8],         # Lv.2: 100,108,116,124,132 = 580
  [180, 14],        # Lv.3: 180,194,208,222,236 = 1,040
  [700, 70],        # Lv.4: 700,770,840,910,980 = 4,200
  [2800, 280],      # Lv.5: 2800,3080,3360,3640,3920 = 16,800
]

# ━━ 탐험 그룹 ━━
# root: 이동 속도 (6t×5L)
const MOVE_SPEED_TICK_COSTS: Array = [
  [0, 0],           # Lv.1: special (1+sub/2): 1,1,2,2,3,3 = 12
  [10, 1],          # Lv.2: 10,11,12,13,14,15 = 75
  [80, 8],          # Lv.3: 80,88,96,104,112,120 = 600
  [300, 30],        # Lv.4: 300,330,360,390,420,450 = 2,250
  [3000, 300],      # Lv.5: 3000,3300,3600,3900,4200,4500 = 22,500
]
# row1: 세션 시간 (3t×5L)
const SESSION_TIME_TICK_COSTS: Array = [
  [20, 5],          # Lv.1: 20,25,30 = 75
  [200, 30],        # Lv.2: 200,230,260 = 690
  [800, 100],       # Lv.3: 800,900,1000 = 2,700
  [5000, 1500],     # Lv.4: 5000,6500,8000 = 19,500
  [40000, 23000],   # Lv.5: 40000,63000,86000 = 189,000
]
# row1: 상자 확률 (5t×5L)
const CHEST_CHANCE_TICK_COSTS: Array = [
  [15, 2],          # Lv.1: 15,17,19,21,23 = 95
  [40, 5],          # Lv.2: 40,45,50,55,60 = 250
  [80, 8],          # Lv.3: 80,88,96,104,112 = 480
  [1000, 100],      # Lv.4: 1000,1100,1200,1300,1400 = 6,000
  [30000, 3000],    # Lv.5: 30000,33000,36000,39000,42000 = 180,000
]
# row2: 분노 속도 (4t×4L)
const FURY_RATE_TICK_COSTS: Array = [
  [50, 6],          # Lv.1: 50,56,62,68 = 236
  [120, 10],        # Lv.2: 120,130,140,150 = 540
  [500, 50],        # Lv.3: 500,550,600,650 = 2,300
  [3000, 300],      # Lv.4: 3000,3300,3600,3900 = 13,800
]

func get_upgrade_cost(current_level: int, upgrade_type: String = "") -> int:
  var cost = _get_raw_upgrade_cost(current_level, upgrade_type)
  # 80% 이상 달성 시 최소 5000/틱 (1.6배씩 스케일)
  var max_lvl = get_skill_max_level(upgrade_type)
  if max_lvl > 0:
    var threshold = int(max_lvl * 0.8)  # 80% 유저 레벨
    var user_level = current_level + 1
    if user_level >= threshold:
      var levels_over = user_level - threshold
      var base = int(5000 * pow(1.6, levels_over))
      var sub = upgrade_sub_levels.get(upgrade_type, 0)
      var sub_inc = int(base * 0.06)
      cost = maxi(cost, base + sub * sub_inc)
  return cost

func _get_raw_upgrade_cost(current_level: int, upgrade_type: String = "") -> int:
  var sub = upgrade_sub_levels.get(upgrade_type, 0)

  # Special: move_speed Lv.1 — 2틱마다 1원 증가
  if current_level == 0 and upgrade_type == "move_speed":
    return 1 + sub / 2

  # 스킬별 틱 비용 테이블 선택
  var tier_costs: Array
  var SKILL_TICK_COSTS: Dictionary = {
    "attack_power": ATTACK_POWER_TICK_COSTS,
    "attack_speed": ATTACK_SPEED_TICK_COSTS,
    "attack_range": ATTACK_RANGE_TICK_COSTS,
    "attack_count": ATTACK_COUNT_TICK_COSTS,
    "magnet_range": MAGNET_TICK_COSTS,
    "grass_density": DENSITY_TICK_COSTS,
    "grass_quality": QUALITY_TICK_COSTS,
    "golden_chance": GOLDEN_CHANCE_TICK_COSTS,
    "golden_reward": GOLDEN_REWARD_TICK_COSTS,
    "crit_chance": CRIT_CHANCE_TICK_COSTS,
    "crit_damage": CRIT_DAMAGE_TICK_COSTS,
    "monster_damage": MONSTER_DAMAGE_TICK_COSTS,
    "fury_rate": FURY_RATE_TICK_COSTS,
    "move_speed": MOVE_SPEED_TICK_COSTS,
    "session_time": SESSION_TIME_TICK_COSTS,
    "chest_chance": CHEST_CHANCE_TICK_COSTS,
  }
  tier_costs = SKILL_TICK_COSTS.get(upgrade_type, ATTACK_POWER_TICK_COSTS)

  if current_level < tier_costs.size():
    return tier_costs[current_level][0] + sub * tier_costs[current_level][1]
  # Fallback: 마지막 정의 레벨 기준 1.6배씩 스케일
  var last = tier_costs[-1]
  var extra = current_level - tier_costs.size() + 1
  return int((last[0] + sub * last[1]) * pow(1.6, extra))

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
  upgrade_sub_levels[upgrade_type] = upgrade_sub_levels.get(upgrade_type, 0) + 1
  if upgrade_sub_levels[upgrade_type] >= get_skill_sub_max(upgrade_type):
    upgrade_levels[upgrade_type] = next_level
    upgrade_sub_levels[upgrade_type] = 0
    # 무기 레벨 변경 시 WeaponManager 동기화
    if upgrade_type == "attack_power":
      WeaponManager.current_weapon_level = next_level
      WeaponManager.weapon_changed.emit(next_level)
  upgrade_purchased.emit(upgrade_type, next_level)
  return true

func get_part_penalty_mult() -> float:
  # 스킬트리 기반: Lv1 -25%, Lv2 -50%, Lv3 -75%
  return 1.0 - upgrade_levels.get("penalty_reduce", 0) * 0.25

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
    "upgrade_sub_levels": upgrade_sub_levels.duplicate(),
    "selected_world": selected_world,
    "unlocked_worlds": unlocked_worlds,
    "owned_keys": owned_keys,
    "has_potion": has_potion,
    "world_strength_levels": world_strength_levels.duplicate(),
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
  # Sub-levels
  var saved_sub = data.get("upgrade_sub_levels", {})
  for type in saved_sub:
    upgrade_sub_levels[type] = int(saved_sub[type])
  selected_world = data.get("selected_world", 0)
  var saved_worlds = data.get("unlocked_worlds", [0])
  unlocked_worlds = []
  for w in saved_worlds:
    unlocked_worlds.append(int(w))
  if 0 not in unlocked_worlds:
    unlocked_worlds.append(0)
  has_potion = data.get("has_potion", false)
  var saved_keys = data.get("owned_keys", [])
  owned_keys = []
  for k in saved_keys:
    owned_keys.append(int(k))
  # 월드 초월 레벨 복원 (JSON 키는 문자열이므로 int 변환)
  world_strength_levels = {}
  var saved_strength = data.get("world_strength_levels", {})
  for k in saved_strength:
    world_strength_levels[int(k)] = int(saved_strength[k])
  money_changed.emit(money)
  # weapon 스킬 레벨에서 WeaponManager 동기화
  WeaponManager.current_weapon_level = upgrade_levels.get("attack_power", 0)
  WeaponManager.weapon_changed.emit(WeaponManager.current_weapon_level)

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
  session_buff_critical_surge = false
  session_buff_critical_reaper = 0
  session_buff_golden_luck = false
  timed_buffs.clear()
  hit_penalty_active = false
  fury = 0.0
  session_key_acquired = -1
  session_boss_reward = 0
  session_money_changed.emit(0)
