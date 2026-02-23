extends Node

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
const WORLD_UNLOCK_COSTS: Array = [0, 5000, 20000, 50000]

signal world_unlocked(index: int)
signal key_acquired(world_index: int)

# Upgrades
var upgrade_grass_density: int = 0  # 풀 밀도 업그레이드 (0-10, 최대 레벨에서 빽빽하게)
var upgrade_grass_quality: int = 0  # 풀 등급 업그레이드 (0-16, 고급 풀 등장 확률 증가)
var upgrade_grass_regen: int = 0  # 풀 재생 속도 업그레이드 (0-10)
var upgrade_grass_reward: int = 0  # 풀 보상 업그레이드 (0-10, 코인 드롭량 증가)
var upgrade_monster_knockback: int = 0  # 몬스터 넉백 증가 (0-5)
var upgrade_grass_drop: int = 0  # 풀 드롭률 증가 (0-5)
var upgrade_golden_chance: int = 0  # 황금풀 확률 증가 (0-5)

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
var base_magnet_range: float = 75.0  # Half of original 150

# Grass density settings
const MAX_DENSITY_LEVEL: int = 10
const MAX_QUALITY_LEVEL: int = 10
const MAX_REGEN_LEVEL: int = 5
const MAX_REWARD_LEVEL: int = 10
const MAX_KNOCKBACK_LEVEL: int = 5
const MAX_DROP_LEVEL: int = 5
const MAX_GOLDEN_CHANCE_LEVEL: int = 5
const BASE_GRASS_PER_CHUNK: int = 8
const BASE_MIN_SPACING: float = 60.0
const GRASS_DROP_CHANCE: float = 0.2

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

var _sfx_click: AudioStreamPlayer
var _sfx_confirm: AudioStreamPlayer
var _sfx_craft: AudioStreamPlayer
var _sfx_weapon_upgrade: AudioStreamPlayer
var _sfx_skill_upgrade: AudioStreamPlayer
var _sfx_unlock: AudioStreamPlayer

func _ready() -> void:
  process_mode = Node.PROCESS_MODE_ALWAYS
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

func style_button(btn: Button, main_color: Color) -> void:
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
  style_n.content_margin_left = 24
  style_n.content_margin_right = 24
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
  style_p.content_margin_left = 24
  style_p.content_margin_right = 24
  style_p.content_margin_top = 16
  style_p.content_margin_bottom = 10
  btn.add_theme_stylebox_override("pressed", style_p)

  # Disabled
  var style_d = style_n.duplicate()
  style_d.bg_color = main_color.darkened(0.4)
  style_d.border_color = shadow_color.darkened(0.4)
  btn.add_theme_stylebox_override("disabled", style_d)

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

func get_random_grass_data() -> GrassData:
  var quality_level = upgrade_grass_quality

  var roll = randf()
  if roll < get_golden_grass_chance():
    return grass_data_list[3]  # 황금풀

  # 가중치 기반 3종 풀 분배 (겹치는 구간 있음)
  # 기본풀: Lv.0에서 100%, Lv.7에서 ~2%, Lv.8+ 등장 안 함
  # 완전 센풀: Lv.2 이하 등장 안 함, Lv.3에서 ~2%, Lv.10에서 100%
  # 강한풀: 나머지 (중반에 70% 정도로 피크)
  var normal_w: float
  if quality_level >= 8:
    normal_w = 0.0
  else:
    normal_w = pow((8.0 - quality_level) / 8.0, 1.8)

  var strong_w: float
  if quality_level <= 2:
    strong_w = 0.0
  else:
    strong_w = pow((quality_level - 2.0) / 8.0, 1.8)

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
  return upgrade_grass_quality

func get_grass_per_chunk() -> int:
  # Level 0: 8, Level 10: 80 (레벨당 +7.2)
  return int(BASE_GRASS_PER_CHUNK + upgrade_grass_density * 7.2)

func get_grass_min_spacing() -> float:
  # Level 0: 60, Level 10: 15 (레벨당 -4.5)
  return BASE_MIN_SPACING - upgrade_grass_density * 4.5

func get_grass_density_level() -> int:
  return upgrade_grass_density

func get_magnet_range() -> float:
  var mult = 1.0 + session_buff_magnet_range * 0.3
  if timed_buffs.has("harvest_madness"):
    mult *= 2.0
  return base_magnet_range * mult

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
  var mult = 1.0 + session_buff_move_speed * 0.25
  if timed_buffs.has("overdrive"):
    mult *= 0.2  # -80%
  if timed_buffs.has("harvest_madness"):
    mult *= 2.0
  if hit_penalty_active:
    mult *= 0.5
  return mult

func get_coin_multiplier() -> int:
  if timed_buffs.has("gold_rush"):
    return 2
  return 1

func is_beast_rush_active() -> bool:
  return timed_buffs.has("beast_rush")

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
      _start_timed_buff("beast_rush", 5.0)
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

const BASE_KNOCKBACK: float = 600.0
const KNOCKBACK_PER_LEVEL: float = 120.0

func get_monster_knockback_strength() -> float:
  return BASE_KNOCKBACK + upgrade_monster_knockback * KNOCKBACK_PER_LEVEL

func get_grass_drop_chance() -> float:
  # 레벨당 6% 증가 (Lv.5 = 50%)
  return GRASS_DROP_CHANCE + upgrade_grass_drop * 0.06

func get_golden_grass_chance() -> float:
  if upgrade_golden_chance == 0:
    return 0.0002  # 기본 0.02%
  return 0.002 * upgrade_golden_chance  # Lv.1=0.2%, Lv.5=1.0%

func get_total_skill_level() -> int:
  return upgrade_grass_density + upgrade_grass_quality + upgrade_grass_regen + upgrade_grass_reward + upgrade_monster_knockback + upgrade_grass_drop + upgrade_golden_chance

func get_grass_reward_multiplier() -> float:
  # 레벨당 30% 증가 (Lv.10 = x4.0)
  return 1.0 + upgrade_grass_reward * 0.3

# 무기 레벨별 필요 스킬 포인트 (수동 튜닝)
# Lv0 나뭇가지, Lv1 녹슨식칼, Lv2 피자커터, Lv3 전기파리채,
# Lv4 뜨거운다리미, Lv5 매우화난고양이, Lv6 체인소,
# Lv7 마법지팡이, Lv8 날개달린선풍기, Lv9 위성레이저제초기
const WEAPON_SKILL_REQUIREMENTS = [0, 0, 1, 2, 4, 6, 9, 12, 15, 18]

# Skill tree prerequisites: "type:level" -> Array of {type, level} (all AND)
const SKILL_PREREQS = {
  "grass_density:4": [{"type": "grass_quality", "level": 2}],
  "grass_density:7": [{"type": "grass_regen", "level": 2}],
  "grass_quality:4": [{"type": "grass_density", "level": 2}],
  "grass_quality:7": [{"type": "grass_reward", "level": 3}],
  "grass_regen:1": [{"type": "grass_density", "level": 2}],
  "grass_regen:3": [{"type": "grass_quality", "level": 2}],
  "grass_reward:1": [{"type": "grass_quality", "level": 2}],
  "grass_reward:4": [{"type": "grass_density", "level": 3}],
  "grass_reward:7": [{"type": "grass_regen", "level": 2}],
  "monster_knockback:1": [{"type": "grass_density", "level": 3}],
  "monster_knockback:3": [{"type": "grass_regen", "level": 2}],
  "grass_drop:1": [{"type": "grass_reward", "level": 2}],
  "grass_drop:3": [{"type": "grass_quality", "level": 3}],
  "golden_chance:1": [{"type": "grass_quality", "level": 3}],
  "golden_chance:3": [{"type": "grass_reward", "level": 3}],
}

func check_skill_prereqs(type: String, level: int) -> Dictionary:
  var key = "%s:%d" % [type, level]
  if not SKILL_PREREQS.has(key):
    return {"met": true, "missing": []}
  var missing: Array = []
  for req in SKILL_PREREQS[key]:
    var current = _get_upgrade_level(req.type)
    if current < req.level:
      missing.append({"type": req.type, "level": req.level, "current": current})
  return {"met": missing.is_empty(), "missing": missing}

func _get_upgrade_level(type: String) -> int:
  match type:
    "grass_density":
      return upgrade_grass_density
    "grass_quality":
      return upgrade_grass_quality
    "grass_regen":
      return upgrade_grass_regen
    "grass_reward":
      return upgrade_grass_reward
    "monster_knockback":
      return upgrade_monster_knockback
    "grass_drop":
      return upgrade_grass_drop
    "golden_chance":
      return upgrade_golden_chance
  return 0

func get_weapon_skill_requirement(weapon_level: int) -> int:
  if weapon_level < 0 or weapon_level >= WEAPON_SKILL_REQUIREMENTS.size():
    return 0
  return WEAPON_SKILL_REQUIREMENTS[weapon_level]

func get_grass_regen_time(base_time: float) -> float:
  # 매 레벨마다 3초씩 감소 (최대 Lv.5 = -15초)
  return base_time - (upgrade_grass_regen * 3.0)

func get_upgrade_cost(current_level: int, upgrade_type: String = "") -> int:
  var base = int(BASE_UPGRADE_COST * pow(UPGRADE_COST_MULTIPLIER, current_level))
  if upgrade_type == "golden_chance":
    # Lv.1: 5x, Lv.2: 7x, Lv.3: 8x, Lv.4: 9x, Lv.5: 10x
    var multiplier = 5.0 + current_level * 1.25
    return int(base * multiplier)
  return base

func purchase_upgrade(upgrade_type: String) -> bool:
  var current_level: int
  var max_level: int = -1  # -1 means no max
  match upgrade_type:
    "grass_density":
      current_level = upgrade_grass_density
      max_level = MAX_DENSITY_LEVEL
    "grass_quality":
      current_level = upgrade_grass_quality
      max_level = MAX_QUALITY_LEVEL
    "grass_regen":
      current_level = upgrade_grass_regen
      max_level = MAX_REGEN_LEVEL
    "grass_reward":
      current_level = upgrade_grass_reward
      max_level = MAX_REWARD_LEVEL
    "monster_knockback":
      current_level = upgrade_monster_knockback
      max_level = MAX_KNOCKBACK_LEVEL
    "grass_drop":
      current_level = upgrade_grass_drop
      max_level = MAX_DROP_LEVEL
    "golden_chance":
      current_level = upgrade_golden_chance
      max_level = MAX_GOLDEN_CHANCE_LEVEL
    _:
      return false

  # Check max level
  if max_level >= 0 and current_level >= max_level:
    return false

  # Check skill prerequisites
  var next_level = current_level + 1
  var prereq_result = check_skill_prereqs(upgrade_type, next_level)
  if not prereq_result.met:
    return false

  var cost = get_upgrade_cost(current_level, upgrade_type)
  if money < cost:
    return false

  money -= cost
  money_changed.emit(money)

  match upgrade_type:
    "grass_density":
      upgrade_grass_density += 1
    "grass_quality":
      upgrade_grass_quality += 1
    "grass_regen":
      upgrade_grass_regen += 1
    "grass_reward":
      upgrade_grass_reward += 1
    "monster_knockback":
      upgrade_monster_knockback += 1
    "grass_drop":
      upgrade_grass_drop += 1
    "golden_chance":
      upgrade_golden_chance += 1

  upgrade_purchased.emit(upgrade_type, current_level + 1)
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
    "upgrade_grass_density": upgrade_grass_density,
    "upgrade_grass_quality": upgrade_grass_quality,
    "upgrade_grass_regen": upgrade_grass_regen,
    "upgrade_grass_reward": upgrade_grass_reward,
    "upgrade_monster_knockback": upgrade_monster_knockback,
    "upgrade_grass_drop": upgrade_grass_drop,
    "upgrade_golden_chance": upgrade_golden_chance,
    "inventory": inventory,
    "discovered_items": discovered_items,
    "selected_world": selected_world,
    "unlocked_worlds": unlocked_worlds,
    "owned_keys": owned_keys,
    "truck_assembled": truck_assembled,
  }

func load_save_data(data: Dictionary) -> void:
  money = data.get("money", 0)
  upgrade_grass_density = data.get("upgrade_grass_density", 0)
  upgrade_grass_quality = data.get("upgrade_grass_quality", 0)
  upgrade_grass_regen = data.get("upgrade_grass_regen", 0)
  upgrade_grass_reward = data.get("upgrade_grass_reward", 0)
  upgrade_monster_knockback = data.get("upgrade_monster_knockback", 0)
  upgrade_grass_drop = data.get("upgrade_grass_drop", 0)
  upgrade_golden_chance = data.get("upgrade_golden_chance", 0)
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
