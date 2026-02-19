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
var upgrade_magnet_range: int = 0
var upgrade_grass_quality: int = 0  # 풀 등급 업그레이드 (고급 풀 등장 확률 증가)
var upgrade_grass_regen: int = 0  # 풀 재생 속도 업그레이드 (0-10)

# Upgrade costs (increases each level)
const BASE_UPGRADE_COST: int = 100
const UPGRADE_COST_MULTIPLIER: float = 1.5

# Game settings
var base_magnet_range: float = 75.0  # Half of original 150

# Grass density settings
const MAX_DENSITY_LEVEL: int = 10
const MAX_REGEN_LEVEL: int = 10
const BASE_GRASS_PER_CHUNK: int = 8
const BASE_MIN_SPACING: float = 60.0

# Grass data
var grass_data_list: Array[GrassData] = []

# Signals
signal money_changed(new_amount: int)
signal session_money_changed(new_amount: int)
signal upgrade_purchased(upgrade_type: String, level: int)
signal item_added(item_id: String, count: int)
signal inventory_changed()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_grass_data()
	call_deferred("_debug_fill_parts")

func _debug_fill_parts() -> void:
	if not OS.is_debug_build():
		return
	var parts = {
		"개념상 바퀴": 4,
		"폭발하는 엔진 코어": 10,
		"충격 무시 범퍼": 2,
		"이세계 내비게이션": 1,
		"강화 유리 모듈": 6,
		"운전기사": 1,
	}
	for part_id in parts:
		if get_item_count(part_id) < parts[part_id]:
			inventory[part_id] = parts[part_id]
			if part_id not in discovered_items:
				discovered_items.append(part_id)
	inventory_changed.emit()

func _init_grass_data() -> void:
	# 0: 기본풀 - 체력 낮음, 보상 적음 (첫 무기로 4번 베기)
	var normal_grass = GrassData.new()
	normal_grass.grass_name = "기본풀"
	normal_grass.max_health = 4
	normal_grass.regen_time = 22.0
	normal_grass.min_drop_value = 1
	normal_grass.max_drop_value = 1
	normal_grass.drop_chance = 1.0
	normal_grass.color = Color(0.3, 0.7, 0.3)
	normal_grass.cut_color = Color(0.5, 0.4, 0.2)

	# 1: 강한풀 - 체력 중간, 보상 좋음
	var tough_grass = GrassData.new()
	tough_grass.grass_name = "강한풀"
	tough_grass.max_health = 12
	tough_grass.regen_time = 23.0
	tough_grass.min_drop_value = 5
	tough_grass.max_drop_value = 5
	tough_grass.drop_chance = 1.0
	tough_grass.color = Color(0.15, 0.5, 0.35)
	tough_grass.cut_color = Color(0.3, 0.35, 0.25)

	# 2: 완전 센풀 - 체력 높음, 보상 매우 좋음
	var strong_grass = GrassData.new()
	strong_grass.grass_name = "완전 센풀"
	strong_grass.max_health = 24
	strong_grass.regen_time = 24.0
	strong_grass.min_drop_value = 30
	strong_grass.max_drop_value = 30
	strong_grass.drop_chance = 1.0
	strong_grass.color = Color(0.1, 0.35, 0.5)
	strong_grass.cut_color = Color(0.2, 0.3, 0.35)

	# 3: 황금풀 - 예외적 존재, 모든 레벨에서 동일 확률로 등장
	var golden_grass = GrassData.new()
	golden_grass.grass_name = "황금풀"
	golden_grass.max_health = 60
	golden_grass.regen_time = 25.0
	golden_grass.min_drop_value = 100
	golden_grass.max_drop_value = 500
	golden_grass.drop_chance = 1.0
	golden_grass.color = Color(1.0, 0.85, 0.1)
	golden_grass.cut_color = Color(0.7, 0.6, 0.1)

	grass_data_list.append(normal_grass)
	grass_data_list.append(tough_grass)
	grass_data_list.append(strong_grass)
	grass_data_list.append(golden_grass)

func get_random_grass_data() -> GrassData:
	var quality_level = upgrade_grass_quality

	# 황금풀: 모든 레벨에서 동일한 확률 (2%)
	const GOLDEN_CHANCE = 0.02

	var roll = randf()
	if roll < GOLDEN_CHANCE:
		return grass_data_list[3]  # 황금풀

	# 나머지 확률에서 3단계 풀 분배
	# Lv.0: 기본풀 100%
	# Lv.9: 기본풀 50%, 강한풀 50%
	# Lv.18: 강한풀 50%, 완전 센풀 50%
	# Lv.27+: 완전 센풀 100%
	var progress = min(quality_level / 27.0, 1.0)  # 0.0 ~ 1.0

	# 3단계 전환: 기본 -> 강한 -> 완전 센
	var normal_chance: float
	var tough_chance: float

	if progress < 0.5:
		# 전반부: 기본풀에서 강한풀로 전환
		var t = progress * 2.0  # 0 ~ 1
		normal_chance = 1.0 - t
		tough_chance = t
	else:
		# 후반부: 강한풀에서 완전 센풀로 전환
		var t = (progress - 0.5) * 2.0  # 0 ~ 1
		normal_chance = 0.0
		tough_chance = 1.0 - t

	var remaining_roll = randf()
	if remaining_roll < normal_chance:
		return grass_data_list[0]  # 기본풀
	elif remaining_roll < normal_chance + tough_chance:
		return grass_data_list[1]  # 강한풀
	else:
		return grass_data_list[2]  # 완전 센풀

func add_money(amount: int) -> void:
	session_money += amount
	session_money_changed.emit(session_money)

# Returns grass quality level for spawning calculations
# Higher level = more chance for rare grass
func get_grass_quality_level() -> int:
	return upgrade_grass_quality

func get_grass_per_chunk() -> int:
	# Level 0: 8, Level 10: 80 (very dense)
	return int(BASE_GRASS_PER_CHUNK * (1.0 + upgrade_grass_density * 0.9))

func get_grass_min_spacing() -> float:
	# Level 0: 60, Level 10: 12 (almost no space between grass)
	return BASE_MIN_SPACING / (1.0 + upgrade_grass_density * 0.4)

func get_grass_density_level() -> int:
	return upgrade_grass_density

func get_magnet_range() -> float:
	return base_magnet_range * (1.0 + upgrade_magnet_range * 0.3)  # 30% increase per level

func get_grass_regen_time(base_time: float) -> float:
	# 매 레벨마다 2초씩 감소
	return base_time - (upgrade_grass_regen * 2.0)

func get_upgrade_cost(current_level: int) -> int:
	return int(BASE_UPGRADE_COST * pow(UPGRADE_COST_MULTIPLIER, current_level))

func purchase_upgrade(upgrade_type: String) -> bool:
	var current_level: int
	var max_level: int = -1  # -1 means no max
	match upgrade_type:
		"grass_density":
			current_level = upgrade_grass_density
			max_level = MAX_DENSITY_LEVEL
		"magnet_range":
			current_level = upgrade_magnet_range
		"grass_quality":
			current_level = upgrade_grass_quality
		"grass_regen":
			current_level = upgrade_grass_regen
			max_level = MAX_REGEN_LEVEL
		_:
			return false

	# Check max level
	if max_level >= 0 and current_level >= max_level:
		return false

	var cost = get_upgrade_cost(current_level)
	if money < cost:
		return false

	money -= cost
	money_changed.emit(money)

	match upgrade_type:
		"grass_density":
			upgrade_grass_density += 1
		"magnet_range":
			upgrade_magnet_range += 1
		"grass_quality":
			upgrade_grass_quality += 1
		"grass_regen":
			upgrade_grass_regen += 1

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
		"upgrade_magnet_range": upgrade_magnet_range,
		"upgrade_grass_quality": upgrade_grass_quality,
		"upgrade_grass_regen": upgrade_grass_regen,
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
	upgrade_magnet_range = data.get("upgrade_magnet_range", 0)
	upgrade_grass_quality = data.get("upgrade_grass_quality", 0)
	upgrade_grass_regen = data.get("upgrade_grass_regen", 0)
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
	session_money_changed.emit(0)
