extends Node

signal weapon_changed(weapon_level: int)

# Preload weapon textures
var weapon_textures: Array[Texture2D] = []

# Weapon data structure
# visual_type: "scythe", "double_scythe", "spinner", "machine", "flamethrower", "device", "orb"
const WEAPONS = [
  {
    "name": "낡은 낫",
    "price": 0,
    "damage": 1,
    "range_mult": 1.0,
    "speed_mult": 1.0,
    "attack_type": "single",
    "description": "기본 무기",
    "color": Color(0.6, 0.5, 0.4),
    "visual_type": "scythe",
    "blade_length": 60,
    "blade_width": 12,
    "texture": "res://resources/images/weapon/1단계_낡은낫.png"
  },
  {
    "name": "날 선 낫",
    "price": 100,
    "damage": 2,
    "range_mult": 1.2,
    "speed_mult": 1.0,
    "attack_type": "single",
    "description": "범위 증가",
    "color": Color(0.7, 0.7, 0.75),
    "visual_type": "scythe",
    "blade_length": 70,
    "blade_width": 14,
    "texture": "res://resources/images/weapon/2단계_날선낫.png"
  },
  {
    "name": "무거운 낫",
    "price": 180,
    "damage": 4,
    "range_mult": 1.5,
    "speed_mult": 0.7,
    "attack_type": "single",
    "description": "범위↑ 속도↓",
    "color": Color(0.4, 0.4, 0.5),
    "visual_type": "heavy_scythe",
    "blade_length": 85,
    "blade_width": 20,
    "texture": "res://resources/images/weapon/3단계_무거운낫.png"
  },
  {
    "name": "이중 낫",
    "price": 324,
    "damage": 3,
    "range_mult": 1.3,
    "speed_mult": 1.0,
    "attack_type": "double",
    "description": "앞뒤 동시 공격",
    "color": Color(0.5, 0.6, 0.7),
    "visual_type": "double_scythe",
    "blade_length": 55,
    "blade_width": 12,
    "texture": "res://resources/images/weapon/4단계_이중낫.png"
  },
  {
    "name": "회전 예초낫",
    "price": 583,
    "damage": 2,
    "range_mult": 1.4,
    "speed_mult": 1.5,
    "attack_type": "spin",
    "description": "이동 중 지속 베기",
    "color": Color(0.3, 0.7, 0.4),
    "visual_type": "spinner",
    "blade_length": 50,
    "blade_width": 8,
    "texture": "res://resources/images/weapon/5단계_회전예초낫.png"
  },
  {
    "name": "제초 기계",
    "price": 1050,
    "damage": 4,
    "range_mult": 1.6,
    "speed_mult": 2.0,
    "attack_type": "aura",
    "description": "접근만 해도 피해",
    "color": Color(0.8, 0.5, 0.2),
    "visual_type": "machine",
    "blade_length": 40,
    "blade_width": 40,
    "texture": "res://resources/images/weapon/6단계_제초기계.png"
  },
  {
    "name": "분쇄 예초기",
    "price": 1890,
    "damage": 6,
    "range_mult": 2.0,
    "speed_mult": 2.5,
    "attack_type": "aura",
    "description": "대형 지속 범위",
    "color": Color(0.9, 0.3, 0.3),
    "visual_type": "machine",
    "blade_length": 55,
    "blade_width": 55,
    "texture": "res://resources/images/weapon/7단계_분쇄예초기.png"
  },
  {
    "name": "화염 제초기",
    "price": 3400,
    "damage": 12,
    "range_mult": 2.2,
    "speed_mult": 3.0,
    "attack_type": "flame",
    "description": "즉사 / 드롭 감소",
    "color": Color(1.0, 0.4, 0.1),
    "visual_type": "flamethrower",
    "blade_length": 70,
    "blade_width": 25,
    "texture": "res://resources/images/weapon/8단계_회염제초기.png"
  },
  {
    "name": "재앙 장치",
    "price": 5400,
    "damage": 24,
    "range_mult": 3.0,
    "speed_mult": 1.0,
    "attack_type": "screen",
    "description": "화면 전체 공격",
    "color": Color(0.6, 0.2, 0.8),
    "visual_type": "device",
    "blade_length": 50,
    "blade_width": 50,
    "texture": "res://resources/images/weapon/9단계_재앙장치.png"
  },
  {
    "name": "세계 정리자",
    "price": 8600,
    "damage": 60,
    "range_mult": 5.0,
    "speed_mult": 4.0,
    "attack_type": "world",
    "description": "맵 전체 자동 베기",
    "color": Color(1.0, 0.9, 0.3),
    "visual_type": "orb",
    "blade_length": 60,
    "blade_width": 60,
    "texture": "res://resources/images/weapon/10단계_세계정리자.png"
  }
]

var current_weapon_level: int = 0

func _ready() -> void:
  process_mode = Node.PROCESS_MODE_ALWAYS
  _load_weapon_textures()

func _load_weapon_textures() -> void:
  for weapon in WEAPONS:
    var texture = load(weapon.texture) as Texture2D
    weapon_textures.append(texture)

func get_current_weapon() -> Dictionary:
  return WEAPONS[current_weapon_level]

func get_weapon(level: int) -> Dictionary:
  if level >= 0 and level < WEAPONS.size():
    return WEAPONS[level]
  return WEAPONS[0]

func get_next_weapon() -> Dictionary:
  if current_weapon_level + 1 < WEAPONS.size():
    return WEAPONS[current_weapon_level + 1]
  return {}

func get_next_weapon_price() -> int:
  var next = get_next_weapon()
  if next.is_empty():
    return -1  # Max level
  return next.price

func can_upgrade() -> bool:
  var price = get_next_weapon_price()
  if price < 0:
    return false
  return GameManager.money >= price

func purchase_next_weapon() -> bool:
  if not can_upgrade():
    return false

  var price = get_next_weapon_price()
  GameManager.money -= price
  GameManager.money_changed.emit(GameManager.money)

  current_weapon_level += 1
  weapon_changed.emit(current_weapon_level)
  return true

func get_weapon_range() -> float:
  return get_current_weapon().range_mult

func get_weapon_speed() -> float:
  return get_current_weapon().speed_mult

func get_weapon_damage() -> int:
  return get_current_weapon().damage

func get_attack_type() -> String:
  return get_current_weapon().attack_type

func get_weapon_color() -> Color:
  return get_current_weapon().color

func get_visual_type() -> String:
  return get_current_weapon().visual_type

func get_blade_length() -> int:
  return get_current_weapon().blade_length

func get_blade_width() -> int:
  return get_current_weapon().blade_width

func get_weapon_texture() -> Texture2D:
  if current_weapon_level < weapon_textures.size():
    return weapon_textures[current_weapon_level]
  return null

func is_max_level() -> bool:
  return current_weapon_level >= WEAPONS.size() - 1

func get_save_data() -> Dictionary:
  return {
    "weapon_level": current_weapon_level
  }

func load_save_data(data: Dictionary) -> void:
  current_weapon_level = data.get("weapon_level", 0)
  weapon_changed.emit(current_weapon_level)
