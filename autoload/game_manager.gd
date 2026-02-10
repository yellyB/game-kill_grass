extends Node

# Game state
var money: int = 0

# Upgrades
var upgrade_attack_speed: int = 0
var upgrade_attack_range: int = 0
var upgrade_drop_rate: int = 0
var upgrade_magnet_range: int = 0
var upgrade_bonus_rate: int = 0  # 보상 증가 업그레이드

# Upgrade costs (increases each level)
const BASE_UPGRADE_COST: int = 100
const UPGRADE_COST_MULTIPLIER: float = 1.5

# Game settings
var base_attack_speed: float = 1.0
var base_attack_range: float = 80.0
var base_drop_rate: float = 1.0
var base_magnet_range: float = 75.0  # Half of original 150

# Signals
signal money_changed(new_amount: int)
signal bonus_triggered(bonus_amount: int)
signal upgrade_purchased(upgrade_type: String, level: int)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func add_money(amount: int) -> void:
	var bonus_mult = get_bonus_rate()
	var final_amount = int(amount * bonus_mult)
	money += final_amount
	money_changed.emit(money)

func add_money_with_breakdown(amount: int) -> Dictionary:
	var bonus_mult = get_bonus_rate() - 1.0  # Extra multiplier beyond base
	var bonus_amount = int(amount * bonus_mult)
	var total = amount + bonus_amount
	money += total
	money_changed.emit(money)
	if bonus_amount > 0:
		bonus_triggered.emit(bonus_amount)
	return {
		"base": amount,
		"bonus": bonus_amount,
		"total": total
	}

func get_bonus_rate() -> float:
	return 1.0 + (upgrade_bonus_rate * 0.05)  # 5% bonus per level

func get_attack_speed() -> float:
	return base_attack_speed * (1.0 + upgrade_attack_speed * 0.15)

func get_attack_range() -> float:
	return base_attack_range * (1.0 + upgrade_attack_range * 0.2)

func get_drop_multiplier() -> float:
	return base_drop_rate * (1.0 + upgrade_drop_rate * 0.25)

func get_magnet_range() -> float:
	return base_magnet_range * (1.0 + upgrade_magnet_range * 0.3)  # 30% increase per level

func get_upgrade_cost(current_level: int) -> int:
	return int(BASE_UPGRADE_COST * pow(UPGRADE_COST_MULTIPLIER, current_level))

func purchase_upgrade(upgrade_type: String) -> bool:
	var current_level: int
	match upgrade_type:
		"attack_speed":
			current_level = upgrade_attack_speed
		"attack_range":
			current_level = upgrade_attack_range
		"drop_rate":
			current_level = upgrade_drop_rate
		"magnet_range":
			current_level = upgrade_magnet_range
		"bonus_rate":
			current_level = upgrade_bonus_rate
		_:
			return false

	var cost = get_upgrade_cost(current_level)
	if money < cost:
		return false

	money -= cost
	money_changed.emit(money)

	match upgrade_type:
		"attack_speed":
			upgrade_attack_speed += 1
		"attack_range":
			upgrade_attack_range += 1
		"drop_rate":
			upgrade_drop_rate += 1
		"magnet_range":
			upgrade_magnet_range += 1
		"bonus_rate":
			upgrade_bonus_rate += 1

	upgrade_purchased.emit(upgrade_type, current_level + 1)
	return true

func get_save_data() -> Dictionary:
	return {
		"money": money,
		"upgrade_attack_speed": upgrade_attack_speed,
		"upgrade_attack_range": upgrade_attack_range,
		"upgrade_drop_rate": upgrade_drop_rate,
		"upgrade_magnet_range": upgrade_magnet_range,
		"upgrade_bonus_rate": upgrade_bonus_rate
	}

func load_save_data(data: Dictionary) -> void:
	money = data.get("money", 0)
	upgrade_attack_speed = data.get("upgrade_attack_speed", 0)
	upgrade_attack_range = data.get("upgrade_attack_range", 0)
	upgrade_drop_rate = data.get("upgrade_drop_rate", 0)
	upgrade_magnet_range = data.get("upgrade_magnet_range", 0)
	upgrade_bonus_rate = data.get("upgrade_bonus_rate", 0)
	money_changed.emit(money)

func reset_session_data() -> void:
	# Reset any temporary session state (none currently)
	pass
