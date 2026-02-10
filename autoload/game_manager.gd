extends Node

# Game state
var money: int = 0

# Upgrades
var upgrade_drop_rate: int = 0
var upgrade_magnet_range: int = 0
var upgrade_grass_quality: int = 0  # 풀 등급 업그레이드 (고급 풀 등장 확률 증가)

# Upgrade costs (increases each level)
const BASE_UPGRADE_COST: int = 100
const UPGRADE_COST_MULTIPLIER: float = 1.5

# Game settings
var base_drop_rate: float = 1.0
var base_magnet_range: float = 75.0  # Half of original 150

# Grass data
var grass_data_list: Array[GrassData] = []

# Signals
signal money_changed(new_amount: int)
signal upgrade_purchased(upgrade_type: String, level: int)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_grass_data()

func _init_grass_data() -> void:
	var normal_grass = GrassData.new()
	normal_grass.grass_name = "Normal Grass"
	normal_grass.max_health = 1
	normal_grass.regen_time = 5.0
	normal_grass.min_drop_value = 1
	normal_grass.max_drop_value = 1
	normal_grass.drop_chance = 1.0
	normal_grass.color = Color(0.3, 0.7, 0.3)
	normal_grass.cut_color = Color(0.5, 0.4, 0.2)

	var tough_grass = GrassData.new()
	tough_grass.grass_name = "Tough Grass"
	tough_grass.max_health = 3
	tough_grass.regen_time = 8.0
	tough_grass.min_drop_value = 5
	tough_grass.max_drop_value = 5
	tough_grass.drop_chance = 1.0
	tough_grass.color = Color(0.15, 0.4, 0.35)
	tough_grass.cut_color = Color(0.3, 0.35, 0.25)

	var golden_grass = GrassData.new()
	golden_grass.grass_name = "Golden Grass"
	golden_grass.max_health = 2
	golden_grass.regen_time = 15.0
	golden_grass.min_drop_value = 10
	golden_grass.max_drop_value = 10
	golden_grass.drop_chance = 1.0
	golden_grass.color = Color(0.9, 0.8, 0.2)
	golden_grass.cut_color = Color(0.6, 0.5, 0.1)

	grass_data_list.append(normal_grass)
	grass_data_list.append(tough_grass)
	grass_data_list.append(golden_grass)

func get_random_grass_data() -> GrassData:
	var quality_level = upgrade_grass_quality

	# Golden increases from 5% to 100% over 17 levels
	var golden_chance = min(0.05 + quality_level * (0.95 / 17.0), 1.0)

	# Remaining probability split between normal and tough
	var remaining = 1.0 - golden_chance
	var tough_chance = remaining * 0.26

	var roll = randf()
	if roll < golden_chance:
		return grass_data_list[2]  # Golden
	elif roll < golden_chance + tough_chance:
		return grass_data_list[1]  # Tough
	else:
		return grass_data_list[0]  # Normal (remaining)

func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)

# Returns grass quality level for spawning calculations
# Higher level = more chance for rare grass
func get_grass_quality_level() -> int:
	return upgrade_grass_quality

func get_drop_multiplier() -> float:
	return base_drop_rate * (1.0 + upgrade_drop_rate * 0.25)

func get_magnet_range() -> float:
	return base_magnet_range * (1.0 + upgrade_magnet_range * 0.3)  # 30% increase per level

func get_upgrade_cost(current_level: int) -> int:
	return int(BASE_UPGRADE_COST * pow(UPGRADE_COST_MULTIPLIER, current_level))

func purchase_upgrade(upgrade_type: String) -> bool:
	var current_level: int
	match upgrade_type:
		"drop_rate":
			current_level = upgrade_drop_rate
		"magnet_range":
			current_level = upgrade_magnet_range
		"grass_quality":
			current_level = upgrade_grass_quality
		_:
			return false

	var cost = get_upgrade_cost(current_level)
	if money < cost:
		return false

	money -= cost
	money_changed.emit(money)

	match upgrade_type:
		"drop_rate":
			upgrade_drop_rate += 1
		"magnet_range":
			upgrade_magnet_range += 1
		"grass_quality":
			upgrade_grass_quality += 1

	upgrade_purchased.emit(upgrade_type, current_level + 1)
	return true

func get_save_data() -> Dictionary:
	return {
		"money": money,
		"upgrade_drop_rate": upgrade_drop_rate,
		"upgrade_magnet_range": upgrade_magnet_range,
		"upgrade_grass_quality": upgrade_grass_quality
	}

func load_save_data(data: Dictionary) -> void:
	money = data.get("money", 0)
	upgrade_drop_rate = data.get("upgrade_drop_rate", 0)
	upgrade_magnet_range = data.get("upgrade_magnet_range", 0)
	upgrade_grass_quality = data.get("upgrade_grass_quality", 0)
	money_changed.emit(money)

func reset_session_data() -> void:
	# Reset any temporary session state (none currently)
	pass
