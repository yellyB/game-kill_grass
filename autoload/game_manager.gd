extends Node

# Game state
var money: int = 0
var combo: int = 0
var combo_timer: float = 0.0
const COMBO_TIMEOUT: float = 1.5

# Upgrades
var upgrade_attack_speed: int = 0
var upgrade_attack_range: int = 0
var upgrade_drop_rate: int = 0
var upgrade_magnet_range: int = 0

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
signal combo_changed(new_combo: int)
signal combo_ended()
signal upgrade_purchased(upgrade_type: String, level: int)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if combo > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			end_combo()

func add_money(amount: int) -> void:
	var bonus = 1.0 + (combo * 0.03)  # 3% bonus per combo
	var final_amount = int(amount * bonus)
	money += final_amount
	money_changed.emit(money)

func add_money_with_breakdown(amount: int, use_combo: int = -1) -> Dictionary:
	# Use provided combo or current combo
	var effective_combo = use_combo if use_combo >= 0 else combo
	var combo_multiplier = effective_combo * 0.03  # 3% per combo
	var combo_bonus = int(amount * combo_multiplier)
	var total = amount + combo_bonus
	money += total
	money_changed.emit(money)
	return {
		"base": amount,
		"combo_bonus": combo_bonus,
		"total": total
	}

func add_combo() -> void:
	combo += 1
	combo_timer = COMBO_TIMEOUT
	combo_changed.emit(combo)

func end_combo() -> void:
	combo = 0
	combo_timer = 0.0
	combo_ended.emit()

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

	upgrade_purchased.emit(upgrade_type, current_level + 1)
	return true

func get_save_data() -> Dictionary:
	return {
		"money": money,
		"upgrade_attack_speed": upgrade_attack_speed,
		"upgrade_attack_range": upgrade_attack_range,
		"upgrade_drop_rate": upgrade_drop_rate,
		"upgrade_magnet_range": upgrade_magnet_range
	}

func load_save_data(data: Dictionary) -> void:
	money = data.get("money", 0)
	upgrade_attack_speed = data.get("upgrade_attack_speed", 0)
	upgrade_attack_range = data.get("upgrade_attack_range", 0)
	upgrade_drop_rate = data.get("upgrade_drop_rate", 0)
	upgrade_magnet_range = data.get("upgrade_magnet_range", 0)
	money_changed.emit(money)

func reset_session_data() -> void:
	combo = 0
	combo_timer = 0.0
